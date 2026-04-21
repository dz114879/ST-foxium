#!/usr/bin/env bash

################################################################################
#  File:  ./foxiumV2/main.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
FOXIUM_ROOT="$SCRIPT_DIR"
if [[ ! -d "$FOXIUM_ROOT/lib" && -d "$SCRIPT_DIR/../lib" ]]; then
    FOXIUM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
fi
cd "$FOXIUM_ROOT" || exit 1
# shellcheck source=./lib/common.sh


################################################################################
#  File:  foxiumV2/./lib/common.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


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
            y | yes) return 0 ;;
            n | no) return 1 ;;
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
    [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 > 0))
}
random_port() {
    printf '%s' "$((10000 + RANDOM % 39152))"
}
is_risky_port() {
    case "$1" in
        20 | 21 | 22 | 23 | 25 | 53 | 80 | 110 | 123 | 143 | 443 | 465 | 587 | 993 | 995 | 1433 | 1521 | 2049 | 2375 | 2376 | 3000 | 3306 | 3389 | 5432 | 5672 | 5900 | 6379 | 8080 | 8443 | 9200)
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
        : >"$temp_file"  || return 1
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
    IFS='.' read -r major minor patch extra <<<"$cleaned"
    printf '%s %s %s' \
        "$(sanitize_version_part "$major")" \
        "$(sanitize_version_part "$minor")" \
        "$(sanitize_version_part "$patch")"
}
compare_versions() {
    local left_major left_minor left_patch
    local right_major right_minor right_patch

    read -r left_major left_minor left_patch <<<"$( parse_version_triplet "$1")"
    read -r right_major right_minor right_patch <<<"$( parse_version_triplet "$2")"

    if ((10#$left_major > 10#$right_major)); then
        printf '%s' "1"
    elif ((10#$left_major < 10#$right_major)); then
        printf '%s' "-1"
    elif ((10#$left_minor > 10#$right_minor)); then
        printf '%s' "1"
    elif ((10#$left_minor < 10#$right_minor)); then
        printf '%s' "-1"
    elif ((10#$left_patch > 10#$right_patch)); then
        printf '%s' "1"
    elif ((10#$left_patch < 10#$right_patch)); then
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
        '<' | -lt) [[ "$comparison" == "-1" ]] ;;
        '<=' | -le) [[ "$comparison" == "-1" || "$comparison" == "0" ]] ;;
        '=' | '==' | -eq) [[ "$comparison" == "0" ]] ;;
        '!=' | -ne) [[ "$comparison" != "0" ]] ;;
        '>=' | -ge) [[ "$comparison" == "1" || "$comparison" == "0" ]] ;;
        '>' | -gt) [[ "$comparison" == "1" ]] ;;
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

    if jq "$expr" "$file" >"$temp_file"; then
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
    ' "$file" >"$temp_file"; then
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
            1 | 2)
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


################################################################################
#  End File:  foxiumV2/./lib/common.sh
################################################################################


# shellcheck source=./lib/backup.sh


################################################################################
#  File:  foxiumV2/./lib/backup.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


init_backup_session() {
    if [[ -z "$BACKUP_ROOT" ]]; then
        print_error "备份根目录尚未初始化。"
        return 1
    fi

    if [[ ! -d "$BACKUP_ROOT" ]]; then
        print_info "创建备份根目录: $BACKUP_ROOT"
        if ! mkdir -p "$BACKUP_ROOT"; then
            print_error "无法创建备份根目录。"
            return 1
        fi
    fi

    local timestamp random_suffix session_name
    timestamp="$(date +"%Y%m%d_%H%M%S")"

    while true; do
        random_suffix="$(printf '%04X' "$((RANDOM % 65536))")"
        session_name="${timestamp}_${random_suffix}"
        BACKUP_SESSION_DIR="${BACKUP_ROOT}/${session_name}"

        if [[ ! -e "$BACKUP_SESSION_DIR" ]]; then
            if mkdir -p "$BACKUP_SESSION_DIR"; then
                print_success "已创建本次备份会话目录: $BACKUP_SESSION_DIR"
                return 0
            fi

            print_error "创建备份会话目录失败。"
            return 1
        fi
    done
}
resolve_backup_destination() {
    local input_path="$1"
    local base_name="$2"
    local candidate_path="${BACKUP_SESSION_DIR}/${base_name}"
    local index=2

    if [[ ! -e "$candidate_path" ]]; then
        printf '%s' "$candidate_path"
        return 0
    fi

    while [[ -e "${BACKUP_SESSION_DIR}/${index}_${base_name}" ]]; do
        ((index++))
    done

    printf '%s' "${BACKUP_SESSION_DIR}/${index}_${base_name}"
}
create_backup() {
    local input_path="$1"

    if [[ -z "$BACKUP_SESSION_DIR" ]]; then
        print_error "备份会话目录尚未准备好。"
        return 1
    fi

    if [[ ! -e "$input_path" ]]; then
        print_warn "源文件或目录不存在，跳过备份: $input_path"
        return 1
    fi

    local base_name destination
    base_name="$(basename "$input_path")"
    destination="$(resolve_backup_destination "$input_path" "$base_name")" || return 1

    if [[ -d "$input_path" ]]; then
        if cp -R "$input_path" "$destination"; then
            print_success "已备份目录: $destination"
            return 0
        fi
    else
        if cp "$input_path" "$destination"; then
            print_success "已备份文件: $destination"
            return 0
        fi
    fi

    print_error "备份失败: $input_path"
    return 1
}


################################################################################
#  End File:  foxiumV2/./lib/backup.sh
################################################################################


# shellcheck source=./lib/detect.sh


################################################################################
#  File:  foxiumV2/./lib/detect.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


declare -a ST_CANDIDATES=()
FOXIUM_JQ_WINDOWS_VERSION="${FOXIUM_JQ_WINDOWS_VERSION:-1.8.1}"
FOXIUM_YQ_WINDOWS_VERSION="${FOXIUM_YQ_WINDOWS_VERSION:-v4.52.5}"
is_valid_st_dir() {
    local candidate="$1"
    [[ -d "$candidate" && -f "${candidate}/server.js" && -f "${candidate}/package.json" ]]
}
add_st_candidate() {
    local candidate="$1"
    local resolved_candidate

    if ! is_valid_st_dir "$candidate"; then
        return 0
    fi

    resolved_candidate="$(canonical_path "$candidate")" || return 0

    local existing
    for existing in "${ST_CANDIDATES[@]}"; do
        if [[ "$existing" == "$resolved_candidate" ]]; then
            return 0
        fi
    done

    ST_CANDIDATES+=("$resolved_candidate")
}
scan_candidate_root() {
    local root="$1"
    local candidate

    [[ -d "$root" ]] || return 0

    add_st_candidate "$root"

    for candidate in \
        "${root}/SillyTavern" \
        "${root}/sillytavern" \
        "${root}/ST" \
        "${root}/st" \
        "${root}"/SillyTavern-*; do
        [[ -e "$candidate" ]] || continue
        add_st_candidate "$candidate"
    done
}
collect_st_candidates() {
    ST_CANDIDATES=()

    scan_candidate_root "$FOXIUM_ROOT"
    scan_candidate_root "$(cd "$FOXIUM_ROOT/.." && pwd -P)"
    scan_candidate_root "$(pwd -P)"
}
prompt_for_st_directory() {
    local user_input resolved_path

    print_warn "未自动找到 SillyTavern 目录。"
    print_info "请输入 SillyTavern 根目录，目录内需要同时包含 server.js 和 package.json。"

    while true; do
        prompt_choice "ST 目录路径: " user_input
        user_input="$(trim_whitespace "$user_input")"

        if [[ -z "$user_input" ]]; then
            print_warn "路径不能为空。"
            continue
        fi

        if [[ -d "$user_input" ]]; then
            resolved_path="$(canonical_path "$user_input")"
        elif [[ -d "${FOXIUM_ROOT}/../${user_input}" ]]; then
            resolved_path="$(canonical_path "${FOXIUM_ROOT}/../${user_input}")"
        else
            print_warn "目录不存在: $user_input"
            continue
        fi

        if is_valid_st_dir "$resolved_path"; then
            ST_DIR="$resolved_path"
            print_success "已设置 ST 目录: $ST_DIR"
            return 0
        fi

        print_warn "该目录不是有效的 SillyTavern 根目录。"
    done
}
select_st_directory() {
    collect_st_candidates

    if [[ ${#ST_CANDIDATES[@]} -eq 1 ]]; then
        ST_DIR="${ST_CANDIDATES[0]}"
        print_success "已找到 ST 目录: $ST_DIR"
        return 0
    fi

    if [[ ${#ST_CANDIDATES[@]} -gt 1 ]]; then
        print_info "找到多个可用的 SillyTavern 目录："
        local index=1
        local candidate
        for candidate in "${ST_CANDIDATES[@]}"; do
            printf '%s. %s\n' "$index" "$candidate"
            ((index++))
        done

        while true; do
            prompt_choice "请选择要使用的目录编号: " selection

            if is_positive_integer "$selection" && ((selection >= 1 && selection <= ${#ST_CANDIDATES[@]})); then
                ST_DIR="${ST_CANDIDATES[$((selection - 1))]}"
                print_success "已设置 ST 目录: $ST_DIR"
                return 0
            fi

            print_warn "无效的选择。"
        done
    fi

    prompt_for_st_directory
}
read_st_version() {
    local package_json="${ST_DIR}/package.json"

    if [[ ! -f "$package_json" ]]; then
        print_warn "未找到 package.json，无法读取 ST 版本。"
        ST_VERSION=""
        return 1
    fi

    if command_exists jq; then
        ST_VERSION="$(jq -r '.version // empty' "$package_json" 2>/dev/null)"
    fi

    if [[ -z "$ST_VERSION" ]]; then
        ST_VERSION="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$package_json" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')"
    fi

    if [[ -n "$ST_VERSION" ]]; then
        print_success "当前 ST 版本: $ST_VERSION"
        return 0
    fi

    print_warn "无法读取 ST 版本。"
    return 1
}
validate_user_name() {
    local value="$1"

    if [[ -z "$value" ]]; then
        return 1
    fi

    if [[ "$value" == *['\/:*?"<>|%!']* ]]; then
        return 1
    fi

    return 0
}
set_user_directory() {
    local input_user

    while true; do
        prompt_choice "请输入酒馆用户名 [默认: default-user]: " input_user
        input_user="$(trim_whitespace "$input_user")"

        if [[ -z "$input_user" ]]; then
            USER_NAME="default-user"
            break
        fi

        if validate_user_name "$input_user"; then
            USER_NAME="$input_user"
            break
        fi

        print_warn "用户名不能包含路径分隔符或 Windows 非法文件名字符。"
    done

    USER_DIR="${ST_DIR}/data/${USER_NAME}"

    if [[ -d "$USER_DIR" ]]; then
        print_success "用户目录: $USER_DIR"
        return 0
    fi

    print_warn "用户目录不存在: $USER_DIR"
    if ask_confirm "是否创建该用户目录？" "y"; then
        if mkdir -p "$USER_DIR"; then
            print_success "已创建用户目录。"
            return 0
        fi

        print_error "创建用户目录失败。"
        return 1
    fi

    print_error "未设置用户目录，脚本无法继续。"
    return 1
}
is_termux_environment() {
    command_exists pkg && [[ -n "${PREFIX:-}" && "$PREFIX" == *com.termux* ]]
}
is_windows_git_bash_environment() {
    case "${OSTYPE:-}" in
        msys* | cygwin*)
            return 0
            ;;
    esac

    case "${MSYSTEM:-}" in
        MINGW* | UCRT* | CLANG*)
            return 0
            ;;
    esac

    return 1
}
ensure_windows_user_bin_in_path() {
    local user_bin

    if [[ -z "${HOME:-}" ]]; then
        return 1
    fi

    user_bin="${HOME}/bin"
    mkdir -p "$user_bin" || return 1

    case ":$PATH:" in
        *":$user_bin:"*) ;;

        *)
            PATH="$user_bin:$PATH"
            ;;
    esac

    return 0
}
resolve_windows_git_bash_arch() {
    local machine_arch
    machine_arch="$(uname -m 2>/dev/null || printf '%s' '')"

    case "$machine_arch" in
        x86_64 | amd64)
            printf '%s' "amd64"
            ;;
        i686 | i386)
            printf '%s' "386"
            ;;
        *)
            print_warn "当前 Windows Git Bash 架构为 ${machine_arch:-未知}，Foxium 目前仅支持 x86_64/amd64 或 i686/i386 的自动安装。"
            return 1
            ;;
    esac
}
windows_git_bash_download_url() {
    local tool_name="$1"
    local tool_arch="$2"

    case "${tool_name}:${tool_arch}" in
        jq:amd64)
            printf '%s' "https://github.com/jqlang/jq/releases/download/jq-${FOXIUM_JQ_WINDOWS_VERSION}/jq-windows-amd64.exe"
            ;;
        jq:386)
            printf '%s' "https://github.com/jqlang/jq/releases/download/jq-${FOXIUM_JQ_WINDOWS_VERSION}/jq-windows-i386.exe"
            ;;
        yq:amd64)
            printf '%s' "https://github.com/mikefarah/yq/releases/download/${FOXIUM_YQ_WINDOWS_VERSION}/yq_windows_amd64.exe"
            ;;
        yq:386)
            printf '%s' "https://github.com/mikefarah/yq/releases/download/${FOXIUM_YQ_WINDOWS_VERSION}/yq_windows_386.exe"
            ;;
        *)
            return 1
            ;;
    esac
}
install_windows_git_bash_tool() {
    local tool_name="$1"
    local tool_arch download_url user_bin target_path temp_file

    if ! is_windows_git_bash_environment; then
        return 1
    fi

    if ! command_exists curl; then
        print_warn "当前 Git Bash 未找到 curl，无法自动安装 ${tool_name}。"
        return 1
    fi

    if ! ensure_windows_user_bin_in_path; then
        print_warn "无法准备 Git Bash 的用户 bin 目录。"
        return 1
    fi

    tool_arch="$(resolve_windows_git_bash_arch)" || return 1
    download_url="$(windows_git_bash_download_url "$tool_name" "$tool_arch")" || {
        print_warn "未找到 ${tool_name} 对应的 Windows 下载地址。"
        return 1
    }

    user_bin="${HOME}/bin"
    target_path="${user_bin}/${tool_name}.exe"
    temp_file="$(make_temp_next_to "$target_path")" || {
        print_warn "无法创建 ${tool_name} 安装临时文件。"
        return 1
    }

    print_info "检测到 Windows Git Bash，将安装 ${tool_name} 到 ${user_bin}。"
    if curl -fL --retry 3 --connect-timeout 15 "$download_url" -o "$temp_file"; then
        if mv "$temp_file" "$target_path"; then
            chmod +x "$target_path" >/dev/null 2>&1 || true
            hash -r

            if command_exists "$tool_name"; then
                print_success "${tool_name} 安装完成：$target_path"
                return 0
            fi

            if [[ -f "$target_path" ]]; then
                print_success "${tool_name} 已下载到：$target_path"
                print_warn "当前会话未立即识别该命令，请重新打开 Git Bash 后再运行脚本。"
                return 0
            fi
        fi
    fi

    rm -f "$temp_file"
    print_warn "${tool_name} 安装失败，将继续以不可用状态运行。"
    return 1
}
detect_optional_tool() {
    local tool_name="$1"
    local __resultvar="$2"
    printf -v "$__resultvar" '%s' "0"

    if is_windows_git_bash_environment; then
        ensure_windows_user_bin_in_path >/dev/null 2>&1 || true
    fi

    if command_exists "$tool_name"; then
        printf -v "$__resultvar" '%s' "1"
        print_success "已检测到 ${tool_name}"
        return 0
    fi

    print_warn "未检测到 ${tool_name}"

    if is_termux_environment; then
        if ask_confirm "是否尝试自动安装 ${tool_name}？" "y"; then
            if pkg install -y "$tool_name"; then
                if command_exists "$tool_name"; then
                    printf -v "$__resultvar" '%s' "1"
                    print_success "${tool_name} 安装完成。"
                    return 0
                fi
            fi
            print_warn "${tool_name} 安装失败，将继续以不可用状态运行。"
        fi
    elif is_windows_git_bash_environment; then
        print_info "当前环境是 Windows Git Bash，可将 ${tool_name} 安装到 \$HOME/bin（通常对应 C:\\Users\\当前用户名\\bin）。"
        if ask_confirm "是否尝试自动安装 ${tool_name}？" "y"; then
            if install_windows_git_bash_tool "$tool_name"; then
                printf -v "$__resultvar" '%s' "1"
                return 0
            fi
        fi
    else
        print_info "当前环境不是 Termux。请手动安装 ${tool_name} 后重新运行脚本。"
    fi

    return 1
}
detect_optional_tools() {
    detect_optional_tool "jq" JQ_AVAILABLE
    detect_optional_tool "yq" YQ_AVAILABLE

    if [[ "$YQ_AVAILABLE" == "1" ]] && ! detect_yq_flavor; then
        print_warn "检测到 yq，但无法识别其用法，config.yaml 编辑器将保持不可用。"
        YQ_AVAILABLE="0"
    fi
}
run_startup_checks() {
    print_title "Foxium V2 启动检查"

    if ! select_st_directory; then
        print_error "无法定位 SillyTavern 目录。"
        exit 1
    fi

    if is_windows_git_bash_environment; then
        ensure_windows_user_bin_in_path >/dev/null 2>&1 || true
    fi

    read_st_version

    BACKUP_ROOT="${FOXIUM_ROOT}/STbackupF"
    if ! init_backup_session; then
        print_error "无法初始化备份系统。"
        exit 1
    fi

    if ! set_user_directory; then
        exit 1
    fi

    detect_optional_tools

    print_success "启动检查完成。"
    print_info "ST 目录: $ST_DIR"
    print_info "用户目录: $USER_DIR"
    print_info "本次备份目录: $BACKUP_SESSION_DIR"
    print_info "jq: $([[ "$JQ_AVAILABLE" == "1" ]] && printf '%s' '可用' || printf '%s' '不可用')"
    print_info "yq: $([[ "$YQ_AVAILABLE" == "1" ]] && printf '%s' '可用' || printf '%s' '不可用')"
    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/detect.sh
################################################################################


# shellcheck source=./lib/npm_fix.sh


################################################################################
#  File:  foxiumV2/./lib/npm_fix.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


fix_npm_install() {
    print_title "修复 node 包问题"
    print_info "此功能会删除 node_modules，然后使用淘宝镜像重新执行 npm install。"

    if ! command_exists npm; then
        print_error "当前环境未找到 npm，无法执行该功能。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认执行此操作吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    if (
        cd "$ST_DIR" || exit 1

        if [[ -d "node_modules" ]]; then
            print_info "删除 node_modules..."
            rm -rf "node_modules"
        fi

        print_info "使用淘宝镜像重新安装依赖..."
        npm install --registry=https://registry.npmmirror.com
    ); then
        print_success "依赖已重新安装完成。"
    else
        print_error "重新安装依赖失败。"
    fi

    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/npm_fix.sh
################################################################################


# shellcheck source=./lib/extension_fix.sh


################################################################################
#  File:  foxiumV2/./lib/extension_fix.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


fix_extension_uninstall() {
    print_title "强制删除扩展"
    print_info "此功能会列出当前用户扩展和第三方扩展，选择后先备份再删除。"

    local user_ext_dir="${USER_DIR}/extensions"
    local third_party_dir="${ST_DIR}/public/scripts/extensions/third-party"
    local -a extension_names=()
    local -a extension_paths=()
    local index=1

    printf '%s\n\n' "已安装的扩展："

    local old_nullglob
    old_nullglob="$(shopt -p nullglob)"
    shopt -s nullglob

    if [[ -d "$user_ext_dir" ]]; then
        printf '%s\n' "[为当前用户安装的扩展]"
        local ext_path
        for ext_path in "${user_ext_dir}"/*; do
            [[ -d "$ext_path" ]] || continue
            extension_names[index]="$(basename "$ext_path")"
            extension_paths[index]="$ext_path"
            printf '  %s. %s\n' "$index" "${extension_names[index]}"
            ((index++))
        done
        printf '\n'
    fi

    if [[ -d "$third_party_dir" ]]; then
        printf '%s\n' "[为所有用户安装的第三方扩展]"
        local ext_path
        for ext_path in "${third_party_dir}"/*; do
            [[ -d "$ext_path" ]] || continue
            extension_names[index]="$(basename "$ext_path")"
            extension_paths[index]="$ext_path"
            printf '  %s. %s\n' "$index" "${extension_names[index]}"
            ((index++))
        done
        printf '\n'
    fi

    eval "$old_nullglob"

    if [[ ${#extension_names[@]} -eq 0 ]]; then
        print_info "未找到可删除的扩展。"
        press_enter_to_continue
        return
    fi

    printf '%s\n\n' "0. 返回"
    prompt_choice "请选择要删除的扩展编号: " selection

    if [[ "$selection" == "0" ]]; then
        return
    fi

    if ! is_positive_integer "$selection" || [[ -z "${extension_paths[$selection]:-}" ]]; then
        print_warn "无效的选择。"
        press_enter_to_continue
        return
    fi

    print_warn "即将删除扩展：${extension_names[$selection]}"
    print_info "路径：${extension_paths[$selection]}"

    if ! ask_confirm "确认删除这个扩展吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    create_backup "${extension_paths[$selection]}"
    if rm -rf "${extension_paths[$selection]}"; then
        print_success "扩展已删除：${extension_names[$selection]}"
    else
        print_error "删除扩展失败。"
    fi

    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/extension_fix.sh
################################################################################


# shellcheck source=./lib/never_oom.sh


################################################################################
#  File:  foxiumV2/./lib/never_oom.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


patch_expired_interval_setting() {
    local target_file="$1"
    local anchor="$2"
    local inserted_line="$3"

    if [[ ! -f "$target_file" ]]; then
        print_warn "文件不存在，跳过：$target_file"
        return 1
    fi

    if awk -v anchor="$anchor" -v inserted_line="$inserted_line" '
        index($0, anchor) { in_block = 1 }
        in_block && index($0, inserted_line) { found = 1 }
        in_block && $0 ~ /^[[:space:]]*}/ { in_block = 0 }
        END { exit found ? 0 : 1 }
    ' "$target_file"; then
        print_warn "$(basename "$target_file") 已包含 expiredInterval 配置，跳过。"
        return 0
    fi

    create_backup "$target_file"
    if insert_line_after_anchor "$target_file" "$anchor" "$inserted_line"; then
        print_success "已修改 $(basename "$target_file")"
        return 0
    fi

    print_warn "未找到锚点，无法修改 $(basename "$target_file")"
    return 1
}
update_start_script_memory_limit() {
    local start_file="$1"
    local memory_size="${2:-4096}"
    local temp_file

    if [[ ! -f "$start_file" ]]; then
        print_error "启动脚本不存在：$start_file"
        return 1
    fi

    if grep -Fq -- "--max-old-space-size=${memory_size}" "$start_file"; then
        print_warn "启动脚本已经设置为 ${memory_size}MB。"
        return 0
    fi

    temp_file="$(make_temp_next_to "$start_file")" || return 1
    create_backup "$start_file"

    if awk -v memory_size="$memory_size" '
        {
            line = $0
            if (!updated && $0 ~ /node/ && $0 ~ /server\.js/) {
                if ($0 ~ /--max-old-space-size=[0-9]+/) {
                    sub(/--max-old-space-size=[0-9]+/, "--max-old-space-size=" memory_size, line)
                } else {
                    sub(/node[[:space:]]+/, "node --max-old-space-size=" memory_size " ", line)
                }
                updated = 1
            }
            print line
        }
        END { exit updated ? 0 : 1 }
    ' "$start_file" >"$temp_file"; then
        mv "$temp_file" "$start_file"
        print_success "已把启动脚本内存限制设置为 ${memory_size}MB"
        return 0
    fi

    rm -f "$temp_file"
    print_error "未找到 node server.js 启动行，修改失败。"
    return 1
}
never_oom() {
    print_title "二合一爆内存修复"
    print_info "此功能会尝试完成两步："
    printf '%s\n' "1. 对旧版本 ST 的 users.js 和 characters.js 加入 expiredInterval: 0"
    printf '%s\n' "2. 为启动脚本增加 --max-old-space-size=4096"

    if ! ask_confirm "确认执行该修复吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    print_title "[1/2] 修复旧版本缓存过期扫描"
    local should_patch_storage="1"
    if [[ -n "$ST_VERSION" ]] && check_st_version ">=" 1 13 5; then
        should_patch_storage="0"
        print_info "当前 ST 版本为 ${ST_VERSION}，官方已包含该修复，跳过源码补丁。"
    fi

    if [[ "$should_patch_storage" == "1" ]]; then
        patch_expired_interval_setting "${ST_DIR}/src/users.js" "ttl: false, // Never expire" "        expiredInterval: 0,"
        patch_expired_interval_setting "${ST_DIR}/src/endpoints/characters.js" "forgiveParseErrors: true," "            expiredInterval: 0,"
    fi

    print_title "[2/2] 提高启动脚本内存上限"
    printf '%s\n' "1. Termux / Linux (修改 start.sh)"
    printf '%s\n' "2. Windows (修改 Start.bat 或 start.bat)"
    printf '%s\n' "0. 跳过此步骤"

    local env_choice start_file
    while true; do
        prompt_choice "请选择 [0-2]: " env_choice
        case "$env_choice" in
            1)
                start_file="${ST_DIR}/start.sh"
                update_start_script_memory_limit "$start_file" 4096
                break
                ;;
            2)
                if ! choose_windows_start_script start_file; then
                    print_error "未找到可用的 Windows 启动脚本。"
            else
                    update_start_script_memory_limit "$start_file" 4096
            fi
                break
                ;;
            0)
                print_info "已跳过启动脚本内存限制修改。"
                break
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done

    print_success "Never OOM 修复流程已结束。"
    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/never_oom.sh
################################################################################


# shellcheck source=./lib/gemini_media.sh


################################################################################
#  File:  foxiumV2/./lib/gemini_media.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


array_contains_model() {
    local target_file="$1"
    local anchor="$2"
    local model_prefix="$3"

    awk -v anchor="$anchor" -v model_prefix="$model_prefix" '
        index($0, anchor) { in_block = 1 }
        in_block && index($0, model_prefix) { found = 1 }
        in_block && /\];/ { in_block = 0 }
        END { exit found ? 0 : 1 }
    ' "$target_file"
}
fix_gemini3_media() {
    print_title "允许给 Gemini 3 系列模型发图"
    print_risk "此功能会直接修改 public/scripts/openai.js。"

    if [[ -n "$ST_VERSION" ]] && check_st_version ">" 1 13 999; then
        print_info "当前 ST 版本为 ${ST_VERSION}，已经不需要使用此功能。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认执行此风险操作吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    local openai_js="${ST_DIR}/public/scripts/openai.js"
    if [[ ! -f "$openai_js" ]]; then
        print_error "未找到 openai.js: $openai_js"
        press_enter_to_continue
        return
    fi

    local modified=0
    if ! array_contains_model "$openai_js" "const visionSupportedModels = [" "'gemini-3'"; then
        create_backup "$openai_js"
        if insert_line_after_anchor "$openai_js" "const visionSupportedModels = [" "        'gemini-3',"; then
            print_success "已把 gemini-3 加入 visionSupportedModels"
            modified=1
        else
            print_warn "未找到 visionSupportedModels 插入点。"
        fi
    else
        print_warn "visionSupportedModels 已包含 gemini-3，跳过。"
    fi

    if ! array_contains_model "$openai_js" "const videoSupportedModels = [" "'gemini-3'"; then
        if ((modified == 0)); then
            create_backup "$openai_js"
        fi
        if insert_line_after_anchor "$openai_js" "const videoSupportedModels = [" "        'gemini-3',"; then
            print_success "已把 gemini-3 加入 videoSupportedModels"
            modified=1
        else
            print_warn "未找到 videoSupportedModels 插入点。"
        fi
    else
        print_warn "videoSupportedModels 已包含 gemini-3，跳过。"
    fi

    if ((modified > 0)); then
        print_success "Gemini 3 媒体支持修复完成。"
    else
        print_info "没有新的内容需要写入。"
    fi

    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/gemini_media.sh
################################################################################


# shellcheck source=./lib/config_editor.sh


################################################################################
#  File:  foxiumV2/./lib/config_editor.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


show_config_editor_menu() {
    clear_screen
    print_title "config.yaml 编辑器"
    printf '%s\n' "1. 修改服务器端口 (port)"
    printf '%s\n' "2. 修改备份保留数量 (numberOfBackups)"
    printf '%s\n' "3. 开关自动启动浏览器 (browserLaunch.enabled)"
    printf '%s\n' "4. 配置代理 (requestProxy)"
    printf '%s\n' "5. [危险] 禁用 CSRF 保护 (disableCsrfProtection)"
    printf '%s\n' "6. 开关懒加载角色 (lazyLoadCharacters)"
    printf '%s\n' "7. [危险] 启用服务器插件 (enableServerPlugins)"
    printf '\n'
    printf '%s\n' "0. 返回上级"
    printf '\n'
}
config_editor_file() {
    printf '%s' "${ST_DIR}/config.yaml"
}
backup_config_editor_file() {
    local config_file
    config_file="$(config_editor_file)"
    create_backup "$config_file"
}
toggle_config_boolean() {
    local yaml_path="$1"
    local label="$2"
    local danger_message="${3:-}"
    local config_file current_value next_value
    config_file="$(config_editor_file)"
    current_value="$(to_lower "$(yaml_read "$yaml_path" "$config_file" 2>/dev/null)")"

    if [[ "$current_value" != "true" && "$current_value" != "false" ]]; then
        print_warn "无法读取当前值，默认按 false 处理。"
        current_value="false"
    fi

    next_value="true"
    if [[ "$current_value" == "true" ]]; then
        next_value="false"
    fi

    print_info "当前 ${label}: ${current_value}"
    if [[ -n "$danger_message" ]]; then
        print_risk "$danger_message"
    fi

    if ! ask_confirm "确认将 ${label} 切换为 ${next_value} 吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    backup_config_editor_file
    if yaml_write "${yaml_path} = ${next_value}" "$config_file"; then
        print_success "${label} 已切换为 ${next_value}"
    else
        print_error "修改 ${label} 失败。"
    fi

    press_enter_to_continue
}
config_edit_port() {
    local config_file current_port mode new_port
    config_file="$(config_editor_file)"
    current_port="$(yaml_read '.port' "$config_file" 2>/dev/null)"

    print_info "当前服务器端口: ${current_port:-未知}"
    printf '%s\n' "1. 生成随机端口（推荐）"
    printf '%s\n' "2. 手动输入端口"
    printf '%s\n' "0. 返回"

    while true; do
        prompt_choice "请选择 [0-2]: " mode
        case "$mode" in
            1)
                new_port="$(random_port)"
                print_info "已生成随机端口: $new_port"
                break
                ;;
            2)
                prompt_choice "请输入端口号 [推荐 10000-49151]: " new_port
                new_port="$(trim_whitespace "$new_port")"

                if ! is_positive_integer "$new_port" || ((10#$new_port < 1 || 10#$new_port > 65535)); then
                    print_warn "端口必须是 1-65535 的整数。"
                    continue
            fi
                break
                ;;
            0)
                return
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done

    if is_risky_port "$new_port"; then
        print_warn "该端口属于常见高风险/常用服务端口，请确认没有冲突。"
    fi

    if [[ "$new_port" == "$current_port" ]]; then
        print_warn "新端口与当前端口相同，无需修改。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认将端口修改为 ${new_port} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    backup_config_editor_file
    if yaml_write ".port = ${new_port}" "$config_file"; then
        print_success "端口已修改为 ${new_port}"
    else
        print_error "端口修改失败。"
    fi

    press_enter_to_continue
}
config_edit_backup_count() {
    local config_file current_count input_count new_count
    config_file="$(config_editor_file)"
    current_count="$(yaml_read '.backups.common.numberOfBackups' "$config_file" 2>/dev/null)"

    print_info "当前备份保留数量: ${current_count:-未知}"
    prompt_choice "请输入新的备份保留数量 [默认: 3]: " input_count
    input_count="$(trim_whitespace "$input_count")"
    new_count="${input_count:-3}"

    if ! is_positive_integer "$new_count"; then
        print_warn "备份保留数量必须是正整数。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认将备份保留数量修改为 ${new_count} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    backup_config_editor_file
    if yaml_write ".backups.common.numberOfBackups = ${new_count}" "$config_file"; then
        print_success "备份保留数量已修改为 ${new_count}"
    else
        print_error "备份保留数量修改失败。"
    fi

    press_enter_to_continue
}
config_toggle_browser_launch() {
    toggle_config_boolean '.browserLaunch.enabled' '自动启动浏览器'
}
config_configure_proxy() {
    local config_file current_enabled current_url mode proxy_url escaped_url
    config_file="$(config_editor_file)"
    current_enabled="$(to_lower "$(yaml_read '.requestProxy.enabled' "$config_file" 2>/dev/null)")"
    current_url="$(yaml_read '.requestProxy.url' "$config_file" 2>/dev/null)"

    print_info "当前代理开关: ${current_enabled:-未知}"
    print_info "当前代理地址: ${current_url:-未设置}"
    print_info "提示：Termux 用户通常不需要在这里额外开启代理。"
    printf '%s\n' "1. 开启并设置代理"
    printf '%s\n' "2. 关闭代理"
    printf '%s\n' "0. 返回"

    while true; do
        prompt_choice "请选择 [0-2]: " mode
        case "$mode" in
            1)
                prompt_choice "请输入代理 URL: " proxy_url
                proxy_url="$(trim_whitespace "$proxy_url")"
                if [[ -z "$proxy_url" ]]; then
                    print_warn "代理 URL 不能为空。"
                    continue
            fi

                escaped_url="${proxy_url//\\/\\\\}"
                escaped_url="${escaped_url//\"/\\\"}"

                if ! ask_confirm "确认启用代理并写入该 URL 吗？" "y"; then
                    print_info "操作已取消。"
                    press_enter_to_continue
                    return
            fi

                backup_config_editor_file
                if yaml_write ".requestProxy.enabled = true | .requestProxy.url = \"${escaped_url}\"" "$config_file"; then
                    print_success "代理配置已更新。"
            else
                    print_error "代理配置更新失败。"
            fi

                press_enter_to_continue
                return
                ;;
            2)
                if ! ask_confirm "确认关闭代理吗？" "y"; then
                    print_info "操作已取消。"
                    press_enter_to_continue
                    return
            fi

                backup_config_editor_file
                if yaml_write '.requestProxy.enabled = false' "$config_file"; then
                    print_success "代理已关闭。"
            else
                    print_error "关闭代理失败。"
            fi

                press_enter_to_continue
                return
                ;;
            0)
                return
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done
}
config_toggle_disable_csrf() {
    toggle_config_boolean '.disableCsrfProtection' '禁用 CSRF 保护' '关闭 CSRF 保护会降低安全性，只建议在你明确知道风险时使用。'
}
config_toggle_lazy_load() {
    toggle_config_boolean '.performance.lazyLoadCharacters' '懒加载角色'
}
config_toggle_server_plugins() {
    toggle_config_boolean '.enableServerPlugins' '服务器插件' '启用服务器插件会扩大服务端代码执行面，请确认插件来源可信。'
}
config_editor_menu() {
    if ! require_dependency_or_return "yq" "$YQ_AVAILABLE"; then
        return
    fi

    local config_file
    config_file="$(config_editor_file)"
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到 config.yaml: $config_file"
        press_enter_to_continue
        return
    fi

    while true; do
        show_config_editor_menu
        prompt_choice "请输入选项 [0-7]: " choice

        case "$choice" in
            1) config_edit_port ;;
            2) config_edit_backup_count ;;
            3) config_toggle_browser_launch ;;
            4) config_configure_proxy ;;
            5) config_toggle_disable_csrf ;;
            6) config_toggle_lazy_load ;;
            7) config_toggle_server_plugins ;;
            0) return ;;
            *)
                print_warn "无效的选项。"
                press_enter_to_continue
                ;;
        esac
    done
}


################################################################################
#  End File:  foxiumV2/./lib/config_editor.sh
################################################################################


# shellcheck source=./lib/settings_editor.sh


################################################################################
#  File:  foxiumV2/./lib/settings_editor.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


show_settings_editor_menu() {
    clear_screen
    print_title "settings.json 编辑器"
    printf '%s\n' "1. 重置主题为 Dark Lite（修复美化卡死）"
    printf '%s\n' "2. 清空自定义 CSS（修复 CSS 导致设置按钮消失）"
    printf '%s\n' "3. 关闭自动加载聊天（修复聊天加载卡死）"
    printf '\n'
    printf '%s\n' "0. 返回上级"
    printf '\n'
}
settings_file_path() {
    printf '%s' "${USER_DIR}/settings.json"
}
apply_settings_change() {
    local description="$1"
    local jq_expr="$2"
    local settings_file
    settings_file="$(settings_file_path)"

    if [[ ! -f "$settings_file" ]]; then
        print_error "未找到 settings.json: $settings_file"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认执行“${description}”吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    create_backup "$settings_file"
    if json_update_file "$settings_file" "$jq_expr"; then
        print_success "${description} 已完成。"
    else
        print_error "${description} 失败。"
    fi

    press_enter_to_continue
}
settings_editor_menu() {
    if ! require_dependency_or_return "jq" "$JQ_AVAILABLE"; then
        return
    fi

    while true; do
        show_settings_editor_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) apply_settings_change "重置主题为 Dark Lite" '.theme = "Dark Lite"' ;;
            2) apply_settings_change "清空自定义 CSS" '.custom_css = ""' ;;
            3) apply_settings_change "关闭自动加载聊天" '.auto_load_chat = false' ;;
            0) return ;;
            *)
                print_warn "无效的选项。"
                press_enter_to_continue
                ;;
        esac
    done
}


################################################################################
#  End File:  foxiumV2/./lib/settings_editor.sh
################################################################################


# shellcheck source=./lib/model_editor.sh


################################################################################
#  File:  foxiumV2/./lib/model_editor.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


show_model_editor_menu() {
    clear_screen
    print_title "Claude/Gemini 模型列表修改器"
    printf '%s\n' "1. 添加模型"
    printf '%s\n' "2. 查看已添加的自定义模型"
    printf '%s\n' "3. 删除已添加的自定义模型"
    printf '\n'
    printf '%s\n' "0. 返回上级"
    printf '\n'
}
model_editor_file() {
    printf '%s' "${ST_DIR}/public/index.html"
}
resolve_model_target() {
    local model_id_lower
    model_id_lower="$(to_lower "$1")"

    case "$model_id_lower" in
        claude* | neptune*)
            printf '%s' "model_claude_select"
            ;;
        gemini* | gemma*)
            printf '%s' "model_google_select"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}
prompt_model_target() {
    while true; do
        printf '%s\n' "1. Claude / Neptune"
        printf '%s\n' "2. Gemini / Gemma"
        printf '\n'
        prompt_choice "请选择目标下拉框 [1-2]: " selection

        case "$selection" in
            1)
                printf '%s' "model_claude_select"
                return 0
                ;;
            2)
                printf '%s' "model_google_select"
                return 0
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done
}
collect_custom_models() {
    local index_file
    index_file="$(model_editor_file)"

    awk '
        /<select id="model_claude_select">/ { current = "model_claude_select" }
        /<select id="model_google_select">/ { current = "model_google_select" }
        /<\/select>/ { current = "" }
        /foxium-custom/ {
            value = ""
            label = ""
            if (match($0, /value="[^"]+"/)) {
                value = substr($0, RSTART + 7, RLENGTH - 8)
            }
            if (match($0, />[^<]*<\/option>/)) {
                label = substr($0, RSTART + 1, RLENGTH - 10)
            }
            gsub(/&quot;/, "\"", label)
            gsub(/&gt;/, ">", label)
            gsub(/&lt;/, "<", label)
            gsub(/&amp;/, "\\&", label)
            if (current != "" && value != "") {
                printf "%s\t%s\t%s\n", current, value, label
            }
        }
    ' "$index_file"
}
list_custom_models() {
    local -a entries=()
    mapfile -t entries < <(collect_custom_models)

    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "当前没有由 Foxium 添加的自定义模型。"
        return 1
    fi

    local index=1 target_label target_id model_id display_name
    for entry in "${entries[@]}"; do
        IFS=$'\t' read -r target_id model_id display_name <<<"$entry"
        if [[ "$target_id" == "model_claude_select" ]]; then
            target_label="Claude/Neptune"
        else
            target_label="Gemini/Gemma"
        fi

        printf '%s. [%s] %s -> %s\n' "$index" "$target_label" "$model_id" "$display_name"
        ((index++))
    done

    return 0
}
add_custom_model() {
    local index_file model_id display_name target_select escaped_model_id escaped_display_name
    index_file="$(model_editor_file)"

    if [[ ! -f "$index_file" ]]; then
        print_error "未找到 index.html: $index_file"
        press_enter_to_continue
        return
    fi

    prompt_choice "请输入模型 ID: " model_id
    model_id="$(trim_whitespace "$model_id")"
    if [[ -z "$model_id" ]]; then
        print_warn "模型 ID 不能为空。"
        press_enter_to_continue
        return
    fi

    if [[ "$model_id" == *['"<>']* ]]; then
        print_warn "模型 ID 不能包含双引号、< 或 >。"
        press_enter_to_continue
        return
    fi

    prompt_choice "请输入显示名称 [默认与模型 ID 相同]: " display_name
    display_name="$(trim_whitespace "$display_name")"
    if [[ -z "$display_name" ]]; then
        display_name="$model_id"
    fi

    target_select="$(resolve_model_target "$model_id")"
    if [[ -z "$target_select" ]]; then
        target_select="$(prompt_model_target)"
    fi

    if grep -Fq "value=\"${model_id}\"" "$index_file"; then
        print_warn "index.html 中已存在相同的模型 ID：${model_id}"
        press_enter_to_continue
        return
    fi

    escaped_model_id="$(escape_html "$model_id")"
    escaped_display_name="$(escape_html "$display_name")"

    local inserted_line='                                    <!-- foxium-custom --><option value="'"${escaped_model_id}"'">'"${escaped_display_name}"'</option>'
    local temp_file
    temp_file="$(make_temp_next_to "$index_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    create_backup "$index_file"
    if awk -v target_select="$target_select" -v inserted_line="$inserted_line" '
        index($0, "<select id=\"" target_select "\">") {
            in_target = 1
            print
            next
        }
        in_target && $0 ~ /<optgroup[^>]*>/ && !inserted {
            print
            print inserted_line
            inserted = 1
            in_target = 0
            next
        }
        { print }
        END { exit inserted ? 0 : 1 }
    ' "$index_file" >"$temp_file"; then
        mv "$temp_file" "$index_file"
        print_success "已添加自定义模型：${model_id}"
    else
        rm -f "$temp_file"
        print_error "添加模型失败，未找到目标下拉框或插入点。"
    fi

    press_enter_to_continue
}
view_custom_models() {
    if ! list_custom_models; then
        press_enter_to_continue
        return
    fi

    press_enter_to_continue
}
delete_custom_model() {
    local -a entries=()
    local selection target_id model_id display_name
    local index_file temp_file
    index_file="$(model_editor_file)"

    mapfile -t entries < <(collect_custom_models)
    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "当前没有可删除的自定义模型。"
        press_enter_to_continue
        return
    fi

    list_custom_models
    printf '\n'
    prompt_choice "请选择要删除的编号 [0-$((${#entries[@]}))]: " selection

    if [[ "$selection" == "0" ]]; then
        return
    fi

    if ! is_positive_integer "$selection" || ((selection < 1 || selection > ${#entries[@]})); then
        print_warn "无效的编号。"
        press_enter_to_continue
        return
    fi

    IFS=$'\t' read -r target_id model_id display_name <<<"${entries[$((selection - 1))]}"

    if ! ask_confirm "确认删除自定义模型 ${model_id} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    temp_file="$(make_temp_next_to "$index_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    create_backup "$index_file"
    if awk -v target_select="$target_id" -v model_id="$model_id" '
        index($0, "<select id=\"" target_select "\">") { in_target = 1 }
        in_target && /<\/select>/ { in_target = 0 }
        in_target && /foxium-custom/ && index($0, "value=\"" model_id "\"") {
            removed = 1
            next
        }
        { print }
        END { exit removed ? 0 : 1 }
    ' "$index_file" >"$temp_file"; then
        mv "$temp_file" "$index_file"
        print_success "已删除自定义模型：${model_id}"
    else
        rm -f "$temp_file"
        print_error "删除失败，未找到对应的自定义模型。"
    fi

    press_enter_to_continue
}
model_editor_menu() {
    while true; do
        show_model_editor_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) add_custom_model ;;
            2) view_custom_models ;;
            3) delete_custom_model ;;
            0) return ;;
            *)
                print_warn "无效的选项。"
                press_enter_to_continue
                ;;
        esac
    done
}


################################################################################
#  End File:  foxiumV2/./lib/model_editor.sh
################################################################################


# shellcheck source=./lib/chat_limit.sh


################################################################################
#  File:  foxiumV2/./lib/chat_limit.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


remove_chat_size_limit() {
    print_title "解除聊天文件大小限制"
    print_info "此功能会把 src/server-main.js 中 bodyParser 的大小限制改为 1024mb。"

    local server_main="${ST_DIR}/src/server-main.js"
    if [[ ! -f "$server_main" ]]; then
        print_error "未找到 server-main.js: $server_main"
        press_enter_to_continue
        return
    fi

    local current_json current_urlencoded
    current_json="$(grep -oE "bodyParser\.json\(\{ limit: '[^']+'" "$server_main" | head -n 1 | grep -oE "'[^']+'" | tr -d "'" 2>/dev/null)"
    current_urlencoded="$(grep -oE "bodyParser\.urlencoded\(\{ extended: true, limit: '[^']+'" "$server_main" | head -n 1 | grep -oE "'[^']+'" | tr -d "'" 2>/dev/null)"
    print_info "当前 JSON 限制: ${current_json:-未知}"
    print_info "当前 URL-encoded 限制: ${current_urlencoded:-未知}"

    if ! ask_confirm "确认修改为 1024mb 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    local temp_file
    temp_file="$(make_temp_next_to "$server_main")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    create_backup "$server_main"
    if awk '
        {
            line = $0
            if ($0 ~ /app\.use\(bodyParser\.json\(\{ limit: /) {
                sub(/limit: '\''[^'\'']*'\''/, "limit: '\''1024mb'\''", line)
                changed_json = 1
            }
            if ($0 ~ /app\.use\(bodyParser\.urlencoded\(\{ extended: true, limit: /) {
                sub(/limit: '\''[^'\'']*'\''/, "limit: '\''1024mb'\''", line)
                changed_urlencoded = 1
            }
            print line
        }
        END { exit (changed_json && changed_urlencoded) ? 0 : 1 }
    ' "$server_main" >"$temp_file"; then
        mv "$temp_file" "$server_main"
        print_success "聊天文件大小限制已修改为 1024mb。"
    else
        rm -f "$temp_file"
        print_error "未找到完整的 bodyParser 限制配置，修改失败。"
    fi

    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/chat_limit.sh
################################################################################


# shellcheck source=./lib/auto_backup.sh


################################################################################
#  File:  foxiumV2/./lib/auto_backup.sh
#  Bundle Date: 2026-04-21 11:31:49
################################################################################


write_shell_auto_backup_block() {
    local output_file="$1"
    local escaped_user="$2"

    cat >"$output_file"  <<EOF
# === FOXIUM AUTO BACKUP START ===
FOXIUM_USER="${escaped_user}"
FOXIUM_BACKUP_PARENT_DIR="\$(cd "\$(dirname "\$0")" && pwd)/foxiumV2/STbackupF"
FOXIUM_BACKUP_TIMESTAMP="\$(date +"%Y%m%d_%H%M%S")"
FOXIUM_BACKUP_DIR="\${FOXIUM_BACKUP_PARENT_DIR}/auto_backup_\${FOXIUM_BACKUP_TIMESTAMP}"

mkdir -p "\$FOXIUM_BACKUP_PARENT_DIR"
for foxium_existing_dir in "\$FOXIUM_BACKUP_PARENT_DIR"/auto_backup_*; do
    [[ -e "\$foxium_existing_dir" ]] || continue
    rm -rf "\$foxium_existing_dir"
done

mkdir -p "\$FOXIUM_BACKUP_DIR"

foxium_backup_if_exists() {
    local input_path="\$1"
    local destination_name="\$2"
    if [[ -e "\$input_path" ]]; then
        cp -R "\$input_path" "\$FOXIUM_BACKUP_DIR/\$destination_name" >/dev/null 2>&1
    fi
}

echo "[Foxium] Running auto backup..."
foxium_backup_if_exists "data/\${FOXIUM_USER}/worlds" "worlds"
foxium_backup_if_exists "data/\${FOXIUM_USER}/characters" "characters"
foxium_backup_if_exists "data/\${FOXIUM_USER}/OpenAI Settings" "OpenAI_Settings"
foxium_backup_if_exists "data/\${FOXIUM_USER}/QuickReplies" "QuickReplies"
foxium_backup_if_exists "data/\${FOXIUM_USER}/settings.json" "settings.json"
echo "[Foxium] Auto backup completed: \${FOXIUM_BACKUP_DIR}"
echo
# === FOXIUM AUTO BACKUP END ===

EOF
}
write_batch_auto_backup_block() {
    local output_file="$1"
    local batch_user="$2"

    cat >"$output_file"  <<EOF
:: === FOXIUM AUTO BACKUP START ===
set "FOXIUM_USER=${batch_user}"
set "FOXIUM_BACKUP_PARENT_DIR=%~dp0foxiumV2\\STbackupF"
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "FOXIUM_BACKUP_TIMESTAMP=%%A"
set "FOXIUM_BACKUP_DIR=%FOXIUM_BACKUP_PARENT_DIR%\\auto_backup_%FOXIUM_BACKUP_TIMESTAMP%"

if not exist "%FOXIUM_BACKUP_PARENT_DIR%" mkdir "%FOXIUM_BACKUP_PARENT_DIR%" >nul 2>&1
for /d %%D in ("%FOXIUM_BACKUP_PARENT_DIR%\\auto_backup_*") do rd /s /q "%%D" 2>nul
if not exist "%FOXIUM_BACKUP_DIR%" mkdir "%FOXIUM_BACKUP_DIR%" >nul 2>&1

echo [Foxium] Running auto backup...
if exist "%~dp0data\\%FOXIUM_USER%\\worlds" xcopy "%~dp0data\\%FOXIUM_USER%\\worlds" "%FOXIUM_BACKUP_DIR%\\worlds\\" /E /Y /I /C /H /R /Q >nul 2>&1
if exist "%~dp0data\\%FOXIUM_USER%\\characters" xcopy "%~dp0data\\%FOXIUM_USER%\\characters" "%FOXIUM_BACKUP_DIR%\\characters\\" /E /Y /I /C /H /R /Q >nul 2>&1
if exist "%~dp0data\\%FOXIUM_USER%\\OpenAI Settings" xcopy "%~dp0data\\%FOXIUM_USER%\\OpenAI Settings" "%FOXIUM_BACKUP_DIR%\\OpenAI_Settings\\" /E /Y /I /C /H /R /Q >nul 2>&1
if exist "%~dp0data\\%FOXIUM_USER%\\QuickReplies" xcopy "%~dp0data\\%FOXIUM_USER%\\QuickReplies" "%FOXIUM_BACKUP_DIR%\\QuickReplies\\" /E /Y /I /C /H /R /Q >nul 2>&1
if exist "%~dp0data\\%FOXIUM_USER%\\settings.json" copy "%~dp0data\\%FOXIUM_USER%\\settings.json" "%FOXIUM_BACKUP_DIR%\\settings.json" /Y >nul 2>&1
echo [Foxium] Auto backup completed: %FOXIUM_BACKUP_DIR%
echo.
:: === FOXIUM AUTO BACKUP END ===

EOF
}
insert_auto_backup_block() {
    local target_file="$1"
    local block_file="$2"
    local temp_file

    temp_file="$(make_temp_next_to "$target_file")" || return 1
    if awk 'FNR == NR { block = block $0 ORS; next }
        !inserted && $0 ~ /node/ && $0 ~ /server\.js/ {
            printf "%s", block
            inserted = 1
        }
        { print }
        END { exit inserted ? 0 : 1 }
    ' "$block_file" "$target_file" >"$temp_file"; then
        mv "$temp_file" "$target_file"
        return 0
    fi

    rm -f "$temp_file"
    return 1
}
enable_auto_backup() {
    print_title "启用自动备份"
    print_info "此功能会把自动备份代码注入到 start.sh 或 Windows 启动脚本中。"
    print_info "自动备份会在每次启动前保留最新一份 worlds / characters / OpenAI Settings / QuickReplies / settings.json。"

    printf '%s\n' "1. Termux / Linux (修改 start.sh)"
    printf '%s\n' "2. Windows (修改 Start.bat 或 start.bat)"
    printf '%s\n' "0. 返回"

    local env_choice target_file block_file marker escaped_user batch_user
    while true; do
        prompt_choice "请选择 [0-2]: " env_choice
        case "$env_choice" in
            1)
                target_file="${ST_DIR}/start.sh"
                break
                ;;
            2)
                if ! choose_windows_start_script target_file; then
                    print_error "未找到 Windows 启动脚本。"
                    press_enter_to_continue
                    return
            fi
                break
                ;;
            0)
                return
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done

    if [[ ! -f "$target_file" ]]; then
        print_error "启动脚本不存在：$target_file"
        press_enter_to_continue
        return
    fi

    if grep -Fq "FOXIUM AUTO BACKUP START" "$target_file"; then
        print_warn "目标启动脚本已经启用了 Foxium 自动备份。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认修改 ${target_file} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    create_backup "$target_file"
    block_file="$(make_temp_next_to "$target_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    if [[ "$env_choice" == "1" ]]; then
        escaped_user="${USER_NAME//\\/\\\\}"
        escaped_user="${escaped_user//\"/\\\"}"
        write_shell_auto_backup_block "$block_file" "$escaped_user"
    else
        batch_user="${USER_NAME//%/%%}"
        write_batch_auto_backup_block "$block_file" "$batch_user"
    fi

    if insert_auto_backup_block "$target_file" "$block_file"; then
        rm -f "$block_file"
        if [[ "$env_choice" == "1" ]]; then
            chmod +x "$target_file" >/dev/null 2>&1 || true
        fi
        print_success "已启用自动备份。"
    else
        rm -f "$block_file"
        print_error "未找到合适的插入点，修改失败。"
    fi

    press_enter_to_continue
}


################################################################################
#  End File:  foxiumV2/./lib/auto_backup.sh
################################################################################


show_main_menu() {
    clear_screen
    print_title "Foxium V2"
    printf '%s\n' "当前配置:"
    printf '  ST 目录: %s%s%s\n' "$GREEN" "$ST_DIR" "$NC"
    printf '  ST 版本: %s%s%s\n' "$GREEN" "${ST_VERSION:-未知}" "$NC"
    printf '  用户: %s%s%s\n' "$GREEN" "$USER_NAME" "$NC"
    printf '  备份会话: %s%s%s\n' "$GREEN" "$BACKUP_SESSION_DIR" "$NC"
    printf '\n'
    printf '%s\n' "请选择功能类别:"
    printf '%s\n' "1. 修复功能"
    printf '%s\n' "2. 编辑器"
    printf '%s\n' "3. 优化功能"
    printf '\n'
    printf '%s\n' "0. 退出"
    printf '\n'
}
show_fix_menu() {
    clear_screen
    print_title "修复功能"
    printf '%s\n' "1. 修复 node 包问题无法启动酒馆"
    printf '%s\n' "2. 强制删除扩展"
    printf '%s\n' "3. 二合一爆内存修复"
    printf '%s\n' "4. [风险] 允许给 Gemini 3 系列模型发图（仅 ST <= 1.13.*）"
    printf '\n'
    printf '%s\n' "0. 返回主菜单"
    printf '\n'
}
show_editor_menu() {
    clear_screen
    print_title "编辑器"
    printf '1. config.yaml 编辑器%s\n' "$(format_dependency_status "yq" "$YQ_AVAILABLE")"
    printf '2. settings.json 编辑器%s\n' "$(format_dependency_status "jq" "$JQ_AVAILABLE")"
    printf '%s\n' "3. Claude/Gemini 模型列表修改器"
    printf '\n'
    printf '%s\n' "0. 返回主菜单"
    printf '\n'
}
show_optimize_menu() {
    clear_screen
    print_title "优化功能"
    printf '%s\n' "1. 解除聊天文件大小限制"
    printf '%s\n' "2. 启用自动备份"
    printf '\n'
    printf '%s\n' "0. 返回主菜单"
    printf '\n'
}
fix_menu_loop() {
    while true; do
        show_fix_menu
        prompt_choice "请输入选项 [0-4]: " choice

        case "$choice" in
            1) fix_npm_install ;;
            2) fix_extension_uninstall ;;
            3) never_oom ;;
            4) fix_gemini3_media ;;
            0) return ;;
            *)
                print_error "无效的选项"
                press_enter_to_continue
                ;;
        esac
    done
}
editor_menu_loop() {
    while true; do
        show_editor_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) config_editor_menu ;;
            2) settings_editor_menu ;;
            3) model_editor_menu ;;
            0) return ;;
            *)
                print_error "无效的选项"
                press_enter_to_continue
                ;;
        esac
    done
}
optimize_menu_loop() {
    while true; do
        show_optimize_menu
        prompt_choice "请输入选项 [0-2]: " choice

        case "$choice" in
            1) remove_chat_size_limit ;;
            2) enable_auto_backup ;;
            0) return ;;
            *)
                print_error "无效的选项"
                press_enter_to_continue
                ;;
        esac
    done
}
main_loop() {
    while true; do
        show_main_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) fix_menu_loop ;;
            2) editor_menu_loop ;;
            3) optimize_menu_loop ;;
            0)
                print_info "再见。"
                exit 0
                ;;
            *)
                print_error "无效的选项"
                press_enter_to_continue
                ;;
        esac
    done
}
main() {
    run_startup_checks
    main_loop
}
main "$@"


################################################################################
#  End File:  ./foxiumV2/main.sh
################################################################################

