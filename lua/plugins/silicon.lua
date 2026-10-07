-- silicon.nvim：把代码渲染成漂亮的截图（Rust 插件, 上游 krivahtoo/silicon.nvim）
-- 本体是 prebuilt cdylib: build 钩子跑 install.sh 从 release 下载 silicon-mac-arm64
-- 装到 lua/silicon.so（无 cargo 依赖; 要源码编译则改 build = "./install.sh build"）
-- 用法: 可视模式选中 → SS（或 :'<,'>Silicon）→ 图片进剪贴板
--        :'<,'>Silicon!  → 存文件到 cwd（output.path/format 控制）
-- 换主题: 见 :lua print(vim.inspect(require("silicon").list_themes()))
return {
  {
    "krivahtoo/silicon.nvim",
    build = "./install.sh",
    config = function()
      require("silicon").setup({
        -- 本机已装 HackNerdFont (~/Library/Fonts/HackNerdFont-*.ttf)
        font = "Hack Nerd Font=20",
        theme = "Dracula",
      })
    end,
  },
}
