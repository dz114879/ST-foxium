#!/usr/bin/env bash
#
# 把 main.sh 与 lib/ 拼成发布用单文件 build/ffss.sh。
#
# 规则：以 main.sh 为骨架，把每一行 `source "./lib/X.sh"` 替换成 X 的内容
# （去掉各自的 shebang），最后整体包上 File/End File 标记。产物格式与历史
# 发布文件保持一致，tests/static_checks.bats 会逐文件比对两者是否同步。

set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUTPUT="${BUNDLE_ROOT}/build/ffss.sh"
BUNDLE_DATE="$(date +"%Y-%m-%d %H:%M:%S")"

emit_marker() {
    printf '%s\n' '################################################################################'
    printf '#  %s  %s\n' "$1" "$2"
    printf '#  Bundle Date: %s\n' "$BUNDLE_DATE"
    printf '%s\n\n' '################################################################################'
}

emit_section() {
    local source_file="$1"
    local display_name="$2"

    emit_marker "File:" "$display_name"
    tail -n +2 "$source_file"
    printf '\n'
    emit_marker "End File:" "$display_name"
}

{
    printf '#!/usr/bin/env bash\n\n'

    emit_marker "File:" "./foxiumV2/main.sh"

    while IFS= read -r line; do
        case "$line" in
            'source "./lib/'*'.sh"')
                lib_name="$(printf '%s' "$line" | sed -E 's#^source "\./lib/(.+)"$#\1#')"
                emit_section "${BUNDLE_ROOT}/lib/${lib_name}" "foxiumV2/./lib/${lib_name}"
                ;;
            *)
                printf '%s\n' "$line"
                ;;
        esac
    done < <(tail -n +2 "${BUNDLE_ROOT}/main.sh")

    emit_marker "End File:" "./foxiumV2/main.sh"
} > "$OUTPUT"

printf '已生成 %s\n' "$OUTPUT"
