#!/usr/bin/env bats

setup() {
    load test_helper
}

# Build a throwaway copy of the script outside the checkout, a fake install it
# can boot against, and a throwaway HOME so the $HOME scan cannot pick up a real
# SillyTavern installation. Tests then run main.sh from the sandbox directory.
prepare_black_box() {
    mkdir -p "${BATS_TEST_TMPDIR}/sandbox" "${BATS_TEST_TMPDIR}/home"
    mkdir -p "${BATS_TEST_TMPDIR}/SillyTavern/data/default-user"

    cp "${REPO_ROOT}/main.sh" "${BATS_TEST_TMPDIR}/sandbox/main.sh"
    cp -R "${REPO_ROOT}/lib" "${BATS_TEST_TMPDIR}/sandbox/lib"

    : > "${BATS_TEST_TMPDIR}/SillyTavern/server.js"
    printf '{"name":"sillytavern","version":"1.12.0"}\n' > "${BATS_TEST_TMPDIR}/SillyTavern/package.json"
    printf '{}\n' > "${BATS_TEST_TMPDIR}/SillyTavern/data/default-user/settings.json"
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
