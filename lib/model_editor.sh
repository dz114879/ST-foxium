#!/usr/bin/env bash

show_model_editor_menu() {
    clear_screen
    print_title "Claude/Gemini 模型列表修改器"
    printf '%s\n' "1. 添加模型"
    printf '%s\n' "2. 查看已添加的自定义模型"
    printf '%s\n' "3. 删除已添加的自定义模型"
    printf '\n'
    printf '%s\n' "0. 返回上级"
    printf '\n'
}

model_editor_file() {
    printf '%s' "${ST_DIR}/public/index.html"
}

resolve_model_target() {
    local model_id_lower
    model_id_lower="$(to_lower "$1")"

    case "$model_id_lower" in
        claude*|neptune*)
            printf '%s' "model_claude_select"
            ;;
        gemini*|gemma*)
            printf '%s' "model_google_select"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}

prompt_model_target() {
    while true; do
        printf '%s\n' "1. Claude / Neptune"
        printf '%s\n' "2. Gemini / Gemma"
        printf '\n'
        prompt_choice "请选择目标下拉框 [1-2]: " selection

        case "$selection" in
            1)
                printf '%s' "model_claude_select"
                return 0
                ;;
            2)
                printf '%s' "model_google_select"
                return 0
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done
}

collect_custom_models() {
    local index_file
    index_file="$(model_editor_file)"

    awk '
        /<select id="model_claude_select">/ { current = "model_claude_select" }
        /<select id="model_google_select">/ { current = "model_google_select" }
        /<\/select>/ { current = "" }
        /foxium-custom/ {
            value = ""
            label = ""
            if (match($0, /value="[^"]+"/)) {
                value = substr($0, RSTART + 7, RLENGTH - 8)
            }
            if (match($0, />[^<]*<\/option>/)) {
                label = substr($0, RSTART + 1, RLENGTH - 10)
            }
            gsub(/&quot;/, "\"", label)
            gsub(/&gt;/, ">", label)
            gsub(/&lt;/, "<", label)
            gsub(/&amp;/, "\\&", label)
            if (current != "" && value != "") {
                printf "%s\t%s\t%s\n", current, value, label
            }
        }
    ' "$index_file"
}

list_custom_models() {
    local -a entries=()
    mapfile -t entries < <(collect_custom_models)

    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "当前没有由 Foxium 添加的自定义模型。"
        return 1
    fi

    local index=1 target_label target_id model_id display_name
    for entry in "${entries[@]}"; do
        IFS=$'\t' read -r target_id model_id display_name <<< "$entry"
        if [[ "$target_id" == "model_claude_select" ]]; then
            target_label="Claude/Neptune"
        else
            target_label="Gemini/Gemma"
        fi

        printf '%s. [%s] %s -> %s\n' "$index" "$target_label" "$model_id" "$display_name"
        ((index++))
    done

    return 0
}

add_custom_model() {
    local index_file model_id display_name target_select escaped_model_id escaped_display_name
    index_file="$(model_editor_file)"

    if [[ ! -f "$index_file" ]]; then
        print_error "未找到 index.html: $index_file"
        press_enter_to_continue
        return
    fi

    prompt_choice "请输入模型 ID: " model_id
    model_id="$(trim_whitespace "$model_id")"
    if [[ -z "$model_id" ]]; then
        print_warn "模型 ID 不能为空。"
        press_enter_to_continue
        return
    fi

    if [[ "$model_id" == *['"<>']* ]]; then
        print_warn "模型 ID 不能包含双引号、< 或 >。"
        press_enter_to_continue
        return
    fi

    prompt_choice "请输入显示名称 [默认与模型 ID 相同]: " display_name
    display_name="$(trim_whitespace "$display_name")"
    if [[ -z "$display_name" ]]; then
        display_name="$model_id"
    fi

    target_select="$(resolve_model_target "$model_id")"
    if [[ -z "$target_select" ]]; then
        target_select="$(prompt_model_target)"
    fi

    if grep -Fq "value=\"${model_id}\"" "$index_file"; then
        print_warn "index.html 中已存在相同的模型 ID：${model_id}"
        press_enter_to_continue
        return
    fi

    escaped_model_id="$(escape_html "$model_id")"
    escaped_display_name="$(escape_html "$display_name")"

    local inserted_line='                                    <!-- foxium-custom --><option value="'"${escaped_model_id}"'">'"${escaped_display_name}"'</option>'
    local temp_file
    temp_file="$(make_temp_next_to "$index_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    create_backup "$index_file"
    if awk -v target_select="$target_select" -v inserted_line="$inserted_line" '
        index($0, "<select id=\"" target_select "\">") {
            in_target = 1
            print
            next
        }
        in_target && $0 ~ /<optgroup[^>]*>/ && !inserted {
            print
            print inserted_line
            inserted = 1
            in_target = 0
            next
        }
        { print }
        END { exit inserted ? 0 : 1 }
    ' "$index_file" > "$temp_file"; then
        mv "$temp_file" "$index_file"
        print_success "已添加自定义模型：${model_id}"
    else
        rm -f "$temp_file"
        print_error "添加模型失败，未找到目标下拉框或插入点。"
    fi

    press_enter_to_continue
}

view_custom_models() {
    if ! list_custom_models; then
        press_enter_to_continue
        return
    fi

    press_enter_to_continue
}

delete_custom_model() {
    local -a entries=()
    local selection target_id model_id display_name
    local index_file temp_file
    index_file="$(model_editor_file)"

    mapfile -t entries < <(collect_custom_models)
    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "当前没有可删除的自定义模型。"
        press_enter_to_continue
        return
    fi

    list_custom_models
    printf '\n'
    prompt_choice "请选择要删除的编号 [0-$((${#entries[@]}))]: " selection

    if [[ "$selection" == "0" ]]; then
        return
    fi

    if ! is_positive_integer "$selection" || (( selection < 1 || selection > ${#entries[@]} )); then
        print_warn "无效的编号。"
        press_enter_to_continue
        return
    fi

    IFS=$'\t' read -r target_id model_id display_name <<< "${entries[$((selection - 1))]}"

    if ! ask_confirm "确认删除自定义模型 ${model_id} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    temp_file="$(make_temp_next_to "$index_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    create_backup "$index_file"
    if awk -v target_select="$target_id" -v model_id="$model_id" '
        index($0, "<select id=\"" target_select "\">") { in_target = 1 }
        in_target && /<\/select>/ { in_target = 0 }
        in_target && /foxium-custom/ && index($0, "value=\"" model_id "\"") {
            removed = 1
            next
        }
        { print }
        END { exit removed ? 0 : 1 }
    ' "$index_file" > "$temp_file"; then
        mv "$temp_file" "$index_file"
        print_success "已删除自定义模型：${model_id}"
    else
        rm -f "$temp_file"
        print_error "删除失败，未找到对应的自定义模型。"
    fi

    press_enter_to_continue
}

model_editor_menu() {
    while true; do
        show_model_editor_menu
        prompt_choice "请输入选项 [0-3]: " choice

        case "$choice" in
            1) add_custom_model ;;
            2) view_custom_models ;;
            3) delete_custom_model ;;
            0) return ;;
            *)
                print_warn "无效的选项。"
                press_enter_to_continue
                ;;
        esac
    done
}
