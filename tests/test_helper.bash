#!/usr/bin/env bash
#
# Shared helpers for the FFSS bats suite.
#
# Rules the whole suite follows:
#   * assertions check exit status and filesystem side effects, never the
#     Chinese/ANSI stdout text, so rewording a prompt cannot break a test;
#   * bats runs test bodies with errexit semantics, so a call that is expected
#     to fail must be guarded with `|| status=$?` or wrapped in `run`;
#   * `run` executes in a subshell and therefore loses side effects on shell
#     variables -- it cannot be used for functions that report through a global
#     (YQ_FLAVOR, BACKUP_SESSION_DIR, ...).

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd -P)"
FFSS_LIB_DIR="${REPO_ROOT}/lib"

# Source every lib file in the same order main.sh does.
source_libs() {
    local name
    for name in common backup detect npm_fix extension_fix never_oom \
        gemini_media config_editor settings_editor chat_limit auto_backup; do
        # shellcheck source=/dev/null
        source "${FFSS_LIB_DIR}/${name}.sh"
    done
}

# Write the two files is_valid_st_dir requires; callers add whatever else their
# fixture needs.
make_st_root() {
    local dir="$1"

    mkdir -p "$dir"
    : > "${dir}/server.js"
    printf '{"name":"sillytavern","version":"1.12.0"}\n' > "${dir}/package.json"
}

# Build the smallest tree that passes is_valid_st_dir and gives the patched or
# edited files somewhere to live. Everything goes under BATS_TEST_TMPDIR so the
# real checkout is never touched.
make_st_fixture() {
    ST_DIR="${BATS_TEST_TMPDIR}/st"
    USER_NAME="default-user"
    USER_DIR="${ST_DIR}/data/${USER_NAME}"

    make_st_root "$ST_DIR"
    mkdir -p "${USER_DIR}"
    printf 'port: 8000\n' > "${ST_DIR}/config.yaml"
    printf '{}\n' > "${USER_DIR}/settings.json"
    printf '#!/usr/bin/env bash\nnode server.js\n' > "${ST_DIR}/start.sh"

    ST_VERSION="1.12.0"
}

# Point the backup system at a throwaway root and open a session, mirroring what
# run_startup_checks does before any write can happen.
init_test_backup() {
    BACKUP_ROOT="${BATS_TEST_TMPDIR}/backups"
    BACKUP_SESSION_DIR=""
    init_backup_session >/dev/null
}

backup_entry_count() {
    find "$BACKUP_SESSION_DIR" -mindepth 1 -maxdepth 1 -print 2>/dev/null |
        wc -l | tr -d '[:space:]'
}

# Assert that BACKUP_SESSION_DIR holds a copy identical to the snapshot at $1.
# Tests take that snapshot *before* the operation under test, which encodes the
# CLAUDE.md contract: the pre-change bytes must still be recoverable afterwards.
assert_backed_up() {
    local snapshot="$1"
    local candidate

    if [[ ! -d "$BACKUP_SESSION_DIR" ]]; then
        printf 'backup session directory does not exist: %s\n' "$BACKUP_SESSION_DIR" >&2
        return 1
    fi

    if [[ -d "$snapshot" ]]; then
        while IFS= read -r candidate; do
            if diff -r "$snapshot" "$candidate" >/dev/null 2>&1; then
                return 0
            fi
        done < <(find "$BACKUP_SESSION_DIR" -mindepth 1 -maxdepth 1 -type d)
    else
        while IFS= read -r candidate; do
            if cmp -s "$snapshot" "$candidate"; then
                return 0
            fi
        done < <(find "$BACKUP_SESSION_DIR" -mindepth 1 -maxdepth 1 -type f)
    fi

    printf 'no backup copy matching %s under %s\n' "$snapshot" "$BACKUP_SESSION_DIR" >&2
    return 1
}

# Install a recording `yq` shim on PATH. The shim does not emulate yq: it records
# how it was invoked and reports success or failure according to the requested
# flavour, which is exactly what detect_yq_flavor probes for.
install_yq_stub() {
    local flavor="$1"

    YQ_STUB_BIN="${BATS_TEST_TMPDIR}/bin"
    YQ_STUB_LOG="${BATS_TEST_TMPDIR}/yq.log"
    export YQ_STUB_LOG
    export FAKE_YQ_FLAVOR="$flavor"

    mkdir -p "$YQ_STUB_BIN"
    : > "$YQ_STUB_LOG"

    cat > "${YQ_STUB_BIN}/yq" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${YQ_STUB_LOG:?}"
case "${FAKE_YQ_FLAVOR:?}" in
    mikefarah)
        [[ "${1:-}" == "eval" ]] && exit 0
        exit 1
        ;;
    kislyuk)
        [[ "${1:-}" == "eval" ]] && exit 1
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
STUB
    chmod +x "${YQ_STUB_BIN}/yq"

    PATH="${YQ_STUB_BIN}:${PATH}"
    export PATH
}

yq_stub_calls() {
    cat "$YQ_STUB_LOG"
}
