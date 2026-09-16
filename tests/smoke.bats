#!/usr/bin/env bats

setup() {
    load test_helper
}

# The only black-box test in the suite: run main.sh the way a user would, from a
# copy outside the checkout, and check that it boots, creates its backup session
# next to the copy, and leaves the real repository alone.
@test "main.sh boots against a fake install and exits cleanly" {
    local sandbox="${BATS_TEST_TMPDIR}/sandbox"
    local st="${BATS_TEST_TMPDIR}/SillyTavern"

    mkdir -p "$sandbox" "${st}/data/default-user" "${BATS_TEST_TMPDIR}/home"
    cp "${REPO_ROOT}/main.sh" "${sandbox}/main.sh"
    cp -R "${REPO_ROOT}/lib" "${sandbox}/lib"

    : > "${st}/server.js"
    printf '{"name":"sillytavern","version":"1.12.0"}\n' > "${st}/package.json"
    printf '{}\n' > "${st}/data/default-user/settings.json"

    # candidate confirmation (blank -> yes), user name (blank -> default-user),
    # the startup summary prompt, then "0" to exit
    printf '\n\n\n0\n' > "${BATS_TEST_TMPDIR}/stdin.txt"

    cd "$sandbox"
    # A throwaway HOME keeps the $HOME scan from picking up a real SillyTavern
    # installation and changing the number of candidates.
    run env TERM=dumb HOME="${BATS_TEST_TMPDIR}/home" bash main.sh < "${BATS_TEST_TMPDIR}/stdin.txt"

    [ "$status" -eq 0 ]

    [ -d "${sandbox}/STbackupF" ]
    run bash -c "find '${sandbox}/STbackupF' -mindepth 1 -maxdepth 1 -type d | wc -l"
    [ "$(tr -d '[:space:]' <<< "$output")" -eq 1 ]

    [ ! -e "${REPO_ROOT}/STbackupF" ]
}
