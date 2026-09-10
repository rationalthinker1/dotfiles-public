" lightline — statusline, and lightline-bufferline as the sole owner of 'tabline'.
" (ap/vim-buftabline used to set 'tabline' as well; the two fought.)

if !exists('g:loaded_lightline')
  finish
endif

" g:lightline itself is in config/05-plugin-vars.vim; the component functions it
" names are resolved by lightline at render time, so they can live here.

function! LightlineModified() abort
  if &filetype ==# 'help'
    return ''
  elseif &modified
    return '+'
  elseif !&modifiable
    return '-'
  endif
  return ''
endfunction

function! LightlineReadonly() abort
  return (&filetype !=# 'help' && &readonly) ? 'RO' : ''
endfunction

function! LightlineFilename() abort
  let l:name = empty(expand('%:t')) ? '[No Name]' : expand('%:t')
  let l:ro = LightlineReadonly()
  let l:mod = LightlineModified()
  return (empty(l:ro) ? '' : l:ro . ' ') . l:name . (empty(l:mod) ? '' : ' ' . l:mod)
endfunction

" Git information comes from coc-git. The old config read vim-fugitive's
" fugitive#head() and vim-gitgutter's GitGutterGetHunkSummary() — the latter was
" never installed, so the component silently rendered nothing.
function! LightlineGitBranch() abort
  return get(g:, 'coc_git_status', '')
endfunction

function! LightlineGitStatus() abort
  return winwidth(0) > 90 ? get(b:, 'coc_git_status', '') : ''
endfunction

augroup lightline_refresh
  autocmd!
  autocmd User CocStatusChange,CocGitStatusChange call lightline#update()
augroup END
