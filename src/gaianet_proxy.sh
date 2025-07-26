#!/bin/bash

# GaiaNet 多节点代理模式启动脚本
# 此脚本支持代理模式，可以连接到共享的模型服务

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 注释：原来检查 gaianet-node 目录的代码已移除
# 因为我们直接使用已安装的 gaianet 文件，不需要源码目录

# 代理模式配置
SHARED_CHAT_URL="http://localhost:9000"
SHARED_EMBEDDING_URL="http://localhost:9001"
PROXY_MODE=false

# 颜色定义
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
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

# 检查共享服务是否运行
check_shared_services() {
    info "[+] 检查共享模型服务状态..."
    
    # 检查Chat服务
    if curl -s --max-time 5 "$SHARED_CHAT_URL/v1/models" >/dev/null 2>&1; then
        info "    ✅ Chat服务正常运行: $SHARED_CHAT_URL"
    else
        error "    ❌ Chat服务不可用: $SHARED_CHAT_URL"
        error "    请先启动共享模型服务: ./start_shared_model_services.sh start"
        exit 1
    fi
    
    # 检查Embedding服务
    if curl -s --max-time 5 "$SHARED_EMBEDDING_URL/v1/models" >/dev/null 2>&1; then
        info "    ✅ Embedding服务正常运行: $SHARED_EMBEDDING_URL"
    else
        error "    ❌ Embedding服务不可用: $SHARED_EMBEDDING_URL"
        error "    请先启动共享模型服务: ./start_shared_model_services.sh start"
        exit 1
    fi
}

# 代理模式启动gaia-nexus
start_gaia_nexus_proxy() {
    local gaianet_base_dir=$1
    local local_only=$2
    local force_rag=$3
    
    # 读取配置
    domain=$(awk -F'"' '/"domain":/ {print $4}' $gaianet_base_dir/config.json)
    llamaedge_port=$(awk -F'"' '/"llamaedge_port":/ {print $4}' $gaianet_base_dir/config.json)
    
    qdrant_collection_name=$(awk -F'"' '/"embedding_collection_name":/ {print $4}' $gaianet_base_dir/config.json)
    if [[ -z "$qdrant_collection_name" ]]; then
        qdrant_collection_name="default"
    fi
    
    qdrant_score_threshold=$(awk -F'"' '/"qdrant_score_threshold":/ {print $4}' $gaianet_base_dir/config.json)
    qdrant_limit=$(awk -F'"' '/"qdrant_limit":/ {print $4}' $gaianet_base_dir/config.json)
    rag_prompt=$(awk -F'"' '/"rag_prompt":/ {print $4}' $gaianet_base_dir/config.json)
    
    if grep -q '"context_window":' $gaianet_base_dir/config.json; then
        context_window=$(awk -F'"' '/"context_window":/ {print $4}' $gaianet_base_dir/config.json)
    else
        context_window=1
    fi
    
    if grep -q '"rag_policy":' $gaianet_base_dir/config.json; then
        rag_policy=$(awk -F'"' '/"rag_policy":/ {print $4}' $gaianet_base_dir/config.json)
    else
        rag_policy="system-message"
    fi
    
    # 检查端口是否被占用
    if lsof -Pi :$llamaedge_port -sTCP:LISTEN -t >/dev/null ; then
        error "    端口 $llamaedge_port 已被占用。退出..."
        exit 1
    fi
    
    # 创建日志目录
    log_dir=$gaianet_base_dir/log
    if ! [ -d "$log_dir" ]; then
        mkdir -p -m777 $log_dir
    fi
    
    # 检查gaia-nexus二进制文件
    llama_nexus="$gaianet_base_dir/bin/gaia-nexus"
    if [ ! -f "$llama_nexus" ]; then
        error "❌ 找不到gaia-nexus二进制文件: $gaianet_base_dir/bin"
        exit 1
    fi
    
    # 设置节点版本
    export NODE_VERSION="0.5.3-proxy"
    
    info "[+] 启动代理模式gaia-nexus..."
    cd $gaianet_base_dir
    
    # 确保使用当前目录的配置文件
    export GAIANET_BASE_DIR="$gaianet_base_dir"
    export NODE_CONFIG_DIR="$gaianet_base_dir"
    
    # 根据是否需要RAG决定启动参数
    snapshot=$(awk -F'"' '/"snapshot":/ {print $4}' $gaianet_base_dir/config.json)
    if [ -n "$snapshot" ] || [ "$force_rag" = true ]; then
        # RAG模式：检查是否使用共享Qdrant
        shared_qdrant_url="http://localhost:6333"
        
        # 检查共享Qdrant是否可用
        if curl -s --max-time 3 "$shared_qdrant_url/health" >/dev/null 2>&1; then
            info "    使用共享Qdrant服务: $shared_qdrant_url"
            
            # 使用共享Qdrant的gaia-nexus启动
            cd $gaianet_base_dir
            nohup $gaianet_base_dir/bin/gaia-nexus \
            --rag \
            --check-health \
            --check-health-interval 60 \
            --web-ui $gaianet_base_dir/dashboard \
            --log-destination file \
            --log-file $log_dir/gaia-nexus-proxy.log \
            --gaianet-dir $gaianet_base_dir \
            --vdb-url $shared_qdrant_url \
            --vdb-collection-name $qdrant_collection_name \
            --vdb-limit $qdrant_limit \
            --vdb-score-threshold $qdrant_score_threshold \
            --rag-prompt "'$rag_prompt'" \
            --rag-context-window $context_window \
            --rag-policy $rag_policy \
            --port $llamaedge_port > $log_dir/start-gaia-nexus-proxy.log 2>&1 &
        else
            # 共享Qdrant不可用，启动本地Qdrant
            info "    共享Qdrant不可用，启动本地Qdrant实例..."
            
            # 启动Qdrant
            cd $gaianet_base_dir/qdrant
            nohup $gaianet_base_dir/bin/qdrant > $log_dir/proxy-qdrant.log 2>&1 &
            qdrant_pid=$!
            echo $qdrant_pid > $gaianet_base_dir/qdrant.pid
            sleep 5
            info "    ✅ 本地Qdrant启动成功，PID: $qdrant_pid"
            
            # 带RAG的gaia-nexus启动
            cd $gaianet_base_dir
            nohup $gaianet_base_dir/bin/gaia-nexus \
            --rag \
            --check-health \
            --check-health-interval 60 \
            --web-ui $gaianet_base_dir/dashboard \
            --log-destination file \
            --log-file $log_dir/gaia-nexus-proxy.log \
            --gaianet-dir $gaianet_base_dir \
            --vdb-url http://localhost:6333 \
            --vdb-collection-name $qdrant_collection_name \
            --vdb-limit $qdrant_limit \
            --vdb-score-threshold $qdrant_score_threshold \
            --rag-prompt "'$rag_prompt'" \
            --rag-context-window $context_window \
            --rag-policy $rag_policy \
            --port $llamaedge_port > $log_dir/start-gaia-nexus-proxy.log 2>&1 &
        fi
    else
        # 纯代理模式：不需要本地RAG
        nohup $gaianet_base_dir/bin/gaia-nexus \
        --check-health \
        --check-health-interval 60 \
        --web-ui $gaianet_base_dir/dashboard \
        --log-destination file \
        --log-file $log_dir/gaia-nexus-proxy.log \
        --gaianet-dir $gaianet_base_dir \
        --port $llamaedge_port > $log_dir/start-gaia-nexus-proxy.log 2>&1 &
    fi
    
    llama_nexus_pid=$!
    
    # 检查是否启动成功
    sleep 10
    if ! ps -p $llama_nexus_pid > /dev/null 2>&1; then
        error "    ❌ gaia-nexus启动失败。请检查日志: $log_dir/start-gaia-nexus-proxy.log"
        if [ -f "$log_dir/start-gaia-nexus-proxy.log" ]; then
            echo "最后几行日志:"
            tail -5 $log_dir/start-gaia-nexus-proxy.log
        fi
        exit 1
    else
        rm -f $log_dir/start-gaia-nexus-proxy.log
    fi
    
    # 验证gaia-nexus
    sleep 5
    info "    验证gaia-nexus..."
    local max_retries=6
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -s --max-time 10 "http://localhost:$llamaedge_port/admin/servers" >/dev/null 2>&1; then
            success=true
        else
            ((retry_count++))
            if [ $retry_count -lt $max_retries ]; then
                info "      等待gaia-nexus准备就绪... ($retry_count/$max_retries)"
                sleep 10
            fi
        fi
    done
    
    if [ "$success" = false ]; then
        error "    ❌ gaia-nexus验证失败"
        exit 1
    fi
    
    echo $llama_nexus_pid > $gaianet_base_dir/llama_nexus.pid
    info "    ✅ gaia-nexus代理模式启动成功，PID: $llama_nexus_pid"
    
    return 0
}

# 注册共享服务到gaia-nexus
register_shared_services() {
    local gaianet_base_dir=$1
    local llamaedge_port=$(awk -F'"' '/"llamaedge_port":/ {print $4}' $gaianet_base_dir/config.json)
    
    info "[+] 注册共享服务到gaia-nexus..."
    
    # 注册Chat服务
    info "    注册Chat服务: $SHARED_CHAT_URL"
    local response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$llamaedge_port/admin/servers/register" \
        -H "Content-Type: application/json" \
        -d '{"url": "'$SHARED_CHAT_URL'", "kind": "chat"}')
    
    local status_code=$(echo "$response" | tail -n1)
    if [[ $status_code -ge 200 && $status_code -lt 300 ]]; then
        info "    ✅ Chat服务注册成功"
    else
        error "    ❌ Chat服务注册失败，状态码: $status_code"
        exit 1
    fi
    
    # 注册Embedding服务
    info "    注册Embedding服务: $SHARED_EMBEDDING_URL"
    response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$llamaedge_port/admin/servers/register" \
        -H "Content-Type: application/json" \
        -d '{"url": "'$SHARED_EMBEDDING_URL'", "kind": "embeddings"}')
    
    status_code=$(echo "$response" | tail -n1)
    if [[ $status_code -ge 200 && $status_code -lt 300 ]]; then
        info "    ✅ Embedding服务注册成功"
    else
        error "    ❌ Embedding服务注册失败，状态码: $status_code"
        exit 1
    fi
}

# 代理模式启动函数
start_proxy_mode() {
    local gaianet_base_dir=$1
    local local_only=$2
    local force_rag=$3
    
    info "🚀 启动GaiaNet代理模式..."
    
    # 1. 检查共享服务
    check_shared_services
    
    # 2. 检查配置文件
    info "[1/4] 检查配置文件..."
    if [ ! -f "$gaianet_base_dir/config.json" ]; then
        error "❌ 配置文件不存在: $gaianet_base_dir/config.json"
        exit 1
    fi
    info "    ✅ 配置文件检查完成"
    
    # 3. 同步配置到dashboard
    cd $gaianet_base_dir
    if [ -f "registry.wasm" ]; then
        wasmedge --dir .:. registry.wasm
    fi
    
    # 4. 启动gaia-frp（如果不是本地模式）
    if [ "$local_only" -eq 0 ]; then
        info "[2/4] 启动gaia-frp..."
        
        log_dir=$gaianet_base_dir/log
        mkdir -p -m777 $log_dir
        
        nohup $gaianet_base_dir/bin/frpc -c $gaianet_base_dir/gaia-frp/frpc.toml > $log_dir/start-gaia-frp-proxy.log 2>&1 &
        sleep 2
        gaia_frp_pid=$!
        echo $gaia_frp_pid > $gaianet_base_dir/gaia-frp.pid
        info "    ✅ gaia-frp启动成功，PID: $gaia_frp_pid"
    else
        info "[2/4] 跳过gaia-frp（本地模式）"
    fi
    
    # 5. 启动gaia-nexus代理模式
    info "[3/4] 启动gaia-nexus代理模式..."
    start_gaia_nexus_proxy "$gaianet_base_dir" "$local_only" "$force_rag"
    
    # 6. 注册共享服务
    info "[4/4] 注册共享服务..."
    register_shared_services "$gaianet_base_dir"
    
    # 显示结果
    llamaedge_port=$(awk -F'"' '/"llamaedge_port":/ {print $4}' $gaianet_base_dir/config.json)
    
    if [ "$local_only" -eq 0 ]; then
        subdomain=$(grep "subdomain" $gaianet_base_dir/gaia-frp/frpc.toml | cut -d'=' -f2 | tr -d ' "')
        domain=$(awk -F'"' '/"domain":/ {print $4}' $gaianet_base_dir/config.json)
        info "✅ GaiaNet代理节点已启动: https://$subdomain.$domain"
    else
        info "✅ GaiaNet代理节点已启动（本地模式）: http://localhost:$llamaedge_port"
    fi
    
    info "💡 此节点使用共享模型服务，内存占用已优化"
    info "👉 停止节点: $0 stop --base $gaianet_base_dir"
}

# 显示代理模式帮助
show_proxy_help() {
    echo "GaiaNet 多节点代理模式启动脚本"
    echo ""
    echo "用法: $0 {start|stop|status|help} [选项]"
    echo ""
    echo "命令:"
    echo "  start      - 启动代理模式GaiaNet节点"
    echo "  stop       - 停止GaiaNet节点"
    echo "  status     - 显示节点状态"
    echo "  help       - 显示帮助信息"
    echo ""
    echo "选项:"
    echo "  --base <path>      - GaiaNet基础目录（默认: \$HOME/gaianet）"
    echo "  --local-only       - 仅本地模式启动"
    echo "  --force-rag        - 强制启动RAG模式"
    echo "  --shared-chat <url>     - 共享Chat服务URL（默认: $SHARED_CHAT_URL）"
    echo "  --shared-embedding <url> - 共享Embedding服务URL（默认: $SHARED_EMBEDDING_URL）"
    echo ""
    echo "使用前请确保:"
    echo "1. 先启动共享模型服务: ./start_shared_model_services.sh start"
    echo "2. 确保各节点配置文件中的llamaedge_port不同"
}

# 停止代理模式节点
stop_proxy_node() {
    local gaianet_base_dir=$1
    
    info "[+] 停止GaiaNet代理节点..."
    
    # 停止gaia-nexus
    if [ -f "$gaianet_base_dir/llama_nexus.pid" ]; then
        local nexus_pid=$(cat "$gaianet_base_dir/llama_nexus.pid")
        if kill -0 $nexus_pid 2>/dev/null; then
            kill -9 $nexus_pid
            info "    ✅ gaia-nexus已停止 (PID: $nexus_pid)"
        fi
        rm -f "$gaianet_base_dir/llama_nexus.pid"
    fi
    
    # 停止gaia-frp
    if [ -f "$gaianet_base_dir/gaia-frp.pid" ]; then
        local frp_pid=$(cat "$gaianet_base_dir/gaia-frp.pid")
        if kill -0 $frp_pid 2>/dev/null; then
            kill -9 $frp_pid
            info "    ✅ gaia-frp已停止 (PID: $frp_pid)"
        fi
        rm -f "$gaianet_base_dir/gaia-frp.pid"
    fi
    
    # 停止Qdrant（如果是代理模式启动的）
    if [ -f "$gaianet_base_dir/qdrant.pid" ]; then
        local qdrant_pid=$(cat "$gaianet_base_dir/qdrant.pid")
        if kill -0 $qdrant_pid 2>/dev/null; then
            kill -9 $qdrant_pid
            info "    ✅ Qdrant已停止 (PID: $qdrant_pid)"
        fi
        rm -f "$gaianet_base_dir/qdrant.pid"
    fi
    
    # 清理可能残留的进程
    pkill -9 -f "gaia-nexus.*$gaianet_base_dir" || true
    pkill -9 -f "frpc.*$gaianet_base_dir" || true
    
    info "✅ GaiaNet代理节点已停止"
}

# 显示节点状态
show_proxy_status() {
    local gaianet_base_dir=$1
    
    info "[+] GaiaNet代理节点状态:"
    
    # 检查gaia-nexus
    if [ -f "$gaianet_base_dir/llama_nexus.pid" ]; then
        local nexus_pid=$(cat "$gaianet_base_dir/llama_nexus.pid")
        if kill -0 $nexus_pid 2>/dev/null; then
            local llamaedge_port=$(awk -F'"' '/"llamaedge_port":/ {print $4}' $gaianet_base_dir/config.json)
            info "    ✅ gaia-nexus运行中 (PID: $nexus_pid, Port: $llamaedge_port)"
        else
            error "    ❌ gaia-nexus未运行"
        fi
    else
        error "    ❌ gaia-nexus未运行"
    fi
    
    # 检查共享服务连接
    info "    共享服务状态:"
    if curl -s --max-time 3 "$SHARED_CHAT_URL/v1/models" >/dev/null 2>&1; then
        info "      ✅ Chat服务连接正常: $SHARED_CHAT_URL"
    else
        error "      ❌ Chat服务连接失败: $SHARED_CHAT_URL"
    fi
    
    if curl -s --max-time 3 "$SHARED_EMBEDDING_URL/v1/models" >/dev/null 2>&1; then
        info "      ✅ Embedding服务连接正常: $SHARED_EMBEDDING_URL"
    else
        error "      ❌ Embedding服务连接失败: $SHARED_EMBEDDING_URL"
    fi
}

# 主函数
main() {
    local gaianet_base_dir="$HOME/gaianet"
    local local_only=0
    local force_rag=false
    local command="${1:-help}"
    
    # 解析参数
    shift || true
    while (( "$#" )); do
        case "$1" in
            --base)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    gaianet_base_dir=$2
                    shift 2
                else
                    error "❌ --base 参数需要指定目录"
                    exit 1
                fi
                ;;
            --local-only)
                local_only=1
                shift
                ;;
            --force-rag)
                force_rag=true
                shift
                ;;
            --shared-chat)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    SHARED_CHAT_URL=$2
                    shift 2
                else
                    error "❌ --shared-chat 参数需要指定URL"
                    exit 1
                fi
                ;;
            --shared-embedding)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    SHARED_EMBEDDING_URL=$2
                    shift 2
                else
                    error "❌ --shared-embedding 参数需要指定URL"
                    exit 1
                fi
                ;;
            *)
                error "❌ 未知参数: $1"
                show_proxy_help
                exit 1
                ;;
        esac
    done
    
    # 检查基础目录
    if [ ! -d "$gaianet_base_dir" ]; then
        error "❌ GaiaNet基础目录不存在: $gaianet_base_dir"
        error "    请先运行 gaianet init 初始化节点"
        exit 1
    fi
    
    # 执行命令
    case $command in
        start)
            start_proxy_mode "$gaianet_base_dir" "$local_only" "$force_rag"
            ;;
        stop)
            stop_proxy_node "$gaianet_base_dir"
            ;;
        status)
            show_proxy_status "$gaianet_base_dir"
            ;;
        help|--help|-h)
            show_proxy_help
            ;;
        *)
            error "❌ 未知命令: $command"
            show_proxy_help
            exit 1
            ;;
    esac
}

# 清理函数
cleanup() {
    echo ""
    info "🛑 正在清理..."
}

# 不设置自动清理陷阱 - 让代理节点持续运行
# trap cleanup EXIT INT TERM

# 运行主函数
main "$@"