-- 主题切换 + 记住上次选择 (2026-09-16)
-- 入口: dashboard 的 "Theme" 项 (键 t) → snacks 配色 picker
--       光标移动 = 实时预览, 回车 = 应用, Esc = 还原回原来那个。
-- 记忆: 换主题 (任何方式: dashboard / :colorscheme / <leader>uC) 后把主题名写进
--       vim.fn.stdpath("state").."/colorscheme" —— 状态目录不在 git 里, 不脏仓库。
--       启动时 lua/config/lazy.lua 的 colorscheme 回调读它, 恢复上次用过的主题。
-- 回到默认: 删掉那个状态文件 (rm ~/.local/state/nvim/colorscheme) 即回 oxocarbon。
local M = {}

M.default = "oxocarbon"
M.state_file = vim.fn.stdpath("state") .. "/colorscheme"

---上次选过的主题名 (文件不存在 / 内容为空 → nil)
---@return string?
function M.saved()
  local ok, lines = pcall(vim.fn.readfile, M.state_file)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  local name = vim.trim(lines[1] or "")
  return name ~= "" and name or nil
end

---启动时用: 上次记住的主题 (先试着加载, 装不上就回默认), 否则默认
---@return string
function M.startup()
  local name = M.saved()
  if name and name ~= M.default then
    -- pcall 里的 :colorscheme 对不存在的主题会抛 E185 → 这里判失败, 不污染启动
    if pcall(vim.cmd.colorscheme, name) then
      return name -- 原样返回文件名: 第二次应用 (LazyVim) 走同一个 colors/*.vim|lua
    end
    vim.notify(("上次的主题 %s 已不可用, 回默认 %s"):format(name, M.default), vim.log.levels.WARN, { title = "Theme" })
  end
  return M.default
end

---dashboard "Theme" 项调用的入口
function M.pick()
  -- snacks 自带实时预览: 移动光标即换色, 回车留下, Esc 自动还原
  Snacks.picker.colorschemes()
end

-- 记住当前主题 (任何时候 ColorScheme 触发都记; 只在变化时写盘)
local last = M.saved()
vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Remember current colorscheme so it survives restarts",
  callback = function()
    local name = vim.g.colors_name
    if not name or name == "" or name == last then
      return
    end
    last = name
    pcall(vim.fn.writefile, { name }, M.state_file)
  end,
})

return M
