#!/bin/bash

# GaiaNet GUI 环境自动安装脚本
# 适用于macOS系统

set -e

# 颜色定义
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
NC=$'\e[0m'

info() { printf "${GREEN}$1${NC}\n"; }
error() { printf "${RED}$1${NC}\n"; }
warning() { printf "${YELLOW}$1${NC}\n"; }
highlight() { printf "${BLUE}$1${NC}\n"; }

echo ""
highlight "🚀 GaiaNet GUI 环境自动安装器"
echo ""

# 检查系统
if [[ "$(uname)" != "Darwin" ]]; then
    error "❌ 此脚本仅支持macOS系统"
    exit 1
fi

info "✅ 系统检查通过: macOS"

# 检查是否已有Python3
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    info "✅ 已安装Python: $PYTHON_VERSION"
    
    # 检查tkinter
    if python3 -c "import tkinter" 2>/dev/null; then
        info "✅ tkinter可用"
        info "🎉 环境已就绪！可以直接启动GUI"
        
        read -p "是否现在启动GUI？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./start_gui.sh
        fi
        exit 0
    else
        warning "⚠️  tkinter不可用，需要安装"
    fi
else
    warning "⚠️  未找到Python3，需要安装"
fi

echo ""
highlight "🔧 开始安装Python环境..."

# 检查Homebrew
if command -v brew >/dev/null 2>&1; then
    info "✅ Homebrew已安装"
else
    info "📦 正在安装Homebrew..."
    echo "这可能需要几分钟时间，请耐心等待..."
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 添加Homebrew到PATH（Apple Silicon Mac）
    if [[ -d "/opt/homebrew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    info "✅ Homebrew安装完成"
fi

# 安装Python
info "📦 正在安装Python..."
brew install python

# 安装tkinter
info "📦 正在安装Python tkinter支持..."
brew install python-tk

# 验证安装
echo ""
info "🔍 验证安装结果..."

if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    info "✅ Python安装成功: $PYTHON_VERSION"
else
    error "❌ Python安装失败"
    exit 1
fi

if python3 -c "import tkinter" 2>/dev/null; then
    info "✅ tkinter安装成功"
else
    error "❌ tkinter安装失败"
    
    warning "💡 尝试替代方案..."
    info "正在安装Xcode命令行工具..."
    xcode-select --install 2>/dev/null || true
    
    # 再次检查
    if python3 -c "import tkinter" 2>/dev/null; then
        info "✅ tkinter现在可用"
    else
        error "❌ tkinter仍然不可用"
        echo ""
        error "请尝试以下解决方案："
        echo "1. 重启终端后重试"
        echo "2. 手动安装: brew reinstall python-tk"
        echo "3. 使用官方Python安装包: https://www.python.org/downloads/"
        exit 1
    fi
fi

# 检查其他依赖
info "🔍 检查其他依赖..."

# 检查必要的系统工具
required_tools=("curl" "lsof" "jq")
missing_tools=()

for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    info "📦 安装缺失的工具: ${missing_tools[*]}"
    for tool in "${missing_tools[@]}"; do
        case $tool in
            "jq")
                brew install jq
                ;;
            "curl"|"lsof")
                # 这些通常是系统自带的
                warning "⚠️  系统缺少 $tool，这很不常见"
                ;;
        esac
    done
fi

# 最终验证
echo ""
info "🎯 最终环境检查..."

checks_passed=0
total_checks=3

# 检查Python
if command -v python3 >/dev/null 2>&1; then
    info "✅ Python3: $(python3 --version 2>&1)"
    ((checks_passed++))
else
    error "❌ Python3: 未安装"
fi

# 检查tkinter
if python3 -c "import tkinter" 2>/dev/null; then
    info "✅ tkinter: 可用"
    ((checks_passed++))
else
    error "❌ tkinter: 不可用"
fi

# 检查GUI脚本
if [ -f "./gaianet_gui.py" ]; then
    info "✅ GUI脚本: 存在"
    ((checks_passed++))
else
    warning "⚠️  GUI脚本: 未找到 (gaianet_gui.py)"
fi

echo ""
if [ $checks_passed -eq $total_checks ]; then
    highlight "🎉 安装完成！环境已就绪"
    echo ""
    info "现在可以启动GaiaNet GUI了："
    echo "  ./start_gui.sh"
    echo ""
    
    read -p "是否现在启动GUI？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "🚀 启动GUI..."
        ./start_gui.sh
    else
        info "💡 稍后可以运行 ./start_gui.sh 启动GUI"
    fi
else
    warning "⚠️  安装部分完成 ($checks_passed/$total_checks 项检查通过)"
    echo ""
    info "请根据上述错误信息进行修复，然后重新运行此脚本"
fi