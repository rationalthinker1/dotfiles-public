Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Great place to custom fzf functions
" https://github.com/mars90226/dotvim/blob/f8e1c7aeefd0f50ccb36d95b8fd0f80c54cb7f7a/autoload/vimrc/fzf.vim

function! s:find_files()
	let root_directory = FindRootDirectory()
	if root_directory != ''
		execute 'Files' root_directory  
	else
		execute 'Files'
	endif
endfunction
command! ProjectFiles execute s:find_files()
nnoremap F :ProjectFiles<CR>
nnoremap ; :Buffers<CR>
" Yanks
nnoremap R :Registers<CR>
"nnoremap T :Tags<CR>
"nnoremap t :BTags<CR>
nnoremap <Space><Space> :Find<CR>
nnoremap H :History<CR>

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

function! s:registers_source()
	return split(execute('registers', 'silent!'), "\n")[1:]
endfunction

function! s:registers()
	call fzf#run(fzf#wrap('Registers', {
				\ 'source': s:registers_source(),
				\ 'sink': function('vimrc#fzf#registers_sink'),
				\ 'options': ['+s', '--prompt', 'Registers> ']}))
endfunction
command! Registers call s:registers()



command! Functions call s:functions()

function! s:functions()
  call fzf#run(fzf#wrap('Functions', {
      \ 'source':  s:functions_source(),
      \ 'sink':    function('s:functions_sink'),
      \ 'options': ['--prompt', 'Functions> ']}))
endfunction

function! s:functions_sink(line)
  let function_name = matchstr(a:line, '\s\zs\S[^(]*\ze(')
  let @" = function_name
endfunction

function! s:functions_source()
  return split(execute('function', 'silent!'), "\n")
endfunction
