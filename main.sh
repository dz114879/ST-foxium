#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
FOXIUM_ROOT="$SCRIPT_DIR"

if [[ ! -d "$FOXIUM_ROOT/lib" && -d "$SCRIPT_DIR/../lib" ]]; then
    FOXIUM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
fi

cd "$FOXIUM_ROOT" || exit 1

# shellcheck source=./lib/common.sh
source "./lib/common.sh"
# shellcheck source=./lib/backup.sh
source "./lib/backup.sh"
# shellcheck source=./lib/detect.sh
source "./lib/detect.sh"
# shellcheck source=./lib/npm_fix.sh
source "./lib/npm_fix.sh"
# shellcheck source=./lib/extension_fix.sh
source "./lib/extension_fix.sh"
# shellcheck source=./lib/never_oom.sh
source "./lib/never_oom.sh"
# shellcheck source=./lib/gemini_media.sh
source "./lib/gemini_media.sh"
# shellcheck source=./lib/config_editor.sh
source "./lib/config_editor.sh"
# shellcheck source=./lib/settings_editor.sh
source "./lib/settings_editor.sh"
# shellcheck source=./lib/model_editor.sh
source "./lib/model_editor.sh"
# shellcheck source=./lib/chat_limit.sh
source "./lib/chat_limit.sh"
# shellcheck source=./lib/auto_backup.sh
source "./lib/auto_backup.sh"

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
