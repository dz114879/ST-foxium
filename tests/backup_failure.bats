#!/usr/bin/env bats
#
# Locks down the CLAUDE.md contract: a write must never happen after its
# backup failed. Clearing BACKUP_SESSION_DIR makes create_backup fail
# deterministically without touching the target file's permissions.

setup() {
    load test_helper
    source_libs
    make_st_fixture
    init_test_backup
}

@test "update_start_script_memory_limit leaves the file untouched when the backup fails" {
    cp "${ST_DIR}/start.sh" "${BATS_TEST_TMPDIR}/before.sh"
    BACKUP_SESSION_DIR=""

    run update_start_script_memory_limit "${ST_DIR}/start.sh" 4096

    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/before.sh" "${ST_DIR}/start.sh"
    [ -z "$(find "${ST_DIR}" -name '.foxium.*' -print -quit)" ]
}

@test "patch_expired_interval_setting leaves the file untouched when the backup fails" {
    local file="${ST_DIR}/users.js"
    printf 'const user = {\n    ttl: false, // Never expire\n};\n' > "$file"
    cp "$file" "${BATS_TEST_TMPDIR}/before.js"
    BACKUP_SESSION_DIR=""

    run patch_expired_interval_setting "$file" "ttl: false, // Never expire" "    expiredInterval: 0,"

    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/before.js" "$file"
}

@test "remove_chat_size_limit leaves the file untouched when the backup fails" {
    local server_main="${ST_DIR}/src/server-main.js"
    mkdir -p "$(dirname "$server_main")"
    printf "app.use(bodyParser.json({ limit: '10mb' }));\napp.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));\n" > "$server_main"
    cp "$server_main" "${BATS_TEST_TMPDIR}/before.js"
    BACKUP_SESSION_DIR=""

    run remove_chat_size_limit < /dev/null

    cmp -s "${BATS_TEST_TMPDIR}/before.js" "$server_main"
    [ -z "$(find "${ST_DIR}/src" -name '.foxium.*' -print -quit)" ]
}
