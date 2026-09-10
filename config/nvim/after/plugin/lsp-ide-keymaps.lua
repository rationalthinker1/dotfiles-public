-- after/plugin/lsp-ide-keymaps.lua — the IDE chords, on native LSP.
--
-- These were in config/31-keymap-ide.vim bound to <Plug>(coc-*). They moved
-- here because the native API is Lua-only, and because after/plugin is where
-- mappings belong once the thing they call is loaded.
--
-- Same keys as the Vim config; see docs/VIM_KEYMAP.md.

local map = vim.keymap.set
local function lsp(fn, desc) return fn, { desc = desc } end

-- Quick fix / intention        Alt+Enter  (IntelliJ's headline binding)
map({ 'n', 'x' }, '<M-CR>', vim.lsp.buf.code_action, { desc = 'Quick fix' })
map({ 'n', 'x' }, '<leader>a', vim.lsp.buf.code_action, { desc = 'Quick fix' })
-- Refactor this                Ctrl+Alt+Shift+T
map({ 'n', 'x' }, '<C-A-S-t>', vim.lsp.buf.code_action, { desc = 'Refactor this' })

-- Go to declaration            F12          · Find usages   Shift+F12 / Alt+F7
map('n', '<F12>', vim.lsp.buf.definition, { desc = 'Go to declaration' })
map('n', '<S-F12>', vim.lsp.buf.references, { desc = 'Find usages' })
map('n', '<A-F7>', vim.lsp.buf.references, { desc = 'Find usages' })
-- Go to type declaration       Ctrl+Shift+B
map('n', '<C-S-b>', vim.lsp.buf.type_definition, { desc = 'Go to type declaration' })

-- Rename                       F2 / Shift+F6
map('n', '<F2>', vim.lsp.buf.rename, { desc = 'Rename' })
map('n', '<S-F6>', vim.lsp.buf.rename, { desc = 'Rename' })

-- Format document              Ctrl+Alt+L / <leader>F   (conform, see format.lua)
map({ 'n', 'x' }, '<C-A-l>', function() require('conform').format({ async = true }) end,
  { desc = 'Format document' })
-- NOT <leader>F — that is the file picker (config/31-keymap-ide.vim). This file
-- is in after/plugin, so it loads later and would silently win. Format stays on
-- Ctrl+Alt+L and <leader>f.

-- Organize imports             Ctrl+Alt+O
local function organize_imports()
  vim.lsp.buf.code_action({
    context = { only = { 'source.organizeImports' }, diagnostics = {} },
    apply = true,
  })
end
map('n', '<C-A-o>', organize_imports, { desc = 'Organize imports' })
map('n', '<leader>oi', organize_imports, { desc = 'Organize imports' })

-- ESLint autofix               Ctrl+Shift+S  (their own keybindings.json override)
map('n', '<C-S-s>', function()
  vim.lsp.buf.code_action({
    context = { only = { 'source.fixAll.eslint' }, diagnostics = {} },
    apply = true,
  })
end, { desc = 'ESLint autofix' })

-- Next / previous problem      F8 / Shift+F8
map('n', '<F8>', function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = 'Next problem' })
map('n', '<S-F8>', function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = 'Previous problem' })
-- Error description            Ctrl+F1
map('n', '<C-F1>', vim.diagnostic.open_float, { desc = 'Error description' })
-- Problems list                Alt+0
map('n', '<A-0>', function() Snacks.picker.diagnostics() end, { desc = 'Problems' })

-- Quick documentation          Ctrl+Q
map('n', '<C-q>', vim.lsp.buf.hover, { desc = 'Quick documentation' })

-- Symbol in file / project     Ctrl+Shift+O, Alt+7, Ctrl+F12 / Ctrl+Alt+Shift+N
-- Through snacks.picker rather than vim.lsp.buf.document_symbol, which dumps
-- into the quickfix list; the picker is what coc's :CocList outline felt like.
local function doc_symbols() Snacks.picker.lsp_symbols() end
local function ws_symbols() Snacks.picker.lsp_workspace_symbols() end
map('n', '<C-S-o>', doc_symbols, { desc = 'File structure' })
map('n', '<A-7>', doc_symbols, { desc = 'File structure' })
map('n', '<C-F12>', doc_symbols, { desc = 'File structure' })
map('n', '<leader>o', doc_symbols, { desc = 'File structure' })
map('n', '<C-A-S-n>', ws_symbols, { desc = 'Symbol in project' })
map('n', '<leader>O', ws_symbols, { desc = 'Symbol in project' })

-- Expand / shrink selection    Alt+Shift+Right / Left
-- coc-range-select has no native equivalent; Neovim 0.12 added
-- textDocument/selectionRange support, reachable through this incremental
-- selection helper.
map({ 'n', 'x' }, '<M-S-Right>', function() vim.lsp.buf.selection_range(1) end,
  { desc = 'Expand selection' })
map('x', '<M-S-Left>', function() vim.lsp.buf.selection_range(-1) end,
  { desc = 'Shrink selection' })
