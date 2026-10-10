-- 语言服务器补充配置（原 AstroNvim astrolsp.lua 迁移）
-- 需要手动指定 cmd/init_options 的服务：elmls、nil_ls（项目 devShell 装，非 mason）
-- 注：lang.elm / lang.nix extras 已声明 elmls/nil_ls，这里覆盖 cmd 指向 devShell 二进制

-- Nix 工具路径解析（PATH → 当前目录 .direnv → 用户 nix profile → 系统 profile）
-- GUI 启动的 nvim 从 launchd 继承的 PATH 不含 nix profile，必须显式给绝对路径
local function nix_bin(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  local cwd = vim.fn.getcwd()
  local direnv_path = cwd .. "/.direnv/bin/" .. name
  if vim.fn.filereadable(direnv_path) == 1 then
    return direnv_path
  end
  local user_path = "/Users/dok4ever/.nix-profile/bin/" .. name
  if vim.fn.filereadable(user_path) == 1 then
    return user_path
  end
  return "/run/current-system/sw/bin/" .. name
end

-- nil 只走 devShell（PATH / .direnv），不依赖全局系统 profile；
-- 找不到返回 nil → 调用方应禁用 nil_ls，避免 ENOENT 报错
local function nil_bin()
  local path = vim.fn.exepath("nil")
  if path ~= "" then
    return path
  end
  local cwd = vim.fn.getcwd()
  local direnv_path = cwd .. "/.direnv/bin/nil"
  if vim.fn.filereadable(direnv_path) == 1 then
    return direnv_path
  end
  return nil
end

-- gopls 同理：Go 工具链与 gopls 都在项目 devShell（如 ~/Project/ketch 的 flake）；
-- GUI/外部启动的 nvim PATH 里没有 gopls，优先 exepath（direnv 激活的终端），
-- 再退到当前目录 .direnv/bin（nix-direnv 生成的 profile bin 软链）。
local function gopls_bin()
  local path = vim.fn.exepath("gopls")
  if path ~= "" then
    return path
  end
  local direnv_path = vim.fn.getcwd() .. "/.direnv/bin/gopls"
  if vim.fn.filereadable(direnv_path) == 1 then
    return direnv_path
  end
  return nil
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      -- elmls：GUI 启动 PATH 常缺 nix profile，显式给 cmd + init_options
      -- mason=false：elmls 不在 mason registry，避免 LazyVim 尝试 mason 安装
      opts.servers.elmls = {
        mason = false,
        cmd = { nix_bin("elm-language-server") },
        init_options = {
          elmPath = nix_bin("elm"),
          elmFormatPath = nix_bin("elm-format"),
          elmTestPath = nix_bin("elm-test-rs"),
          elmReviewPath = nix_bin("elm-review"),
        },
      }
      -- nil_ls：全局已删（2026-09），只走项目 devShell（direnv 激活的 PATH 或 .direnv/bin）；
      -- 无 devShell 环境（如 /etc/nix-darwin）时禁用，避免 ENOENT
      local nil_path = nil_bin()
      if nil_path then
        opts.servers.nil_ls = { mason = false, cmd = { nil_path } }
      else
        opts.servers.nil_ls = { mason = false, enabled = false }
      end
      -- marksman：markdown LSP（mason 装）。给 md 提供 documentSymbol（标题树），
      -- 让 <leader>ss 能模糊搜标题；LazyVim kind_filter 对 markdown = false（不过滤），标题不会被种类过滤掉。
      opts.servers.marksman = {}
      -- gopls：Go LSP（extras.lang.go 声明 settings/init_options），二进制走项目 devShell（flake 提供 go+gopls），
      -- 不装 mason（gopls 少了 go 工具链也是废的）；无 devShell 时禁用 → Go 文件退化为 treesitter（高亮/大纲），不报 ENOENT。
      local gopls_path = gopls_bin()
      if gopls_path then
        opts.servers.gopls = vim.tbl_deep_extend("force", opts.servers.gopls or {}, {
          mason = false,
          cmd = { gopls_path },
        })
      else
        opts.servers.gopls = vim.tbl_deep_extend("force", opts.servers.gopls or {}, {
          mason = false,
          enabled = false,
        })
      end
    end,
  },
  -- 关闭 nix 文件的 statix lint（statix 未全局安装，遵循 Nix 铁律：工具走 devShell；
  -- nil_ls 已提供诊断，statix 属可选 linter，避免打开 nix 文件报 ENOENT）
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.nix = nil -- 移除 nix 的 statix，nil_ls 诊断已足够
      -- golangci-lint 同样要 `go` 工具链。PATH 里没有 go（nvim 不是从项目 devShell
      -- 的 shell 启动的）时它会打印 help / level=error 日志，nvim-lint 按 JSON 解析
      -- 失败 → 在文件第 1 行抛假错误
      -- "Parser failed. Error message: ... Expected value but found invalid token"
      -- （2026-10-10 实测）。照上面 nil_ls 的降级套路：没 go 就不注册 go 的 linter，
      -- 静默跳过；有 go 时（devShell 里启动的 nvim）照常 lint。
      if vim.fn.executable("go") == 0 then
        opts.linters_by_ft.go = nil
      end
    end,
  },
}
