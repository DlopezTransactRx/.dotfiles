-- Neotest: run tests from the editor and see the suite's state at a glance.
--
-- Adapter note: neotest-golang, not neotest-go. The older neotest-go is
-- effectively unmaintained and mishandles table-driven tests and subtests,
-- which is most of how Go tests are actually written.
--
-- Keymaps live under <leader>T ([T]est); <leader>t is already the [T]oggle group.
return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'fredrikaverpil/neotest-golang',
  },
  keys = {
    {
      '<leader>Tr',
      function()
        require('neotest').run.run()
      end,
      desc = '[T]est: [r]un nearest',
    },
    {
      '<leader>Tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = '[T]est: run [f]ile',
    },
    {
      '<leader>Ta',
      function()
        require('neotest').run.run(vim.uv.cwd())
      end,
      desc = '[T]est: run [a]ll',
    },
    {
      '<leader>Tl',
      function()
        require('neotest').run.run_last()
      end,
      desc = '[T]est: run [l]ast',
    },
    {
      '<leader>Ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = '[T]est: toggle [s]ummary',
    },
    {
      '<leader>To',
      function()
        require('neotest').output.open { enter = true, auto_close = true }
      end,
      desc = '[T]est: show [o]utput',
    },
    {
      '<leader>TO',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = '[T]est: toggle [O]utput panel',
    },
    {
      '<leader>TC',
      function()
        require('neotest').output_panel.clear()
      end,
      desc = '[T]est: [C]lear output panel',
    },
    {
      '<leader>TS',
      function()
        require('neotest').run.stop()
      end,
      desc = '[T]est: [S]top',
    },
    {
      -- Reuses the dap config already set up in kickstart.plugins.debug, so a
      -- failing test can be stepped through without leaving the buffer.
      '<leader>Td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = '[T]est: [d]ebug nearest',
    },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-golang' {
          -- -race catches the concurrency bugs that only show up under load;
          -- cheap enough to leave on for editor-driven runs.
          go_test_args = { '-v', '-race', '-count=1' },
        },
      },
      -- Mark failures inline on the offending line rather than only in a panel.
      status = { virtual_text = true },
      output = { open_on_run = false },
    }
  end,
}
