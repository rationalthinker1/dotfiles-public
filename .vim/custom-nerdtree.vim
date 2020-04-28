Plug 'scrooloose/nerdtree' " Shows file manager
nnoremap <silent> <expr> <C-b> g:NERDTree.IsOpen() ? "\:NERDTreeClose<CR>" : bufexists(expand('%')) ? "\:NERDTreeFind<CR>" : "\:NERDTree<CR>"
" nerdtree - open when vim open
"          - switch to opened window
"          - close if last remaining window
"          - minimal UI
"          - show hidden files
"          - single click to open dir, double to open file
autocmd VimEnter * NERDTree
autocmd VimEnter * wincmd p
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
let NERDTreeRespectWildIgnore=1
let NERDTreeIgnore=['.DS_Store', '.git', 'node_modules', '\.sublime-project', '\.sublime-workspace']
let NERDTreeShowHidden = 1
let NERDTreeMouseMode=2
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1
let g:nerd_preview_enabled = 1
let g:preview_last_buffer = 0

function! NerdTreePreview()
	" Only on nerdtree window
	if (&ft ==# 'nerdtree')
		" Get filename
		let l:filename = substitute(getline("."), "^\\s\\+\\|\\s\\+$","","g")

		" Preview if it is not a folder
		let l:lastchar = strpart(l:filename, strlen(l:filename) - 1, 1)
		if (l:lastchar != "/" && strpart(l:filename, 0 ,2) != "..")

			let l:store_buffer_to_close = 1
			if (bufnr(l:filename) > 0)
				" Don't close if the buffer is already open
				let l:store_buffer_to_close = 0
			endif

			" Do preview
			execute "normal go"

			" Close previews buffer
			if (g:preview_last_buffer > 0)
				execute "bwipeout " . g:preview_last_buffer
				let g:preview_last_buffer = 0
			endif

			" Set last buffer to close it later
			if (l:store_buffer_to_close)
				let g:preview_last_buffer = bufnr(l:filename)
			endif
		endif
	elseif (g:preview_last_buffer > 0)
		" Close last previewed buffer
		let g:preview_last_buffer = 0
	endif
endfunction

function! NerdPreviewToggle()
	if (g:nerd_preview_enabled)
		let g:nerd_preview_enabled = 0
		augroup nerdpreview
			autocmd!
		augroup END
	else
		let g:nerd_preview_enabled = 1
		augroup nerdpreview
			autocmd!
			autocmd CursorMoved * nested call NerdTreePreview()
		augroup END
	endif
endfunction
