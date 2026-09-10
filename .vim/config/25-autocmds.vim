" ~/.vim/config/25-autocmds.vim — every autocommand, inside a named group.
"
" The old config scattered bare `autocmd` calls outside any augroup across six
" places. Combined with a .vimrc that re-sourced itself on every write of any
" .vim file, each save registered another copy of every one of them. Named groups
" with `autocmd!` make re-sourcing idempotent.

augroup vimrc_filetypes
  autocmd!
  " '-' is a word character in html/css: it appears constantly in class names.
  autocmd FileType html,css setlocal iskeyword+=45
  " Close the quickfix window once an entry is chosen.
  autocmd FileType qf nnoremap <buffer> <CR> <CR>:cclose<CR>
  " Git commit buffers: no listchars clutter, and start at the top of the message.
  autocmd FileType gitcommit setlocal nolist textwidth=72
augroup END

augroup vimrc_reload
  autocmd!
  " Reload on write of the vimrc or any config fragment. The old version also
  " slept 500ms on every write of every .vim file — including plugin sources —
  " and ran a substitute-based line counter to guess whether to run PlugInstall.
  autocmd BufWritePost $MYVIMRC,~/.vim/config/*.vim
        \ source $MYVIMRC | echomsg 'Reloaded ' . expand('%:t')
augroup END

augroup vimrc_fugitive
  autocmd!
  autocmd BufReadPost fugitive://* setlocal bufhidden=delete
  autocmd BufReadPost fugitive://* call s:FugitiveSettings()
augroup END

function! s:FugitiveSettings() abort
  setlocal nowrap winfixwidth nonumber nolist
  if exists('g:NERDTree') && g:NERDTree.IsOpen()
    NERDTreeClose
  endif
endfunction

" Cursor position on reopen is handled by farmergreg/vim-lastplace. The old
" config additionally hand-rolled it twice (two competing BufReadPost autocmds)
" and then ran `clearjumps` on VimEnter, which fought both. All three are gone.
