-- lua/plugins/format.lua — conform.nvim, replacing coc-prettier.
--
-- coc-prettier formatted on demand via :Prettier and on save through
-- coc-settings.json. conform does the same, but picks the formatter per
-- filetype rather than routing everything through one language server, which
-- is why the LSP servers that also offer formatting are told to stand down in
-- lua/plugins/lsp.lua.

require('conform').setup({
  formatters_by_ft = {
    javascript = { 'prettier' },
    javascriptreact = { 'prettier' },
    typescript = { 'prettier' },
    typescriptreact = { 'prettier' },
    json = { 'prettier' },
    jsonc = { 'prettier' },
    css = { 'prettier' },
    scss = { 'prettier' },
    html = { 'prettier' },
    yaml = { 'prettier' },
    markdown = { 'prettier' },
    sh = { 'shfmt' },
    bash = { 'shfmt' },
    php = { 'php_cs_fixer' },
    python = { 'ruff_format' },
  },
  -- Formatting stays EXPLICIT (Ctrl+Alt+L / <leader>F), matching the Vim
  -- config. No format_on_save: the repo has files whose formatting is
  -- deliberate, and a silent reformat on every write is how those get churned.
  default_format_opts = { lsp_format = 'fallback', timeout_ms = 3000 },
})

-- Used by the Ctrl+Alt+L / <leader>F mappings in config/31-keymap-ide.vim.
vim.api.nvim_create_user_command('Format', function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = { start = { args.line1, 0 }, ['end'] = { args.line2, end_line:len() } }
  end
  require('conform').format({ async = true, range = range })
end, { range = true, desc = 'Format buffer or range' })
