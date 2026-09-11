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

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    name = "oxocarbon",
    lazy = false,
    priority = 1000,
  },
}
