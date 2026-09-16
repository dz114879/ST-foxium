#!/usr/bin/env bash

fix_npm_install() {
    print_title "修复 node 包问题"
    print_info "此功能会删除 node_modules，然后使用淘宝镜像重新执行 npm install。"

    if ! command_exists npm; then
        print_error "当前环境未找到 npm，无法执行该功能。"
        press_enter_to_continue
        return
    fi

    print_info "删除 node_modules 和安装依赖都可能在几十秒内没有任何新输出，这是正常的，不是卡死。"
    print_info "整个过程中请不要按 Ctrl+C：npm 装到一半被打断，依赖会残缺，酒馆反而更启动不了。"
    print_info "如果已经打断过：重新运行本功能即可，它会先删干净再重新安装。"

    if ! ask_confirm "确认执行此操作吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    local start_seconds=$SECONDS
    if (
        cd "$ST_DIR" || exit 1

        if [[ -d "node_modules" ]]; then
            print_info "正在删除 node_modules（文件很多，通常 10-60 秒）..."
            rm -rf "node_modules"
        fi

        print_info "正在使用淘宝镜像重新安装依赖（通常 1-5 分钟，取决于网络）..."
        npm install --registry=https://registry.npmmirror.com
    ); then
        print_success "依赖已重新安装完成，耗时 $((SECONDS - start_seconds)) 秒。"
    else
        print_error "重新安装依赖失败，耗时 $((SECONDS - start_seconds)) 秒。"
        print_info "如果刚才是按了 Ctrl+C 中断，重新运行本功能即可。"
    fi

    press_enter_to_continue
}
