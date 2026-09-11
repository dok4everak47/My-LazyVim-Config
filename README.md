# My-LazyVim-Config

个人 Neovim 配置 —— 基于 [LazyVim](https://github.com/LazyVim/LazyVim)（v16），从 AstroNvim v6 迁移而来（2026-09）。

## ✨ 特性

- **LazyVim v16** 完整默认集（blink.cmp 补全、snacks picker/terminal、neo-tree、noice UI、lualine）
- **catppuccin** 主题（mocha）
- **VS Code 风格补全**（blink.cmp）：Tab/CR 接受、ghost_text 灰显预览、preselect 高亮、签名提示、Rust 自动补分号
- 语言支持：**Lua / C/C++ / Python / TypeScript / JSON / HTML / CSS / Elm / Nix**
- 调试（DAP core + Python/C++ adapters）
- 格式化（conform）：Lua=stylua、Nix=alejandra、Elm=elm-format（devShell 优先）、TS=prettierd
- LSP：elmls / nil_ls 走 nix/devShell（非 mason）

## 🗂 目录结构

```
~/.config/nvim
├── init.lua                  # 入口 → require("config.lazy")
└── lua/
    ├── config/
    │   ├── lazy.lua          # lazy.nvim 引导 + LazyVim spec/extras
    │   ├── options.lua       # 全局选项、leader、Cmd+S
    │   ├── keymaps.lua       # 自定义快捷键
    │   └── autocmds.lua      # C/C++/Elm 缩进等
    └── plugins/              # 插件个性化
        ├── blink.lua         # 补全 VS Code 风格
        ├── neo-tree.lua      # 文件树偏好
        ├── conform.lua       # 格式化
        ├── mason.lua         # 工具自动安装
        └── lsp.lua           # elmls/nil_ls 显式路径
```

## 📦 安装

```bash
# 备份旧配置（如有）
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak

# 克隆
git clone https://github.com/dok4everak47/My-LazyVim-Config ~/.config/nvim

# 启动（首次自动装插件）
nvim
```

## 🔑 快捷键（自定义部分）

| 键位 | 功能 |
|---|---|
| `<leader>r` / `<leader>R` | 运行当前文件（终端内运行）——按文件类型（py/cpp/c） |
| `<leader>tf` / `<leader>th` | 终端开在当前文件目录（浮动 / 水平） |
| `<leader>o` | Aerial 大纲 |
| `<leader>fs` | 当前文件符号搜索（VS Code Cmd+Shift+O 风格） |
| `<leader>bn` / `bp` / `bb` / `1-9` | 缓冲区切换 |
| `gi` | LSP 实现跳转 |
| `jk` | 退出插入模式并强制保存（`:w!`，不自动格式化） |
| `Cmd+S` / `Ctrl+S` | 保存（所有模式） |
| `<C-space>` / `<BS>` | Treesitter 增量选择 |

LazyVim 默认快捷键（`<leader>e` 文件树、`<leader>ff` 找文件、`<leader>g` git 等）保持不变，见 [LazyVim 文档](https://www.lazyvim.org/)。

## 🪵 备注

- Neovim 由 nix-darwin 管理（`/run/current-system/sw/bin/nvim`）
- Elm/Nix 工具链（elmls / elm-format / alejandra / nil）由项目 devShell + nix profile 提供，非 mason
- Git 远端：GitHub + Gitea 双推送
