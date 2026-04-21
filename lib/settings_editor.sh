#!/usr/bin/env bash

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
