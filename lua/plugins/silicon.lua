-- silicon.nvim：把代码渲染成漂亮的截图（Rust 插件, 上游 krivahtoo/silicon.nvim）
-- 本体是 prebuilt cdylib: build 钩子跑 install.sh 从 release 下载 silicon-mac-arm64
-- 装到 lua/silicon.so（无 cargo 依赖; 要源码编译则改 build = "./install.sh build"）
-- 用法: 可视模式选中 → SS（或 :'<,'>Silicon）→ 图片进剪贴板
--        :'<,'>Silicon!  → 存文件到 cwd（output.path/format 控制）
-- 换主题: 见 :lua print(vim.inspect(require("silicon").list_themes()))
--
-- font 为什么写成这个串（2026-10-07 实测坑, 别改成单个字体名）:
--  1) 插件 src/utils.rs 里有个硬编码兜底: 字体串里没有恰好叫 "Hack" 的项时,
--     它自动追加 ("Hack", 26.0)。macOS 上按名查 "Hack" 会回退到系统字体,
--     于是链条里混进一个 26pt 字体, 每行被撑高约 2px（实测 432 vs 416 高）。
--     末尾显式写 "Hack=20" 把它顶掉（has_hack=true → 不再追加）。
--  2) "Hack Nerd Font=20" 单独用: 中文注释整行渲染不出来, 字符全被丢弃
--     （只有 "No font found for character" 警告）。Maple Mono NF CN 自带中文 +
--     Nerd 图标, 一个字体覆盖 ASCII/CJK/图标, 中文字宽恰好 = 2 个 ASCII 格,
--     行高也最紧凑, 且不需要 fallback 混排。
--  3) 可用替代组合（本机实测都正常）:
--     font = "Hack Nerd Font=20;PingFang SC=20;Hack=20"      -- 原生中文, 行高略高
--     font = "Hack Nerd Font Mono=20;PingFang SC=20;Hack=20"
--     emoji（✅🎉 类）拿不到——Apple Color Emoji 是位图字体, 会被直接丢弃,
--     不是配置问题。
return {
  {
    "krivahtoo/silicon.nvim",
    build = "./install.sh",
    config = function()
      require("silicon").setup({
        -- ~/Library/Fonts/MapleMono-NF-CN-*.ttf, family 名即 "Maple Mono NF CN"
        font = "Maple Mono NF CN=20;Hack=20",
        theme = "Dracula",
      })
    end,
  },
}
