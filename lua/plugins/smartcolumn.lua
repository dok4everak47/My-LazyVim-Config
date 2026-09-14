-- smartcolumn.nvim：只在行宽超过 colorcolumn 时才画竖线（参考 Sam Natale 配置）
-- 之前 colorcolumn 完全没设（LazyVim 默认不管），超宽没有任何视觉提示。
-- scope = "window"：只看当前窗口可见部分是否超宽（比 "file" 更少打扰，
--   适合本配置 opt.wrap = true 的自动折行习惯）。
-- disabled_filetypes：非代码类/UI 类 buffer 不画线。
return {
  {
    "m4xshen/smartcolumn.nvim",
    opts = {
      colorcolumn = "80",
      scope = "window",
      disabled_filetypes = {
        "help",
        "text",
        "markdown",
        "lazy",
        "mason",
        "noice",
        "Trouble",
        "snacks_dashboard",
        "snacks_picker_input",
        "neo-tree",
        "aerial",
        "Avante",
        "qf",
        "gitcommit",
      },
    },
  },
}
