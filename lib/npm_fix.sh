#!/usr/bin/env bash

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
