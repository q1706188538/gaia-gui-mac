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
temp_config="/tmp/subscription_config.yaml"
if curl -fsSL "$SUBSCRIPTION_URL" -o "$temp_config"; then
    echo "✅ 订阅配置下载成功"
    echo ""
    
    # 显示文件前几行以了解格式
    echo "📄 配置文件格式预览:"
    echo "==================="
    head -20 "$temp_config"
    echo ""
    
    # 解析节点名称
    echo "📋 节点列表:"
    echo "============"
    
    # 尝试解析不同格式的配置文件
    if grep -q "proxies:" "$temp_config"; then
        # Clash格式
        echo "检测到 Clash 格式配置"
        echo ""
        
        # 提取节点名称
        grep -A1 "^  - name:" "$temp_config" | grep "name:" | sed 's/^  - name: //' | sed 's/[\x27\x22]//g' | nl
        
    elif grep -q "\"outbounds\"" "$temp_config"; then
        # V2Ray格式
        echo "检测到 V2Ray 格式配置"
        python3 -c "
import json, sys
try:
    with open('$temp_config', 'r') as f:
        data = json.load(f)
    
    outbounds = data.get('outbounds', [])
    count = 1
    for outbound in outbounds:
        if outbound.get('protocol') in ['vmess', 'vless', 'shadowsocks', 'trojan']:
            tag = outbound.get('tag', 'Unknown')
            print(f'{count}. {tag}')
            count += 1
except Exception as e:
    print(f'解析错误: {e}')
"
    else
        echo "尝试多种方式解析节点名称..."
        echo ""
        
        # 方法1: 查找name字段
        echo "🔍 方法1 - 查找name字段:"
        grep -i "name" "$temp_config" | head -10 | nl
        echo ""
        
        # 方法2: 查找server字段附近的信息
        echo "🔍 方法2 - 查找server相关信息:"
        grep -B2 -A2 "server" "$temp_config" | head -15
        echo ""
        
        # 方法3: 尝试解析YAML格式
        echo "🔍 方法3 - YAML解析尝试:"
        python3 -c "
import yaml, sys
try:
    with open('$temp_config', 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
    
    if isinstance(data, dict):
        # 查找proxies字段
        if 'proxies' in data:
            proxies = data['proxies']
            print('找到proxies字段:')
            for i, proxy in enumerate(proxies[:10], 1):  # 只显示前10个
                if isinstance(proxy, dict) and 'name' in proxy:
                    print(f'{i}. {proxy[\"name\"]}')
        else:
            print('未找到proxies字段，显示所有键:')
            for key in data.keys():
                print(f'- {key}')
    else:
        print('配置文件格式不是标准字典')
        
except Exception as e:
    print(f'YAML解析错误: {e}')
    
    # 如果YAML解析失败，尝试逐行查找
    try:
        with open('$temp_config', 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        print('\\n尝试逐行解析:')
        count = 1
        for line in lines:
            if 'name:' in line:
                name = line.split('name:')[-1].strip().strip('\"\'')
                if name and len(name) > 1:
                    print(f'{count}. {name}')
                    count += 1
                    if count > 20:  # 限制显示数量
                        break
    except Exception as e2:
        print(f'逐行解析也失败: {e2}')
"
    fi
    
    echo ""
    echo "💡 使用精确匹配命令:"
    echo "===================="
    echo ""
    
    # 基于您提到的节点名称给出示例
    echo "🎯 基于您提到的 'JP.日本.B-智能' 节点:"
    echo ""
    echo "# 精确切换命令:"
    echo "./clash-node-manager.sh switch \"JP.日本.B-智能\""
    echo ""
    echo "# 搜索日本节点:"
    echo "./clash-node-manager.sh search JP"
    echo "./clash-node-manager.sh search 日本"
    echo ""
    echo "🚀 安装时自动选择日本节点:"
    echo "./install-clash-verge.sh \\"
    echo "  --subscription '$SUBSCRIPTION_URL' \\"
    echo "  --node 'JP' \\"
    echo "  --auto-start"
    echo ""
    echo "📝 如果上面显示了具体的节点名称，请使用完整名称:"
    echo "./clash-node-manager.sh switch \"完整的节点名称\""
    
    # 清理临时文件
    rm -f "$temp_config"
    
else
    echo "❌ 订阅配置下载失败"
    echo "请检查订阅地址是否正确或网络连接"
fi