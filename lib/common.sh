#!/usr/bin/env bash

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
DIM=$'\033[2m'
NC=$'\033[0m'
BOLD=$'\033[1m'

ST_DIR="${ST_DIR:-}"
ST_VERSION="${ST_VERSION:-}"
USER_NAME="${USER_NAME:-default-user}"
USER_DIR="${USER_DIR:-}"
BACKUP_ROOT="${BACKUP_ROOT:-}"
BACKUP_SESSION_DIR="${BACKUP_SESSION_DIR:-}"
JQ_AVAILABLE="${JQ_AVAILABLE:-0}"
YQ_AVAILABLE="${YQ_AVAILABLE:-0}"
YQ_FLAVOR="${YQ_FLAVOR:-}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

clear_screen() {
    if command_exists clear; then
        clear
    fi
}

print_info() {
    printf '%b\n' "${BLUE}[信息]${NC} $*"
}

print_success() {
    printf '%b\n' "${GREEN}[成功]${NC} $*"
}

print_warn() {
    printf '%b\n' "${YELLOW}[警告]${NC} $*"
}

print_error() {
    printf '%b\n' "${RED}[错误]${NC} $*"
}

print_risk() {
    printf '%b\n' "${RED}${BOLD}[风险]${NC} $*"
}

print_title() {
    printf '\n%b\n' "${BOLD}${CYAN}========================================${NC}"
    printf '%b\n' "${BOLD}${CYAN}$1${NC}"
    printf '%b\n\n' "${BOLD}${CYAN}========================================${NC}"
}

press_enter_to_continue() {
    printf '%b' "${YELLOW}按回车键继续...${NC}"
    read -r _
}

prompt_choice() {
    local prompt="$1"
    local __resultvar="$2"
    local response
    printf '%b' "${YELLOW}${prompt}${NC}"
    read -r response
    printf -v "$__resultvar" '%s' "$response"
}

ask_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local suffix=""
    local response=""

    case "${default,,}" in
        y) suffix=" [Y/n]: " ;;
        *) suffix=" [y/N]: " ;;
    esac

    while true; do
        printf '%b' "${YELLOW}${prompt}${suffix}${NC}"
        read -r response
        response="$(trim_whitespace "${response:-$default}")"

        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *)
                print_warn "请输入 y 或 n。"
                ;;
        esac
    done
}

trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

to_lower() {
    printf '%s' "${1,,}"
}

is_integer() {
    [[ "$1" =~ ^-?[0-9]+$ ]]
}

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 > 0 ))
}

random_port() {
    printf '%s' "$((10000 + RANDOM % 39152))"
}

is_risky_port() {
    case "$1" in
        20|21|22|23|25|53|80|110|123|143|443|465|587|993|995|1433|1521|2049|2375|2376|3000|3306|3389|5432|5672|5900|6379|8080|8443|9200)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

canonical_path() {
    local path="$1"

    if [[ -d "$path" ]]; then
        (cd "$path" && pwd -P)
        return
    fi

    if [[ -e "$path" ]]; then
        local parent
        parent="$(cd "$(dirname "$path")" && pwd -P)" || return 1
        printf '%s/%s' "$parent" "$(basename "$path")"
        return
    fi

    return 1
}

make_temp_next_to() {
    local target="$1"
    local target_dir
    target_dir="$(cd "$(dirname "$target")" && pwd -P)" || return 1

    if command_exists mktemp; then
        mktemp "${target_dir}/.foxium.XXXXXX"
    else
        local temp_file="${target_dir}/.foxium.$$.$RANDOM"
        : > "$temp_file" || return 1
        printf '%s' "$temp_file"
    fi
}

sanitize_version_part() {
    local part="${1//[^0-9]/}"
    printf '%s' "${part:-0}"
}

parse_version_triplet() {
    local cleaned="${1%%-*}"
    cleaned="${cleaned%%+*}"
    local major minor patch extra
    IFS='.' read -r major minor patch extra <<< "$cleaned"
    printf '%s %s %s' \
        "$(sanitize_version_part "$major")" \
        "$(sanitize_version_part "$minor")" \
        "$(sanitize_version_part "$patch")"
}

compare_versions() {
    local left_major left_minor left_patch
    local right_major right_minor right_patch

    read -r left_major left_minor left_patch <<< "$(parse_version_triplet "$1")"
    read -r right_major right_minor right_patch <<< "$(parse_version_triplet "$2")"

    if (( 10#$left_major > 10#$right_major )); then
        printf '%s' "1"
    elif (( 10#$left_major < 10#$right_major )); then
        printf '%s' "-1"
    elif (( 10#$left_minor > 10#$right_minor )); then
        printf '%s' "1"
    elif (( 10#$left_minor < 10#$right_minor )); then
        printf '%s' "-1"
    elif (( 10#$left_patch > 10#$right_patch )); then
        printf '%s' "1"
    elif (( 10#$left_patch < 10#$right_patch )); then
        printf '%s' "-1"
    else
        printf '%s' "0"
    fi
}

check_st_version() {
    local operator="$1"
    local target_version="${2:-0}.${3:-0}.${4:-0}"
    local comparison

    if [[ -z "$ST_VERSION" ]]; then
        return 1
    fi

    comparison="$(compare_versions "$ST_VERSION" "$target_version")"

    case "$operator" in
        '<'|-lt) [[ "$comparison" == "-1" ]] ;;
        '<='|-le) [[ "$comparison" == "-1" || "$comparison" == "0" ]] ;;
        '='|'=='|-eq) [[ "$comparison" == "0" ]] ;;
        '!='|-ne) [[ "$comparison" != "0" ]] ;;
        '>='|-ge) [[ "$comparison" == "1" || "$comparison" == "0" ]] ;;
        '>'|-gt) [[ "$comparison" == "1" ]] ;;
        *)
            print_error "未知的版本比较操作符: $operator"
            return 1
            ;;
    esac
}

format_dependency_status() {
    local tool_name="$1"
    local available="$2"

    if [[ "$available" == "1" ]]; then
        printf '%s' ""
    else
        printf ' %b' "${DIM}[未安装 ${tool_name}，不可用]${NC}"
    fi
}

require_dependency_or_return() {
    local tool_name="$1"
    local available="$2"

    if [[ "$available" == "1" ]]; then
        return 0
    fi

    print_warn "当前未安装 ${tool_name}，此功能不可用。"
    press_enter_to_continue
    return 1
}

detect_yq_flavor() {
    if [[ "$YQ_AVAILABLE" != "1" ]] || [[ ! -f "${ST_DIR}/config.yaml" ]]; then
        return 1
    fi

    if yq eval '.port' "${ST_DIR}/config.yaml" >/dev/null 2>&1; then
        YQ_FLAVOR="mikefarah"
        return 0
    fi

    if yq -r '.port' "${ST_DIR}/config.yaml" >/dev/null 2>&1; then
        YQ_FLAVOR="kislyuk"
        return 0
    fi

    YQ_FLAVOR=""
    return 1
}

yaml_read() {
    local expr="$1"
    local file="$2"

    case "$YQ_FLAVOR" in
        mikefarah) yq eval -r "$expr" "$file" ;;
        kislyuk) yq -r "$expr" "$file" ;;
        *) return 1 ;;
    esac
}

yaml_write() {
    local expr="$1"
    local file="$2"

    case "$YQ_FLAVOR" in
        mikefarah) yq eval -i "$expr" "$file" ;;
        kislyuk) yq -y -i "$expr" "$file" ;;
        *) return 1 ;;
    esac
}

json_read() {
    local expr="$1"
    local file="$2"
    jq -r "$expr" "$file"
}

json_update_file() {
    local file="$1"
    local expr="$2"
    local temp_file
    temp_file="$(make_temp_next_to "$file")" || return 1

    if jq "$expr" "$file" > "$temp_file"; then
        mv "$temp_file" "$file"
        return 0
    fi

    rm -f "$temp_file"
    return 1
}

insert_line_after_anchor() {
    local file="$1"
    local anchor="$2"
    local inserted_line="$3"
    local temp_file
    temp_file="$(make_temp_next_to "$file")" || return 1

    if awk -v anchor="$anchor" -v inserted_line="$inserted_line" '
        index($0, anchor) && !inserted {
            print
            print inserted_line
            inserted = 1
            next
        }
        { print }
        END { exit inserted ? 0 : 1 }
    ' "$file" > "$temp_file"; then
        mv "$temp_file" "$file"
        return 0
    fi

    rm -f "$temp_file"
    return 1
}

escape_html() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    printf '%s' "$value"
}

choose_windows_start_script() {
    local __resultvar="$1"
    local -a candidates=()
    local resolved_path=""
    local selection=""

    if [[ -z "$__resultvar" ]]; then
        print_error "choose_windows_start_script 缺少结果变量名。"
        return 1
    fi

    if [[ -f "${ST_DIR}/Start.bat" ]]; then
        candidates+=("${ST_DIR}/Start.bat")
    fi

    if [[ -f "${ST_DIR}/start.bat" ]]; then
        if [[ ${#candidates[@]} -eq 0 ]]; then
            candidates+=("${ST_DIR}/start.bat")
        else
            local first_path second_path
            first_path="$(canonical_path "${candidates[0]}")"
            second_path="$(canonical_path "${ST_DIR}/start.bat")"
            if [[ "$first_path" != "$second_path" ]]; then
                candidates+=("${ST_DIR}/start.bat")
            fi
        fi
    fi

    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ ${#candidates[@]} -eq 1 ]]; then
        printf -v "$__resultvar" '%s' "${candidates[0]}"
        return 0
    fi

    print_info "检测到多个 Windows 启动脚本："
    printf '1. %s\n' "${candidates[0]}"
    printf '2. %s\n' "${candidates[1]}"

    while true; do
        prompt_choice "请选择要修改的文件 [1-2]: " selection
        case "$selection" in
            1|2)
                resolved_path="${candidates[$((selection - 1))]}"
                printf -v "$__resultvar" '%s' "$resolved_path"
                return 0
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done
}
