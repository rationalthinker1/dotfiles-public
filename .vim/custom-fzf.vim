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
nnoremap s :Rg<CR>
nnoremap h :History<CR>

let g:fzf_history_dir = '~/.config/fzf/fzf-history'

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
