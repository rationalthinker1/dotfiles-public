-- after/plugin/dap-keymaps.lua — debugger keys, and the lazy load behind them.
--
-- WHY THE LOAD IS DONE HERE AND NOT WITH lazy.on_cmd()
--
-- nvim-dap creates its own :DapContinue, :DapToggleBreakpoint etc. from its
-- plugin/ file, which packloadall sources AFTER init.lua. Stub commands
-- registered in init.lua would therefore be silently overwritten by the real
-- ones — which exist but have no adapters configured, so they would fail at
-- the moment of use. The keys wrap the load instead: first press requires
-- lua/plugins/dap.lua (idempotent, `require` caches), then acts.
--
-- KEY CHOICE: VSCode spelling, not IntelliJ.
--
-- IntelliJ debugging is F7/F8/Shift+F8/Ctrl+F8, but this config already binds
-- F7 to spell-check and F8/Shift+F8 to next/previous problem — all three are
-- long-standing and used far more often than a debugger. VSCode's F5/F9/F10/F11
-- set is entirely free by comparison, and is the more universal spelling
-- anyway. The IntelliJ forms that ARE free (Ctrl+F8, Ctrl+F2, Alt+F8) are
-- bound as aliases.
--
-- The one displacement: F5 was UndotreeToggle, which moves to <leader>u.
-- F5 = start debugging is close to universal and worth the swap.

local function dap()
  require('plugins.dap')
  return require('dap')
end

local map = vim.keymap.set

-- Start / continue                F5        (VSCode) · Shift+F9 (IntelliJ)
map('n', '<F5>', function() dap().continue() end, { desc = 'Debug: start/continue' })
map('n', '<S-F9>', function() dap().continue() end, { desc = 'Debug: start/continue' })
-- Stop                            Shift+F5  (VSCode) · Ctrl+F2 (IntelliJ)
map('n', '<S-F5>', function() dap().terminate() end, { desc = 'Debug: stop' })
map('n', '<C-F2>', function() dap().terminate() end, { desc = 'Debug: stop' })
-- Restart                         Ctrl+Shift+F5
map('n', '<C-S-F5>', function() dap().restart() end, { desc = 'Debug: restart' })

-- Breakpoints                     F9 (VSCode) · Ctrl+F8 (IntelliJ)
map('n', '<F9>', function() dap().toggle_breakpoint() end, { desc = 'Debug: toggle breakpoint' })
map('n', '<C-F8>', function() dap().toggle_breakpoint() end, { desc = 'Debug: toggle breakpoint' })
map('n', '<S-F9>', function() dap().toggle_breakpoint() end, { desc = 'Debug: toggle breakpoint' })
-- Conditional breakpoint
map('n', '<leader>dB', function()
  vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(cond)
    if cond and cond ~= '' then
      dap().set_breakpoint(cond)
    end
  end)
end, { desc = 'Debug: conditional breakpoint' })

-- Stepping                        F10 / F11 / Shift+F11  (VSCode)
map('n', '<F10>', function() dap().step_over() end, { desc = 'Debug: step over' })
map('n', '<F11>', function() dap().step_into() end, { desc = 'Debug: step into' })
map('n', '<S-F11>', function() dap().step_out() end, { desc = 'Debug: step out' })

-- Evaluate under cursor / selection   Alt+F8 (IntelliJ) · <leader>de
local function eval()
  require('plugins.dap')
  require('dapui').eval(nil, { enter = true })
end
map({ 'n', 'v' }, '<A-F8>', eval, { desc = 'Debug: evaluate' })
map({ 'n', 'v' }, '<leader>de', eval, { desc = 'Debug: evaluate' })

-- Panel and REPL
map('n', '<leader>du', function()
  require('plugins.dap')
  require('dapui').toggle()
end, { desc = 'Debug: toggle UI' })
map('n', '<leader>dr', function() dap().repl.toggle() end, { desc = 'Debug: toggle REPL' })
map('n', '<leader>dl', function() dap().run_last() end, { desc = 'Debug: run last' })

-- Undotree, displaced from F5 by the debugger.
-- :Undotree, not :UndotreeToggle — the latter was mbbill/undotree's command
-- name, and this now uses Neovim 0.12's bundled nvim.undotree package. The
-- mapping survived the swap looking correct and would have failed on use.
map('n', '<leader>u', '<cmd>Undotree<cr>', { desc = 'Undo tree' })
