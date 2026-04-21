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
