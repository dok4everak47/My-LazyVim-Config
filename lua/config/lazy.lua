-- Bootstrap lazy.nvim + LazyVim (lua/config/lazy.lua)
-- 结构对齐 LazyVim starter：init.lua 只 require 本文件
-- 本文件在 lazy.setup 前配置好 rtp，随后加载 LazyVim 及所有 spec。
-- lua/config/options.lua / keymaps.lua / autocmds.lua 由 lazy.nvim 自动加载
-- （options 在 setup 前，keymaps/autocmds 在 VeryLazy）

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- 引入 LazyVim 及其默认插件集；colorscheme 用你原本的 catppuccin
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",
      opts = {
        -- 主题: 默认 Oxocarbon (2026-09-05; kanagawa-dragon → oxocarbon, IBM 碳黑风)。
        -- 在 dashboard 里用 "Theme" 项 (键 t) 换过的主题记在 state 文件里, 由
        -- config/theme.lua 恢复 (换过的主题装不上时自动回默认)。
        colorscheme = function()
          vim.cmd.colorscheme(require("config.theme").startup())
        end,
      },
    },
    -- 可选 extras（对齐原 AstroNvim 功能面）
    -- 注意: edgy 必须在 aerial 之前 import (edgy 注册布局, aerial 等窗口型插件依赖其顺序)
    { import = "lazyvim.plugins.extras.ui.edgy" }, -- Edgy 侧栏窗口管理 (2026-09-05; 先于 aerial)
    { import = "lazyvim.plugins.extras.ui.treesitter-context" }, -- 顶部冻结当前函数/块上下文 (VS Code 粘滞滚动风, 2026-09-05)
    { import = "lazyvim.plugins.extras.editor.aerial" }, -- Aerial 大纲
    { import = "lazyvim.plugins.extras.editor.neo-tree" }, -- neo-tree 文件树
    { import = "lazyvim.plugins.extras.coding.luasnip" }, -- LuaSnip 引擎 + friendly-snippets（blink 后端）
    { import = "lazyvim.plugins.extras.lang.elm" }, -- Elm (LSP/treesitter/format)
    { import = "lazyvim.plugins.extras.lang.nix" }, -- Nix (nil_ls/treesitter)
    { import = "lazyvim.plugins.extras.lang.python" }, -- Python (basedpyright/ruff/venv)
    { import = "lazyvim.plugins.extras.lang.clangd" }, -- C/C++ (clangd + clangd_extensions)
    { import = "lazyvim.plugins.extras.lang.typescript" }, -- TS/JS (vtsls)
    { import = "lazyvim.plugins.extras.lang.rust" }, -- Rust (rustaceanvim + rust-analyzer, devShell 提供)
    { import = "lazyvim.plugins.extras.dap.core" }, -- 调试核心
    { import = "lazyvim.plugins.extras.coding.mini-surround" }, -- mini.surround 环绕编辑 (gsa/gsd/gsr, 2026-09-05)
    -- 本地用户插件
    { import = "plugins" },
  },
  defaults = {
    lazy = false, -- 自定义插件默认立即加载（starter 同款；LazyVim 插件仍懒加载）
    version = false,
  },
  install = { colorscheme = { "oxocarbon", "habamax" } },
  checker = { enabled = false }, -- 关自动更新检查（保持可手动 :Lazy update）
  performance = {
    cache = { enabled = true },
    rtp = {
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
})
