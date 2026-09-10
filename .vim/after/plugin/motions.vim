" Motion plugins — mappings only.
" Variables (clever-f, smoothie, easymotion) live in config/05-plugin-vars.vim.

"--- clever-f: f repeats f, no need for ; ----------------------------------
map f <Plug>(clever-f-f)
map F <Plug>(clever-f-F)
map t <Plug>(clever-f-t)
map T <Plug>(clever-f-T)

"--- vim-smartword: w/b/e stop at more useful boundaries -------------------
map w  <Plug>(smartword-w)
map b  <Plug>(smartword-b)
map e  <Plug>(smartword-e)
map ge <Plug>(smartword-ge)

"--- vim-asterisk: * without the cursor jumping ----------------------------
" incsearch.vim used to wrap all of these to clear 'hlsearch'; Vim 9.2's bundled
" `nohlsearch` package (packadd in config/10-plugins.vim) does that on its own.
map *   <Plug>(asterisk-*)
map g*  <Plug>(asterisk-g*)
map #   <Plug>(asterisk-#)
map g#  <Plug>(asterisk-g#)
" z* keeps the cursor where it is — pair with cgn to change every match with `.`
map z*  <Plug>(asterisk-z*)
map gz* <Plug>(asterisk-gz*)
map z#  <Plug>(asterisk-z#)
map gz# <Plug>(asterisk-gz#)

"--- vim-smoothie: animated PageUp/PageDown --------------------------------
" g:smoothie_no_default_mappings is 1, so only these two are bound; smoothie's
" defaults would otherwise claim <C-b>, <C-d>, <C-e>, <C-f>, <C-u> and <C-y>,
" five of which are IDE actions in config/31-keymap-ide.vim.
silent! map <PageDown> <Plug>(SmoothieForwards)
silent! map <PageUp>   <Plug>(SmoothieBackwards)
