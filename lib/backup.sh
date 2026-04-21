#!/usr/bin/env bash

init_backup_session() {
    if [[ -z "$BACKUP_ROOT" ]]; then
        print_error "备份根目录尚未初始化。"
        return 1
    fi

    if [[ ! -d "$BACKUP_ROOT" ]]; then
        print_info "创建备份根目录: $BACKUP_ROOT"
        if ! mkdir -p "$BACKUP_ROOT"; then
            print_error "无法创建备份根目录。"
            return 1
        fi
    fi

    local timestamp random_suffix session_name
    timestamp="$(date +"%Y%m%d_%H%M%S")"

    while true; do
        random_suffix="$(printf '%04X' "$((RANDOM % 65536))")"
        session_name="${timestamp}_${random_suffix}"
        BACKUP_SESSION_DIR="${BACKUP_ROOT}/${session_name}"

        if [[ ! -e "$BACKUP_SESSION_DIR" ]]; then
            if mkdir -p "$BACKUP_SESSION_DIR"; then
                print_success "已创建本次备份会话目录: $BACKUP_SESSION_DIR"
                return 0
            fi

            print_error "创建备份会话目录失败。"
            return 1
        fi
    done
}

resolve_backup_destination() {
    local input_path="$1"
    local base_name="$2"
    local candidate_path="${BACKUP_SESSION_DIR}/${base_name}"
    local index=2

    if [[ ! -e "$candidate_path" ]]; then
        printf '%s' "$candidate_path"
        return 0
    fi

    while [[ -e "${BACKUP_SESSION_DIR}/${index}_${base_name}" ]]; do
        ((index++))
    done

    printf '%s' "${BACKUP_SESSION_DIR}/${index}_${base_name}"
}

create_backup() {
    local input_path="$1"

    if [[ -z "$BACKUP_SESSION_DIR" ]]; then
        print_error "备份会话目录尚未准备好。"
        return 1
    fi

    if [[ ! -e "$input_path" ]]; then
        print_warn "源文件或目录不存在，跳过备份: $input_path"
        return 1
    fi

    local base_name destination
    base_name="$(basename "$input_path")"
    destination="$(resolve_backup_destination "$input_path" "$base_name")" || return 1

    if [[ -d "$input_path" ]]; then
        if cp -R "$input_path" "$destination"; then
            print_success "已备份目录: $destination"
            return 0
        fi
    else
        if cp "$input_path" "$destination"; then
            print_success "已备份文件: $destination"
            return 0
        fi
    fi

    print_error "备份失败: $input_path"
    return 1
}
