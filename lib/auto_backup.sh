#!/usr/bin/env bash

write_shell_auto_backup_block() {
    local output_file="$1"
    local escaped_user="$2"

    cat > "$output_file" <<EOF
# === FOXIUM AUTO BACKUP START ===
FOXIUM_USER="${escaped_user}"
FOXIUM_ST_ROOT="\$(cd "\$(dirname "\$0")" && pwd)"
FOXIUM_BACKUP_PARENT_DIR="\${FOXIUM_ST_ROOT}/foxiumV2/STbackupF"
FOXIUM_BACKUP_TIMESTAMP="\$(date +"%Y%m%d_%H%M%S")"
FOXIUM_BACKUP_DIR="\${FOXIUM_BACKUP_PARENT_DIR}/auto_backup_\${FOXIUM_BACKUP_TIMESTAMP}"
FOXIUM_BACKUP_TMP="\${FOXIUM_BACKUP_DIR}.tmp"
FOXIUM_BACKUP_KEEP=3

# 先复制到 .tmp，确认复制成功后才改名为正式备份并清理旧备份，
# 任何失败都不会影响上一次的备份。
mkdir -p "\$FOXIUM_BACKUP_PARENT_DIR"
rm -rf "\$FOXIUM_BACKUP_TMP"
mkdir -p "\$FOXIUM_BACKUP_TMP"

foxium_backup_failed=0

foxium_backup_if_exists() {
    local input_path="\$1"
    local destination_name="\$2"
    if [[ -e "\$input_path" ]]; then
        if ! cp -R "\$input_path" "\$FOXIUM_BACKUP_TMP/\$destination_name"; then
            echo "[Foxium] 备份失败: \$input_path"
            foxium_backup_failed=1
        fi
    fi
}

echo "[Foxium] Running auto backup..."
foxium_backup_if_exists "\${FOXIUM_ST_ROOT}/data/\${FOXIUM_USER}/worlds" "worlds"
foxium_backup_if_exists "\${FOXIUM_ST_ROOT}/data/\${FOXIUM_USER}/characters" "characters"
foxium_backup_if_exists "\${FOXIUM_ST_ROOT}/data/\${FOXIUM_USER}/OpenAI Settings" "OpenAI_Settings"
foxium_backup_if_exists "\${FOXIUM_ST_ROOT}/data/\${FOXIUM_USER}/QuickReplies" "QuickReplies"
foxium_backup_if_exists "\${FOXIUM_ST_ROOT}/data/\${FOXIUM_USER}/settings.json" "settings.json"

foxium_backup_entries="\$(compgen -G "\$FOXIUM_BACKUP_TMP/*")"

if [[ "\$foxium_backup_failed" != "0" || -z "\$foxium_backup_entries" ]]; then
    echo "[Foxium] Auto backup failed: 复制出错或未找到 data 目录，本次没有生成备份，旧备份保持原样。"
    rm -rf "\$FOXIUM_BACKUP_TMP"
else
    mv "\$FOXIUM_BACKUP_TMP" "\$FOXIUM_BACKUP_DIR"
    echo "[Foxium] Auto backup completed: \$FOXIUM_BACKUP_DIR (\$(du -sh "\$FOXIUM_BACKUP_DIR" 2>/dev/null | cut -f1))"

    foxium_backup_dirs=()
    for foxium_dir in "\$FOXIUM_BACKUP_PARENT_DIR"/auto_backup_*; do
        [[ -d "\$foxium_dir" ]] || continue
        case "\$foxium_dir" in *.tmp) continue ;; esac
        foxium_backup_dirs+=("\$foxium_dir")
    done

    foxium_backup_sorted=()
    while IFS= read -r foxium_dir; do
        [[ -n "\$foxium_dir" ]] && foxium_backup_sorted+=("\$foxium_dir")
    done < <(printf '%s\n' "\${foxium_backup_dirs[@]}" | sort -r)

    foxium_backup_kept=0
    for foxium_dir in "\${foxium_backup_sorted[@]}"; do
        foxium_backup_kept=\$((foxium_backup_kept + 1))
        [[ "\$foxium_backup_kept" -le "\$FOXIUM_BACKUP_KEEP" ]] || rm -rf "\$foxium_dir"
    done
fi
echo
# === FOXIUM AUTO BACKUP END ===

EOF
}

write_batch_auto_backup_block() {
    local output_file="$1"
    local batch_user="$2"

    cat > "$output_file" <<EOF
:: === FOXIUM AUTO BACKUP START ===
set "FOXIUM_USER=${batch_user}"
set "FOXIUM_BACKUP_PARENT_DIR=%~dp0foxiumV2\\STbackupF"
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "FOXIUM_BACKUP_TIMESTAMP=%%A"
set "FOXIUM_BACKUP_DIR=%FOXIUM_BACKUP_PARENT_DIR%\\auto_backup_%FOXIUM_BACKUP_TIMESTAMP%"
set "FOXIUM_BACKUP_TMP=%FOXIUM_BACKUP_DIR%.tmp"
set "FOXIUM_BACKUP_KEEP=3"

:: Copy into .tmp first; only rename to a real backup and prune old ones
:: after the copy succeeded, so a failure never touches previous backups.
if not exist "%FOXIUM_BACKUP_PARENT_DIR%" mkdir "%FOXIUM_BACKUP_PARENT_DIR%" >nul 2>&1
if exist "%FOXIUM_BACKUP_TMP%" rd /s /q "%FOXIUM_BACKUP_TMP%" 2>nul
mkdir "%FOXIUM_BACKUP_TMP%" >nul 2>&1

set "FOXIUM_BACKUP_FAILED="
echo [Foxium] Running auto backup...
if exist "%~dp0data\\%FOXIUM_USER%\\worlds" (
    xcopy "%~dp0data\\%FOXIUM_USER%\\worlds" "%FOXIUM_BACKUP_TMP%\\worlds\\" /E /Y /I /C /H /R /Q >nul 2>&1
    if errorlevel 1 set "FOXIUM_BACKUP_FAILED=1"
)
if exist "%~dp0data\\%FOXIUM_USER%\\characters" (
    xcopy "%~dp0data\\%FOXIUM_USER%\\characters" "%FOXIUM_BACKUP_TMP%\\characters\\" /E /Y /I /C /H /R /Q >nul 2>&1
    if errorlevel 1 set "FOXIUM_BACKUP_FAILED=1"
)
if exist "%~dp0data\\%FOXIUM_USER%\\OpenAI Settings" (
    xcopy "%~dp0data\\%FOXIUM_USER%\\OpenAI Settings" "%FOXIUM_BACKUP_TMP%\\OpenAI_Settings\\" /E /Y /I /C /H /R /Q >nul 2>&1
    if errorlevel 1 set "FOXIUM_BACKUP_FAILED=1"
)
if exist "%~dp0data\\%FOXIUM_USER%\\QuickReplies" (
    xcopy "%~dp0data\\%FOXIUM_USER%\\QuickReplies" "%FOXIUM_BACKUP_TMP%\\QuickReplies\\" /E /Y /I /C /H /R /Q >nul 2>&1
    if errorlevel 1 set "FOXIUM_BACKUP_FAILED=1"
)
if exist "%~dp0data\\%FOXIUM_USER%\\settings.json" (
    copy "%~dp0data\\%FOXIUM_USER%\\settings.json" "%FOXIUM_BACKUP_TMP%\\settings.json" /Y >nul 2>&1
    if errorlevel 1 set "FOXIUM_BACKUP_FAILED=1"
)

for /f %%C in ('dir /b /a "%FOXIUM_BACKUP_TMP%" 2^>nul ^| find /c /v ""') do set "FOXIUM_BACKUP_ITEMS=%%C"

if defined FOXIUM_BACKUP_FAILED goto foxium_backup_failed
if "%FOXIUM_BACKUP_ITEMS%"=="0" goto foxium_backup_failed

move "%FOXIUM_BACKUP_TMP%" "%FOXIUM_BACKUP_DIR%" >nul
echo [Foxium] Auto backup completed: %FOXIUM_BACKUP_DIR%
for /f "skip=%FOXIUM_BACKUP_KEEP% delims=" %%D in ('dir /b /ad /o-n "%FOXIUM_BACKUP_PARENT_DIR%\\auto_backup_*" 2^>nul') do rd /s /q "%FOXIUM_BACKUP_PARENT_DIR%\\%%D" 2>nul
goto foxium_backup_done

:foxium_backup_failed
echo [Foxium] Auto backup failed: copy error or data directory not found; previous backups are kept.
rd /s /q "%FOXIUM_BACKUP_TMP%" 2>nul

:foxium_backup_done
echo.
:: === FOXIUM AUTO BACKUP END ===

EOF
}

insert_auto_backup_block() {
    local target_file="$1"
    local block_file="$2"
    local temp_file

    temp_file="$(make_temp_next_to "$target_file")" || return 1
    if awk 'FNR == NR { block = block $0 ORS; next }
        !inserted && $0 ~ /node/ && $0 ~ /server\.js/ {
            printf "%s", block
            inserted = 1
        }
        { print }
        END { exit inserted ? 0 : 1 }
    ' "$block_file" "$target_file" > "$temp_file"; then
        mv "$temp_file" "$target_file"
        return 0
    fi

    rm -f "$temp_file"
    return 1
}

enable_auto_backup() {
    print_title "启用自动备份"
    print_info "此功能会把自动备份代码注入到 start.sh 或 Windows 启动脚本中。"
    print_info "自动备份会在每次启动前备份 worlds / characters / OpenAI Settings / QuickReplies / settings.json，并保留最近 3 份。"

    printf '%s\n' "1. Termux / Linux (修改 start.sh)"
    printf '%s\n' "2. Windows (修改 Start.bat 或 start.bat)"
    printf '%s\n' "0. 返回"

    local env_choice target_file block_file marker escaped_user batch_user
    while true; do
        prompt_choice "请选择 [0-2]: " env_choice
        case "$env_choice" in
            1)
                target_file="${ST_DIR}/start.sh"
                break
                ;;
            2)
                if ! choose_windows_start_script target_file; then
                    print_error "未找到 Windows 启动脚本。"
                    press_enter_to_continue
                    return
                fi
                break
                ;;
            0)
                return
                ;;
            *)
                print_warn "无效的选项。"
                ;;
        esac
    done

    if [[ ! -f "$target_file" ]]; then
        print_error "启动脚本不存在：$target_file"
        press_enter_to_continue
        return
    fi

    if grep -Fq "FOXIUM AUTO BACKUP START" "$target_file"; then
        print_warn "目标启动脚本已经启用了 Foxium 自动备份。"
        press_enter_to_continue
        return
    fi

    if ! ask_confirm "确认修改 ${target_file} 吗？" "y"; then
        print_info "操作已取消。"
        press_enter_to_continue
        return
    fi

    create_backup "$target_file" || {
        press_enter_to_continue
        return
    }
    block_file="$(make_temp_next_to "$target_file")" || {
        print_error "无法创建临时文件。"
        press_enter_to_continue
        return
    }

    if [[ "$env_choice" == "1" ]]; then
        escaped_user="${USER_NAME//\\/\\\\}"
        escaped_user="${escaped_user//\"/\\\"}"
        write_shell_auto_backup_block "$block_file" "$escaped_user"
    else
        batch_user="${USER_NAME//%/%%}"
        write_batch_auto_backup_block "$block_file" "$batch_user"
    fi

    if insert_auto_backup_block "$target_file" "$block_file"; then
        rm -f "$block_file"
        print_success "已启用自动备份。"
    else
        rm -f "$block_file"
        print_error "未找到合适的插入点，修改失败。"
    fi

    press_enter_to_continue
}
