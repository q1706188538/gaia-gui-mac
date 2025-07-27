#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
GaiaNet多节点部署管理GUI
跨平台用户友好界面 (支持Windows、macOS、Linux)
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog
import subprocess
import threading
import json
import os
import sys
from pathlib import Path
import webbrowser

class GaiaNetGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("GaiaNet多节点部署管理器 v1.2 - 高并发优化版")
        self.root.geometry("1200x800")
        self.root.resizable(True, True)
        
        # 设置样式
        style = ttk.Style()
        # 跨平台主题选择
        if sys.platform == "darwin":  # macOS
            style.theme_use('aqua')
        elif sys.platform == "win32":  # Windows
            style.theme_use('vista')
        else:  # Linux
            style.theme_use('clam')
        
        # 初始化变量
        # 检测是否在PyInstaller打包环境中
        if getattr(sys, 'frozen', False):
            # 打包后的环境
            if sys.platform == "darwin":  # macOS
                # macOS应用包结构: .app/Contents/Resources/scripts/
                app_path = Path(sys.executable).parent.parent
                self.script_dir = app_path / "Resources" / "scripts"
                # GUI运行目录（用于保存用户文件）- 使用用户桌面目录而不是根目录
                desktop_path = Path.home() / "Desktop"
                if desktop_path.exists() and desktop_path.is_dir():
                    self.work_dir = desktop_path
                else:
                    self.work_dir = Path.home()
            else:
                # Windows/Linux打包环境
                self.script_dir = Path(sys.executable).parent / "scripts"
                self.work_dir = Path(sys.executable).parent
        else:
            # 开发环境
            self.script_dir = Path(__file__).parent
            self.work_dir = Path(__file__).parent
        
        # 调试信息：输出脚本目录
        print(f"脚本目录: {self.script_dir}")
        print(f"脚本目录是否存在: {self.script_dir.exists()}")
        print(f"工作目录: {self.work_dir}")
        if self.script_dir.exists():
            print(f"脚本目录内容: {list(self.script_dir.glob('*'))}")
        
        self.nodes_config = []
        self.is_running = False
        
        # 创建界面
        self.create_widgets()
        self.load_default_config()
        
        # 默认选中更新说明页面
        self.notebook.select(0)
        
    def expand_path(self, path_str):
        """展开路径变量（$HOME等）"""
        if path_str.startswith('$HOME'):
            return path_str.replace('$HOME', os.path.expanduser('~'))
        return os.path.expanduser(path_str)
        
    def create_widgets(self):
        """创建主界面组件"""
        # 创建主框架
        main_frame = ttk.Frame(self.root)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # 创建标题
        title_label = ttk.Label(main_frame, text="🚀 GaiaNet多节点部署管理器", 
                               font=('Arial', 18, 'bold'))
        title_label.pack(pady=(0, 20))
        
        # 创建选项卡
        self.notebook = ttk.Notebook(main_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True)
        
        # 底部状态栏 (需要先创建，因为其他组件可能会用到status_var)
        self.create_status_bar(main_frame)
        
        # 选项卡0: 更新说明 (默认页面)
        self.create_updates_tab()
        
        # 选项卡1: 初次安装
        self.create_install_tab()
        
        # 选项卡2: 节点配置
        self.create_config_tab()
        
        # 选项卡3: 系统管理
        self.create_management_tab()
        
        # 选项卡4: 系统状态
        self.create_status_tab()
        
        # 选项卡5: 日志查看
        self.create_log_tab()
        
    def create_updates_tab(self):
        """创建更新说明选项卡"""
        updates_frame = ttk.Frame(self.notebook)
        self.notebook.add(updates_frame, text="📝 更新说明")
        
        # 创建滚动区域
        canvas = tk.Canvas(updates_frame)
        scrollbar = ttk.Scrollbar(updates_frame, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # 标题部分
        title_frame = ttk.Frame(scrollable_frame)
        title_frame.pack(fill=tk.X, padx=20, pady=20)
        
        ttk.Label(title_frame, text="🚀 GaiaNet多节点部署管理器", 
                 font=('Arial', 24, 'bold')).pack(anchor=tk.W)
        ttk.Label(title_frame, text="v1.2 - 高并发优化版", 
                 font=('Arial', 14), foreground='blue').pack(anchor=tk.W, pady=(5, 0))
        
        # 最新更新部分
        latest_frame = ttk.LabelFrame(scrollable_frame, text="🔥 最新更新 (v1.2)", padding=15)
        latest_frame.pack(fill=tk.X, padx=20, pady=10)
        
        latest_updates = """
✨ 重大优化 - 解决多节点并发访问问题
• Chat服务并发能力提升8倍: batch-size 512→4096
• 新增8线程并行处理: parallel 1→8  
• 上下文窗口翻倍: ctx-size 16384→32768
• 添加智能重试机制: 服务繁忙时自动重试3次

🔧 配置文件持久化
• 配置自动保存到桌面，关闭GUI重新打开配置不丢失
• 支持跨平台桌面路径识别 (Desktop/桌面)
• 双重保存策略确保脚本和GUI都能正常工作

⚡ 性能监控与优化
• 支持50+节点同时访问共享服务
• 内存占用优化: 约15-20GB支持大规模部署  
• CPU效率提升: 多线程并行处理
        """
        
        ttk.Label(latest_frame, text=latest_updates.strip(), 
                 font=('Arial', 11), justify=tk.LEFT).pack(anchor=tk.W)
        
        # 功能特性部分
        features_frame = ttk.LabelFrame(scrollable_frame, text="🎯 核心功能", padding=15)
        features_frame.pack(fill=tk.X, padx=20, pady=10)
        
        features_text = """
🏗️  一键部署系统
• 主节点自动安装 (包含5GB模型文件下载)
• 多从节点批量初始化和配置
• 共享服务架构节省50%+内存占用

⚙️  智能配置管理  
• 可视化节点配置界面
• 支持端口、RAG、公网访问等参数配置
• 配置文件自动持久化，重启不丢失

🔄  高级系统管理
• 一键启动/停止/重启所有节点
• 实时系统状态监控和健康检查
• 进程清理和故障排除工具

🌐  网络与代理支持
• 代理服务器配置 (支持受限网络环境)
• SSL证书验证禁用 (提高下载成功率)  
• 智能重试机制 (网络问题自动重试)

📊  监控与诊断
• 实时日志查看和管理
• 节点身份信息查看和备份
• 详细的错误诊断和修复建议
        """
        
        ttk.Label(features_frame, text=features_text.strip(), 
                 font=('Arial', 10), justify=tk.LEFT).pack(anchor=tk.W)
        
        # 系统要求部分
        requirements_frame = ttk.LabelFrame(scrollable_frame, text="💻 系统要求", padding=15)
        requirements_frame.pack(fill=tk.X, padx=20, pady=10)
        
        requirements_text = """
最低配置 (支持10个节点):
• RAM: 16GB+ 
• CPU: 4核心+
• 存储: 20GB 可用空间
• 网络: 稳定互联网连接

推荐配置 (支持30个节点):
• RAM: 32GB+
• CPU: 8核心+ 
• 存储: 50GB SSD
• 网络: 千兆带宽

高性能配置 (支持50+节点):
• RAM: 64GB+
• CPU: 16核心+
• 存储: 100GB+ NVMe SSD  
• 网络: 万兆带宽
        """
        
        ttk.Label(requirements_frame, text=requirements_text.strip(), 
                 font=('Arial', 10), justify=tk.LEFT).pack(anchor=tk.W)
        
        # 快速开始部分
        quickstart_frame = ttk.LabelFrame(scrollable_frame, text="🚀 快速开始", padding=15)
        quickstart_frame.pack(fill=tk.X, padx=20, pady=10)
        
        quickstart_text = """
1. 📦 首次使用: 
   • 切换到 "初次安装" 选项卡
   • 点击 "安装主节点" 下载GaiaNet程序和模型
   • 配置节点数量和参数，点击 "一键部署所有节点"

2. ⚙️ 节点管理:
   • 在 "节点配置" 选项卡管理节点参数
   • 使用 "系统管理" 选项卡控制节点启停
   • 通过 "系统状态" 选项卡监控运行状况

3. 🔧 问题排除:
   • 查看 "日志查看" 选项卡诊断问题
   • 使用 "清理进程" 功能重置系统状态  
   • 配置代理服务器解决网络问题
        """
        
        ttk.Label(quickstart_frame, text=quickstart_text.strip(), 
                 font=('Arial', 10), justify=tk.LEFT).pack(anchor=tk.W)
        
        # 底部按钮
        button_frame = ttk.Frame(scrollable_frame)
        button_frame.pack(fill=tk.X, padx=20, pady=20)
        
        ttk.Button(button_frame, text="🚀 开始安装", 
                  command=lambda: self.notebook.select(1)).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="⚙️ 配置节点", 
                  command=lambda: self.notebook.select(2)).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="🎛️ 系统管理", 
                  command=lambda: self.notebook.select(3)).pack(side=tk.LEFT, padx=5)
        
        # 配置滚动
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # 绑定鼠标滚轮
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

    def create_install_tab(self):
        """创建初次安装选项卡"""
        install_frame = ttk.Frame(self.notebook)
        self.notebook.add(install_frame, text="📦 初次安装")
        
        # 安装步骤说明
        info_frame = ttk.LabelFrame(install_frame, text="安装步骤", padding=10)
        info_frame.pack(fill=tk.X, padx=10, pady=5)
        
        steps_text = """
1. 首次安装主节点 (下载GaiaNet官方程序)
2. 配置从节点参数 (端口、RAG、公网访问等)
3. 初始化所有节点 (生成独立身份信息)
4. 启动多节点系统

⚠️  注意: 首次安装需要下载大约5GB的模型文件，请确保网络连接稳定
        """
        
        ttk.Label(info_frame, text=steps_text, justify=tk.LEFT).pack(anchor=tk.W)
        
        # 主节点安装区域
        main_node_frame = ttk.LabelFrame(install_frame, text="🏠 主节点安装", padding=10)
        main_node_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(main_node_frame, text="主节点安装路径:").grid(row=0, column=0, sticky=tk.W, pady=2)
        self.main_node_path = tk.StringVar(value=os.path.expanduser("~/gaianet"))
        ttk.Entry(main_node_frame, textvariable=self.main_node_path, width=50).grid(row=0, column=1, padx=5)
        ttk.Button(main_node_frame, text="选择", command=self.select_main_node_path).grid(row=0, column=2)
        
        # 安装选项
        self.reinstall_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(main_node_frame, text="重新安装 (删除现有文件)", 
                       variable=self.reinstall_var).grid(row=1, column=0, columnspan=2, sticky=tk.W, pady=5)
        
        # 代理设置
        self.use_proxy_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(main_node_frame, text="使用代理服务器", 
                       variable=self.use_proxy_var, command=self.toggle_proxy_settings).grid(row=2, column=0, columnspan=2, sticky=tk.W, pady=2)
        
        # 代理配置框架
        self.proxy_frame = ttk.LabelFrame(main_node_frame, text="代理设置", padding=5)
        self.proxy_frame.grid(row=3, column=0, columnspan=3, sticky=tk.EW, pady=5)
        self.proxy_frame.grid_remove()  # 初始隐藏
        
        # 代理参数
        ttk.Label(self.proxy_frame, text="地址:").grid(row=0, column=0, sticky=tk.W, padx=2)
        self.proxy_host = tk.StringVar(value="5.253.36.69")
        ttk.Entry(self.proxy_frame, textvariable=self.proxy_host, width=15).grid(row=0, column=1, padx=2)
        
        ttk.Label(self.proxy_frame, text="端口:").grid(row=0, column=2, sticky=tk.W, padx=2)
        self.proxy_port = tk.StringVar(value="22078")
        ttk.Entry(self.proxy_frame, textvariable=self.proxy_port, width=8).grid(row=0, column=3, padx=2)
        
        ttk.Label(self.proxy_frame, text="用户名:").grid(row=1, column=0, sticky=tk.W, padx=2)
        self.proxy_user = tk.StringVar(value="0EGMs0GNqO")
        ttk.Entry(self.proxy_frame, textvariable=self.proxy_user, width=15).grid(row=1, column=1, padx=2)
        
        ttk.Label(self.proxy_frame, text="密码:").grid(row=1, column=2, sticky=tk.W, padx=2)
        self.proxy_pass = tk.StringVar(value="lCcZ2Ai3sF")
        ttk.Entry(self.proxy_frame, textvariable=self.proxy_pass, width=15, show="*").grid(row=1, column=3, padx=2)
        
        # 安装按钮
        install_btn_frame = ttk.Frame(main_node_frame)
        install_btn_frame.grid(row=4, column=0, columnspan=3, pady=10)
        
        ttk.Button(install_btn_frame, text="🚀 安装主节点", 
                  command=self.install_main_node, style='Accent.TButton').pack(side=tk.LEFT, padx=5)
        ttk.Button(install_btn_frame, text="📋 检查安装状态", 
                  command=self.check_install_status).pack(side=tk.LEFT, padx=5)
        
        # 快速部署区域
        quick_frame = ttk.LabelFrame(install_frame, text="⚡ 快速部署", padding=10)
        quick_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(quick_frame, text="从节点数量:").grid(row=0, column=0, sticky=tk.W)
        self.node_count = tk.IntVar(value=3)
        ttk.Spinbox(quick_frame, from_=1, to=10, textvariable=self.node_count, width=10).grid(row=0, column=1, sticky=tk.W, padx=5)
        
        ttk.Label(quick_frame, text="起始端口:").grid(row=0, column=2, sticky=tk.W, padx=(20,0))
        self.start_port = tk.IntVar(value=8081)
        ttk.Spinbox(quick_frame, from_=8081, to=9000, textvariable=self.start_port, width=10).grid(row=0, column=3, sticky=tk.W, padx=5)
        
        # 默认配置选项
        config_frame = ttk.Frame(quick_frame)
        config_frame.grid(row=1, column=0, columnspan=4, sticky=tk.W, pady=10)
        
        self.default_public = tk.BooleanVar(value=True)
        self.default_rag = tk.BooleanVar(value=True)
        self.default_auto = tk.BooleanVar(value=True)
        
        ttk.Checkbutton(config_frame, text="公网访问", variable=self.default_public).pack(side=tk.LEFT, padx=5)
        ttk.Checkbutton(config_frame, text="强制RAG", variable=self.default_rag).pack(side=tk.LEFT, padx=5)
        ttk.Checkbutton(config_frame, text="自动启动", variable=self.default_auto).pack(side=tk.LEFT, padx=5)
        
        ttk.Button(quick_frame, text="🎯 一键部署所有节点", 
                  command=self.quick_deploy_all, style='Accent.TButton').grid(row=2, column=0, columnspan=4, pady=10)
        
        # 安装日志区域
        log_frame = ttk.LabelFrame(install_frame, text="安装日志", padding=10)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # 日志控制按钮
        log_ctrl_frame = ttk.Frame(log_frame)
        log_ctrl_frame.pack(fill=tk.X, pady=(0, 5))
        
        ttk.Button(log_ctrl_frame, text="🧹 清空日志", 
                  command=self.clear_install_log).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="💾 保存日志", 
                  command=self.save_install_log).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="📋 复制日志", 
                  command=self.copy_install_log).pack(side=tk.LEFT, padx=5)
        
        # 自动滚动选项
        self.auto_scroll_install = tk.BooleanVar(value=True)
        ttk.Checkbutton(log_ctrl_frame, text="自动滚动", 
                       variable=self.auto_scroll_install).pack(side=tk.RIGHT, padx=5)
        
        # 日志显示区域
        self.install_log_text = scrolledtext.ScrolledText(log_frame, height=12, font=('Monaco', 10))
        self.install_log_text.pack(fill=tk.BOTH, expand=True)
        
        # 添加初始欢迎消息
        self.append_install_log("📦 安装日志已启动")
        self.append_install_log("💡 点击'安装主节点'开始安装过程")
        
    def create_config_tab(self):
        """创建节点配置选项卡"""
        config_frame = ttk.Frame(self.notebook)
        self.notebook.add(config_frame, text="⚙️ 节点配置")
        
        # 工具栏
        toolbar = ttk.Frame(config_frame)
        toolbar.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Button(toolbar, text="➕ 添加节点", command=self.add_node).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="➖ 删除节点", command=self.remove_node).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="📄 导入配置", command=self.import_config).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="💾 导出配置", command=self.export_config).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="🔄 重置默认", command=self.load_default_config).pack(side=tk.LEFT, padx=2)
        
        # 显示配置文件路径
        config_info_frame = ttk.Frame(config_frame)
        config_info_frame.pack(fill=tk.X, padx=10, pady=2)
        config_file_path = self.get_config_file_path()
        ttk.Label(config_info_frame, text=f"📄 配置文件: {config_file_path}", 
                 font=('Arial', 9), foreground='gray').pack(anchor=tk.W)
        ttk.Label(config_info_frame, text="💡 修改节点配置后会自动保存到桌面，支持持久化", 
                 font=('Arial', 8), foreground='green').pack(anchor=tk.W)
        
        # 节点列表
        list_frame = ttk.LabelFrame(config_frame, text="节点列表", padding=5)
        list_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # 创建Treeview
        columns = ('节点名', '路径', '端口', '公网访问', 'RAG', '自动启动')
        self.tree = ttk.Treeview(list_frame, columns=columns, show='tree headings', height=8)
        
        # 设置列标题
        self.tree.heading('#0', text='ID')
        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=120)
        
        self.tree.column('#0', width=50)
        
        # 滚动条
        scrollbar = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # 编辑区域
        edit_frame = ttk.LabelFrame(config_frame, text="节点编辑", padding=10)
        edit_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # 节点配置表单
        self.create_node_form(edit_frame)
        
        # 绑定选择事件
        self.tree.bind('<<TreeviewSelect>>', self.on_node_select)
        
    def create_management_tab(self):
        """创建系统管理选项卡"""
        mgmt_frame = ttk.Frame(self.notebook)
        self.notebook.add(mgmt_frame, text="🎛️ 系统管理")
        
        # 系统操作区域
        ops_frame = ttk.LabelFrame(mgmt_frame, text="系统操作", padding=10)
        ops_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # 创建按钮网格
        btn_frame1 = ttk.Frame(ops_frame)
        btn_frame1.pack(fill=tk.X, pady=5)
        
        ttk.Button(btn_frame1, text="🔧 初始化所有节点", 
                  command=self.init_nodes, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame1, text="🚀 启动所有节点", 
                  command=self.start_all_nodes, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame1, text="🛑 停止所有节点", 
                  command=self.stop_all_nodes, width=20).pack(side=tk.LEFT, padx=5)
        
        btn_frame2 = ttk.Frame(ops_frame)
        btn_frame2.pack(fill=tk.X, pady=5)
        
        ttk.Button(btn_frame2, text="🔄 重启所有节点", 
                  command=self.restart_all_nodes, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame2, text="📊 查看系统状态", 
                  command=self.show_system_status, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame2, text="🆔 查看身份信息", 
                  command=self.show_identity_info, width=20).pack(side=tk.LEFT, padx=5)
        
        btn_frame3 = ttk.Frame(ops_frame)
        btn_frame3.pack(fill=tk.X, pady=5)
        
        ttk.Button(btn_frame3, text="🧹 清理进程", 
                  command=self.cleanup_processes, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame3, text="🗑️ 删除所有从节点目录", 
                  command=self.delete_all_slave_nodes_directories, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame3, text="🗑️ 删除主节点目录", 
                  command=self.delete_main_node_directory, width=20).pack(side=tk.LEFT, padx=5)
        
        # 高级操作
        advanced_frame = ttk.LabelFrame(mgmt_frame, text="高级操作", padding=10)
        advanced_frame.pack(fill=tk.X, padx=10, pady=5)
        
        btn_frame3 = ttk.Frame(advanced_frame)
        btn_frame3.pack(fill=tk.X, pady=5)
        
        ttk.Button(btn_frame3, text="🔧 修复Device ID", 
                  command=self.fix_device_id, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame3, text="✅ 验证节点身份", 
                  command=self.verify_nodes, width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame3, text="🌐 打开节点URL", 
                  command=self.open_node_urls, width=20).pack(side=tk.LEFT, padx=5)
        
        # 操作进度
        progress_frame = ttk.LabelFrame(mgmt_frame, text="操作进度", padding=10)
        progress_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.progress_var = tk.StringVar(value="就绪")
        self.progress_label = ttk.Label(progress_frame, textvariable=self.progress_var)
        self.progress_label.pack(anchor=tk.W)
        
        self.progress_bar = ttk.Progressbar(progress_frame, mode='indeterminate')
        self.progress_bar.pack(fill=tk.X, pady=5)
        
        # 操作日志区域
        log_frame = ttk.LabelFrame(mgmt_frame, text="操作日志", padding=10)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # 日志控制按钮
        log_ctrl_frame = ttk.Frame(log_frame)
        log_ctrl_frame.pack(fill=tk.X, pady=(0, 5))
        
        ttk.Button(log_ctrl_frame, text="🧹 清空日志", 
                  command=self.clear_mgmt_log).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="💾 保存日志", 
                  command=self.save_mgmt_log).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="📋 复制日志", 
                  command=self.copy_mgmt_log).pack(side=tk.LEFT, padx=5)
        
        # 自动滚动选项
        self.auto_scroll_mgmt = tk.BooleanVar(value=True)
        ttk.Checkbutton(log_ctrl_frame, text="自动滚动", 
                       variable=self.auto_scroll_mgmt).pack(side=tk.RIGHT, padx=5)
        
        # 日志显示区域
        self.mgmt_log_text = scrolledtext.ScrolledText(log_frame, height=15, font=('Monaco', 10))
        self.mgmt_log_text.pack(fill=tk.BOTH, expand=True)
        
        # 添加初始欢迎消息
        self.append_mgmt_log("🎛️ 系统管理日志已启动")
        self.append_mgmt_log("💡 所有操作的详细信息都会显示在这里")
        
    def create_status_tab(self):
        """创建系统状态选项卡"""
        status_frame = ttk.Frame(self.notebook)
        self.notebook.add(status_frame, text="📊 系统状态")
        
        # 状态刷新控件
        refresh_frame = ttk.Frame(status_frame)
        refresh_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Button(refresh_frame, text="🔄 刷新状态", 
                  command=self.refresh_status).pack(side=tk.LEFT, padx=5)
        ttk.Button(refresh_frame, text="⚡ 快速检查", 
                  command=self.quick_health_check).pack(side=tk.LEFT, padx=5)
        ttk.Button(refresh_frame, text="🔧 修复问题", 
                  command=self.fix_common_issues).pack(side=tk.LEFT, padx=5)
        
        # 自动刷新选项
        self.auto_refresh = tk.BooleanVar(value=False)
        ttk.Checkbutton(refresh_frame, text="自动刷新 (30秒)", 
                       variable=self.auto_refresh, command=self.toggle_auto_refresh).pack(side=tk.RIGHT, padx=5)
        
        # 状态显示区域
        self.status_text = scrolledtext.ScrolledText(status_frame, height=25, font=('Monaco', 11))
        self.status_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # 显示初始欢迎信息而不是立即检查状态
        welcome_msg = """📋 系统状态检查器已就绪

💡 使用说明：
• 点击 '🔄 刷新状态' 获取完整系统状态
• 点击 '⚡ 快速检查' 进行节点健康检查  
• 启用 '自动刷新' 可每30秒自动更新状态

📌 重要提示：
• 本系统采用共享服务架构，主节点(8080)不需要运行
• 实际运行的是共享服务 + 从节点(8081/8082/8083)
• 如果看到"主节点异常"这是正常现象，请关注从节点状态"""

        self.update_status_display(welcome_msg)
        
    def create_log_tab(self):
        """创建日志查看选项卡"""
        log_frame = ttk.Frame(self.notebook)
        self.notebook.add(log_frame, text="📝 日志查看")
        
        # 日志控制区域
        log_ctrl_frame = ttk.Frame(log_frame)
        log_ctrl_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(log_ctrl_frame, text="选择节点:").pack(side=tk.LEFT, padx=5)
        
        self.log_node_var = tk.StringVar()
        self.log_node_combo = ttk.Combobox(log_ctrl_frame, textvariable=self.log_node_var, width=20)
        self.log_node_combo.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(log_ctrl_frame, text="📄 查看日志", 
                  command=self.load_node_log).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="🗂️ 打开日志目录", 
                  command=self.open_log_directory).pack(side=tk.LEFT, padx=5)
        ttk.Button(log_ctrl_frame, text="🧹 清空显示", 
                  command=self.clear_log_display).pack(side=tk.LEFT, padx=5)
        
        # 日志显示区域
        self.log_text = scrolledtext.ScrolledText(log_frame, height=30, font=('Monaco', 10))
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # 更新节点列表
        self.update_log_node_list()
        
    def create_status_bar(self, parent):
        """创建状态栏"""
        status_frame = ttk.Frame(parent)
        status_frame.pack(fill=tk.X, side=tk.BOTTOM)
        
        self.status_var = tk.StringVar(value="准备就绪")
        ttk.Label(status_frame, textvariable=self.status_var).pack(side=tk.LEFT, padx=5)
        
        # 版本信息
        ttk.Label(status_frame, text="v1.2").pack(side=tk.RIGHT, padx=5)
        
    def create_node_form(self, parent):
        """创建节点编辑表单"""
        # 节点名称
        ttk.Label(parent, text="节点名称:").grid(row=0, column=0, sticky=tk.W, padx=5, pady=2)
        self.node_name_var = tk.StringVar()
        ttk.Entry(parent, textvariable=self.node_name_var, width=20).grid(row=0, column=1, sticky=tk.W, padx=5)
        
        # 基础目录
        ttk.Label(parent, text="基础目录:").grid(row=0, column=2, sticky=tk.W, padx=5, pady=2)
        self.node_path_var = tk.StringVar()
        ttk.Entry(parent, textvariable=self.node_path_var, width=30).grid(row=0, column=3, sticky=tk.W, padx=5)
        
        # 端口
        ttk.Label(parent, text="端口:").grid(row=1, column=0, sticky=tk.W, padx=5, pady=2)
        self.node_port_var = tk.IntVar()
        ttk.Entry(parent, textvariable=self.node_port_var, width=10).grid(row=1, column=1, sticky=tk.W, padx=5)
        
        # 选项
        self.node_local_only_var = tk.BooleanVar()
        self.node_force_rag_var = tk.BooleanVar()
        self.node_auto_start_var = tk.BooleanVar()
        
        ttk.Checkbutton(parent, text="仅本地访问", variable=self.node_local_only_var).grid(row=1, column=2, sticky=tk.W, padx=5)
        ttk.Checkbutton(parent, text="强制RAG", variable=self.node_force_rag_var).grid(row=1, column=3, sticky=tk.W, padx=5)
        ttk.Checkbutton(parent, text="自动启动", variable=self.node_auto_start_var).grid(row=2, column=0, sticky=tk.W, padx=5)
        
        # 操作按钮
        btn_frame = ttk.Frame(parent)
        btn_frame.grid(row=2, column=1, columnspan=3, sticky=tk.W, pady=10)
        
        ttk.Button(btn_frame, text="💾 保存", command=self.save_node).pack(side=tk.LEFT, padx=2)
        ttk.Button(btn_frame, text="🔄 重置", command=self.reset_node_form).pack(side=tk.LEFT, padx=2)
        
    # 事件处理方法
    def toggle_proxy_settings(self):
        """切换代理设置显示"""
        if self.use_proxy_var.get():
            self.proxy_frame.grid()
        else:
            self.proxy_frame.grid_remove()
    
    def get_proxy_curl_options(self):
        """获取代理curl选项"""
        options = "--insecure"  # 禁用SSL验证提高成功率
        
        if self.use_proxy_var.get():
            host = self.proxy_host.get().strip()
            port = self.proxy_port.get().strip()
            user = self.proxy_user.get().strip()
            password = self.proxy_pass.get().strip()
            
            if host and port and user and password:
                options += f" --proxy http://{user}:{password}@{host}:{port}"
        
        return options
        
    def select_main_node_path(self):
        """选择主节点路径"""
        path = filedialog.askdirectory(title="选择主节点安装目录")
        if path:
            self.main_node_path.set(path)
            
    def install_main_node(self):
        """安装主节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        # 确认对话框
        if self.reinstall_var.get():
            result = messagebox.askyesno("确认", "这将删除现有的GaiaNet安装，是否继续？")
            if not result:
                return
                
        self.run_async_operation("安装主节点中...", self._install_main_node)
        
    def _install_main_node(self):
        """执行主节点安装"""
        try:
            self.root.after(0, lambda: self.append_install_log("🚀 开始主节点安装过程..."))
            
            # 第一步：下载并运行官方安装脚本
            proxy_options = self.get_proxy_curl_options()
            if self.reinstall_var.get():
                install_script = f"""
#!/bin/bash
set -e

# 下载并运行官方安装脚本（重新安装模式）
curl -sSfL {proxy_options} 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash -s -- --reinstall
                """
                self.root.after(0, lambda: self.append_install_log("🔄 使用重新安装模式"))
            else:
                install_script = f"""
#!/bin/bash
set -e

# 下载并运行官方安装脚本
curl -sSfL {proxy_options} 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash
                """
            
            if proxy_options:
                self.root.after(0, lambda: self.append_install_log(f"🌐 使用代理: {self.proxy_host.get()}:{self.proxy_port.get()}"))
            
            cmd = ["bash", "-c", install_script]
                
            self.update_status("📦 步骤1/2: 安装GaiaNet程序...")
            self.root.after(0, lambda: self.append_install_log("📦 步骤1/2: 安装GaiaNet程序..."))
            self.root.after(0, lambda: self.append_install_log(f"📋 执行命令: {' '.join(cmd)}"))
            
            # 使用subprocess.Popen进行实时输出
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1,
                cwd=os.path.expanduser("~")
            )
            
            # 实时读取输出
            install_output = []
            while True:
                line = process.stdout.readline()
                if line:
                    line = line.rstrip('\n\r')
                    install_output.append(line)
                    # 实时显示到安装日志
                    self.root.after(0, lambda l=line: self.append_install_log(f"    {l}"))
                elif process.poll() is not None:
                    break
            
            # 等待进程完成
            return_code = process.wait()
            
            if return_code != 0:
                error_msg = f"程序安装失败（返回码: {return_code}）"
                self.update_status(f"❌ {error_msg}")
                self.root.after(0, lambda: self.append_install_log(f"❌ {error_msg}"))
                self.root.after(0, lambda: messagebox.showerror("错误", f"{error_msg}\n\n详细日志请查看安装日志区域"))
                return
            
            self.root.after(0, lambda: self.append_install_log("✅ 程序安装完成"))
            
            # 第二步：运行gaianet init下载模型文件（带重试机制）
            self.update_status("📥 步骤2/2: 下载模型文件（这可能需要几分钟）...")
            self.root.after(0, lambda: self.append_install_log("📥 步骤2/2: 下载模型文件（这可能需要几分钟）..."))
            
            # 检查gaianet程序是否存在
            gaianet_path = os.path.expanduser("~/gaianet/bin/gaianet")
            if not os.path.exists(gaianet_path):
                error_msg = f"gaianet程序未找到: {gaianet_path}"
                self.update_status(f"❌ {error_msg}")
                self.root.after(0, lambda: self.append_install_log(f"❌ {error_msg}"))
                self.root.after(0, lambda: messagebox.showerror("错误", error_msg))
                return
            
            self.root.after(0, lambda: self.append_install_log(f"✅ 找到gaianet程序: {gaianet_path}"))
            
            # 运行gaianet init（使用绝对路径）- 带重试机制
            init_cmd = [gaianet_path, "init"]
            
            # 设置环境变量，确保能找到相关程序
            env = os.environ.copy()
            gaianet_bin_dir = os.path.expanduser("~/gaianet/bin")
            if gaianet_bin_dir not in env.get('PATH', ''):
                env['PATH'] = gaianet_bin_dir + ':' + env.get('PATH', '')
            
            # 设置代理环境变量（用于脚本中的下载）
            if self.use_proxy_var.get():
                host = self.proxy_host.get().strip()
                port = self.proxy_port.get().strip()
                user = self.proxy_user.get().strip()
                password = self.proxy_pass.get().strip()
                if host and port and user and password:
                    env['GAIANET_PROXY_HOST'] = host
                    env['GAIANET_PROXY_PORT'] = port
                    env['GAIANET_PROXY_USER'] = user
                    env['GAIANET_PROXY_PASS'] = password
            
            # 设置更宽松的curl选项以处理SSL问题
            env['CURL_CA_BUNDLE'] = ''  # 禁用证书验证（仅用于下载）
            
            self.root.after(0, lambda: self.append_install_log(f"📋 执行命令: {' '.join(init_cmd)}"))
            self.root.after(0, lambda: self.append_install_log("🔧 配置网络连接参数以提高下载成功率"))
            
            # 最多重试3次
            max_retries = 3
            for attempt in range(max_retries):
                if attempt > 0:
                    self.root.after(0, lambda a=attempt: self.append_install_log(f"🔄 第 {a+1} 次重试下载..."))
                
                # 使用subprocess.Popen进行实时输出
                init_process = subprocess.Popen(
                    init_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    universal_newlines=True,
                    bufsize=1,
                    cwd=os.path.expanduser("~/gaianet"),
                    env=env
                )
                
                # 实时读取输出
                init_output = []
                while True:
                    line = init_process.stdout.readline()
                    if line:
                        line = line.rstrip('\n\r')
                        init_output.append(line)
                        # 实时显示到安装日志
                        self.root.after(0, lambda l=line: self.append_install_log(f"    {l}"))
                    elif init_process.poll() is not None:
                        break
                
                # 等待进程完成
                init_return_code = init_process.wait()
                
                if init_return_code == 0:
                    success_msg = "✅ 主节点安装成功（包含模型文件）！"
                    self.update_status(success_msg)
                    self.root.after(0, lambda: self.append_install_log(success_msg))
                    self.root.after(0, lambda: self.append_install_log("🎉 安装过程完全完成"))
                    self.root.after(0, lambda: messagebox.showinfo("成功", "主节点安装完成！\n\n✅ 程序已安装\n✅ 模型文件已下载\n\n现在可以配置从节点并进行部署。"))
                    return
                else:
                    # 检查是否是SSL/网络问题
                    output_text = '\n'.join(init_output)
                    if "SSL_ERROR" in output_text or "Failed to download" in output_text or "LibreSSL" in output_text:
                        if attempt < max_retries - 1:
                            self.root.after(0, lambda: self.append_install_log("⚠️ 检测到网络连接问题，准备重试..."))
                            continue
                        else:
                            error_msg = f"模型下载失败（网络连接问题，已重试{max_retries}次）"
                            self.update_status(f"❌ {error_msg}")
                            self.root.after(0, lambda: self.append_install_log(f"❌ {error_msg}"))
                            self.root.after(0, lambda: messagebox.showerror("网络错误", 
                                f"{error_msg}\n\n"
                                "可能的解决方案:\n"
                                "1. 检查网络连接\n"
                                "2. 尝试使用VPN或更换网络\n"
                                "3. 稍后重试安装\n"
                                "4. 手动运行: ~/gaianet/bin/gaianet init\n\n"
                                "详细日志请查看安装日志区域"))
                            return
                    else:
                        error_msg = f"模型下载失败（返回码: {init_return_code}）"
                        self.update_status(f"❌ {error_msg}")
                        self.root.after(0, lambda: self.append_install_log(f"❌ {error_msg}"))
                        self.root.after(0, lambda: messagebox.showerror("错误", f"{error_msg}\n\n程序已安装，但模型文件下载失败。\n请手动运行: ~/gaianet/bin/gaianet init\n\n详细日志请查看安装日志区域"))
                        return
                
        except Exception as e:
            error_msg = f"安装异常: {str(e)}"
            self.update_status(f"❌ {error_msg}")
            self.root.after(0, lambda: self.append_install_log(f"❌ {error_msg}"))
            self.root.after(0, lambda: messagebox.showerror("错误", f"安装过程中发生异常:\n{str(e)}"))
            
    def check_install_status(self):
        """检查安装状态"""
        main_path = os.path.expanduser("~/gaianet")
        
        status_info = []
        status_info.append("=== 主节点安装状态检查 ===\n")
        
        # 检查目录
        if os.path.exists(main_path):
            status_info.append(f"✅ 主节点目录存在: {main_path}")
            
            # 检查关键文件
            key_files = ["bin/gaianet", "config.json", "nodeid.json"]
            for file in key_files:
                file_path = os.path.join(main_path, file)
                if os.path.exists(file_path):
                    status_info.append(f"✅ {file}: 存在")
                else:
                    status_info.append(f"❌ {file}: 缺失")
                    
            # 检查 wasmedge 运行时
            status_info.append("\n=== 运行时依赖检查 ===")
            
            # 检查系统 PATH 中的 wasmedge
            wasmedge_found = False
            
            # 设置包含gaianet路径的环境
            env = os.environ.copy()
            gaianet_bin_dir = os.path.expanduser("~/gaianet/bin")
            if gaianet_bin_dir not in env.get('PATH', ''):
                env['PATH'] = gaianet_bin_dir + ':' + env.get('PATH', '')
            
            try:
                result = subprocess.run(["wasmedge", "--version"], 
                                      capture_output=True, text=True, timeout=5, env=env)
                if result.returncode == 0:
                    version = result.stdout.strip().split('\n')[0]
                    status_info.append(f"✅ wasmedge (系统PATH): 已安装 ({version})")
                    wasmedge_found = True
            except:
                pass
            
            # 检查用户目录中的 wasmedge
            if not wasmedge_found:
                wasmedge_path = os.path.expanduser("~/.wasmedge/bin/wasmedge")
                if os.path.exists(wasmedge_path):
                    try:
                        result = subprocess.run([wasmedge_path, "--version"], 
                                              capture_output=True, text=True, timeout=5)
                        if result.returncode == 0:
                            version = result.stdout.strip().split('\n')[0]
                            status_info.append(f"✅ wasmedge (用户目录): 已安装 ({version})")
                            status_info.append(f"    路径: {wasmedge_path}")
                            wasmedge_found = True
                    except:
                        pass
            
            if not wasmedge_found:
                status_info.append("❌ wasmedge: 未安装或不在PATH中")
                status_info.append("💡 请运行主节点安装或手动安装 wasmedge")
                
        else:
            status_info.append(f"❌ 主节点目录不存在: {main_path}")
            status_info.append("\n💡 请先运行主节点安装")
            
        messagebox.showinfo("安装状态", "\n".join(status_info))
        
    def quick_deploy_all(self):
        """一键部署所有节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        # 检查主节点
        if not os.path.exists(os.path.expanduser("~/gaianet/bin/gaianet")):
            messagebox.showerror("错误", "请先安装主节点！")
            return
            
        result = messagebox.askyesno("确认", f"将创建 {self.node_count.get()} 个从节点并自动部署，是否继续？")
        if not result:
            return
            
        self.run_async_operation("快速部署中...", self._quick_deploy_all)
        
    def _quick_deploy_all(self):
        """执行快速部署"""
        try:
            # 生成节点配置
            self.nodes_config = []
            count = self.node_count.get()
            start_port = self.start_port.get()
            
            for i in range(count):
                node = {
                    "name": f"node{i+1}",
                    "base_dir": f"$HOME/gaianet_node{i+1}",
                    "port": start_port + i,
                    "local_only": not self.default_public.get(),
                    "force_rag": self.default_rag.get(),
                    "auto_start": self.default_auto.get()
                }
                self.nodes_config.append(node)
                
            # 更新界面
            self.root.after(0, self.update_tree)
            
            # 保存配置并部署
            self.save_config_file()
            
            # 执行部署
            script_path = self.script_dir / "deploy_multinode_advanced.sh"
            cmd = [str(script_path), "init"]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                self.update_status("✅ 快速部署完成！")
                self.root.after(0, lambda: messagebox.showinfo("成功", "所有节点部署完成！\n\n现在可以启动节点系统。"))
            else:
                self.update_status(f"❌ 部署失败: {result.stderr}")
                self.root.after(0, lambda: messagebox.showerror("错误", f"部署失败:\n{result.stderr}"))
                
        except Exception as e:
            self.update_status(f"❌ 部署异常: {str(e)}")
            self.root.after(0, lambda: messagebox.showerror("错误", f"部署过程中发生异常:\n{str(e)}"))
            
    def load_default_config(self):
        """加载配置 - 优先从桌面加载，没有则使用默认配置"""
        # 尝试从桌面加载现有配置
        config_path = self.get_config_file_path()
        
        if config_path.exists():
            try:
                print(f"从配置文件加载: {config_path}")
                with open(config_path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    
                if 'nodes' in config and config['nodes']:
                    # 将展开的路径转换回$HOME格式（如果需要）
                    for node in config['nodes']:
                        home_path = os.path.expanduser('~')
                        if node['base_dir'].startswith(home_path):
                            relative_path = node['base_dir'][len(home_path):]
                            if relative_path.startswith('/') or relative_path.startswith('\\'):
                                relative_path = relative_path[1:]
                            if relative_path:
                                node['base_dir'] = f"$HOME/{relative_path}"
                            else:
                                node['base_dir'] = "$HOME"
                    
                    self.nodes_config = config['nodes']
                    self.update_tree()
                    print(f"成功加载 {len(self.nodes_config)} 个节点配置")
                    return
            except Exception as e:
                print(f"加载配置文件失败: {e}")
        
        # 如果没有配置文件或加载失败，使用默认配置
        print("使用默认节点配置")
        self.nodes_config = [
            {
                "name": "node1",
                "base_dir": "$HOME/gaianet_node1",
                "port": 8081,
                "local_only": False,
                "force_rag": True,
                "auto_start": True
            },
            {
                "name": "node2",
                "base_dir": "$HOME/gaianet_node2",
                "port": 8082,
                "local_only": False,
                "force_rag": True,
                "auto_start": True
            },
            {
                "name": "node3",
                "base_dir": "$HOME/gaianet_node3",
                "port": 8083,
                "local_only": False,
                "force_rag": True,
                "auto_start": True
            }
        ]
        self.update_tree()
        # 自动保存默认配置到桌面
        self.save_config_file()
        
    def update_tree(self):
        """更新节点列表显示"""
        # 清空现有项目
        for item in self.tree.get_children():
            self.tree.delete(item)
            
        # 添加节点
        for i, node in enumerate(self.nodes_config):
            # 显示展开后的路径
            display_path = self.expand_path(node['base_dir'])
            
            self.tree.insert('', 'end', iid=i, text=str(i+1), values=(
                node['name'],
                display_path,  # 显示展开后的路径
                node['port'],
                "否" if node['local_only'] else "是",
                "是" if node['force_rag'] else "否",
                "是" if node['auto_start'] else "否"
            ))
            
    def add_node(self):
        """添加新节点"""
        # 生成默认配置
        new_port = 8081
        if self.nodes_config:
            new_port = max(node['port'] for node in self.nodes_config) + 1
            
        new_node = {
            "name": f"node{len(self.nodes_config)+1}",
            "base_dir": f"$HOME/gaianet_node{len(self.nodes_config)+1}",
            "port": new_port,
            "local_only": False,
            "force_rag": True,
            "auto_start": True
        }
        
        self.nodes_config.append(new_node)
        self.update_tree()
        # 自动保存到文件
        self.save_config_file()
        
        # 选中新添加的节点
        self.tree.selection_set(len(self.nodes_config)-1)
        self.on_node_select(None)
        
    def remove_node(self):
        """删除选中节点"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("警告", "请先选择要删除的节点")
            return
            
        result = messagebox.askyesno("确认", "确定要删除选中的节点吗？")
        if result:
            index = int(selection[0])
            del self.nodes_config[index]
            self.update_tree()
            self.reset_node_form()
            # 自动保存到文件
            self.save_config_file()
            
    def on_node_select(self, event):
        """节点选择事件"""
        selection = self.tree.selection()
        if selection:
            index = int(selection[0])
            node = self.nodes_config[index]
            
            # 更新表单 - 显示展开后的路径
            self.node_name_var.set(node['name'])
            self.node_path_var.set(self.expand_path(node['base_dir']))  # 显示展开路径
            self.node_port_var.set(node['port'])
            self.node_local_only_var.set(node['local_only'])
            self.node_force_rag_var.set(node['force_rag'])
            self.node_auto_start_var.set(node['auto_start'])
            
    def save_node(self):
        """保存节点配置"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("警告", "请先选择要编辑的节点")
            return
            
        index = int(selection[0])
        
        # 验证端口
        port = self.node_port_var.get()
        if port < 1024 or port > 65535:
            messagebox.showerror("错误", "端口必须在1024-65535之间")
            return
            
        # 检查端口冲突
        for i, node in enumerate(self.nodes_config):
            if i != index and node['port'] == port:
                messagebox.showerror("错误", f"端口 {port} 已被节点 {node['name']} 使用")
                return
        
        # 处理路径：如果是用户主目录下的路径，转换为$HOME格式
        entered_path = self.node_path_var.get()
        home_path = os.path.expanduser('~')
        
        if entered_path.startswith(home_path):
            # 转换为$HOME格式保存
            relative_path = entered_path[len(home_path):]
            if relative_path.startswith('/'):
                relative_path = relative_path[1:]
            stored_path = f"$HOME/{relative_path}" if relative_path else "$HOME"
        else:
            # 非用户目录，直接保存绝对路径
            stored_path = entered_path
                
        # 更新配置
        self.nodes_config[index] = {
            "name": self.node_name_var.get(),
            "base_dir": stored_path,  # 使用处理后的路径
            "port": port,
            "local_only": self.node_local_only_var.get(),
            "force_rag": self.node_force_rag_var.get(),
            "auto_start": self.node_auto_start_var.get()
        }
        
        self.update_tree()
        # 自动保存配置到文件
        self.save_config_file()
        messagebox.showinfo("成功", "节点配置已保存并同步到文件")
        
    def reset_node_form(self):
        """重置表单"""
        self.node_name_var.set("")
        self.node_path_var.set("")
        self.node_port_var.set(8081)
        self.node_local_only_var.set(False)
        self.node_force_rag_var.set(True)
        self.node_auto_start_var.set(True)
        
    def get_config_file_path(self):
        """获取配置文件路径 - 优先保存到桌面以确保持久化"""
        # 优先级：桌面 > 工作目录 > 脚本目录
        if hasattr(self, 'work_dir') and self.work_dir and self.work_dir.exists() and self.work_dir != Path("/"):
            # 如果有工作目录且不是根目录，使用工作目录
            config_path = self.work_dir / "nodes_config.json"
        else:
            # 使用桌面目录
            desktop_paths = [
                Path.home() / "Desktop",
                Path.home() / "桌面"  # 中文桌面
            ]
            
            config_path = None
            for desktop_path in desktop_paths:
                if desktop_path.exists() and desktop_path.is_dir():
                    config_path = desktop_path / "nodes_config.json"
                    break
            
            # 如果都没找到桌面，回退到脚本目录
            if config_path is None:
                config_path = self.script_dir / "nodes_config.json"
        
        return config_path
    
    def save_config_file(self):
        """保存配置文件"""
        # 展开路径变量
        expanded_nodes = []
        for node in self.nodes_config:
            expanded_node = node.copy()
            expanded_node['base_dir'] = self.expand_path(node['base_dir'])
            expanded_nodes.append(expanded_node)
        
        config = {
            "shared_services": {
                "chat_port": 9000,
                "embedding_port": 9001,
                "auto_start": True
            },
            "nodes": expanded_nodes
        }
        
        # 获取配置文件路径（优先保存到桌面）
        config_path = self.get_config_file_path()
        
        # 确保目录存在
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
            
        print(f"配置文件已保存到: {config_path}")
        print("配置内容（节点路径已展开）:")
        for node in expanded_nodes:
            print(f"  {node['name']}: {node['base_dir']}")
        
        # 同时复制到脚本目录（脚本期望的位置）
        script_config_path = self.script_dir / "nodes_config.json"
        if config_path != script_config_path:
            try:
                with open(script_config_path, 'w', encoding='utf-8') as f:
                    json.dump(config, f, indent=2, ensure_ascii=False)
                print(f"配置文件已同步到脚本目录: {script_config_path}")
            except Exception as e:
                print(f"同步到脚本目录失败: {e}")
            
        # 显示保存的配置文件内容
        print("完整配置文件内容:")
        print(json.dumps(config, indent=2, ensure_ascii=False))
            
    def import_config(self):
        """导入配置"""
        file_path = filedialog.askopenfilename(
            title="选择配置文件",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if file_path:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    
                if 'nodes' in config:
                    self.nodes_config = config['nodes']
                    self.update_tree()
                    # 自动保存到文件（同步到脚本目录）
                    self.save_config_file()
                    messagebox.showinfo("成功", "配置导入成功并已同步")
                else:
                    messagebox.showerror("错误", "配置文件格式不正确")
                    
            except Exception as e:
                messagebox.showerror("错误", f"导入配置失败:\n{str(e)}")
                
    def export_config(self):
        """导出配置"""
        file_path = filedialog.asksaveasfilename(
            title="保存配置文件",
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if file_path:
            try:
                config = {
                    "shared_services": {
                        "chat_port": 9000,
                        "embedding_port": 9001,
                        "auto_start": True
                    },
                    "nodes": self.nodes_config
                }
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(config, f, indent=2, ensure_ascii=False)
                    
                messagebox.showinfo("成功", "配置导出成功")
                
            except Exception as e:
                messagebox.showerror("错误", f"导出配置失败:\n{str(e)}")
                
    # 系统管理方法
    def init_nodes(self):
        """初始化所有节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.save_config_file()
        self.run_async_operation("初始化节点中...", self._run_script_command, "init")
        
    def start_all_nodes(self):
        """启动所有节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.save_config_file()
        self.run_async_operation("启动节点中...", self._run_script_command, "start")
        
    def stop_all_nodes(self):
        """停止所有节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.save_config_file()
        self.run_async_operation("停止节点中...", self._run_script_command, "stop")
        
    def restart_all_nodes(self):
        """重启所有节点"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.save_config_file()
        self.run_async_operation("重启节点中...", self._run_script_command, "restart")
        
    def show_system_status(self):
        """显示系统状态"""
        self.notebook.select(3)  # 切换到状态选项卡
        self.refresh_status()
        
    def show_identity_info(self):
        """显示身份信息"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.run_async_operation("获取身份信息中...", self._run_script_command, "identity")
        
    def cleanup_processes(self):
        """清理GaiaNet相关进程"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        result = messagebox.askyesno("确认清理进程", 
            "即将强制结束以下类型的进程：\n\n"
            "🔄 共享服务进程 (Chat、Embedding、Qdrant)\n"
            "🌐 FRP代理进程 (frpc)\n"
            "⚡ gaia-nexus进程\n"
            "🔧 wasmedge进程\n\n"
            "⚠️ 这将强制结束所有相关进程，可能会影响正在运行的节点\n\n"
            "确定要继续吗？")
        
        if result:
            self.run_async_operation("清理进程中...", self._cleanup_processes)
    
    def _cleanup_processes(self):
        """执行进程清理"""
        try:
            self.root.after(0, lambda: self.append_mgmt_log("🧹 开始清理GaiaNet相关进程..."))
            
            cleanup_count = 0
            
            # 定义要清理的进程模式
            process_patterns = [
                ("frpc", "FRP代理进程"),
                ("gaia-nexus", "gaia-nexus进程"),
                ("wasmedge", "wasmedge进程"),
                ("qdrant", "Qdrant向量数据库"),
                ("llama-server", "Llama服务进程"),
                ("embedding-server", "Embedding服务进程")
            ]
            
            for pattern, description in process_patterns:
                try:
                    self.root.after(0, lambda d=description: self.append_mgmt_log(f"🔍 搜索{d}..."))
                    
                    # 跨平台进程查找和终止
                    if sys.platform == "win32":
                        # Windows: 使用taskkill
                        result = subprocess.run(
                            ["taskkill", "/F", "/IM", f"{pattern}.exe"],
                            capture_output=True, text=True
                        )
                        if result.returncode == 0:
                            cleanup_count += 1
                            self.root.after(0, lambda d=description: 
                                           self.append_mgmt_log(f"✅ 已结束{d}"))
                    else:
                        # macOS/Linux: 使用pkill
                        result = subprocess.run(
                            ["pkill", "-f", pattern],
                            capture_output=True, text=True
                        )
                        if result.returncode == 0:
                            cleanup_count += 1
                            self.root.after(0, lambda d=description: 
                                           self.append_mgmt_log(f"✅ 已结束{d}"))
                        
                        # 额外尝试使用killall（某些系统可能需要）
                        subprocess.run(["killall", "-9", pattern], 
                                     capture_output=True, text=True)
                                     
                except Exception as e:
                    self.root.after(0, lambda d=description, err=str(e): 
                                   self.append_mgmt_log(f"⚠️ 清理{d}时出错: {err}"))
            
            # 清理PID文件
            try:
                self.root.after(0, lambda: self.append_mgmt_log("🗂️ 清理PID文件..."))
                
                pid_patterns = [
                    "*/llama_nexus.pid",
                    "*/gaia-frp.pid", 
                    "*/qdrant.pid",
                    "*/shared_qdrant.pid"
                ]
                
                for pattern in pid_patterns:
                    if sys.platform == "win32":
                        # Windows: 使用del命令
                        subprocess.run(["del", "/Q", pattern], shell=True, 
                                     capture_output=True, text=True)
                    else:
                        # macOS/Linux: 使用rm命令  
                        subprocess.run(["rm", "-f"] + pattern.split(), 
                                     capture_output=True, text=True)
                        
                self.root.after(0, lambda: self.append_mgmt_log("✅ PID文件清理完成"))
                
            except Exception as e:
                self.root.after(0, lambda err=str(e): 
                               self.append_mgmt_log(f"⚠️ 清理PID文件时出错: {err}"))
            
            # 等待进程完全结束
            import time
            time.sleep(2)
            
            success_msg = f"✅ 进程清理完成！处理了 {cleanup_count} 类进程"
            self.update_status(success_msg)
            self.root.after(0, lambda: self.append_mgmt_log(success_msg))
            self.root.after(0, lambda: self.append_mgmt_log("💡 建议等待几秒后再重新启动节点"))
            
            self.root.after(0, lambda: messagebox.showinfo("清理完成", 
                f"进程清理操作完成！\n\n"
                f"✅ 已处理 {cleanup_count} 类相关进程\n"
                f"✅ PID文件已清理\n\n"
                f"💡 现在可以安全地重新启动节点系统\n"
                f"💡 建议先查看系统状态确认清理效果"))
                
        except Exception as e:
            error_msg = f"进程清理操作异常: {str(e)}"
            self.update_status(f"❌ {error_msg}")
            self.root.after(0, lambda: self.append_mgmt_log(f"❌ {error_msg}"))
            self.root.after(0, lambda: messagebox.showerror("错误", f"进程清理操作失败:\n{str(e)}"))
            
    def delete_all_slave_nodes_directories(self):
        """删除所有从节点目录"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        # 首先获取要删除的从节点目录列表
        directories_to_delete = []
        for node in self.nodes_config:
            expanded_path = self.expand_path(node['base_dir'])
            if os.path.exists(expanded_path):
                directories_to_delete.append((node['name'], expanded_path))
        
        if not directories_to_delete:
            messagebox.showinfo("提示", "没有找到需要删除的从节点目录")
            return
            
        # 显示将要删除的目录列表
        dir_list = "\n".join([f"• {name}: {path}" for name, path in directories_to_delete])
        
        # 确认对话框
        result = messagebox.askyesno(
            "⚠️ 危险操作确认", 
            f"即将删除以下 {len(directories_to_delete)} 个从节点目录:\n\n{dir_list}\n\n"
            "⚠️ 警告: 此操作将永久删除:\n"
            "• 所有从节点配置文件\n"
            "• 从节点身份信息 (keystore)\n" 
            "• 从节点日志文件\n"
            "• 其他从节点数据\n\n"
            "❗ 此操作无法撤销，确定要继续吗？\n"
            "💡 主节点目录 ~/gaianet 不会被删除"
        )
        
        if result:
            self.run_async_operation("删除从节点目录中...", self._delete_slave_nodes_directories, directories_to_delete)
        
    def delete_main_node_directory(self):
        """删除主节点目录"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        main_node_path = os.path.expanduser("~/gaianet")
        
        if not os.path.exists(main_node_path):
            messagebox.showinfo("提示", f"主节点目录不存在: {main_node_path}")
            return
            
        # 危险操作确认
        result = messagebox.askyesno(
            "⚠️ 极度危险操作确认", 
            f"即将删除主节点目录:\n{main_node_path}\n\n"
            "⚠️ 警告: 此操作将永久删除:\n"
            "• GaiaNet主程序文件\n"
            "• 主节点配置文件\n"
            "• 主节点身份信息\n"
            "• 所有下载的模型文件 (数GB)\n"
            "• 主节点日志和数据\n\n"
            "❗ 删除后需要重新安装整个GaiaNet系统！\n"
            "❗ 此操作无法撤销，确定要继续吗？"
        )
        
        if result:
            self.run_async_operation("删除主节点目录中...", self._delete_main_node_directory, main_node_path)
        
    def _delete_slave_nodes_directories(self, directories_to_delete):
        """执行删除所有从节点目录"""
        try:
            self.root.after(0, lambda: self.append_mgmt_log("🗑️ 开始删除所有从节点目录..."))
            
            deleted_count = 0
            failed_count = 0
            
            for node_name, dir_path in directories_to_delete:
                try:
                    self.root.after(0, lambda n=node_name, p=dir_path: 
                                   self.append_mgmt_log(f"🗑️ 正在删除从节点 {n}: {p}"))
                    
                    if os.path.exists(dir_path):
                        # 使用跨平台的删除命令
                        if sys.platform == "win32":
                            # Windows
                            import shutil
                            shutil.rmtree(dir_path)
                        else:
                            # macOS/Linux
                            subprocess.run(['rm', '-rf', dir_path], check=True)
                        
                        self.root.after(0, lambda n=node_name: 
                                       self.append_mgmt_log(f"✅ 从节点 {n} 目录删除成功"))
                        deleted_count += 1
                    else:
                        self.root.after(0, lambda n=node_name: 
                                       self.append_mgmt_log(f"⚠️ 从节点 {n} 目录不存在，跳过"))
                        
                except Exception as e:
                    error_msg = f"删除从节点 {node_name} 失败: {str(e)}"
                    self.root.after(0, lambda msg=error_msg: self.append_mgmt_log(f"❌ {msg}"))
                    failed_count += 1
            
            # 删除完成后的结果报告
            success_msg = f"✅ 从节点删除操作完成！成功: {deleted_count}, 失败: {failed_count}"
            self.update_status(success_msg)
            self.root.after(0, lambda: self.append_mgmt_log(success_msg))
            
            if failed_count == 0:
                self.root.after(0, lambda: messagebox.showinfo("删除完成", 
                    f"所有从节点目录删除成功！\n\n"
                    f"已删除 {deleted_count} 个从节点目录\n"
                    f"主节点目录 ~/gaianet 保持不变\n"
                    f"现在可以重新初始化从节点"))
            else:
                self.root.after(0, lambda: messagebox.showwarning("删除完成", 
                    f"从节点删除操作完成，但有部分失败\n\n"
                    f"成功: {deleted_count} 个目录\n"
                    f"失败: {failed_count} 个目录\n\n"
                    f"请查看操作日志了解详细信息"))
                
        except Exception as e:
            error_msg = f"从节点删除操作异常: {str(e)}"
            self.update_status(f"❌ {error_msg}")
            self.root.after(0, lambda: self.append_mgmt_log(f"❌ {error_msg}"))
            self.root.after(0, lambda: messagebox.showerror("错误", f"从节点删除操作失败:\n{str(e)}"))
    
    def _delete_main_node_directory(self, main_node_path):
        """执行删除主节点目录"""
        try:
            self.root.after(0, lambda: self.append_mgmt_log("🗑️ 开始删除主节点目录..."))
            self.root.after(0, lambda p=main_node_path: self.append_mgmt_log(f"🗑️ 目标路径: {p}"))
            
            if os.path.exists(main_node_path):
                # 使用跨平台的删除命令
                if sys.platform == "win32":
                    # Windows
                    import shutil
                    shutil.rmtree(main_node_path)
                else:
                    # macOS/Linux
                    subprocess.run(['rm', '-rf', main_node_path], check=True)
                
                success_msg = "✅ 主节点目录删除成功"
                self.update_status(success_msg)
                self.root.after(0, lambda: self.append_mgmt_log(success_msg))
                self.root.after(0, lambda: self.append_mgmt_log("💡 GaiaNet主程序已完全卸载"))
                
                self.root.after(0, lambda: messagebox.showinfo("删除完成", 
                    "主节点目录删除成功！\n\n"
                    "✅ GaiaNet主程序已完全卸载\n"
                    "✅ 所有模型文件已删除\n"
                    "✅ 主节点配置和数据已清空\n\n"
                    "💡 如需重新使用，请点击'安装主节点'重新安装"))
            else:
                warning_msg = "⚠️ 主节点目录不存在，无需删除"
                self.update_status(warning_msg)
                self.root.after(0, lambda: self.append_mgmt_log(warning_msg))
                self.root.after(0, lambda: messagebox.showinfo("提示", f"主节点目录不存在: {main_node_path}"))
                
        except Exception as e:
            error_msg = f"主节点删除操作异常: {str(e)}"
            self.update_status(f"❌ {error_msg}")
            self.root.after(0, lambda: self.append_mgmt_log(f"❌ {error_msg}"))
            self.root.after(0, lambda: messagebox.showerror("错误", f"主节点删除操作失败:\n{str(e)}"))
            
    def fix_device_id(self):
        """修复Device ID"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        result = messagebox.askyesno("确认", "这将修复所有节点的Device ID配置，是否继续？")
        if result:
            self.run_async_operation("修复Device ID中...", self._run_script_command, "fix-device-id")
            
    def verify_nodes(self):
        """验证节点身份"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        self.run_async_operation("验证节点中...", self._run_script_command, "verify")
        
    def open_node_urls(self):
        """打开节点URL"""
        try:
            # 读取节点状态获取URL
            script_path = self.script_dir / "deploy_multinode_advanced.sh"
            result = subprocess.run([str(script_path), "identity"], 
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                # 解析输出获取地址
                lines = result.stdout.split('\n')
                urls = []
                
                for line in lines:
                    if '地址:' in line:
                        address = line.split('地址:')[1].strip()
                        if address and address != '文件不存在':
                            url = f"https://{address}.gaia.domains"
                            urls.append(url)
                            
                if urls:
                    for url in urls:
                        webbrowser.open(url)
                    messagebox.showinfo("成功", f"已打开 {len(urls)} 个节点URL")
                else:
                    messagebox.showwarning("警告", "未找到有效的节点地址")
            else:
                messagebox.showerror("错误", "获取节点地址失败")
                
        except Exception as e:
            messagebox.showerror("错误", f"打开URL失败:\n{str(e)}")
            
    def _run_script_command(self, command):
        """运行脚本命令"""
        try:
            script_path = self.script_dir / "deploy_multinode_advanced.sh"
            
            # 调试信息
            print(f"执行脚本: {script_path}")
            print(f"脚本存在: {script_path.exists()}")
            print(f"工作目录: {self.work_dir}")
            if script_path.exists():
                print(f"脚本权限: {oct(script_path.stat().st_mode)}")
            
            # 设置环境变量，告诉脚本工作目录
            env = os.environ.copy()
            env['GAIA_WORK_DIR'] = str(self.work_dir)
            
            # 确保 wasmedge 在 PATH 中 (macOS 特别处理)
            if sys.platform == "darwin":
                wasmedge_path = os.path.expanduser("~/.wasmedge/bin")
                if os.path.exists(wasmedge_path):
                    if wasmedge_path not in env.get('PATH', ''):
                        env['PATH'] = wasmedge_path + ':' + env.get('PATH', '')
                        print(f"添加 wasmedge 路径到 PATH: {wasmedge_path}")
            
            print(f"传递给脚本的环境变量 GAIA_WORK_DIR: {env['GAIA_WORK_DIR']}")
            print(f"当前 PATH 包含: {env.get('PATH', '')[:200]}...")
            
            # 测试脚本是否可以执行（先试试help参数）
            print(f"测试脚本可执行性...")
            if not script_path.exists():
                self.update_status(f"❌ 脚本文件不存在: {script_path}")
                self.root.after(0, lambda: messagebox.showerror("错误", f"脚本文件不存在:\n{script_path}"))
                return
            
            # 跨平台脚本执行
            if sys.platform == "win32":
                # Windows需要通过bash或Git Bash执行.sh脚本
                bash_paths = [
                    "C:\\Program Files\\Git\\bin\\bash.exe",
                    "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
                    "bash"  # 如果bash在PATH中
                ]
                
                bash_exe = None
                for bash_path in bash_paths:
                    try:
                        result_test = subprocess.run([bash_path, "--version"], 
                                                   capture_output=True, text=True, timeout=5)
                        if result_test.returncode == 0:
                            bash_exe = bash_path
                            break
                    except:
                        continue
                
                if bash_exe:
                    unix_script_path = str(script_path).replace('\\', '/').replace('C:', '/c')
                    cmd = [bash_exe, unix_script_path, command]
                else:
                    self.update_status("❌ Windows系统需要安装Git Bash来运行脚本")
                    self.root.after(0, lambda: messagebox.showerror("错误", 
                        "Windows系统需要安装Git Bash来运行shell脚本。\n请安装Git for Windows。"))
                    return
            else:
                # macOS/Linux直接执行
                if script_path.exists():
                    import stat
                    script_path.chmod(script_path.stat().st_mode | stat.S_IEXEC)
                
                cmd = [str(script_path), command]
            
            # 实时执行并输出
            self.root.after(0, lambda: self.append_mgmt_log(f"📋 执行命令: {' '.join(cmd)}"))
            
            # 检查配置文件状态
            config_file_path = self.script_dir / "nodes_config.json"
            if config_file_path.exists():
                self.root.after(0, lambda: self.append_mgmt_log(f"✅ 配置文件存在: {config_file_path}"))
                try:
                    with open(config_file_path, 'r', encoding='utf-8') as f:
                        config_content = f.read()
                    self.root.after(0, lambda: self.append_mgmt_log(f"📄 配置文件大小: {len(config_content)} 字节"))
                    # 显示配置文件的前200个字符
                    preview = config_content[:200] + "..." if len(config_content) > 200 else config_content
                    self.root.after(0, lambda: self.append_mgmt_log(f"📄 配置文件预览: {preview}"))
                except Exception as e:
                    self.root.after(0, lambda: self.append_mgmt_log(f"❌ 读取配置文件失败: {e}"))
            else:
                self.root.after(0, lambda: self.append_mgmt_log(f"❌ 配置文件不存在: {config_file_path}"))
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # 合并stderr到stdout
                universal_newlines=True,
                bufsize=1,
                env=env
            )
            
            # 实时读取输出
            output_lines = []
            while True:
                line = process.stdout.readline()
                if line:
                    line = line.rstrip('\n\r')
                    output_lines.append(line)
                    # 实时显示到日志
                    self.root.after(0, lambda l=line: self.append_mgmt_log(f"    {l}"))
                elif process.poll() is not None:
                    break
            
            # 等待进程完成
            return_code = process.wait()
            
            self.update_status(f"命令 '{command}' 执行完成")
            
            output = '\n'.join(output_lines)
            
            # 判断执行结果
            if return_code != 0 and not output.strip():
                if command == 'stop' and return_code == 1:
                    output = "🛑 停止操作完成\n💡 返回码1通常表示没有运行的节点需要停止，这是正常情况。"
                    success = True
                else:
                    output = f"脚本执行失败（返回码: {return_code}）\n\n可能的原因：\n1. 脚本内部发生了错误但没有输出\n2. 脚本权限问题\n3. 脚本依赖的命令不存在"
                    success = False
            else:
                success = return_code == 0
                
            # 记录最终结果到日志
            status_icon = "✅" if success else "❌"
            self.root.after(0, lambda: self.append_mgmt_log(f"{status_icon} 命令 '{command}' {'执行成功' if success else '执行失败'}"))
            
            # 仍然显示详细结果窗口
            self.root.after(0, lambda: self.show_command_result(command, output, success))
            
        except Exception as e:
            self.update_status(f"❌ 命令执行异常: {str(e)}")
            self.root.after(0, lambda: self.append_mgmt_log(f"❌ 执行异常: {str(e)}"))
            self.root.after(0, lambda: messagebox.showerror("错误", f"命令执行异常:\n{str(e)}"))
            
    def show_command_result(self, command, output, success):
        """显示命令执行结果"""
        title = f"命令执行结果: {command}"
        
        # 注意：输出已经实时显示在管理日志中了，这里只显示详细窗口
        
        # 无论成功失败，都使用详细窗口显示结果
        if len(output) > 200 or '\n' in output:
            self.show_detailed_result(title, output, success)
        else:
            if success:
                messagebox.showinfo(title, f"✅ 执行成功!\n\n{output}")
            else:
                messagebox.showerror(title, f"❌ 执行失败!\n\n{output}")
    
    def show_detailed_result(self, title, content, success):
        """显示详细结果窗口"""
        result_window = tk.Toplevel(self.root)
        result_window.title(title)
        result_window.geometry("900x700")
        result_window.resizable(True, True)
        
        # 状态标题
        status_frame = ttk.Frame(result_window)
        status_frame.pack(fill=tk.X, padx=10, pady=5)
        
        status_text = "✅ 执行成功!" if success else "❌ 执行失败!"
        status_color = "green" if success else "red"
        status_label = ttk.Label(status_frame, text=status_text, font=('Arial', 12, 'bold'))
        status_label.pack(anchor=tk.W)
        
        # 创建滚动文本框
        text_frame = ttk.Frame(result_window)
        text_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        result_text = scrolledtext.ScrolledText(text_frame, wrap=tk.WORD, font=('Monaco', 11))
        result_text.pack(fill=tk.BOTH, expand=True)
        result_text.insert(tk.END, content)
        result_text.config(state=tk.DISABLED)
        
        # 按钮框架
        btn_frame = ttk.Frame(result_window)
        btn_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Button(btn_frame, text="关闭", command=result_window.destroy).pack(side=tk.RIGHT, padx=5)
        ttk.Button(btn_frame, text="复制内容", command=lambda: self.copy_to_clipboard(content)).pack(side=tk.RIGHT, padx=5)
        
        # 将窗口置于前台
        result_window.lift()
        result_window.focus_force()
    
    def copy_to_clipboard(self, text):
        """复制文本到剪贴板"""
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        messagebox.showinfo("成功", "内容已复制到剪贴板")
    
    def clear_mgmt_log(self):
        """清空管理日志"""
        self.mgmt_log_text.delete(1.0, tk.END)
        self.append_mgmt_log("📋 日志已清空")
    
    def save_mgmt_log(self):
        """保存管理日志"""
        content = self.mgmt_log_text.get(1.0, tk.END)
        if not content.strip():
            messagebox.showwarning("警告", "日志为空，无需保存")
            return
            
        from datetime import datetime
        filename = f"management_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        file_path = filedialog.asksaveasfilename(
            title="保存管理日志",
            defaultextension=".txt",
            initialname=filename,
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        
        if file_path:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                messagebox.showinfo("成功", f"日志已保存到: {file_path}")
            except Exception as e:
                messagebox.showerror("错误", f"保存失败: {str(e)}")
    
    def copy_mgmt_log(self):
        """复制管理日志"""
        content = self.mgmt_log_text.get(1.0, tk.END)
        if not content.strip():
            messagebox.showwarning("警告", "日志为空，无法复制")
            return
        self.copy_to_clipboard(content)
    
    def append_mgmt_log(self, message):
        """添加消息到管理日志"""
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] {message}\n"
        
        self.mgmt_log_text.insert(tk.END, formatted_message)
        
        # 自动滚动到底部
        if self.auto_scroll_mgmt.get():
            self.mgmt_log_text.see(tk.END)
            
        # 限制日志长度，保留最近1000行
        lines = self.mgmt_log_text.get(1.0, tk.END).split('\n')
        if len(lines) > 1000:
            self.mgmt_log_text.delete(1.0, f"{len(lines)-1000}.0")
        
        self.mgmt_log_text.update_idletasks()
    
    def append_install_log(self, message):
        """添加消息到安装日志"""
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] {message}\n"
        
        self.install_log_text.insert(tk.END, formatted_message)
        
        # 自动滚动到底部
        if self.auto_scroll_install.get():
            self.install_log_text.see(tk.END)
            
        # 限制日志长度，保留最近1000行
        lines = self.install_log_text.get(1.0, tk.END).split('\n')
        if len(lines) > 1000:
            self.install_log_text.delete(1.0, f"{len(lines)-1000}.0")
        
        self.install_log_text.update_idletasks()
    
    def clear_install_log(self):
        """清空安装日志"""
        self.install_log_text.delete(1.0, tk.END)
        self.append_install_log("📋 安装日志已清空")
    
    def save_install_log(self):
        """保存安装日志"""
        content = self.install_log_text.get(1.0, tk.END)
        if not content.strip():
            messagebox.showwarning("警告", "日志为空，无需保存")
            return
            
        from datetime import datetime
        filename = f"install_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        file_path = filedialog.asksaveasfilename(
            title="保存安装日志",
            defaultextension=".txt",
            initialname=filename,
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        
        if file_path:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                messagebox.showinfo("成功", f"安装日志已保存到: {file_path}")
            except Exception as e:
                messagebox.showerror("错误", f"保存失败: {str(e)}")
    
    def copy_install_log(self):
        """复制安装日志"""
        content = self.install_log_text.get(1.0, tk.END)
        if not content.strip():
            messagebox.showwarning("警告", "日志为空，无法复制")
            return
        self.copy_to_clipboard(content)
    
    def show_detailed_error(self, title, error_msg):
        """显示详细错误信息窗口"""
        error_window = tk.Toplevel(self.root)
        error_window.title(title)
        error_window.geometry("800x600")
        error_window.resizable(True, True)
        
        # 创建滚动文本框
        text_frame = ttk.Frame(error_window)
        text_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        error_text = scrolledtext.ScrolledText(text_frame, wrap=tk.WORD, font=('Courier', 10))
        error_text.pack(fill=tk.BOTH, expand=True)
        error_text.insert(tk.END, error_msg)
        error_text.config(state=tk.DISABLED)
        
        # 添加关闭按钮
        ttk.Button(error_window, text="关闭", command=error_window.destroy).pack(pady=10)
            
    # 状态管理方法
    def refresh_status(self):
        """刷新系统状态"""
        if self.is_running:
            return
            
        self.run_async_operation("获取系统状态中...", self._refresh_status)
        
    def _refresh_status(self):
        """执行状态刷新"""
        try:
            script_path = self.script_dir / "check_system_status.sh"
            
            # 调试信息
            print(f"查找状态脚本: {script_path}")
            print(f"脚本存在: {script_path.exists()}")
            
            if not script_path.exists():
                error_msg = f"状态检查脚本不存在:\n{script_path}\n\n脚本目录: {self.script_dir}\n目录内容: {list(self.script_dir.glob('*')) if self.script_dir.exists() else '目录不存在'}"
                self.root.after(0, lambda: self.update_status_display(error_msg))
                return
            
            result = subprocess.run([str(script_path), "full"], 
                                  capture_output=True, text=True)
            
            output = result.stdout if result.returncode == 0 else result.stderr
            
            # 更新状态显示
            self.root.after(0, lambda: self.update_status_display(output))
            
        except Exception as e:
            error_msg = f"获取系统状态失败:\n{str(e)}"
            self.root.after(0, lambda: self.update_status_display(error_msg))
            
    def update_status_display(self, content):
        """更新状态显示"""
        self.status_text.delete(1.0, tk.END)
        self.status_text.insert(1.0, content)
        
        # 如果包含系统状态信息，添加解释
        if "节点服务状态" in content and "主节点" in content and "异常" in content:
            explanation = "\n\n" + "="*50 + "\n"
            explanation += "📊 状态解释说明:\n"
            explanation += "• 主节点异常是正常现象 - 本系统使用共享服务架构\n"
            explanation += "• 关注要点：共享服务状态 + 从节点状态\n"
            explanation += "• 从节点正常运行即表示系统工作正常\n"
            explanation += "• 内存节省显示了共享架构的优势\n"
            explanation += "="*50
            self.status_text.insert(tk.END, explanation)
        
        self.status_text.see(1.0)
        
    def quick_health_check(self):
        """快速健康检查"""
        if self.is_running:
            return
            
        self.run_async_operation("快速健康检查中...", self._quick_health_check)
        
    def _quick_health_check(self):
        """执行快速健康检查"""
        try:
            script_path = self.script_dir / "check_system_status.sh"
            result = subprocess.run([str(script_path), "quick"], 
                                  capture_output=True, text=True)
            
            output = result.stdout if result.returncode == 0 else result.stderr
            self.root.after(0, lambda: messagebox.showinfo("健康检查结果", output))
            
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("错误", f"健康检查失败:\n{str(e)}"))
            
    def fix_common_issues(self):
        """修复常见问题"""
        if self.is_running:
            messagebox.showwarning("警告", "有操作正在进行中，请稍候...")
            return
            
        result = messagebox.askyesno("确认", "这将尝试修复系统的常见问题，是否继续？")
        if result:
            self.run_async_operation("修复问题中...", self._fix_common_issues)
            
    def _fix_common_issues(self):
        """执行问题修复"""
        try:
            script_path = self.script_dir / "check_system_status.sh"
            result = subprocess.run([str(script_path), "fix"], 
                                  capture_output=True, text=True)
            
            output = result.stdout if result.returncode == 0 else result.stderr
            self.root.after(0, lambda: messagebox.showinfo("修复结果", output))
            
            # 自动刷新状态
            self.root.after(1000, self.refresh_status)
            
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("错误", f"修复失败:\n{str(e)}"))
            
    def toggle_auto_refresh(self):
        """切换自动刷新"""
        if self.auto_refresh.get():
            self.auto_refresh_status()
        else:
            if hasattr(self, 'refresh_timer'):
                self.root.after_cancel(self.refresh_timer)
                
    def auto_refresh_status(self):
        """自动刷新状态"""
        if self.auto_refresh.get():
            self.refresh_status()
            self.refresh_timer = self.root.after(30000, self.auto_refresh_status)
            
    # 日志管理方法
    def update_log_node_list(self):
        """更新日志节点列表"""
        nodes = ["主节点 (gaianet)"]
        for node in self.nodes_config:
            nodes.append(f"{node['name']} ({node['port']})")
            
        self.log_node_combo['values'] = nodes
        if nodes:
            self.log_node_combo.current(0)
            
    def load_node_log(self):
        """加载节点日志"""
        selected = self.log_node_var.get()
        if not selected:
            messagebox.showwarning("警告", "请选择要查看的节点")
            return
            
        try:
            if "主节点" in selected:
                log_dir = os.path.expanduser("~/gaianet/log")
            else:
                # 解析节点名
                node_name = selected.split()[0]
                for node in self.nodes_config:
                    if node['name'] == node_name:
                        log_dir = self.expand_path(node['base_dir']) + "/log"
                        break
                else:
                    messagebox.showerror("错误", "未找到对应的节点配置")
                    return
                    
            if not os.path.exists(log_dir):
                messagebox.showwarning("警告", f"日志目录不存在: {log_dir}")
                return
                
            # 查找最新的日志文件
            log_files = []
            for file in os.listdir(log_dir):
                if file.endswith('.log'):
                    log_files.append(os.path.join(log_dir, file))
                    
            if not log_files:
                messagebox.showwarning("警告", "未找到日志文件")
                return
                
            # 选择最新的日志文件
            latest_log = max(log_files, key=os.path.getmtime)
            
            # 读取日志内容
            with open(latest_log, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            # 显示日志
            self.log_text.delete(1.0, tk.END)
            self.log_text.insert(1.0, content)
            self.log_text.see(tk.END)  # 滚动到底部
            
        except Exception as e:
            messagebox.showerror("错误", f"加载日志失败:\n{str(e)}")
            
    def open_log_directory(self):
        """打开日志目录"""
        selected = self.log_node_var.get()
        if not selected:
            messagebox.showwarning("警告", "请选择要查看的节点")
            return
            
        try:
            if "主节点" in selected:
                log_dir = os.path.expanduser("~/gaianet/log")
            else:
                node_name = selected.split()[0]
                for node in self.nodes_config:
                    if node['name'] == node_name:
                        log_dir = self.expand_path(node['base_dir']) + "/log"
                        break
                else:
                    messagebox.showerror("错误", "未找到对应的节点配置")
                    return
                    
            if os.path.exists(log_dir):
                subprocess.run(["open", log_dir])  # macOS
            else:
                messagebox.showwarning("警告", f"日志目录不存在: {log_dir}")
                
        except Exception as e:
            messagebox.showerror("错误", f"打开目录失败:\n{str(e)}")
            
    def clear_log_display(self):
        """清空日志显示"""
        self.log_text.delete(1.0, tk.END)
        
    # 工具方法
    def run_async_operation(self, message, operation, *args):
        """运行异步操作"""
        if self.is_running:
            return
            
        self.is_running = True
        self.progress_var.set(message)
        self.progress_bar.start()
        self.update_status(message)
        
        # 记录操作开始到管理日志
        self.append_mgmt_log(f"🚀 开始操作: {message}")
        
        def worker():
            try:
                operation(*args)
            finally:
                self.root.after(0, self.operation_complete)
                
        threading.Thread(target=worker, daemon=True).start()
        
    def operation_complete(self):
        """操作完成"""
        self.is_running = False
        self.progress_bar.stop()
        self.progress_var.set("就绪")
        
    def update_status(self, message):
        """更新状态"""
        self.status_var.set(message)
        self.root.update_idletasks()

def main():
    """主函数"""
    # 创建主窗口
    root = tk.Tk()
    
    # 设置跨平台样式
    if sys.platform == 'darwin':  # macOS特定设置
        root.option_add('*tearOff', False)
    
    # 创建应用
    app = GaiaNetGUI(root)
    
    # 启动主循环
    root.mainloop()

if __name__ == "__main__":
    main()