-- quicker.nvim：quickfix 窗口增强（参考 Sam Natale 配置）
-- 改进项：语法高亮 / 上下文行展开 / 整个 quickfix 当可编辑 buffer（改完 :w 批量写回多个文件）
-- 只管 qf buffer 的显示与行为，不抢任何键；trouble（<leader>xq / <leader>xQ）走自己的 buffer，不受影响。
return {
  {
    "stevearc/quicker.nvim",
    ft = "qf",
    opts = {
      keys = {
        {
          ">",
          function()
            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
          end,
          desc = "Expand quickfix context",
        },
        { "<", function() require("quicker").collapse() end, desc = "Collapse quickfix context" },
      },
    },
  },
}
