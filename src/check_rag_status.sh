#!/bin/bash

# RAG功能状态检查脚本
# 显示所有节点的RAG配置和运行状态

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

# 检查单个节点的RAG状态
check_node_rag_status() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    printf "  %-15s " "$node_name:"
    
    if [ ! -d "$node_dir" ]; then
        error "目录不存在"
        return
    fi
    
    # 检查config.json中的RAG配置
    local has_rag_config=false
    local has_snapshot=false
    local has_qdrant_running=false
    
    if [ -f "$node_dir/config.json" ]; then
        if grep -q "rag_policy" "$node_dir/config.json"; then
            has_rag_config=true
        fi
        
        if grep -q '"snapshot"' "$node_dir/config.json" && ! grep -q '"snapshot": ""' "$node_dir/config.json"; then
            has_snapshot=true
        fi
    fi
    
    # 检查Qdrant是否运行
    if [ -f "$node_dir/qdrant.pid" ]; then
        local qdrant_pid=$(cat "$node_dir/qdrant.pid" 2>/dev/null)
        if [ -n "$qdrant_pid" ] && kill -0 "$qdrant_pid" 2>/dev/null; then
            has_qdrant_running=true
        fi
    fi
    
    # 显示状态
    if [ "$has_rag_config" = true ] && [ "$has_snapshot" = true ] && [ "$has_qdrant_running" = true ]; then
        printf "${GREEN}✅ 完整RAG${NC} (配置✓ 数据✓ 运行✓)"
    elif [ "$has_rag_config" = true ] && [ "$has_qdrant_running" = true ]; then
        printf "${YELLOW}⚠️  基础RAG${NC} (配置✓ 运行✓ 数据?)"
    elif [ "$has_rag_config" = true ]; then
        printf "${YELLOW}🔧 已配置${NC} (配置✓ 未运行)"
    else
        printf "${RED}❌ 纯对话${NC}"
    fi
    
    # 显示Qdrant端口信息
    if [ "$has_qdrant_running" = true ]; then
        local qdrant_port=$(lsof -Pi :6333 -sTCP:LISTEN -t 2>/dev/null | head -1)
        if [ -n "$qdrant_port" ]; then
            printf " (Qdrant:6333)"
        fi
    fi
    
    echo ""
}

# 显示RAG配置详情
show_rag_config_details() {
    local node_dir=$1
    local node_name=$(basename "$node_dir")
    
    if [ ! -f "$node_dir/config.json" ]; then
        return
    fi
    
    echo "    📋 $node_name RAG配置:"
    
    # 提取RAG相关配置
    local rag_policy=$(grep -o '"rag_policy": "[^"]*"' "$node_dir/config.json" 2>/dev/null | cut -d'"' -f4)
    local collection=$(grep -o '"embedding_collection_name": "[^"]*"' "$node_dir/config.json" 2>/dev/null | cut -d'"' -f4)
    local threshold=$(grep -o '"qdrant_score_threshold": "[^"]*"' "$node_dir/config.json" 2>/dev/null | cut -d'"' -f4)
    local limit=$(grep -o '"qdrant_limit": "[^"]*"' "$node_dir/config.json" 2>/dev/null | cut -d'"' -f4)
    
    if [ -n "$rag_policy" ]; then
        echo "      - RAG策略: $rag_policy"
        echo "      - 集合名称: ${collection:-default}"  
        echo "      - 相似度阈值: ${threshold:-0.5}"
        echo "      - 检索限制: ${limit:-3}"
    else
        echo "      - 未配置RAG功能"
    fi
    echo ""
}

# 主函数
main() {
    highlight "📊 RAG功能状态报告"
    info ""
    
    info "[节点RAG状态概览]"
    
    # 检查所有节点
    for node_dir in $HOME/gaianet $HOME/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            check_node_rag_status "$node_dir"
        fi
    done
    
    info ""
    info "[详细配置信息]"
    
    # 显示详细配置
    for node_dir in $HOME/gaianet $HOME/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            show_rag_config_details "$node_dir"
        fi
    done
    
    info "💡 状态说明:"
    info "   ✅ 完整RAG: 配置完整且正在运行，可获得最高积分"
    info "   ⚠️  基础RAG: 基本配置运行，但可能缺少知识库数据"  
    info "   🔧 已配置: 配置完成但未运行"
    info "   ❌ 纯对话: 仅基础对话功能"
    info ""
    info "🎯 积分最大化建议: 所有节点都应显示 ✅ 完整RAG 状态"
}

main "$@"