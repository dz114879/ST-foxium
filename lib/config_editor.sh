#!/usr/bin/env bash

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

                if ! is_positive_integer "$new_port" || (( 10#$new_port < 1 || 10#$new_port > 65535 )); then
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
