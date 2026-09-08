-- rust-analyzer 补全：函数自动补全括号（2026-09-04）
-- 现象：补全 `Some`/`Ok` 等函数只出名字，不带 `()`。
-- 根因：rust-analyzer 默认 completion.callable.snippets = "none"（只补函数名）。
-- 这里设为 "fill_arguments"：可调用项补全自动带 `()` 并预填参数占位（$1...）。
--   可选值：none（默认）/ add_parenthesis（只加 () 不填参）/ fill_arguments（加 () + 预填参）。
-- 用 opts 函数深合并进 LazyVim rust extra 已设的 default_settings，不覆盖其它键。

-- devShell 环境兜底（2026-09-08）：
-- rust-analyzer / cargo 只存在于项目 devShell（Nix 铁律：工具链不装全局）。
-- 若 nvim 启动时 PATH 里没有 rust-analyzer（从项目外目录用绝对路径打开文件、
-- 或 GUI 启动继承 launchd PATH），则从当前文件目录向上找 .envrc + flake.nix，
-- 用 `direnv exec` 导出 devShell 环境（仅 PATH / RUST_SRC_PATH）补进 nvim 进程，
-- 并给 rustaceanvim 显式绝对 cmd —— RA 既能找到自己，也能 spawn cargo 做依赖解析。
local function ensure_devshell_env()
  if vim.fn.exepath("rust-analyzer") ~= "" then
    return nil -- PATH 已有：正常 devShell 场景，零开销
  end
  -- direnv 也可能不在 launchd PATH 里，兜底到系统 profile 绝对路径
  local direnv_bin = vim.fn.exepath("direnv")
  if direnv_bin == "" then
    direnv_bin = "/run/current-system/sw/bin/direnv"
  end
  if vim.fn.executable(direnv_bin) ~= 1 then
    return nil
  end
  -- 候选起点：当前文件目录（绝对路径打开的文件）与 nvim 启动目录
  local starts = {}
  local file_dir = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
  if file_dir ~= "." and file_dir ~= "" then
    table.insert(starts, file_dir)
  end
  table.insert(starts, vim.fn.getcwd())
  for _, start in ipairs(starts) do
    local dir = start
    while dir ~= "/" and dir ~= "" do
      if vim.fn.filereadable(dir .. "/.envrc") == 1
        and vim.fn.filereadable(dir .. "/flake.nix") == 1 then
        local out = vim.fn.system({
          "sh",
          "-c",
          direnv_bin .. " exec " .. vim.fn.shellescape(dir) .. " env 2>/dev/null",
        })
        if vim.v.shell_error == 0 and out ~= "" then
          -- 白名单只取 PATH / RUST_SRC_PATH，绝不复制代理等其它环境变量
          for _, line in ipairs(vim.split(out, "\n")) do
            local key, value = line:match("^([A-Z_]+)=(.*)$")
            if key == "PATH" then
              vim.env.PATH = value
            elseif key == "RUST_SRC_PATH" then
              vim.env.RUST_SRC_PATH = value
            end
          end
          return vim.fn.exepath("rust-analyzer") or nil
        end
      end
      dir = vim.fn.fnamemodify(dir, ":h")
    end
  end
  return nil
end

return {
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      -- devShell 兜底：注入 PATH 并解析 rust-analyzer 绝对路径
      local ra_path = ensure_devshell_env()
      if ra_path then
        opts.server = opts.server or {}
        opts.server.cmd = { ra_path }
      end
      opts.server = opts.server or {}
      opts.server.default_settings = opts.server.default_settings or {}
      local ra = opts.server.default_settings["rust-analyzer"] or {}
      ra.completion = vim.tbl_deep_extend("force", ra.completion or {}, {
        callable = {
          snippets = "fill_arguments",
        },
        -- 自定义 snippet：println! 宏补全默认只出 println!()（无参数占位，宏不走
        -- fill_arguments），这里提供带 fmt 字符串 + args 两个占位的版本。
        -- 补全列表会出现额外一项（描述 "println!(\"…\", …)"），选中即展开
        -- println!(\"$1\", $2) 光标在 $1，Tab 跳 $2。prefix 匹配 "println"。
        snippets = {
          custom = {
            ["println!"] = {
              prefix = { "println" },
              body = 'println!("$1", $2)$0',
              description = 'println!("…", …)',
              scope = "expr",
            },
            ["eprintln!"] = {
              prefix = { "eprintln" },
              body = 'eprintln!("$1", $2)$0',
              description = 'eprintln!("…", …)',
              scope = "expr",
            },
            ["print!"] = {
              prefix = { "print" },
              body = 'print!("$1", $2)$0',
              description = 'print!("…", …)',
              scope = "expr",
            },
          },
        },
      })
      opts.server.default_settings["rust-analyzer"] = ra
    end,
  },
}
