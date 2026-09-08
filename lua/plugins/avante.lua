-- avante.nvim — Cursor 式 AI 助手（聊天 + 行内编辑 + Agent 模式）
-- 2026-09-08 自装。注意：不用 LazyVim extras/ai/avante 的 import ——
-- 那个 extra 会把 blink.cmp sources.default 强制覆盖为 { "avante" }，
-- 挤掉 lsp/path/snippets/buffer 补全源。这里自己写 spec，完全可控。
-- Provider：CommandCode AI（OpenAI 兼容 chat/completions，
--   key 在 config/secrets.lua，gitignore 不提交）
-- 模型注意：claude-*/gpt-5.6-luna 当前套餐不可用（403），可用的是
--   zai-org/GLM-5.2（默认）、deepseek/deepseek-v4-pro、deepseek-v4-flash、
--   moonshotai/Kimi-K3、Qwen/Qwen3.8-Max 等。切换用 <leader>am。

return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = function()
      -- 本地密钥文件（不入库）：设置 vim.env.COMMANDCODE_API_KEY
      pcall(require, "config.secrets")

      return {
        provider = "commandcode",
        model = "zai-org/GLM-5.2",
        selection = {
          hint_display = "none",
        },
        behaviour = {
          auto_set_keymaps = false,
        },
        providers = {
          commandcode = {
            __inherited_from = "openai",
            api_key_name = "COMMANDCODE_API_KEY",
            endpoint = "https://api.commandcode.ai/provider/v1",
            model = "zai-org/GLM-5.2",
          },
        },
      }
    end,
    config = function(_, opts)
      require("avante").setup(opts)
      -- 隐藏聊天窗口里的中间工具调用卡片（Agent 照常执行，只是不刷屏显示）
      local ok, Sidebar = pcall(require, "avante.sidebar")
      local okh, Helpers = pcall(require, "avante.history.helpers")
      if ok and okh then
        local orig_get_message_lines = Sidebar.get_message_lines
        Sidebar.get_message_lines = function(self, ctx, message, messages, ignore_record_prefix)
          if Helpers.is_tool_use_message(message) then
            return {}
          end
          return orig_get_message_lines(self, ctx, message, messages, ignore_record_prefix)
        end
      end
    end,
    keys = {
      { "<leader>aa", "<cmd>AvanteAsk<CR>", desc = "Ask Avante" },
      { "<leader>ac", "<cmd>AvanteChat<CR>", desc = "Chat with Avante" },
      { "<leader>ae", "<cmd>AvanteEdit<CR>", desc = "Edit Avante" },
      { "<leader>af", "<cmd>AvanteFocus<CR>", desc = "Focus Avante" },
      { "<leader>ah", "<cmd>AvanteHistory<CR>", desc = "Avante History" },
      { "<leader>am", "<cmd>AvanteModels<CR>", desc = "Select Avante Model" },
      { "<leader>an", "<cmd>AvanteChatNew<CR>", desc = "New Avante Chat" },
      { "<leader>ap", "<cmd>AvanteSwitchProvider<CR>", desc = "Switch Avante Provider" },
      { "<leader>ar", "<cmd>AvanteRefresh<CR>", desc = "Refresh Avante" },
      { "<leader>as", "<cmd>AvanteStop<CR>", desc = "Stop Avante" },
      { "<leader>at", "<cmd>AvanteToggle<CR>", desc = "Toggle Avante" },
    },
  },
}
