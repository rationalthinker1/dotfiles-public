-- lua/plugins/git.lua — gitsigns, replacing coc-git.
--
-- Keeps the same keys the coc-git bindings used, so nothing has to be relearned:
--   [g / ]g                       previous / next hunk
--   Ctrl+Alt+Shift+Up / Down      same, IntelliJ spelling
--   Ctrl+Alt+Z                    reset (rollback) the hunk under the cursor
--   gs                            preview the hunk
--   ig / ag                       hunk text objects
--   <leader>gc                    the git commit itself, via fugitive
--
-- The statusline components in after/plugin/lightline.vim read coc-git's
-- b:coc_git_status; they are repointed at gitsigns' b:gitsigns_status below.

require('gitsigns').setup({
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(bufnr)
    local gs = require('gitsigns')
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map('n', ']g', function() gs.nav_hunk('next') end, 'Next hunk')
    map('n', '[g', function() gs.nav_hunk('prev') end, 'Previous hunk')
    map('n', '<C-A-S-Down>', function() gs.nav_hunk('next') end, 'Next change')
    map('n', '<C-A-S-Up>', function() gs.nav_hunk('prev') end, 'Previous change')
    map('n', 'gs', gs.preview_hunk, 'Preview hunk')
    map('n', '<C-A-z>', gs.reset_hunk, 'Rollback hunk')
    map('n', '<leader>gu', gs.reset_hunk, 'Rollback hunk')
    map('n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Blame line')
    map({ 'o', 'x' }, 'ig', gs.select_hunk, 'Inner hunk')
    map({ 'o', 'x' }, 'ag', gs.select_hunk, 'A hunk')
  end,
})

-- ATTACH TO BUFFERS THAT ALREADY EXIST.
--
-- This module is deferred to BufReadPre (see init.lua), so gitsigns.setup()
-- runs *during* the BufReadPre of the very first file opened. gitsigns
-- registers its own attach autocmds inside setup(), so the event for that first
-- buffer has already passed and it is never attached.
--
-- The symptom is deceptive: gitsigns sets b:gitsigns_head from its repo scan,
-- so the buffer LOOKS attached, while its cache entry is absent and none of the
-- on_attach keymaps (]g, [g, gs, <leader>gu, Ctrl+Alt+Z) exist. Every one was
-- silently dead on the first file of every session.
--
-- Attached on the next BufEnter rather than immediately: at BufReadPre the
-- buffer is not yet loaded, so an is-loaded guard skips it and an unguarded
-- attach runs against a bufferless read. BufEnter is the first point where the
-- buffer is real. once=true, since gitsigns' own autocmds handle every buffer
-- after this one.
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufReadPost' }, {
  group = vim.api.nvim_create_augroup('gitsigns_attach_first', { clear = true }),
  once = true,
  callback = function()
    vim.schedule(function()
      local gs = require('gitsigns')
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then
          pcall(gs.attach, buf)
        end
      end
    end)
  end,
})
