#!/bin/bash

# macOS应用构建脚本
# 用于本地构建.app应用

set -e

# 颜色定义
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

info() { printf "${GREEN}$1${NC}\n"; }
error() { printf "${RED}$1${NC}\n"; }
warning() { printf "${YELLOW}$1${NC}\n"; }

# 检查是否在macOS上运行
if [[ "$(uname)" != "Darwin" ]]; then
    error "❌ 此脚本仅能在macOS上运行"
    exit 1
fi

info "🚀 开始构建GaiaNet Manager macOS应用..."

# 检查依赖
if ! command -v python3 >/dev/null 2>&1; then
    error "❌ 未找到Python3"
    exit 1
fi

# 安装构建依赖
info "📦 安装构建依赖..."
pip3 install pyinstaller pillow

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# 创建构建目录
BUILD_DIR="build_macos"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 创建PyInstaller spec文件
info "📝 创建PyInstaller配置..."
cat > "$BUILD_DIR/gaianet_gui.spec" << 'EOF'
# -*- mode: python ; coding: utf-8 -*-

import os
from pathlib import Path

# 获取项目根目录
PROJECT_ROOT = Path.cwd()

block_cipher = None

a = Analysis(
    ['src/gaianet_gui.py'],
    pathex=[str(PROJECT_ROOT)],
    binaries=[],
    datas=[
        ('src/*.sh', 'scripts'),
        ('docs/*', 'docs'),
        ('*.md', '.'),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='GaiaNet Manager',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='GaiaNet Manager',
)

app = BUNDLE(
    coll,
    name='GaiaNet Manager.app',
    icon=None,
    bundle_identifier='com.gaianet.multinode-manager',
    version='1.0.0',
    info_plist={
        'CFBundleDisplayName': 'GaiaNet多节点管理器',
        'CFBundleExecutable': 'GaiaNet Manager',
        'CFBundleIdentifier': 'com.gaianet.multinode-manager',
        'CFBundleName': 'GaiaNet Manager',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundlePackageType': 'APPL',
        'NSHighResolutionCapable': True,
        'NSRequiresAquaSystemAppearance': False,
        'NSAppleScriptEnabled': False,
        'LSMinimumSystemVersion': '10.14.0',
        'NSHumanReadableCopyright': 'Copyright © 2024 GaiaNet Community',
    },
)
EOF

# 构建应用
info "🔨 构建macOS应用..."
cd "$BUILD_DIR"
pyinstaller gaianet_gui.spec

# 检查构建结果
if [ -d "dist/GaiaNet Manager.app" ]; then
    info "✅ 应用构建成功!"
    
    # 复制到发布目录
    RELEASE_DIR="../release"
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR"
    
    cp -r "dist/GaiaNet Manager.app" "$RELEASE_DIR/"
    
    # 设置脚本权限
    SCRIPTS_DIR="$RELEASE_DIR/GaiaNet Manager.app/Contents/Resources/scripts"
    if [ -d "$SCRIPTS_DIR" ]; then
        chmod +x "$SCRIPTS_DIR"/*.sh
        info "✅ 脚本权限设置完成"
    fi
    
    # 创建ZIP包
    info "📦 创建发布包..."
    cd "$RELEASE_DIR"
    zip -r "GaiaNet-Manager-macOS.zip" "GaiaNet Manager.app"
    
    # 显示结果
    echo ""
    info "🎉 构建完成!"
    echo ""
    info "📁 输出文件:"
    echo "  应用: $PROJECT_ROOT/release/GaiaNet Manager.app"
    echo "  ZIP包: $PROJECT_ROOT/release/GaiaNet-Manager-macOS.zip"
    echo ""
    info "💡 使用方法:"
    echo "  1. 双击运行 'GaiaNet Manager.app'"
    echo "  2. 或者分发 'GaiaNet-Manager-macOS.zip' 给其他用户"
    
    # 测试应用
    warning "🧪 测试应用启动..."
    if open "$PROJECT_ROOT/release/GaiaNet Manager.app" --args --test 2>/dev/null; then
        info "✅ 应用可以正常启动"
    else
        warning "⚠️  应用启动测试未通过，请手动测试"
    fi
    
else
    error "❌ 应用构建失败"
    exit 1
fi