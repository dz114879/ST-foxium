#!/usr/bin/env bats

setup() {
    load test_helper
    source_libs

    HOME="${BATS_TEST_TMPDIR}/home"
    FOXIUM_ROOT="${BATS_TEST_TMPDIR}/workspace"
    FOXIUM_INVOCATION_DIR=""
    mkdir -p "$HOME" "$FOXIUM_ROOT"
}

@test "scan_candidate_root finds an install under an arbitrary directory name" {
    make_st_root "${BATS_TEST_TMPDIR}/root/酒馆-1.12.14"

    ST_CANDIDATES=()
    scan_candidate_root "${BATS_TEST_TMPDIR}/root"

    [ "${#ST_CANDIDATES[@]}" -eq 1 ]
    [ "${ST_CANDIDATES[0]}" = "$(canonical_path "${BATS_TEST_TMPDIR}/root/酒馆-1.12.14")" ]
}

@test "scan_candidate_root ignores directories that are not a complete install" {
    mkdir -p "${BATS_TEST_TMPDIR}/root/half"
    : > "${BATS_TEST_TMPDIR}/root/half/server.js"

    ST_CANDIDATES=()
    scan_candidate_root "${BATS_TEST_TMPDIR}/root"

    [ "${#ST_CANDIDATES[@]}" -eq 0 ]
}

@test "collect_st_candidates finds an install under HOME" {
    make_st_root "${HOME}/SillyTavern"

    collect_st_candidates

    [ "${#ST_CANDIDATES[@]}" -eq 1 ]
    [ "${ST_CANDIDATES[0]}" = "$(canonical_path "${HOME}/SillyTavern")" ]
}

@test "collect_st_candidates reports the same install once when several roots reach it" {
    make_st_root "$FOXIUM_ROOT"
    FOXIUM_INVOCATION_DIR="$FOXIUM_ROOT"

    collect_st_candidates

    [ "${#ST_CANDIDATES[@]}" -eq 1 ]
}

@test "expand_user_path expands tilde and the HOME variable and strips quotes" {
    [ "$(expand_user_path '~')" = "$HOME" ]
    [ "$(expand_user_path '~/SillyTavern')" = "${HOME}/SillyTavern" ]
    [ "$(expand_user_path '"~/SillyTavern"')" = "${HOME}/SillyTavern" ]
    [ "$(expand_user_path '$HOME/SillyTavern')" = "${HOME}/SillyTavern" ]
}

@test "expand_user_path converts a Windows drive path to the msys form" {
    [ "$(expand_user_path 'C:\Users\me\SillyTavern')" = "/c/Users/me/SillyTavern" ]
}

@test "resolve_user_path resolves a relative name against the invocation directory" {
    make_st_root "${BATS_TEST_TMPDIR}/apps/SillyTavern"
    FOXIUM_INVOCATION_DIR="${BATS_TEST_TMPDIR}/apps"

    run resolve_user_path "SillyTavern"

    [ "$status" -eq 0 ]
    [ "$output" = "$(canonical_path "${BATS_TEST_TMPDIR}/apps/SillyTavern")" ]
}

@test "resolve_user_path falls back to HOME for a relative name" {
    make_st_root "${HOME}/SillyTavern"

    run resolve_user_path "SillyTavern"

    [ "$status" -eq 0 ]
    [ "$output" = "$(canonical_path "${HOME}/SillyTavern")" ]
}

@test "resolve_user_path resolves an existing file as well as a directory" {
    make_st_root "${BATS_TEST_TMPDIR}/apps/SillyTavern"
    FOXIUM_INVOCATION_DIR="${BATS_TEST_TMPDIR}/apps"

    run resolve_user_path "SillyTavern/server.js"

    [ "$status" -eq 0 ]
    [ "$output" = "$(canonical_path "${BATS_TEST_TMPDIR}/apps/SillyTavern/server.js")" ]
}

@test "build_st_search_roots lists a directory once when roots overlap" {
    FOXIUM_ROOT="$HOME"
    FOXIUM_INVOCATION_DIR="$HOME"

    build_st_search_roots

    # HOME and its parent; the duplicate invocation root and HOME/.. are dropped.
    [ "${#ST_SEARCH_ROOTS[@]}" -eq 2 ]
}

@test "prompt_for_st_directory accepts a tilde path" {
    make_st_root "${HOME}/SillyTavern"
    ST_DIR=""

    prompt_for_st_directory <<< "~/SillyTavern" > /dev/null

    [ "$ST_DIR" = "$(canonical_path "${HOME}/SillyTavern")" ]
}

@test "prompt_for_st_directory returns non-zero on empty input instead of looping" {
    local status=0

    prompt_for_st_directory <<< "" > /dev/null || status=$?

    [ "$status" -ne 0 ]
}

@test "prompt_for_st_directory walks up from a directory inside the install" {
    make_st_root "${HOME}/SillyTavern"
    mkdir -p "${HOME}/SillyTavern/data"
    ST_DIR=""

    prompt_for_st_directory <<< $'~/SillyTavern/data\ny' > /dev/null

    [ "$ST_DIR" = "$(canonical_path "${HOME}/SillyTavern")" ]
}

@test "prompt_for_st_directory offers installs found under the given parent directory" {
    make_st_root "${HOME}/apps/SillyTavern"
    ST_DIR=""

    prompt_for_st_directory <<< $'~/apps\ny' > /dev/null

    [ "$ST_DIR" = "$(canonical_path "${HOME}/apps/SillyTavern")" ]
}

@test "prompt_for_st_directory walks up from a file inside the install" {
    make_st_root "${HOME}/SillyTavern"
    mkdir -p "${HOME}/SillyTavern/data/default-user"
    : > "${HOME}/SillyTavern/data/default-user/settings.json"
    ST_DIR=""

    prompt_for_st_directory <<< $'~/SillyTavern/data/default-user/settings.json\ny' > /dev/null

    [ "$ST_DIR" = "$(canonical_path "${HOME}/SillyTavern")" ]
}

@test "prompt_for_st_directory rejects a missing path next to a valid install" {
    make_st_root "${HOME}/SillyTavern"
    ST_DIR=""
    local status=0

    # the first path does not exist, so the script asks again; q then exits
    prompt_for_st_directory <<< $'~/SillyTavern/nope.txt\nq' > /dev/null || status=$?

    [ "$status" -ne 0 ]
    [ -z "$ST_DIR" ]
}

@test "select_st_directory asks before using a single candidate" {
    make_st_root "${FOXIUM_ROOT}/SillyTavern"
    ST_DIR=""

    select_st_directory <<< "y" > /dev/null
    [ "$ST_DIR" = "$(canonical_path "${FOXIUM_ROOT}/SillyTavern")" ]

    # declining the candidate falls back to manual input; q then exits there
    local status=0
    ST_DIR=""
    select_st_directory <<< $'n\nq' > /dev/null || status=$?

    [ "$status" -ne 0 ]
    [ -z "$ST_DIR" ]
}
