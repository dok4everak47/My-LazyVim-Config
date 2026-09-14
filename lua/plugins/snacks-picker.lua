-- Snacks.picker 微调：常用文件频次排序 (frecency)
-- 参考 Sam Natale 配置里的 "fre" 插件 (2026-09-14)
-- 现状: snacks 全局 matcher.frecency 默认 false，只有 smart/projects 两个源自带开启，
--       files/recent 没开 → <leader>ff / <leader>fr 的排序不会把常打开的文件顶上来。
-- 本文件只给这两个源开 frecency，不改动其它 picker 行为。
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      for _, src in ipairs({ "files", "recent" }) do
        opts.picker.sources[src] = opts.picker.sources[src] or {}
        opts.picker.sources[src].matcher = opts.picker.sources[src].matcher or {}
        opts.picker.sources[src].matcher.frecency = true
      end
    end,
  },
}
