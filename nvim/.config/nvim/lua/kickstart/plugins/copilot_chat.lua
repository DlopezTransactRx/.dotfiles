return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'github/copilot.vim' }, -- or zbirenbaum/copilot.lua
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      panel = { enabled = true }, -- Enable the CopilotChat panel
      suggestion = { enabled = true }, -- Enable suggestions
    },
    config = function(_, opts)
      require('CopilotChat').setup(opts)

      -- Keymap to toggle CopilotChat
      vim.keymap.set('n', '<leader>cc', ':CopilotChat<CR>', { noremap = true, silent = true })
      vim.g.copilot_no_tab_map = true
      vim.api.nvim_set_keymap('i', '<Tab>', 'v:lua.require("copilot.suggestion").accept()', { silent = true, expr = true })
    end,
  },
}
