-- nvim-chainsaw：智能插入 log 语句（参考 Sam Natale 配置）
-- Rust 支持实测（插件 log-statements-data.lua）：
--   variableLog/objectLog → println!("{} {}: {:?}", marker, var, var);
--   debugLog → dbg!(&var);   assertLog → assert!(...)   messageLog → println!
-- 注意：Rust 不支持"智能选字段"(只有 lua/python/js/go)，光标在哪取哪个 token。
-- 键位选的是你 n 模式空着的 <leader>l* 段（ll 已被你的循环列表占用，避开）。
return {
  {
    "chrisgrieser/nvim-chainsaw",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      require("chainsaw").setup(opts)
      local map = function(mode, lhs, rhs, desc)
        Snacks.keymap.set(mode, lhs, rhs, { desc = desc })
      end
      map({ "n", "x" }, "<leader>lv", function() require("chainsaw").variableLog() end, "Log 变量值 (println)")
      map("n", "<leader>ld", function() require("chainsaw").debugLog() end, "Debug 语句 (dbg!)")
      map("n", "<leader>la", function() require("chainsaw").assertLog() end, "Assert 语句 (assert!)")
      map("n", "<leader>lm", function() require("chainsaw").messageLog() end, "Log 并输入自定义消息")
      map({ "n", "x" }, "<leader>lr", function() require("chainsaw").removeLogs() end, "删除本 buffer 的 log 语句")
    end,
  },
}
