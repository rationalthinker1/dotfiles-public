Plug 'AndrewRadev/switch.vim'
let g:switch_mapping = "-"
nnoremap <c-a> :call switch#Switch()<cr>
nnoremap <c-x> :call switch#Switch({'reverse': 1})<cr>

let g:switch_custom_definitions =
			\ [
			\ ['true', 'false'],
			\ ['next', 'previous'],
			\ ['dark', 'light'],
			\ ['yes', 'no'],
			\ ['on', 'off'],
			\ ['left', 'right'],
			\ ['!=', '=='],
			\ ['&&', '||'],
			\ [': ', '='],
			\ ['min', 'max'],
			\ ['@', 'this.'],
			\]

let s:switch_filetype_definitions = {}
let s:switch_filetype_definitions.javascript =
			\ [
			\   ['addClass', 'removeClass']
			\ ]

let s:switch_filetype_definitions.vim =
			\ [
			\   ['g:', 'b:', 'l:', 's:'],
			\   ['map', 'nmap', 'imap', 'vmap', 'smap', 'xmap', 'cmap', 'omap'],
			\   ['noremap', 'nnoremap', 'inoremap', 'vnoremap', 'snoremap', 'xnoremap', 'cnoremap', 'onoremap'],
			\   ['unmap', 'nunmap', 'iunmap', 'vunmap', 'sunmap', 'xunmap', 'cunmap', 'ounmap'],
			\   ['<special>', '<silent>', '<buffer>', '<expr>'],
			\ ]

let s:switch_filetype_definitions.css =
			\ [
			\    ['padding', 'margin']
			\ ]

augroup Switches
	autocmd!
	autocmd FileType css,scss,javascript   let b:switch_custom_definitions = s:switch_filetype_definitions.css
	autocmd FileType javascript let b:switch_custom_definitions = s:switch_filetype_definitions.javascript
	autocmd FileType vim        let b:switch_custom_definitions = s:switch_filetype_definitions.vim
augroup END
