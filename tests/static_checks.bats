#!/usr/bin/env bats

setup() {
    load test_helper
}

# The release artifact is a hand-regenerated bundle with no generator in the
# repo, so the only guard against shipping stale code to users is this check.
# The bundle goes through a shfmt-like pass, so whitespace is stripped from both
# sides before comparing; any real edit still shows up as a mismatch.
@test "build/ffss.sh contains every lib file verbatim (whitespace-insensitive)" {
    local bundle
    bundle="$(tr -d '[:space:]' < "${REPO_ROOT}/build/ffss.sh")"

    local drifted=()
    local path body
    for path in "${REPO_ROOT}"/lib/*.sh; do
        body="$(tail -n +2 "$path" | tr -d '[:space:]')"
        if [[ "$bundle" != *"$body"* ]]; then
            drifted+=("$(basename "$path")")
        fi
    done

    if [ "${#drifted[@]}" -ne 0 ]; then
        printf 'build/ffss.sh is out of sync with lib/: %s\n' "${drifted[*]}" >&2
        return 1
    fi
}

@test "shellcheck reports no error-level findings" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck is not installed"
    fi

    run shellcheck -S error "${REPO_ROOT}"/lib/*.sh "${REPO_ROOT}/main.sh"

    [ "$status" -eq 0 ]
}
