#!/bin/bash

# Clash 节点管理工具
# 用于查看、搜索和切换 Clash Verge 中的订阅节点

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC} $1\n"; }
warning() { printf "${YELLOW}[WARNING]${NC} $1\n"; }
error() { printf "${RED}[ERROR]${NC} $1\n"; }
highlight() { printf "${BLUE}[SELECT]${NC} $1\n"; }
title() { printf "${CYAN}$1${NC}\n"; }

# 检查 Clash API 连接
check_clash_api() {
    if ! curl -s http://127.0.0.1:9090/configs >/dev/null 2>&1; then
        error "❌ 无法连接到 Clash API"
        error "请确保 Clash Verge 正在运行且 API 端口为 9090"
        exit 1
    fi
}

# 显示当前状态
show_current_status() {
    title "📊 当前代理状态"
    echo "===================="
    
    local config_json=$(curl -s http://127.0.0.1:9090/configs 2>/dev/null)
    if [[ -n "$config_json" ]]; then
        echo "$config_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    mode = data.get('mode', 'unknown')
    port = data.get('port', 'unknown')
    tun = data.get('tun', {}).get('enable', False)
    print(f'• 代理模式: {mode}')
    print(f'• 监听端口: {port}')
    print(f'• TUN模式: {\"启用\" if tun else \"禁用\"}')
except:
    print('• 状态: 获取失败')
"
    fi
    
    # 显示当前选中的节点
    local proxies_json=$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
    if [[ -n "$proxies_json" ]]; then
        echo "$proxies_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    
    # 查找主要代理组
    main_groups = ['PROXY', '♻️ 自动选择', '🚀 节点选择', 'Proxy', '🌍 节点选择']
    
    for group_name in main_groups:
        if group_name in proxies:
            current = proxies[group_name].get('now', 'unknown')
            print(f'• 当前节点: {current}')
            break
    else:
        # 如果没找到主要代理组，显示第一个Selector类型的
        for name, proxy in proxies.items():
            if proxy.get('type') == 'Selector':
                current = proxy.get('now', 'unknown')
                print(f'• 当前节点: {current} (通过 {name})')
                break
except:
    print('• 当前节点: 获取失败')
"
    fi
    echo
}

# 列出所有代理组
list_proxy_groups() {
    title "🔄 代理组列表"
    echo "=============="
    
    local proxies_json=$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
    if [[ -z "$proxies_json" ]]; then
        error "❌ 无法获取代理列表"
        return 1
    fi
    
    echo "$proxies_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    
    groups = {}
    for name, proxy in proxies.items():
        proxy_type = proxy.get('type', 'unknown')
        if proxy_type in ['Selector', 'URLTest', 'Fallback', 'LoadBalance']:
            groups[name] = proxy
    
    if groups:
        for i, (name, group) in enumerate(groups.items(), 1):
            current = group.get('now', 'unknown')
            all_proxies = group.get('all', [])
            group_type = group.get('type', 'unknown')
            print(f'{i:2d}. {name}')
            print(f'    类型: {group_type}')
            print(f'    当前: {current}')
            print(f'    可选: {len(all_proxies)} 个节点')
            print()
    else:
        print('未找到代理组')
        
except Exception as e:
    print(f'解析错误: {e}')
"
}

# 列出所有节点（分页显示）
list_all_nodes() {
    local page_size=${1:-20}
    local page=${2:-1}
    
    title "🌍 节点列表 (第 $page 页，每页 $page_size 个)"
    echo "============================="
    
    local proxies_json=$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
    if [[ -z "$proxies_json" ]]; then
        error "❌ 无法获取代理列表"
        return 1
    fi
    
    echo "$proxies_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    page_size = int('$page_size')
    page = int('$page')
    
    nodes = []
    for name, proxy in proxies.items():
        proxy_type = proxy.get('type', 'unknown')
        if proxy_type in ['Shadowsocks', 'VMess', 'Trojan', 'Vless', 'Hysteria', 'Hysteria2']:
            delay = proxy.get('history', [])
            delay_ms = delay[-1].get('delay', 0) if delay else 0
            delay_str = f'{delay_ms}ms' if delay_ms > 0 else 'N/A'
            nodes.append((name, delay_str, delay_ms))
    
    # 按延迟排序（延迟为0的排在最后）
    nodes.sort(key=lambda x: x[2] if x[2] > 0 else 9999)
    
    total = len(nodes)
    start_idx = (page - 1) * page_size
    end_idx = start_idx + page_size
    page_nodes = nodes[start_idx:end_idx]
    
    if page_nodes:
        for i, (name, delay, _) in enumerate(page_nodes, start_idx + 1):
            # 标记延迟状态
            if delay == 'N/A':
                status = '⚫'
            elif int(delay.replace('ms', '')) < 100:
                status = '🟢'
            elif int(delay.replace('ms', '')) < 300:
                status = '🟡'
            else:
                status = '🔴'
            
            print(f'{i:3d}. {status} {name} ({delay})')
        
        print(f'\\n显示 {start_idx + 1}-{min(end_idx, total)} / {total} 个节点')
        
        if end_idx < total:
            print(f'💡 查看下一页: $0 list {page_size} {page + 1}')
    else:
        print('未找到节点')
        
except Exception as e:
    print(f'解析错误: {e}')
"
}

# 搜索节点
search_nodes() {
    local search_term="$1"
    
    if [[ -z "$search_term" ]]; then
        error "❌ 请提供搜索关键词"
        echo "用法: $0 search <关键词>"
        echo "示例: $0 search 香港"
        return 1
    fi
    
    title "🔍 搜索节点: $search_term"
    echo "==================="
    
    local proxies_json=$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
    if [[ -z "$proxies_json" ]]; then
        error "❌ 无法获取代理列表"
        return 1
    fi
    
    echo "$proxies_json" | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    search_term = '$search_term'
    
    matches = []
    for name, proxy in proxies.items():
        proxy_type = proxy.get('type', 'unknown')
        if proxy_type in ['Shadowsocks', 'VMess', 'Trojan', 'Vless', 'Hysteria', 'Hysteria2']:
            if re.search(search_term, name, re.IGNORECASE):
                delay = proxy.get('history', [])
                delay_ms = delay[-1].get('delay', 0) if delay else 0
                delay_str = f'{delay_ms}ms' if delay_ms > 0 else 'N/A'
                matches.append((name, delay_str, delay_ms))
    
    if matches:
        # 按延迟排序
        matches.sort(key=lambda x: x[2] if x[2] > 0 else 9999)
        
        for i, (name, delay, _) in enumerate(matches, 1):
            # 标记延迟状态
            if delay == 'N/A':
                status = '⚫'
            elif int(delay.replace('ms', '')) < 100:
                status = '🟢'
            elif int(delay.replace('ms', '')) < 300:
                status = '🟡'
            else:
                status = '🔴'
                
            print(f'{i:2d}. {status} {name} ({delay})')
        
        print(f'\\n找到 {len(matches)} 个匹配的节点')
        print(f'💡 切换到最佳节点: $0 switch \"{matches[0][0]}\"')
    else:
        print('❌ 未找到匹配的节点')
        print('\\n💡 搜索建议:')
        print('  • 尝试更短的关键词: HK, 香港, US, JP, SG')
        print('  • 检查拼写是否正确')
        print('  • 使用 $0 list 查看所有可用节点')
        
except Exception as e:
    print(f'搜索错误: {e}')
"
}

# 切换节点
switch_node() {
    local node_name="$1"
    local proxy_group="${2:-auto}"
    
    if [[ -z "$node_name" ]]; then
        error "❌ 请提供节点名称"
        echo "用法: $0 switch <节点名称> [代理组]"
        echo "示例: $0 switch \"香港-01\""
        return 1
    fi
    
    info "🔄 切换到节点: $node_name"
    
    # 如果代理组是auto，尝试自动找到合适的代理组
    if [[ "$proxy_group" == "auto" ]]; then
        local proxies_json=$(curl -s http://127.0.0.1:9090/proxies 2>/dev/null)
        proxy_group=$(echo "$proxies_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    node_name = '$node_name'
    
    # 查找包含该节点的代理组
    for name, proxy in proxies.items():
        if proxy.get('type') in ['Selector', 'URLTest', 'Fallback', 'LoadBalance']:
            all_proxies = proxy.get('all', [])
            if node_name in all_proxies:
                print(name)
                break
    else:
        # 使用默认代理组
        main_groups = ['PROXY', '♻️ 自动选择', '🚀 节点选择', 'Proxy', '🌍 节点选择']
        for group in main_groups:
            if group in proxies:
                print(group)
                break
except:
    print('PROXY')
")
    fi
    
    if [[ -z "$proxy_group" ]]; then
        proxy_group="PROXY"
    fi
    
    info "📍 使用代理组: $proxy_group"
    
    # 尝试切换节点
    local result=$(curl -s -X PUT "http://127.0.0.1:9090/proxies/$proxy_group" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$node_name\"}" \
        -w "%{http_code}")
    
    local http_code="${result: -3}"
    
    if [[ "$http_code" == "204" ]]; then
        info "✅ 节点切换成功"
        
        # 验证切换结果
        sleep 1
        local current_node=$(curl -s "http://127.0.0.1:9090/proxies/$proxy_group" | \
            python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('now', 'unknown'))" 2>/dev/null)
        
        if [[ "$current_node" == "$node_name" ]]; then
            highlight "🎯 当前节点: $current_node"
            
            # 测试节点延迟
            info "📡 测试延迟..."
            sleep 2
            test_node_delay "$node_name"
        fi
    else
        error "❌ 节点切换失败 (HTTP: $http_code)"
        warning "💡 可能的原因:"
        echo "  • 节点名称不存在"
        echo "  • 代理组名称错误"
        echo "  • 节点暂时不可用"
        
        echo ""
        warning "💡 建议操作:"
        echo "  • 使用 $0 search <关键词> 查找正确的节点名称"
        echo "  • 使用 $0 groups 查看可用的代理组"
    fi
}

# 测试节点延迟
test_node_delay() {
    local node_name="$1"
    
    if [[ -z "$node_name" ]]; then
        error "❌ 请提供节点名称"
        echo "用法: $0 test <节点名称>"
        return 1
    fi
    
    local delay_info=$(curl -s "http://127.0.0.1:9090/proxies/$node_name" | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    history = data.get('history', [])
    if history:
        latest = history[-1]
        delay = latest.get('delay', 0)
        if delay > 0:
            if delay < 100:
                status = '🟢 优秀'
            elif delay < 300:
                status = '🟡 良好'
            else:
                status = '🔴 较慢'
            print(f'{status} - 延迟: {delay}ms')
        else:
            print('🔴 超时 - 节点不可用')
    else:
        print('⚫ 未测试 - 等待测试')
except:
    print('❌ 获取失败')
")
    
    echo "  $delay_info"
}

# 显示帮助信息
show_help() {
    title "🛠️  Clash 节点管理工具"
    echo "======================="
    echo
    echo "用法: $0 <命令> [参数]"
    echo
    echo "命令："
    echo "  status              显示当前代理状态"
    echo "  groups              列出所有代理组"
    echo "  list [页大小] [页号]  列出所有节点（分页）"
    echo "  search <关键词>      搜索节点"
    echo "  switch <节点名>      切换到指定节点"
    echo "  test <节点名>        测试节点延迟"
    echo "  help                显示帮助信息"
    echo
    echo "示例："
    echo "  $0 status                    # 查看当前状态"
    echo "  $0 list                      # 列出前20个节点"
    echo "  $0 list 50 2                 # 列出第2页，每页50个"
    echo "  $0 search 香港                # 搜索包含'香港'的节点"
    echo "  $0 switch \"香港-BGP-01\"       # 切换到指定节点"
    echo "  $0 test \"香港-BGP-01\"         # 测试节点延迟"
    echo
    echo "延迟状态："
    echo "  🟢 < 100ms (优秀)    🟡 100-300ms (良好)"
    echo "  🔴 > 300ms (较慢)    ⚫ 未测试/超时"
}

# 主函数
main() {
    local command="$1"
    
    # 检查Clash连接（除了help命令）
    if [[ "$command" != "help" && "$command" != "-h" && "$command" != "--help" ]]; then
        check_clash_api
    fi
    
    case "$command" in
        "status"|"s")
            show_current_status
            ;;
        "groups"|"g")
            list_proxy_groups
            ;;
        "list"|"l")
            list_all_nodes "$2" "$3"
            ;;
        "search"|"find"|"f")
            search_nodes "$2"
            ;;
        "switch"|"sw")
            switch_node "$2" "$3"
            ;;
        "test"|"t")
            test_node_delay "$2"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            error "❌ 未知命令: $command"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"