" NERDTree — mappings and sync behaviour.
" g:NERDTree* variables are in config/05-plugin-vars.vim.

" g:NERDTree is an autoload-created object and does not exist yet at this point;
" the :NERDTree command comes from the plugin file and does.
if !exists(':NERDTree')
  finish
endif

" Toggle: close if open, otherwise open and reveal the current file.
function! s:NERDTreeToggle() abort
  if g:NERDTree.IsOpen()
    NERDTreeClose
  elseif filereadable(expand('%:p'))
    NERDTreeFind
  else
    NERDTree
  endif
endfunction
" Both explorer keys live here, next to the function they call: <SID> is
" script-local, so a mapping in config/31-keymap-ide.vim cannot reach it —
" which is how this ended up with two near-identical toggle functions.
"
"   Ctrl+B  the VSCode sidebar spelling
"   Alt+1   IntelliJ's Project tool window, and what the real VSCode keymap on
"           this machine uses (its Ctrl+B is goToDeclaration)
nnoremap <silent> <C-b> :call <SID>NERDTreeToggle()<CR>
nnoremap <silent> <A-1> :call <SID>NERDTreeToggle()<CR>

" Reveal the current file in an already-open tree, without stealing focus.
" The old version ran this from a bare `autocmd BufEnter *` and could call
" NERDTreeToggle from inside the handler, which made the tree flicker open and
" shut while cycling buffers.
function! s:SyncTree() abort
  if !g:NERDTree.IsOpen() || &diff || !&modifiable
    return
  endif
  if !filereadable(expand('%:p')) || bufname('%') =~# 'NERD_tree'
    return
  endif
  let l:current = winnr()
  NERDTreeFind
  execute l:current . 'wincmd w'
endfunction

augroup nerdtree_settings
  autocmd!
  autocmd BufEnter * call s:SyncTree()
  " Quit Vim if the tree is the only window left.
  autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
  " Buffer cycling from inside the tree should act on the edit window.
  autocmd FileType nerdtree nnoremap <buffer> <A-PageDown> :wincmd w <bar> bnext<CR>
  autocmd FileType nerdtree nnoremap <buffer> <A-PageUp>   :wincmd w <bar> bprevious<CR>
augroup END
