return {
  'christoomey/vim-tmux-navigator',
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatePrevious',
    'TmuxNavigatorProcessList',
  },
  keys = {
    { '<c-M-S-h>', '<cmd><C-U>TmuxNavigateLeft<cr>' },
    { '<c-M-S-j>', '<cmd><C-U>TmuxNavigateDown<cr>' },
    { '<c-M-S-k>', '<cmd><C-U>TmuxNavigateUp<cr>' },
    { '<c-M-S-l>', '<cmd><C-U>TmuxNavigateRight<cr>' },
    { '<c-M-S-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>' },
  },
}

