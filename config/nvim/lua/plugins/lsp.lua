-- lua/plugins/lsp.lua — language servers, replacing coc.nvim.
--
-- WHAT REPLACED WHAT
--
-- The Vim config runs coc.nvim with 16 extensions. coc bundles a lot behind one
-- plugin; Neovim splits it across the native LSP client plus three plugins:
--
--   coc-tsserver      -> ts_ls          coc-html          -> html
--   coc-eslint        -> eslint         coc-json          -> jsonls
--   coc-pyright       -> pyright        coc-phpls         -> intelephense
--   coc-css           -> cssls          coc-tailwindcss   -> tailwindcss
--   coc-sh            -> bashls         coc-docker        -> dockerls
--   coc-emmet         -> emmet_language_server
--
--   coc-prettier      -> conform.nvim          (lua/plugins/format.lua)
--   coc-git           -> gitsigns.nvim         (lua/plugins/git.lua)
--   coc-snippets      -> blink.cmp             (lua/plugins/completion.lua)
--   coc-highlight     -> built in, below (LSP document highlight on CursorHold)
--   coc-yank          -> dropped; nothing in the keymap used it
--
-- THE 0.11+ MODEL
--
--   vim.lsp.config(name, cfg)  registers/overrides a server's configuration
--   vim.lsp.enable(name)       turns it on; Neovim starts it on matching files
--
-- nvim-lspconfig's job is now just to ship the `lsp/` definitions Neovim reads
-- (root markers, filetypes, cmd). mason installs the binaries. mason-lspconfig
-- bridges the two names and calls vim.lsp.enable() for what is installed.

require('mason').setup({
  ui = { border = 'rounded' },
})

-- ensure_installed drives mason to fetch these on first start. Names here are
-- lspconfig names; mason-lspconfig maps them to mason package names.
require('mason-lspconfig').setup({
  ensure_installed = {
    'ts_ls',
    'eslint',
    'pyright',
    'cssls',
    'html',
    'jsonls',
    'bashls',
    'dockerls',
    'intelephense',
    'tailwindcss',
    'emmet_language_server',
  },
  -- Call vim.lsp.enable() for every installed server. Without this each one
  -- would need enabling by hand.
  automatic_enable = true,
})

--- Per-server overrides. Anything not named here uses lspconfig's defaults.
--
-- eslint: run its fix-all on write, which is what coc-eslint's
-- `eslint.autoFixOnSave` did. Ctrl+Shift+S (their VSCode binding for
-- eslint.executeAutofix) is wired to the same command in 31-keymap-ide.vim.
vim.lsp.config('eslint', {
  settings = { run = 'onType', format = false },
})

-- Prettier owns formatting for the web filetypes (via conform), so the servers
-- that also offer it are told not to, otherwise both fight over the buffer.
for _, server in ipairs({ 'ts_ls', 'html', 'cssls', 'jsonls' }) do
  vim.lsp.config(server, {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
  })
end

-- Diagnostics. The Vim config sets signcolumn=yes so text does not shift;
-- matching that here, with virtual text kept short enough not to wrap.
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, prefix = '●' },
  float = { border = 'rounded', source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '✗',
      [vim.diagnostic.severity.WARN] = '▲',
      [vim.diagnostic.severity.INFO] = '»',
      [vim.diagnostic.severity.HINT] = '»',
    },
  },
})

-- Buffer-local setup once a server attaches.
--
-- Neovim 0.11 added default LSP mappings — grn rename, gra code action, grr
-- references, gri implementation, K hover — so those are NOT redefined here.
-- The IDE-style chords (F12, Alt+Enter, Ctrl+Alt+L …) are in
-- config/31-keymap-ide.vim, and the gd/gy/gi/gr set in
-- after/plugin/lsp-keymaps.lua, both matching what coc was bound to.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('nvim_lsp_attach', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- coc-highlight's job: underline other references to the symbol under the
    -- cursor. 'updatetime' (300ms, set in 20-options.vim) drives the delay,
    -- exactly as it drove coc's CursorHold highlight.
    if client:supports_method('textDocument/documentHighlight') then
      local hl = vim.api.nvim_create_augroup('nvim_lsp_highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = hl,
        buffer = args.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = hl,
        buffer = args.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end

    -- Inlay hints, which coc did not do at all. Off by default; <leader>ih.
    if client:supports_method('textDocument/inlayHint') then
      vim.keymap.set('n', '<leader>ih', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }),
          { bufnr = args.buf })
      end, { buffer = args.buf, desc = 'Toggle inlay hints' })
    end
  end,
})
