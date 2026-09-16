" ~/.config/nvim/config/40-ui.vim — colours and highlight overrides.
"
" The old config ran three `color` commands back to back (onedark, cosmic-barf,
" cyberpunk). Vim sourced all three in full and kept only the last, costing ~16ms
" of startup for two schemes that were discarded immediately.

" No `syntax enable` here, deliberately. Neovim turns syntax on by itself once
" init has finished, so the command is redundant -- and running it *during* init
" is actively harmful: it sources runtime/syntax/syntax.vim, which pulls in
" runtime/filetype.lua, which runs `doautoall filetypedetect BufRead`. That
" fires FileType for the command-line argument's buffer while it is still
" unloaded, and any handler that wants the buffer's text (treesitter, via this
" config or via Nvim's own ftplugin/lua.lua) loads it then and there. Nvim
" afterwards finds the buffer already loaded, takes the "no read needed" path
" in do_ecmd(), and never applies 'foldlevelstart' -- so 'foldlevel' stays 0
" against treesitter's folds and every file opens folded shut.
"
" (The Vim config keeps `syntax enable` -- Vim does not enable syntax on its
" own, and `syntax on` there resets user highlight settings, which is what
" silently undid the italic-comment override below.)

set background=dark

" Italic comments, honoured by onedark and vim-one when these are set first.
let g:one_allow_italics = 1
let g:onedark_terminal_italics = 1

silent! colorscheme cyberpunk

" Applied after the colorscheme so they are not overwritten by it.
highlight Comment cterm=italic gui=italic

" Indent guides drawn by 'listchars' (see 20-options.vim) should recede rather
" than compete with the text.
highlight! link SpecialKey NonText

" The Vim config carries a has('gui_running') block for gvim/MacVim.
" Neovim has no built-in GUI: appearance is the GUI client's business
" (Neovide, goneovim, …) and 'guioptions'/'guifont'/'winaltkeys' either do not
" exist or are ignored. The block is dropped rather than translated.
