#!/bin/bash

# GaiaNet节点网络流量捕获脚本
# 捕获节点启动时向官方发送的心跳请求参数

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

# 配置
CAPTURE_FILE="/tmp/gaianet_traffic_$(date +%Y%m%d_%H%M%S).log"
NODE_DIR="${1:-/Users/bk-00/gaianet_node2}"

# 启动网络流量监控
start_traffic_capture() {
    info "[+] 启动网络流量捕获..."
    
    # 方法1: 使用tcpdump捕获HTTP流量
    if command -v tcpdump >/dev/null 2>&1; then
        info "    使用tcpdump捕获网络流量..."
        
        # 检测操作系统并使用合适的网络接口
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - 使用主要网络接口
            NETWORK_INTERFACE=$(route get default | grep interface | awk '{print $2}')
            if [ -z "$NETWORK_INTERFACE" ]; then
                NETWORK_INTERFACE="en0"  # 默认WiFi接口
            fi
            info "    检测到macOS，使用网络接口: $NETWORK_INTERFACE"
            
            # macOS tcpdump命令
            sudo tcpdump -i "$NETWORK_INTERFACE" -A -s 0 'host gaia.domains or host hub.gaia.domains or port 7000' > "$CAPTURE_FILE" 2>&1 &
        else
            # Linux - 使用any接口
            sudo tcpdump -i any -A -s 0 'host gaia.domains or host hub.gaia.domains or port 7000' > "$CAPTURE_FILE" 2>&1 &
        fi
        
        TCPDUMP_PID=$!
        
        info "    ✅ tcpdump已启动，PID: $TCPDUMP_PID"
        info "    ✅ 捕获文件: $CAPTURE_FILE"
    else
        warning "    ❗ tcpdump不可用，尝试其他方法..."
    fi
    
    # 方法2: 使用netstat监控连接
    info "    启动连接监控..."
    
    while true; do
        echo "=== $(date) ===" >> "${CAPTURE_FILE}.connections"
        
        # 监控活动连接
        netstat -an | grep -E "(gaia\.domains|7000)" >> "${CAPTURE_FILE}.connections" 2>/dev/null || true
        
        # 监控进程网络活动
        lsof -i | grep -E "(gaia-nexus|frpc)" >> "${CAPTURE_FILE}.connections" 2>/dev/null || true
        
        sleep 5
    done &
    NETSTAT_PID=$!
    
    info "    ✅ 连接监控已启动，PID: $NETSTAT_PID"
}

# 分析gaia-nexus和frpc的日志
analyze_logs() {
    local node_dir=$1
    
    info "[+] 分析节点日志..."
    
    # 分析gaia-nexus日志
    if [ -f "$node_dir/log/gaia-nexus-proxy.log" ]; then
        info "    分析gaia-nexus日志..."
        echo "=== GAIA-NEXUS LOG ===" >> "$CAPTURE_FILE.analysis"
        tail -50 "$node_dir/log/gaia-nexus-proxy.log" >> "$CAPTURE_FILE.analysis"
        echo "" >> "$CAPTURE_FILE.analysis"
    fi
    
    # 分析frpc日志
    if [ -f "$node_dir/log/start-gaia-frp-proxy.log" ]; then
        info "    分析frpc日志..."
        echo "=== FRPC LOG ===" >> "$CAPTURE_FILE.analysis"
        tail -50 "$node_dir/log/start-gaia-frp-proxy.log" >> "$CAPTURE_FILE.analysis"
        echo "" >> "$CAPTURE_FILE.analysis"
    fi
    
    # 分析系统日志中的网络活动
    echo "=== SYSTEM LOG (GaiaNet相关) ===" >> "$CAPTURE_FILE.analysis"
    sudo dmesg | grep -i gaia >> "$CAPTURE_FILE.analysis" 2>/dev/null || true
}

# 启动节点并捕获流量
capture_node_startup() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    highlight "🔍 捕获节点 $node_name 的启动流量"
    
    # 检查gaianet_proxy.sh脚本是否存在
    if [ ! -f "./gaianet_proxy.sh" ]; then
        error "❌ gaianet_proxy.sh脚本不存在，请确保在正确的目录运行"
        return 1
    fi
    
    # 确保节点已停止
    info "[1/5] 停止节点..."
    ./gaianet_proxy.sh stop --base "$node_dir" 2>/dev/null || true
    sleep 3
    
    # 启动流量捕获
    info "[2/5] 启动流量捕获..."
    start_traffic_capture
    sleep 2
    
    # 启动节点
    info "[3/5] 启动节点..."
    echo "=== NODE STARTUP: $(date) ===" >> "$CAPTURE_FILE.startup"
    ./gaianet_proxy.sh start --base "$node_dir" >> "$CAPTURE_FILE.startup" 2>&1 &
    
    # 等待节点启动完成
    info "[4/5] 等待节点启动并捕获初始通信..."
    sleep 30
    
    # 分析日志
    info "[5/5] 分析节点日志..."
    analyze_logs "$node_dir"
    
    # 停止捕获
    info "停止流量捕获..."
    [ -n "$TCPDUMP_PID" ] && sudo kill $TCPDUMP_PID 2>/dev/null || true
    [ -n "$NETSTAT_PID" ] && kill $NETSTAT_PID 2>/dev/null || true
    
    info "✅ 流量捕获完成！"
}

# 分析捕获的数据
analyze_captured_data() {
    highlight "📊 分析捕获的网络数据"
    
    info "[+] 生成分析报告..."
    
    local report_file="${CAPTURE_FILE}.report"
    
    cat > "$report_file" << EOF
=== GaiaNet节点网络流量分析报告 ===
生成时间: $(date)
节点目录: $NODE_DIR
节点名称: $(basename "$NODE_DIR")

EOF
    
    # 分析Device ID和Node ID在网络请求中的使用
    info "    搜索Device ID相关通信..."
    echo "=== Device ID 相关通信 ===" >> "$report_file"
    
    if [ -f "$NODE_DIR/deviceid.txt" ]; then
        local device_id=$(cat "$NODE_DIR/deviceid.txt")
        echo "节点Device ID: $device_id" >> "$report_file"
        
        # 在捕获的流量中搜索这个Device ID
        grep -r "$device_id" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未在网络流量中发现Device ID" >> "$report_file"
        
        # 搜索去掉device-前缀的ID
        local hex_id=$(echo "$device_id" | sed 's/device-//')
        echo "搜索十六进制ID: $hex_id" >> "$report_file"
        grep -r "$hex_id" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现十六进制ID" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # 分析Node ID相关通信
    info "    搜索Node ID相关通信..." 
    echo "=== Node ID 相关通信 ===" >> "$report_file"
    
    if [ -f "$NODE_DIR/nodeid.json" ]; then
        local node_address=$(grep -o '"address": "[^"]*"' "$NODE_DIR/nodeid.json" | cut -d'"' -f4)
        echo "节点地址: $node_address" >> "$report_file"
        
        # 在捕获的流量中搜索这个地址
        grep -r "$node_address" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未在网络流量中发现Node地址" >> "$report_file"
        
        # 搜索去掉0x前缀的地址
        local hex_address=$(echo "$node_address" | sed 's/0x//')
        echo "搜索十六进制地址: $hex_address" >> "$report_file"
        grep -r "$hex_address" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现十六进制地址" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # 分析FRP相关通信
    echo "=== FRP 相关通信 ===" >> "$report_file"
    echo "搜索gaia.domains相关请求..." >> "$report_file"
    grep -r -i "gaia\.domains\|7000\|metadatas\|deviceId" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现FRP相关通信" >> "$report_file"
    
    echo "" >> "$report_file"
    
    # 分析HTTP请求
    echo "=== HTTP 请求分析 ===" >> "$report_file"
    echo "所有HTTP请求:" >> "$report_file"
    grep -r -i "POST\|GET\|PUT\|HTTP" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现HTTP请求" >> "$report_file"
    
    echo "" >> "$report_file"
    
    # 分析JSON数据
    echo "=== JSON 数据分析 ===" >> "$report_file"
    echo "搜索JSON格式的数据传输..." >> "$report_file"
    grep -r -i "application/json\|{.*}\|\[.*\]" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现JSON数据" >> "$report_file"
    
    echo "" >> "$report_file"
    
    # 分析心跳和注册相关
    echo "=== 心跳和注册相关通信 ===" >> "$report_file"
    echo "搜索heartbeat, register, login等关键词..." >> "$report_file"
    grep -r -i "heartbeat\|register\|login\|auth\|token" "${CAPTURE_FILE}"* >> "$report_file" 2>/dev/null || echo "未发现心跳注册相关通信" >> "$report_file"
    
    info "✅ 分析报告生成完成: $report_file"
    
    # 显示摘要
    highlight "📋 捕获数据摘要:"
    echo "  捕获文件:"
    ls -la "${CAPTURE_FILE}"* 2>/dev/null || echo "  无捕获文件"
    
    echo ""
    info "💡 请查看以下文件了解详细信息:"
    info "   📄 主报告: $report_file"
    info "   📄 原始流量: $CAPTURE_FILE"
    info "   📄 连接日志: ${CAPTURE_FILE}.connections"
    info "   📄 节点日志: ${CAPTURE_FILE}.analysis"
    info "   📄 启动日志: ${CAPTURE_FILE}.startup"
}

# 实时监控模式
realtime_monitor() {
    highlight "📡 实时监控模式"
    info "监控所有GaiaNet相关的网络活动..."
    info "按Ctrl+C停止监控"
    
    # 实时显示网络连接
    while true; do
        clear
        echo "=== GaiaNet网络活动监控 $(date) ==="
        echo ""
        
        echo "活动连接:"
        netstat -an | grep -E "(gaia\.domains|7000|6333|9000|9001)" || echo "无相关连接"
        
        echo ""
        echo "相关进程:"
        ps aux | grep -E "(gaia-nexus|frpc|qdrant|wasmedge)" | grep -v grep || echo "无相关进程"
        
        echo ""
        echo "端口监听:"
        lsof -i | grep -E "(8080|8081|8082|6333|7000|9000|9001)" || echo "无相关端口"
        
        sleep 5
    done
}

# 主函数
main() {
    case "${1:-capture}" in
        capture)
            if [ -z "$2" ]; then
                error "❌ 请指定节点目录"
                echo "用法: $0 capture /Users/bk-00/gaianet_node2"
                exit 1
            fi
            NODE_DIR="$2"
            capture_node_startup "$NODE_DIR"
            analyze_captured_data
            ;;
        analyze)
            analyze_captured_data
            ;;
        monitor)
            realtime_monitor
            ;;
        help|--help|-h)
            echo "GaiaNet节点网络流量捕获工具"
            echo ""
            echo "用法: $0 {capture|analyze|monitor|help} [节点目录]"
            echo ""
            echo "命令:"
            echo "  capture <节点目录>  - 捕获指定节点的启动流量"
            echo "  analyze            - 分析已捕获的数据"
            echo "  monitor            - 实时监控网络活动"
            echo "  help               - 显示帮助"
            echo ""
            echo "示例:"
            echo "  $0 capture /Users/bk-00/gaianet_node2"
            echo "  $0 monitor"
            ;;
        *)
            error "❌ 未知命令: $1"
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"