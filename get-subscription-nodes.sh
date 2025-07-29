#!/bin/bash

# 订阅节点名称获取工具
# 用于查看订阅中的具体节点名称

SUBSCRIPTION_URL="$1"

if [[ -z "$SUBSCRIPTION_URL" ]]; then
    echo "用法: $0 <订阅地址>"
    exit 1
fi

echo "🔍 正在获取订阅节点列表..."
echo "订阅地址: $SUBSCRIPTION_URL"
echo "=================================="

# 下载订阅配置
temp_config="/tmp/subscription_config.txt"
if curl -fsSL "$SUBSCRIPTION_URL" -o "$temp_config"; then
    echo "✅ 订阅配置下载成功"
    echo ""
    
    # 显示文件前几行以了解格式
    echo "📄 配置文件格式预览:"
    echo "==================="
    head -5 "$temp_config"
    echo ""
    
    # 解析节点名称
    echo "📋 节点列表:"
    echo "============"
    
    # 使用Python解析订阅内容
    python3 -c "
import base64
import urllib.parse
import json
import sys

try:
    with open('$temp_config', 'r', encoding='utf-8') as f:
        content = f.read().strip()
    
    print('🔍 开始解析订阅内容...')
    
    # 尝试base64解码
    try:
        decoded = base64.b64decode(content).decode('utf-8')
        print('✅ Base64解码成功!')
        print('')
        
        lines = decoded.split('\n')
        count = 1
        japan_nodes = []
        all_nodes = []
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            node_name = 'Unknown'
            
            # 解析不同协议的节点
            if line.startswith('vmess://'):
                try:
                    # vmess协议解析
                    vmess_data = line[8:]  # 去掉vmess://前缀
                    vmess_decoded = base64.b64decode(vmess_data).decode('utf-8')
                    vmess_json = json.loads(vmess_decoded)
                    node_name = vmess_json.get('ps', 'Unknown')
                except Exception as e:
                    print(f'   警告: vmess节点解析失败: {str(e)[:50]}...')
                    continue
                    
            elif line.startswith('ss://') or line.startswith('trojan://'):
                try:
                    # SS/Trojan协议解析 - 节点名通常在#后面
                    if '#' in line:
                        name_encoded = line.split('#')[1]
                        node_name = urllib.parse.unquote(name_encoded)
                    else:
                        continue
                except Exception as e:
                    print(f'   警告: ss/trojan节点解析失败: {str(e)[:50]}...')
                    continue
            else:
                continue
            
            if node_name != 'Unknown':
                all_nodes.append(node_name)
                
                # 检查是否为日本节点
                if any(keyword in node_name for keyword in ['JP', '日本', 'Japan', 'jp']):
                    japan_nodes.append(node_name)
                
                # 显示节点信息
                status = '🇯🇵' if any(keyword in node_name for keyword in ['JP', '日本', 'Japan', 'jp']) else '🌍'
                print(f'{count:3d}. {status} {node_name}')
                count += 1
        
        print(f'\\n📊 解析结果统计:')
        print(f'   总节点数: {len(all_nodes)}')
        print(f'   日本节点: {len(japan_nodes)}')
        print('')
        
        if japan_nodes:
            print('🎯 日本相关节点详细列表:')
            print('=' * 50)
            target_found = False
            for i, node in enumerate(japan_nodes, 1):
                marker = ''
                if 'B-智能' in node or 'B-智能' in node:
                    marker = ' ⭐ <- 目标节点!'
                    target_found = True
                print(f'  {i:2d}. {node}{marker}')
            
            if target_found:
                print('')
                print('✅ 找到目标节点 \"JP.日本.B-智能\"!')
            else:
                print('')
                print('⚠️  未找到完全匹配的 \"JP.日本.B-智能\" 节点')
                print('    请检查节点名称是否有变化')
        else:
            print('❌ 未找到任何日本节点')
        
    except Exception as decode_error:
        print(f'❌ Base64解码失败: {decode_error}')
        print('尝试直接解析URL格式...')
        
        # 如果不是base64编码，尝试直接解析
        lines = content.split('\\n')
        count = 1
        for line in lines:
            line = line.strip()
            if line and '#' in line:
                try:
                    name_part = line.split('#')[1]
                    name = urllib.parse.unquote(name_part)
                    status = '🇯🇵' if any(keyword in name for keyword in ['JP', '日本', 'Japan', 'jp']) else '🌍'
                    print(f'{count:3d}. {status} {name}')
                    count += 1
                except:
                    pass
        
except Exception as e:
    print(f'❌ 解析错误: {e}')
    sys.exit(1)
"
    
    echo ""
    echo "💡 使用精确匹配命令:"
    echo "===================="
    echo ""
    
    # 基于解析结果给出具体命令
    echo "🎯 针对您的订阅，推荐使用以下命令:"
    echo ""
    echo "# 1. 安装Clash Verge并自动选择日本节点:"
    echo "./install-clash-verge.sh \\"
    echo "  --subscription '$SUBSCRIPTION_URL' \\"
    echo "  --node 'JP' \\"
    echo "  --auto-start"
    echo ""
    echo "# 2. 如果找到了完整的节点名称，使用精确切换:"
    echo "# ./clash-node-manager.sh switch \"完整的节点名称\""
    echo ""
    echo "# 3. 搜索日本相关节点:"
    echo "./clash-node-manager.sh search JP"
    echo "./clash-node-manager.sh search 日本"
    echo "./clash-node-manager.sh search 智能"
    echo ""
    echo "🚀 一键安装并选择最佳日本节点:"
    echo "curl -fsSL https://raw.githubusercontent.com/q1706188538/gaia-gui-mac/main/install-clash-verge.sh | bash -s -- --subscription '$SUBSCRIPTION_URL' --node 'JP' --auto-start"
    
    # 清理临时文件
    rm -f "$temp_config"
    
else
    echo "❌ 订阅配置下载失败"
    echo "请检查订阅地址是否正确或网络连接"
fi