#!/bin/bash

# GaiaNet GUI 快速安装脚本 - 无需Git，无需Xcode命令行工具
# 专为新Mac设计的快速安装方案

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${GREEN}[安装]${NC} $1\n"; }
error() { printf "${RED}[错误]${NC} $1\n"; }
warning() { printf "${YELLOW}[警告]${NC} $1\n"; }
highlight() { printf "${BLUE}[部署]${NC} $1\n"; }

# 配置
INSTALL_DIR="$HOME/Desktop/gaia-gui-mac"

# 解析命令行参数
AUTO_DEPLOY=false
FULL_AUTO=false
NODES_COUNT=20
WALLET_KEY=""
DOMAIN_ID=""
SUDO_PASSWORD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-deploy)
            AUTO_DEPLOY=true
            shift
            ;;
        --full-auto)
            FULL_AUTO=true
            AUTO_DEPLOY=true
            shift
            ;;
        --nodes)
            NODES_COUNT="$2"
            shift 2
            ;;
        --wallet)
            WALLET_KEY="$2"
            shift 2
            ;;
        --domain-id)
            DOMAIN_ID="$2"
            shift 2
            ;;
        --sudo-password)
            SUDO_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            echo "GaiaNet GUI 快速安装脚本 (无需Git)"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --full-auto       完整自动化流程(新Mac推荐)"
            echo "  --nodes NUM       节点数量 (默认: 20)"
            echo "  --wallet KEY      钱包私钥(可选，不提供则自动生成)"
            echo "  --domain-id ID    要加入的域ID(可选)"
            echo "  --sudo-password PWD  管理员密码(用于自动安装Homebrew)"
            echo "  -h, --help        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 --full-auto --nodes 20 --domain-id 742"
            echo "  $0 --full-auto --sudo-password 'your_password' --nodes 20"
            exit 0
            ;;
        *)
            warning "未知参数: $1"
            shift
            ;;
    esac
done

# 快速环境检查
check_environment() {
    info "🔍 快速环境检查..."
    
    # 检查并安装Python 3.11
    check_and_install_python311
    
    # 检查网络
    if ! curl -s --max-time 10 https://github.com >/dev/null; then
        error "无法连接到GitHub，请检查网络连接"
        exit 1
    fi
    info "✅ 网络连接正常"
    
    # 检查unzip
    if ! command -v unzip >/dev/null 2>&1; then
        error "系统缺少unzip命令，请安装"
        exit 1
    fi
    info "✅ ZIP解压工具可用"
}

# 检查并安装Python 3.11
check_and_install_python311() {
    info "🐍 检查Python 3.11..."
    
    # 首先检查python3.11是否直接可用
    if command -v python3.11 >/dev/null 2>&1; then
        local version=$(python3.11 --version 2>/dev/null | grep -o "3\.11\.[0-9]*")
        if [ -n "$version" ]; then
            info "✅ Python 3.11已安装: Python $version"
            export PYTHON3_CMD="python3.11"
            return 0
        fi
    fi
    
    # 检查系统默认python3版本
    if command -v python3 >/dev/null 2>&1; then
        local current_version=$(python3 --version 2>/dev/null | grep -o "[0-9]\+\.[0-9]\+")
        info "📋 当前Python版本: Python $current_version"
        
        if [ "$current_version" = "3.11" ]; then
            info "✅ Python 3.11已安装并设为默认"
            export PYTHON3_CMD="python3"
            return 0
        else
            # 如果是Python 3.9或更高版本，先尝试使用它
            local major_version=$(echo "$current_version" | cut -d'.' -f1)
            local minor_version=$(echo "$current_version" | cut -d'.' -f2)
            
            if [ "$major_version" = "3" ] && [ "$minor_version" -ge "9" ]; then
                warning "⚠️ 当前版本是Python $current_version，尝试使用现有版本运行GUI"
                info "💡 如果GUI运行出现问题，建议手动安装Python 3.11"
                export PYTHON3_CMD="python3"
                return 0
            else
                warning "⚠️ 当前版本是Python $current_version，但GUI推荐Python 3.11"
            fi
        fi
    fi
    
    # 尝试安装Python 3.11
    info "🔧 尝试安装Python 3.11..."
    
    # 检查是否安装了Homebrew
    if command -v brew >/dev/null 2>&1; then
        info "📦 使用现有Homebrew安装Python 3.11..."
        if brew install python@3.11; then
            info "✅ Python 3.11安装完成"
            
            # 添加到PATH
            local python311_path="/opt/homebrew/bin/python3.11"
            if [ ! -f "$python311_path" ]; then
                python311_path="/usr/local/bin/python3.11"
            fi
            
            if [ -f "$python311_path" ]; then
                export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                export PYTHON3_CMD="python3.11"
                update_shell_config_for_python311
                info "✅ Python 3.11已添加到PATH"
                return 0
            else
                error "❌ Python 3.11安装后未找到"
                return 1
            fi
        else
            error "❌ Homebrew安装Python 3.11失败"
        fi
    else
        warning "⚠️ 未安装Homebrew，跳过Python 3.11安装"
        info "💡 将使用系统默认Python版本"
        if command -v python3 >/dev/null 2>&1; then
            export PYTHON3_CMD="python3"
            return 0
        else
            error "❌ 系统未安装Python 3"
            error "请手动安装Python 3.11: brew install python@3.11"
            exit 1
        fi
    fi
    
    # 如果Homebrew安装失败，但有系统Python，使用系统版本
    if command -v python3 >/dev/null 2>&1; then
        warning "⚠️ Python 3.11安装失败，使用系统默认Python版本"
        export PYTHON3_CMD="python3"
        return 0
    fi
    
    # 如果所有方法都失败了
    error "❌ 无法获得可用的Python版本"
    error "请手动安装Python后重新运行此脚本"
    error "推荐方法: brew install python@3.11"
    exit 1
}

# 安装Homebrew和Python 3.11
install_homebrew_and_python311() {
    info "🍺 安装Homebrew..."
    
    # 使用提供的密码进行非交互安装
    if [ -n "$SUDO_PASSWORD" ]; then
        info "📝 使用提供的管理员密码进行自动安装..."
        
        # 验证密码
        echo "$SUDO_PASSWORD" | sudo -S echo "验证密码..." 2>/dev/null
        if [ $? -eq 0 ]; then
            info "✅ 密码验证成功"
            
            # 设置非交互模式环境变量
            export NONINTERACTIVE=1
            export CI=1
            
            # 创建临时脚本来处理Homebrew安装
            local temp_script="/tmp/homebrew_install_$$.sh"
            cat > "$temp_script" << 'HOMEBREW_SCRIPT'
#!/bin/bash
export NONINTERACTIVE=1
export CI=1
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
HOMEBREW_SCRIPT
            
            chmod +x "$temp_script"
            
            # 使用当前用户身份运行（不使用sudo）
            if "$temp_script"; then
                info "✅ Homebrew安装完成"
                rm -f "$temp_script"
            else
                error "❌ Homebrew安装失败"
                rm -f "$temp_script"
                return 1
            fi
        else
            error "❌ 管理员密码验证失败"
            return 1
        fi
    else
        # 交互模式安装
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            info "✅ Homebrew安装完成"
        else
            error "❌ Homebrew安装失败"
            return 1
        fi
    fi
    
    # 添加Homebrew到PATH
    if [ -f "/opt/homebrew/bin/brew" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
        echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zprofile
    elif [ -f "/usr/local/bin/brew" ]; then
        export PATH="/usr/local/bin:$PATH"
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zprofile
    fi
    
    # 安装Python 3.11
    info "📦 使用新安装的Homebrew安装Python 3.11..."
    
    # 如果有密码，可能需要用于某些brew操作
    if [ -n "$SUDO_PASSWORD" ]; then
        # 先尝试不使用sudo
        if brew install python@3.11; then
            info "✅ Python 3.11安装完成"
            export PYTHON3_CMD="python3.11"
            update_shell_config_for_python311
            return 0
        else
            # 如果失败，尝试使用sudo辅助某些操作
            info "🔄 尝试使用管理员权限安装Python 3.11..."
            if echo "$SUDO_PASSWORD" | sudo -S brew install python@3.11 2>/dev/null || brew install python@3.11; then
                info "✅ Python 3.11安装完成"
                export PYTHON3_CMD="python3.11"
                update_shell_config_for_python311
                return 0
            else
                error "❌ Python 3.11安装失败"
                return 1
            fi
        fi
    else
        if brew install python@3.11; then
            info "✅ Python 3.11安装完成"
            export PYTHON3_CMD="python3.11"
            update_shell_config_for_python311
            return 0
        else
            error "❌ Python 3.11安装失败"
            return 1
        fi
    fi
}

# 更新shell配置文件以包含Python 3.11
update_shell_config_for_python311() {
    local shell_config=""
    if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        shell_config="$HOME/.zshrc"
    elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
        shell_config="$HOME/.bash_profile"
    fi
    
    if [ -n "$shell_config" ]; then
        # 检查是否已经添加了Python 3.11的PATH
        if ! grep -q "python@3.11" "$shell_config" 2>/dev/null; then
            echo '# Python 3.11' >> "$shell_config"
            echo 'export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"' >> "$shell_config"
            echo 'export PATH="/usr/local/opt/python@3.11/bin:$PATH"' >> "$shell_config"
            info "✅ 已添加Python 3.11 PATH到 $shell_config"
        fi
    fi
}

# 快速下载安装（使用ZIP，无需Git）
fast_install() {
    info "📥 快速下载GaiaNet GUI (使用ZIP方案)..."
    
    # 如果目录已存在，先备份
    if [ -d "$INSTALL_DIR" ]; then
        local backup_dir="${INSTALL_DIR}.backup.$(date +%s)"
        warning "目录已存在，备份到: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
    fi
    
    # 下载ZIP文件
    local zip_file="/tmp/gaia-gui-mac-fast.zip"
    
    if curl -sSL "https://github.com/q1706188538/gaia-gui-mac/archive/refs/heads/main.zip" -o "$zip_file"; then
        info "✅ ZIP文件下载完成 (约几MB)"
        
        # 解压到临时目录
        local temp_extract="/tmp/gaia-gui-extract-fast-$$"
        mkdir -p "$temp_extract"
        
        if unzip -q "$zip_file" -d "$temp_extract"; then
            # 移动到目标目录
            mv "$temp_extract/gaia-gui-mac-main" "$INSTALL_DIR"
            rm -rf "$temp_extract"
            rm -f "$zip_file"
            info "✅ 解压完成，无需Git"
        else
            error "ZIP解压失败"
            rm -rf "$temp_extract" 2>/dev/null || true
            rm -f "$zip_file" 2>/dev/null || true
            exit 1
        fi
    else
        error "ZIP文件下载失败"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # 安装Python依赖
    info "📦 安装Python依赖..."
    if [ -f "requirements.txt" ]; then
        # 确保使用正确的Python 3.11版本
        local pip_cmd="pip3"
        if [ -n "$PYTHON3_CMD" ]; then
            pip_cmd="${PYTHON3_CMD} -m pip"
        fi
        
        if $pip_cmd install -r requirements.txt; then
            info "✅ 依赖安装完成"
        else
            warning "依赖安装失败，请手动运行: $pip_cmd install -r requirements.txt"
        fi
    fi
    
    # 设置脚本执行权限
    info "🔧 设置执行权限..."
    find . -name "*.sh" -exec chmod +x {} \;
    
    # 创建桌面启动脚本
    info "🔗 创建桌面快捷方式..."
    cat > "$HOME/Desktop/启动GaiaNet管理器.command" << 'EOF'
#!/bin/bash
cd "$HOME/Desktop/gaia-gui-mac"
# 使用正确的Python 3.11版本
if [ -f "/opt/homebrew/bin/python3.11" ]; then
    /opt/homebrew/bin/python3.11 src/gaianet_gui.py
elif [ -f "/usr/local/bin/python3.11" ]; then
    /usr/local/bin/python3.11 src/gaianet_gui.py
elif command -v python3.11 >/dev/null 2>&1; then
    python3.11 src/gaianet_gui.py
else
    python3 src/gaianet_gui.py
fi
EOF
    
    chmod +x "$HOME/Desktop/启动GaiaNet管理器.command"
    
    info "✅ 快速安装完成！"
}

# 安装GaiaNet主节点（快速版本）
install_main_gaianet_node_fast() {
    info "  📥 下载并安装GaiaNet主节点..."
    
    # 检查是否已经安装
    if [ -f "$HOME/gaianet/bin/gaianet" ]; then
        info "  ✅ GaiaNet主节点已存在，跳过安装"
        return 0
    fi
    
    # 下载并安装GaiaNet
    if curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash; then
        info "  ✅ GaiaNet主节点安装完成"
        
        # 设置环境变量
        info "  🔧 设置环境变量..."
        export PATH="$HOME/gaianet/bin:$PATH"
        
        # 更新shell配置文件
        local shell_config=""
        if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
            shell_config="$HOME/.zshrc"
        elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
            shell_config="$HOME/.bash_profile"
        fi
        
        if [ -n "$shell_config" ]; then
            if ! grep -q "gaianet/bin" "$shell_config" 2>/dev/null; then
                echo 'export PATH="$HOME/gaianet/bin:$PATH"' >> "$shell_config"
                info "  ✅ 已添加PATH到 $shell_config"
            fi
        fi
        
        # 初始化主节点
        info "  📦 初始化主节点和下载模型文件..."
        cd "$HOME/gaianet"
        
        if [ -f "./bin/gaianet" ]; then
            info "  🔄 执行 gaianet init (这可能需要几分钟)..."
            
            # 使用自定义超时函数
            if run_with_timeout_fast 1800 "./bin/gaianet" "init"; then
                info "  ✅ 主节点模型文件下载完成"
                return 0
            else
                error "  ❌ 主节点模型文件下载失败或超时"
                error "  💡 您可以稍后手动运行: cd ~/gaianet && ./bin/gaianet init"
                return 1
            fi
        else
            error "  ❌ gaianet命令未找到"
            return 1
        fi
    else
        error "  ❌ GaiaNet主节点安装失败"
        return 1
    fi
}

# 自定义超时函数
run_with_timeout_fast() {
    local timeout_duration=$1
    shift
    local cmd=("$@")
    
    "${cmd[@]}" &
    local pid=$!
    
    local count=0
    while [ $count -lt $timeout_duration ]; do
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid
            return $?
        fi
        sleep 1
        count=$((count + 1))
        
        if [ $((count % 30)) -eq 0 ]; then
            info "    ⏳ 已等待 $((count / 60)) 分钟，继续下载中..."
        fi
    done
    
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    return 124
}

# 创建节点配置
create_nodes_config_for_full_auto_fast() {
    info "  📝 创建$NODES_COUNT个节点的配置..."
    
    $PYTHON3_CMD src/gaianet_gui.py --create-config --nodes "$NODES_COUNT"
    
    info "  ✅ 节点配置创建完成"
}

# 生成钱包
generate_wallet_for_full_auto_fast() {
    info "  🔄 生成新钱包地址和私钥..."
    
    if $PYTHON3_CMD src/gaianet_gui.py --headless --generate-wallet --save-to auto-deploy-config.json; then
        info "  ✅ 新钱包已生成并保存"
    else
        error "  ❌ 钱包生成失败"
        exit 1
    fi
}

# 更新配置文件中的钱包信息
update_config_with_wallet_fast() {
    $PYTHON3_CMD -c "
import json
import sys
from eth_account import Account

try:
    # 验证私钥并获取地址
    account = Account.from_key('$WALLET_KEY')
    
    with open('auto-deploy-config.json', 'r') as f:
        config = json.load(f)
    
    config['wallet']['private_key'] = '$WALLET_KEY'
    config['wallet']['address'] = account.address
    config['wallet']['batch_bind']['enabled'] = True
    config['wallet']['batch_bind']['count'] = $NODES_COUNT
    
    if '$DOMAIN_ID':
        config['wallet']['auto_join_domain'] = {
            'enabled': True,
            'domain_id': '$DOMAIN_ID'
        }
    
    with open('auto-deploy-config.json', 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('✅ 钱包配置已更新')
except Exception as e:
    print(f'❌ 钱包配置失败: {e}')
    sys.exit(1)
"
}

# 显示钱包信息
show_wallet_info_for_full_auto_fast() {
    info ""
    highlight "💰 钱包信息:"
    
    if [ -f "auto-deploy-config.json" ]; then
        $PYTHON3_CMD -c "
import json

try:
    with open('auto-deploy-config.json', 'r') as f:
        config = json.load(f)
    
    wallet = config.get('wallet', {})
    if 'private_key' in wallet and 'address' in wallet:
        print(f'🔑 私钥: {wallet[\"private_key\"]}')
        print(f'📍 地址: {wallet[\"address\"]}')
        print('')
        print('⚠️  重要提醒:')
        print('• 请立即备份私钥到安全位置')
        print('• 私钥已保存在: auto-deploy-config.json')
        print('• 钱包配置也已保存到桌面')
    else:
        print('❌ 未找到钱包信息')
except Exception as e:
    print(f'❌ 读取钱包信息失败: {e}')
"
    else
        error "❌ 配置文件不存在"
    fi
}

# 主函数
main() {
    highlight "🚀 GaiaNet GUI 快速安装脚本 (无需Git/Xcode)"
    echo "=================================================="
    
    if [ "$FULL_AUTO" = true ]; then
        info "模式: 完整自动化部署 (快速版)"
        info "节点数量: $NODES_COUNT"
        if [ -n "$WALLET_KEY" ]; then
            info "钱包: 使用提供的私钥"
        else
            info "钱包: 自动生成"
        fi
        if [ -n "$DOMAIN_ID" ]; then
            info "域ID: $DOMAIN_ID"
        fi
    else
        info "模式: 仅安装 (快速版)"
    fi
    
    echo ""
    
    # 执行步骤
    check_environment
    fast_install
    
    if [ "$FULL_AUTO" = true ]; then
        # 执行完整自动化流程
        info "🚀 开始完整自动化部署流程..."
        cd "$INSTALL_DIR"
        
        # 第1步: 安装主节点和下载模型文件
        info "🔧 第1步: 安装GaiaNet主节点和下载模型文件..."
        if ! install_main_gaianet_node_fast; then
            error "❌ 主节点安装失败"
            exit 1
        fi
        
        # 第2步: 创建从节点配置
        info "📝 第2步: 创建从节点配置..."
        create_nodes_config_for_full_auto_fast
        
        # 第3步: 初始化从节点(复制主节点文件)
        info "📂 第3步: 初始化从节点(复制主节点文件)..."
        if ! $PYTHON3_CMD src/gaianet_gui.py --headless --init --config auto-deploy-config.json; then
            error "❌ 从节点初始化失败"
            exit 1
        fi
        
        # 第4步: 启动所有节点
        info "🚀 第4步: 启动所有节点..."
        if ! $PYTHON3_CMD src/gaianet_gui.py --headless --start --config auto-deploy-config.json; then
            error "❌ 节点启动失败"
            exit 1
        fi
        
        # 第5步: 生成钱包(如果未提供)
        if [ -z "$WALLET_KEY" ]; then
            info "🔑 第5步: 生成新钱包..."
            generate_wallet_for_full_auto_fast
        else
            info "🔑 第5步: 使用提供的钱包私钥..."
            update_config_with_wallet_fast
        fi
        
        # 第6步: 批量绑定节点
        info "🔗 第6步: 批量绑定节点..."
        if ! $PYTHON3_CMD src/gaianet_gui.py --headless --batch-bind --config auto-deploy-config.json; then
            error "❌ 批量绑定失败"
            exit 1
        fi
        
        # 第7步: 批量加入域(如果提供了域ID)
        if [ -n "$DOMAIN_ID" ]; then
            info "🌐 第7步: 批量加入域 $DOMAIN_ID..."
            if ! $PYTHON3_CMD src/gaianet_gui.py --headless --batch-join-domain "$DOMAIN_ID" --config auto-deploy-config.json; then
                error "❌ 批量加入域失败"
                exit 1
            fi
        else
            info "⏭️  第7步: 跳过域加入(未指定域ID)"
        fi
        
        # 显示最终状态
        highlight "🎉 完整自动化部署完成！"
        info "📊 最终状态:"
        $PYTHON3_CMD src/gaianet_gui.py --headless --status
        
        # 显示钱包信息
        show_wallet_info_for_full_auto_fast
    fi
    
    show_usage_info
}

# 显示使用信息
show_usage_info() {
    if [ "$FULL_AUTO" = true ]; then
        # 如果是完全自动化，不需要显示额外的使用信息
        return
    fi
    
    highlight "🎯 快速安装完成！使用方法："
    echo ""
    echo "图形界面模式："
    echo "  双击桌面上的 '启动GaiaNet管理器.command'"
    echo ""
    echo "继续自动化部署："
    echo "  cd $INSTALL_DIR"
    echo "  $PYTHON3_CMD src/gaianet_gui.py --headless --auto-deploy"
    echo ""
    echo "💡 重要提醒："
    echo "  在GUI中安装主节点时，会自动处理环境变量设置"
    echo "  或者手动运行: source ~/.zshrc 后再执行 gaianet init"
    echo ""
    
    highlight "🔥 快速安装完成，请使用GUI进行后续的主节点安装和自动化部署！"
    echo ""
    echo "🎯 下一步操作："
    echo "1. 双击桌面的 '启动GaiaNet管理器.command'"
    echo "2. 在GUI中点击 '安装主节点' (会自动处理环境变量)"  
    echo "3. 然后进行多节点部署和钱包操作"
    echo ""
    echo "优势: 无需安装Xcode命令行工具，安装速度快10倍+"
}

# 错误处理
trap 'error "安装过程中发生错误"' ERR

# 运行主函数
main "$@"