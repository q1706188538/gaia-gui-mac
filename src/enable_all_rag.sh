#!/bin/bash

# 全节点RAG启用脚本 - 最大化积分获得
# 为所有节点启用RAG功能以获得最高积分

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

# 为单个节点启用RAG配置
enable_rag_for_node() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    info "  [+] 为节点 $node_name 启用RAG功能..."
    
    if [ ! -d "$node_dir" ]; then
        error "    ❌ 节点目录不存在: $node_dir"
        return 1
    fi
    
    # 1. 更新config.json，添加RAG相关配置
    if [ -f "$node_dir/config.json" ]; then
        # 备份原配置
        cp "$node_dir/config.json" "$node_dir/config.json.pre-rag-backup"
        
        # 使用sed更新JSON配置，避免python3依赖
        local temp_file="/tmp/enable_rag_$$.json"
        cp "$node_dir/config.json" "$temp_file"
        
        # 添加RAG相关配置
        sed -i.bak1 's/"embedding_collection_name"[[:space:]]*:[[:space:]]*"[^"]*"/"embedding_collection_name": "default"/' "$temp_file"
        sed -i.bak2 's/"rag_policy"[[:space:]]*:[[:space:]]*"[^"]*"/"rag_policy": "system-message"/' "$temp_file"
        sed -i.bak3 's/"rag_prompt"[[:space:]]*:[[:space:]]*"[^"]*"/"rag_prompt": "Use the following information to answer the question."/' "$temp_file"
        sed -i.bak4 's/"context_window"[[:space:]]*:[[:space:]]*"[^"]*"/"context_window": 1/' "$temp_file"
        sed -i.bak5 's/"qdrant_score_threshold"[[:space:]]*:[[:space:]]*"[^"]*"/"qdrant_score_threshold": "0.5"/' "$temp_file"
        sed -i.bak6 's/"qdrant_limit"[[:space:]]*:[[:space:]]*"[^"]*"/"qdrant_limit": "3"/' "$temp_file"
        
        # 如果字段不存在，则在}前添加
        if ! grep -q '"embedding_collection_name"' "$temp_file"; then
            sed -i.bak7 's/}$/,\n  "embedding_collection_name": "default",\n  "rag_policy": "system-message",\n  "rag_prompt": "Use the following information to answer the question.",\n  "context_window": 1,\n  "qdrant_score_threshold": "0.5",\n  "qdrant_limit": "3"\n}/' "$temp_file"
        fi
        
        # 检查是否有snapshot字段，如果没有则添加
        if ! grep -q '"snapshot"' "$temp_file"; then
            sed -i.bak8 's/}$/,\n  "snapshot": "default_knowledge_base.snapshot"\n}/' "$temp_file"
        else
            # 如果snapshot为空，更新它
            sed -i.bak9 's/"snapshot"[[:space:]]*:[[:space:]]*""/"snapshot": "default_knowledge_base.snapshot"/' "$temp_file"
        fi
        
        # 复制更新后的配置文件
        cp "$temp_file" "$node_dir/config.json"
        
        # 清理临时文件
        rm -f "$temp_file" "$temp_file".bak* 2>/dev/null || true
        
        echo "✅ RAG配置已添加到config.json"
        
        if [ $? -eq 0 ]; then
            info "    ✅ config.json RAG配置更新成功"
        else
            error "    ❌ config.json RAG配置更新失败"
            return 1
        fi
    else
        error "    ❌ config.json不存在"
        return 1
    fi
    
    # 2. 确保qdrant目录存在
    if [ ! -d "$node_dir/qdrant" ]; then
        mkdir -p "$node_dir/qdrant"
        info "    ✅ 创建qdrant目录"
    fi
    
    # 3. 复制qdrant配置（如果node3有的话）
    if [ -d "$HOME/gaianet_node3/qdrant" ] && [ "$node_dir" != "$HOME/gaianet_node3" ]; then
        # 复制qdrant基础配置文件
        if [ -f "$HOME/gaianet_node3/qdrant/config.yaml" ]; then
            cp "$HOME/gaianet_node3/qdrant/config.yaml" "$node_dir/qdrant/"
            info "    ✅ 复制qdrant配置文件"
        fi
    fi
    
    # 4. 确保bin/qdrant存在
    if [ ! -f "$node_dir/bin/qdrant" ] && [ -f "$HOME/gaianet_node3/bin/qdrant" ]; then
        cp "$HOME/gaianet_node3/bin/qdrant" "$node_dir/bin/"
        chmod +x "$node_dir/bin/qdrant"
        info "    ✅ 复制qdrant二进制文件"
    fi
    
    info "    ✅ 节点 $node_name RAG功能启用完成"
    return 0
}

# 主函数
main() {
    highlight "🚀 全节点RAG启用 - 最大化积分获得策略"
    info ""
    info "此脚本将为所有节点启用RAG功能，以最大化积分获得"
    info ""
    
    local success_count=0
    local total_count=0
    
    # 为每个节点启用RAG
    for node_dir in $HOME/gaianet $HOME/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            total_count=$((total_count + 1))
            
            # 检查是否已经启用RAG
            if [ -f "$node_dir/config.json" ] && grep -q "rag_policy" "$node_dir/config.json"; then
                info "  ⏭️  跳过 $(basename "$node_dir"): 已启用RAG功能"
                success_count=$((success_count + 1))
            else
                if enable_rag_for_node "$node_dir"; then
                    success_count=$((success_count + 1))
                fi
            fi
        fi
    done
    
    info ""
    info "📊 RAG启用结果: $success_count/$total_count 个节点"
    
    if [ $success_count -eq $total_count ]; then
        highlight "🎉 所有节点RAG功能启用成功！"
        info ""
        info "💡 接下来请运行："
        info "   1. ./deploy_multinode_advanced.sh restart  # 重启所有节点"
        info "   2. ./deploy_multinode_advanced.sh status   # 检查状态"
        info ""
        info "🎯 预期效果："
        info "   - 所有节点都将启动独立的Qdrant实例"
        info "   - 每个节点都支持RAG增强问答" 
        info "   - 最大化积分获得潜力"
        info ""
        warning "⚠️  注意：每个节点将额外消耗约200-500MB内存用于Qdrant"
    else
        error "❌ 部分节点RAG启用失败"
        return 1
    fi
}

main "$@"