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
        
        # 使用Python更新JSON配置
        python3 -c "
import json
import sys

config_file = '$node_dir/config.json'
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # 添加RAG相关配置
    config['embedding_collection_name'] = 'default'
    config['rag_policy'] = 'system-message'
    config['rag_prompt'] = 'Use the following information to answer the question.'
    config['context_window'] = 1
    config['qdrant_score_threshold'] = '0.5'
    config['qdrant_limit'] = '3'
    
    # 如果没有snapshot，添加一个默认的（用于触发RAG模式）
    if 'snapshot' not in config or not config['snapshot']:
        config['snapshot'] = 'default_knowledge_base.snapshot'
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ RAG配置已添加到config.json')
except Exception as e:
    print(f'❌ 更新配置失败: {e}')
    sys.exit(1)
"
        
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