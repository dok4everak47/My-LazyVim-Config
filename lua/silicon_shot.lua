-- silicon 的"进程隔离"包装层（2026-10-07）
--
-- 为什么不用插件自带的 setup()（别退回那种写法）:
--   插件是 Rust cdylib，内部报错时会在 nvim_oxi 的 C 回调里触发
--   "panic in a function that cannot unwind" → 内核 SIGABRT → **整个 nvim 被杀死**
--   （实测 filetype 不被 syntect 认识时 exit 134）。
--   所以主进程只负责"写临时文件 + 起 `nvim --headless --clean` 子进程出图"，
--   子进程崩了只是非零退出码，主进程只弹一条提示。
--   细节与实测记录: skill lazyvim-configuration → references/silicon-code-screenshot.md
--
-- 另一条纪律: 子进程 exit 0 不代表出图成功（存图目录不存在时它照样 exit 0 但没写文件），
--   所以成功判据一律是"磁盘上真的出现了非空 PNG"。
local M = {}

local PLUGIN_DIR = vim.fn.stdpath("data") .. "/lazy/silicon.nvim"

-- 传给插件 setup() 的表（只支持数据；window_title 这类函数跨进程传不了）
M.opts = {
  font = "Maple Mono NF CN=20;Hack=20",
  theme = "Dracula",
  -- output = { path = vim.fn.expand("~/Desktop/Renders") }, -- 想固定存图目录就打开这行
}

-- 实测确认一定失败（子进程必 abort）的 filetype：直接给提示，省一次注定失败的启动
local never_works = { [""] = true, text = true, jsonc = true, gitcommit = true, typst = true, norg = true }

local function notify(msg, level)
  vim.notify("[silicon] " .. msg, level or vim.log.levels.INFO)
end

local function setup_literal(opts)
  -- vim.inspect 出的是多行 Lua 字面量，压成一行当 -c 参数
  return ("require('silicon').setup(%s)"):format((vim.inspect(opts):gsub("%s*\n%s*", " ")))
end

-- 插件 output.format 用的是 time-rs 占位符，这里只支持常见几个
local function formatted_name(fmt)
  local map = {
    ["[year]"] = "%Y", ["[month]"] = "%m", ["[day]"] = "%d",
    ["[hour]"] = "%H", ["[minute]"] = "%M", ["[second]"] = "%S",
  }
  for k, v in pairs(map) do fmt = fmt:gsub("%[" .. k:sub(2, -2) .. "%]", v) end
  return os.date(fmt)
end

local function applescript_quote(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

--- 用子进程把若干行代码渲染成 PNG（只负责出图，返回路径或 nil）
local function render_png(lines, ft, out_png)
  local tmp = vim.fn.tempname() .. "." .. ft
  vim.fn.writefile(lines, tmp)

  local res = vim.system({
    vim.v.progpath, -- 用当前这个 nvim 自己
    "--headless",
    "--clean", -- 不加载用户配置：启动快，也不受本文件影响
    "-c", "set rtp^=" .. PLUGIN_DIR,
    "-c", "lua " .. setup_literal(M.opts),
    "-c", "set filetype=" .. ft,
    "-c", "Silicon! " .. vim.fn.fnameescape(out_png),
    "-c", "qa!",
    "--", tmp,
  }, { text = true }):wait()
  vim.fn.delete(tmp)

  if vim.fn.filereadable(out_png) == 1 and vim.fn.getfsize(out_png) > 0 then
    return out_png, res
  end
  return nil, res
end

local function failure_reason(ft, res)
  if (res.stderr or ""):find("panic") then
    return ("filetype '%s' 不在 silicon 支持的语法里（先 :set ft=rust 之类再截）"):format(ft)
  end
  local line = (res.stderr or ""):match("[^\n]+")
  return line or ("没有生成图片（子进程退出码 " .. tostring(res.code) .. "）")
end

--- 把若干行代码渲染成图片
---@param lines string[] 要渲染的行
---@param out string|nil 存图路径；nil = 拷进剪贴板
function M.render(lines, out)
  if vim.fn.filereadable(PLUGIN_DIR .. "/lua/silicon.so") == 0 then
    return notify("插件还没 build：先跑 :Lazy build silicon.nvim", vim.log.levels.WARN)
  end

  local ft = vim.bo.filetype
  if never_works[ft] then
    return notify(
      ("filetype '%s' 不在 silicon 支持的语法里；先 :set ft=rust（或对应语言）再截"):format(
        ft == "" and "<空>" or ft
      ),
      vim.log.levels.WARN
    )
  end

  -- 剪贴板模式也先出图到临时文件：只有文件真的存在才算成功，然后再拷进剪贴板
  local clipboard = out == nil
  local png = clipboard and (vim.fn.tempname() .. ".png") or out

  -- 存图目录不存在时子进程会 panic（且 exit 0 不报错），主进程先查掉
  if not clipboard then
    local dir = vim.fn.fnamemodify(out, ":h")
    if vim.fn.isdirectory(dir) == 0 then
      return notify(("存图目录不存在: %s（先 mkdir，或换 :Silicon! <别的路径>）"):format(dir), vim.log.levels.WARN)
    end
  end

  local ok, res = render_png(lines, ft, png)
  if not ok then
    return notify("出图失败：" .. failure_reason(ft, res), vim.log.levels.ERROR)
  end

  if not clipboard then
    return notify("已存图: " .. out)
  end

  local copy = vim.system({
    "osascript", "-e",
    ("set the clipboard to (read (POSIX file %s) as «class PNGf»)"):format(applescript_quote(png)),
  }, { text = true }):wait()
  vim.fn.delete(png)

  if copy.code ~= 0 then
    return notify("图已生成但拷进剪贴板失败：" .. ((copy.stderr or ""):match("[^\n]+") or "osascript 出错"),
      vim.log.levels.ERROR)
  end
  notify("图片已进剪贴板")
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  vim.api.nvim_create_user_command("Silicon", function(args)
    local lines = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)
    local out
    if args.args ~= "" then
      out = vim.fn.fnamemodify(args.args, ":p")
    elseif args.bang then
      -- 插件原语义: 无 file + 带 ! = 存到 output.path/output.format
      local outcfg = M.opts.output or {}
      local dir = vim.fn.expand(outcfg.path or ".")
      out = (dir == "" and "." or dir):gsub("/$", "")
        .. "/"
        .. formatted_name(outcfg.format or "silicon_%Y%m%d_%H%M%S.png")
    end
    M.render(lines, out)
  end, {
    range = "%", -- 不给范围 = 整个文件；可视选中 = 只有选中的行
    bang = true,
    nargs = "?",
    complete = "file",
    desc = "代码转图片（剪贴板；带 ! 存盘）",
  })

  vim.keymap.set("x", "SS", ":Silicon<CR>", { desc = "代码转图片到剪贴板" })
end

return M
