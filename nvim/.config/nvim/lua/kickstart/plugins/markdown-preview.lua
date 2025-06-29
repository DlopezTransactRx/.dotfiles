-- install with yarn or npm
return {
  'iamcco/markdown-preview.nvim',
  cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
  build = 'cd app && yarn install',
  keys = {
    { '<leader>pt', '<cmd>MarkdownPreviewToggle<cr>', desc = 'Markdown Preview' },
  },
  init = function()
    vim.g.mkdp_filetypes = { 'markdown' }
  end,
  ft = { 'markdown' },
}
