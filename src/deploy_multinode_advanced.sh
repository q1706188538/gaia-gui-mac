#!/bin/bash

# GaiaNet 多节点部署管理脚本 - 基于共享模型服务的高级版本
# 用于批量部署和管理多个GaiaNet代理节点

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES_CONFIG_FILE="$SCRIPT_DIR/nodes_config.json"
SHARED_MODEL_SCRIPT="$SCRIPT_DIR/start_shared_model_services.sh"
PROXY_SCRIPT="$SCRIPT_DIR/gaianet_proxy.sh"

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

# 创建示例配置文件
create_example_config() {
    cat > "$NODES_CONFIG_FILE" << 'EOF'
{
  "shared_services": {
    "chat_port": 9000,
    "embedding_port": 9001,
    "auto_start": true
  },
  "nodes": [
    {
      "name": "node1",
      "base_dir": "$HOME/gaianet_node1",
      "port": 8080,
      "local_only": false,
      "force_rag": true,
      "auto_start": true
    },
    {
      "name": "node2", 
      "base_dir": "$HOME/gaianet_node2",
      "port": 8081,
      "local_only": false,
      "force_rag": true,
      "auto_start": true
    },
    {
      "name": "node3",
      "base_dir": "$HOME/gaianet_node3", 
      "port": 8082,
      "local_only": false,
      "force_rag": true,
      "auto_start": true
    }
  ]
}
EOF
    
    info "✅ 示例配置文件已创建: $NODES_CONFIG_FILE"
    info "💡 请根据实际情况修改配置文件"
}

# 检查配置文件
check_config() {
    if [ ! -f "$NODES_CONFIG_FILE" ]; then
        warning "❗ 配置文件不存在: $NODES_CONFIG_FILE"
        info "正在创建示例配置文件..."
        create_example_config
        return 1
    fi
    
    # 检查JSON格式
    if ! python3 -c "import json; json.load(open('$NODES_CONFIG_FILE'))" 2>/dev/null; then
        error "❌ 配置文件JSON格式错误: $NODES_CONFIG_FILE"
        return 1
    fi
    
    return 0
}

# 读取配置中的节点信息
get_nodes_info() {
    python3 -c "
import json
with open('$NODES_CONFIG_FILE', 'r') as f:
    config = json.load(f)
for node in config['nodes']:
    print(f\"{node['name']}|{node['base_dir']}|{node['port']}|{node.get('local_only', False)}|{node.get('force_rag', False)}|{node.get('auto_start', True)}\")
"
}

# 读取共享服务配置
get_shared_services_info() {
    python3 -c "
import json
with open('$NODES_CONFIG_FILE', 'r') as f:
    config = json.load(f)
shared = config.get('shared_services', {})
print(f\"{shared.get('chat_port', 9000)}|{shared.get('embedding_port', 9001)}|{shared.get('auto_start', True)}\")
"
}

# 更新节点配置文件的端口和RAG设置
update_node_config() {
    local base_dir=$1
    local port=$2
    local force_rag=${3:-false}
    
    if [ -f "$base_dir/config.json" ]; then
        # 备份原配置
        cp "$base_dir/config.json" "$base_dir/config.json.backup"
        
        # 检查是否有共享RAG服务
        local use_shared_rag=false
        if [ -f "$SCRIPT_DIR/shared_rag_service.sh" ]; then
            use_shared_rag=true
        fi
        
        # 更新端口和RAG配置
        python3 -c "
import json
with open('$base_dir/config.json', 'r') as f:
    config = json.load(f)
config['llamaedge_port'] = '$port'

# 配置共享RAG服务
use_shared_rag = '$use_shared_rag' == 'true'
if use_shared_rag:
    # 使用共享Qdrant服务
    config['qdrant_url'] = 'http://localhost:6333'
    config['embedding_collection_name'] = 'default'
    config['rag_policy'] = 'system-message'
    config['rag_prompt'] = 'Use the following information to answer the question.'
    config['context_window'] = '1'
    config['qdrant_score_threshold'] = '0.5'
    config['qdrant_limit'] = '3'
else:
    # 使用独立RAG（如果force_rag=true）
    force_rag = '$force_rag' == 'true'
    if force_rag:
        config['embedding_collection_name'] = 'default'
        config['rag_policy'] = 'system-message'
        config['rag_prompt'] = 'Use the following information to answer the question.'
        config['context_window'] = '1'
        config['qdrant_score_threshold'] = '0.5'
        config['qdrant_limit'] = '3'

with open('$base_dir/config.json', 'w') as f:
    json.dump(config, f, indent=2)
"
        if [ "$use_shared_rag" = "true" ]; then
            info "    ✅ 节点配置已更新（端口: $port, 共享RAG: 启用）"
        else
            info "    ✅ 节点配置已更新（端口: $port, 独立RAG: $force_rag）"
        fi
    else
        warning "    ❗ 节点配置文件不存在: $base_dir/config.json"
    fi
}

# 启动共享模型服务
start_shared_services() {
    info "[+] 启动共享模型服务..."
    
    if [ ! -f "$SHARED_MODEL_SCRIPT" ]; then
        error "❌ 共享模型服务脚本不存在: $SHARED_MODEL_SCRIPT"
        return 1
    fi
    
    # 读取共享服务配置
    local shared_info=$(get_shared_services_info)
    local chat_port=$(echo "$shared_info" | cut -d'|' -f1)
    local embedding_port=$(echo "$shared_info" | cut -d'|' -f2)
    local auto_start=$(echo "$shared_info" | cut -d'|' -f3)
    
    if [ "$auto_start" = "True" ]; then
        export CHAT_MODEL_PORT=$chat_port
        export EMBEDDING_MODEL_PORT=$embedding_port
        
        bash "$SHARED_MODEL_SCRIPT" start
        sleep 3
        
        # 验证服务启动
        if curl -s --max-time 5 "http://localhost:$chat_port/v1/models" >/dev/null 2>&1 && \
           curl -s --max-time 5 "http://localhost:$embedding_port/v1/models" >/dev/null 2>&1; then
            info "    ✅ 共享模型服务启动成功"
            return 0
        else
            error "    ❌ 共享模型服务启动失败"
            return 1
        fi
    else
        info "    ⏭️  跳过共享服务启动（auto_start=false）"
        return 0
    fi
}

# 停止共享模型服务
stop_shared_services() {
    info "[+] 停止共享模型服务..."
    
    if [ -f "$SHARED_MODEL_SCRIPT" ]; then
        bash "$SHARED_MODEL_SCRIPT" stop
    else
        warning "    ❗ 共享模型服务脚本不存在"
    fi
}

# 启动单个节点
start_single_node() {
    local name=$1
    local base_dir=$2
    local port=$3
    local local_only=$4
    local force_rag=$5
    
    info "  [+] 启动节点: $name"
    
    # 检查节点目录
    if [ ! -d "$base_dir" ]; then
        error "    ❌ 节点目录不存在: $base_dir"
        return 1
    fi
    
    # 检查代理脚本
    if [ ! -f "$PROXY_SCRIPT" ]; then
        error "    ❌ 代理脚本不存在: $PROXY_SCRIPT"
        return 1
    fi
    
    # 更新节点配置端口
    update_node_config "$base_dir" "$port"
    
    # 构建启动参数
    local args="start --base $base_dir"
    if [ "$local_only" = "True" ]; then
        args="$args --local-only"
    fi
    if [ "$force_rag" = "True" ]; then
        args="$args --force-rag"
    fi
    
    # 启动节点
    if bash "$PROXY_SCRIPT" $args; then
        info "    ✅ 节点 $name 启动成功 (端口: $port)"
        return 0
    else
        error "    ❌ 节点 $name 启动失败"
        return 1
    fi
}

# 停止单个节点
stop_single_node() {
    local name=$1
    local base_dir=$2
    
    info "  [+] 停止节点: $name"
    
    if [ ! -d "$base_dir" ]; then
        warning "    ❗ 节点目录不存在: $base_dir"
        return 1
    fi
    
    if bash "$PROXY_SCRIPT" stop --base "$base_dir"; then
        info "    ✅ 节点 $name 已停止"
        return 0
    else
        warning "    ❗ 节点 $name 停止时出现问题"
        return 1
    fi
}

# 显示单个节点状态
show_single_node_status() {
    local name=$1
    local base_dir=$2
    local port=$3
    
    printf "  %-10s " "$name:"
    
    if [ ! -d "$base_dir" ]; then
        printf "${RED}目录不存在${NC}\n"
        return
    fi
    
    # 检查gaia-nexus进程
    if [ -f "$base_dir/llama_nexus.pid" ]; then
        local pid=$(cat "$base_dir/llama_nexus.pid")
        if kill -0 $pid 2>/dev/null; then
            # 检查端口监听
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                printf "${GREEN}运行中${NC} (PID: $pid, Port: $port)\n"
            else
                printf "${YELLOW}进程存在但端口未监听${NC} (PID: $pid)\n"
            fi
        else
            printf "${RED}未运行${NC} (PID文件存在但进程不存在)\n"
        fi
    else
        printf "${RED}未运行${NC}\n"
    fi
}

# 启动所有节点
start_all_nodes() {
    info "🚀 启动多节点部署..."
    
    # 检查配置
    if ! check_config; then
        error "❌ 配置检查失败"
        return 1
    fi
    
    # 启动共享服务
    if ! start_shared_services; then
        error "❌ 共享服务启动失败，停止部署"
        return 1
    fi
    
    # 启动共享RAG服务（如果存在）
    start_shared_rag_service  # 允许失败，会回退到独立RAG
    
    info "[+] 启动所有节点..."
    local success_count=0
    local total_count=0
    
    # 读取节点配置并启动
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        total_count=$((total_count + 1))
        
        if [ "$auto_start" = "True" ]; then
            if start_single_node "$name" "$base_dir" "$port" "$local_only" "$force_rag"; then
                success_count=$((success_count + 1))
                sleep 2  # 避免同时启动太多节点
            fi
        else
            info "  ⏭️  跳过节点: $name (auto_start=false)"
        fi
    done < <(get_nodes_info)
    
    info "✅ 多节点部署完成！"
    info "📊 成功启动: $success_count/$total_count 个节点"
    
    if [ $success_count -gt 0 ]; then
        info "💡 查看节点状态: $0 status"
        info "💡 停止所有节点: $0 stop"
    fi
}

# 停止所有节点
stop_all_nodes() {
    info "🛑 停止多节点部署..."
    
    if ! check_config; then
        return 1
    fi
    
    info "[+] 停止所有节点..."
    
    # 停止各个节点
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        stop_single_node "$name" "$base_dir"
    done < <(get_nodes_info)
    
    sleep 2
    
    # 停止共享服务
    stop_shared_services
    
    # 停止共享RAG服务
    stop_shared_rag_service
    
    info "✅ 所有节点已停止！"
}

# 显示所有节点状态
show_all_status() {
    info "📊 多节点状态报告:"
    
    if ! check_config; then
        return 1
    fi
    
    # 共享服务状态
    info ""
    info "[共享模型服务]"
    local shared_info=$(get_shared_services_info)
    local chat_port=$(echo "$shared_info" | cut -d'|' -f1)
    local embedding_port=$(echo "$shared_info" | cut -d'|' -f2)
    
    printf "  %-10s " "Chat服务:"
    if curl -s --max-time 3 "http://localhost:$chat_port/v1/models" >/dev/null 2>&1; then
        printf "${GREEN}运行中${NC} (端口: $chat_port)\n"
    else
        printf "${RED}未运行${NC} (端口: $chat_port)\n"
    fi
    
    printf "  %-10s " "Embedding:"
    if curl -s --max-time 3 "http://localhost:$embedding_port/v1/models" >/dev/null 2>&1; then
        printf "${GREEN}运行中${NC} (端口: $embedding_port)\n"
    else
        printf "${RED}未运行${NC} (端口: $embedding_port)\n"
    fi
    
    printf "  %-10s " "共享Qdrant:"
    if curl -s --max-time 3 "http://localhost:6333/health" >/dev/null 2>&1; then
        printf "${GREEN}运行中${NC} (端口: 6333)\n"
    else
        printf "${RED}未运行${NC} (端口: 6333)\n"
    fi
    
    # 节点状态
    info ""
    info "[GaiaNet节点]"
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        show_single_node_status "$name" "$base_dir" "$port"
    done < <(get_nodes_info)
}

# 重启所有节点
restart_all_nodes() {
    info "🔄 重启多节点部署..."
    
    stop_all_nodes
    sleep 5
    start_all_nodes
}

# 启动共享RAG服务
start_shared_rag_service() {
    info "[+] 启动共享RAG服务..."
    
    # 检查共享RAG脚本是否存在
    local shared_rag_script="$SCRIPT_DIR/shared_rag_service.sh"
    if [ ! -f "$shared_rag_script" ]; then
        warning "    ❗ 共享RAG服务脚本不存在: $shared_rag_script"
        info "    将为各节点配置独立RAG服务"
        return 1
    fi
    
    # 启动共享Qdrant服务
    bash "$shared_rag_script" start >/dev/null 2>&1
    sleep 3
    
    # 验证共享Qdrant服务
    if curl -s --max-time 5 "http://localhost:6333/health" >/dev/null 2>&1; then
        info "    ✅ 共享Qdrant服务启动成功 (端口: 6333)"
        return 0
    else
        warning "    ❗ 共享Qdrant服务启动失败，将使用独立RAG"
        return 1
    fi
}

# 停止共享RAG服务
stop_shared_rag_service() {
    info "[+] 停止共享RAG服务..."
    
    local shared_rag_script="$SCRIPT_DIR/shared_rag_service.sh"
    if [ -f "$shared_rag_script" ]; then
        bash "$shared_rag_script" stop >/dev/null 2>&1
    else
        warning "    ❗ 共享RAG服务脚本不存在"
    fi
}
update_frpc_config() {
    local base_dir=$1
    local device_id=$2
    local node_address=$3
    local local_port=$4
    
    if [ -f "$base_dir/gaia-frp/frpc.toml" ]; then
        info "    更新frpc.toml配置..."
        
        # 备份原文件
        cp "$base_dir/gaia-frp/frpc.toml" "$base_dir/gaia-frp/frpc.toml.backup.$(date +%s)"
        
        # 创建正确的TOML配置（无缩进，修复v0.1.3兼容性问题）
        cat > "$base_dir/gaia-frp/frpc.toml" << EOF
serverAddr = "gaia.domains"
serverPort = 7000
metadatas.deviceId = "$device_id"

[[proxies]]
name = "$node_address.gaia.domains"
type = "http"
localPort = $local_port
subdomain = "$node_address"
EOF
        
        info "    ✅ frpc.toml配置已完全更新（无缩进格式）"
        info "      - Device ID: $device_id"
        info "      - Local Port: $local_port"
        info "      - Network Identity: $node_address"
    else
        warning "    ❗ frpc.toml文件不存在: $base_dir/gaia-frp/frpc.toml"
    fi
}

# 初始化节点目录
init_nodes() {
    info "[+] 初始化节点目录..."
    
    if ! check_config; then
        return 1
    fi
    
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        info "  [+] 初始化节点: $name -> $base_dir"
        
        if [ -d "$base_dir" ]; then
            warning "    ❗ 目录已存在: $base_dir"
            continue
        fi
        
        # 创建节点目录
        mkdir -p "$base_dir"
        
        # 复制基础文件（排除身份相关文件）
        if [ -d "$HOME/gaianet" ]; then
            info "    复制基础配置..."
            
            # 复制所有文件除了身份文件和临时文件
            rsync -av --exclude='nodeid.json' --exclude='deviceid.txt' --exclude='keystore' --exclude='*.pid' --exclude='log/' "$HOME/gaianet/" "$base_dir/"
            
            # 重新生成节点身份信息
            info "    生成独立的节点身份..."
            cd "$base_dir"
            
            # 下载官方nodeid.json模板并生成新的身份
            if command -v curl >/dev/null 2>&1; then
                curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/nodeid.json' -o nodeid.json
            elif command -v wget >/dev/null 2>&1; then
                wget -q 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/nodeid.json'
            else
                error "    ❌ 需要curl或wget来下载nodeid.json模板"
                rmdir "$base_dir" 2>/dev/null || true
                continue
            fi
            
            # 基于下载的模板使用 wasmedge 生成完整身份信息
            info "    使用 wasmedge 生成完整身份信息..."
            if [ -f "$HOME/gaianet/registry.wasm" ]; then
                wasmedge --dir .:. "$HOME/gaianet/registry.wasm"
                if [ $? -eq 0 ]; then
                    info "    ✅ 身份信息生成成功"
                else
                    warning "    ⚠️  wasmedge 返回错误，但继续处理"
                fi
            else
                error "    ❌ 未找到 registry.wasm 文件"
                continue
            fi
            
            # 生成新的设备ID（使用与主节点相同的格式）
            # 主节点格式: device-小写hex字符串
            local device_id=""
            if command -v openssl >/dev/null 2>&1; then
                # 生成24位小写hex字符串（与主节点格式一致）
                hex_id=$(openssl rand -hex 12 | tr '[:upper:]' '[:lower:]')
                device_id="device-$hex_id"
                echo "$device_id" > deviceid.txt
            else
                # 备用方案：使用时间戳和随机数生成
                timestamp=$(date +%s)
                random_part=$(printf "%08x" $((RANDOM * RANDOM)))
                device_id="device-${timestamp}${random_part}"
                echo "$device_id" > deviceid.txt
            fi
            
            info "    生成的Device ID: $device_id"
            
            # 获取Node Address（如果存在）
            local node_address=""
            if [ -f "nodeid.json" ]; then
                info "    调试: 检查nodeid.json文件内容..."
                # 显示文件内容用于调试
                if [ -s "nodeid.json" ]; then
                    info "    nodeid.json内容预览:"
                    head -5 nodeid.json | sed 's/^/      /'
                    
                    # 尝试多种可能的地址格式
                    node_address=$(grep -o '"address": "[^"]*"' nodeid.json | cut -d'"' -f4)
                    if [ -z "$node_address" ]; then
                        # 尝试其他可能的格式
                        node_address=$(jq -r '.address // empty' nodeid.json 2>/dev/null)
                    fi
                    if [ -z "$node_address" ]; then
                        # 尝试查找任何包含地址的字段
                        node_address=$(grep -i address nodeid.json | head -1 | cut -d'"' -f4)
                    fi
                else
                    warning "    ❗ nodeid.json文件为空"
                fi
                
                if [ -n "$node_address" ]; then
                    info "    ✅ Node Address: $node_address"
                else
                    warning "    ❗ 未能从nodeid.json中读取到地址"
                fi
            else
                warning "    ❗ nodeid.json文件不存在"
            fi
            
            # 更新frpc.toml配置文件，使其使用独立的Device ID和端口
            update_frpc_config "$base_dir" "$device_id" "$node_address" "$port"
            
            # keystore文件会在节点首次启动时自动生成
            
            # 更新配置端口和RAG设置
            update_node_config "$base_dir" "$port" "$force_rag"
            
            info "    ✅ 节点 $name 初始化完成（独立身份和frpc配置）"
        else
            error "    ❌ 基础gaianet目录不存在: $HOME/gaianet"
            error "    请先运行: gaianet init"
            rmdir "$base_dir" 2>/dev/null || true
        fi
    done < <(get_nodes_info)
}

# 使用gaianet命令验证节点身份
verify_nodes_with_gaianet() {
    info "🔍 使用gaianet命令验证节点身份:"
    
    if ! check_config; then
        return 1
    fi
    
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        info ""
        info "[节点: $name]"
        
        if [ -d "$base_dir" ]; then
            cd "$base_dir"
            
            # 使用gaianet命令获取官方认证的身份信息
            if [ -f "$HOME/gaianet/bin/gaianet" ]; then
                info "  官方gaianet命令验证结果:"
                $HOME/gaianet/bin/gaianet info --base "$base_dir" 2>/dev/null || {
                    warning "  ❗ gaianet命令无法读取此节点配置"
                    info "  请检查节点是否正确初始化"
                }
            else
                warning "  ❗ 未找到gaianet命令: $HOME/gaianet/bin/gaianet"
            fi
        else
            error "  ❌ 节点目录不存在: $base_dir"
        fi
        
    done < <(get_nodes_info)
    
    info ""
    info "💡 如需单独验证某个节点，使用命令:"
    info "   cd /path/to/node && $HOME/gaianet/bin/gaianet info --base \$(pwd)"
}

# 修复现有节点的Device ID问题
fix_existing_nodes_device_id() {
    info "[+] 修复现有节点的Device ID问题..."
    
    if ! check_config; then
        return 1
    fi
    
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        info "  [+] 修复节点: $name"
        
        if [ ! -d "$base_dir" ]; then
            warning "    ❗ 节点目录不存在: $base_dir"
            continue
        fi
        
        # 读取该节点的Device ID
        local device_id=""
        if [ -f "$base_dir/deviceid.txt" ]; then
            device_id=$(cat "$base_dir/deviceid.txt" 2>/dev/null)
            info "    当前Device ID: $device_id"
        else
            # 如果没有deviceid.txt，生成一个新的
            if command -v openssl >/dev/null 2>&1; then
                hex_id=$(openssl rand -hex 12 | tr '[:upper:]' '[:lower:]')
                device_id="device-$hex_id"
                echo "$device_id" > "$base_dir/deviceid.txt"
                info "    生成新的Device ID: $device_id"
            else
                timestamp=$(date +%s)
                random_part=$(printf "%08x" $((RANDOM * RANDOM)))
                device_id="device-${timestamp}${random_part}"
                echo "$device_id" > "$base_dir/deviceid.txt"
                info "    生成新的Device ID: $device_id"
            fi
        fi
        
        # 获取Node Address
        local node_address=""
        if [ -f "$base_dir/nodeid.json" ]; then
            node_address=$(grep -o '"address": "[^"]*"' "$base_dir/nodeid.json" | cut -d'"' -f4)
            info "    Node Address: $node_address"
        fi
        
        # 获取节点的端口配置
        local node_port=""
        if [ -f "$base_dir/config.json" ]; then
            node_port=$(awk -F'"' '/\"llamaedge_port\":/ {print $4}' "$base_dir/config.json")
        fi
        
        # 更新frpc.toml配置
        update_frpc_config "$base_dir" "$device_id" "$node_address" "$node_port"
        
        info "    ✅ 节点 $name Device ID修复完成"
        
    done < <(get_nodes_info)
    
    info "✅ 所有节点Device ID修复完成！"
    info "💡 现在重新启动节点时，每个节点将使用独立的Device ID"
}

# 显示所有节点身份信息
show_nodes_identity() {
    info "📋 节点身份信息报告:"
    
    if ! check_config; then
        return 1
    fi
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local identity_file="$script_dir/nodes_identity_$(date +%Y%m%d_%H%M%S).txt"
    
    # 创建身份信息文件
    echo "=== GaiaNet 多节点身份信息报告 ===" > "$identity_file"
    echo "生成时间: $(date)" >> "$identity_file"
    echo "" >> "$identity_file"
    
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        info ""
        info "[节点: $name]"
        echo "" >> "$identity_file"
        echo "=== 节点: $name ===" >> "$identity_file"
        echo "目录: $base_dir" >> "$identity_file"
        echo "端口: $port" >> "$identity_file"
        
        if [ -d "$base_dir" ]; then
            # NodeID - 从JSON文件中提取地址、keystore和password
            if [ -f "$base_dir/nodeid.json" ]; then
                local node_address=$(grep -o '"address": "[^"]*"' "$base_dir/nodeid.json" | cut -d'"' -f4)
                local keystore_name=$(grep -o '"keystore": "[^"]*"' "$base_dir/nodeid.json" | cut -d'"' -f4)
                local password=$(grep -o '"password": "[^"]*"' "$base_dir/nodeid.json" | cut -d'"' -f4)
                info "  地址: $node_address"
                info "  Keystore标识: $keystore_name"
                info "  Password: $password"
                echo "地址: $node_address" >> "$identity_file"
                echo "Keystore标识: $keystore_name" >> "$identity_file"
                echo "Password: $password" >> "$identity_file"
            else
                warning "  ❗ nodeid.json 不存在"
                echo "地址: 文件不存在" >> "$identity_file"
            fi
            
            # Device ID  
            if [ -f "$base_dir/deviceid.txt" ]; then
                local device_id=$(cat "$base_dir/deviceid.txt" 2>/dev/null)
                info "  DeviceID: $device_id"
                echo "DeviceID: $device_id" >> "$identity_file"
            else
                warning "  ❗ deviceid.txt 不存在"
                echo "DeviceID: 文件不存在" >> "$identity_file"
            fi
            
            # Keystore 文件 - 基于nodeid.json中的keystore标识查找
            local keystore_file=""
            local keystore_name=""
            
            if [ -f "$base_dir/nodeid.json" ]; then
                keystore_name=$(grep -o '"keystore": "[^"]*"' "$base_dir/nodeid.json" | cut -d'"' -f4)
                if [ -n "$keystore_name" ]; then
                    # 查找对应的keystore文件
                    keystore_file=$(find "$base_dir" -name "$keystore_name" -type f 2>/dev/null | head -1)
                    if [ -f "$keystore_file" ]; then
                        info "  Keystore文件: $keystore_name"
                        echo "Keystore文件: $keystore_name" >> "$identity_file"
                        
                        # 复制keystore文件到脚本目录
                        cp "$keystore_file" "$script_dir/${name}_${keystore_name}"
                        info "  ✅ Keystore已复制到: ${name}_${keystore_name}"
                        echo "Keystore备份: ${name}_${keystore_name}" >> "$identity_file"
                        
                        # 读取keystore内容
                        echo "" >> "$identity_file"
                        echo "Keystore内容:" >> "$identity_file"
                        cat "$keystore_file" >> "$identity_file" 2>/dev/null || echo "读取失败" >> "$identity_file"
                    else
                        warning "  ❗ Keystore文件未找到: $keystore_name"
                        echo "Keystore文件: 未找到($keystore_name)" >> "$identity_file"
                    fi
                else
                    warning "  ❗ nodeid.json中未找到keystore标识"
                    echo "Keystore文件: 无标识信息" >> "$identity_file"
                fi
            else
                warning "  ❗ 无法读取keystore信息(nodeid.json不存在)"
                echo "Keystore文件: 无法读取" >> "$identity_file"
            fi
            
        else
            error "  ❌ 节点目录不存在: $base_dir"
            echo "状态: 目录不存在" >> "$identity_file"
        fi
        
        echo "" >> "$identity_file"
        
    done < <(get_nodes_info)
    
    info ""
    info "✅ 身份信息已保存到: $identity_file"
    info "💡 使用命令查看完整报告: cat $identity_file"
}

show_config() {
    info "📋 当前配置信息:"
    
    if ! check_config; then
        return 1
    fi
    
    # 显示共享服务配置
    info ""
    highlight "[共享模型服务配置]"
    local shared_info=$(get_shared_services_info)
    local chat_port=$(echo "$shared_info" | cut -d'|' -f1)
    local embedding_port=$(echo "$shared_info" | cut -d'|' -f2)
    local auto_start=$(echo "$shared_info" | cut -d'|' -f3)
    
    echo "  Chat端口:      $chat_port"
    echo "  Embedding端口: $embedding_port"
    echo "  自动启动:      $auto_start"
    
    # 显示节点配置
    info ""
    highlight "[节点配置]"
    printf "  %-8s %-25s %-6s %-6s %-4s %-5s\n" "名称" "目录" "端口" "本地" "RAG" "自启"
    printf "  %-8s %-25s %-6s %-6s %-4s %-5s\n" "----" "----" "----" "----" "---" "----"
    
    while IFS='|' read -r name base_dir port local_only force_rag auto_start; do
        printf "  %-8s %-25s %-6s %-6s %-4s %-5s\n" \
            "$name" "$base_dir" "$port" "$local_only" "$force_rag" "$auto_start"
    done < <(get_nodes_info)
}

# 显示帮助信息
show_help() {
    echo "GaiaNet 多节点部署管理脚本"
    echo ""
    echo "用法: $0 {command} [options]"
    echo ""
    echo "命令:"
    echo "  init       - 初始化节点目录（避免重复下载大模型，支持共享RAG）"
    echo "  start      - 启动所有节点"
    echo "  stop       - 停止所有节点"
    echo "  restart    - 重启所有节点"
    echo "  status     - 显示所有节点状态"
    echo "  config     - 显示配置信息"
    echo "  identity   - 显示节点身份信息并备份keystore"
    echo "  verify     - 使用gaianet官方命令验证节点身份"
    echo "  fix-device-id - 修复现有节点的Device ID配置问题"
    echo "  create-config - 创建示例配置文件"
    echo "  help       - 显示帮助信息"
    echo ""
    echo "配置文件: $NODES_CONFIG_FILE"
    echo ""
    echo "使用流程:"
    echo "  1. $0 create-config    # 创建配置文件"
    echo "  2. 编辑配置文件 $NODES_CONFIG_FILE"
    echo "  3. $0 init            # 初始化节点目录（正确流程，避免重复下载）"
    echo "  4. $0 start           # 启动所有节点"
    echo "  5. $0 status          # 查看状态"
    echo ""
    echo "特性:"
    echo "  ✅ 避免重复下载大模型文件"
    echo "  ✅ 每个节点独立身份信息"
    echo "  ✅ 共享模型服务节省内存"
    echo "  ✅ 自动检测和配置共享RAG服务"
    echo "  ✅ 修复FRP v0.1.3 TOML格式问题"
}

# 主函数
main() {
    local command="${1:-help}"
    
    case $command in
        start)
            start_all_nodes
            ;;
        stop)
            stop_all_nodes
            ;;
        restart)
            restart_all_nodes
            ;;
        status)
            show_all_status
            ;;
        init)
            init_nodes
            ;;
        config)
            show_config
            ;;
        identity)
            show_nodes_identity
            ;;
        verify)
            verify_nodes_with_gaianet
            ;;
        fix-device-id)
            fix_existing_nodes_device_id
            ;;
        create-config)
            create_example_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "❌ 未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    if ! command -v python3 >/dev/null 2>&1; then
        error "❌ 需要python3来解析JSON配置文件"
        exit 1
    fi
    
    if ! command -v lsof >/dev/null 2>&1; then
        warning "❗ 建议安装lsof以便更好地检查端口状态"
    fi
}

# 清理函数
cleanup() {
    echo ""
    info "🛑 清理中..."
}

# 不设置自动清理陷阱 - 让多节点服务持续运行
# trap cleanup EXIT INT TERM

# 检查依赖并运行主函数
check_dependencies
main "$@"