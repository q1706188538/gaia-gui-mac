#!/bin/bash

# GaiaNet多节点系统状态检查脚本

set -e

# 颜色定义
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
NC=$'\e[0m'

info() { printf "${GREEN}$1${NC}\n"; }
error() { printf "${RED}$1${NC}\n"; }
warning() { printf "${YELLOW}$1${NC}\n"; }
highlight() { printf "${BLUE}$1${NC}\n"; }

# 检查系统完整状态
check_system_status() {
    highlight "🔍 GaiaNet多节点系统完整状态检查"
    echo ""
    
    # 1. 共享服务检查
    info "1. 共享服务状态："
    
    # Chat服务
    if curl -s --max-time 3 "http://localhost:9000/v1/models" >/dev/null 2>&1; then
        echo "   ✅ Chat服务 (9000): 正常运行"
    else
        echo "   ❌ Chat服务 (9000): 异常"
    fi
    
    # Embedding服务
    if curl -s --max-time 3 "http://localhost:9001/v1/models" >/dev/null 2>&1; then
        echo "   ✅ Embedding服务 (9001): 正常运行"
    else
        echo "   ❌ Embedding服务 (9001): 异常"
    fi
    
    # 共享Qdrant
    if curl -s --max-time 3 "http://localhost:6333/health" >/dev/null 2>&1; then
        echo "   ✅ 共享Qdrant (6333): 正常运行"
    else
        echo "   ❌ 共享Qdrant (6333): 异常"
    fi
    
    echo ""
    
    # 2. 节点服务检查
    info "2. 节点服务状态："
    
    # 主节点
    if curl -s --max-time 3 "http://localhost:8080/admin/servers" >/dev/null 2>&1; then
        echo "   ✅ 主节点 (8080): 正常运行"
    else
        echo "   ❌ 主节点 (8080): 异常"
    fi
    
    # 从节点2
    if curl -s --max-time 3 "http://localhost:8081/admin/servers" >/dev/null 2>&1; then
        echo "   ✅ 从节点2 (8081): 正常运行"
    else
        echo "   ❌ 从节点2 (8081): 异常"
    fi
    
    # 从节点3
    if curl -s --max-time 3 "http://localhost:8082/admin/servers" >/dev/null 2>&1; then
        echo "   ✅ 从节点3 (8082): 正常运行"
    else
        echo "   ❌ 从节点3 (8082): 异常"
    fi
    
    echo ""
    
    # 3. FRP连接检查
    info "3. FRP网络连接状态："
    
    local frp_processes=$(ps aux | grep frpc | grep -v grep | wc -l | tr -d ' ')
    echo "   活动FRP进程数: $frp_processes"
    
    if [ "$frp_processes" -gt 0 ]; then
        echo "   FRP进程详情:"
        ps aux | grep frpc | grep -v grep | while read line; do
            echo "     $(echo $line | awk '{print $2, $11, $12, $13}')"
        done
    fi
    
    local gaianet_connections=$(lsof -i :7000 2>/dev/null | grep ESTABLISHED | wc -l | tr -d ' ')
    echo "   GaiaNet服务器连接数: $gaianet_connections"
    
    if [ "$gaianet_connections" -gt 0 ]; then
        echo "   连接详情:"
        lsof -i :7000 2>/dev/null | grep ESTABLISHED | while read line; do
            echo "     $(echo $line | awk '{print $1, $2, $9}')"
        done
    fi
    
    echo ""
    
    # 4. 内存使用统计
    info "4. 内存使用情况："
    
    local total_memory=$(ps aux | grep -E "(gaia-nexus|wasmedge|qdrant)" | grep -v grep | awk '{sum += $6} END {printf "%.1f", sum/1024}')
    echo "   当前内存使用: ${total_memory:-0}MB"
    echo "   传统方案预估: 15360MB (3节点 × 5120MB)"
    
    if [ -n "$total_memory" ] && [ $(echo "$total_memory > 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
        local savings=$(echo "15360 - $total_memory" | bc -l 2>/dev/null || echo 0)
        local percentage=$(echo "scale=1; $savings * 100 / 15360" | bc -l 2>/dev/null || echo 0)
        echo "   内存节省: ${savings}MB (${percentage}%)"
    fi
    
    echo ""
    
    # 5. 公网访问地址
    info "5. 公网访问地址："
    
    for node_dir in $HOME/gaianet $HOME/gaianet_node*; do
        if [ -d "$node_dir" ] && [ -f "$node_dir/nodeid.json" ]; then
            local node_name=$(basename "$node_dir")
            local node_address=$(jq -r '.address' "$node_dir/nodeid.json" 2>/dev/null || echo "未知")
            local port=$(jq -r '.llamaedge_port // "未知"' "$node_dir/config.json" 2>/dev/null || echo "未知")
            echo "   $node_name ($port): https://$node_address.gaia.domains"
        fi
    done
    
    echo ""
    
    # 6. 总体评估
    info "6. 系统健康评估："
    
    local services_ok=0
    local total_services=6
    
    # 检查各项服务
    curl -s --max-time 3 "http://localhost:9000/v1/models" >/dev/null 2>&1 && ((services_ok++))
    curl -s --max-time 3 "http://localhost:9001/v1/models" >/dev/null 2>&1 && ((services_ok++))
    curl -s --max-time 3 "http://localhost:6333/health" >/dev/null 2>&1 && ((services_ok++))
    curl -s --max-time 3 "http://localhost:8080/admin/servers" >/dev/null 2>&1 && ((services_ok++))
    curl -s --max-time 3 "http://localhost:8081/admin/servers" >/dev/null 2>&1 && ((services_ok++))
    curl -s --max-time 3 "http://localhost:8082/admin/servers" >/dev/null 2>&1 && ((services_ok++))
    
    local health_percentage=$(echo "scale=1; $services_ok * 100 / $total_services" | bc -l 2>/dev/null || echo 0)
    
    if [ "$services_ok" -eq "$total_services" ]; then
        echo "   🎉 系统状态: 完美 ($services_ok/$total_services 服务正常)"
        echo "   💡 所有服务正常运行，可以开始使用！"
    elif [ "$services_ok" -ge 4 ]; then
        echo "   ⚠️  系统状态: 良好 ($services_ok/$total_services 服务正常)"
        echo "   💡 核心功能正常，部分服务需要检查"
    else
        echo "   ❌ 系统状态: 异常 ($services_ok/$total_services 服务正常)"
        echo "   💡 需要检查和修复多个服务"
    fi
}

# 快速健康检查
quick_health_check() {
    echo "🚀 快速健康检查..."
    
    local issues=0
    
    # 核心服务检查
    if ! curl -s --max-time 3 "http://localhost:9000/v1/models" >/dev/null 2>&1; then
        echo "❌ Chat服务异常"
        ((issues++))
    fi
    
    if ! curl -s --max-time 3 "http://localhost:8081/admin/servers" >/dev/null 2>&1; then
        echo "❌ 从节点2异常"
        ((issues++))
    fi
    
    if [ "$(ps aux | grep frpc | grep -v grep | wc -l | tr -d ' ')" -eq 0 ]; then
        echo "❌ 无FRP连接"
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        echo "✅ 系统运行正常"
        return 0
    else
        echo "⚠️  发现 $issues 个问题，运行完整检查: $0 full"
        return 1
    fi
}

# 修复常见问题
fix_common_issues() {
    highlight "🔧 修复常见问题"
    
    echo "1. 检查并启动共享模型服务..."
    if [ -f "./start_shared_model_services.sh" ]; then
        ./start_shared_model_services.sh start >/dev/null 2>&1 || true
        echo "   ✅ 共享模型服务已启动"
    fi
    
    echo "2. 检查并启动共享RAG服务..."
    if [ -f "./shared_rag_service.sh" ]; then
        ./shared_rag_service.sh start >/dev/null 2>&1 || true
        echo "   ✅ 共享RAG服务已启动"
    fi
    
    echo "3. 重启FRP连接..."
    for node_dir in $HOME/gaianet_node*; do
        if [ -d "$node_dir" ]; then
            local node_name=$(basename "$node_dir")
            echo "   重启 $node_name FRP..."
            
            cd "$node_dir"
            if [ -f "gaia-frp.pid" ]; then
                local old_pid=$(cat gaia-frp.pid)
                kill $old_pid 2>/dev/null || true
            fi
            
            nohup ./bin/frpc -c gaia-frp/frpc.toml > log/start-gaia-frp-proxy.log 2>&1 &
            echo $! > gaia-frp.pid
        fi
    done
    echo "   ✅ FRP连接已重启"
    
    echo ""
    echo "💡 等待10秒后检查修复效果..."
    sleep 10
    quick_health_check
}

# 主函数
main() {
    case "${1:-quick}" in
        full|complete)
            check_system_status
            ;;
        quick|fast)
            quick_health_check
            ;;
        fix|repair)
            fix_common_issues
            ;;
        help|--help|-h)
            echo "GaiaNet多节点系统状态检查工具"
            echo ""
            echo "用法: $0 {quick|full|fix|help}"
            echo ""
            echo "命令:"
            echo "  quick  - 快速健康检查（默认）"
            echo "  full   - 完整状态检查"
            echo "  fix    - 修复常见问题"
            echo "  help   - 显示帮助"
            ;;
        *)
            quick_health_check
            ;;
    esac
}

main "$@"