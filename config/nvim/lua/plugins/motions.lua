-- lua/plugins/motions.lua — flash.nvim, replacing easymotion and clever-f.
--
-- Two vimscript plugins become one Lua one:
--
--   clever-f     f/F/t/T that repeat on the same key instead of needing ;
--                -> flash's `char` mode does exactly this, and adds labels when
--                   more than one match is in reach.
--   easymotion   jump to a labelled position anywhere on screen
--                -> flash's `jump` mode, on <leader><leader> and <leader>s.
--
-- KEY CHOICE MATTERS HERE. flash's own defaults are `s` for jump and `S` for
-- treesitter select — and this config requires `s` and `S` to stay unmapped.
-- They were reclaimed once already (`s` had been :%s///g, `S` was an fzf
-- picker), and both are listed as must-stay-unmapped in the repo's CLAUDE.md
-- and docs/VIM_KEYMAP.md. So the defaults are explicitly NOT used; the jump
-- lands on <leader><leader>, matching the easymotion spelling this config has
-- always had, so nothing has to be relearned.

require('flash').setup({
  modes = {
    -- f/F/t/T enhancement. This is the clever-f replacement: pressing f again
    -- advances to the next match rather than requiring ;.
    char = {
      enabled = true,
      jump_labels = true,
      -- Keep ; and , doing what Vim does; only f/F/t/T are taken over.
      -- The pickers moved to <leader>+capital, so F and T are free again.
      keys = { 'f', 'F', 't', 'T' },
    },
    -- Do not let flash hook / and ? — this config drives search through
    -- vim-asterisk and the bundled nohlsearch package, and a second layer on
    -- the search command line fights both.
    search = { enabled = false },
  },
  label = { uppercase = false },
  jump = { autojump = false },
})

local map = vim.keymap.set

-- Jump to a labelled position — the easymotion replacement.
-- <leader><leader> matches the old <leader><leader>w spelling closely enough
-- that muscle memory carries; the trailing motion key is no longer needed
-- because flash labels every match as you type.
map({ 'n', 'x', 'o' }, '<leader><leader>', function() require('flash').jump() end,
  { desc = 'Flash jump' })
-- NOT <leader>s: that is the prefix for the spell maps (<leader>sn/sp/sa/s?),
-- so binding it made every one of them wait out 'timeoutlen' first.
-- <leader><leader> is the jump.

-- Treesitter-aware select: expands to the enclosing node, labelled.
-- flash puts this on S by default, which must stay unmapped here, and
-- <leader>S is now the grep picker — so it lands on <leader>v ("select node").
map({ 'n', 'x', 'o' }, '<leader>v', function() require('flash').treesitter() end,
  { desc = 'Flash treesitter select' })

-- Remote operations: yank/delete at a distance without moving the cursor.
-- e.g. `yr` then a label then `iw` yanks that word and comes back.
map('o', 'r', function() require('flash').remote() end, { desc = 'Flash remote' })
