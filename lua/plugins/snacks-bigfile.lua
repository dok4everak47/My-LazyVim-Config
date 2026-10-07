-- Snacks.bigfile 修复 (2026-10-07): 后台被 bufload 的大文件会把「b:completion=false」
-- 写到**你正在编辑的那个文件**上, 于是 blink 补全在该文件里彻底不弹候选框。
--
-- 现象: Rust 文件里打字完全没有补全菜单(其它文件类型正常)。
-- 根因(pty 真机实测 + 栈回溯):
--   ① workspace-diagnostics.nvim 在 LspAttach 后对工作区每个文件 bufload() 探测 filetype;
--      其中 .DS_Store 是「8KB / 1 行」, 命中 snacks.bigfile 的启发式
--      (size-lines)/lines > 1000 → 那个后台 buffer 的 ft 被判成 bigfile。
--   ② snacks 的 FileType bigfile 处理函数在 nvim_buf_call(后台 buffer) 里先执行
--      `vim.cmd("NoMatchParen")`。那些后台 buffer 不在任何窗口里, 这行 ex 命令执行完
--      nvim 会把 curbuf 同步回「真实窗口里的 buffer」→ 从这里开始, 回调内的
--      “当前 buffer” 已经不是目标 buffer 了 (实测: 进 buf_call 时 cur=3, 跑完 NoMatchParen
--      时 cur=1)。
--   ③ 紧接着的 `vim.b.completion = false`(无索引写 = 写给“当前 buffer”)因此落到了
--      你正在编辑的文件上。blink 的 config.enabled() 见到 b:completion == false 直接
--      返回 false → 菜单永不出现, 与快捷键/映射/RA 无关。
--      同一处的 minianimate_disable / minihipatterns_disable 也写错了 buffer。
--
-- 上游 snacks main 分支目前仍是这么写的 (git 拉取确认), 所以 Lazy update 修不了;
-- 这里覆盖 bigfile.setup 修根因:
--   · buffer 局部变量一律用带索引的 `vim.b[ctx.buf]`(与当前 buffer 无关);
--   · 会动窗口/ex 命令的部分只在「目标 buffer 就是当前窗口的 buffer」时执行,
--     免得后台大文件顺手改掉你窗口的 foldmethod / statuscolumn。
-- 想临时平复已经有问题的 buffer: `:lua vim.b.completion = true`。
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.bigfile = opts.bigfile or {}
      opts.bigfile.setup = function(ctx)
        -- ① buffer 局部变量: 必须带 ctx.buf 索引
        vim.b[ctx.buf].completion = false
        vim.b[ctx.buf].minianimate_disable = true
        vim.b[ctx.buf].minihipatterns_disable = true
        -- ② 窗口/命令级: 只在目标 buffer 真的显示在当前窗口时才动
        if vim.api.nvim_get_current_buf() == ctx.buf then
          if vim.fn.exists(":NoMatchParen") ~= 0 then
            vim.cmd([[NoMatchParen]])
          end
          require("snacks").util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
        end
        -- ③ 保持上游行为: 把 syntax 恢复成 filetype 探测结果
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ctx.buf) then
            vim.bo[ctx.buf].syntax = ctx.ft
          end
        end)
      end
    end,
  },
}
