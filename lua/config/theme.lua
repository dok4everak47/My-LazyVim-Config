-- 主题切换 + 记住上次选择 (2026-09-16)
-- 入口: dashboard 的 "Theme" 项 (键 t) → snacks 配色 picker
--       光标移动 = 实时预览, 回车 = 应用并记住, Esc = 还原且不留痕。
-- 记忆: 状态文件 vim.fn.stdpath("state").."/colorscheme" (不在 git 里, 不脏仓库),
--       启动时 lua/config/lazy.lua 的 colorscheme 回调读它恢复, 装不上则回默认。
-- 回到默认: rm ~/.local/state/nvim/colorscheme
--
-- 两个刻意的设计 (都实测过):
-- 1) 记「文件名」而不是 vim.g.colors_name。近三分之一的主题带变体文件
--    (catppuccin-latte / windir-light / onedark_vivid ...), 它们的 g:colors_name 会落成
--    不带变体的主名 (catppuccin / windir), 只记主名的话下次启动就退化成主题的默认风格。
--    所以 picker 回车 → 记所选文件名; 其它途径 (:colorscheme) → 记 g:colors_name。
-- 2) picker 浏览期间的 ColorScheme 事件 (一格一格的预览 + Esc 那次还原) 一律不记 ——
--    否则「打开看一眼就退出」也会把状态文件改掉。
local M = {}

M.default = "oxocarbon"
M.state_file = vim.fn.stdpath("state") .. "/colorscheme"

local picking = false -- picker 正开着 (期间不记)
local last -- 状态文件当前值的内存缓存, 免掉重复读写

---上次选过的主题名 (文件不存在 / 内容为空 → nil)
---@return string?
function M.saved()
  if last then
    return last
  end
  local ok, lines = pcall(vim.fn.readfile, M.state_file)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  local name = vim.trim(lines[1] or "")
  last = name ~= "" and name or nil
  return last
end

---@param name? string
local function remember(name)
  if not name or name == "" or name == last then
    return
  end
  last = name
  pcall(vim.fn.writefile, { name }, M.state_file)
end

---启动时用: 上次记住的主题 (先试着加载, 装不上就回默认), 否则默认
---@return string
function M.startup()
  local name = M.saved()
  if name and name ~= M.default then
    -- 不存在的主题在 pcall 里抛 E185 → 判失败, 不污染启动
    if pcall(vim.cmd.colorscheme, name) then
      return name -- 原样返回文件名: LazyVim 的二次应用走同一个 colors/*.vim|lua
    end
    vim.notify(("上次的主题 %s 已不可用, 回默认 %s"):format(name, M.default), vim.log.levels.WARN, { title = "Theme" })
  end
  return M.default
end

---应用主题并记住 (picker 回车走这里); 主题不存在则提示且不动状态文件
---@param name string
---@return boolean
function M.set(name)
  local ok = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(("主题 %s 加载失败 (不存在或插件没装)"):format(name), vim.log.levels.WARN, { title = "Theme" })
    return false
  end
  remember(name)
  return true
end

---dashboard "Theme" 项调用的入口
function M.pick()
  picking = true
  Snacks.picker.colorschemes({
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      picker.preview.state.colorscheme = nil -- 别让预览窗口关闭时把主题还原回去
      vim.schedule(function()
        M.set(item.text) -- 记所选文件名, 变体不会退化成主名
      end)
    end,
    on_close = function()
      -- 关掉之后稍等一下再恢复"记忆": Esc 取消时 snacks 会晚一步把主题还原,
      -- 那次还原不该写状态文件 (否则变体主题会被记成它的主名)
      vim.defer_fn(function()
        picking = false
      end, 300)
    end,
  })
end

-- 其它途径换主题 (:colorscheme xxx 等) 也记住 —— picker 浏览期间除外
vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Remember current colorscheme so it survives restarts",
  callback = function()
    if picking then
      return
    end
    remember(vim.g.colors_name)
  end,
})

return M
