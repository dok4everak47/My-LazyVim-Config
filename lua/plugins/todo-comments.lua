-- 让 `// TODO(#N): ...` 这类占位注释在 neovim 里也能被识别。
--
-- LazyVim 自带 todo-comments.nvim，走上游默认 pattern：
--   highlight.pattern = [[.*<(KEYWORDS)\s*:]]
-- 它要求"关键字后面（可带空白）紧跟冒号"。我们的写法是 `TODO(#11):`，关键字和冒号
-- 中间夹了 `(#11)`，默认匹配不到。
--
-- ★ 坑一：不能简单地把 `(#N)` 变成捕获组加进去。todo-comments 提取关键字用的是
--   highlight.lua 里的 `kw = m[3] ~= "" and m[3] or m[2]` —— 第 3 个捕获组一旦非空
--   就被当成关键字。多一个 `(...)` 会让 kw 变成字面量 "(#11)"，于是既没有高亮，
--   `tag=TODO` 的过滤（<leader>xT）也命中不了。
--   ⇒ 必须用**非捕获组**。very magic(`\v`) 下非捕获组写作 `%(`，不是 `\%(`。
-- ★ 坑二：搜索路径（TodoTelescope / Trouble todo / snacks）最终也调
--   `Highlight.match`（见 search.lua），所以修 highlight.pattern 一处即可两边通行；
--   search.pattern 只是给 ripgrep 的预过滤。
--
-- 默认值（对照）：
--   highlight.pattern = [[.*<(KEYWORDS)\s*:]]
--   search.pattern    = [[\b(KEYWORDS):]]
-- KEYWORDS 会被替换成 (TODO|FIX|HACK|WARN|PERF|NOTE|TEST|...)。
return {
  {
    "folke/todo-comments.nvim",
    opts = {
      highlight = {
        -- 允许关键字后夹一个 (#N) 再跟冒号；(: 前可有空白。%( = 非捕获组
        pattern = [[.*<(KEYWORDS)\s*%(\(#[0-9A-Za-z]*\))?\s*:]],
      },
      search = {
        -- 同理，供 ripgrep 预过滤（:TodoTelescope / :TodoTrouble 用）
        pattern = [[\b(KEYWORDS)(\(#[0-9A-Za-z]*\))?:]],
      },
    },
  },
}
