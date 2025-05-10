return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  lazy = true,
  config = function()
    require('nvim-treesitter.configs').setup {
      vim.keymap.set('n', '<leader>ti', ':InspectTree<CR>', { desc = 'Inspect Tree' }),

      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {

            -- Assignment Text
            ['a='] = { query = '@assignment.outer', desc = 'Select outer part of an assignment' },
            ['i='] = { query = '@assignment.inner', desc = 'Select inner part of an assignment' },
            ['l='] = { query = '@assignment.lhs', desc = 'Select left hand side of an assignment' },
            ['r='] = { query = '@assignment.inner', desc = 'Select assignment' },

            -- Function Text
            ['af'] = { query = '@function.outer', desc = 'Select outer part of a function' },
            ['if'] = { query = '@function.inner', desc = 'Select inner part of a function' },

            -- Arguments Text
            ['aa'] = { query = '@parameter.outer', desc = 'Select outer part of a parameter' },
            ['ia'] = { query = '@parameter.inner', desc = 'Select inner part of a parameter' },

            -- Conditional Text
            ['ai'] = { query = '@conditional.outer', desc = 'Select outer part of a conditional' },
            ['ii'] = { query = '@conditional.inner', desc = 'Select inner part of a conditional' },

            -- Loop Text
            ['al'] = { query = '@loop.outer', desc = 'Select outer part of a loop' },
            ['il'] = { query = '@loop.inner', desc = 'Select inner part of a loop' },

            -- Class Text
            ['ac'] = { query = '@class.outer', desc = 'Select outer part of a class' },
            ['ic'] = { query = '@class.inner', desc = 'Select inner part of a class' },

            -- Block Text
            ['ab'] = { query = '@block.outer', desc = 'Select outer block.' },
            ['ib'] = { query = '@block.inner', desc = 'Selet inner block.' },
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ['<leader>na'] = { query = '@parameter.inner', desc = 'Swap next parameter' },
            ['<leader>nf'] = { query = '@function.outer', desc = 'Swap next function' },
          },
          swap_previous = {
            ['<leader>pa'] = { query = '@parameter.inner', desc = 'Swap previous parameter' },
            ['<leader>pf'] = { query = '@function.outer', desc = 'Swap previous function' },
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            [']a'] = { query = '@assignment.outer', desc = 'Next assignment' },
            [']f'] = { query = '@function.outer', desc = 'Next function' },
            [']i'] = { query = '@conditional.outer', desc = 'Next conditional' },
            [']l'] = { query = '@loop.outer', desc = 'Next loop' },
            [']c'] = { query = '@class.outer', desc = 'Next class' },
            [']b'] = { query = '@block.outer', desc = 'Next block' },
          },
          goto_next_end = {
            [']A'] = { query = '@assignment.outer', desc = 'Next assignment end' },
            [']F'] = { query = '@function.outer', desc = 'Next function end' },
            [']I'] = { query = '@conditional.outer', desc = 'Next conditional end' },
            [']L'] = { query = '@loop.outer', desc = 'Next loop end' },
            [']C'] = { query = '@class.outer', desc = 'Next class end' },
            [']B'] = { query = '@block.outer', desc = 'Next block end' },
          },
          goto_previous_start = {
            ['[a'] = { query = '@assignment.outer', desc = 'Previous assignment' },
            ['[f'] = { query = '@function.outer', desc = 'Previous function' },
            ['[i'] = { query = '@conditional.outer', desc = 'Previous conditional' },
            ['[l'] = { query = '@loop.outer', desc = 'Previous loop' },
            ['[c'] = { query = '@class.outer', desc = 'Previous class' },
            ['[b'] = { query = '@block.outer', desc = 'Previous block' },
          },
          goto_previous_end = {
            ['[A'] = { query = '@assignment.outer', desc = 'Previous assignment end' },
            ['[F'] = { query = '@function.outer', desc = 'Previous function end' },
            ['[I'] = { query = '@conditional.outer', desc = 'Previous conditional end' },
            ['[L'] = { query = '@loop.outer', desc = 'Previous loop end' },
            ['[C'] = { query = '@class.outer', desc = 'Previous class end' },
            ['[B'] = { query = '@block.outer', desc = 'Previous block end' },
          },
        },
      },
    }
  end,
}
