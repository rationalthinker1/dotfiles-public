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
nnoremap S :Rg<CR>
nnoremap H :History<CR>
nnoremap B :Buffers<CR>
nnoremap T :BTags<CR>

let g:fzf_history_dir = '~/.config/fzf/fzf-history'

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }

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

