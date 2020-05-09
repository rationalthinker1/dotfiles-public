Plug 'scrooloose/nerdtree' " Shows file manager
let NERDTreeRespectWildIgnore=1
let NERDTreeIgnore=['.DS_Store', '.git', 'node_modules', '\.sublime-project', '\.sublime-workspace', '.idea']
let NERDTreeShowHidden = 1
let NERDTreeMouseMode=2
let NERDTreeMinimalUI = 1
let NERDTreeShowFiles = 1
let NERDTreeDirArrows = 1

let g:nerd_preview_enabled = 1
let g:preview_last_buffer = 0
nnoremap <silent> <expr> <C-b> g:NERDTree.IsOpen() ? "\:NERDTreeClose<CR>" : bufexists(expand('%')) ? "\:NERDTreeFind<CR>" : "\:NERDTree<CR>"

" https://github.com/YArane/dotfiles/blob/aac6b3efc617ec4716646af95b02a823d2cb0d0f/.vim/nerdtree.vim
" returns true iff NERDTRee open / active
function! s:isNERDTreeOpen()
	return exists("t:NERDTreeBufName") && (bufwinnr(t:NERDTreeBufName) != -1)
endfunction

" calls NERDTreeFind iff NERDTree is active, current window contains a modifiable file, and we're not in vimdiff
function! s:syncTree()
	let s:curwnum = winnr()
	NERDTreeFind
	exec s:curwnum . "wincmd l"
endfunction

function! s:syncTreeIf()
	if (winnr("$") > 1 && s:isNERDTreeOpen() && filereadable(expand('%:p')) && &modifiable && !&diff &&  bufname() != t:NERDTreeBufName)
		let s:curwnum = winnr()
		NERDTreeFind
		exec s:curwnum . "wincmd w"
	endif
	if (winnr("$") > 2 && s:isNERDTreeOpen() && filereadable(expand('%:p')) && &modifiable && !&diff &&  bufname() != t:NERDTreeBufName)
		NERDTreeToggle
	endif
endfunction

augroup NerdTree
	autocmd!
	"autocmd VimEnter * :wincmd p
	" Focus on opened view after starting (instead of NERDTree)
	autocmd VimEnter * call s:syncTree()

	autocmd BufEnter * call s:syncTreeIf()
	" Automatically close vim if only NERDTree left
	autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

augroup END


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
