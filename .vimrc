" ~/.vimrc — loader only.
"
" Configuration lives in two places:
"
"   ~/.vim/config/*.vim        sourced from here, in filename order
"   ~/.vim/after/plugin/*.vim  sourced by Vim automatically, after plugins load
"
" The split matters. The previous layout `source`d its fragments from *inside*
" the plug#begin()/plug#end() block, so every mapping and setting in coc.vim,
" fzf.vim, nerdtree.vim and the rest ran before the plugin it configured was on
" 'runtimepath'. Anything that must observe a loaded plugin now goes in
" after/plugin/ and gets that guarantee for free.
"
" Load order is encoded in the filename prefixes:
"
"   00-xdg          paths and state dirs — before anything writes state
"   01-clipboard    clipboard provider   — before anything touches a register
"   05-plugin-vars  plugin variables     — before plug#end() reads them
"   10-plugins      plug#begin/end, then packadd for Vim 9.2's bundled packages
"   20-options      every 'set', assigned exactly once
"   25-autocmds     every autocommand, inside a named augroup
"   30-keymap-core  Vim-native keys, and the helpers the IDE layer calls
"   31-keymap-ide   the VSCode/IntelliJ layer  (see docs/VIM_KEYMAP.md)
"   40-ui           colourscheme and highlight overrides
"
" The 05/after split is load-bearing, not cosmetic: most plugins read their
" configuration once, when plug#end() puts them on 'runtimepath'. A variable set
" later is ignored and the plugin's own defaults win — usually including mappings
" that shadow yours. So: VARIABLES in 05-plugin-vars.vim, MAPPINGS in
" after/plugin/. See the header of 05-plugin-vars.vim for the four concrete
" collisions this caused.
"
" Machine-specific overrides go in ~/.vim/config/90-local.vim, which is
" gitignored and sourced last if present.

set nocompatible

" The leader must exist before any mapping that uses it.
let mapleader = ','
let g:mapleader = ','

for s:file in sort(glob('~/.vim/config/*.vim', 0, 1))
  execute 'source' fnameescape(s:file)
endfor
unlet! s:file
