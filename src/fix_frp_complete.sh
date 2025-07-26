#!/bin/bash

# 完全修复FRP连接问题
# 解决DNS解析和配置格式问题

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

# 修复DNS解析问题
fix_dns_resolution() {
    local node_dir=$1
    
    highlight "🔧 修复DNS解析问题"
    
    # 测试DNS解析
    info "[1/3] 测试当前DNS解析..."
    local resolved_ip=$(nslookup gaia.domains 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    
    if [ "$resolved_ip" = "198.18.0.22" ]; then
        info "    ✅ DNS解析正确: gaia.domains -> $resolved_ip"
        return 0
    else
        warning "    ⚠️  DNS解析异常: gaia.domains -> $resolved_ip"
    fi
    
    # 检查/etc/hosts
    info "[2/3] 检查本地hosts文件..."
    if grep -q "gaia.domains" /etc/hosts 2>/dev/null; then
        info "    发现hosts条目:"
        grep "gaia.domains" /etc/hosts
    else
        info "    ✅ hosts文件中无gaia.domains条目"
    fi
    
    # 使用直接IP连接
    info "[3/3] 配置直接IP连接..."
    local frpc_file="$node_dir/gaia-frp/frpc.toml"
    
    # 备份并创建新配置
    cp "$frpc_file" "$frpc_file.backup.$(date +%s)"
    
    # 读取配置参数
    local device_id=$(grep -E "deviceId|device_id" "$frpc_file" | cut -d'"' -f2 | head -1)
    local subdomain=$(grep -E "subdomain" "$frpc_file" | cut -d'"' -f2 | head -1)
    local local_port=$(grep -E "localPort" "$frpc_file" | grep -o '[0-9]*' | head -1)
    
    info "配置参数:"
    echo "  Device ID: $device_id"
    echo "  Subdomain: $subdomain"
    echo "  Local Port: $local_port"
    
    # 创建新的TOML格式配置
    cat > "$frpc_file" << EOL
# GaiaNet FRP Client Configuration - Fixed Version
# 使用直接IP地址避免DNS解析问题

serverAddr = "198.18.0.22"
serverPort = 7000
loginFailExit = false
protocol = "tcp"

# 连接优化
transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90
transport.tcpMux = true
transport.dialServerTimeout = 20

# 元数据
metadatas.deviceId = "$device_id"

# 代理配置
[[proxies]]
name = "$subdomain.gaia.domains"
type = "http"
localIP = "127.0.0.1"
localPort = $local_port
subdomain = "$subdomain"

# 请求头设置
[[proxies.requestHeaders]]
set.Host = "$subdomain.gaia.domains"
EOL
    
    info "✅ 已创建优化的FRP配置（直接IP连接）"
}

# 测试修复后的连接
test_fixed_frp_connection() {
    local node_dir=$1
    
    highlight "🧪 测试修复后的FRP连接"
    
    cd "$node_dir"
    
    # 启动测试连接
    info "启动FRP测试连接（直接IP）..."
    
    local log_file="/tmp/frpc_fixed_test_$(date +%s).log"
    ./bin/frpc -c gaia-frp/frpc.toml > "$log_file" 2>&1 &
    local frpc_pid=$!
    
    info "FRP测试进程PID: $frpc_pid"
    
    # 等待连接建立
    info "等待连接建立..."
    sleep 15
    
    # 检查进程状态
    if kill -0 $frpc_pid 2>/dev/null; then
        info "✅ FRP进程运行中"
        
        # 检查日志中的连接状态
        if grep -q "login to server success" "$log_file" 2>/dev/null; then
            info "✅ 成功登录到FRP服务器"
        elif grep -q "start proxy success" "$log_file" 2>/dev/null; then
            info "✅ 代理启动成功"
        else
            warning "⚠️  检查连接日志:"
            tail -10 "$log_file"
        fi
        
        # 检查网络连接
        if netstat -an | grep "198.18.0.22:7000" | grep "ESTABLISHED" >/dev/null; then
            info "✅ 与GaiaNet服务器连接已建立"
        else
            warning "⚠️  未发现与GaiaNet服务器的连接"
        fi
    else
        error "❌ FRP进程已退出，检查错误日志:"
        cat "$log_file"
    fi
    
    # 停止测试进程
    kill $frpc_pid 2>/dev/null || true
    sleep 2
    kill -9 $frpc_pid 2>/dev/null || true
    
    info "测试日志保存在: $log_file"
    info "✅ 连接测试完成"
}

# 验证配置并启动节点
verify_and_start_node() {
    local node_dir=$1
    
    highlight "🚀 验证配置并启动节点"
    
    # 验证配置文件
    info "[1/3] 验证FRP配置..."
    local frpc_file="$node_dir/gaia-frp/frpc.toml"
    
    if [ -f "$frpc_file" ]; then
        info "    ✅ FRP配置文件存在"
        
        # 检查关键配置
        if grep -q "198.18.0.22" "$frpc_file" && grep -q "deviceId" "$frpc_file"; then
            info "    ✅ 关键配置参数正确"
        else
            error "    ❌ 配置参数缺失"
            return 1
        fi
    else
        error "    ❌ FRP配置文件不存在"
        return 1
    fi
    
    # 停止现有节点
    info "[2/3] 停止现有节点..."
    if [ -f "./gaianet_proxy.sh" ]; then
        ./gaianet_proxy.sh stop --base "$node_dir" 2>/dev/null || true
        sleep 3
    fi
    
    # 启动节点
    info "[3/3] 启动节点..."
    if [ -f "./gaianet_proxy.sh" ]; then
        ./gaianet_proxy.sh start --base "$node_dir"
    else
        error "    ❌ gaianet_proxy.sh脚本不存在"
        return 1
    fi
    
    info "✅ 节点启动完成"
}

# 主函数
main() {
    local node_dir="${1:-/Users/bk-00/gaianet_node2}"
    local action="${2:-fix}"
    
    if [ ! -d "$node_dir" ]; then
        error "❌ 节点目录不存在: $node_dir"
        exit 1
    fi
    
    case $action in
        fix)
            fix_dns_resolution "$node_dir"
            test_fixed_frp_connection "$node_dir"
            ;;
        test)
            test_fixed_frp_connection "$node_dir"
            ;;
        start)
            fix_dns_resolution "$node_dir"
            test_fixed_frp_connection "$node_dir"
            verify_and_start_node "$node_dir"
            ;;
        help|--help|-h)
            echo "FRP连接完全修复工具"
            echo ""
            echo "用法: $0 [节点目录] [动作]"
            echo ""
            echo "动作:"
            echo "  fix    - 修复DNS和配置问题（默认）"
            echo "  test   - 测试FRP连接"
            echo "  start  - 修复并启动节点"
            echo "  help   - 显示帮助"
            echo ""
            echo "示例:"
            echo "  $0 /Users/bk-00/gaianet_node2 fix"
            echo "  $0 /Users/bk-00/gaianet_node2 start"
            ;;
        *)
            error "❌ 未知动作: $action"
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"