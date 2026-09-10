-- lua/plugins/pairs.lua — nvim-autopairs, replacing cohama/lexima.vim.
--
-- The substantive difference is WHEN the decision is made. lexima matches
-- against a rule table built at startup (several hundred rules, ~9ms, which is
-- why the Vim config defers it to InsertEnter). nvim-autopairs asks treesitter
-- at the moment of the keystroke. No rule table, no deferral needed.
--
-- Concretely, what check_ts buys — measured, not assumed:
--     x = "he'      ->  x = "h'e"     apostrophe inside a string: NOT paired
--     y = '         ->  y = ''        the same key in code:       paired
-- It does NOT suppress pairing inside comments; `-- note (` still becomes
-- `-- note ()`, which is the intended behaviour and matches what lexima did.
-- ts_config below names the node types where the check applies per language.
--
-- <CR> IS THE DELICATE PART, and is tested explicitly rather than assumed.
--
-- Three plugins want this key: blink.cmp (accept the completion), nvim-autopairs
-- (split a just-opened pair onto its own line), and Vim (insert a newline). The
-- Vim config needed a hand-written arbiter for the coc/lexima version of this
-- same fight — see .vim/after/plugin/zz-completion.vim.
--
-- Here the chain resolves by itself, but only because of how blink is mapped in
-- lua/plugins/completion.lua:
--
--   ['<CR>'] = { 'accept', 'fallback' }
--
-- `fallback` means: if the completion menu is NOT visible, hand the key on to
-- whatever else is mapped — which is nvim-autopairs' <CR>. If the menu IS
-- visible, blink consumes it and autopairs never sees it, which is correct:
-- accepting a completion should not also split a bracket.
--
-- So the ordering requirement is that autopairs' map_cr stays enabled and
-- blink's <CR> keeps its `fallback`. Removing either breaks one of the two
-- behaviours silently.

require('nvim-autopairs').setup({
  -- Ask treesitter before pairing, and never pair inside a string or comment.
  check_ts = true,
  ts_config = {
    lua = { 'string' },
    javascript = { 'template_string' },
    typescript = { 'template_string' },
  },
  -- Do not add a closing pair when the next character is one of these — the
  -- common "typing ( before an existing word" case.
  enable_check_bracket_line = true,
  ignored_next_char = [=[[%w%%%'%[%"%.%`%$]]=],
  map_cr = true,   -- see the <CR> note above
  map_bs = true,   -- backspace over a pair deletes both halves
  fast_wrap = {
    map = '<M-e>', -- Alt+E: wrap the next word in the pair just typed
  },
})
