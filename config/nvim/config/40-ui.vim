" ~/.config/nvim/config/40-ui.vim — colours and highlight overrides.
"
" The old config ran three `color` commands back to back (onedark, cosmic-barf,
" cyberpunk). Vim sourced all three in full and kept only the last, costing ~16ms
" of startup for two schemes that were discarded immediately.

" `syntax enable` rather than `syntax on`: `on` resets user highlight settings,
" which is what silently undid the italic-comment override below. The old config
" called both, in that order.
if !exists('g:syntax_on')
  syntax enable
endif

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
