#!/bin/bash

# GaiaNet GUI 一键安装和自动部署脚本
# 从GitHub自动下载最新版本并支持自动化部署

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
REPO_URL="https://github.com/q1706188538/gaia-gui-mac.git"
INSTALL_DIR="$HOME/Desktop/gaia-gui-mac"

# 解析命令行参数
AUTO_DEPLOY=false
CREATE_CONFIG=false
FULL_AUTO=false
NODES_COUNT=20
WALLET_KEY=""
DOMAIN_ID=""

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
        --create-config)
            CREATE_CONFIG=true
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
        -h|--help)
            echo "GaiaNet GUI 一键安装脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --auto-deploy     安装后自动部署节点"
            echo "  --full-auto       完整自动化流程(新Mac推荐)"
            echo "  --create-config   创建配置文件后退出"
            echo "  --nodes NUM       节点数量 (默认: 20)"
            echo "  --wallet KEY      钱包私钥(可选，不提供则自动生成)"
            echo "  --domain-id ID    要加入的域ID(可选)"
            echo "  -h, --help        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                                    # 仅安装GUI"
            echo "  $0 --auto-deploy                     # 安装后自动部署"
            echo "  $0 --full-auto --nodes 20 --domain-id 742  # 完整自动化(推荐)"
            echo "  $0 --create-config                   # 创建配置文件"
            exit 0
            ;;
        *)
            warning "未知参数: $1"
            shift
            ;;
    esac
done

# 检查环境
check_environment() {
    info "🔍 检查系统环境..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "darwin"* ]]; then
        warning "此脚本专为macOS设计，其他系统可能需要调整"
    fi
    
    # 检查Python3
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3未安装，请先安装Python3"
        error "建议使用Homebrew安装: brew install python"
        exit 1
    else
        local python_version=$(python3 --version 2>/dev/null || echo "Python 3.x")
        info "✅ Python3已安装: $python_version"
    fi
    
    # 检查网络连接
    if ! curl -s --max-time 10 https://github.com >/dev/null; then
        error "无法连接到GitHub，请检查网络连接"
        exit 1
    fi
    
    info "✅ 网络连接正常"
    
    # 检查Git（如果没有Git，我们使用ZIP下载方案）
    if ! command -v git >/dev/null 2>&1; then
        warning "⚠️ Git未安装，将使用ZIP下载方案（更快）"
        USE_CURL_DOWNLOAD=true
    else
        local git_version=$(git --version 2>/dev/null || echo "git version unknown")
        info "✅ Git已安装: $git_version"
        USE_CURL_DOWNLOAD=false
    fi
}

# 修改下载函数支持curl方案
install_gaianet_gui() {
    info "📥 下载GaiaNet GUI最新版本..."
    
    # 如果目录已存在，先备份
    if [ -d "$INSTALL_DIR" ]; then
        local backup_dir="${INSTALL_DIR}.backup.$(date +%s)"
        warning "目录已存在，备份到: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
    fi
    
    if [ "$USE_CURL_DOWNLOAD" = true ]; then
        # 使用curl下载ZIP文件
        info "📦 使用ZIP下载方案（快速）..."
        local zip_file="/tmp/gaia-gui-mac.zip"
        
        if curl -sSL "https://github.com/q1706188538/gaia-gui-mac/archive/refs/heads/main.zip" -o "$zip_file"; then
            info "✅ ZIP文件下载完成"
            
            # 解压到临时目录
            local temp_extract="/tmp/gaia-gui-extract-$$"
            mkdir -p "$temp_extract"
            
            if command -v unzip >/dev/null 2>&1; then
                if unzip -q "$zip_file" -d "$temp_extract"; then
                    # 移动到目标目录
                    mv "$temp_extract/gaia-gui-mac-main" "$INSTALL_DIR"
                    rm -rf "$temp_extract"
                    rm -f "$zip_file"
                    info "✅ 项目解压完成"
                else
                    error "ZIP解压失败"
                    rm -rf "$temp_extract"
                    rm -f "$zip_file"
                    exit 1
                fi
            else
                error "系统缺少unzip命令"
                rm -rf "$temp_extract"
                rm -f "$zip_file"
                exit 1
            fi
        else
            error "ZIP文件下载失败"
            exit 1
        fi
    else
        # 使用git clone
        if git clone "$REPO_URL" "$INSTALL_DIR"; then
            info "✅ Git克隆完成"
        else
            error "Git克隆失败，请检查网络连接或仓库地址"
            exit 1
        fi
    fi
    
    # 检查网络连接
    if ! curl -s --max-time 10 https://github.com >/dev/null; then
        error "无法连接到GitHub，请检查网络连接"
        exit 1
    fi
    
    info "✅ 网络连接正常"
}

# 下载并安装
install_gaianet_gui() {
    info "📥 下载GaiaNet GUI最新版本..."
    
    # 如果目录已存在，先备份
    if [ -d "$INSTALL_DIR" ]; then
        local backup_dir="${INSTALL_DIR}.backup.$(date +%s)"
        warning "目录已存在，备份到: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
    fi
    
    # 克隆仓库
    if git clone "$REPO_URL" "$INSTALL_DIR"; then
        info "✅ 下载完成"
    else
        error "下载失败，请检查网络连接或仓库地址"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # 安装Python依赖
    info "📦 安装Python依赖..."
    if [ -f "requirements.txt" ]; then
        if pip3 install -r requirements.txt; then
            info "✅ 依赖安装完成"
        else
            warning "依赖安装失败，请手动运行: pip3 install -r requirements.txt"
        fi
    else
        warning "未找到requirements.txt文件"
    fi
    
    # 设置脚本执行权限
    info "🔧 设置执行权限..."
    find . -name "*.sh" -exec chmod +x {} \;
    
    # 创建桌面启动脚本
    info "🔗 创建桌面快捷方式..."
    cat > "$HOME/Desktop/启动GaiaNet管理器.command" << 'EOF'
#!/bin/bash
cd "$HOME/Desktop/gaia-gui-mac"
python3 src/gaianet_gui.py
EOF
    
    chmod +x "$HOME/Desktop/启动GaiaNet管理器.command"
    
    info "✅ 安装完成！"
}

# 创建自动化配置文件
create_auto_config() {
    info "📝 创建自动化配置文件..."
    
    cd "$INSTALL_DIR"
    
    # 创建配置文件
    python3 src/gaianet_gui.py --create-config
    
    # 如果提供了钱包私钥，更新配置
    if [ -n "$WALLET_KEY" ]; then
        info "🔑 配置钱包私钥..."
        
        # 使用Python更新JSON配置
        python3 -c "
import json
import sys

try:
    with open('auto-deploy-config.json', 'r') as f:
        config = json.load(f)
    
    config['wallet']['private_key'] = '$WALLET_KEY'
    config['wallet']['batch_bind']['enabled'] = True
    config['wallet']['batch_bind']['count'] = $NODES_COUNT
    config['nodes']['count'] = $NODES_COUNT
    
    with open('auto-deploy-config.json', 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('✅ 配置文件已更新')
except Exception as e:
    print(f'❌ 配置更新失败: {e}')
    sys.exit(1)
"
    fi
    
    info "✅ 配置文件创建完成: auto-deploy-config.json"
}

# 自动部署
auto_deploy() {
    info "🚀 开始自动部署..."
    
    cd "$INSTALL_DIR"
    
    # 执行自动部署
    if python3 src/gaianet_gui.py --headless --auto-deploy --config auto-deploy-config.json; then
        highlight "🎉 自动部署完成！"
        
        # 显示状态
        info "📊 最终状态:"
        python3 src/gaianet_gui.py --headless --status
        
    else
        error "自动部署失败"
        error "你可以："
        error "1. 检查配置文件: auto-deploy-config.json"
        error "2. 手动运行GUI: python3 src/gaianet_gui.py"
        error "3. 查看日志排查问题"
        exit 1
    fi
}

# 完整自动化流程 (新Mac推荐)
full_auto_deploy() {
    highlight "🚀 开始完整自动化部署流程..."
    highlight "📋 流程包括: 主节点安装 → 从节点初始化 → 启动节点 → 生成钱包 → 绑定节点 → 加入域"
    
    cd "$INSTALL_DIR"
    
    # 第1步: 安装主节点和下载模型文件
    info "🔧 第1步: 安装GaiaNet主节点和下载模型文件..."
    if ! install_main_gaianet_node; then
        error "❌ 主节点安装失败"
        exit 1
    fi
    
    # 第2步: 创建从节点配置
    info "📝 第2步: 创建从节点配置..."
    create_nodes_config_for_full_auto
    
    # 第3步: 初始化从节点(复制主节点文件)
    info "📂 第3步: 初始化从节点(复制主节点文件)..."
    if ! python3 src/gaianet_gui.py --headless --init --config auto-deploy-config.json; then
        error "❌ 从节点初始化失败"
        exit 1
    fi
    
    # 第4步: 启动所有节点
    info "🚀 第4步: 启动所有节点..."
    if ! python3 src/gaianet_gui.py --headless --start --config auto-deploy-config.json; then
        error "❌ 节点启动失败"
        exit 1
    fi
    
    # 第5步: 生成钱包(如果未提供)
    if [ -z "$WALLET_KEY" ]; then
        info "🔑 第5步: 生成新钱包..."
        generate_wallet_for_full_auto
    else
        info "🔑 第5步: 使用提供的钱包私钥..."
    fi
    
    # 第6步: 批量绑定节点
    info "🔗 第6步: 批量绑定节点..."
    if ! python3 src/gaianet_gui.py --headless --batch-bind --config auto-deploy-config.json; then
        error "❌ 批量绑定失败"
        exit 1
    fi
    
    # 第7步: 批量加入域(如果提供了域ID)
    if [ -n "$DOMAIN_ID" ]; then
        info "🌐 第7步: 批量加入域 $DOMAIN_ID..."
        if ! python3 src/gaianet_gui.py --headless --batch-join-domain "$DOMAIN_ID" --config auto-deploy-config.json; then
            error "❌ 批量加入域失败"
            exit 1
        fi
    else
        info "⏭️  第7步: 跳过域加入(未指定域ID)"
    fi
    
    # 显示最终状态
    highlight "🎉 完整自动化部署完成！"
    info "📊 最终状态:"
    python3 src/gaianet_gui.py --headless --status
    
    # 显示钱包信息
    show_wallet_info_for_full_auto
}

# 安装GaiaNet主节点
install_main_gaianet_node() {
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
        
        # 添加到PATH
        export PATH="$HOME/gaianet/bin:$PATH"
        
        # 创建或更新shell配置文件
        local shell_config=""
        if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
            shell_config="$HOME/.zshrc"
        elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
            shell_config="$HOME/.bash_profile"
        fi
        
        if [ -n "$shell_config" ]; then
            # 检查是否已经添加了PATH
            if ! grep -q "gaianet/bin" "$shell_config" 2>/dev/null; then
                echo 'export PATH="$HOME/gaianet/bin:$PATH"' >> "$shell_config"
                info "  ✅ 已添加PATH到 $shell_config"
            fi
        fi
        
        # 初始化主节点(下载模型文件)
        info "  📦 初始化主节点和下载模型文件..."
        cd "$HOME/gaianet"
        
        # 确保gaianet命令可用
        if [ -f "./bin/gaianet" ]; then
            info "  🔄 执行 gaianet init (这可能需要几分钟)..."
            
            # 使用自定义超时函数（macOS没有timeout命令）
            if run_with_timeout 1800 "./bin/gaianet" "init"; then
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

# 自定义超时函数（替代timeout命令）
run_with_timeout() {
    local timeout_duration=$1
    shift
    local cmd=("$@")
    
    # 在后台运行命令
    "${cmd[@]}" &
    local pid=$!
    
    # 等待指定时间
    local count=0
    while [ $count -lt $timeout_duration ]; do
        if ! kill -0 $pid 2>/dev/null; then
            # 进程已经结束
            wait $pid
            return $?
        fi
        sleep 1
        count=$((count + 1))
        
        # 每30秒显示一次进度
        if [ $((count % 30)) -eq 0 ]; then
            info "    ⏳ 已等待 $((count / 60)) 分钟，继续下载中..."
        fi
    done
    
    # 超时，杀死进程
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    return 124  # timeout exit code
}

# 为完整自动化创建节点配置
create_nodes_config_for_full_auto() {
    info "  📝 创建$NODES_COUNT个节点的配置..."
    
    # 创建配置文件
    python3 src/gaianet_gui.py --create-config --nodes "$NODES_COUNT"
    
    # 更新配置文件
    if [ -n "$WALLET_KEY" ]; then
        info "  🔑 配置提供的钱包私钥..."
        
        # 使用Python更新JSON配置
        python3 -c "
import json
import sys

try:
    with open('auto-deploy-config.json', 'r') as f:
        config = json.load(f)
    
    config['wallet']['private_key'] = '$WALLET_KEY'
    config['wallet']['batch_bind']['enabled'] = True
    config['wallet']['batch_bind']['count'] = $NODES_COUNT
    config['nodes']['count'] = $NODES_COUNT
    
    if '$DOMAIN_ID':
        config['wallet']['auto_join_domain'] = {
            'enabled': True,
            'domain_id': '$DOMAIN_ID'
        }
    
    with open('auto-deploy-config.json', 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('✅ 配置文件已更新')
except Exception as e:
    print(f'❌ 配置更新失败: {e}')
    sys.exit(1)
"
    else
        info "  🔄 配置自动生成钱包..."
    fi
    
    info "  ✅ 节点配置创建完成"
}

# 为完整自动化生成钱包
generate_wallet_for_full_auto() {
    info "  🔄 生成新钱包地址和私钥..."
    
    # 调用GUI的钱包生成功能
    if python3 src/gaianet_gui.py --headless --generate-wallet --save-to auto-deploy-config.json; then
        info "  ✅ 新钱包已生成并保存"
    else
        error "  ❌ 钱包生成失败"
        exit 1
    fi
}

# 显示钱包信息
show_wallet_info_for_full_auto() {
    info ""
    highlight "💰 钱包信息:"
    
    if [ -f "auto-deploy-config.json" ]; then
        python3 -c "
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

# 显示使用信息
show_usage_info() {
    highlight "🎯 安装完成！使用方法："
    echo ""
    echo "图形界面模式："
    echo "  双击桌面上的 '启动GaiaNet管理器.command'"
    echo "  或运行: cd $INSTALL_DIR && python3 src/gaianet_gui.py"
    echo ""
    echo "命令行模式："
    echo "  创建配置: python3 src/gaianet_gui.py --create-config"
    echo "  自动部署: python3 src/gaianet_gui.py --headless --auto-deploy"
    echo "  查看状态: python3 src/gaianet_gui.py --headless --status"
    echo ""
    echo "更多命令行选项："
    echo "  python3 src/gaianet_gui.py --help"
    echo ""
    
    if [ "$AUTO_DEPLOY" = true ]; then
        highlight "🔥 节点已自动部署并启动！"
        echo "你可以使用GUI界面进行后续管理和配置。"
    fi
}

# 主函数
main() {
    highlight "🚀 GaiaNet GUI 一键安装脚本"
    echo "=================================================="
    
    # 显示参数
    if [ "$FULL_AUTO" = true ]; then
        info "模式: 完整自动化部署 (新Mac推荐)"
        info "节点数量: $NODES_COUNT"
        if [ -n "$WALLET_KEY" ]; then
            info "钱包: 使用提供的私钥"
        else
            info "钱包: 自动生成"
        fi
        if [ -n "$DOMAIN_ID" ]; then
            info "域ID: $DOMAIN_ID"
        else
            info "域ID: 未指定，跳过域加入"
        fi
    elif [ "$AUTO_DEPLOY" = true ]; then
        info "模式: 安装 + 自动部署"
        info "节点数量: $NODES_COUNT"
        if [ -n "$WALLET_KEY" ]; then
            info "钱包: 已配置"
        fi
    else
        info "模式: 仅安装"
    fi
    
    echo ""
    
    # 执行步骤
    check_environment
    install_gaianet_gui
    
    if [ "$CREATE_CONFIG" = true ]; then
        create_auto_config
        info "✅ 配置文件已创建，请编辑后重新运行"
        exit 0
    fi
    
    if [ "$FULL_AUTO" = true ]; then
        # 完整自动化流程
        full_auto_deploy
    elif [ "$AUTO_DEPLOY" = true ]; then
        # 传统自动部署
        create_auto_config
        auto_deploy
    fi
    
    show_usage_info
}

# 错误处理
trap 'error "安装过程中发生错误，请检查网络连接和权限设置"' ERR

# 运行主函数
main "$@"