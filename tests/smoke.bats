#!/usr/bin/env bats

setup() {
    load test_helper
}

# Build a throwaway copy of the script outside the checkout, a fake install it
# can boot against (including the files never_oom patches), and a throwaway HOME
# so the $HOME scan cannot pick up a real SillyTavern installation. Tests then
# run main.sh from the sandbox directory.
prepare_black_box() {
    mkdir -p "${BATS_TEST_TMPDIR}/sandbox" "${BATS_TEST_TMPDIR}/home"
    mkdir -p "${BATS_TEST_TMPDIR}/SillyTavern/data/default-user"
    mkdir -p "${BATS_TEST_TMPDIR}/SillyTavern/src/endpoints"

    cp "${REPO_ROOT}/main.sh" "${BATS_TEST_TMPDIR}/sandbox/main.sh"
    cp -R "${REPO_ROOT}/lib" "${BATS_TEST_TMPDIR}/sandbox/lib"

    : > "${BATS_TEST_TMPDIR}/SillyTavern/server.js"
    printf '{"name":"sillytavern","version":"1.12.0"}\n' > "${BATS_TEST_TMPDIR}/SillyTavern/package.json"
    printf '{}\n' > "${BATS_TEST_TMPDIR}/SillyTavern/data/default-user/settings.json"
    printf '#!/usr/bin/env bash\nnode server.js\n' > "${BATS_TEST_TMPDIR}/SillyTavern/start.sh"
    printf 'const user = {\n    ttl: false, // Never expire\n};\n' > "${BATS_TEST_TMPDIR}/SillyTavern/src/users.js"
    printf 'const characters = {\n    forgiveParseErrors: true,\n};\n' > "${BATS_TEST_TMPDIR}/SillyTavern/src/endpoints/characters.js"
}

# Run the sandboxed main.sh with stdin closed, so any interactive read would
# fail and surface as a non-zero exit. OSTYPE/MSYSTEM are pinned so the
# automatic start script choice is the Unix one no matter the host platform.
run_main() {
    cd "${BATS_TEST_TMPDIR}/sandbox"
    run env TERM=dumb HOME="${BATS_TEST_TMPDIR}/home" OSTYPE=linux-gnu MSYSTEM= \
        bash main.sh "$@" < /dev/null
}

# The only black-box tests in the suite: run main.sh the way a user would, from a
# copy outside the checkout, and check what it does to the sandbox.
@test "main.sh boots against a fake install and exits cleanly" {
    prepare_black_box

    # candidate confirmation (blank -> yes), user name (blank -> default-user),
    # the startup summary prompt, then "0" to exit
    printf '\n\n\n0\n' > "${BATS_TEST_TMPDIR}/stdin.txt"

    cd "${BATS_TEST_TMPDIR}/sandbox"
    run env TERM=dumb HOME="${BATS_TEST_TMPDIR}/home" bash main.sh < "${BATS_TEST_TMPDIR}/stdin.txt"

    [ "$status" -eq 0 ]

    [ -d "${BATS_TEST_TMPDIR}/sandbox/STbackupF" ]
    run bash -c "find '${BATS_TEST_TMPDIR}/sandbox/STbackupF' -mindepth 1 -maxdepth 1 -type d | wc -l"
    [ "$(tr -d '[:space:]' <<< "$output")" -eq 1 ]

    [ ! -e "${REPO_ROOT}/STbackupF" ]
}

# The menu used to spin on EOF: read fails, the empty choice falls into the
# "invalid option" branch, and the loop keeps writing to stdout forever. Closing
# stdin must end the script instead.
@test "main.sh exits when stdin ends at the menu instead of spinning" {
    command -v timeout >/dev/null 2>&1 || skip "timeout is not installed"
    prepare_black_box

    # the three startup answers, then EOF right at the main menu
    printf '\n\n\n' > "${BATS_TEST_TMPDIR}/stdin.txt"

    cd "${BATS_TEST_TMPDIR}/sandbox"
    run env TERM=dumb HOME="${BATS_TEST_TMPDIR}/home" timeout 10 bash main.sh < "${BATS_TEST_TMPDIR}/stdin.txt" > /dev/null

    [ "$status" -ne 0 ]
    # 124 would mean timeout had to kill a spinning script.
    [ "$status" -ne 124 ]
}

@test "--fix-oom patches both OOM targets unattended and backs them up first" {
    prepare_black_box
    local st="${BATS_TEST_TMPDIR}/SillyTavern"
    cp "${st}/src/users.js" "${BATS_TEST_TMPDIR}/users.snapshot"
    cp "${st}/src/endpoints/characters.js" "${BATS_TEST_TMPDIR}/characters.snapshot"
    cp "${st}/start.sh" "${BATS_TEST_TMPDIR}/start.snapshot"

    run_main --fix-oom

    [ "$status" -eq 0 ]
    grep -Fq 'expiredInterval: 0,' "${st}/src/users.js"
    grep -Fq 'expiredInterval: 0,' "${st}/src/endpoints/characters.js"
    grep -Fq -- '--max-old-space-size=4096' "${st}/start.sh"

    BACKUP_SESSION_DIR="$(find "${BATS_TEST_TMPDIR}/sandbox/STbackupF" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [ -n "$BACKUP_SESSION_DIR" ]
    assert_backed_up "${BATS_TEST_TMPDIR}/users.snapshot"
    assert_backed_up "${BATS_TEST_TMPDIR}/characters.snapshot"
    assert_backed_up "${BATS_TEST_TMPDIR}/start.snapshot"
}

# Two installs make the choice ambiguous; --fix-oom must refuse rather than
# guess and patch the wrong one.
@test "--fix-oom refuses to guess between several installs" {
    prepare_black_box
    mkdir -p "${BATS_TEST_TMPDIR}/SillyTavern-2"
    : > "${BATS_TEST_TMPDIR}/SillyTavern-2/server.js"
    printf '{"name":"sillytavern","version":"1.12.0"}\n' > "${BATS_TEST_TMPDIR}/SillyTavern-2/package.json"
    cp "${BATS_TEST_TMPDIR}/SillyTavern/start.sh" "${BATS_TEST_TMPDIR}/start.snapshot"

    run_main --fix-oom

    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/start.snapshot" "${BATS_TEST_TMPDIR}/SillyTavern/start.sh"
    [ ! -e "${BATS_TEST_TMPDIR}/sandbox/STbackupF" ]
}

@test "main.sh rejects an unknown option instead of starting the menu" {
    prepare_black_box

    run_main --no-such-flag

    [ "$status" -ne 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/sandbox/STbackupF" ]
}
