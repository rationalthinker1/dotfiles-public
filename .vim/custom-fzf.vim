Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

function! s:find_files()
    let git_dir = system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
    if git_dir != ''
        execute 'Files' git_dir
    else
        execute 'Files'
    endif
endfunction
command! ProjectFiles execute s:find_files()
nnoremap f :ProjectFiles<CR>
nnoremap ; :Buffers<CR>
nnoremap T :Tags<CR>
nnoremap t :BTags<CR>
nnoremap s :Find<CR>
nnoremap h :History<CR>

let g:fzf_history_dir = '~/.config/fzf/fzf-history'

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
" --column: Show column number
" --line-number: Show line number
" --no-heading: Do not show file headings in results
" --fixed-strings: Search term as a literal string
" --ignore-case: Case insensitive search
" --no-ignore: Do not respect .gitignore, etc...
" --hidden: Search hidden files and folders
" --follow: Follow symlinks
" --glob: Additional conditions for search (in this case ignore everything in the .git/ folder)
" --color: Search color options
command! -bang -nargs=* Find call fzf#vim#grep('rg --smart-case --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --glob "!{.git,node_modules,vendor,oh-my-zsh,antigen,.vim/plugged}" --color "always" '.shellescape(<q-args>).'| tr -d "\017"', 1, <bang>0)
