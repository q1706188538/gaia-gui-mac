#!/bin/bash

# 共享RAG服务启动脚本
# 启动单个Qdrant实例供所有节点共享使用

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
SHARED_QDRANT_PORT=6333
SHARED_QDRANT_DIR="$HOME/shared_qdrant"
QDRANT_PID_FILE="$SHARED_QDRANT_DIR/shared_qdrant.pid"
QDRANT_LOG_FILE="$SHARED_QDRANT_DIR/shared_qdrant.log"

# 创建共享Qdrant目录
setup_shared_qdrant() {
    info "[+] 设置共享Qdrant服务..."
    
    # 创建共享目录
    mkdir -p "$SHARED_QDRANT_DIR"
    
    # 复制Qdrant二进制文件（从node3获取）
    if [ -f "$HOME/gaianet_node3/bin/qdrant" ]; then
        if [ ! -f "$SHARED_QDRANT_DIR/qdrant" ]; then
            cp "$HOME/gaianet_node3/bin/qdrant" "$SHARED_QDRANT_DIR/"
            chmod +x "$SHARED_QDRANT_DIR/qdrant"
            info "    ✅ 复制Qdrant二进制文件"
        fi
    else
        error "    ❌ 找不到Qdrant二进制文件"
        return 1
    fi
    
    # 创建Qdrant配置文件
    cat > "$SHARED_QDRANT_DIR/config.yaml" << EOF
service:
  host: 0.0.0.0
  http_port: $SHARED_QDRANT_PORT
  grpc_port: 6334

storage:
  storage_path: $SHARED_QDRANT_DIR/storage

log_level: INFO
EOF
    
    info "    ✅ 共享Qdrant配置创建完成"
}

# 启动共享Qdrant服务
start_shared_qdrant() {
    info "[+] 启动共享Qdrant服务..."
    
    # 检查端口是否被占用
    if lsof -Pi :$SHARED_QDRANT_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        warning "    ❗ 端口 $SHARED_QDRANT_PORT 已被占用"
        
        # 检查是否是我们的服务
        if [ -f "$QDRANT_PID_FILE" ]; then
            local existing_pid=$(cat "$QDRANT_PID_FILE")
            if kill -0 "$existing_pid" 2>/dev/null; then
                info "    ✅ 共享Qdrant服务已在运行，PID: $existing_pid"
                return 0
            fi
        fi
        
        error "    ❌ 端口被其他服务占用"
        return 1
    fi
    
    # 启动服务
    cd "$SHARED_QDRANT_DIR"
    nohup ./qdrant --config-path config.yaml > "$QDRANT_LOG_FILE" 2>&1 &
    local qdrant_pid=$!
    echo $qdrant_pid > "$QDRANT_PID_FILE"
    
    info "    共享Qdrant服务已启动，PID: $qdrant_pid"
    
    # 等待服务就绪
    local max_wait=30
    local wait_time=0
    
    info "    等待服务就绪..."
    while [ $wait_time -lt $max_wait ]; do
        if curl -s --max-time 3 "http://localhost:$SHARED_QDRANT_PORT/health" >/dev/null 2>&1; then
            info "    ✅ 共享Qdrant服务就绪"
            return 0
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
        echo -n "."
    done
    
    echo ""
    error "    ❌ 共享Qdrant服务启动失败"
    return 1
}

# 停止共享Qdrant服务
stop_shared_qdrant() {
    info "[+] 停止共享Qdrant服务..."
    
    if [ -f "$QDRANT_PID_FILE" ]; then
        local qdrant_pid=$(cat "$QDRANT_PID_FILE")
        if kill -0 "$qdrant_pid" 2>/dev/null; then
            kill -TERM "$qdrant_pid"
            sleep 3
            if kill -0 "$qdrant_pid" 2>/dev/null; then
                kill -9 "$qdrant_pid"
            fi
            info "    ✅ 共享Qdrant服务已停止"
        else
            warning "    ❗ 进程不存在"
        fi
        rm -f "$QDRANT_PID_FILE"
    else
        warning "    ❗ PID文件不存在"
    fi
    
    # 清理可能残留的进程
    pkill -f "qdrant.*$SHARED_QDRANT_PORT" 2>/dev/null || true
}

# 显示共享Qdrant状态
show_shared_qdrant_status() {
    info "[+] 共享Qdrant服务状态:"
    
    if [ -f "$QDRANT_PID_FILE" ]; then
        local qdrant_pid=$(cat "$QDRANT_PID_FILE")
        if kill -0 "$qdrant_pid" 2>/dev/null; then
            if curl -s --max-time 3 "http://localhost:$SHARED_QDRANT_PORT/health" >/dev/null 2>&1; then
                info "    ✅ 共享Qdrant运行正常 (PID: $qdrant_pid, Port: $SHARED_QDRANT_PORT)"
            else
                warning "    ⚠️  进程存在但服务无响应 (PID: $qdrant_pid)"
            fi
        else
            error "    ❌ 进程不存在"
        fi
    else
        error "    ❌ 服务未启动"
    fi
}

# 配置节点使用共享RAG
configure_node_shared_rag() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    info "  [+] 配置节点 $node_name 使用共享RAG..."
    
    if [ ! -f "$node_dir/config.json" ]; then
        error "    ❌ config.json不存在"
        return 1
    fi
    
    # 备份配置
    cp "$node_dir/config.json" "$node_dir/config.json.pre-shared-rag"
    
    # 更新配置使用共享Qdrant
    python3 -c "
import json

config_file = '$node_dir/config.json'
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # 配置共享RAG
    config['embedding_collection_name'] = 'default'
    config['rag_policy'] = 'system-message'
    config['rag_prompt'] = 'Use the following information to answer the question.'
    config['context_window'] = 1
    config['qdrant_score_threshold'] = '0.5'
    config['qdrant_limit'] = '3'
    config['snapshot'] = 'shared_knowledge_base'
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ 共享RAG配置已更新')
except Exception as e:
    print(f'❌ 配置更新失败: {e}')
    exit(1)
"
    
    if [ $? -eq 0 ]; then
        info "    ✅ 节点 $node_name 共享RAG配置完成"
        return 0
    else
        error "    ❌ 节点 $node_name 配置失败"
        return 1
    fi
}

# 配置所有节点使用共享RAG
configure_all_nodes_shared_rag() {
    info "[+] 配置所有节点使用共享RAG..."
    
    local success_count=0
    local total_count=0
    
    for node_dir in $HOME/gaianet $HOME/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            total_count=$((total_count + 1))
            if configure_node_shared_rag "$node_dir"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    info "📊 配置结果: $success_count/$total_count 个节点配置成功"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            highlight "🚀 启动共享RAG服务"
            setup_shared_qdrant
            start_shared_qdrant
            configure_all_nodes_shared_rag
            info ""
            info "✅ 共享RAG服务启动完成！"
            info "💡 Qdrant地址: http://localhost:$SHARED_QDRANT_PORT"
            info "💡 现在重启节点即可使用共享RAG服务"
            ;;
        stop)
            highlight "🛑 停止共享RAG服务"
            stop_shared_qdrant
            info "✅ 共享RAG服务已停止"
            ;;
        status)
            show_shared_qdrant_status
            ;;
        restart)
            highlight "🔄 重启共享RAG服务"
            stop_shared_qdrant
            sleep 2
            setup_shared_qdrant
            start_shared_qdrant
            info "✅ 共享RAG服务重启完成"
            ;;
        help|--help|-h)
            echo "共享RAG服务管理脚本"
            echo ""
            echo "用法: $0 {start|stop|restart|status|help}"
            echo ""
            echo "命令:"
            echo "  start   - 启动共享RAG服务并配置所有节点"
            echo "  stop    - 停止共享RAG服务"
            echo "  restart - 重启共享RAG服务"  
            echo "  status  - 显示服务状态"
            echo "  help    - 显示帮助信息"
            ;;
        *)
            error "❌ 未知命令: $1"
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"