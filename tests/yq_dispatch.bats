#!/usr/bin/env bats

setup() {
    load test_helper
    source_libs
    make_st_fixture
}

@test "detect_yq_flavor recognises the mikefarah dialect" {
    install_yq_stub mikefarah
    YQ_AVAILABLE="1"

    local status=0
    detect_yq_flavor || status=$?

    [ "$status" -eq 0 ]
    [ "$YQ_FLAVOR" = "mikefarah" ]
}

@test "detect_yq_flavor falls back to the kislyuk dialect" {
    install_yq_stub kislyuk
    YQ_AVAILABLE="1"

    local status=0
    detect_yq_flavor || status=$?

    [ "$status" -eq 0 ]
    [ "$YQ_FLAVOR" = "kislyuk" ]
}

@test "detect_yq_flavor disables itself when neither dialect works" {
    install_yq_stub bogus
    YQ_AVAILABLE="1"
    YQ_FLAVOR=""

    local status=0
    detect_yq_flavor || status=$?

    [ "$status" -ne 0 ]
    [ -z "$YQ_FLAVOR" ]
}

@test "detect_yq_flavor probes nothing without yq or without config.yaml" {
    install_yq_stub mikefarah

    YQ_AVAILABLE="0"
    local status=0
    detect_yq_flavor || status=$?
    [ "$status" -ne 0 ]
    [ ! -s "$YQ_STUB_LOG" ]

    YQ_AVAILABLE="1"
    ST_DIR="${BATS_TEST_TMPDIR}/no-config"
    mkdir -p "$ST_DIR"
    status=0
    detect_yq_flavor || status=$?
    [ "$status" -ne 0 ]
    [ ! -s "$YQ_STUB_LOG" ]
}

@test "yaml_write dispatches to the dialect-specific command shape" {
    local file="${ST_DIR}/config.yaml"

    install_yq_stub mikefarah
    YQ_FLAVOR="mikefarah"
    yaml_write '.port = 8001' "$file"
    [ "$(yq_stub_calls)" = "eval -i .port = 8001 ${file}" ]

    install_yq_stub kislyuk
    YQ_FLAVOR="kislyuk"
    yaml_write '.port = 8001' "$file"
    [ "$(yq_stub_calls)" = "-y -i .port = 8001 ${file}" ]
}

@test "yaml_read dispatches to the dialect-specific command shape" {
    local file="${ST_DIR}/config.yaml"

    install_yq_stub mikefarah
    YQ_FLAVOR="mikefarah"
    yaml_read '.port' "$file"
    [ "$(yq_stub_calls)" = "eval -r .port ${file}" ]

    install_yq_stub kislyuk
    YQ_FLAVOR="kislyuk"
    yaml_read '.port' "$file"
    [ "$(yq_stub_calls)" = "-r .port ${file}" ]
}

@test "yaml_read and yaml_write refuse to run without a recognised flavour" {
    install_yq_stub mikefarah
    local file="${ST_DIR}/config.yaml"
    YQ_FLAVOR=""

    local status=0
    yaml_read '.port' "$file" || status=$?
    [ "$status" -ne 0 ]

    status=0
    yaml_write '.port = 8001' "$file" || status=$?
    [ "$status" -ne 0 ]

    [ ! -s "$YQ_STUB_LOG" ]
}
