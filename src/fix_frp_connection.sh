#!/bin/bash

# FRP连接问题诊断和修复脚本
# 解决 "connection write timeout" 和注册失败问题

set -e

# 颜色定义
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
NC=$'\e[0m'

info() {
    printf "${GREEN}$1${NC}\n"
}

error() {
    printf "${RED}$1${NC}\n"
}

warning() {
    printf "${YELLOW}$1${NC}\n"
}

highlight() {
    printf "${BLUE}$1${NC}\n"
}

# 诊断FRP连接问题
diagnose_frp_connection() {
    local node_dir=$1
    
    highlight "🔍 诊断FRP连接问题"
    
    info "[1/5] 检查frpc.toml配置..."
    
    if [ ! -f "$node_dir/gaia-frp/frpc.toml" ]; then
        error "❌ frpc.toml文件不存在: $node_dir/gaia-frp/frpc.toml"
        return 1
    fi
    
    # 显示当前配置
    echo "当前frpc.toml配置:"
    cat "$node_dir/gaia-frp/frpc.toml"
    echo ""
    
    info "[2/5] 检查网络连接性..."
    
    # 测试DNS解析
    if nslookup gaia.domains >/dev/null 2>&1; then
        info "    ✅ DNS解析正常: gaia.domains"
    else
        warning "    ⚠️  DNS解析可能有问题"
    fi
    
    # 测试端口连接
    info "    测试端口7000连接..."
    # Mac兼容的连接测试
    if bash -c "exec 3<>/dev/tcp/198.18.0.22/7000 && echo 'test' >&3 && exec 3<&-" 2>/dev/null; then
        info "    ✅ 端口7000连接正常"
    else
        warning "    ⚠️  端口7000连接失败，可能被防火墙阻挡"
    fi
    
    info "[3/5] 检查系统代理设置..."
    
    # 检查环境变量中的代理设置
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
        warning "    ⚠️  检测到系统代理设置，可能影响FRP连接"
        echo "    HTTP代理: ${http_proxy:-${HTTP_PROXY:-未设置}}"
        echo "    HTTPS代理: ${https_proxy:-${HTTPS_PROXY:-未设置}}"
    else
        info "    ✅ 未检测到系统代理"
    fi
    
    info "[4/5] 检查防火墙状态..."
    
    # macOS防火墙检查
    if command -v sudo >/dev/null 2>&1; then
        local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep "enabled" || echo "disabled")
        if [[ "$firewall_status" == *"enabled"* ]]; then
            warning "    ⚠️  macOS防火墙已启用，可能阻挡FRP连接"
        else
            info "    ✅ macOS防火墙未阻挡"
        fi
    fi
    
    info "[5/5] 生成连接测试报告..."
    
    local report_file="/tmp/frp_diagnosis_$(date +%Y%m%d_%H%M%S).log"
    
    cat > "$report_file" << EOF
=== FRP连接诊断报告 ===
时间: $(date)
节点: $(basename "$node_dir")

1. 配置文件检查:
$(cat "$node_dir/gaia-frp/frpc.toml")

2. 网络测试:
DNS解析测试: $(nslookup gaia.domains 2>&1 | head -5)

端口连接测试: $(bash -c "exec 3<>/dev/tcp/198.18.0.22/7000 && echo '连接成功' && exec 3<&-" 2>/dev/null || echo "连接失败")

3. 系统环境:
HTTP代理: ${http_proxy:-未设置}
HTTPS代理: ${https_proxy:-未设置}

4. 建议解决方案:
EOF
    
    info "✅ 诊断报告生成: $report_file"
}

# 修复FRP配置
fix_frp_config() {
    local node_dir=$1
    
    highlight "🔧 修复FRP配置"
    
    local frpc_file="$node_dir/gaia-frp/frpc.toml"
    
    # 备份原配置
    cp "$frpc_file" "$frpc_file.backup.$(date +%Y%m%d_%H%M%S)"
    info "✅ 配置已备份"
    
    # 读取当前配置
    local device_id=$(grep "deviceId" "$frpc_file" | cut -d'"' -f2)
    local subdomain=$(grep "subdomain" "$frpc_file" | cut -d'"' -f2)
    local local_port=$(grep "localPort" "$frpc_file" | awk -F'=' '{print $2}' | tr -d ' ')
    
    info "修复FRP配置参数:"
    echo "  Device ID: $device_id"
    echo "  Subdomain: $subdomain"  
    echo "  Local Port: $local_port"
    
    # 生成优化的frpc.toml配置
    cat > "$frpc_file" << EOF
[common]
serverAddr = "gaia.domains"
serverPort = 7000
loginFailExit = false

[metadatas]
deviceId = "$device_id"

[$subdomain.gaia.domains]
type = "http"
localPort = $local_port
subdomain = "$subdomain"
name = "$subdomain.gaia.domains"

# 连接优化配置
[common.tcp_mux]
enabled = true

[common.heartbeat]
interval = 30
timeout = 90

[common.dial]
timeout = 30

[common.proxy]
pool_count = 1
EOF
    
    info "✅ FRP配置已优化"
}

# 测试修复后的连接
test_fixed_connection() {
    local node_dir=$1
    
    highlight "🧪 测试修复后的FRP连接"
    
    # 启动测试
    info "启动FRP测试连接..."
    
    cd "$node_dir"
    
    # Mac兼容的后台进程启动
    ./bin/frpc -c gaia-frp/frpc.toml > /tmp/frpc_test_$(date +%s).log 2>&1 &
    local frpc_pid=$!
    
    info "FRP测试进程PID: $frpc_pid"
    
    # 等待连接建立
    sleep 10
    
    # 检查进程状态
    if kill -0 $frpc_pid 2>/dev/null; then
        info "✅ FRP进程运行中"
        
        # 检查连接
        if netstat -an | grep ":7000" | grep "ESTABLISHED" >/dev/null; then
            info "✅ FRP连接已建立"
        else
            warning "⚠️  FRP连接未建立，检查日志："
            echo "$(tail -5 /tmp/frpc_test_*.log 2>/dev/null | tail -5)"
        fi
    else
        error "❌ FRP进程已退出，检查日志："
        echo "$(tail -10 /tmp/frpc_test_*.log 2>/dev/null | tail -10)"
    fi
    
    # 停止测试进程
    kill $frpc_pid 2>/dev/null || true
    sleep 2
    kill -9 $frpc_pid 2>/dev/null || true
    
    info "✅ 连接测试完成"
}

# 主函数
main() {
    local node_dir="${1:-/Users/bk-00/gaianet_node2}"
    local action="${2:-diagnose}"
    
    if [ ! -d "$node_dir" ]; then
        error "❌ 节点目录不存在: $node_dir"
        exit 1
    fi
    
    case $action in
        diagnose)
            diagnose_frp_connection "$node_dir"
            ;;
        fix)
            diagnose_frp_connection "$node_dir"
            fix_frp_config "$node_dir" 
            test_fixed_connection "$node_dir"
            ;;
        test)
            test_fixed_connection "$node_dir"
            ;;
        help|--help|-h)
            echo "FRP连接问题诊断和修复工具"
            echo ""
            echo "用法: $0 [节点目录] [动作]"
            echo ""
            echo "动作:"
            echo "  diagnose  - 诊断FRP连接问题（默认）"
            echo "  fix       - 诊断并修复FRP配置"
            echo "  test      - 测试FRP连接"
            echo "  help      - 显示帮助"
            echo ""
            echo "示例:"
            echo "  $0 /Users/bk-00/gaianet_node2 diagnose"
            echo "  $0 /Users/bk-00/gaianet_node2 fix"
            ;;
        *)
            error "❌ 未知动作: $action"
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"