#!/bin/bash

# frpc.toml 配置对比脚本
# 显示各节点的frpc.toml关键配置信息

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

highlight() {
    printf "${BLUE}$1${NC}\n"
}

warning() {
    printf "${YELLOW}$1${NC}\n"
}

# 显示单个节点的frpc.toml配置
show_node_frpc_config() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    if [ ! -f "$node_dir/gaia-frp/frpc.toml" ]; then
        warning "  ❗ $node_name: frpc.toml不存在"
        return
    fi
    
    local device_id=$(grep "metadatas.deviceId" "$node_dir/gaia-frp/frpc.toml" | cut -d'"' -f2)
    local local_port=$(grep "localPort" "$node_dir/gaia-frp/frpc.toml" | grep -o '[0-9]*')
    local subdomain=$(grep "subdomain" "$node_dir/gaia-frp/frpc.toml" | cut -d'"' -f2)
    local proxy_name=$(grep "name = " "$node_dir/gaia-frp/frpc.toml" | cut -d'"' -f2)
    
    # 也显示config.json中的端口用于对比
    local config_port=""
    if [ -f "$node_dir/config.json" ]; then
        config_port=$(awk -F'"' '/\"llamaedge_port\":/ {print $4}' "$node_dir/config.json")
    fi
    
    printf "  %-15s DeviceID: %-35s LocalPort: %-4s (config: %-4s) Subdomain: %-40s\n" \
           "$node_name" "$device_id" "$local_port" "$config_port" "$subdomain"
}

# 主函数
main() {
    info "📋 frpc.toml 配置对比报告"
    info ""
    
    highlight "格式: 节点名称    Device ID    FRP本地端口(配置文件端口)    网络子域名"
    echo ""
    
    # 检查主节点
    if [ -d "/Users/bk-00/gaianet" ]; then
        show_node_frpc_config "/Users/bk-00/gaianet"
    fi
    
    # 检查所有从节点
    for node_dir in /Users/bk-00/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            show_node_frpc_config "$node_dir"
        fi
    done
    
    echo ""
    info "💡 理想状态："
    info "   - 每个节点的Device ID应该不同"
    info "   - FRP本地端口应该与config.json中的llamaedge_port一致"
    info "   - 每个节点的网络子域名(subdomain)应该对应其独立的节点地址"
    echo ""
    info "🔧 如发现问题，运行修复命令："
    info "   ./deploy_multinode_advanced.sh fix-device-id"
}

main "$@"