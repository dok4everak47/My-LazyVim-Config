-- tiny-code-action.nvim：code action 先看 diff 预览再决定应用（参考 Sam Natale 配置）
-- 背景：LazyVim 16 的 <leader>ca 不是自己 set 的，而是把它写在 vim.lsp.config("*").keys 里、
--       由 nvim 在 LspAttach 时注册（lazyvim/plugins/lsp/init.lua:88）。实测：在 LspAttach 里
--       vim.schedule/vim.defer_fn 抢注 buffer-local map 都盖不住它（nvim 的注册更晚）。
-- 所以改成从源头替换：在 nvim-lspconfig 的 opts 里把那条 keys 条目换成走 tiny-code-action。
-- backend = "vim"：用 nvim 内置 diff（官方说明 delta 后端在大 action 时更慢）。
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local star = opts.servers and opts.servers["*"]
      if not (star and star.keys) then
        return
      end
      -- 重建列表（避免原地改可能被共享的表），剔除原生 code action 条目
      local kept = {}
      for _, k in ipairs(star.keys) do
        if k[1] ~= "<leader>ca" then
          kept[#kept + 1] = k
        end
      end
      kept[#kept + 1] = {
        "<leader>ca",
        function()
          require("tiny-code-action").code_action()
        end,
        desc = "Code Action (diff 预览)",
        mode = { "n", "x" },
        has = "codeAction",
      }
      star.keys = kept
    end,
  },

  {
    "rachartier/tiny-code-action.nvim",
    event = "LspAttach",
    opts = {
      backend = "vim",
      picker = "snacks",
      resolve_timeout = 200,
      notify = { enabled = true, on_empty = true },
    },
  },
}
