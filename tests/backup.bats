#!/usr/bin/env bats

setup() {
    load test_helper
    source_libs
}

@test "init_backup_session creates a missing backup root and a session directory" {
    BACKUP_ROOT="${BATS_TEST_TMPDIR}/fresh-backups"
    BACKUP_SESSION_DIR=""
    [ ! -d "$BACKUP_ROOT" ]

    init_backup_session

    [ -d "$BACKUP_SESSION_DIR" ]
    [[ "$BACKUP_SESSION_DIR" == "${BACKUP_ROOT}/"* ]]
}

@test "init_backup_session refuses to run without a backup root" {
    BACKUP_ROOT=""
    run init_backup_session
    [ "$status" -ne 0 ]
}

@test "consecutive sessions never share a directory" {
    BACKUP_ROOT="${BATS_TEST_TMPDIR}/backups"
    BACKUP_SESSION_DIR=""
    init_backup_session
    local first="$BACKUP_SESSION_DIR"

    BACKUP_SESSION_DIR=""
    init_backup_session

    [ -n "$BACKUP_SESSION_DIR" ]
    [ "$BACKUP_SESSION_DIR" != "$first" ]
}

@test "create_backup copies a file byte for byte" {
    make_st_fixture
    init_test_backup

    create_backup "${ST_DIR}/config.yaml"

    assert_backed_up "${ST_DIR}/config.yaml"
}

@test "create_backup copies a directory recursively" {
    make_st_fixture
    init_test_backup
    mkdir -p "${USER_DIR}/worlds"
    printf 'world\n' > "${USER_DIR}/worlds/a.json"

    create_backup "$USER_DIR"

    assert_backed_up "$USER_DIR"
    [ -f "${BACKUP_SESSION_DIR}/$(basename "$USER_DIR")/worlds/a.json" ]
}

@test "repeated backups of the same name are prefixed instead of overwritten" {
    make_st_fixture
    init_test_backup

    printf 'first\n' > "${ST_DIR}/config.yaml"
    create_backup "${ST_DIR}/config.yaml"
    printf 'second\n' > "${ST_DIR}/config.yaml"
    create_backup "${ST_DIR}/config.yaml"
    create_backup "${ST_DIR}/config.yaml"

    [ -f "${BACKUP_SESSION_DIR}/config.yaml" ]
    [ -f "${BACKUP_SESSION_DIR}/2_config.yaml" ]
    [ -f "${BACKUP_SESSION_DIR}/3_config.yaml" ]
    [ "$(cat "${BACKUP_SESSION_DIR}/config.yaml")" = "first" ]
    [ "$(cat "${BACKUP_SESSION_DIR}/2_config.yaml")" = "second" ]
}

@test "create_backup refuses a missing source and creates nothing" {
    init_test_backup

    run create_backup "${BATS_TEST_TMPDIR}/does-not-exist"

    [ "$status" -ne 0 ]
    [ "$(backup_entry_count)" -eq 0 ]
}

@test "create_backup refuses to run without a session directory" {
    make_st_fixture
    BACKUP_SESSION_DIR=""

    run create_backup "${ST_DIR}/config.yaml"

    [ "$status" -ne 0 ]
}
