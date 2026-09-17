#!/usr/bin/env bash

declare -a ST_CANDIDATES=()
declare -a ST_SEARCH_ROOTS=()
FOXIUM_JQ_WINDOWS_VERSION="${FOXIUM_JQ_WINDOWS_VERSION:-1.8.1}"
FOXIUM_YQ_WINDOWS_VERSION="${FOXIUM_YQ_WINDOWS_VERSION:-v4.52.5}"

is_valid_st_dir() {
    local candidate="$1"
    [[ -d "$candidate" && -f "${candidate}/server.js" && -f "${candidate}/package.json" ]]
}

set_st_dir() {
    ST_DIR="$1"
    print_success "已设置 ST 目录: $ST_DIR"
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

    # 按 server.js + package.json 的特征识别，不依赖目录名，
    # 改名、大小写、带版本号后缀的目录都能被找到。
    for candidate in "$root"/*/; do
        add_st_candidate "${candidate%/}"
    done
}

# 可能藏着 ST 的位置；自动扫描与手输相对路径共用这一份列表。
# 先规范化再去重，脚本放在主目录里时不会把同一个目录扫两遍。
build_st_search_roots() {
    ST_SEARCH_ROOTS=()

    local root resolved existing
    local -a roots=()

    if [[ -n "${FOXIUM_INVOCATION_DIR:-}" ]]; then
        roots+=("$FOXIUM_INVOCATION_DIR")
    fi
    if [[ -n "$FOXIUM_ROOT" ]]; then
        roots+=("$FOXIUM_ROOT" "${FOXIUM_ROOT}/..")
    fi
    if [[ -n "${HOME:-}" ]]; then
        roots+=("$HOME" "${HOME}/storage/shared")
    fi

    for root in "${roots[@]}"; do
        resolved="$(canonical_path "$root")" || continue

        for existing in "${ST_SEARCH_ROOTS[@]}"; do
            if [[ "$existing" == "$resolved" ]]; then
                continue 2
            fi
        done

        ST_SEARCH_ROOTS+=("$resolved")
    done
}

collect_st_candidates() {
    ST_CANDIDATES=()

    build_st_search_roots

    local root
    for root in "${ST_SEARCH_ROOTS[@]}"; do
        scan_candidate_root "$root"
    done
}

# read 不会展开 ~、$HOME，也不会去掉引号，用户粘贴的 Windows 反斜杠路径也要处理。
expand_user_path() {
    local input="$1"

    if [[ ${#input} -ge 2 ]] && [[ "$input" == \"*\" || "$input" == \'*\' ]]; then
        input="${input:1:${#input}-2}"
    fi

    input="${input//\\//}"

    if [[ "$input" =~ ^([A-Za-z]):/(.*)$ ]]; then
        input="/$(to_lower "${BASH_REMATCH[1]}")/${BASH_REMATCH[2]}"
    fi

    case "$input" in
        '~'|'$HOME'|'${HOME}') input="${HOME:-}" ;;
        '~/'*|'$HOME/'*|'${HOME}/'*) input="${HOME:-}/${input#*/}" ;;
    esac

    printf '%s' "$input"
}

# 把用户输入解析成真实存在的路径（文件或目录），成功时输出规范化后的绝对路径。
# 绝对路径直接用，相对路径按搜索根依次尝试。
resolve_user_path() {
    local input="$1"
    local base attempt

    if [[ "$input" == /* ]]; then
        [[ -e "$input" ]] || return 1
        canonical_path "$input" || return 1
        return 0
    fi

    build_st_search_roots

    for base in "${ST_SEARCH_ROOTS[@]}"; do
        attempt="${base%/}/${input}"
        if [[ -e "$attempt" ]]; then
            canonical_path "$attempt" || return 1
            return 0
        fi
    done

    return 1
}

# 接纳用户输入的路径：文件取它所在的目录，然后校验、纠错，必要时向上或向下找。
accept_user_directory() {
    local directory="$1"
    local missing="" name
    local ancestor parent
    local -i level

    if [[ ! -d "$directory" ]]; then
        print_info "你输入的是一个文件，改用它所在的目录。"
        directory="$(dirname "$directory")"
    fi

    if is_valid_st_dir "$directory"; then
        set_st_dir "$directory"
        return 0
    fi

    for name in server.js package.json; do
        [[ -f "${directory}/${name}" ]] || missing="${missing:+${missing}、}${name}"
    done
    print_warn "该目录里缺少 ${missing}，不是有效的 SillyTavern 根目录。"

    ancestor="$directory"
    for ((level = 0; level < 3; level++)); do
        parent="$(dirname "$ancestor")"
        [[ "$parent" != "$ancestor" ]] || break
        ancestor="$parent"

        if is_valid_st_dir "$ancestor"; then
            print_info "输入的目录位于 SillyTavern 根目录内部。"
            ask_confirm "是否改用根目录 ${ancestor}？" "y" || return 1
            set_st_dir "$ancestor"
            return 0
        fi
    done

    ST_CANDIDATES=()
    scan_candidate_root "$directory"
    if [[ ${#ST_CANDIDATES[@]} -gt 0 ]]; then
        print_info "该目录下找到可用的 SillyTavern 目录。"
        prompt_candidate_selection && return 0
        return 1
    fi

    print_warn "没有在 ${directory} 里找到 SillyTavern（server.js 和 package.json 必须同时存在）。"
    return 1
}

# 从 ST_CANDIDATES 里确定目录：唯一候选要用户确认，多个候选按编号选择。
prompt_candidate_selection() {
    local candidate selection
    local index=1

    if [[ ${#ST_CANDIDATES[@]} -eq 1 ]]; then
        if ! ask_confirm "检测到 SillyTavern 目录: ${ST_CANDIDATES[0]}，是否使用？" "y"; then
            print_info "已跳过这个目录，改为手动输入。"
            return 1
        fi
        set_st_dir "${ST_CANDIDATES[0]}"
        return 0
    fi

    print_info "找到多个可用的 SillyTavern 目录："
    for candidate in "${ST_CANDIDATES[@]}"; do
        printf '%s. %s\n' "$index" "$candidate"
        ((index++))
    done

    while true; do
        prompt_choice "请选择要使用的目录编号 [0 手动输入]: " selection

        if [[ "$selection" == "0" ]]; then
            print_info "已跳过候选列表，改为手动输入。"
            return 1
        fi

        if is_positive_integer "$selection" && (( selection >= 1 && selection <= ${#ST_CANDIDATES[@]} )); then
            set_st_dir "${ST_CANDIDATES[$((selection - 1))]}"
            return 0
        fi

        print_warn "无效的选择。"
    done
}

prompt_for_st_directory() {
    local user_input expanded_path resolved_path

    print_info "请输入 SillyTavern 根目录，目录内需要同时包含 server.js 和 package.json。"
    print_info "支持 ~ 开头的主目录路径；直接回车或输入 q 可退出。"
    print_info "不清楚目录在哪？可以运行 ls ~ 查看主目录，或运行 find ~ -maxdepth 3 -name server.js 搜索。"

    while true; do
        prompt_choice "ST 目录路径: " user_input
        user_input="$(trim_whitespace "$user_input")"

        if [[ -z "$user_input" || "${user_input,,}" == "q" ]]; then
            print_info "已跳过手动输入。"
            return 1
        fi

        expanded_path="$(expand_user_path "$user_input")"

        if resolved_path="$(resolve_user_path "$expanded_path")"; then
            accept_user_directory "$resolved_path" && return 0
            continue
        fi

        print_warn "目录不存在: $user_input"
    done
}

select_st_directory() {
    collect_st_candidates

    # 自动模式下不做编号选择：猜错会改到另一个酒馆，宁可让用户手动跑一次。
    if is_noninteractive_mode && [[ ${#ST_CANDIDATES[@]} -gt 1 ]]; then
        print_error "检测到多个 SillyTavern 目录，非交互模式无法自动选择："
        printf '  %s\n' "${ST_CANDIDATES[@]}"
        print_info "请去掉 --fix-oom 手动运行一次，选择要修复的目录。"
        return 1
    fi

    if [[ ${#ST_CANDIDATES[@]} -gt 0 ]]; then
        prompt_candidate_selection && return 0
    elif is_noninteractive_mode; then
        print_error "未自动找到 SillyTavern 目录，非交互模式无法手动输入路径。"
        print_info "请在酒馆目录或它的上级目录里运行，或去掉 --fix-oom 手动指定目录。"
        return 1
    else
        print_warn "未自动找到 SillyTavern 目录。"
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

    # 白名单而非黑名单：用户名会被拼进未加引号的 heredoc（生成 start.sh 自动
    # 备份块时做参数展开/命令替换）和 Windows 批处理，也会被拼成路径。只放行
    # ST handle 实际使用的字符集，避免遗漏某个元字符就重新打开注入点。
    if [[ ! "$value" =~ ^[A-Za-z0-9._-]+$ ]]; then
        return 1
    fi

    # 纯点名字能通过上面的字符白名单，但 "${ST_DIR}/data/.." 会被解析成
    # ST_DIR 本身，让 USER_DIR 指向上层目录；"." 也不是有效 handle。
    if [[ "$value" != *[!.]* ]]; then
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

        print_warn "用户名只能包含字母、数字、点、下划线和连字符。"
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
        msys*|cygwin*)
            return 0
            ;;
    esac

    case "${MSYSTEM:-}" in
        MINGW*|UCRT*|CLANG*)
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
        *":$user_bin:"*)
            ;;
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
        x86_64|amd64)
            printf '%s' "amd64"
            ;;
        i686|i386)
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

    # 非交互模式不代为安装：装包属于本次修复之外的副作用，留给用户自己决定。
    if is_noninteractive_mode; then
        return 1
    fi

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

    # 非交互模式不询问用户名：本次自动修复用不到用户目录，
    # 也不会为了「看起来正常」去创建一个并不存在的用户目录。
    if is_noninteractive_mode; then
        print_info "非交互模式：跳过用户名检查。"
    elif ! set_user_directory; then
        exit 1
    fi

    detect_optional_tools

    print_success "启动检查完成。"
    print_info "ST 目录: $ST_DIR"
    if [[ -n "$USER_DIR" ]]; then
        print_info "用户目录: $USER_DIR"
    fi
    print_info "本次备份目录: $BACKUP_SESSION_DIR"
    print_info "jq: $([[ "$JQ_AVAILABLE" == "1" ]] && printf '%s' '可用' || printf '%s' '不可用')"
    print_info "yq: $([[ "$YQ_AVAILABLE" == "1" ]] && printf '%s' '可用' || printf '%s' '不可用')"
    press_enter_to_continue
}
