#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
FOXIUM_ROOT="$SCRIPT_DIR"

if [[ ! -d "$FOXIUM_ROOT/lib" && -d "$SCRIPT_DIR/../lib" ]]; then
    FOXIUM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
fi

# 用户敲命令时所在的目录，手输相对路径时优先按它解析。
FOXIUM_INVOCATION_DIR="$(pwd -P)"

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
    printf '%s\n' "3. [已弃用] Claude/Gemini 模型列表修改器"
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

show_model_editor_deprecated() {
    print_title "功能已弃用"
    print_warn "Claude/Gemini 模型列表修改器已弃用。"
    print_info "请改用 SillyTavern-CustomModels 插件："
    printf '%s\n' "  https://github.com/LenAnderson/SillyTavern-CustomModels"
    print_info "此前用本功能写入 public/index.html 的旧条目，请手动删除。"
    printf '\n'
    press_enter_to_continue
}

editor_menu_loop() {
    while true; do
        show_editor_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) config_editor_menu ;;
            2) settings_editor_menu ;;
            3) show_model_editor_deprecated ;;
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

show_usage() {
    printf '%s\n' "用法: bash ffss.sh [选项]"
    printf '%s\n' "  --fix-oom   非交互执行「二合一爆内存修复」，所有确认自动按 y 处理"
    printf '%s\n' "  -h, --help  显示本帮助"
    printf '%s\n' "不带选项时进入交互菜单。"
}

parse_cli_args() {
    local arg

    for arg in "$@"; do
        case "$arg" in
            --fix-oom)
                FOXIUM_NONINTERACTIVE="1"
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "未知的参数: $arg"
                show_usage
                return 1
                ;;
        esac
    done
}

handle_interrupt() {
    printf '\n'
    print_warn "已中断。"
    if [[ -n "$BACKUP_SESSION_DIR" ]]; then
        print_info "本次备份目录: $BACKUP_SESSION_DIR"
    fi
    print_info "重新运行脚本即可继续。"
    exit 130
}

main() {
    trap handle_interrupt INT

    if ! parse_cli_args "$@"; then
        exit 1
    fi

    if is_noninteractive_mode; then
        print_title "--fix-oom 非交互模式"
        print_info "所有确认自动按 y 处理；遇到无法自动决定的选择会直接报错退出。"
    fi

    run_startup_checks

    if is_noninteractive_mode; then
        never_oom
        exit $?
    fi

    main_loop
}

main "$@"
