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
NODES_COUNT=20
WALLET_KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-deploy)
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
        -h|--help)
            echo "GaiaNet GUI 一键安装脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --auto-deploy     安装后自动部署节点"
            echo "  --create-config   创建配置文件后退出"
            echo "  --nodes NUM       节点数量 (默认: 20)"
            echo "  --wallet KEY      钱包私钥"
            echo "  -h, --help        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                           # 仅安装GUI"
            echo "  $0 --auto-deploy            # 安装后自动部署"
            echo "  $0 --create-config          # 创建配置文件"
            echo "  $0 --auto-deploy --nodes 10 # 部署10个节点"
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
    fi
    
    info "✅ Python3已安装: $(python3 --version)"
    
    # 检查Git
    if ! command -v git >/dev/null 2>&1; then
        error "Git未安装，请先安装Git"
        error "建议使用Homebrew安装: brew install git"
        exit 1
    fi
    
    info "✅ Git已安装: $(git --version)"
    
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
    if [ "$AUTO_DEPLOY" = true ]; then
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
    
    if [ "$AUTO_DEPLOY" = true ]; then
        create_auto_config
        auto_deploy
    fi
    
    show_usage_info
}

# 错误处理
trap 'error "安装过程中发生错误，请检查网络连接和权限设置"' ERR

# 运行主函数
main "$@"