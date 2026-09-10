-- lua/plugins/completion.lua — blink.cmp, replacing coc's completion popup.
--
-- Keymap deliberately mirrors what coc was bound to in the Vim config, so the
-- muscle memory carries over:
--
--   <Tab>       accept the selected item, else fall through to a real tab
--   <S-Tab>     previous item
--   <C-Space>   trigger completion       (coc#refresh)
--   <C-j>/<C-k> snippet jump forward/back (g:coc_snippet_next/prev)
--   <CR>        accept if the menu is open, else a normal newline
--
-- <CR> matters here. The Vim config needs after/plugin/zz-completion.vim to
-- arbitrate between coc's popup and lexima's bracket expansion, because
-- whichever plugin loaded second won outright. blink handles this natively:
-- with `auto_insert` off and this preset, <CR> only intercepts when the menu is
-- actually visible, and lexima sees the keypress otherwise.

require('blink.cmp').setup({
  keymap = {
    preset = 'none',
    ['<Tab>'] = { 'accept', 'fallback' },
    ['<S-Tab>'] = { 'select_prev', 'fallback' },
    ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
    ['<Down>'] = { 'select_next', 'fallback' },
    ['<Up>'] = { 'select_prev', 'fallback' },
    ['<C-n>'] = { 'select_next', 'fallback' },
    ['<C-p>'] = { 'select_prev', 'fallback' },
    ['<C-e>'] = { 'hide', 'fallback' },
    ['<CR>'] = { 'accept', 'fallback' },
    ['<C-j>'] = { 'snippet_forward', 'fallback' },
    ['<C-k>'] = { 'snippet_backward', 'fallback' },
  },

  appearance = { nerd_font_variant = 'mono' },

  completion = {
    -- coc showed documentation alongside the menu; match that.
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    menu = { border = 'rounded' },
    -- Do NOT insert as you move through the list. The Vim config's <Tab>
    -- mapping only ever inserted on an explicit accept, and auto-insert makes
    -- lexima's bracket handling fire against half-typed text.
    list = { selection = { preselect = true, auto_insert = false } },
  },

  signature = { enabled = true, window = { border = 'rounded' } },

  -- blink ships every source in-tree, unlike nvim-cmp where each is a separate
  -- plugin.
  --
  -- SNIPPETS DID NOT CARRY OVER. honza/vim-snippets is UltiSnips format, which
  -- coc-snippets read directly; blink reads LSP-format snippets. Rather than
  -- add LuaSnip purely to run an UltiSnips compatibility layer, honza is
  -- dropped and rafamadriz/friendly-snippets (LSP format, the collection blink
  -- expects) takes its place. Any personally-written UltiSnips snippets would
  -- need converting — there were none in this repo.
  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer' },
  },

  fuzzy = {
    -- Prefer the prebuilt Rust matcher, but keep working if the download for
    -- this platform is missing rather than erroring at startup.
    implementation = 'prefer_rust_with_warning',
  },
})
