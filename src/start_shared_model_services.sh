#!/bin/bash

# 共享模型服务启动脚本 - 修复版
# 这个脚本会启动共享的Chat和Embedding模型服务，供多个GaiaNet节点使用

set -e

# 颜色定义
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

# 基础目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_SERVICES_DIR="$SCRIPT_DIR/shared_services"
LOG_DIR="$SHARED_SERVICES_DIR/logs"

# 默认配置
CHAT_MODEL_PORT=9000
EMBEDDING_MODEL_PORT=9001
CHAT_MODEL_NAME="Llama-3.2-3B-Instruct"
EMBEDDING_MODEL_NAME="Nomic-embed-text-v1.5"

# 读取配置文件中的模型信息
GAIANET_BASE_DIR="$HOME/gaianet"
if [ -f "$GAIANET_BASE_DIR/config.json" ]; then
    CHAT_MODEL_URL=$(awk -F'"' '/"chat":/ {print $4}' "$GAIANET_BASE_DIR/config.json")
    EMBEDDING_MODEL_URL=$(awk -F'"' '/"embedding":/ {print $4}' "$GAIANET_BASE_DIR/config.json")
    CHAT_CTX_SIZE=$(awk -F'"' '/"chat_ctx_size":/ {print $4}' "$GAIANET_BASE_DIR/config.json")
    EMBEDDING_CTX_SIZE=$(awk -F'"' '/"embedding_ctx_size":/ {print $4}' "$GAIANET_BASE_DIR/config.json")
    PROMPT_TEMPLATE=$(awk -F'"' '/"prompt_template":/ {print $4}' "$GAIANET_BASE_DIR/config.json")
    
    # 从URL中提取模型文件名
    CHAT_MODEL_FILE=$(basename "$CHAT_MODEL_URL")
    EMBEDDING_MODEL_FILE=$(basename "$EMBEDDING_MODEL_URL")
else
    echo "${RED}❌ 未找到 $GAIANET_BASE_DIR/config.json 配置文件${NC}"
    exit 1
fi

info() {
    printf "${GREEN}$1${NC}\n"
}

error() {
    printf "${RED}$1${NC}\n"
}

warning() {
    printf "${YELLOW}$1${NC}\n"
}

# 创建必要的目录
setup_directories() {
    info "[+] 创建共享服务目录..."
    mkdir -p "$SHARED_SERVICES_DIR"
    mkdir -p "$LOG_DIR"
    
    # 复制模型文件到共享目录（如果不存在）
    if [ -f "$GAIANET_BASE_DIR/$CHAT_MODEL_FILE" ]; then
        if [ ! -f "$SHARED_SERVICES_DIR/$CHAT_MODEL_FILE" ]; then
            info "    复制Chat模型文件到共享目录..."
            cp "$GAIANET_BASE_DIR/$CHAT_MODEL_FILE" "$SHARED_SERVICES_DIR/"
        fi
    else
        error "❌ Chat模型文件不存在: $GAIANET_BASE_DIR/$CHAT_MODEL_FILE"
        exit 1
    fi
    
    if [ -f "$GAIANET_BASE_DIR/$EMBEDDING_MODEL_FILE" ]; then
        if [ ! -f "$SHARED_SERVICES_DIR/$EMBEDDING_MODEL_FILE" ]; then
            info "    复制Embedding模型文件到共享目录..."
            cp "$GAIANET_BASE_DIR/$EMBEDDING_MODEL_FILE" "$SHARED_SERVICES_DIR/"
        fi
    else
        error "❌ Embedding模型文件不存在: $GAIANET_BASE_DIR/$EMBEDDING_MODEL_FILE"
        exit 1
    fi
    
    # 复制必要的wasm文件
    if [ ! -f "$SHARED_SERVICES_DIR/llama-api-server.wasm" ]; then
        info "    复制LlamaEdge API Server到共享目录..."
        cp "$GAIANET_BASE_DIR/llama-api-server.wasm" "$SHARED_SERVICES_DIR/"
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 等待服务就绪的函数
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_wait=120  # 最大等待2分钟
    local wait_time=0
    
    info "    等待 $service_name 服务就绪..."
    
    while [ $wait_time -lt $max_wait ]; do
        # 检查端口是否在监听
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            # 端口在监听，尝试简单的健康检查
            if curl -s --max-time 5 "http://localhost:$port/v1/models" >/dev/null 2>&1; then
                info "    ✅ $service_name 服务已就绪"
                return 0
            fi
        fi
        
        sleep 5
        wait_time=$((wait_time + 5))
        echo -n "."
    done
    
    echo ""
    error "    ❌ $service_name 服务在 $max_wait 秒内未就绪"
    return 1
}

# 启动共享Chat模型服务
start_chat_service() {
    info "[+] 启动共享Chat模型服务..."
    
    if check_port $CHAT_MODEL_PORT; then
        warning "    ❗ 端口 $CHAT_MODEL_PORT 已被占用，跳过Chat服务启动"
        return
    fi
    
    cd "$SHARED_SERVICES_DIR"
    
    # 构建启动命令 - 使用官方稳定参数 + 多线程并发优化
    local cmd=(
        wasmedge
        --dir ".:."
        --nn-preload "default:GGML:AUTO:$CHAT_MODEL_FILE"
        llama-api-server.wasm
        --model-name "$CHAT_MODEL_NAME"
        --ctx-size "16384"
        --batch-size "128"
        --ubatch-size "128"
        --threads "10"
        --prompt-template "${PROMPT_TEMPLATE:-llama-3-chat}"
        --include-usage
        --port "$CHAT_MODEL_PORT"
    )
    
    info "    启动命令: ${cmd[*]}"
    
    # 启动服务
    nohup "${cmd[@]}" > "$LOG_DIR/chat-service.log" 2>&1 &
    local chat_pid=$!
    echo $chat_pid > "$SHARED_SERVICES_DIR/chat_service.pid"
    
    info "    Chat服务已启动，PID: $chat_pid"
    
    # 等待服务就绪
    if wait_for_service $CHAT_MODEL_PORT "Chat"; then
        info "    ✅ Chat服务启动成功，端口: $CHAT_MODEL_PORT"
    else
        error "    ❌ Chat服务启动失败"
        info "    最后几行日志:"
        tail -10 "$LOG_DIR/chat-service.log" || true
        return 1
    fi
}

# 启动共享Embedding模型服务
start_embedding_service() {
    info "[+] 启动共享Embedding模型服务..."
    
    if check_port $EMBEDDING_MODEL_PORT; then
        warning "    ❗ 端口 $EMBEDDING_MODEL_PORT 已被占用，跳过Embedding服务启动"
        return
    fi
    
    cd "$SHARED_SERVICES_DIR"
    
    # 构建启动命令
    local cmd=(
        wasmedge
        --dir ".:."
        --nn-preload "default:GGML:AUTO:$EMBEDDING_MODEL_FILE"
        llama-api-server.wasm
        --model-name "$EMBEDDING_MODEL_NAME"
        --ctx-size "${EMBEDDING_CTX_SIZE:-8192}"
        --batch-size "8192"
        --ubatch-size "8192"
        --prompt-template "embedding"
        --port "$EMBEDDING_MODEL_PORT"
    )
    
    info "    启动命令: ${cmd[*]}"
    
    # 启动服务
    nohup "${cmd[@]}" > "$LOG_DIR/embedding-service.log" 2>&1 &
    local embedding_pid=$!
    echo $embedding_pid > "$SHARED_SERVICES_DIR/embedding_service.pid"
    
    info "    Embedding服务已启动，PID: $embedding_pid"
    
    # 等待服务就绪
    if wait_for_service $EMBEDDING_MODEL_PORT "Embedding"; then
        info "    ✅ Embedding服务启动成功，端口: $EMBEDDING_MODEL_PORT"
    else
        error "    ❌ Embedding服务启动失败"
        info "    最后几行日志:"
        tail -10 "$LOG_DIR/embedding-service.log" || true
        return 1
    fi
}

# 停止共享服务
stop_services() {
    info "[+] 停止共享模型服务..."
    
    # 停止Chat服务
    if [ -f "$SHARED_SERVICES_DIR/chat_service.pid" ]; then
        local chat_pid=$(cat "$SHARED_SERVICES_DIR/chat_service.pid")
        if ps -p $chat_pid >/dev/null 2>&1; then
            kill -TERM $chat_pid
            sleep 3
            if ps -p $chat_pid >/dev/null 2>&1; then
                kill -9 $chat_pid
            fi
            info "    ✅ Chat服务已停止 (PID: $chat_pid)"
        fi
        rm -f "$SHARED_SERVICES_DIR/chat_service.pid"
    fi
    
    # 停止Embedding服务
    if [ -f "$SHARED_SERVICES_DIR/embedding_service.pid" ]; then
        local embedding_pid=$(cat "$SHARED_SERVICES_DIR/embedding_service.pid")
        if ps -p $embedding_pid >/dev/null 2>&1; then
            kill -TERM $embedding_pid
            sleep 3
            if ps -p $embedding_pid >/dev/null 2>&1; then
                kill -9 $embedding_pid
            fi
            info "    ✅ Embedding服务已停止 (PID: $embedding_pid)"
        fi
        rm -f "$SHARED_SERVICES_DIR/embedding_service.pid"
    fi
    
    # 杀死所有可能残留的wasmedge进程
    pkill -f "wasmedge.*llama-api-server.wasm.*port.*(9000|9001)" 2>/dev/null || true
}

# 显示服务状态
show_status() {
    info "[+] 共享模型服务状态:"
    
    # 检查Chat服务
    if check_port $CHAT_MODEL_PORT; then
        # 进一步检查服务是否响应
        if curl -s --max-time 3 "http://localhost:$CHAT_MODEL_PORT/v1/models" >/dev/null 2>&1; then
            info "    ✅ Chat服务运行正常 - 端口: $CHAT_MODEL_PORT"
        else
            warning "    ⚠️  Chat服务端口被占用但无响应 - 端口: $CHAT_MODEL_PORT"
        fi
    else
        error "    ❌ Chat服务未运行 - 端口: $CHAT_MODEL_PORT"
    fi
    
    # 检查Embedding服务
    if check_port $EMBEDDING_MODEL_PORT; then
        # 进一步检查服务是否响应
        if curl -s --max-time 3 "http://localhost:$EMBEDDING_MODEL_PORT/v1/models" >/dev/null 2>&1; then
            info "    ✅ Embedding服务运行正常 - 端口: $EMBEDDING_MODEL_PORT"
        else
            warning "    ⚠️  Embedding服务端口被占用但无响应 - 端口: $EMBEDDING_MODEL_PORT"
        fi
    else
        error "    ❌ Embedding服务未运行 - 端口: $EMBEDDING_MODEL_PORT"
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 {start|stop|restart|status|help}"
    echo ""
    echo "命令:"
    echo "  start    - 启动共享模型服务"
    echo "  stop     - 停止共享模型服务"
    echo "  restart  - 重启共享模型服务"
    echo "  status   - 显示服务状态"
    echo "  help     - 显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  CHAT_MODEL_PORT=$CHAT_MODEL_PORT"
    echo "  EMBEDDING_MODEL_PORT=$EMBEDDING_MODEL_PORT"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            setup_directories
            start_chat_service
            start_embedding_service
            show_status
            info "✅ 共享模型服务启动完成！"
            info "💡 Chat服务地址: http://localhost:$CHAT_MODEL_PORT"
            info "💡 Embedding服务地址: http://localhost:$EMBEDDING_MODEL_PORT"
            ;;
        stop)
            stop_services
            info "✅ 共享模型服务已停止！"
            ;;
        restart)
            stop_services
            sleep 3
            setup_directories
            start_chat_service
            start_embedding_service
            show_status
            info "✅ 共享模型服务重启完成！"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "❌ 未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 不设置自动清理陷阱 - 让服务持续运行
# trap 'echo ""; info "🛑 正在清理..."; stop_services 2>/dev/null || true' EXIT INT TERM

# 运行主函数
main "$@"