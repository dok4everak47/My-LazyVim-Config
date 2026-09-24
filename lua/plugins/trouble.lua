-- trouble.nvim：诊断/引用/symbols/quickfix 面板（LazyVim 默认 spec 在 lazyvim/plugins/editor.lua，键位 <leader>xx <leader>xX <leader>cs <leader>cS <leader>xL <leader>xQ）
-- 这里只改窗口选项：长路径/长消息自动折行换行显示，不被右侧栏宽截断
-- trouble 内部对非 main 窗口硬编码了 wo.wrap = false 作为 minimal 默认值，
-- 而用户 opts 在合并顺序里位于 minimal 之后，所以这里能覆盖它（win.wo 是窗口局部选项，逐项 nvim_set_option_value）
return {
  {
    "folke/trouble.nvim",
    opts = {
      -- 全局默认（所有 mode 生效）
      win = { wo = { wrap = true } },
      -- 只想给某几个 mode 开的话，改成：
      -- modes = {
      --   diagnostics = { win = { wo = { wrap = true } } },
      --   qflist      = { win = { wo = { wrap = true } } },
      -- },
    },
  },
}
