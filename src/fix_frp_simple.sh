#!/bin/bash

# 简单直接的FRP修复脚本
# 直接替换配置文件解决所有问题

set -e

# 颜色定义
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

info() { printf "${GREEN}$1${NC}\n"; }
error() { printf "${RED}$1${NC}\n"; }
warning() { printf "${YELLOW}$1${NC}\n"; }

# 直接修复FRP配置
fix_frp_simple() {
    local node_dir=$1
    local frpc_file="$node_dir/gaia-frp/frpc.toml"
    
    info "🔧 直接修复FRP配置..."
    
    # 备份原文件
    cp "$frpc_file" "$frpc_file.backup.$(date +%s)"
    info "✅ 已备份原配置"
    
    # 从原配置提取参数
    local device_id=$(grep -E "deviceId|device_id" "$frpc_file" | cut -d'"' -f2 | head -1)
    local subdomain=$(grep -E "subdomain" "$frpc_file" | cut -d'"' -f2 | head -1)
    local local_port=$(grep -E "localPort" "$frpc_file" | grep -o '[0-9]*' | head -1)
    
    info "提取的配置参数:"
    echo "  Device ID: $device_id"
    echo "  Subdomain: $subdomain"
    echo "  Local Port: $local_port"
    
    # 创建兼容的INI格式配置（因为当前frpc版本可能较老）
    cat > "$frpc_file" << 'EOF'
[common]
server_addr = 198.18.0.22
server_port = 7000
login_fail_exit = false
protocol = tcp
heartbeat_interval = 30
heartbeat_timeout = 90
tcp_mux = true
dial_server_timeout = 20

EOF
    
    # 添加设备ID配置
    echo "device_id = \"$device_id\"" >> "$frpc_file"
    echo "" >> "$frpc_file"
    
    # 添加代理配置
    cat >> "$frpc_file" << EOF
[$subdomain.gaia.domains]
type = http
local_ip = 127.0.0.1
local_port = $local_port
subdomain = $subdomain
host_header_rewrite = $subdomain.gaia.domains
EOF
    
    info "✅ 已创建兼容的FRP配置"
    
    # 显示新配置
    echo ""
    info "新的FRP配置内容:"
    cat "$frpc_file"
    echo ""
}

# 测试新配置
test_new_config() {
    local node_dir=$1
    
    info "🧪 测试新FRP配置..."
    
    cd "$node_dir"
    
    # 启动测试
    local log_file="/tmp/frp_simple_test_$(date +%s).log"
    ./bin/frpc -c gaia-frp/frpc.toml > "$log_file" 2>&1 &
    local frpc_pid=$!
    
    info "FRP测试进程PID: $frpc_pid"
    
    # 等待连接
    sleep 10
    
    if kill -0 $frpc_pid 2>/dev/null; then
        info "✅ FRP进程运行中"
        
        # 检查连接
        if netstat -an | grep "198.18.0.22:7000" | grep "ESTABLISHED" >/dev/null; then
            info "✅ 成功连接到GaiaNet服务器！"
        else
            warning "⚠️  连接状态检查..."
        fi
        
        # 显示日志
        info "FRP连接日志:"
        tail -10 "$log_file"
    else
        error "❌ FRP进程退出，错误日志:"
        cat "$log_file"
    fi
    
    # 清理
    kill $frpc_pid 2>/dev/null || true
    kill -9 $frpc_pid 2>/dev/null || true
    
    info "测试完成，日志: $log_file"
}

# 启动节点
start_node() {
    local node_dir=$1
    
    info "🚀 启动节点..."
    
    # 停止现有节点
    if [ -f "./gaianet_proxy.sh" ]; then
        ./gaianet_proxy.sh stop --base "$node_dir" 2>/dev/null || true
        sleep 3
        
        # 启动节点
        ./gaianet_proxy.sh start --base "$node_dir"
    else
        error "❌ gaianet_proxy.sh不存在"
        return 1
    fi
}

# 主函数
main() {
    local node_dir="${1:-$HOME/gaianet_node2}"
    
    if [ ! -d "$node_dir" ]; then
        error "❌ 节点目录不存在: $node_dir"
        exit 1
    fi
    
    fix_frp_simple "$node_dir"
    test_new_config "$node_dir"
    
    echo ""
    info "💡 修复完成！现在可以启动节点:"
    echo "  ./gaianet_proxy.sh start --base $node_dir"
    echo ""
    info "🎯 如果需要立即启动，运行:"
    echo "  $0 $node_dir && ./gaianet_proxy.sh start --base $node_dir"
}

main "$@"