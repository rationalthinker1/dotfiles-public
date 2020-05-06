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
nnoremap R :Registers<CR>
nnoremap S :Find<CR>
nnoremap H :History<CR>
nnoremap B :Buffers<CR>
nnoremap T :BTags<CR>

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
command! -bang -nargs=* Find call fzf#vim#grep(
	\ 'rg --smart-case --column --line-number --no-heading --fixed-strings --ignore-case --hidden --follow --glob "!{.git,node_modules,vendor,oh-my-zsh,antigen,.vim/plugged,*.log,.viminfo}" --color "always" '.shellescape(<q-args>).'| tr -d "\017"', 1,
	\ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%', '?'),
	\ <bang>0)

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

