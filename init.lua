-- LazyVim 迁移（AstroNvim → LazyVim）
-- 引导入口：只负责加载 config/lazy.lua（内含 lazy.nvim 安装 + LazyVim spec）
--
-- 终端 nvim 与 VS Code（vscode-neovim）共用同一份配置：
-- vscode-neovim 里 nvim 正常加载本文件 → 完整 LazyVim 在 VS Code 里同样生效。
-- 个别插件在 VS Code 里需要差异化时，用 vim.g.vscode 在其 spec 里做小开关。
--
-- 先做 devShell 自举（把当前项目的 flake 环境并进 PATH），再加载 lazy：
-- 顺序不能反 —— lsp.lua 的 gopls 路径解析、conform/nvim-lint 的工具判定
-- 都在 lazy.setup 期就把结果定下来了（见 lua/config/devshell.lua）。
require("config.devshell")
require("config.lazy")
