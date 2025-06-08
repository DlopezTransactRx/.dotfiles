return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'github/copilot.vim' },
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      panel = { enabled = true }, -- Enable the CopilotChat panel
    },
    config = function(_, opts)
      require('CopilotChat').setup(opts)

      -- Keymap to toggle CopilotChat
      vim.keymap.set('n', '<leader>cc', ':CopilotChat<CR>', { noremap = true, silent = true })

      -- Configure Tab key for copilot.vim suggestions
      vim.g.copilot_no_tab_map = true
      vim.api.nvim_set_keymap('i', '<A-y>', 'copilot#Accept("<CR>")', { silent = true, expr = true })
    end,
  },
}
