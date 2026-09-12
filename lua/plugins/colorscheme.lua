-- Oxocarbon 主题 (2026-09-05, nyoom-engineering/oxocarbon.nvim)
-- IBM 碳黑风: dark 背景 (oxocarbon 默认; 也是 nyoom.nvim 用的主题)
-- oxocarbon 支持 vim.o.background = dark/light 切换 (默认 dark, 无需配置)
-- ⚠️ 不给 opts: oxocarbon 无 setup() 函数, LazyVim 遇 opts 会调 require().setup → nil 报错。
-- 纯 colorscheme 插件, lazy=false + LazyVim opts.colorscheme="oxocarbon" 即可自动加载。
--
-- 语法高亮 (2026-09-11): 全走 oxocarbon 原生默认色, 不再做自定义覆盖。
--   (2026-09-05 曾在这里用 ColorScheme autocmd 覆盖 variable/function/keyword/
--    boolean/constant 五类颜色; 2026-09-11 用户要求恢复默认, 整块已删。)
--   原生默认参考 (dark): @variable/@parameter/Identifier=#d0d0d0 灰
--     @function=#ff7eb6 粉 + bold, Function=#3ddbd9 青
--     @keyword/Keyword/Boolean=#78a9ff 蓝, @constant=#be95ff 紫,
--     @constant.builtin=#08bdba 青
--   恢复自定义只需再加一个 ColorScheme autocmd (见 git 历史 d0eb363 之前的版本)。
--
-- 2026-09-12 (用户指定): 变量家族 → #1DA812 (亮绿);
--   LspInlayHint → #565656 + italic (oxocarbon 未给该组设色, 默认落成 #d0d0d0 白字,
--   改暗灰+斜体以区分"编辑器虚拟文本")。
--   ⚠️ nvim_set_hl 是整组替换非合并: 这里逐组取现有 def, 显式带上 bold/italic/underline
--   等属性再设, 避免把 @function 类组的粗体弄丢 (变量家族原本无 bold, 但稳妥起见统一保留)。

local function recolor_oxocarbon()
  if vim.g.colors_name ~= "oxocarbon" then return end
  local set = vim.api.nvim_set_hl
  local get = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) or {} end

  -- 变量/标识符家族 (treesitter + LSP + legacy, capture 与 link target 都设)
  local var_color = "#1DA812"
  local var_groups = {
    "@variable", "@variable.builtin", "@variable.parameter", "@variable.parameter.builtin",
    "@variable.member", "@field", "@parameter",
    "@lsp.type.variable", "@lsp.type.parameter", "@lsp.type.selfKeyword", "@lsp.type.selfParameter",
    "@lsp.typemod.variable.defaultLibrary", "@lsp.typemod.variable.injected",
    "Identifier",
  }
  for _, g in ipairs(var_groups) do
    local d = get(g)
    set(0, g, {
      fg = var_color,
      bg = d.bg,
      bold = d.bold, italic = d.italic, underline = d.underline,
      undercurl = d.undercurl, strikethrough = d.strikethrough,
    })
  end

  -- inlay hint 虚拟文本: 暗灰斜体 (无 bg, 跟随 Normal 背景)
  set(0, "LspInlayHint", { fg = "#565656", italic = true })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "oxocarbon: variables #1DA812, inlay hints #565656 italic",
  callback = recolor_oxocarbon,
})

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    name = "oxocarbon",
    lazy = false,
    priority = 1000,
  },
}
