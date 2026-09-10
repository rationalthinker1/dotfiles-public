-- lua/plugins/ui-extras.lua — rainbow delimiters and auto-tags, both treesitter.
--
-- Two vimscript plugins replaced by treesitter-native ones. In both cases the
-- old plugin worked by pattern-matching text; these work on the parsed tree,
-- which is the whole reason treesitter is installed.
--
--   luochen1990/rainbow -> rainbow-delimiters.nvim
--       The old one matched brackets with a regex and a hand-written operator
--       list, so it mis-coloured anything inside a string or comment.
--   alvan/vim-closetag  -> nvim-ts-autotag
--       Closes AND renames: editing an opening tag updates its closing partner,
--       which closetag could not do.

require('rainbow-delimiters.setup').setup({
  -- Guard: rainbow-delimiters only acts on filetypes with a parser, and falls
  -- back to nothing rather than erroring where there is none (nginx, kitty).
  highlight = {
    'RainbowDelimiterYellow',
    'RainbowDelimiterViolet',
    'RainbowDelimiterBlue',
    'RainbowDelimiterOrange',
    'RainbowDelimiterGreen',
    'RainbowDelimiterCyan',
  },
})

require('nvim-ts-autotag').setup({
  opts = {
    enable_close = true,          -- close on >
    enable_rename = true,         -- rename the pair when either side changes
    enable_close_on_slash = false,
  },
})
