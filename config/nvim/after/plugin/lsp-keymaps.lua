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

local map = vim.keymap.set

map('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
map('n', 'gy', vim.lsp.buf.type_definition, { desc = 'Go to type definition' })
map('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to implementation' })
map('n', 'gr', vim.lsp.buf.references, { desc = 'Find references' })

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
