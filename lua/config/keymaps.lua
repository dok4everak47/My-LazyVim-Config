-- LazyVim keymaps (lua/config/keymaps.lua)
-- 原 AstroNvim polish.lua + astrocore.mappings 迁移到这里
-- 注：本文件由 LazyVim 在 VeryLazy 事件自动 require（见 lazyvim.config M.load）
-- 真实 GUI 打开时必触发；headless/后台无 UI 时不触发（正常现象）

local map = vim.keymap.set
-- LazyVim 的 <leader> 映射需走 Snacks.keymap.set（能正确处理 <leader> 前缀与 which-key 交互），
-- 裸 vim.keymap.set 注册 <leader> 映射会被 which-key 占位忽略。
local lmap = function(lhs, rhs, opts)
  Snacks.keymap.set("n", lhs, rhs, opts)
end


-- ── jk：退出插入模式 + 强制保存 + 格式化 ──
-- 注：终端 nvim 与 VS Code(vscode-neovim)共用本配置（vscode-neovim 嵌入 nvim 加载完整配置，
-- 并设 vim.g.vscode=1（数字，用 ~= nil 判定）。
-- 终端 nvim：完整行为——stopinsert → 清理残留 snippet → w! 强制保存 → 格式化
--   （rust 且有 cargo → cargo fmt；其余 → LazyVim.format）。每步 pcall 包裹：出错不阻断后续，
--   保证 w! 一定执行。
-- VS Code：只退 insert + 保存；格式化交给 VS Code 自带 formatOnSave
--   （rust 走 rust-analyzer 扩展，底层也是 rustfmt，与 cargo fmt 结果一致，避免双重格式化）。
local in_vscode = vim.g.vscode ~= nil -- vscode-neovim 注入的是 g:vscode=1（数字），用 ~= nil 判定
if in_vscode then
  map("i", "jk", "<Esc><cmd>w!<CR>", { desc = "jk exit insert + save (VS Code formats on save)" })
else
  map("i", "jk", function()
    vim.cmd("stopinsert")
    vim.schedule(function()
      -- 1) 清理残留 LuaSnip snippet（若有），避免退出后 Tab 被当成跳占位
      pcall(function()
        local ls_ok, ls = pcall(require, "luasnip")
        if ls_ok and ls.expand_or_jumpable() then
          ls.unlink_current()
        end
      end)

      -- 2) 强制保存（核心，必须执行）
      pcall(vim.cmd, "w!")

      -- 3) 格式化：rust + cargo 可用 → cargo fmt；否则 LazyVim.format
      local ft = vim.bo.filetype
      if ft == "rust" and vim.fn.executable("cargo") == 1 and vim.fn.findfile("Cargo.toml", ".;") ~= "" then
        local dir = vim.fn.expand("%:p:h")
        vim.system({ "cargo", "fmt" }, { cwd = dir, text = true }, function(res)
          if res.code ~= 0 then
            vim.schedule(function()
              vim.notify("cargo fmt 失败 (exit " .. res.code .. "): " .. (res.stderr or ""):gsub("%s+$", ""), vim.log.levels.ERROR)
            end)
          else
            vim.schedule(function()
              vim.cmd("checktime")
            end)
          end
        end)
      else
        pcall(LazyVim.format, { force = true })
      end
    end)
  end, { desc = "jk exit insert + force save + format (rust: cargo fmt)" })
end

-- ── 缓冲区切换（原 polish.lua setup_buffer_navigation + astrocore）──
lmap("<leader>bn", "<cmd>bn<CR>", { desc = "Next buffer" })
lmap("<leader>bp", "<cmd>bp<CR>", { desc = "Previous buffer" })
lmap("<leader>bb", "<cmd>e #<CR>", { desc = "Switch to last buffer" })
-- 数字 1-9 快速切缓冲: 按"列表顺序"而非"buffer 编号" (2026-09-05 修正)
-- 用户以为 <leader>1 = 第 1 个打开的 buffer; vim 的 buffer N 是"编号 N"(编号会
-- 随意增长如 9/18)。改成: 取当前 listed buffers 列表 (按打开顺序), <leader>1 切
-- 列表第 1 个, <leader>2 切第 2 个...
-- 注: 用裸 vim.keymap.set (map) 而非 lmap (Snacks.keymap.set): 数字键不打算
-- 出现在 which-key 菜单, 裸注册的全局映射优先级高于 which-key 的 <Space> trigger,
-- 不会被菜单拦截 (实测 lmap 注册的数字键被 which-key 吞掉, 按 <Space>1 无反应)。
for i = 1, 9 do
  map("n", "<leader>" .. i, function()
    -- listed buffers (按 buffer 编号排序 = 打开顺序近似)
    local listed = vim.tbl_filter(function(b)
      return b.listed == 1 and b.name ~= ""
    end, vim.fn.getbufinfo({ buflisted = 1 }))
    local target = listed[i]
    if target then
      vim.cmd("buffer " .. target.bufnr)
    end
  end, { desc = "Switch to buffer " .. i })
end
-- VS Code 风格切文件: Ctrl+Tab 下个 / Ctrl+Shift+Tab 上个 (不占 leader, 无 which-key 拦截)
map("n", "<C-Tab>", function()
  vim.cmd("bnext")
end, { desc = "Next buffer (VS Code Ctrl+Tab)" })
map("n", "<C-S-Tab>", function()
  vim.cmd("bprevious")
end, { desc = "Previous buffer (VS Code Ctrl+Shift+Tab)" })
-- Alt+方向键切缓冲（非 leader，仍用 map）
map("n", "<A-Left>", "<cmd>bp<CR>", { desc = "Previous buffer" })
map("n", "<A-Right>", "<cmd>bn<CR>", { desc = "Next buffer" })
-- 当前窗口内切缓冲（跳过 nofile）
lmap("<leader>bh", function()
  vim.cmd("bp | if &bt == 'nofile' | bp | endif")
end, { desc = "Previous buffer in window" })
lmap("<leader>bl", function()
  vim.cmd("bn | if &bt == 'nofile' | bn | endif")
end, { desc = "Next buffer in window" })

-- ── 代码运行（VS Code Code Runner 式，2026-09-11 方案 B）──
-- 逻辑全在 lua/config/run.lua：filetype → 命令映射 + 项目根探测（Cargo.toml/go.mod/
-- Makefile/package.json-with-start），需要 devShell 的语言自动走 direnv exec。
-- 命令一律显式用 bash -c 执行（登录 shell 是 nushell，nu 不支持 `cd X && Y`）。
lmap("<leader>r", function()
  require("config.run").run("float")
end, { desc = "Run file / project (float)" })

-- 右侧分屏跑，输出常驻不遮挡代码
lmap("<leader>R", function()
  require("config.run").run("right")
end, { desc = "Run file / project (split)" })

-- ── 终端开在当前文件目录（原 polish.lua setup_terminal_file_dir）──
-- LazyVim 默认用 snacks terminal。保持 <leader>tf/th（浮动/水平）。
lmap("<leader>tf", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  require("snacks").terminal.open(nil, { cwd = dir, float = true })
end, { desc = "Float terminal in file dir" })
lmap("<leader>th", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  require("snacks").terminal.open(nil, { cwd = dir, pos = "bottom" })
end, { desc = "Horizontal terminal in file dir" })

-- ── Aerial 大纲（原 polish.lua <leader>o；LazyVim aerial extra 默认 <leader>cs，保留 <leader>o）──
lmap("<leader>o", "<cmd>AerialToggle<cr>", { desc = "Toggle Aerial outline" })

-- ── VS Code 风格符号搜索（原 polish.lua <leader>fs）──
lmap("<leader>fs", function()
  Snacks.picker.lsp_symbols()
end, { desc = "Go to symbol in current file (VS Code Cmd+Shift+O)" })

-- ── 全项目符号搜索（VS Code Cmd+T 风格）──
-- LSP 支持 workspace/symbol（TS/rust 等）→ 用 LSP 精确符号；
-- 否则（nix/lua/elm/无 LSP）→ 降级为 grep 文本搜索（rg，跨文件，输入词即搜）。
-- nix 的 nil / lua 的 lua_ls 均无 workspaceSymbolProvider，降级让 <leader>fS 始终可用。
local function workspace_symbols_or_grep()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local supported = false
  for _, client in ipairs(clients) do
    if client.supports_method and client.supports_method("workspace/symbol") then
      supported = true
      break
    end
  end
  if supported then
    Snacks.picker.lsp_workspace_symbols()
  else
    -- 降级：grep 搜光标词（可编辑）。search/pattern 预填当前词。
    -- <cword> 在符号上（如 nix 的 { }）会返回纯符号，此时不预填，让用户输入。
    local word = vim.fn.expand("<cword>"):match("^%s*(.-)%s*$") or ""
    if word == "" or not word:find("%w") then
      Snacks.picker.grep()
    else
      Snacks.picker.grep({ pattern = word, search = word })
    end
  end
end

lmap("<leader>fS", workspace_symbols_or_grep, { desc = "Workspace symbol search (LSP or grep fallback)" })

-- ── LSP 跳转（AstroNvim 用 gi，LazyVim 默认用 gI；补 gi 兼容肌肉记忆）──
map("n", "gi", vim.lsp.buf.implementation, { desc = "Goto Implementation" })

-- ── 智能缩进增量选择（原 polish.lua setup_incremental_selection；LazyVim treesitter 无此，重建）──
-- 用 nvim-treesitter-textobjects? 不，保持 C-space/bs 手动方案
do
  local api = vim.api
  local current_node = nil
  local function node_at_cursor()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    return vim.treesitter.get_node({ bufnr = 0, row = row - 1, col = col })
  end
  local function select_node(node)
    if not node then
      return
    end
    current_node = node
    local sr, sc, er, ec = node:range()
    local mode = api.nvim_get_mode().mode
    if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
      vim.cmd("normal! v")
    end
    api.nvim_win_set_cursor(0, { sr + 1, sc })
    vim.cmd("normal! o")
    local end_col
    if ec > 0 then
      end_col = ec - 1
    else
      local line = api.nvim_buf_get_lines(0, er, er + 1, false)[1]
      end_col = line and (#line - 1) or 0
    end
    api.nvim_win_set_cursor(0, { er + 1, math.max(end_col, 0) })
  end
  local function expand()
    local mode = api.nvim_get_mode().mode
    local visual = mode == "v" or mode == "V" or mode == "\22"
    if not visual or not current_node then
      local node = node_at_cursor()
      if node then
        select_node(node)
      end
      return
    end
    local parent = current_node:parent()
    if parent then
      select_node(parent)
    end
  end
  local function shrink()
    if not current_node then
      return
    end
    if current_node:named_child_count() > 0 then
      select_node(current_node:named_child(0))
    end
  end
  map({ "n", "x" }, "<C-space>", expand, { desc = "Treesitter: increment selection" })
  map("x", "<bs>", shrink, { desc = "Treesitter: decrement selection" })
end

-- ── 光标形状（原 polish.lua：insert 竖线）──
vim.opt.guicursor = "n-v-c:block,i:ver50,ci:ver50,ve:ver50,o:block,a:blinkon100"

-- ── 反斜杠 \ 启动命令行 (2026-09-05, 用户嫌 : 要按 Shift) ──
-- \ 在 n/x/o/i 全空闲(实测), 回车键上方单手好按。映射 normal 下 \ → :。
map("n", "\\", ":", { desc = "Command line (replaces :)" })
map("x", "\\", ":", { desc = "Command line (replaces :)" })

-- ── 退出前停 LSP（原 astrocore autocmds VimLeavePre，治孤儿进程）──
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    for _, client in ipairs(vim.lsp.get_clients()) do
      pcall(vim.lsp.stop_client, client, true)
    end
  end,
  desc = "Stop all LSP clients on exit (fix orphan processes)",
})

-- ── 返回 Dashboard (2026-09-05) ──
-- LazyVim 无现成"回 dashboard"键; <leader>D 空闲(查过 LazyVim + 用户 keymaps)。
-- 注: snacks.dashboard.open() 内部会用 vim.cmd 操作当前 buffer, 若在不可修改的
-- buffer (dashboard/neo-tree/help) 上触发会 E21。先确保当前 buffer 可改或已切走。
map("n", "<leader>D", function()
  -- 若当前 buffer 不可修改 (dashboard/neo-tree/help 等), 先建个临时可改 buffer 再开
  if not vim.bo.modifiable then
    pcall(vim.cmd, "enew")
  end
  local ok, err = pcall(function()
    require("snacks.dashboard").open()
  end)
  if not ok then
    vim.notify("Dashboard open failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end, { desc = "Dashboard" })

