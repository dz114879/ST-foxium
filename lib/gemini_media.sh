#!/usr/bin/env bash

array_contains_model() {
    local target_file="$1"
    local anchor="$2"
    local model_prefix="$3"

    awk -v anchor="$anchor" -v model_prefix="$model_prefix" '
        index($0, anchor) { in_block = 1 }
        in_block && index($0, model_prefix) { found = 1 }
        in_block && /\];/ { in_block = 0 }
        END { exit found ? 0 : 1 }
    ' "$target_file"
}

fix_gemini3_media() {
    print_title "允许给 Gemini 3 系列模型发图"
    print_risk "此功能会直接修改 public/scripts/openai.js。"

    if [[ -n "$ST_VERSION" ]] && check_st_version ">" 1 13 999; then
        print_info "当前 ST 版本为 ${ST_VERSION}，已经不需要使用此功能。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认执行此风险操作吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    local openai_js="${ST_DIR}/public/scripts/openai.js"
    if [[ ! -f "$openai_js" ]]; then
        print_error "未找到 openai.js: $openai_js"
        press_enter_to_continue
        return
    fi

    local modified=0
    if ! array_contains_model "$openai_js" "const visionSupportedModels = [" "'gemini-3'"; then
        create_backup "$openai_js"
        if insert_line_after_anchor "$openai_js" "const visionSupportedModels = [" "        'gemini-3',"; then
            print_success "已把 gemini-3 加入 visionSupportedModels"
            modified=1
        else
            print_warn "未找到 visionSupportedModels 插入点。"
        fi
    else
        print_warn "visionSupportedModels 已包含 gemini-3，跳过。"
    fi

    if ! array_contains_model "$openai_js" "const videoSupportedModels = [" "'gemini-3'"; then
        if (( modified == 0 )); then
            create_backup "$openai_js"
        fi
        if insert_line_after_anchor "$openai_js" "const videoSupportedModels = [" "        'gemini-3',"; then
            print_success "已把 gemini-3 加入 videoSupportedModels"
            modified=1
        else
            print_warn "未找到 videoSupportedModels 插入点。"
        fi
    else
        print_warn "videoSupportedModels 已包含 gemini-3，跳过。"
    fi

    if (( modified > 0 )); then
        print_success "Gemini 3 媒体支持修复完成。"
    else
        print_info "没有新的内容需要写入。"
    fi

    press_enter_to_continue
}
