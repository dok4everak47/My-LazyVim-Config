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
    opts = function(_, opts)
      -- dashboard 加 "Theme" 项 (2026-09-16): 打开 snacks 配色 picker (实时预览)
      -- snacks/lazy 的 opts 合并是按 key 递归并, 数组是「按索引并」→ 直接换掉整个 keys 会
      -- 残留 LazyVim 的多余项, 所以这里往 LazyVim 那份列表里插, 不重写。
      local keys = vim.tbl_get(opts or {}, "dashboard", "preset", "keys")
      if type(keys) ~= "table" then
        return
      end
      for _, item in ipairs(keys) do
        if item.key == "t" or item.desc == "Theme" then
          return -- 已经加过 (opts 函数重复执行时不重复插入)
        end
      end
      local pos = #keys + 1
      for i, item in ipairs(keys) do
        if item.key == "q" then -- 排在 Quit 前面
          pos = i
          break
        end
      end
      table.insert(keys, pos, {
        icon = "󰏘 ",
        key = "t",
        desc = "Theme",
        action = function()
          require("config.theme").pick()
        end,
      })
      -- 上面 autocmd 的注册时机: snacks 一加载就注册 (本 spec lazy=false 的默认),
      -- dashboard 打开时必然已经在。
    end,
  },
}
