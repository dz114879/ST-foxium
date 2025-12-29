#!/data/data/com.termux/files/usr/bin/bash

# ========================================
# Foxium - SillyTavern 综合优化小工具
# 作者：KKTsN（橘狐） & limcode
# 适用于 Termux/Android 环境
# 本工具免费分发于GitHub与Discord 类脑
# ========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 全局变量
# 使用更可靠的方式获取脚本所在目录
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# 如果 readlink -f 失败（某些系统不支持），则使用备用方法
if [ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
ST_DIR=""
BACKUP_DIR="${SCRIPT_DIR}/STbackupF"
USER_NAME="default-user"
USER_DIR=""

# ========================================
# 工具函数
# ========================================

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_title() {
    echo -e "\n${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}\n"
}

print_risk() {
    echo -e "${RED}${BOLD}[风险操作]${NC} $1"
}

# 询问用户确认
ask_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        echo -ne "${YELLOW}${prompt} [Y/n]: ${NC}"
    else
        echo -ne "${YELLOW}${prompt} [y/N]: ${NC}"
    fi
    
    read -r response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 创建备份
create_backup() {
    local source_file="$1"
    local backup_name="$2"
    
    if [ ! -f "$source_file" ] && [ ! -d "$source_file" ]; then
        print_warning "源文件/目录不存在: $source_file"
        return 1
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="${BACKUP_DIR}/${backup_name}_${timestamp}"
    
    if [ -d "$source_file" ]; then
        cp -r "$source_file" "$backup_path"
    else
        cp "$source_file" "$backup_path"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "已备份到: $backup_path"
        return 0
    else
        print_error "备份失败: $source_file"
        return 1
    fi
}

# ========================================
# 启动检查
# ========================================

check_st_directory() {
    print_title "检查 SillyTavern 目录"
    
    # 显示调试信息
    print_info "脚本所在目录: $SCRIPT_DIR"
    print_info "当前工作目录: $(pwd)"
    echo ""
    
    # 检查常见的 ST 目录名
    local possible_dirs=("SillyTavern" "sillytavern" "ST" "st" "SillyTavern-git" "SillyTavern-zip")
    
    print_info "正在查找 SillyTavern 目录..."
    echo ""
    
    for dir in "${possible_dirs[@]}"; do
        local check_path="${SCRIPT_DIR}/${dir}"
        echo "  检查: $check_path"
        
        if [ -d "$check_path" ]; then
            echo "    ${GREEN}✓${NC} 目录存在"
            # 检查关键文件是否存在
            if [ -f "${check_path}/server.js" ] && [ -f "${check_path}/package.json" ]; then
                echo "    ${GREEN}✓${NC} 包含 server.js 和 package.json"
                print_info "找到有效的 SillyTavern 目录: $check_path"
                if ask_confirm "是否使用此目录?"; then
                    ST_DIR="$check_path"
                    print_success "已设置 ST 目录: $ST_DIR"
                    return 0
                fi
            else
                echo "    ${RED}✗${NC} 缺少关键文件 (server.js 或 package.json)"
            fi
        else
            echo "    ${RED}✗${NC} 目录不存在"
        fi
    done
    
    echo ""
    # 未找到，让用户手动输入
    print_warning "未找到 SillyTavern 目录"
    print_info "提示: 如果 SillyTavern 在当前目录，请输入完整路径"
    print_info "例如: ${SCRIPT_DIR}/SillyTavern 或使用绝对路径"
    echo ""
    echo -ne "${YELLOW}请输入 SillyTavern 目录的完整路径: ${NC}"
    read -r user_path
    
    # 如果用户输入的是相对路径，尝试转换为绝对路径
    if [[ "$user_path" != /* ]]; then
        # 相对路径，基于脚本目录
        user_path="${SCRIPT_DIR}/${user_path}"
    fi
    
    if [ -d "$user_path" ] && [ -f "${user_path}/server.js" ] && [ -f "${user_path}/package.json" ]; then
        ST_DIR="$user_path"
        print_success "已设置 ST 目录: $ST_DIR"
        return 0
    else
        print_error "无效的 SillyTavern 目录"
        if [ ! -d "$user_path" ]; then
            print_error "目录不存在: $user_path"
        elif [ ! -f "${user_path}/server.js" ]; then
            print_error "缺少 server.js 文件"
        elif [ ! -f "${user_path}/package.json" ]; then
            print_error "缺少 package.json 文件"
        fi
        return 1
    fi
}

check_backup_directory() {
    print_title "检查备份目录"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "创建备份目录: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        if [ $? -eq 0 ]; then
            print_success "备份目录创建成功"
        else
            print_error "备份目录创建失败"
            return 1
        fi
    else
        print_success "备份目录已存在: $BACKUP_DIR"
    fi
    
    return 0
}

check_user_directory() {
    print_title "设置用户目录"
    
    echo -ne "${YELLOW}请输入用户名 [默认: default-user]: ${NC}"
    read -r input_user
    
    if [ -n "$input_user" ]; then
        USER_NAME="$input_user"
    fi
    
    USER_DIR="${ST_DIR}/data/${USER_NAME}"
    
    if [ -d "$USER_DIR" ]; then
        print_success "用户目录: $USER_DIR"
        return 0
    else
        print_warning "用户目录不存在: $USER_DIR"
        if ask_confirm "是否创建此用户目录?"; then
            mkdir -p "$USER_DIR"
            print_success "用户目录创建成功"
            return 0
        else
            print_error "用户目录未设置"
            return 1
        fi
    fi
}

run_startup_checks() {
    print_title "Foxium 启动检查"
    
    if ! check_st_directory; then
        print_error "启动检查失败: 无法找到 SillyTavern 目录"
        exit 1
    fi
    
    if ! check_backup_directory; then
        print_error "启动检查失败: 无法创建备份目录"
        exit 1
    fi
    
    if ! check_user_directory; then
        print_error "启动检查失败: 用户目录未设置"
        exit 1
    fi
    
    print_success "所有启动检查完成！"
    echo ""
    print_info "ST 目录: $ST_DIR"
    print_info "备份目录: $BACKUP_DIR"
    print_info "用户目录: $USER_DIR"
    echo ""
}

# ========================================
# 备份功能
# ========================================

manual_backup() {
    print_title "手动备份"
    
    print_info "请选择要备份的内容:"
    echo "1. 世界书 (worlds)"
    echo "2. 角色卡 (characters)"
    echo "3. 聊天补全预设 (OpenAI Settings)"
    echo "4. 快速回复 (QuickReplies)"
    echo "5. settings.json"
    echo "6. secrets.json ${RED}(包含敏感信息)${NC}"
    echo "7. config.yaml"
    echo "8. 聊天记录 (chats) ${RED}(可能很大)${NC}"
    echo "9. '为自己安装'扩展 (extensions)"
    echo "10. '为所有人安装'扩展 (third-party)"
    echo "11. 全部备份"
    echo "0. 返回主菜单"
    
    echo -ne "\n${YELLOW}请输入选项 [0-11]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            if [ -d "${USER_DIR}/worlds" ]; then
                create_backup "${USER_DIR}/worlds" "worlds"
            else
                print_warning "世界书目录不存在"
            fi
            ;;
        2)
            if [ -d "${USER_DIR}/characters" ]; then
                create_backup "${USER_DIR}/characters" "characters"
            else
                print_warning "角色卡目录不存在"
            fi
            ;;
        3)
            if [ -d "${USER_DIR}/OpenAI Settings" ]; then
                create_backup "${USER_DIR}/OpenAI Settings" "openai_settings"
            else
                print_warning "聊天补全预设目录不存在"
            fi
            ;;
        4)
            if [ -d "${USER_DIR}/QuickReplies" ]; then
                create_backup "${USER_DIR}/QuickReplies" "quick_replies"
            else
                print_warning "快速回复目录不存在"
            fi
            ;;
        5)
            if [ -f "${USER_DIR}/settings.json" ]; then
                create_backup "${USER_DIR}/settings.json" "settings"
            else
                print_warning "settings.json 不存在"
            fi
            ;;
        6)
            print_warning "secrets.json 包含 API 密钥等敏感信息"
            if ask_confirm "确认要备份 secrets.json 吗?"; then
                if [ -f "${USER_DIR}/secrets.json" ]; then
                    create_backup "${USER_DIR}/secrets.json" "secrets"
                else
                    print_warning "secrets.json 不存在"
                fi
            fi
            ;;
        7)
            if [ -f "${ST_DIR}/config.yaml" ]; then
                create_backup "${ST_DIR}/config.yaml" "config"
            else
                print_warning "config.yaml 不存在"
            fi
            ;;
        8)
            print_warning "聊天记录可能占用大量空间"
            if ask_confirm "确认要备份聊天记录吗?"; then
                if [ -d "${USER_DIR}/chats" ]; then
                    create_backup "${USER_DIR}/chats" "chats"
                else
                    print_warning "聊天记录目录不存在"
                fi
            fi
            ;;
        9)
            if [ -d "${USER_DIR}/extensions" ]; then
                create_backup "${USER_DIR}/extensions" "user_extensions"
            else
                print_warning "用户扩展目录不存在"
            fi
            ;;
        10)
            if [ -d "${ST_DIR}/public/scripts/extensions/third-party" ]; then
                create_backup "${ST_DIR}/public/scripts/extensions/third-party" "third_party_extensions"
            else
                print_warning "第三方扩展目录不存在"
            fi
            ;;
        11)
            print_info "开始全部备份..."
            [ -d "${USER_DIR}/worlds" ] && create_backup "${USER_DIR}/worlds" "worlds"
            [ -d "${USER_DIR}/characters" ] && create_backup "${USER_DIR}/characters" "characters"
            [ -d "${USER_DIR}/OpenAI Settings" ] && create_backup "${USER_DIR}/OpenAI Settings" "openai_settings"
            [ -d "${USER_DIR}/QuickReplies" ] && create_backup "${USER_DIR}/QuickReplies" "quick_replies"
            [ -f "${USER_DIR}/settings.json" ] && create_backup "${USER_DIR}/settings.json" "settings"
            [ -f "${ST_DIR}/config.yaml" ] && create_backup "${ST_DIR}/config.yaml" "config"
            [ -d "${USER_DIR}/extensions" ] && create_backup "${USER_DIR}/extensions" "user_extensions"
            [ -d "${ST_DIR}/public/scripts/extensions/third-party" ] && create_backup "${ST_DIR}/public/scripts/extensions/third-party" "third_party_extensions"
            
            if ask_confirm "是否也备份 secrets.json (包含敏感信息)?"; then
                [ -f "${USER_DIR}/secrets.json" ] && create_backup "${USER_DIR}/secrets.json" "secrets"
            fi
            
            if ask_confirm "是否也备份聊天记录 (可能很大)?"; then
                [ -d "${USER_DIR}/chats" ] && create_backup "${USER_DIR}/chats" "chats"
            fi
            
            print_success "全部备份完成！"
            ;;
        0)
            return
            ;;
        *)
            print_error "无效的选项"
            ;;
    esac
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 自动备份设置
auto_backup_setup() {
    print_title "自动备份设置"
    
    print_info "此功能将:"
    echo "  1. 修改 start.sh，在启动 ST 前自动执行备份"
    echo "  2. 备份范围包括所有重要数据（世界书、角色卡、设置等）"
    echo "  3. 每次启动 ST 时自动创建带时间戳的备份"
    echo ""
    print_warning "注意事项："
    echo "  - 启用后，每次启动 ST 都会执行备份，可能略微延长启动时间"
    echo "  - 备份文件会累积，请定期清理旧备份"
    echo "  - 若要禁用，需要手动编辑 start.sh 删除备份代码"
    echo ""
    
    local start_sh="${ST_DIR}/start.sh"
    
    # 检查 start.sh 是否存在
    if [ ! -f "$start_sh" ]; then
        print_error "start.sh 不存在: $start_sh"
        print_info "此功能仅适用于 Linux/Mac 环境的 ST"
        echo ""
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    # 检查是否已经启用自动备份
    if grep -q "# === FOXIUM AUTO BACKUP START ===" "$start_sh"; then
        print_warning "自动备份已经启用！"
        print_info "如需禁用，请手动编辑 start.sh 删除备份代码"
        print_info "备份代码位于 '# === FOXIUM AUTO BACKUP START ===' 和 '# === FOXIUM AUTO BACKUP END ===' 之间"
        echo ""
        ask_confirm "按回车键继续..." "y"
        return 0
    fi
    
    if ! ask_confirm "确认启用自动备份吗?"; then
        print_info "操作已取消"
        echo ""
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    # 备份 start.sh
    print_info "备份 start.sh..."
    create_backup "$start_sh" "start_sh"
    
    # 生成备份代码
    print_info "生成备份代码..."
    
    local backup_code=$(cat <<'EOF'

# === FOXIUM AUTO BACKUP START ===
# 自动备份功能 - 由 Foxium 添加
# 若要禁用，请删除此段代码（从 START 到 END 标记之间的所有内容）

echo "执行自动备份..."
BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_BASE_DIR="$(dirname "$(pwd)")/STbackupF/auto_backup_${BACKUP_TIMESTAMP}"

# 创建备份目录
mkdir -p "${BACKUP_BASE_DIR}"

# 备份函数
backup_if_exists() {
    local source="$1"
    local dest_name="$2"
    if [ -e "$source" ]; then
        cp -r "$source" "${BACKUP_BASE_DIR}/${dest_name}" 2>/dev/null && echo "  ✓ 已备份: ${dest_name}" || echo "  ✗ 备份失败: ${dest_name}"
    fi
}

# 执行备份
backup_if_exists "data/default-user/worlds" "worlds"
backup_if_exists "data/default-user/characters" "characters"
backup_if_exists "data/default-user/OpenAI Settings" "OpenAI_Settings"
backup_if_exists "data/default-user/QuickReplies" "QuickReplies"
backup_if_exists "data/default-user/settings.json" "settings.json"
backup_if_exists "data/default-user/secrets.json" "secrets.json"
backup_if_exists "config.yaml" "config.yaml"
backup_if_exists "data/default-user/chats" "chats"
backup_if_exists "data/default-user/extensions" "user_extensions"
backup_if_exists "public/scripts/extensions/third-party" "third_party_extensions"

echo "自动备份完成: ${BACKUP_BASE_DIR}"
echo ""

# === FOXIUM AUTO BACKUP END ===

EOF
)
    
    # 在 start.sh 中插入备份代码
    # 找到 "echo \"Entering SillyTavern...\"" 这一行，在它之前插入备份代码
    print_info "修改 start.sh..."
    
    # 使用临时文件来处理插入
    local temp_file="${start_sh}.tmp"
    
    # 读取文件并在适当位置插入备份代码
    awk -v backup_code="$backup_code" '
    /echo "Entering SillyTavern..."/ {
        print backup_code
    }
    { print }
    ' "$start_sh" > "$temp_file"
    
    # 替换原文件
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$start_sh"
        chmod +x "$start_sh"
        print_success "自动备份已启用！"
        print_info "备份目录: ${BACKUP_DIR}/auto_backup_YYYYMMDD_HHMMSS/"
        print_info "每次启动 ST 时都会自动创建新的备份"
        echo ""
        print_warning "若要禁用自动备份，请手动编辑 start.sh"
        print_info "删除 '# === FOXIUM AUTO BACKUP START ===' 和 '# === FOXIUM AUTO BACKUP END ===' 之间的所有内容"
    else
        print_error "修改 start.sh 失败"
        rm -f "$temp_file"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# ========================================
# 修复功能
# ========================================

# 修复功能 1: 修复无法安装 npm/node 包问题
fix_npm_install() {
    print_title "修复 npm 安装问题"
    
    print_info "此功能将:"
    echo "  1. 备份并删除 node_modules 和 package-lock.json"
    echo "  2. 使用淘宝镜像源重新执行 npm install"
    echo "  本功能适用于因node包等问题而无法启动酒馆的情况，典型报错信息为cannot find package..."
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        return
    fi
    
    cd "$ST_DIR" || return 1
    
    # 备份 package-lock.json
    if [ -f "package-lock.json" ]; then
        print_info "备份 package-lock.json..."
        create_backup "package-lock.json" "package-lock"
    fi
    
    # 删除 node_modules
    if [ -d "node_modules" ]; then
        print_info "删除 node_modules..."
        rm -rf node_modules
    fi
    
    # 删除 package-lock.json
    if [ -f "package-lock.json" ]; then
        print_info "删除 package-lock.json..."
        rm -f package-lock.json
    fi
    
    # 使用淘宝镜像源安装
    print_info "使用淘宝镜像源安装依赖..."
    npm install --registry=https://registry.npmmirror.com
    
    if [ $? -eq 0 ]; then
        print_success "npm 依赖安装成功！"
    else
        print_error "npm 依赖安装失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 2: 修复 UI 主题导致卡死
fix_theme_freeze() {
    print_title "修复 UI 主题卡死问题"
    
    print_info "此功能将:"
    echo "  1. 备份 settings.json"
    echo "  2. 将主题设置为 'Dark Lite'"
    echo "  当选择了不兼容或已删除的UI主题(美化)时，酒馆可能会卡死在网页加载期间，无法以正常方式进入并修改美化。本功能在酒馆外部修改美化为默认的Dark Lite"
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        return
    fi
    
    local settings_file="${USER_DIR}/settings.json"
    
    if [ ! -f "$settings_file" ]; then
        print_error "settings.json 不存在: $settings_file"
        return 1
    fi
    
    # 备份
    print_info "备份 settings.json..."
    create_backup "$settings_file" "settings"
    
    # 修改主题设置
    print_info "修改主题设置..."
    
    # 使用 sed 替换主题设置
    sed -i 's/"theme":[[:space:]]*"[^"]*"/"theme": "Dark Lite"/g' "$settings_file"
    
    if [ $? -eq 0 ]; then
        print_success "主题已设置为 'Dark Lite'"
    else
        print_error "主题设置失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 3: 修复扩展无法卸载
fix_extension_uninstall() {
    print_title "修复扩展无法卸载"
    
    print_info "此功能将列出所有已安装的扩展，您可以选择删除。适用于删除Zerxzlib等因漏洞而无法在酒馆内正常卸载的扩展"
    echo ""
    
    local user_ext_dir="${USER_DIR}/extensions"
    local third_party_dir="${ST_DIR}/public/scripts/extensions/third-party"
    
    # 收集扩展列表
    declare -a extensions
    declare -a ext_paths
    local index=1
    
    echo "${BOLD}已安装的扩展:${NC}"
    echo ""
    
    # 用户扩展
    if [ -d "$user_ext_dir" ]; then
        echo "${CYAN}[为自己安装的扩展]${NC}"
        for ext in "$user_ext_dir"/*/ ; do
            if [ -d "$ext" ]; then
                local ext_name=$(basename "$ext")
                echo "  $index. $ext_name ${BLUE}(用户扩展)${NC}"
                extensions[$index]="$ext_name"
                ext_paths[$index]="$ext"
                ((index++))
            fi
        done
        echo ""
    fi
    
    # 第三方扩展
    if [ -d "$third_party_dir" ]; then
        echo "${CYAN}[为所有人安装的扩展]${NC}"
        for ext in "$third_party_dir"/*/ ; do
            if [ -d "$ext" ]; then
                local ext_name=$(basename "$ext")
                echo "  $index. $ext_name ${MAGENTA}(第三方扩展)${NC}"
                extensions[$index]="$ext_name"
                ext_paths[$index]="$ext"
                ((index++))
            fi
        done
        echo ""
    fi
    
    if [ ${#extensions[@]} -eq 0 ]; then
        print_warning "未找到任何已安装的扩展"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    echo "0. 返回主菜单"
    echo ""
    echo -ne "${YELLOW}请选择要删除的扩展编号 [0-$((index-1))]: ${NC}"
    read -r choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    if [ -z "${extensions[$choice]}" ]; then
        print_error "无效的选项"
        return
    fi
    
    local selected_ext="${extensions[$choice]}"
    local selected_path="${ext_paths[$choice]}"
    
    print_warning "即将删除扩展: $selected_ext"
    print_info "路径: $selected_path"
    
    if ask_confirm "确认删除此扩展吗?"; then
        # 备份
        print_info "备份扩展..."
        create_backup "$selected_path" "extension_${selected_ext}"
        
        # 删除
        print_info "删除扩展..."
        rm -rf "$selected_path"
        
        if [ $? -eq 0 ]; then
            print_success "扩展已删除: $selected_ext"
        else
            print_error "扩展删除失败"
        fi
    else
        print_info "操作已取消"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 4: 修复端口冲突
fix_port_conflict() {
    print_title "修复端口冲突"
    
    print_info "此功能将修改 SillyTavern 的监听端口"
    echo "  当前配置文件: ${ST_DIR}/config.yaml"
    echo ""
    
    local config_file="${ST_DIR}/config.yaml"
    
    if [ ! -f "$config_file" ]; then
        print_error "config.yaml 不存在: $config_file"
        return 1
    fi
    
    # 读取当前端口
    local current_port=$(grep -E '^[[:space:]]*port:' "$config_file" | sed -E 's/^[[:space:]]*port:[[:space:]]*([0-9]+).*/\1/')
    
    if [ -n "$current_port" ]; then
        print_info "当前端口: $current_port"
    else
        print_warning "无法读取当前端口，默认为 8000"
        current_port=8000
    fi
    
    echo ""
    print_info "推荐端口范围: 10000 - 49151"
    print_warning "禁止使用的端口: 0-1023, 2049, 5000, 6000, 6665-6669, 5357, 49152-65535"
    print_warning "高风险端口: 3000/3001, 7000/7001, 8000, 8080, 8888, 8889, 8844, 8484, 5432, 6379, 27017, 3306, 1080, 7890, 7897, 10808"
    echo ""
    
    # 生成随机端口
    local random_port=$((10000 + RANDOM % 39152))
    
    echo -ne "${YELLOW}请输入新端口 [默认随机生成: $random_port]: ${NC}"
    read -r input_port
    
    local new_port
    if [ -z "$input_port" ]; then
        new_port=$random_port
    else
        new_port=$input_port
    fi
    
    # 验证端口号
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
        print_error "无效的端口号: $new_port"
        return 1
    fi
    
    # 检查禁止端口
    if [ $new_port -lt 1024 ] || [ $new_port -eq 2049 ] || [ $new_port -eq 5000 ] || [ $new_port -eq 6000 ] || 
       ([ $new_port -ge 6665 ] && [ $new_port -le 6669 ]) || [ $new_port -eq 5357 ] || [ $new_port -ge 49152 ]; then
        print_error "此端口被禁止使用: $new_port"
        return 1
    fi
    
    # 检查高风险端口
    local high_risk_ports=(3000 3001 7000 7001 8000 8080 8888 8889 8844 8484 5432 6379 27017 3306 1080 7890 7897 10808)
    for risk_port in "${high_risk_ports[@]}"; do
        if [ $new_port -eq $risk_port ]; then
            print_warning "端口 $new_port 有较高冲突风险！"
            if ! ask_confirm "确认仍要使用此端口吗?"; then
                print_info "操作已取消"
                return
            fi
            break
        fi
    done
    
    print_info "将端口设置为: $new_port"
    
    if ! ask_confirm "确认修改端口吗?"; then
        print_info "操作已取消"
        return
    fi
    
    # 备份
    print_info "备份 config.yaml..."
    create_backup "$config_file" "config"
    
    # 修改端口
    print_info "修改端口设置..."
    sed -i "s/^[[:space:]]*port:[[:space:]]*[0-9]*/port: $new_port/" "$config_file"
    
    if [ $? -eq 0 ]; then
        print_success "端口已修改为: $new_port"
        print_info "请重启 SillyTavern 以应用更改"
    else
        print_error "端口修改失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 5: 修复无法打开聊天导致卡死
fix_chat_loading() {
    print_title "修复无法打开聊天导致卡死"
    
    print_info "此功能将:"
    echo "  1. 禁用自动加载聊天 (settings.json)"
    echo "  2. 启用角色懒加载 (config.yaml)"
    echo "  当某个聊天记录损坏或过大时，可能导致酒馆卡死，无法正常进入以删除聊天。此功能可以防止自动加载问题聊天。"
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        return
    fi
    
    local settings_file="${USER_DIR}/settings.json"
    local config_file="${ST_DIR}/config.yaml"
    local success_count=0
    
    # 修改 settings.json
    if [ -f "$settings_file" ]; then
        print_info "备份 settings.json..."
        create_backup "$settings_file" "settings"
        
        print_info "修改 settings.json 中的 auto_load_chat..."
        
        # 使用 sed 替换 auto_load_chat 设置
        sed -i 's/"auto_load_chat"[[:space:]]*:[[:space:]]*true/"auto_load_chat": false/g' "$settings_file"
        
        if [ $? -eq 0 ]; then
            print_success "已禁用自动加载聊天"
            ((success_count++))
        else
            print_error "修改 settings.json 失败"
        fi
    else
        print_warning "settings.json 不存在: $settings_file"
    fi
    
    # 修改 config.yaml
    if [ -f "$config_file" ]; then
        print_info "备份 config.yaml..."
        create_backup "$config_file" "config"
        
        print_info "修改 config.yaml 中的 lazyLoadCharacters..."
        
        # 使用 sed 替换 lazyLoadCharacters 设置
        sed -i 's/^[[:space:]]*lazyLoadCharacters:[[:space:]]*false/lazyLoadCharacters: true/g' "$config_file"
        
        if [ $? -eq 0 ]; then
            print_success "已启用角色懒加载"
            ((success_count++))
        else
            print_error "修改 config.yaml 失败"
        fi
    else
        print_warning "config.yaml 不存在: $config_file"
    fi
    
    echo ""
    if [ $success_count -eq 2 ]; then
        print_success "所有修改完成！请重启 SillyTavern 以应用更改"
    elif [ $success_count -gt 0 ]; then
        print_warning "部分修改完成，请检查日志"
    else
        print_error "修改失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 6: 修复 gemini-3 系列模型无法发送媒体
fix_gemini3_media() {
    print_title "修复 gemini-3 系列模型无法发送媒体"
    
    print_risk "这是一个风险操作！"
    print_info "此功能将:"
    echo "  在 openai.js 中直接添加 gemini-3 系列模型的媒体支持，允许使用旧版本酒馆向此系列模型发送音频，视频和图片"
    echo ""
    print_warning "此操作会直接修改 ST 核心文件，可能导致不可预期的问题"
    echo ""
    
    if ! ask_confirm "确认执行此风险操作吗?"; then
        print_info "操作已取消"
        return
    fi
    
    # 检查 ST 版本
    local package_json="${ST_DIR}/package.json"
    if [ ! -f "$package_json" ]; then
        print_error "package.json 不存在: $package_json"
        return 1
    fi
    
    print_info "检查 ST 版本..."
    local st_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$package_json" | sed 's/"version"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    
    if [ -z "$st_version" ]; then
        print_warning "无法读取 ST 版本，继续执行..."
    else
        print_info "当前 ST 版本: $st_version"
        
        # 简单的版本比较 (假设版本格式为 x.y.z)
        local major=$(echo "$st_version" | cut -d. -f1)
        local minor=$(echo "$st_version" | cut -d. -f2)
        
        if [ "$major" -gt 1 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 14 ]); then
            print_error "ST 版本 >= 1.14.0，此修复已被官方合并，无需执行"
            print_info "您的 SillyTavern 版本已包含 gemini-3 媒体支持"
            echo ""
            ask_confirm "按回车键继续..." "y"
            return
        fi
    fi
    
    # 检查 openai.js 文件
    local openai_js="${ST_DIR}/public/scripts/openai.js"
    if [ ! -f "$openai_js" ]; then
        print_error "openai.js 不存在: $openai_js"
        return 1
    fi
    
    # 备份
    print_info "备份 openai.js..."
    create_backup "$openai_js" "openai_js"
    
    # 修改文件
    print_info "添加 gemini-3 媒体支持..."
    
    # 修改 videoSupportedModels
    if grep -q "const videoSupportedModels = \[" "$openai_js"; then
        sed -i "/const videoSupportedModels = \[/a\\    'gemini-3'," "$openai_js"
        print_success "已添加到 videoSupportedModels"
    else
        print_warning "未找到 videoSupportedModels 定义"
    fi
    
    # 修改 audioSupportedModels
    if grep -q "const audioSupportedModels = \[" "$openai_js"; then
        sed -i "/const audioSupportedModels = \[/a\\    'gemini-3'," "$openai_js"
        print_success "已添加到 audioSupportedModels"
    else
        print_warning "未找到 audioSupportedModels 定义"
    fi
    
    # 修改 visionSupportedModels
    if grep -q "const visionSupportedModels = \[" "$openai_js"; then
        sed -i "/const visionSupportedModels = \[/a\\    'gemini-3'," "$openai_js"
        print_success "已添加到 visionSupportedModels"
    else
        print_warning "未找到 visionSupportedModels 定义"
    fi
    
    print_success "gemini-3 媒体支持修复完成！"
    print_info "请重启 SillyTavern 以应用更改"
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 修复功能 7: 强制更新 ST
force_update_st() {
    print_title "强制更新 SillyTavern"
    
    print_info "此功能将:"
    echo "  1. 检查 ST 是否为 git 安装版本"
    echo "  2. 切换到 release 稳定分支"
    echo "  3. 执行强制更新 (git pull --rebase --autostash)"
    echo ""
    print_warning "此操作会覆盖本地修改，请确保已备份重要数据"
    echo ""
    
    if ! ask_confirm "确认执行强制更新吗?"; then
        print_info "操作已取消"
        return
    fi
    
    # 检查是否为 git 仓库
    if [ ! -d "${ST_DIR}/.git" ]; then
        print_error "ST 目录不是 git 仓库"
        print_info "此功能仅适用于通过 git 安装的 SillyTavern"
        print_info "如果您使用的是 zip 包安装，请手动下载最新版本"
        echo ""
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    print_success "检测到 git 仓库"
    
    # 切换到 ST 目录
    cd "$ST_DIR" || return 1
    
    # 切换到 release 分支
    print_info "切换到 release 稳定分支..."
    git checkout release
    
    if [ $? -ne 0 ]; then
        print_error "切换分支失败"
        echo ""
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    print_success "已切换到 release 分支"
    
    # 执行强制更新
    print_info "执行强制更新..."
    git pull --rebase --autostash
    
    if [ $? -eq 0 ]; then
        print_success "SillyTavern 更新成功！"
        print_info "建议执行 npm install 以更新依赖"
        echo ""
        if ask_confirm "是否现在执行 npm install?"; then
            print_info "安装依赖..."
            npm install --registry=https://registry.npmmirror.com
            if [ $? -eq 0 ]; then
                print_success "依赖安装成功！"
            else
                print_error "依赖安装失败"
            fi
        fi
    else
        print_error "更新失败，请检查网络连接或手动更新"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}


# ========================================
# 优化功能
# ========================================

# 优化功能 1: 优化旧版本 ST 内存占用
optimize_memory_usage() {
    print_title "优化旧版本 ST 内存占用"
    
    print_info "此功能将:"
    echo "  1. 检查 ST 版本"
    echo "  2. 如果版本 < 1.13.5，则优化内存占用"
    echo "  3. 修改 users.js 和 characters.js 文件"
    echo "  本功能通过添加 expiredInterval: 0 配置来优化旧版本ST的内存占用"
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    # 检查 ST 版本
    local package_json="${ST_DIR}/package.json"
    if [ ! -f "$package_json" ]; then
        print_error "package.json 不存在: $package_json"
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    print_info "检查 ST 版本..."
    local st_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$package_json" | sed 's/"version"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    
    if [ -z "$st_version" ]; then
        print_warning "无法读取 ST 版本，继续执行..."
    else
        print_info "当前 ST 版本: $st_version"
        
        # 简单的版本比较 (假设版本格式为 x.y.z)
        local major=$(echo "$st_version" | cut -d. -f1)
        local minor=$(echo "$st_version" | cut -d. -f2)
        local patch=$(echo "$st_version" | cut -d. -f3)
        
        if [ "$major" -gt 1 ] || ([ "$major" -eq 1 ] && [ "$minor" -gt 13 ]) || ([ "$major" -eq 1 ] && [ "$minor" -eq 13 ] && [ "$patch" -ge 5 ]); then
            print_warning "ST 版本 >= 1.13.5，该修复已被官方合并，无需执行"
            echo ""
            ask_confirm "按回车键继续..." "y"
            return
        fi
    fi
    
    local success_count=0
    
    # 修改 users.js
    local users_js="${ST_DIR}/src/users.js"
    if [ -f "$users_js" ]; then
        print_info "备份 users.js..."
        create_backup "$users_js" "users_js"
        
        print_info "修改 users.js..."
        
        # 检查是否已经存在 expiredInterval
        if grep -q "ttl: false, // Never expire" "$users_js"; then
            # 检查下一行是否已经是 expiredInterval: 0,
            if grep -A 1 "ttl: false, // Never expire" "$users_js" | grep -q "expiredInterval: 0,"; then
                print_warning "users.js 已经包含 expiredInterval 配置，跳过"
            else
                # 在 ttl: false 行后插入 expiredInterval: 0,
                sed -i '/ttl: false, \/\/ Never expire/a\        expiredInterval: 0,' "$users_js"
                if [ $? -eq 0 ]; then
                    print_success "已修改 users.js"
                    ((success_count++))
                else
                    print_error "修改 users.js 失败"
                fi
            fi
        else
            print_warning "未找到 'ttl: false, // Never expire' 行"
        fi
    else
        print_warning "users.js 不存在: $users_js"
    fi
    
    # 修改 characters.js
    local characters_js="${ST_DIR}/src/endpoints/characters.js"
    if [ -f "$characters_js" ]; then
        print_info "备份 characters.js..."
        create_backup "$characters_js" "characters_js"
        
        print_info "修改 characters.js..."
        
        # 检查是否已经存在 expiredInterval
        if grep -q "forgiveParseErrors: true," "$characters_js"; then
            # 检查下一行是否已经是 expiredInterval: 0,
            if grep -A 1 "forgiveParseErrors: true," "$characters_js" | grep -q "expiredInterval: 0,"; then
                print_warning "characters.js 已经包含 expiredInterval 配置，跳过"
            else
                # 在 forgiveParseErrors: true, 行后插入 expiredInterval: 0,
                sed -i '/forgiveParseErrors: true,/a\            expiredInterval: 0,' "$characters_js"
                if [ $? -eq 0 ]; then
                    print_success "已修改 characters.js"
                    ((success_count++))
                else
                    print_error "修改 characters.js 失败"
                fi
            fi
        else
            print_warning "未找到 'forgiveParseErrors: true,' 行"
        fi
    else
        print_warning "characters.js 不存在: $characters_js"
    fi
    
    echo ""
    if [ $success_count -gt 0 ]; then
        print_success "内存优化完成！请重启 SillyTavern 以应用更改"
    else
        print_warning "未进行任何修改"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 优化功能 2: 解除聊天记录文件大小限制
remove_chat_size_limit() {
    print_title "解除聊天记录文件大小限制"
    
    print_info "此功能将:"
    echo "  1. 备份 server-main.js"
    echo "  2. 将 bodyParser 的 limit 从 500mb 改为 9999mb"
    echo "  本功能可以解除聊天记录文件大小限制，允许更大的聊天记录"
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    local server_main="${ST_DIR}/src/server-main.js"
    
    if [ ! -f "$server_main" ]; then
        print_error "server-main.js 不存在: $server_main"
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    # 备份
    print_info "备份 server-main.js..."
    create_backup "$server_main" "server_main_js"
    
    # 修改文件
    print_info "修改文件大小限制..."
    
    local success_count=0
    
    # 修改 bodyParser.json 的 limit
    if grep -q "app.use(bodyParser.json({ limit: '500mb' }));" "$server_main"; then
        sed -i "s/app\.use(bodyParser\.json({ limit: '500mb' }));/app.use(bodyParser.json({ limit: '9999mb' }));/" "$server_main"
        if [ $? -eq 0 ]; then
            print_success "已修改 bodyParser.json limit"
            ((success_count++))
        else
            print_error "修改 bodyParser.json limit 失败"
        fi
    else
        print_warning "未找到 bodyParser.json limit 配置"
    fi
    
    # 修改 bodyParser.urlencoded 的 limit
    if grep -q "app.use(bodyParser.urlencoded({ extended: true, limit: '500mb' }));" "$server_main"; then
        sed -i "s/app\.use(bodyParser\.urlencoded({ extended: true, limit: '500mb' }));/app.use(bodyParser.urlencoded({ extended: true, limit: '9999mb' }));/" "$server_main"
        if [ $? -eq 0 ]; then
            print_success "已修改 bodyParser.urlencoded limit"
            ((success_count++))
        else
            print_error "修改 bodyParser.urlencoded limit 失败"
        fi
    else
        print_warning "未找到 bodyParser.urlencoded limit 配置"
    fi
    
    echo ""
    if [ $success_count -eq 2 ]; then
        print_success "文件大小限制已解除！请重启 SillyTavern 以应用更改"
    elif [ $success_count -gt 0 ]; then
        print_warning "部分修改完成，请检查日志"
    else
        print_error "修改失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 优化功能 3: 更新聊天补全模型列表
update_model_list() {
    print_title "更新聊天补全模型列表"
    
    print_info "此功能将:"
    echo "  1. 在 index.html 中添加最新的 Google Gemini 模型"
    echo "  2. 在 index.html 中添加最新的 Claude 模型"
    echo "  3. 包括 gemini-3 和 gemini-2.5 系列"
    echo "  4. 包括 claude-opus-4-5、claude-sonnet-4-5、claude-haiku-4-5 系列"
    echo ""
    
    if ! ask_confirm "确认执行此操作吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    local index_html="${ST_DIR}/public/index.html"
    
    if [ ! -f "$index_html" ]; then
        print_error "index.html 不存在: $index_html"
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    # 备份
    print_info "备份 index.html..."
    create_backup "$index_html" "index_html"
    
    local success_count=0
    
    # 添加 Google Gemini 模型
    print_info "添加 Google Gemini 模型..."
    if grep -q '<select id="model_google_select">' "$index_html"; then
        # 检查是否已经添加过
        if grep -q "gemini-3-pro-preview" "$index_html"; then
            print_warning "Google Gemini 模型已存在，跳过"
        else
            # 在 <select id="model_google_select"> 后添加新模型
            sed -i '/<select id="model_google_select">/a\                                <optgroup label="Added by Foxium">\n                                    <option value="gemini-3-pro-preview">gemini-3-pro-preview</option>\n                                    <option value="gemini-3-pro-image-preview">gemini-3-pro-image-preview</option>\n                                    <option value="gemini-3-flash-preview">gemini-3-flash-preview</option>\n                                    <option value="gemini-2.5-pro">gemini-2.5-pro</option>\n                                    <option value="gemini-2.5-flash">gemini-2.5-flash</option>\n                                    <option value="gemini-2.5-flash-image-preview">gemini-2.5-flash-image-preview</option>\n                                </optgroup>' "$index_html"
            if [ $? -eq 0 ]; then
                print_success "已添加 Google Gemini 模型"
                ((success_count++))
            else
                print_error "添加 Google Gemini 模型失败"
            fi
        fi
    else
        print_warning "未找到 model_google_select"
    fi
    
    # 添加 Claude 模型
    print_info "添加 Claude 模型..."
    if grep -q '<select id="model_claude_select">' "$index_html"; then
        # 检查是否已经添加过
        if grep -q "claude-opus-4-5" "$index_html"; then
            print_warning "Claude 模型已存在，跳过"
        else
            # 在 <select id="model_claude_select"> 后添加新模型
            sed -i '/<select id="model_claude_select">/a\                                <optgroup label="Added by Foxium">\n                                    <option value="claude-opus-4-5">claude-opus-4-5</option>\n                                    <option value="claude-opus-4-5-20251101">claude-opus-4-5-20251101</option>\n                                    <option value="claude-sonnet-4-5">claude-sonnet-4-5</option>\n                                    <option value="claude-sonnet-4-5-20250929">claude-sonnet-4-5-20250929</option>\n                                    <option value="claude-haiku-4-5">claude-haiku-4-5</option>\n                                    <option value="claude-haiku-4-5-20251001">claude-haiku-4-5-20251001</option>\n                                </optgroup>' "$index_html"
            if [ $? -eq 0 ]; then
                print_success "已添加 Claude 模型"
                ((success_count++))
            else
                print_error "添加 Claude 模型失败"
            fi
        fi
    else
        print_warning "未找到 model_claude_select"
    fi
    
    echo ""
    if [ $success_count -gt 0 ]; then
        print_success "模型列表更新完成！请刷新浏览器以查看新模型"
    else
        print_warning "未进行任何修改"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 优化功能 4: 解除所有模型能力限制
remove_model_restrictions() {
    print_title "解除所有模型能力限制"
    
    print_risk "这是一个风险操作！"
    print_info "此功能将:"
    echo "  1. 强制所有模型支持图片内联"
    echo "  2. 强制所有模型支持视频内联"
    echo "  3. 修改 openai.js 中的能力检测函数"
    echo ""
    print_warning "此操作会直接修改 ST 核心文件，可能导致："
    print_warning "  - 向不支持多模态的模型发送图片/视频时出错"
    print_warning "  - API 调用失败或产生额外费用"
    print_warning "  - 不可预期的行为"
    echo ""
    
    if ! ask_confirm "确认执行此风险操作吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    print_warning "请再次确认：此操作有风险！"
    if ! ask_confirm "真的要继续吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    local openai_js="${ST_DIR}/public/scripts/openai.js"
    
    if [ ! -f "$openai_js" ]; then
        print_error "openai.js 不存在: $openai_js"
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    # 备份
    print_info "备份 openai.js..."
    create_backup "$openai_js" "openai_js"
    
    local success_count=0
    
    # 修改 isImageInliningSupported 函数
    print_info "修改图片内联支持检测..."
    if grep -q "export function isImageInliningSupported()" "$openai_js"; then
        # 在函数定义后添加 return true;
        sed -i '/export function isImageInliningSupported()/a\    return true;' "$openai_js"
        if [ $? -eq 0 ]; then
            print_success "已强制启用图片内联支持"
            ((success_count++))
        else
            print_error "修改图片内联支持失败"
        fi
    else
        print_warning "未找到 isImageInliningSupported 函数"
    fi
    
    # 修改 isVideoInliningSupported 函数
    print_info "修改视频内联支持检测..."
    if grep -q "export function isVideoInliningSupported()" "$openai_js"; then
        # 在函数定义后添加 return true;
        sed -i '/export function isVideoInliningSupported()/a\    return true;' "$openai_js"
        if [ $? -eq 0 ]; then
            print_success "已强制启用视频内联支持"
            ((success_count++))
        else
            print_error "修改视频内联支持失败"
        fi
    else
        print_warning "未找到 isVideoInliningSupported 函数"
    fi
    
    echo ""
    if [ $success_count -eq 2 ]; then
        print_success "模型能力限制已解除！请刷新浏览器以应用更改"
        print_warning "请谨慎使用此功能，确保您的模型支持相应的多模态能力"
    elif [ $success_count -gt 0 ]; then
        print_warning "部分修改完成，请检查日志"
    else
        print_error "修改失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}

# 优化功能 5: 一键对局域网开放
enable_lan_access() {
    print_title "一键对局域网开放"
    
    print_risk "这是一个风险操作！"
    print_info "此功能将:"
    echo "  1. 启用 listen 模式（允许外部访问）"
    echo "  2. 添加局域网 IP 段到白名单"
    echo "  3. 修改 config.yaml 配置"
    echo ""
    print_warning "此操作会使 SillyTavern 对局域网开放，可能导致："
    print_warning "  - 局域网内其他设备可以访问您的 ST"
    print_warning "  - 潜在的安全风险"
    print_warning "  - 未授权访问您的聊天记录和配置"
    echo ""
    print_info "将添加以下 IP 段到白名单："
    echo "  - 10.0.0.0/8 (A类私有网络)"
    echo "  - 172.16.0.0/12 (B类私有网络)"
    echo "  - 192.168.0.0/16 (C类私有网络)"
    echo ""
    
    if ! ask_confirm "确认执行此风险操作吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    print_warning "请再次确认：此操作会对局域网开放访问！"
    if ! ask_confirm "真的要继续吗?"; then
        print_info "操作已取消"
        ask_confirm "按回车键继续..." "y"
        return
    fi
    
    local config_file="${ST_DIR}/config.yaml"
    
    if [ ! -f "$config_file" ]; then
        print_error "config.yaml 不存在: $config_file"
        ask_confirm "按回车键继续..." "y"
        return 1
    fi
    
    # 备份
    print_info "备份 config.yaml..."
    create_backup "$config_file" "config"
    
    local success_count=0
    
    # 修改 listen 设置
    print_info "启用 listen 模式..."
    if grep -q "^[[:space:]]*listen:[[:space:]]*false" "$config_file"; then
        sed -i 's/^[[:space:]]*listen:[[:space:]]*false/listen: true/' "$config_file"
        if [ $? -eq 0 ]; then
            print_success "已启用 listen 模式"
            ((success_count++))
        else
            print_error "启用 listen 模式失败"
        fi
    else
        print_warning "listen 已经是 true 或未找到配置"
    fi
    
    # 添加局域网 IP 段到白名单
    print_info "添加局域网 IP 段到白名单..."
    
    # 检查是否已经添加过
    if grep -q "10.0.0.0/8" "$config_file"; then
        print_warning "局域网 IP 段已存在，跳过"
    else
        # 在 whitelist 部分添加局域网 IP 段
        # 查找 whitelist: 行，然后在其后的 127.0.0.1 行后添加
        if grep -q "^[[:space:]]*whitelist:" "$config_file"; then
            # 在 127.0.0.1 行后添加局域网 IP 段
            sed -i '/^[[:space:]]*- 127\.0\.0\.1/a\  - 10.0.0.0/8\n  - 172.16.0.0/12\n  - 192.168.0.0/16' "$config_file"
            if [ $? -eq 0 ]; then
                print_success "已添加局域网 IP 段到白名单"
                ((success_count++))
            else
                print_error "添加局域网 IP 段失败"
            fi
        else
            print_warning "未找到 whitelist 配置"
        fi
    fi
    
    echo ""
    if [ $success_count -eq 2 ]; then
        print_success "局域网访问已启用！请重启 SillyTavern 以应用更改"
        print_info "您现在可以通过局域网 IP 访问 SillyTavern"
        print_warning "请确保您的网络环境安全！"
    elif [ $success_count -gt 0 ]; then
        print_warning "部分修改完成，请检查日志"
    else
        print_error "修改失败"
    fi
    
    echo ""
    ask_confirm "按回车键继续..." "y"
}


# ========================================
# 主菜单
# ========================================

show_main_menu() {
    clear
    print_title "Foxium - SillyTavern 综合优化小工具"
    
    echo "${BOLD}当前配置:${NC}"
    echo "  ST 目录: ${GREEN}$ST_DIR${NC}"
    echo "  用户: ${GREEN}$USER_NAME${NC}"
    echo "  备份目录: ${GREEN}$BACKUP_DIR${NC}"
    echo ""
    
    echo "${BOLD}${CYAN}请选择功能类别:${NC}"
    echo "1. 修复功能"
    echo "2. 优化功能"
    echo "3. 备份功能"
    echo ""
    echo "0. 退出"
    echo ""
}

show_fix_menu() {
    clear
    print_title "修复功能"
    
    echo "${BOLD}${CYAN}请选择修复功能:${NC}"
    echo "1. 修复无法安装 npm/node 包问题"
    echo "2. 修复 UI 主题导致卡死"
    echo "3. 修复扩展无法卸载"
    echo "4. 修复端口冲突"
    echo "5. 修复无法打开聊天导致卡死"
    echo "6. ${RED}修复 gemini-3 系列模型无法发送媒体 (风险)${NC}"
    echo "7. 强制更新 ST"
    echo ""
    echo "0. 返回主菜单"
    echo ""
}

show_optimize_menu() {
    clear
    print_title "优化功能"
    
    echo "${BOLD}${CYAN}请选择优化功能:${NC}"
    echo "1. 优化旧版本 ST 内存占用"
    echo "2. 解除聊天记录文件大小限制"
    echo "3. 更新聊天补全模型列表"
    echo "4. ${RED}解除所有模型能力限制 (风险)${NC}"
    echo "5. ${RED}一键对局域网开放 (风险)${NC}"
    echo ""
    echo "0. 返回主菜单"
    echo ""
}

show_backup_menu() {
    clear
    print_title "备份功能"
    
    echo "${BOLD}${CYAN}请选择备份功能:${NC}"
    echo "1. 手动备份"
    echo "2. 自动备份设置"
    echo ""
    echo "0. 返回主菜单"
    echo ""
}

fix_menu_loop() {
    while true; do
        show_fix_menu
        echo -ne "${YELLOW}请输入选项 [0-7]: ${NC}"
        read -r choice
        
        case $choice in
            1) fix_npm_install ;;
            2) fix_theme_freeze ;;
            3) fix_extension_uninstall ;;
            4) fix_port_conflict ;;
            5) fix_chat_loading ;;
            6) fix_gemini3_media ;;
            7) force_update_st ;;
            0) return ;;
            *)
                print_error "无效的选项或功能尚未实现"
                ask_confirm "按回车键继续..." "y"
                ;;
        esac
    done
}

optimize_menu_loop() {
    while true; do
        show_optimize_menu
        echo -ne "${YELLOW}请输入选项 [0-5]: ${NC}"
        read -r choice
        
        case $choice in
            1) optimize_memory_usage ;;
            2) remove_chat_size_limit ;;
            3) update_model_list ;;
            4) remove_model_restrictions ;;
            5) enable_lan_access ;;
            0) return ;;
            *)
                print_error "无效的选项"
                ask_confirm "按回车键继续..." "y"
                ;;
        esac
    done
}

backup_menu_loop() {
    while true; do
        show_backup_menu
        echo -ne "${YELLOW}请输入选项 [0-2]: ${NC}"
        read -r choice
        
        case $choice in
            1) manual_backup ;;
            2) auto_backup_setup ;;
            0) return ;;
            *)
                print_error "无效的选项"
                ask_confirm "按回车键继续..." "y"
                ;;
        esac
    done
}

main_loop() {
    while true; do
        show_main_menu
        echo -ne "${YELLOW}请输入选项 [0-3]: ${NC}"
        read -r choice
        
        case $choice in
            1) fix_menu_loop ;;
            2) optimize_menu_loop ;;
            3) backup_menu_loop ;;
            0)
                print_info "感谢使用 Foxium！"
                exit 0
                ;;
            *)
                print_error "无效的选项"
                ask_confirm "按回车键继续..." "y"
                ;;
        esac
    done
}

# ========================================
# 主程序入口
# ========================================

main() {
    # 运行启动检查
    run_startup_checks
    
    # 进入主循环
    main_loop
}

# 执行主程序
main
