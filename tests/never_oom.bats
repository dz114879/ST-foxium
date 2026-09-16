#!/usr/bin/env bats

setup() {
    load test_helper
    source_libs
    make_st_fixture
    init_test_backup
}

@test "update_start_script_memory_limit inserts the flag into a bare node line" {
    cp "${ST_DIR}/start.sh" "${BATS_TEST_TMPDIR}/snapshot.sh"

    update_start_script_memory_limit "${ST_DIR}/start.sh" 4096

    grep -Fq 'node --max-old-space-size=4096 server.js' "${ST_DIR}/start.sh"
    assert_backed_up "${BATS_TEST_TMPDIR}/snapshot.sh"
}

@test "update_start_script_memory_limit replaces an existing nonzero limit" {
    printf '#!/usr/bin/env bash\nnode --max-old-space-size=2048 server.js\n' > "${ST_DIR}/start.sh"

    update_start_script_memory_limit "${ST_DIR}/start.sh" 4096

    grep -Fq 'node --max-old-space-size=4096 server.js' "${ST_DIR}/start.sh"
    [ "$(grep -c -- '--max-old-space-size' "${ST_DIR}/start.sh")" -eq 1 ]
}

@test "update_start_script_memory_limit is idempotent and creates no extra backup" {
    update_start_script_memory_limit "${ST_DIR}/start.sh" 4096
    local after_first backups_before
    after_first="$(cat "${ST_DIR}/start.sh")"
    backups_before="$(backup_entry_count)"

    update_start_script_memory_limit "${ST_DIR}/start.sh" 4096

    [ "$(cat "${ST_DIR}/start.sh")" = "$after_first" ]
    [ "$(backup_entry_count)" -eq "$backups_before" ]
}

@test "update_start_script_memory_limit fails without touching the file when no node line exists" {
    printf '#!/usr/bin/env bash\necho hi\n' > "${ST_DIR}/start.sh"
    cp "${ST_DIR}/start.sh" "${BATS_TEST_TMPDIR}/before.sh"

    run update_start_script_memory_limit "${ST_DIR}/start.sh" 4096

    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/before.sh" "${ST_DIR}/start.sh"
    [ -z "$(find "${ST_DIR}" -name '.foxium.*' -print -quit)" ]
}

@test "update_start_script_memory_limit fails when the start script is missing" {
    run update_start_script_memory_limit "${ST_DIR}/nope.sh" 4096
    [ "$status" -ne 0 ]
}

@test "patch_expired_interval_setting inserts the line inside the anchored block" {
    local file="${ST_DIR}/users.js"
    printf 'const user = {\n    ttl: false, // Never expire\n};\n' > "$file"
    cp "$file" "${BATS_TEST_TMPDIR}/snapshot.js"

    patch_expired_interval_setting "$file" "ttl: false, // Never expire" "    expiredInterval: 0,"

    diff -u <(printf 'const user = {\n    ttl: false, // Never expire\n    expiredInterval: 0,\n};\n') "$file"
    assert_backed_up "${BATS_TEST_TMPDIR}/snapshot.js"
}

@test "patch_expired_interval_setting is idempotent and creates no extra backup" {
    local file="${ST_DIR}/users.js"
    printf 'const user = {\n    ttl: false, // Never expire\n};\n' > "$file"
    patch_expired_interval_setting "$file" "ttl: false, // Never expire" "    expiredInterval: 0,"

    local after_first backups_before
    after_first="$(cat "$file")"
    backups_before="$(backup_entry_count)"

    patch_expired_interval_setting "$file" "ttl: false, // Never expire" "    expiredInterval: 0,"

    [ "$(cat "$file")" = "$after_first" ]
    [ "$(backup_entry_count)" -eq "$backups_before" ]
    [ "$(grep -c 'expiredInterval' "$file")" -eq 1 ]
}

@test "patch_expired_interval_setting fails without modifying the file when the anchor is absent" {
    local file="${ST_DIR}/users.js"
    printf 'const user = {\n};\n' > "$file"
    cp "$file" "${BATS_TEST_TMPDIR}/before.js"

    run patch_expired_interval_setting "$file" "ttl: false, // Never expire" "    expiredInterval: 0,"

    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/before.js" "$file"
}

@test "patch_expired_interval_setting fails when the target file is missing" {
    run patch_expired_interval_setting "${ST_DIR}/nope.js" "anchor" "line"
    [ "$status" -ne 0 ]
}

# The platform is pinned so the automatic start script choice is the Unix one
# wherever the suite runs.
pin_unix_platform() {
    OSTYPE="linux-gnu"
    MSYSTEM=""
}

@test "never_oom runs unattended in non-interactive mode and patches both targets" {
    pin_unix_platform
    FOXIUM_NONINTERACTIVE=1
    mkdir -p "${ST_DIR}/src/endpoints"
    printf 'const user = {\n    ttl: false, // Never expire\n};\n' > "${ST_DIR}/src/users.js"
    printf 'const characters = {\n    forgiveParseErrors: true,\n};\n' > "${ST_DIR}/src/endpoints/characters.js"

    run never_oom < /dev/null

    [ "$status" -eq 0 ]
    grep -Fq 'expiredInterval: 0,' "${ST_DIR}/src/users.js"
    grep -Fq 'expiredInterval: 0,' "${ST_DIR}/src/endpoints/characters.js"
    grep -Fq -- '--max-old-space-size=4096' "${ST_DIR}/start.sh"
}

@test "never_oom reports failure through its exit status in non-interactive mode" {
    pin_unix_platform
    FOXIUM_NONINTERACTIVE=1
    # the fixture has no src/ files, so the storage patch step cannot succeed
    run never_oom < /dev/null

    [ "$status" -ne 0 ]
}
