-- LazyVim 迁移（AstroNvim → LazyVim）
-- 引导入口：只负责加载 config/lazy.lua（内含 lazy.nvim 安装 + LazyVim spec）
--
-- 终端 nvim 与 VS Code（vscode-neovim）共用同一份配置：
-- vscode-neovim 里 nvim 正常加载本文件 → 完整 LazyVim 在 VS Code 里同样生效。
-- 个别插件在 VS Code 里需要差异化时，用 vim.g.vscode 在其 spec 里做小开关。
require("config.lazy")
