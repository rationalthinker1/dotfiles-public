Plug 'scrooloose/nerdtree' " Shows file manager
let NERDTreeRespectWildIgnore = 1
let NERDTreeIgnore = ['.DS_Store', '.git', 'node_modules', '\.sublime-project', '\.sublime-workspace', '.idea']
let NERDTreeShowHidden = 1
let NERDTreeMouseMode = 2
let NERDTreeMinimalUI = 1
let NERDTreeShowFiles = 1
let NERDTreeDirArrows = 1
let g:nerd_preview_enabled = 1
let g:preview_last_buffer = 0

nnoremap <C-b> :call <SID>NERDTreeToggle()<CR>

function! s:NERDTreeToggle()
	if g:NERDTree.IsOpen()
		NERDTreeClose
	elseif bufexists(expand('%'))
		NERDTreeFind
	else
		NERDTree
	endif
endfunction

augroup NERDTree
	autocmd!
	" Focus on opened view after starting (instead of NERDTree)
	autocmd VimEnter * call s:syncTree()

	autocmd BufEnter * call s:syncTreeIf()
	" Automatically close vim if only NERDTree left
	autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
augroup END

" calls NERDTreeFind iff NERDTree is active, current window contains a modifiable file, and we're not in vimdiff
function! s:syncTree()
	let l:width = winwidth('%')
	if l:width > 120
		let s:curwnum = winnr()
		NERDTreeFind
		execute s:curwnum . "wincmd l"
	endif
endfunction

function! s:syncTreeIf()
	let l:windowCount = winnr("$")
	if (l:windowCount > 1 && g:NERDTree.IsOpen() && filereadable(expand('%:p')) && &modifiable && !&diff &&  bufname() != t:NERDTreeBufName)
		call s:syncTree()
		if l:windowCount > 2
			NERDTreeToggle
		endif
	endif
endfunction

