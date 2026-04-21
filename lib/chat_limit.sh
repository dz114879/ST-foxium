#!/usr/bin/env bash

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
    ' "$server_main" > "$temp_file"; then
        mv "$temp_file" "$server_main"
        print_success "聊天文件大小限制已修改为 1024mb。"
    else
        rm -f "$temp_file"
        print_error "未找到完整的 bodyParser 限制配置，修改失败。"
    fi

    press_enter_to_continue
}
