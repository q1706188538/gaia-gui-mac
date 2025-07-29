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
            echo "  -h, --help        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 --full-auto --nodes 20 --domain-id 742"
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
    
    # 检查Python3
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3未安装，请先安装Python3"
        exit 1
    fi
    info "✅ Python3已安装"
    
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
        if pip3 install -r requirements.txt; then
            info "✅ 依赖安装完成"
        else
            warning "依赖安装失败，请手动运行: pip3 install -r requirements.txt"
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
python3 src/gaianet_gui.py
EOF
    
    chmod +x "$HOME/Desktop/启动GaiaNet管理器.command"
    
    info "✅ 快速安装完成！"
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
        # 调用完整自动化流程
        info "🔄 切换到完整自动化流程..."
        
        # 构建参数
        local full_cmd="cd '$INSTALL_DIR' && python3 src/gaianet_gui.py --headless --create-config --nodes $NODES_COUNT"
        
        # 创建配置
        eval "$full_cmd"
        
        # 如果提供了钱包或域ID，更新配置
        if [ -n "$WALLET_KEY" ] || [ -n "$DOMAIN_ID" ]; then
            python3 -c "
import json
import sys

try:
    with open('auto-deploy-config.json', 'r') as f:
        config = json.load(f)
    
    if '$WALLET_KEY':
        config['wallet']['private_key'] = '$WALLET_KEY'
        config['wallet']['batch_bind']['enabled'] = True
    
    if '$DOMAIN_ID':
        if 'auto_join_domain' not in config['wallet']:
            config['wallet']['auto_join_domain'] = {}
        config['wallet']['auto_join_domain']['enabled'] = True
        config['wallet']['auto_join_domain']['domain_id'] = '$DOMAIN_ID'
    
    with open('auto-deploy-config.json', 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('✅ 配置文件已更新')
except Exception as e:
    print(f'❌ 配置更新失败: {e}')
    sys.exit(1)
"
        fi
        
        highlight "🎉 快速安装完成！"
        info "💡 现在可以使用GUI或继续自动化流程"
    fi
    
    show_usage_info
}

# 显示使用信息
show_usage_info() {
    highlight "🎯 快速安装完成！使用方法："
    echo ""
    echo "图形界面模式："
    echo "  双击桌面上的 '启动GaiaNet管理器.command'"
    echo ""
    echo "继续自动化部署："
    echo "  cd $INSTALL_DIR"
    echo "  python3 src/gaianet_gui.py --headless --auto-deploy"
    echo ""
    
    if [ "$FULL_AUTO" = true ]; then
        highlight "🔥 快速安装完成，可继续使用GUI进行自动化部署！"
        echo "优势: 无需安装Xcode命令行工具，安装速度快10倍+"
    fi
}

# 错误处理
trap 'error "安装过程中发生错误"' ERR

# 运行主函数
main "$@"