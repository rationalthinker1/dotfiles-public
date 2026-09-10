" <CR> arbitration between coc's completion popup and lexima's pair expansion.
"
" Sourced last (zz-) so both plugins have already installed their own mappings.
" Without this, whichever loaded second won outright: coc would confirm a
" completion where lexima should have expanded a brace, or lexima would swallow
" the confirm.

function! s:smart_cr() abort
  " Confirm the completion if coc's popup is showing.
  if exists('*coc#pum#visible') && coc#pum#visible()
    return coc#pum#confirm()
  endif
  " Otherwise break the undo chain here (so <C-u> in insert does not eat the
  " whole line) and let lexima decide whether this <CR> opens a block.
  if exists('*lexima#expand')
    return "\<C-g>u" . lexima#expand('<CR>', 'i')
  endif
  return "\<C-g>u\<CR>"
endfunction

inoremap <silent><expr> <CR> <SID>smart_cr()
