-- after/plugin/lsp-keymaps.lua — the Vim-idiomatic LSP keys.
--
-- Replaces the gd/gy/gi/gr/K set that after/plugin/coc.vim used to define
-- against <Plug>(coc-*). The IDE-style chords (F12, Alt+Enter, Ctrl+Alt+L …)
-- live in config/31-keymap-ide.vim.
--
-- Neovim 0.11 added DEFAULT LSP mappings, so several of these already exist:
--   grn rename · gra code action · grr references · gri implementation
--   K hover     · <C-s> signature help (insert)
-- They are not redefined; the ones below are the spellings this config used
-- with coc, kept so nothing has to be relearned.
--
-- REFERENCES IS `grr`, NOT `gr`. The coc-era `gr` was here at first, and not
-- redefining the defaults is not the same as not breaking them: mapping the
-- two-key `gr` turns every one of grn/gra/grx/grr/gri/grt into a longer,
-- ambiguous continuation of it. With timeoutlen=500 (20-options.vim) a bare
-- `gr` then stalls half a second before firing, and `gra`/`grn` typed with any
-- pause run references FIRST and feed the trailing letter to normal mode —
-- `gra` became "find references, then enter insert". This config already
-- avoids exactly this shape twice: see 30-keymap-core.vim on why <leader>b is
-- not a mapping, and lua/plugins/motions.lua on why <leader>s is left alone.

local map = vim.keymap.set

map('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
map('n', 'gy', vim.lsp.buf.type_definition, { desc = 'Go to type definition' })
map('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to implementation' })

-- Diagnostics. vim.diagnostic.jump() replaced goto_next/goto_prev in 0.11.
map('n', ']e', function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = 'Next diagnostic' })
map('n', '[e', function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = 'Previous diagnostic' })

map('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Rename symbol' })
map('n', '<leader>qf', vim.lsp.buf.code_action, { desc = 'Quick fix' })
map({ 'n', 'x' }, '<leader>f', function() require('conform').format({ async = true }) end,
  { desc = 'Format' })

-- K is a default in 0.11+, but the Vim config also wanted `:help` for vim/help
-- filetypes rather than an LSP hover, so it is overridden to keep that.
map('n', 'K', function()
  if vim.tbl_contains({ 'vim', 'help' }, vim.bo.filetype) then
    vim.cmd('help ' .. vim.fn.expand('<cword>'))
  else
    vim.lsp.buf.hover()
  end
end, { desc = 'Hover documentation' })
