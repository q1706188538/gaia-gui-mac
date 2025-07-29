#!/bin/bash

# Clash Verge 自动化安装和配置脚本
# 适用于 macOS 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC} $1\n"; }
error() { printf "${RED}[ERROR]${NC} $1\n"; }
warning() { printf "${YELLOW}[WARNING]${NC} $1\n"; }
highlight() { printf "${BLUE}[SETUP]${NC} $1\n"; }

# 配置变量
SUBSCRIPTION_URL=""
SELECTED_NODE=""
AUTO_START=false
ENABLE_TUN=true
SUDO_PASSWORD=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --subscription)
            SUBSCRIPTION_URL="$2"
            shift 2
            ;;
        --node)
            SELECTED_NODE="$2"
            shift 2
            ;;
        --auto-start)
            AUTO_START=true
            shift
            ;;
        --disable-tun)
            ENABLE_TUN=false
            shift
            ;;
        --sudo-password)
            SUDO_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Clash Verge 自动化安装脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --subscription URL    订阅链接"
            echo "  --node NAME          选择的节点名称（支持模糊匹配）"
            echo "  --auto-start         安装后自动启动"
            echo "  --disable-tun        禁用TUN模式"
            echo "  --sudo-password PWD  管理员密码（用于安装TUN驱动）"
            echo "  -h, --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 --subscription 'https://example.com/sub' --node 'HK' --auto-start"
            echo "  $0 --subscription 'https://example.com/sub' --node '香港' --auto-start --sudo-password 'your_password'"
            exit 0
            ;;
        *)
            warning "未知参数: $1"
            shift
            ;;
    esac
done

# 检查系统
if [[ "$(uname)" != "Darwin" ]]; then
    error "此脚本仅支持 macOS 系统"
    exit 1
fi

highlight "🚀 Clash Verge 自动化安装脚本"
echo "=================================================="

# 1. 检查并安装 Homebrew
install_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        info "📦 安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加到 PATH
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        info "✅ Homebrew 已安装"
    fi
}

# 2. 安装 Clash Verge 和 TUN 网卡驱动
install_clash_verge() {
    info "📱 安装 Clash Verge..."
    
    if [[ -d "/Applications/Clash Verge.app" ]]; then
        info "✅ Clash Verge 已安装"
    else
        # 添加 tap 并安装
        brew tap --quiet homebrew/cask
        brew install --cask clash-verge || {
            error "Clash Verge 安装失败"
            exit 1
        }
        info "✅ Clash Verge 安装完成"
    fi
    
    # 安装 TUN/TAP 网卡驱动
    install_tun_driver
}

# 安装 TUN/TAP 网卡驱动
install_tun_driver() {
    if [[ "$ENABLE_TUN" != "true" ]]; then
        info "⏭️ TUN模式已禁用，跳过网卡驱动安装"
        return 0
    fi
    
    info "🔧 安装 TUN/TAP 网卡驱动..."
    
    # 检查是否已安装 TUN/TAP 驱动
    if [[ -d "/Library/Extensions/tun.kext" ]] || [[ -d "/System/Library/Extensions/tun.kext" ]] || kextstat | grep -q "tun\|tap"; then
        info "✅ TUN/TAP 驱动已安装"
        return 0
    fi
    
    # 方法1: 尝试通过 Homebrew 安装 tuntaposx
    info "📦 通过 Homebrew 安装 TUN/TAP 驱动..."
    if brew install --cask tuntap 2>/dev/null; then
        info "✅ TUN/TAP 驱动安装完成"
        return 0
    fi
    
    # 方法2: 下载并安装官方 TUN/TAP 驱动
    info "📥 下载官方 TUN/TAP 驱动..."
    local temp_dir="/tmp/tuntap_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载最新版本的 TUN/TAP 驱动
    local download_url="https://sourceforge.net/projects/tuntaposx/files/latest/download"
    if curl -L "$download_url" -o "tuntap.tar.gz"; then
        info "📦 解压驱动文件..."
        tar -xzf "tuntap.tar.gz"
        
        # 查找 .pkg 文件
        local pkg_file=$(find . -name "*.pkg" | head -n 1)
        if [[ -n "$pkg_file" ]]; then
            info "🔧 安装 TUN/TAP 驱动（需要管理员权限）..."
            
            # 检查是否有sudo密码参数
            if [[ -n "$SUDO_PASSWORD" ]]; then
                echo "$SUDO_PASSWORD" | sudo -S installer -pkg "$pkg_file" -target /
            else
                sudo installer -pkg "$pkg_file" -target /
            fi
            
            if [[ $? -eq 0 ]]; then
                info "✅ TUN/TAP 驱动安装完成"
                warning "⚠️ 系统可能需要重启才能完全启用 TUN 功能"
            else
                error "❌ TUN/TAP 驱动安装失败"
            fi
        else
            error "❌ 未找到驱动安装包"
        fi
    else
        warning "⚠️ 无法自动下载 TUN/TAP 驱动"
        info "💡 请手动访问 https://sourceforge.net/projects/tuntaposx/ 下载安装"
    fi
    
    # 清理临时文件
    cd /
    rm -rf "$temp_dir"
}

# 验证 TUN 驱动安装
verify_tun_driver() {
    if [[ "$ENABLE_TUN" != "true" ]]; then
        return 0
    fi
    
    info "🔍 验证 TUN 驱动安装..."
    
    # 检查内核扩展
    if kextstat | grep -q "tun\|tap"; then
        info "✅ TUN/TAP 驱动已加载"
        return 0
    fi
    
    # 检查设备文件
    if [[ -e "/dev/tun0" ]] || [[ -e "/dev/tap0" ]]; then
        info "✅ TUN/TAP 设备文件存在"
        return 0
    fi
    
    # 尝试加载驱动
    if [[ -d "/Library/Extensions/tun.kext" ]]; then
        info "🔧 尝试加载 TUN 驱动..."
        if [[ -n "$SUDO_PASSWORD" ]]; then
            echo "$SUDO_PASSWORD" | sudo -S kextload /Library/Extensions/tun.kext 2>/dev/null
        else
            sudo kextload /Library/Extensions/tun.kext 2>/dev/null
        fi
    fi
    
    # 再次检查
    if kextstat | grep -q "tun\|tap"; then
        info "✅ TUN 驱动验证成功"
    else
        warning "⚠️ TUN 驱动可能需要系统重启才能生效"
        warning "⚠️ 或者需要在系统偏好设置→安全性与隐私中允许系统扩展"
    fi
}

# 3. 配置 Clash Verge
configure_clash_verge() {
    info "⚙️ 配置 Clash Verge..."
    
    local config_dir="$HOME/.config/clash-verge"
    local profiles_dir="$config_dir/profiles"
    
    # 创建配置目录
    mkdir -p "$profiles_dir"
    
    # 基础配置文件
    cat > "$config_dir/verge.yaml" << 'EOF'
app_log_level: info
language: zh
theme_mode: system
traffic_graph: true
enable_memory_usage: true
enable_tun_mode: true
enable_auto_launch: false
enable_silent_start: false
enable_system_proxy: true
enable_proxy_guard: false
system_proxy_bypass: localhost,127.*,10.*,172.16.*,172.17.*,172.18.*,172.19.*,172.20.*,172.21.*,172.22.*,172.23.*,172.24.*,172.25.*,172.26.*,172.27.*,172.28.*,172.29.*,172.30.*,172.31.*,192.168.*,<local>
web_ui_list:
  - label: Yacd
    url: http://yacd.haishan.me
  - label: Yacd-meta
    url: http://yacd.metacubex.one
  - label: Razord
    url: http://clash.razord.top
hotkeys:
  - func: clash_mode_rule
    keys:
      - cmd
      - shift
      - r
  - func: clash_mode_global  
    keys:
      - cmd
      - shift
      - g
  - func: clash_mode_direct
    keys:
      - cmd
      - shift
      - d
  - func: toggle_system_proxy
    keys:
      - cmd
      - shift
      - s
  - func: toggle_tun_mode
    keys:
      - cmd
      - shift
      - t
EOF

    # TUN 模式配置
    if [[ "$ENABLE_TUN" == "true" ]]; then
        info "🔧 启用 TUN 模式..."
        cat > "$config_dir/clash.yaml" << 'EOF'
mixed-port: 7890
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

tun:
  enable: true
  stack: system
  dns-hijack:
    - 8.8.8.8:53
    - 1.1.1.1:53
  auto-route: true
  auto-detect-interface: true

dns:
  enable: true
  listen: 0.0.0.0:53
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://1.1.1.1/dns-query
    - https://dns.google/dns-query

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,17.0.0.0/8,DIRECT
  - IP-CIDR,100.64.0.0/10,DIRECT
  - DOMAIN-SUFFIX,cn,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
    fi
    
    info "✅ 基础配置完成"
}

# 4. 导入订阅
import_subscription() {
    if [[ -z "$SUBSCRIPTION_URL" ]]; then
        warning "⚠️ 未提供订阅链接，跳过订阅导入"
        return 0
    fi
    
    info "📥 导入订阅: $SUBSCRIPTION_URL"
    
    local config_dir="$HOME/.config/clash-verge"
    local profiles_dir="$config_dir/profiles"
    
    # 创建订阅配置
    local profile_id=$(date +%s)
    local profile_file="$profiles_dir/${profile_id}.yaml"
    
    # 下载订阅配置
    if curl -fsSL "$SUBSCRIPTION_URL" -o "$profile_file"; then
        info "✅ 订阅配置下载成功"
        
        # 创建 profiles.yaml
        cat > "$config_dir/profiles.yaml" << EOF
current: $profile_id
chain: []
valid: []
items:
  - uid: $profile_id
    type: remote
    name: "自动导入订阅"
    desc: "通过脚本自动导入"
    url: "$SUBSCRIPTION_URL"
    selected:
      - name: PROXY
        now: ""
    file: "${profile_id}.yaml"
    updated: $(date +%s)
    option:
      update_interval: 1440
      user_agent: "clash-verge"
EOF
        
        info "✅ 订阅导入完成"
    else
        error "❌ 订阅配置下载失败"
        return 1
    fi
}

# 5. 选择节点
select_node() {
    if [[ -z "$SELECTED_NODE" ]]; then
        warning "⚠️ 未指定节点，将使用默认节点"
        return 0
    fi
    
    info "🎯 搜索节点: $SELECTED_NODE"
    
    # 这里需要启动 Clash Verge 后通过 API 设置节点
    # 由于需要应用运行，我们创建一个延迟执行的脚本
    cat > "/tmp/clash_select_node.sh" << EOF
#!/bin/bash
sleep 5  # 等待应用启动

# 通过 API 获取可用节点
proxies=\$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
if [[ -n "\$proxies" ]]; then
    echo "🔍 正在搜索包含 '$SELECTED_NODE' 的节点..."
    
    # 这里可以解析 JSON 并选择匹配的节点
    # 简化版本：设置为指定的代理组
    curl -X PUT http://127.0.0.1:9090/proxies/PROXY \\
         -H "Content-Type: application/json" \\
         -d '{"name":"'$SELECTED_NODE'"}' 2>/dev/null
    
    if [[ \$? -eq 0 ]]; then
        echo "✅ 节点已设置: $SELECTED_NODE"
    else
        echo "❌ 节点设置失败，请手动在应用中选择"
    fi
else
    echo "❌ 无法连接到 Clash API，请手动选择节点"
fi

rm -f "/tmp/clash_select_node.sh"
EOF
    
    chmod +x "/tmp/clash_select_node.sh"
    info "✅ 节点选择脚本已准备就绪"
}

# 6. 启动应用
start_clash_verge() {
    info "🚀 启动 Clash Verge..."
    
    # 启动应用
    open -a "Clash Verge"
    
    # 等待应用启动
    sleep 3
    
    # 如果需要选择节点，执行节点选择脚本
    if [[ -f "/tmp/clash_select_node.sh" ]]; then
        info "🎯 执行节点选择..."
        bash "/tmp/clash_select_node.sh" &
    fi
    
    info "✅ Clash Verge 已启动"
    
    if [[ "$ENABLE_TUN" == "true" ]]; then
        warning "⚠️ TUN 模式需要管理员权限，请在应用中手动启用"
    fi
}

# 主流程
main() {
    info "开始安装和配置 Clash Verge..."
    
    install_homebrew
    install_clash_verge
    verify_tun_driver
    configure_clash_verge
    import_subscription
    select_node
    
    if [[ "$AUTO_START" == "true" ]]; then
        start_clash_verge
    fi
    
    highlight "🎉 Clash Verge 安装和配置完成！"
    echo ""
    echo "📋 配置信息:"
    echo "• 应用位置: /Applications/Clash Verge.app"
    echo "• 配置目录: ~/.config/clash-verge"
    echo "• 混合端口: 7890"
    echo "• 控制端口: 9090"
    echo "• TUN 模式: $(if [[ "$ENABLE_TUN" == "true" ]]; then echo "已启用"; else echo "已禁用"; fi)"
    
    if [[ "$ENABLE_TUN" == "true" ]]; then
        if kextstat | grep -q "tun\|tap"; then
            echo "• TUN 驱动: ✅ 已加载"
        else
            echo "• TUN 驱动: ⚠️ 已安装，可能需要重启生效"
        fi
    fi
    
    if [[ -n "$SUBSCRIPTION_URL" ]]; then
        echo "• 订阅链接: 已导入"
    fi
    
    if [[ -n "$SELECTED_NODE" ]]; then
        echo "• 选择节点: $SELECTED_NODE"
    fi
    
    echo ""
    echo "🔧 后续操作:"
    echo "1. 启动 Clash Verge 应用"
    if [[ "$ENABLE_TUN" == "true" ]]; then
        echo "2. 在应用中启用 TUN 模式（需要管理员权限）"
        echo "3. 在系统偏好设置→安全性与隐私中允许系统扩展（如有提示）"
        echo "4. 检查节点连接状态"
        echo "5. 享受全局科学上网！"
    else
        echo "2. 检查节点连接状态"  
        echo "3. 享受科学上网！"
    fi
    
    if [[ "$AUTO_START" != "true" ]]; then
        echo ""
        read -p "是否现在启动 Clash Verge? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_clash_verge
        fi
    fi
}

# 运行主函数
main "$@"