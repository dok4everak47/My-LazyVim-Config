-- 方案 B：零插件版「Code Runner」——filetype → 命令映射 + 项目根探测。
-- 由 lua/config/keymaps.lua 的 <leader>r / <leader>R 调用（require("config.run").run(...)）。
--
-- 【本机实测的关键坑，改这里前必读】
--   登录 shell 已迁 nushell（vim.o.shell = /run/current-system/sw/bin/nu），因此
--   snacks.terminal 默认的 `:!` 与终端都跑在 nu 下，而 nu：
--     ① 不支持 `cd X && Y`（&& 直接语法错误）；
--     ② 字符串转义与 POSIX 不同（'a''b' 才是单引号字面量，'\'' 会报 expected closing '）。
--   所以本模块所有命令**显式交给 bash 执行**：把 cmd 以 argv 列表
--   { BASH, "-c", script } 传给 snacks.terminal（termopen 收 list 时不经过任何 shell 解析），
--   script 里再用 vim.fn.shellescape 的 POSIX 引用 —— 与用户登录 shell 无关，结果稳定。
--
-- 【语言工具链纪律】rust/elm/php/racket 本机全局没有二进制（只在项目 devShell），
--   命令必须经 direnv exec 才找得到；仅当向上能找到 .envrc 时才加 direnv 前缀
--   （否则裸跑，报 command not found 也比 direnv 报错更直白）。
local M = {}

local BASH = (function()
  local p = vim.fn.exepath("bash")
  if p == "" then
    p = "/run/current-system/sw/bin/bash"
  end
  if vim.fn.executable(p) ~= 1 then
    p = "/bin/bash"
  end
  return p
end)()

-- direnv 走绝对路径兜底：GUI 启动的 nvim 从 launchd 继承的 PATH 没有 nix profile
local DIRENV = (function()
  local p = vim.fn.exepath("direnv")
  if p == "" then
    p = "/run/current-system/sw/bin/direnv"
  end
  return p
end)()

local function sh(s)
  return vim.fn.shellescape(s)
end

-- 向上查找 marker 文件，返回所在目录（找不到 nil）。用 :h 逐级上溯，"/" 处停止。
local function find_up(start, marker)
  local dir = start
  while dir and dir ~= "" do
    if vim.fn.filereadable(dir .. "/" .. marker) == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir or parent == "" then
      return nil
    end
    dir = parent
  end
  return nil
end

-- 文件级映射：filetype → bash 命令模板
-- 占位符：{file} 绝对路径 / {name} 文件名 / {stem} 去扩展名 / {dir} 所在目录 /
--         {out} 编译产物临时路径 / {direnv} direnv 绝对路径
local RUNNERS = {
  python = "python3 -u {file}", -- 必须 python3：本机没有 `python`（clang 自带的是 python3）
  lua = "nvim -l {file}", -- nvim 自带 lua 解释器，不需要 nix
  javascript = "node {file}",
  typescript = "node {file}", -- node ≥22.18 直接剥离类型跑 .ts（本机 v22.23.2 实测可跑）
  nix = "nix eval --file {file}", -- .nix 无「运行」语义，这是求值出结果
  sh = "bash {file}",
  bash = "bash {file}",
  zsh = "zsh {file}",
  c = "cd {dir} && gcc {name} -o {out} && {out}", -- 用系统 Apple clang，不走 devShell：始终可用
  cpp = "cd {dir} && g++ -std=c++17 {name} -o {out} && {out}",
  rust = "cd {dir} && {direnv_exec}rustc {name} -o {out} && {out}",
  elm = "cd {dir} && {direnv_exec}elm make {name}",
  php = "cd {dir} && {direnv_exec}php {name}",
  racket = "cd {dir} && {direnv_exec}racket {name}",
}

-- 项目级映射：只有「整项目运行」语义才启用（单文件命令在 Cargo/npm 项目里会失败）。
-- marker = 根标记文件；script = 可选，要求 package.json 里有该 scripts 项才用项目命令。
local PROJECTS = {
  rust = { marker = "Cargo.toml", cmd = "cargo run" },
  go = { marker = "go.mod", cmd = "go run ." },
  c = { marker = "Makefile", cmd = "make" },
  cpp = { marker = "Makefile", cmd = "make" },
  javascript = { marker = "package.json", cmd = "npm start", script = "start" },
  typescript = { marker = "package.json", cmd = "npm start", script = "start" },
}

-- package.json 里是否存在指定 scripts 项（不存在就别用 npm start：会直接报错）
local function has_script(root, marker, key)
  local file = root .. "/" .. marker
  if vim.fn.filereadable(file) ~= 1 then
    return false
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
  end)
  return ok and type(data) == "table" and type(data.scripts) == "table" and data.scripts[key] ~= nil
end

-- 需要 devShell 的命令前缀：向上有 .envrc 才加 "<direnv> exec . "，否则空串
local function direnv_exec(dir)
  if find_up(dir, ".envrc") then
    return sh(DIRENV) .. " exec . "
  end
  return ""
end

local function expand(tpl, path, dir)
  local repl = {
    file = sh(path),
    dir = sh(dir),
    name = sh(vim.fn.fnamemodify(path, ":t")),
    stem = sh(vim.fn.fnamemodify(path, ":t:r")),
    out = sh("/tmp/nvim-run-" .. vim.fn.fnamemodify(path, ":t:r")),
    direnv_exec = direnv_exec(dir),
  }
  -- gsub 用表替换时 % 不参与转义，路径里的 % 不会被二次解释
  -- 注意 [%w_]：占位符名含下划线（direnv_exec），只有 %w 会漏掉它
  return (tpl:gsub("{([%w_]+)}", repl))
end

-- 纯函数（可单测）：给 filetype + 文件路径，解析出要跑的命令。
-- 返回 nil（无映射）或 { cmd = <bash 脚本>, cwd = <目录>, kind = "project"|"file" }
function M.resolve(ft, path)
  if not path or path == "" then
    return nil
  end
  path = vim.fn.fnamemodify(path, ":p")
  local dir = vim.fn.fnamemodify(path, ":h")

  local proj = PROJECTS[ft]
  if proj then
    local root = find_up(dir, proj.marker)
    if root and (not proj.script or has_script(root, proj.marker, proj.script)) then
      return {
        cmd = "cd " .. sh(root) .. " && " .. direnv_exec(root) .. proj.cmd,
        cwd = root,
        kind = "project",
      }
    end
  end

  local tpl = RUNNERS[ft]
  if not tpl then
    return nil
  end
  return { cmd = expand(tpl, path, dir), cwd = dir, kind = "file" }
end

-- 调试用：直接拿命令字符串
function M.command(ft, path)
  local res = M.resolve(ft, path)
  return res and res.cmd or nil
end

-- 上一次运行的终端：复跑先关掉旧的（等同 Code Runner 的 restart 语义，也避免浮窗越堆越多）
local last = nil
-- 上一次真正运行的目标文件。光标停在运行终端里时（snacks_terminal，无文件名/filetype 是
-- snacks_terminal），连按 <leader>r 要复跑同一个文件 —— 与 VS Code Code Runner 一致。
local last_target = nil

--- 运行当前 buffer。
---@param position? "float"|"right"|"bottom" 输出窗口位置（默认 float 浮窗）
function M.run(position)
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local ft = vim.bo[buf].filetype
  -- 焦点在运行终端/无名字 buffer 里 → 复用上次目标（复跑）
  if (path == "" or vim.bo[buf].buftype == "terminal") and last_target then
    ft, path = last_target.ft, last_target.path
  end

  local res = M.resolve(ft, path)
  if not res then
    vim.notify(
      "no run mapping for filetype: " .. (ft == "" and "none" or ft)
        .. (vim.api.nvim_buf_get_name(buf) == "" and " (未命名 buffer 先保存)" or ""),
      vim.log.levels.WARN
    )
    return
  end

  -- 命令跑的是磁盘文件，先把该文件所在 buffer 的未保存改动写入。
  -- 不用 vim.cmd("write") 裸写：焦点可能就在终端 buffer 上（会把终端内容写盘）。
  local target = vim.fn.bufnr(path)
  if target and target ~= -1 and vim.api.nvim_buf_is_loaded(target) and vim.bo[target].modified then
    vim.api.nvim_buf_call(target, function()
      pcall(vim.cmd, "write")
    end)
  end

  -- 脚本开头回显此命令（浮窗里能看到到底跑了什么），再用 && 接真正的命令
  local script = "printf '%s\\n' " .. sh("$ " .. res.cmd .. "\n") .. " && " .. res.cmd

  if last and last.buf_valid and last:buf_valid() then
    last:close()
  end

  local term = Snacks.terminal.open({ BASH, "-c", script }, {
    cwd = res.cwd,
    interactive = true,
    -- auto_close 默认 true：成功退出会立刻关掉浮窗，输出看不到。设 false 让输出常驻，
    -- 看完按 q 隐藏（snacks 终端默认键）。
    auto_close = false,
    win = { position = position or "float" },
  })
  last = term
  last_target = { ft = ft, path = path }
  term:on("BufWipeout", function()
    if last == term then
      last = nil
    end
  end, { buf = true })
  return term, res
end

return M
