-- neo-tree 个性化（原 AstroNvim user.lua 迁移）
-- LazyVim editor.neo-tree extra 已提供默认（<leader>e 打开、git 状态等），
-- 这里只保留你 AstroNvim 时期的核心偏好：跟随当前文件 + 显示隐藏文件。

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      -- 注册 seq 组件: buffers 列表显示连续序号 1、2、3 (2026-09-05)
      -- 序号 = 该 buffer 在 listed buffers 中的位置 (与 <leader>1-9 数字切换同一顺序),
      -- 使列表视觉编号与 空格+数字 快捷键一致。neo-tree 默认显示 #真实bufnr (#4/#9 乱号)。
      local ok_c, comps = pcall(require, "neo-tree.sources.buffers.components")
      if ok_c and comps and not comps.seq then
        local nt_hl = require("neo-tree.ui.highlights")
        comps.seq = function(config, node, _)
          local bufnr = node.extra and node.extra.bufnr
          if not bufnr then
            return {}
          end
          -- 与 keymaps.lua 数字映射同序: listed 且有名, 按 buffer 编号升序
          local listed = vim.tbl_filter(function(b)
            return b.listed == 1 and b.name ~= ""
          end, vim.fn.getbufinfo({ buflisted = 1 }))
          for i, b in ipairs(listed) do
            if b.bufnr == bufnr then
              return {
                text = string.format("%d", i),
                highlight = config.highlight or nt_hl.BUFFER_NUMBER,
              }
            end
          end
          return {}
        end
      end

      -- buffers 列表按 buffer 编号从小到大排 (2026-09-05)
      -- neo-tree 默认按文件名(path)排 buffers; 用户要求按编号。全局 sort_function 分流:
      -- 有 extra.bufnr 的节点(=buffers source 的 file 项)按编号排, 其余(文件树等)保持默认 path 排。
      opts.sort_function = function(a, b)
        local ab, bb = a.extra and a.extra.bufnr, b.extra and b.extra.bufnr
        if ab and bb then
          return ab < bb
        end
        -- 一侧有 extra.bufnr 时给确定顺序 (仅 buffers 节点带, 防御性触发, 避免落入 path 比较)
        if ab or bb then
          return ab ~= nil
        end
        if a.type == b.type then
          -- 兜底: message/terminal 等节点可能无 path, 回落 name, 避免 nil < string 抛错
          return (a.path or a.name) < (b.path or b.name)
        else
          return (a.type or "") < (b.type or "")
        end
      end

      opts.filesystem = vim.tbl_deep_extend("force", opts.filesystem or {}, {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          visible = true, -- 显示隐藏文件
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            ".git",
            "node_modules",
            ".DS_Store",
            "thumbs.db",
          },
        },
      })
      opts.buffers = vim.tbl_deep_extend("force", opts.buffers or {}, {
        follow_current_file = { enabled = true },
        -- 覆盖 buffers source 的 file 渲染: 默认显示 #真实bufnr, 改为显示 seq (连续序号 1、2、3)
        renderers = {
          file = {
            { "indent" },
            { "icon" },
            {
              "container",
              content = {
                { "seq", zindex = 10 },
                { "name", zindex = 10 },
                { "clipboard", zindex = 10 },
                { "modified", zindex = 20, align = "right" },
                { "diagnostics", zindex = 20, align = "right" },
                { "git_status", zindex = 10, align = "right" },
              },
            },
          },
        },
      })
    end,
  },
}
