-- blink.cmp 补全（LazyVim 默认补全就是 blink，这里覆盖为 VS Code 风格）
-- 原 AstroNvim lua/plugins/blink.lua 迁移
-- LazyVim blink extra 默认 preset="enter"；我们保持 VS Code 习惯：
--   - Tab 只做 snippet 占位导航
--   - ghost_text 灰显预览（VS Code 标志）
--   - 签名提示开（blink signature；替代 lsp_signature）
--   - 2026-09-04: 取消补全后 Rust 自动补 ';'（accept_with_semicolon 已移除）

return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      -- LuaSnip 引擎（extra 已注入 LuaSnip+friendly-snippets+vscode loader；
      -- 覆盖内置 vim.snippet——0.12.4 上跳 $0 占位会 invalid-extmark 崩溃）
      opts.snippets = opts.snippets or {}
      opts.snippets.preset = "luasnip"
      if opts.snippets.preset == "luasnip" then
        opts.snippets.expand = function(snippet)
          require("luasnip").lsp_expand(snippet)
        end
      end

      -- 默认 sources 基础上微调（保留 lsp/path/snippets/buffer 顺序）
      opts.sources = opts.sources or {}
      opts.sources.providers = vim.tbl_deep_extend("force", opts.sources.providers or {}, {
        snippets = {
          score_offset = 1,
          opts = {
            -- 列表项 label 旁显示 snippet description, 区分同名 snippet (如自定义 fn vs RA fn)
            use_label_description = true,
          },
        },
        lsp = {
          score_offset = 0,
          -- 屏蔽 RA (rust-analyzer) 的重复关键字 snippet 项, 只留自定义 vscode snippet。
          -- 只 block 已自定义覆盖的: if/let/for/while/match/loop/impl/struct/enum。
          -- ⚠️ else 不 block — 无自定义 else。fn 已 block: 自定义 fn 加回 (2026-09-06), 只留自定义。
          -- 2026-09-06
          -- 2026-09-06: sortText 屏蔽 — 真实"按选择频次排序"前提
          -- RA 给每个补全项带 sortText (LSP server 端的"应选顺序"，如把私有方法排后)，
          -- blink fuzzy 的 default sorts = { 'score', 'sort_text' } 中 sort_text 在
          -- score 接近时强制接管排序, 完全压过 frecency 加成 (frecency 最多 +6, fuzzy
          -- match 分动辄几十上百, 一旦 sortText 介入 frecency 几乎无效)。
          -- 屏蔽 sortText 后排序 = match_score + frecency_score + nearby + score_offset,
          -- 高频选过的项会稳定浮到顶端。
          transform_items = function(_, items)
            local blocked = {
              ["if"] = true, ["let"] = true, ["let mut"] = true, ["for"] = true,
              ["while"] = true, ["match"] = true, ["loop"] = true, ["impl"] = true,
              ["struct"] = true, ["enum"] = true, ["fn"] = true,
            }
            for _, item in ipairs(items) do
              item.sortText = nil
            end
            local ret = {}
            for _, item in ipairs(items) do
              local is_snippet = item.kind == vim.lsp.protocol.CompletionItemKind.Snippet
              local is_keyword = item.kind == vim.lsp.protocol.CompletionItemKind.Keyword
              -- RA 的关键字项 kind 可能是 Snippet 或 Keyword, 两者都滤
              if not ((is_snippet or is_keyword) and blocked[item.label]) then
                ret[#ret + 1] = item
              end
            end
            return ret
          end,
        },
        path = { score_offset = 2 },
        buffer = { score_offset = -3 },
      })

      -- VS Code 风格按键
      opts.keymap = opts.keymap or {}

      -- Tab 自定义：snippet 占位导航 + “跳出右括号”
      -- 行为（2026-09-04）：在 snippet 内按 Tab：
      --   1) 有下一占位符 → ls.jump(1) 正常跳
      --   2) jump 后当前节点是 exitNode(type=8, LuaSnip 隐含的 "snippet 结束" 节点，
      --      位于右括号后) → 光标移到该节点 mark 结束位（= 跳出括号），并结束会话
      --   3) 不在 snippet → fallback（缩进）
      -- 实测依据（2026-09-04）：Some($1) 空占位展开后 jumpable(1)=true，但 jump(1) 只把
      -- current_nodes 移到隐含 exitNode，LuaSnip 不负责把光标移到 exit 位置 → 光标卡在 )
      -- 内。必须检测 exitNode 后手动补移光标。
      opts.keymap["<Tab>"] = {
        function(cmp)
          local ls_ok, ls = pcall(require, "luasnip")
          local sess_ok, session = pcall(require, "luasnip.session")
          if not (ls_ok and sess_ok) then
            return false
          end
          local buf = vim.api.nvim_get_current_buf()
          local node = session.current_nodes[buf]
          local has_session = node ~= nil
          local menu_visible = cmp.is_menu_visible()

          -- Tab-out helper (2026-09-05): 光标右侧是自动补的配对符 (引号/小括号/方括号)
          -- 时右移跳出。⚠️ 排除 { } — 块边界不该被 Tab 跳出 (fn snippet 的 $3
          -- 停靠依赖光标停在 ) { 之间)。
          local function try_tabout()
            local p = vim.api.nvim_win_get_cursor(0)
            local l = vim.api.nvim_get_current_line()
            local r = l:sub(p[2] + 1, p[2] + 1)
            if r == '"' or r == "'" or r == ")" or r == "]" then
              -- ⚠️ 必须 vim.schedule: blink 的 <Tab> 映射是 expr 映射, 在 expr 回调里
              -- 同步移光标会被 nvim 丢弃 (实测: 直接调 callback 能动, 真按键纹丝不动)
              vim.schedule(function()
                vim.api.nvim_win_set_cursor(0, { p[1], p[2] + 1 })
              end)
              return true
            end
            return false
          end

          -- 有会话: 跳 snippet 占位优先。
          if has_session then
            -- ── 跨行占位符 guard (2026-09-11) ──
            -- 在占位符里按 <CR>, 换行符会成为占位符文本的一部分 → node.mark 跨行。
            -- 此后 Tab 若还当成「跳下个占位符」, 光标会从当前编辑行跳到下一个占位符
            -- 所在的行 (用户报的「用 tab 缩进时会跳到别的行」), 甚至跳到 snippet 末尾。
            -- 判定 = 当前占位符跨行 (mark 起止不在同一行) → 用户已在里面自由换行编辑,
            -- 会话不再代表「占位符巡览」: 清掉会话 + 放行 fallback(缩进)。
            -- ⚠️ 不能只判「光标在行首(0 列)」: 新行有自动缩进(如 rust 4 空格), 光标
            -- 停在缩进末尾 4 列, 那个条件根本不成立 (2026-09-11 第一版就踩了这个)。
            -- 单行占位符不受影响 → 占位符跳转/Tab-out 行为完全保留。
            if node.type ~= 8 and node.type ~= 0 then
              local okg, gb, ge = pcall(node.mark.pos_begin_end, node.mark)
              if okg and gb and ge and ge[1] > gb[1] then
                pcall(ls.unlink_current)
                return false
              end
            end
            local pos = vim.api.nvim_win_get_cursor(0)
            local row, col = pos[1] - 1, pos[2]
            -- exitNode(type=8)/0 是虚拟节点 (展开后会话刚建或编辑后 current node
            -- 回退到 exit)。不能直接 jump (exit.next=nil → jump 会清会话 = 没反应)。
            -- 改为: 遍历 snippet 的 insertNode, 找光标所在/之后的占位符设为 current,
            -- 再 jump — 光标在最后占位时 jump 不到 → 光标移到 snippet 末尾 (分号后)。
            if node.type == 8 or node.type == 0 then
              vim.schedule(function()
                local snip = node.parent and node.parent.snippet
                if not snip then
                  pcall(ls.unlink_current)
                  return
                end
                -- 递归收集所有 insertNode (type=2)
                local inserts = {}
                local function collect(n)
                  for _, child in ipairs(n.nodes or {}) do
                    if child.type == 2 then
                      inserts[#inserts + 1] = child
                    elseif child.nodes then
                      collect(child)
                    end
                  end
                end
                collect(snip)
                if #inserts == 0 then
                  pcall(ls.unlink_current)
                  return
                end
                -- 找光标所在占位符 (row/col 0-based)
                local pos = vim.api.nvim_win_get_cursor(0)
                local row, col = pos[1] - 1, pos[2]
                local target
                for _, ins in ipairs(inserts) do
                  local okm, b, e = pcall(ins.mark.pos_begin_end, ins.mark)
                  if okm and b and e then
                    local in_b = row > b[1] or (row == b[1] and col >= b[2])
                    local in_e = row < e[1] or (row == e[1] and col <= e[2])
                    if in_b and in_e then
                      target = ins
                      break
                    end
                  end
                end
                -- 手动把 current node 设为光标所在占位, 然后正常 jump
                if target then
                  session.current_nodes[buf] = target
                  vim.schedule(function()
                    if ls.jumpable(1) then
                      ls.jump(1)
                      return
                    end
                    -- 最后占位无下一跳: 光标移到 snippet 末尾收尾
                    local okp, p = pcall(function() return snip.mark:pos_end() end)
                    if okp and p and p[1] ~= nil and p[2] ~= nil then
                      vim.api.nvim_win_set_cursor(0, { p[1] + 1, p[2] })
                    end
                    pcall(ls.unlink_current)
                  end)
                  return
                end
                -- 光标不在任何占位内 (如占位后/分号前) → 移到 snippet 末尾收尾
                local okp, p = pcall(function() return snip.mark:pos_end() end)
                if okp and p and p[1] ~= nil and p[2] ~= nil then
                  vim.api.nvim_win_set_cursor(0, { p[1] + 1, p[2] })
                end
                pcall(ls.unlink_current)
              end)
              return true
            end
            local okm, begin_pos, end_pos = pcall(node.mark.pos_begin_end, node.mark)
            if okm and begin_pos and end_pos then
              local in_node = row > begin_pos[1] or (row == begin_pos[1] and col >= begin_pos[2])
              local in_node_end = row < end_pos[1] or (row == end_pos[1] and col <= end_pos[2])
              if in_node and in_node_end then
                -- 光标在占位符内 → 跳下一占位 (tabout 不抢)
                vim.schedule(function()
                  local jumped = false
                  if ls.jumpable(1) then
                    ls.jump(1)
                    jumped = true
                  end
                  local node = session.current_nodes[buf]
                  -- 判断是否已到 snippet 末尾: 无下一占位可跳 / current 是 exitNode /
                  -- 会话已结束。此时光标应落在 snippet 末尾 (分号后)。
                  local at_end = not ls.in_snippet() or not jumped
                    or (node and node.type == 8)
                  if at_end then
                    -- 用 node 链找 snippet, 光标移到 snippet mark 结束位
                    local snip = node and node.parent and node.parent.snippet
                    if snip and snip.mark then
                      local okp, p = pcall(function() return snip.mark:pos_end() end)
                      if okp and p and p[1] ~= nil and p[2] ~= nil then
                        vim.api.nvim_win_set_cursor(0, { p[1] + 1, p[2] })
                      end
                    end
                    pcall(ls.unlink_current)
                    return
                  end
                end)
                return true
              end
            end
            -- 光标不在占位符内: 试 tabout; 不中 → 清会话放行
            if try_tabout() then
              return true
            end
            pcall(ls.unlink_current)
            return false
          end

          -- 无会话: tabout (跳出自动补配对符) 优先于 fallback; 菜单开着也生效
          if try_tabout() then
            return true
          end

          -- 菜单可见 + 无会话 → 不劫持 (正常补全选择)
          if menu_visible then
            return false
          end

          return false -- 无会话无菜单 → fallback（缩进）
        end,
        "fallback",
      }
      -- S-Tab：snippet 反向 / 反缩进
      opts.keymap["<S-Tab>"] = { "snippet_backward", "fallback" }
      -- CR：菜单可见 -> 接受补全；否则换行（VS Code 同款：Enter 确定）。
      -- 2026-09-04 移除 accept_with_semicolon：补全后不再自动补 ';'（用户不想要）。
      opts.keymap["<CR>"] = { "accept", "fallback" }

      opts.completion = opts.completion or {}
      opts.completion.list = opts.completion.list or {}
      -- preselect 高亮但不自动插入（VS Code 行为）
      opts.completion.list.selection = { preselect = true, auto_insert = false }
      -- 灰显预览
      -- ⚠️ 2026-09-04: ghost_text 与 LuaSnip 占位跳转冲突 (extmark 竞争,
      -- 日志 mark.lua:82/35/136 崩溃 + for snippet Tab 跳转插入幽灵文本)。
      -- 暂关, 观察 Tab 跳转是否恢复稳定。
      -- opts.completion.ghost_text = { enabled = true }

      -- 签名提示（blink 原生；LazyVim 默认 signature=false，开之）
      opts.signature = opts.signature or {}
      opts.signature.enabled = true
      opts.signature.window = opts.signature.window or {}
      -- 优先在光标下方弹出（默认 {'n','s'} 会向上盖住代码）
      opts.signature.window.direction_priority = { "s", "n" }
      -- 限制高度，避免大面积遮挡
      opts.signature.window.max_height = 8

      -- 强制 Rust fuzzy 实现（2026-09-05）
      -- 现象：frecency（按使用频率排序）完全无效。根因：blink 默认 prefer_rust_with_warning，
      -- 启动时 ensure_downloaded 的异步决策未切到 rust（dylib 能 require、checksum 匹配，
      -- 但 implementation_type 停在 lua），而 frecency 只在 rust 实现生效。
      -- 修复：显式 prefer_rust，dylib 已就绪（target/release/libblink_cmp_fuzzy.dylib，
      -- checksum 已验证匹配），加载失败会报错而不是静默降级。
      opts.fuzzy = opts.fuzzy or {}
      opts.fuzzy.implementation = "prefer_rust"
    end,
  },
}
