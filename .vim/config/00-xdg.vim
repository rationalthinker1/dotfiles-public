" ~/.vim/config/00-xdg.vim — XDG paths and on-disk state.
"
" Sourced first: everything after this point may write undo/backup/swap/viminfo,
" so the directories have to exist before any of it runs.

if empty($XDG_CACHE_HOME)
  let $XDG_CACHE_HOME = expand('~/.cache')
endif
if empty($XDG_DATA_HOME)
  let $XDG_DATA_HOME = expand('~/.local/share')
endif

" netrw's history/bookmark file. Vim errors on exit (E886) if the dir is missing.
let g:netrw_home = $XDG_DATA_HOME . '/vim'

" Persistent undo, backups and swap. Swap is off (see 20-options.vim) but
" 'directory' still needs to point somewhere sane for the cases Vim uses it.
set undodir=$XDG_CACHE_HOME/vim/undo
set backupdir=$XDG_CACHE_HOME/vim/backup
set directory=$XDG_CACHE_HOME/vim/swap

" viminfo lives under XDG too; `^%` restores the buffer list.
set viminfo^=%
set viminfo+=n$XDG_DATA_HOME/vim/viminfo

for s:dir in [$XDG_DATA_HOME . '/vim', &undodir, &backupdir, &directory]
  if !isdirectory(expand(s:dir))
    call mkdir(expand(s:dir), 'p', 0700)
  endif
endfor
unlet! s:dir
