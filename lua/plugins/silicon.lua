-- silicon.nvim：把代码渲染成漂亮的截图（Rust 插件, 上游 krivahtoo/silicon.nvim）
-- 本体是 prebuilt cdylib: build 钩子跑 install.sh 从 release 下载 silicon-mac-arm64
-- 装到 lua/silicon.so（无 cargo 依赖; 要源码编译则改 build = "./install.sh build"）
--
-- 关键: lazy = true 且**不调用插件的 setup()**。
--   插件自己注册的 :Silicon / SS 在内部报错时会在 nvim_oxi 的 C 回调里 abort
--   整个 nvim 进程（实测: filetype 不被 syntect 支持 / 存图目录不存在 → exit 134）。
--   出图改由 lua/silicon_shot.lua 起 headless 子进程完成，用法规格不变:
--     可视选中 → SS（或 :'<,'>Silicon）→ 图片进剪贴板
--     :Silicon!          → 存文件到 output.path（默认 cwd）
--     :Silicon[!] <file> → 存到指定路径
--   字体/主题等所有设置都在 lua/silicon_shot.lua 的 M.opts 里（函数型选项如
--   window_title 不支持, 跨进程传不了）。
--
-- 字体串为什么必须带 Hack=20（2026-10-07 实测, 别改成单个字体名）:
--  1) 插件 src/utils.rs 有硬编码兜底: 字体串里没有恰好叫 "Hack" 的项时, 自动追加
--     ("Hack", 26.0)。macOS 按名查 "Hack" 会回退到系统字体, 链条里混进 26pt 字体,
--     每行被撑高约 2px（实测 432 vs 416 高）。末尾显式写 "Hack=20" 顶掉它。
--  2) "Hack Nerd Font=20" 单独用: 中文注释整行渲染不出来, 字符全被丢弃。Maple Mono
--     NF CN（~/Library/Fonts/MapleMono-NF-CN-*.ttf）自带中文 + Nerd 图标, 一个字体
--     覆盖 ASCII/CJK/图标, 中文字宽恰好 = 2 个 ASCII 格, 行高也最紧凑。
--  3) 可用替代: "Hack Nerd Font=20;PingFang SC=20;Hack=20"（原生中文, 行高略高）。
--     emoji（✅🎉 类）拿不到 —— Apple Color Emoji 是位图字体, 会被丢弃, 不是配置问题。
return {
  {
    "krivahtoo/silicon.nvim",
    lazy = true,
    build = "./install.sh",
    init = function()
      require("silicon_shot").setup()
    end,
  },
}
