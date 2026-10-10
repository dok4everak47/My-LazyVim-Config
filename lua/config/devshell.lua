-- devShell 自举（2026-10-10）
--
-- 问题：nvim 的 PATH 继承自「谁启动了它」。只有从「已经 cd 进项目、被 shell 的
-- direnv hook 作用过」的终端里启动，PATH 里才有 devShell 的工具链。从 yazi /
-- Finder / VS Code（vscode-neovim）启动时完全绕过 direnv，于是：
--   * gopls 找不到 → Go 没有补全（lsp.lua 里 gopls 走 devShell，找不到就禁用）
--   * conform 的 goimports/gofumpt 报 "go command required, not found"（每次保存弹错）
--   * nvim-lint 的 golangci-lint 打印 help/日志 → 解析失败 → 假错误 "Parser failed"
-- 2026-10-10 实测：nvim 由 yazi 启动时 PATH 里既无 go 也无 gopls，三种症状同时出现。
--
-- 处理：cwd（或其父目录）有 .envrc 就用 direnv 导出该 flake devShell 的环境，
-- 只把 PATH 与代理变量并进 nvim 进程 —— 效果等同「在项目目录的 direnv shell 里启动」。
-- 只取这几个变量是刻意的：blast radius 最小，避免把整个 devShell 环境（CC/CXX/
-- DEVELOPER_DIR 等）灌进 nvim 影响无关插件；工具链查找靠 PATH 就够。
--
-- 必须在 lazy.setup 之前执行（lsp.lua 的 gopls 解析、conform/lint 的 tool 判定
-- 都在 setup 期定下来），所以由 init.lua 调用。
--
-- 注意：direnv export 的 shellHook 输出走 stderr（nix-direnv 会 echo
-- "🐹 go version ..."），必须丢掉，否则会窜进 nvim 的界面/消息区。

local M = {}

local INJECT = { "PATH", "http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "no_proxy", "NO_PROXY" }

---@return string|nil project_dir 最近的含 .envrc 的目录
function M.project_dir()
  local ok, envrc = pcall(vim.fs.find, ".envrc", { upward = true, path = vim.fn.getcwd() })
  if not ok or type(envrc) ~= "table" or not envrc[1] then
    return nil
  end
  return vim.fs.dirname(envrc[1])
end

function M.apply()
  if vim.fn.executable("direnv") == 0 then
    return
  end
  local dir = M.project_dir()
  if not dir then
    return
  end
  -- 必须 cd 进项目目录：direnv export 只认当前目录，没有 DIR 参数
  local cmd = "cd " .. vim.fn.shellescape(dir) .. " && exec direnv export json 2>/dev/null"
  local ok, out = pcall(vim.fn.system, { "/bin/sh", "-c", cmd })
  if not ok or vim.v.shell_error ~= 0 or type(out) ~= "string" or out == "" then
    return
  end
  local decoded_ok, env = pcall(vim.json.decode, out)
  if not decoded_ok or type(env) ~= "table" then
    return
  end
  for _, key in ipairs(INJECT) do
    local val = env[key]
    if type(val) == "string" and val ~= "" then
      vim.fn.setenv(key, val)
    end
  end
end

M.apply()

return M
