#!/usr/bin/env bash

fix_extension_uninstall() {
    print_title "强制删除扩展"
    print_info "此功能会列出当前用户扩展和第三方扩展，选择后先备份再删除。"

    local user_ext_dir="${USER_DIR}/extensions"
    local third_party_dir="${ST_DIR}/public/scripts/extensions/third-party"
    local -a extension_names=()
    local -a extension_paths=()
    local index=1

    printf '%s\n\n' "已安装的扩展："

    local old_nullglob
    old_nullglob="$(shopt -p nullglob)"
    shopt -s nullglob

    if [[ -d "$user_ext_dir" ]]; then
        printf '%s\n' "[为当前用户安装的扩展]"
        local ext_path
        for ext_path in "${user_ext_dir}"/*; do
            [[ -d "$ext_path" ]] || continue
            extension_names[index]="$(basename "$ext_path")"
            extension_paths[index]="$ext_path"
            printf '  %s. %s\n' "$index" "${extension_names[index]}"
            ((index++))
        done
        printf '\n'
    fi

    if [[ -d "$third_party_dir" ]]; then
        printf '%s\n' "[为所有用户安装的第三方扩展]"
        local ext_path
        for ext_path in "${third_party_dir}"/*; do
            [[ -d "$ext_path" ]] || continue
            extension_names[index]="$(basename "$ext_path")"
            extension_paths[index]="$ext_path"
            printf '  %s. %s\n' "$index" "${extension_names[index]}"
            ((index++))
        done
        printf '\n'
    fi

    eval "$old_nullglob"

    if [[ ${#extension_names[@]} -eq 0 ]]; then
        print_info "未找到可删除的扩展。"
        press_enter_to_continue
        return
    fi

    printf '%s\n\n' "0. 返回"
    prompt_choice "请选择要删除的扩展编号: " selection

    if [[ "$selection" == "0" ]]; then
        return
    fi

    if ! is_positive_integer "$selection" || [[ -z "${extension_paths[$selection]:-}" ]]; then
        print_warn "无效的选择。"
        press_enter_to_continue
        return
    fi

    print_warn "即将删除扩展：${extension_names[$selection]}"
    print_info "路径：${extension_paths[$selection]}"

    if ! ask_confirm "确认删除这个扩展吗？" "n"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    create_backup "${extension_paths[$selection]}"
    if rm -rf "${extension_paths[$selection]}"; then
        print_success "扩展已删除：${extension_names[$selection]}"
    else
        print_error "删除扩展失败。"
    fi

    press_enter_to_continue
}
