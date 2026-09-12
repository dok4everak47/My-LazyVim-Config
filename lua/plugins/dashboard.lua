-- Snacks dashboard 高亮 (2026-09-05)
-- 1) 修复: kanagawa 的 `hi clear` 清掉 SnacksDashboard* 组 → ColorScheme 后重建链接。
-- 2) LAZYVIM 标题(header)显式红色 #E82424 (用户要求, kanagawa samuraiRed)。
--    在 SnacksDashboardOpened 时再强制设一次: dashboard 模块加载(set_hl default=true)
--    可能覆盖 ColorScheme 时设的值, 打开后设最可靠。
local function apply_dashboard_hl()
  -- 标题红色 (显式色值, 不链接)
  pcall(vim.api.nvim_set_hl, 0, "SnacksDashboardHeader", { fg = "#E82424", default = true })
  pcall(vim.api.nvim_set_hl, 0, "SnacksDashboardHeaderIcon", { fg = "#E82424", default = true })
  -- dashboard 窗口背景透明: bg = "none" 让终端默认背景透出来
  -- (Kaku window_background_opacity=0.75; wezterm 把 app 显式设的 bg 当"非默认背景色",
  --  用 text_background_opacity=1.0 不透明绘制, 所以必须留空 bg 才有半透明效果)
  local n = vim.api.nvim_get_hl(0, { name = "Normal" })
  pcall(vim.api.nvim_set_hl, 0, "SnacksDashboardNormal", { fg = n.fg, bg = "none" })
  -- 其余组链接到主题通用高亮
  local map = {
    SnacksDashboardFooter = "Comment",
    SnacksDashboardDesc = "Comment",
    SnacksDashboardKey = "Number",
    SnacksDashboardIcon = "Special",
    SnacksDashboardTitle = "Title",
    SnacksDashboardButton = "Normal",
    SnacksDashboardTerminal = "NormalFloat",
  }
  for group, link in pairs(map) do
    pcall(vim.api.nvim_set_hl, 0, group, { link = link, default = true })
  end
end

-- 换主题后重建
vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Re-link Snacks dashboard highlights after colorscheme",
  callback = apply_dashboard_hl,
})

-- dashboard 打开后强制应用 (防 dashboard 模块自身 set_hl 覆盖)
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardOpened",
  desc = "Force Snacks dashboard header red + relink groups",
  callback = apply_dashboard_hl,
})

return {
  {
    "snacks.nvim",
    optional = true,
    opts = function()
      -- 确保 dashboard 打开时上面 autocmd 已注册 (snacks 加载即可)
    end,
  },
}
