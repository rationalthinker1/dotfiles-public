" Editing plugins — mappings and runtime calls only.
" Their variables are set in config/05-plugin-vars.vim, which runs before the
" plugins load; see the header there for why that split exists.

"--- (lexima removed) --------------------------------------------------------
" Auto-pairing is now nvim-autopairs, in lua/plugins/pairs.lua. It needs no
" InsertEnter deferral: unlike lexima it does not materialise a rule table at
" setup, it asks treesitter at the point of the keystroke.

"--- vim-easy-align --------------------------------------------------------
" Visual: select then ga=  ·  Normal: gaip=
xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

"--- vim-better-whitespace -------------------------------------------------
nnoremap <silent> <leader>$ :StripWhitespace<CR>

"--- vim-move: move lines and blocks ---------------------------------------
" Replaces the abandoned vim-schlepp. Alt+Shift+arrows (VSCode) and
" Ctrl+Shift+arrows (IntelliJ) both work.
nmap <M-S-Up>    <Plug>MoveLineUp
nmap <M-S-Down>  <Plug>MoveLineDown
xmap <M-S-Up>    <Plug>MoveBlockUp
xmap <M-S-Down>  <Plug>MoveBlockDown
xmap <M-S-Left>  <Plug>MoveBlockLeft
xmap <M-S-Right> <Plug>MoveBlockRight
nmap <C-S-Up>    <Plug>MoveLineUp
nmap <C-S-Down>  <Plug>MoveLineDown
xmap <C-S-Up>    <Plug>MoveBlockUp
xmap <C-S-Down>  <Plug>MoveBlockDown

"--- vim-visual-multi: IntelliJ aliases ------------------------------------
" g:VM_maps in 05-plugin-vars.vim takes one key per action, so the IntelliJ
" spellings are added here as <Plug> aliases alongside the VSCode-style ones:
"   Alt+J             add next occurrence   (IntelliJ addSelectionToNextFindMatch)
"   Ctrl+Alt+Shift+J  select all occurrences (IntelliJ selectHighlights)
nmap <A-j>     <Plug>(VM-Find-Under)
xmap <A-j>     <Plug>(VM-Find-Subword-Under)
nmap <C-A-S-j> <Plug>(VM-Select-All)

"--- switch.vim: filetype-specific toggles ---------------------------------
" The global definitions and the -/_ mappings live in 05-plugin-vars.vim; only
" the per-buffer overrides need to happen at runtime.
let s:switch_ft = {}
let s:switch_ft.javascript = [['addClass', 'removeClass']]
let s:switch_ft.css = [['padding', 'margin']]
let s:switch_ft.vim = [
      \ ['g:', 'b:', 'l:', 's:'],
      \ ['map', 'nmap', 'imap', 'vmap', 'smap', 'xmap', 'cmap', 'omap'],
      \ ['noremap', 'nnoremap', 'inoremap', 'vnoremap', 'snoremap', 'xnoremap', 'cnoremap', 'onoremap'],
      \ ['unmap', 'nunmap', 'iunmap', 'vunmap', 'sunmap', 'xunmap', 'cunmap', 'ounmap'],
      \ ['<special>', '<silent>', '<buffer>', '<expr>'],
      \]

augroup switch_filetypes
  autocmd!
  autocmd FileType css,scss   let b:switch_custom_definitions = s:switch_ft.css
  autocmd FileType javascript let b:switch_custom_definitions = s:switch_ft.javascript
  autocmd FileType vim        let b:switch_custom_definitions = s:switch_ft.vim
augroup END
