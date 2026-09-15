#!/usr/bin/env bats

setup() {
    load test_helper
    source_libs
}

@test "trim_whitespace strips surrounding blanks and keeps the middle intact" {
    run trim_whitespace "  a  b  "
    [ "$status" -eq 0 ]
    [ "$output" = "a  b" ]

    run trim_whitespace "   "
    [ "$output" = "" ]
}

@test "is_positive_integer accepts positive decimals and rejects everything else" {
    run is_positive_integer "5"; [ "$status" -eq 0 ]
    run is_positive_integer "05"; [ "$status" -eq 0 ]
    run is_positive_integer "0"; [ "$status" -ne 0 ]
    run is_positive_integer "-1"; [ "$status" -ne 0 ]
    run is_positive_integer "abc"; [ "$status" -ne 0 ]
    run is_positive_integer ""; [ "$status" -ne 0 ]
}

@test "is_risky_port flags well-known service ports only" {
    run is_risky_port "22"; [ "$status" -eq 0 ]
    run is_risky_port "3000"; [ "$status" -eq 0 ]
    run is_risky_port "10000"; [ "$status" -ne 0 ]
}

@test "compare_versions compares numerically rather than lexically" {
    run compare_versions "1.9.0" "1.10.0"
    [ "$output" = "-1" ]

    run compare_versions "1.13.0" "1.12.9"
    [ "$output" = "1" ]

    run compare_versions "1.12.0" "1.12.0"
    [ "$output" = "0" ]
}

@test "compare_versions tolerates pre-release suffixes and missing segments" {
    run compare_versions "1.12.0-staging" "1.12.0"
    [ "$output" = "0" ]

    run compare_versions "1.12.0+build7" "1.12.0"
    [ "$output" = "0" ]

    run compare_versions "2.0" "2.0.0"
    [ "$output" = "0" ]

    run compare_versions "1.12.x" "1.12.0"
    [ "$output" = "0" ]
}

@test "check_st_version fails closed when the ST version is unknown" {
    ST_VERSION=""
    run check_st_version ">=" 1 0 0
    [ "$status" -ne 0 ]
}

@test "check_st_version applies the comparison against the detected version" {
    ST_VERSION="1.13.5"
    run check_st_version ">=" 1 13 5; [ "$status" -eq 0 ]
    run check_st_version "<" 1 13 5; [ "$status" -ne 0 ]
    run check_st_version ">" 1 12 0; [ "$status" -eq 0 ]
    run check_st_version "<=" 1 13 4; [ "$status" -ne 0 ]
}

@test "check_st_version rejects an unknown operator" {
    ST_VERSION="1.13.5"
    run check_st_version "~>" 1 0 0
    [ "$status" -ne 0 ]
}

@test "insert_line_after_anchor inserts once, after the first matching anchor" {
    local file="${BATS_TEST_TMPDIR}/users.js"
    printf 'const a = 1;\nttl: false, // Never expire\nconst b = 2;\nttl: false, // Never expire\n' > "$file"

    run insert_line_after_anchor "$file" "ttl: false, // Never expire" "        expiredInterval: 0,"
    [ "$status" -eq 0 ]

    diff -u <(printf 'const a = 1;\nttl: false, // Never expire\n        expiredInterval: 0,\nconst b = 2;\nttl: false, // Never expire\n') "$file"
    [ "$(grep -c 'expiredInterval' "$file")" -eq 1 ]
}

@test "insert_line_after_anchor leaves the file untouched when the anchor is missing" {
    local file="${BATS_TEST_TMPDIR}/users.js"
    printf 'const a = 1;\n' > "$file"
    cp "$file" "${BATS_TEST_TMPDIR}/before.js"

    run insert_line_after_anchor "$file" "no-such-anchor" "inserted"
    [ "$status" -ne 0 ]
    cmp -s "${BATS_TEST_TMPDIR}/before.js" "$file"
}

@test "insert_line_after_anchor cleans up its temp file when it fails" {
    local file="${BATS_TEST_TMPDIR}/users.js"
    printf 'const a = 1;\n' > "$file"

    run insert_line_after_anchor "$file" "no-such-anchor" "inserted"
    [ "$status" -ne 0 ]
    [ -z "$(find "${BATS_TEST_TMPDIR}" -name '.foxium.*' -print -quit)" ]
}
