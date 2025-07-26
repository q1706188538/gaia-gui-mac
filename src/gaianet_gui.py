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
        self.root.title("GaiaNet多节点部署管理器 v1.0")
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
            else:
                # Windows/Linux打包环境
                self.script_dir = Path(sys.executable).parent / "scripts"
        else:
            # 开发环境
            self.script_dir = Path(__file__).parent
        
        # 调试信息：输出脚本目录
        print(f"脚本目录: {self.script_dir}")
        print(f"脚本目录是否存在: {self.script_dir.exists()}")
        if self.script_dir.exists():
            print(f"脚本目录内容: {list(self.script_dir.glob('*'))}")
        
        self.nodes_config = []
        self.is_running = False
        
        # 创建界面
        self.create_widgets()
        self.load_default_config()
        
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
        
        # 安装按钮
        install_btn_frame = ttk.Frame(main_node_frame)
        install_btn_frame.grid(row=2, column=0, columnspan=3, pady=10)
        
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
        
        # 初始加载状态
        self.refresh_status()
        
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
        ttk.Label(status_frame, text="v1.0").pack(side=tk.RIGHT, padx=5)
        
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
            install_script = """
#!/bin/bash
set -e

# 下载并运行官方安装脚本
curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash
            """
            
            cmd = ["bash", "-c", install_script]
            if self.reinstall_var.get():
                cmd = ["bash", "-c", install_script + " --reinstall"]
                
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.path.expanduser("~"))
            
            if result.returncode == 0:
                self.update_status("✅ 主节点安装成功！")
                messagebox.showinfo("成功", "主节点安装完成！\n\n现在可以配置从节点并进行部署。")
            else:
                self.update_status(f"❌ 主节点安装失败: {result.stderr}")
                messagebox.showerror("错误", f"安装失败:\n{result.stderr}")
                
        except Exception as e:
            self.update_status(f"❌ 安装异常: {str(e)}")
            messagebox.showerror("错误", f"安装过程中发生异常:\n{str(e)}")
            
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
        """加载默认配置"""
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
        
    def update_tree(self):
        """更新节点列表显示"""
        # 清空现有项目
        for item in self.tree.get_children():
            self.tree.delete(item)
            
        # 添加节点
        for i, node in enumerate(self.nodes_config):
            self.tree.insert('', 'end', iid=i, text=str(i+1), values=(
                node['name'],
                node['base_dir'],
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
            
    def on_node_select(self, event):
        """节点选择事件"""
        selection = self.tree.selection()
        if selection:
            index = int(selection[0])
            node = self.nodes_config[index]
            
            # 更新表单
            self.node_name_var.set(node['name'])
            self.node_path_var.set(node['base_dir'])
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
                
        # 更新配置
        self.nodes_config[index] = {
            "name": self.node_name_var.get(),
            "base_dir": self.node_path_var.get(),
            "port": port,
            "local_only": self.node_local_only_var.get(),
            "force_rag": self.node_force_rag_var.get(),
            "auto_start": self.node_auto_start_var.get()
        }
        
        self.update_tree()
        messagebox.showinfo("成功", "节点配置已保存")
        
    def reset_node_form(self):
        """重置表单"""
        self.node_name_var.set("")
        self.node_path_var.set("")
        self.node_port_var.set(8081)
        self.node_local_only_var.set(False)
        self.node_force_rag_var.set(True)
        self.node_auto_start_var.set(True)
        
    def save_config_file(self):
        """保存配置文件"""
        config = {
            "shared_services": {
                "chat_port": 9000,
                "embedding_port": 9001,
                "auto_start": True
            },
            "nodes": self.nodes_config
        }
        
        config_path = self.script_dir / "nodes_config.json"
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
            
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
                    messagebox.showinfo("成功", "配置导入成功")
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
            
            # 跨平台脚本执行
            if sys.platform == "win32":
                # Windows需要通过bash或Git Bash执行.sh脚本
                # 首先检查是否有Git Bash
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
                    # 将Windows路径转换为Unix风格路径给bash使用
                    unix_script_path = str(script_path).replace('\\', '/').replace('C:', '/c')
                    result = subprocess.run([bash_exe, unix_script_path, command], 
                                          capture_output=True, text=True)
                else:
                    # 如果没有bash，显示提示信息
                    self.update_status("❌ Windows系统需要安装Git Bash来运行脚本")
                    self.root.after(0, lambda: messagebox.showerror("错误", 
                        "Windows系统需要安装Git Bash来运行shell脚本。\n请安装Git for Windows。"))
                    return
            else:
                # macOS/Linux直接执行
                result = subprocess.run([str(script_path), command], 
                                      capture_output=True, text=True)
            
            self.update_status(f"命令 '{command}' 执行完成")
            
            # 显示结果
            output = result.stdout if result.returncode == 0 else result.stderr
            self.root.after(0, lambda: self.show_command_result(command, output, result.returncode == 0))
            
        except Exception as e:
            self.update_status(f"❌ 命令执行异常: {str(e)}")
            self.root.after(0, lambda: messagebox.showerror("错误", f"命令执行异常:\n{str(e)}"))
            
    def show_command_result(self, command, output, success):
        """显示命令执行结果"""
        title = f"命令执行结果: {command}"
        if success:
            messagebox.showinfo(title, f"✅ 执行成功!\n\n{output[:1000]}...")
        else:
            # 显示更详细的错误信息
            error_msg = f"❌ 执行失败!\n\n脚本目录: {self.script_dir}\n脚本存在: {(self.script_dir / 'deploy_multinode_advanced.sh').exists()}\n\n错误输出:\n{output[:1000]}..."
            messagebox.showerror(title, error_msg)
            
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
                        log_dir = os.path.expanduser(node['base_dir'].replace('$HOME', '~') + "/log")
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
                        log_dir = os.path.expanduser(node['base_dir'].replace('$HOME', '~') + "/log")
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