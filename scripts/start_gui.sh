#!/bin/bash

# GaiaNet GUI启动脚本
# 适用于macOS系统

set -e

# 颜色定义
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

info() { printf "${GREEN}$1${NC}\n"; }
error() { printf "${RED}$1${NC}\n"; }
warning() { printf "${YELLOW}$1${NC}\n"; }

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_SCRIPT="$SCRIPT_DIR/gaianet_gui.py"

# 检查系统
if [[ "$(uname)" != "Darwin" ]]; then
    error "❌ 此程序仅支持macOS系统"
    exit 1
fi

info "🚀 启动GaiaNet多节点部署管理器..."

# 检查Python环境
check_python_environment() {
    local python_ok=false
    local tkinter_ok=false
    
    # 检查Python
    if command -v python3 >/dev/null 2>&1; then
        python_ok=true
        info "✅ Python3: $(python3 --version 2>&1)"
    else
        error "❌ 未找到Python3"
    fi
    
    # 检查tkinter
    if $python_ok && python3 -c "import tkinter" 2>/dev/null; then
        tkinter_ok=true
        info "✅ tkinter: 可用"
    else
        error "❌ tkinter: 不可用"
    fi
    
    if $python_ok && $tkinter_ok; then
        return 0
    else
        return 1
    fi
}

# 如果环境不满足，提供安装选项
if ! check_python_environment; then
    echo ""
    warning "⚠️  Python环境不完整，需要安装相关依赖"
    echo ""
    echo "解决方案："
    echo "1. 🚀 自动安装 (推荐) - 运行环境安装脚本"
    echo "2. 🔧 手动安装 - 自己安装Python和tkinter"
    echo "3. ❌ 退出"
    echo ""
    
    read -p "请选择 (1/2/3): " -n 1 -r choice
    echo ""
    
    case $choice in
        1)
            if [ -f "$SCRIPT_DIR/install_gui_environment.sh" ]; then
                info "🚀 启动自动安装..."
                bash "$SCRIPT_DIR/install_gui_environment.sh"
                exit 0
            else
                error "❌ 未找到安装脚本: install_gui_environment.sh"
                echo ""
                info "💡 手动安装方法:"
                echo "brew install python python-tk"
                exit 1
            fi
            ;;
        2)
            echo ""
            info "📋 手动安装步骤:"
            echo "1. 安装Homebrew:"
            echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            echo ""
            echo "2. 安装Python和tkinter:"
            echo "   brew install python python-tk"
            echo ""
            echo "3. 重新运行此脚本"
            exit 0
            ;;
        3|*)
            info "👋 已退出"
            exit 0
            ;;
    esac
fi

# 检查GUI脚本
if [ ! -f "$GUI_SCRIPT" ]; then
    error "❌ 未找到GUI脚本: $GUI_SCRIPT"
    exit 1
fi

# 检查权限
if [ ! -x "$GUI_SCRIPT" ]; then
    info "设置GUI脚本执行权限..."
    chmod +x "$GUI_SCRIPT"
fi

# 检查必要的脚本文件
required_scripts=("deploy_multinode_advanced.sh" "check_system_status.sh")
missing_scripts=()

for script in "${required_scripts[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    warning "⚠️  以下脚本文件缺失，部分功能可能不可用:"
    for script in "${missing_scripts[@]}"; do
        echo "   - $script"
    done
    echo ""
    
    read -p "是否仍要继续启动GUI？(y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "👋 已取消启动"
        exit 0
    fi
fi

# 启动GUI
info "✅ 启动图形界面..."
cd "$SCRIPT_DIR"

# 尝试启动GUI
if python3 "$GUI_SCRIPT"; then
    info "✅ GUI已正常退出"
else
    error "❌ GUI启动失败"
    echo ""
    error "💡 故障排除:"
    
    # 显示Python信息
    echo ""
    info "Python环境信息:"
    python3 --version
    python3 -c "import sys; print(f'Python路径: {sys.executable}')"
    
    # 重新检查tkinter
    echo ""
    if python3 -c "import tkinter; print('✅ tkinter可用')" 2>/dev/null; then
        info "✅ tkinter模块正常"
        
        # 尝试创建简单的tkinter窗口测试
        info "🧪 测试tkinter功能..."
        if python3 -c "
import tkinter as tk
root = tk.Tk()
root.withdraw()  # 隐藏窗口
print('✅ tkinter功能正常')
root.quit()
        " 2>/dev/null; then
            error "❌ tkinter测试通过，但GUI启动失败"
            error "    这可能是GUI脚本的问题，请检查脚本文件"
        else
            error "❌ tkinter功能测试失败"
            error "    可能是显示器相关问题，请确保在图形界面环境下运行"
        fi
    else
        error "❌ tkinter模块不可用"
        echo ""
        info "💡 尝试修复:"
        echo "1. 重新安装Python tkinter支持:"
        echo "   brew reinstall python-tk"
        echo ""
        echo "2. 或者使用官方Python安装包:"
        echo "   https://www.python.org/downloads/"
    fi
    
    exit 1
fi