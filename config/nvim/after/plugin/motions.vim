" Motion plugins — mappings only.
" Variables (smoothie, smartword, asterisk) live in config/05-plugin-vars.vim.
" clever-f and easymotion are gone; flash.nvim replaced both, and its config is
" in lua/plugins/motions.lua.

"--- (clever-f removed) ------------------------------------------------------
" f/F/t/T are now flash.nvim's char mode; see lua/plugins/motions.lua.

"--- vim-smartword: w/b/e stop at more useful boundaries -------------------
map w  <Plug>(smartword-w)
map b  <Plug>(smartword-b)
map e  <Plug>(smartword-e)
map ge <Plug>(smartword-ge)

"--- vim-asterisk: * without the cursor jumping ----------------------------
" incsearch.vim used to wrap all of these to clear 'hlsearch'; the bundled
" `nohlsearch` package (packadd in lua/plugins/init.lua) does that on its own.
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
