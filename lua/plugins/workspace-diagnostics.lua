-- workspace-diagnostics.nvim：给"没打开的文件"也出诊断（参考 Sam Natale 配置）
-- 默认 LSP 只诊断已打开的 buffer；TS 这类项目里没打开的文件有错看不出来。
-- nvim 0.12 自带 vim.lsp.buf.workspace_diagnostics()（已实测存在），
-- client 原生支持 workspace/diagnostic 时走内置 API，否则用插件补齐。
-- 每个 client 只跑一次（原生路径自己表去重）。
local handled = {}

local function populate(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if not handled[client.id] and client.attached_buffers and next(client.attached_buffers) then
      handled[client.id] = true
      if client:supports_method("workspace/diagnostic", bufnr) then
        pcall(vim.lsp.buf.workspace_diagnostics, { client_id = client.id })
      else
        pcall(function()
          require("workspace-diagnostics").populate_workspace_diagnostics(client, bufnr)
        end)
      end
    end
  end
end

return {
  {
    "artemave/workspace-diagnostics.nvim",
    event = "LspAttach",
    config = function()
      -- 当前这次 attach 直接处理（autocmd 在事件处理中注册不会为同一事件再次触发）
      vim.schedule(function()
        populate(vim.api.nvim_get_current_buf())
      end)
      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "Workspace diagnostics for new LSP clients",
        callback = function(args)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              populate(args.buf)
            end
          end)
        end,
      })
    end,
  },
}
