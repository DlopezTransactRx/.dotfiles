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

      -- Keymap to accept autocomplete suggestions
      -- vim.keymap.set('i', '<C-l>', 'copilot#Accept("<CR>")', { noremap = true, silent = true, expr = true })
    end,
  },
}
