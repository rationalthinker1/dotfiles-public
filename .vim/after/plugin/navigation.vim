" Window/pane navigation — mappings only.
" Variables (tmux-navigator, winresizer, rooter, startify) are in
" config/05-plugin-vars.vim.

"--- vim-tmux-navigator ----------------------------------------------------
" One set of keys for Vim splits, tmux panes and kitty windows.
"
" There used to be four layers competing for this: kitty's pass_keys.py kitten,
" vim-tmux-navigator, knubie/vim-kitty-navigator, and a hand-rolled <A-arrow>
" block in .vimrc. In kitty the kitten consumed alt+arrow first and re-emitted
" Ctrl+h/j/k/l, so the <A-arrow> mappings could never fire. Two layers remain:
" the terminal sends Ctrl+h/j/k/l, this plugin routes it.
"
"   config/kitty/linux.conf : map alt+{left,down,up,right} -> pass_keys.py -> C-{h,j,k,l}
"   config/tmux/tmux.conf   : bind -n M-{Left,…} if-shell "$is_vim" 'send-keys C-{h,…}'
nnoremap <silent> <C-h> :TmuxNavigateLeft<CR>
nnoremap <silent> <C-j> :TmuxNavigateDown<CR>
nnoremap <silent> <C-k> :TmuxNavigateUp<CR>
nnoremap <silent> <C-l> :TmuxNavigateRight<CR>

" Alt+arrow as a direct alias, for terminals that deliver it unmodified.
nnoremap <silent> <A-Left>  :TmuxNavigateLeft<CR>
nnoremap <silent> <A-Down>  :TmuxNavigateDown<CR>
nnoremap <silent> <A-Up>    :TmuxNavigateUp<CR>
nnoremap <silent> <A-Right> :TmuxNavigateRight<CR>
