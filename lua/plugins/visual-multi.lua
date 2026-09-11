-- vim-visual-multi: 多光标编辑 (VM)
-- 2026-09-07 新增 (决策记录)
--   * 触发: Rust 重构常需同步改多处, 现有 gn/宏/visual-block 不够直观 → VM
--   * 键位设计 (关键决策):
--     - 保留官方默认: <C-n> 找词添加光标, n/N 下一个/上一个, q 跳过, Q 删除光标, \\A 全选
--     - 改掉冲突: LazyVim 默认把 <C-Up>/<C-Down> 绑为窗口 resize
--       → VM 加光标改用 <M-j>/<M-k> (Alt+j/k, LazyVim 未占用)
--     - <C-n> 与 blink.cmp 不冲突: blink 只在 insert 模式, VM 在 normal/visual 模式
--   * 不设 keys/lazy load: 该插件需启动早期注册映射, 用 event 加载
return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "VeryLazy",
    init = function()
      -- 自定义映射: 加光标用 <M-j>/<M-k> (避免覆盖 LazyVim 的窗口 resize)
      vim.g.VM_maps = {
        ["Add Cursor Down"] = "<M-j>",
        ["Add Cursor Up"] = "<M-k>",
      }
    end,
  },
}
