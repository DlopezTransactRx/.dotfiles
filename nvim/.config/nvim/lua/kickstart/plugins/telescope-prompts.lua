return {
  'oleksiiluchnikov/telescope-prompts.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim', -- Required by Telescope
    -- "yetone/avante.nvim",  -- Optional for AI integration
  },
  vim.keymap.set('n', '<leader>ap', '<cmd>Telescope prompts<cr>', {
    desc = 'Browse AI Prompts',
  }),
  config = function()
    require('telescope').load_extension 'prompts'
  end,
}
