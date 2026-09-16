#!/usr/bin/env bash

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

    create_backup "$target_file" || return 1
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
    create_backup "$start_file" || {
        rm -f "$temp_file"
        return 1
    }

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
    ' "$start_file" > "$temp_file"; then
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
    printf '\n'

    local total_memory node_arch
    if total_memory="$(read_total_memory_gb)"; then
        print_info "设备总内存: ${total_memory} GB"
    else
        print_info "设备总内存: 未知"
    fi

    if node_arch="$(read_node_arch)"; then
        print_info "node 架构: ${node_arch}"
        if [[ "$node_arch" == "arm" ]]; then
            print_warn "当前是 32 位 node：它实际到不了 4096 的堆上限，本次修复很可能不生效，建议换用 64 位 node。"
        fi
    else
        print_info "node 架构: 未知"
    fi

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
    elif [[ -z "$ST_VERSION" ]]; then
        print_warn "无法读取 ST 版本，将按旧版本处理。"
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
    printf '\n'
    print_title "如果之后还是爆内存"
    print_info "崩溃时终端会打印一行「<脚本>: line N: PID 信号 <命令>」，照着分四种情况："
    printf '%s\n' "1. 那行里没有 --max-old-space-size=4096：这次崩溃的进程没吃到参数，"
    printf '%s\n' "   要么修改没成功，要么酒馆不是用被改过的启动脚本拉起来的。"
    printf '%s\n' "2. 那行的信号是 Killed（不是 Aborted）：进程是被系统杀掉的，和堆上限无关，"
    printf '%s\n' "   继续调大数字没有用，先减少同时运行的程序、缩短上下文。"
    printf '%s\n' "3. 那行带着 4096，但崩溃前最后几行的内存数字只到 1G 上下：这个进程实际没拿到 4G，"
    printf '%s\n' "   先确认 node 不是 32 位（本功能开头显示的架构是 arm 就是），"
    printf '%s\n' "   再确认设备可用内存是不是被其他程序占满了。"
    printf '%s\n' "4. 崩溃前最后几行的内存数字确实冲到 4096 附近：说明你的酒馆真的吃了 4G 内存，"
    printf '%s\n' "   这是不正常的，先排查可疑的角色卡 / 聊天记录 / 插件。"
    printf '\n'
    print_info "排查不出来时，把本功能开头显示的环境信息和崩溃时那几行一起发出来。"
    press_enter_to_continue
}
