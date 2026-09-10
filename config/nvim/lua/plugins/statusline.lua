-- lua/plugins/statusline.lua — lualine, replacing lightline + lightline-bufferline.
--
-- One plugin for two: lualine's `tabline` section renders the buffer list, which
-- is the only reason lightline-bufferline existed. (Those two also both wrote
-- 'tabline' in the original Vim config and fought over it — see the note in
-- .vim/after/plugin/lightline.vim.)
--
-- Layout deliberately mirrors the lightline one so nothing moves:
--   left   mode | branch, diff, filename
--   right  percent, location | diagnostics | fileformat, encoding, filetype
--
-- Two things are better than the lightline setup rather than merely equivalent:
--   * `diff` and `branch` come from gitsigns directly. The lightline version
--     read vim-gitgutter functions that were never installed, so that component
--     silently rendered nothing for years.
--   * `diagnostics` is a real component. lightline had a coc#status string.

require('lualine').setup({
  options = {
    theme = 'auto',
    globalstatus = true,          -- one statusline for the whole window layout
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = { statusline = { 'snacks_dashboard' } },
  },

  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff' },
    lualine_c = {
      { 'filename', path = 0, symbols = { modified = ' +', readonly = ' RO', unnamed = '[No Name]' } },
    },
    lualine_x = {
      { 'diagnostics', sources = { 'nvim_diagnostic' }, symbols = { error = '✗ ', warn = '▲ ', info = '» ', hint = '» ' } },
      'fileformat',
      'encoding',
      'filetype',
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },

  -- The buffer list, replacing lightline-bufferline. 'showtabline' is already 2
  -- in config/20-options.vim, so it is always visible.
  tabline = {
    lualine_a = { { 'buffers', mode = 2, use_mode_colors = false } },
    lualine_z = { 'tabs' },
  },

  extensions = { 'fugitive', 'quickfix' },
})
