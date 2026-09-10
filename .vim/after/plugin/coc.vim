" coc.nvim — LSP, completion, diagnostics.
" IDE-style chords (F12, Alt+Enter, Ctrl+Alt+L …) live in config/31-keymap-ide.vim;
" this file holds the Vim-idiomatic bindings and coc's own settings.

" Guard on coc's plugin-file marker, NOT exists('*coc#refresh'): an autoload
" function does not exist until its file is first sourced, which has not
" happened yet at after/plugin time. That test silently skipped this whole file.
if !exists('g:did_coc_loaded')
  finish
endif

" g:coc_global_extensions and the snippet-jump keys are in
" config/05-plugin-vars.vim, so they are set before coc loads.

"--- Completion ------------------------------------------------------------
" coc#pum#* is the current API; the older pumvisible()/<C-y> form does not see
" coc's own floating menu.
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#confirm() :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <C-Space> coc#refresh()

function! s:check_back_space() abort
  let l:col = col('.') - 1
  return !l:col || getline('.')[l:col - 1] =~# '\s'
endfunction

"--- Navigation ------------------------------------------------------------
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

nmap <silent> [e <Plug>(coc-diagnostic-prev)
nmap <silent> ]e <Plug>(coc-diagnostic-next)

nmap <leader>rn <Plug>(coc-rename)
nmap <leader>qf <Plug>(coc-fix-current)
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

" K — documentation for the symbol under the cursor.
nnoremap <silent> K :call <SID>show_documentation()<CR>
function! s:show_documentation() abort
  if index(['vim', 'help'], &filetype) >= 0
    execute 'help ' . expand('<cword>')
  elseif coc#rpc#ready()
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . ' ' . expand('<cword>')
  endif
endfunction

"--- coc-git ---------------------------------------------------------------
nmap [g <Plug>(coc-git-prevchunk)
nmap ]g <Plug>(coc-git-nextchunk)
nmap gs <Plug>(coc-git-chunkinfo)
" NOT gc — that is the comment operator (from the bundled `comment` package
" here, and built in on the Neovim side). Mapping coc-git-commit onto gc left
" gcc working but silently broke every motion form: gcj, gcap, gci{ all became
" no-ops, because gc was waiting to be a git command instead of an operator.
nmap <leader>gc <Plug>(coc-git-commit)
omap ig <Plug>(coc-git-chunk-inner)
xmap ig <Plug>(coc-git-chunk-inner)
omap ag <Plug>(coc-git-chunk-outer)
xmap ag <Plug>(coc-git-chunk-outer)
nnoremap <silent> <leader>gu :CocCommand git.chunkUndo<CR>

augroup coc_settings
  autocmd!
  " Highlight other references to the symbol under the cursor ('updatetime' in
  " 20-options.vim controls how quickly).
  autocmd CursorHold * silent call CocActionAsync('highlight')
  autocmd FileType typescript,json setlocal formatexpr=CocAction('formatSelected')
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup END
