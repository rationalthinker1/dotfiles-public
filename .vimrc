"backspace and cursor keys wrap to previous/next line
"CTRL-X and SHIFT-Del are Cut
"CTRL-C and CTRL-Insert are Copy
"CTRL-V and SHIFT-Insert are Paste
"Use CTRL-Q to do what CTRL-V used to do
"Use CTRL-S for saving, also in Insert mode
"CTRL-Z is Undo; not in cmdline though
"CTRL-Y is Redo (although not repeat); not in cmdline though
"Alt-Space is System menu
"CTRL-A is Select all
"CTRL-Tab is Next window
"CTRL-F4 is Close window
"source $VIMRUNTIME/mswin.vim
"source ~/.vim/custom-mswin.vim
"behave mswin
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Vim-Plug Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Automatically install vim-plug and run PlugInstall if vim-plug not found
if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
				\ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
"=== Syntax Highlighting
Plug 'chr4/nginx.vim'
Plug 'vim-scripts/httplog'
Plug 'vim-scripts/apachelogs.vim'
Plug 'vim-scripts/apachestyle'
Plug 'ekalinin/Dockerfile.vim'
Plug 'stanangeloff/php.vim'
Plug 'stephpy/vim-yaml'
"Plug 'cakebaker/scss-syntax.vim'
Plug 'tmux-plugins/vim-tmux'
Plug 'burnettk/vim-angular'
" javascript
"Plug 'pangloss/vim-javascript'
"Plug 'mxw/vim-jsx'
Plug 'yuezk/vim-js'
Plug 'chemzqm/vim-jsx-improve'

"Plug 'mg979/vim-visual-multi'             " Ctrl+N to select multi-line edits and press c to change, i to add and d to delete
Plug 'tpope/vim-fugitive'                 " :Git commit :Git diff :Git log :Git difftool :Gedit HEAD~3:%
Plug 'alvan/vim-closetag'                 " autocomplete html tags
Plug 'tpope/vim-abolish'                  " foo_bar => fooBar 'crm' 'crc' 'crs' 'cr-'; :%Subvert/facilit{y,ies}/building{,s}/g
Plug 'scrooloose/nerdcommenter'           " Ability to comment out lines from many files
Plug 'Yggdroot/indentLine'                " Displays thin vertical lines at each indentation level
Plug 'junegunn/vim-easy-align'            " Highlight area, press ga{=,:, } to align by it
Plug 'tpope/vim-eunuch'                   " Adds methods like :Rename :Delete :Move :Chmod :Mkdir :SudoWrite
Plug 'luochen1990/rainbow'                " Rainbow Parentheses
Plug 'bronson/vim-trailing-whitespace'    " Adds command :FixWhitespace
Plug 'tpope/vim-surround'                 " cs)} -> change surrounding from ) to }; ds( -> delete surrounding (; ysiw} -> yank surrounding inside word }
Plug 'tpope/vim-repeat'                   " repeat using . for non-ing . for non-native commands too
Plug 'ConradIrwin/vim-bracketed-paste'    " enables transparent pasting into vim. (i.e. no more :set paste!)
Plug 'farmergreg/vim-lastplace'           " reopen files at your last edit position
Plug 'chip/vim-fat-finger'                " Automatically corrects common misspellings and typos as you type
Plug 'mhinz/vim-startify'                 " vim start menu showing last open files on vim
Plug 'easymotion/vim-easymotion'          " Press <leader><leader>w and type one of the highlighted characters
Plug 'kshenoy/vim-signature'              " Shows bookmarks visually on the left
Plug 'tmux-plugins/vim-tmux-focus-events' " Focus is gain when switching back and forth with tmux screens
Plug 'christoomey/vim-tmux-navigator'     " Using same keys to move between tmux and vim panes
Plug 'airblade/vim-rooter'                " Loads up root directory of the project automatically
Plug 'simeji/winresizer'                  " Ctrl-E and you can resize current vim windows using 'h', 'j', 'k', 'l' keys
Plug 'PeterRincker/vim-argumentative'     " Shifting arguments with <, and >,
Plug 'blueyed/vim-diminactive'            " Dims inactive windows
Plug 'andymass/vim-matchup'               " Press % to navigate between if endif, while done
Plug 'qstrahl/vim-dentures'               " in visual mode, press ai to select indented section
Plug 'ap/vim-buftabline'                  " Shows buffer tab at the top
"Plug 'skywind3000/asyncrun.vim'          " Runs commands asynchronously
Plug 'knubie/vim-kitty-navigator'
Plug 'cohama/lexima.vim'                  " autoclose { in functions, if statements
let g:lexima_enable_basic_rules = 0

"=== Custom configurations
source ~/.vim/themes.vim        " themes
source ~/.vim/coc.vim           " Autocomplete for many languages
source ~/.vim/lightline.vim     " Shows little bar at the bottom
source ~/.vim/fzf.vim           " Fast search by pressing f
source ~/.vim/gutentags.vim     " Creates tag automatically
source ~/.vim/nerdtree.vim      " Show files and folders in current directory by pressing Ctrl+b
source ~/.vim/tagbar.vim        " Tagbar to show methods/variable by pressing F8
source ~/.vim/snippets.vim      " useful snippets (ultisnips is the engine).
source ~/.vim/switches.vim      " useful switches like true => false with Ctrl+A
source ~/.vim/clever-f.vim      " drop in replacement for f but go to next search result with f rather than ;
"source ~/.vim/vim-sneak.vim     " search with s{char}{char} and press ; or , go to backward or forward
source ~/.vim/insearch.vim      " provides incremental highlighting for all patterns matches unlike default 'incsearch'
source ~/.vim/vim-asterisk.vim  " press z* when over a word and press cgn to replace the word and press '.' to change other instances of that word
source ~/.vim/vim-smoothie.vim  " smooth scrolling
source ~/.vim/vim-smartword.vim " drop-in replacement for word (w) searching
call plug#end()

set termguicolors
let ayucolor="mirage"
set background=dark
color onedark
color ayu
highlight Comment cterm=italic
let g:one_allow_italics = 1 " I love italic for comments
let g:onedark_terminal_italics = 1
set background=dark

" Fixed tearing in kitty
" https://sw.kovidgoyal.net/kitty/faq.html#using-a-color-theme-with-a-background-color-does-not-work-well-in-vim
let &t_ut=''

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ","
let g:mapleader = ","

augroup common
	autocmd!
	" Clear jump list
	autocmd VimEnter * clearjumps
	" Locate cursor to the last position
	autocmd BufReadPost *
				\ if line("'\"") > 1 && line("'\"") <= line("$") && &filetype !~# 'commit' |
				\     execute "normal! g`\"" |
				\ endif
augroup END

" maps caplock to esc
augroup caplock
	autocmd!
	autocmd VimEnter * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape' 1>/dev/null 2>&1 &
	autocmd VimLeave * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Caps_Lock' 1>/dev/null 2>&1 &
augroup END

set encoding=UTF-8

"" no one is really happy until you have this shortcuts
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qall! qall!
cnoreabbrev Wq wq
cnoreabbrev Wa wa
cnoreabbrev wQ wq
cnoreabbrev WQ wq
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qall qall

" Set zsh aliases
set shell=/bin/zsh\ -l
let $BASH_ENV = "~/.dotfiles/zsh/aliases.zsh"

" https://vim.fandom.com/wiki/Set_working_directory_to_the_current_file
"autocmd BufEnter * silent! lcd %:p:h

" https://vim.fandom.com/wiki/Map_Ctrl-S_to_save_current_or_new_files
" Use CTRL-S for saving, also in Insert mode (<C-O> doesn't work well when
" using completions).
" Ctrl+S to save
" If the current buffer has never been saved, it will have no name,
" call the file browser to save it, otherwise just save it.
command -nargs=0 -bar Update if &modified
			\|    if empty(bufname('%'))
				\|        browse confirm write
				\|    else
					\|        confirm write
					\|    endif
					\|endif
nnoremap <silent> <C-s> :<C-u>Update<CR>
inoremap <C-s> <Esc>:Update<CR>
vmap <C-s> <esc>:w<CR>gv

" Sets how many lines of history VIM has to remember
set history=700

" v$ doesn't select newline
" https://vi.stackexchange.com/questions/12607/extend-visual-selection-til-the-last-character-on-the-line-excluding-the-new-li
set selection=exclusive
set backspace=indent,eol,start
" https://stackoverflow.com/questions/3676388/cursor-positioning-when-entering-insert-mode
" end of line $ goes to after the last character, not before
set virtualedit+=onemore
noremap $ g$
" Remap VIM 1 to first non-blank character and 2 to the last non-blank character
nmap 1 ^
nmap 2 $
" mapping for <End>
nmap <Esc>[4~ $

"These are to cancel the default behavior of d, D, c, C
"  to put the text they delete in the default register.
"  Note that this means e.g. "ad won't copy the text into
"  register a anymore.  You have to explicitly yank it.
nnoremap d "_d
xnoremap d "_d
nnoremap D "_D
xnoremap D "_D
nnoremap c "_c
xnoremap c "_c
nnoremap C "_C
xnoremap C "_C

" <Delete> key
nnoremap <Esc>[3~ "_x
xnoremap <Esc>[3~ "_x

" change lines without copying it (use x to cut)
nnoremap c "_c
vnoremap c "_c

" Pasting like windows
" Automatically indent pasted lines
"map p		"+gP
" Needed to fix up pasting (highlighted and paste right after cursor)
" https://unix.stackexchange.com/questions/5056/cursor-position-after-pasting-in-vi-vim
nnoremap p P=`]<Right>
nmap P o<esc>gp=`]
noremap gp p
noremap gP P

" will highlight current word
nnoremap ww viw
" replace current word
inoremap <C-x> <Esc>viwc
" Yank current word with just y
nnoremap y viwy<Esc>
" Replace current word
nnoremap x viwc

nnoremap <C-Up> 5k
nnoremap <C-Down> 5j

"vnoremap > iw
"vnoremap < '>iwob

" using Shift-End in visual mode to select end of line except newline
" use sed -n l and type in <End> to get these characters
" use sed -n l and type in <End> to get these characters
"vmap <Esc>[1;2F $h
"nmap <Esc>[1;2F v$h
"vmap <Esc>[1;2H ^
"nmap <Esc>[1;2H v^

"nmap <Esc>[1;2B :echo 'Hello'<cr>V<Down>
" Change to visual mode with shift key
" https://stackoverflow.com/questions/9721732/mapping-shift-arrows-to-selecting-characters-lines
nmap <S-Up> v<Up>
nmap <S-Down> v<Down>
nmap <S-Left> v<Left>
nmap <S-Right> v<Right>
vmap <S-Up> <Up>
vmap <S-Down> <Down>
vmap <S-Left> <Left>
vmap <S-Right> <Right>
imap <S-Up> <Esc>v<Up>
imap <S-Down> <Esc>v<Down>
imap <S-Left> <Esc>v<Left>
imap <S-Right> <Esc>v<Right>
nmap <S-End> v$
vmap <S-End> $
imap <S-End> <Esc>lv$
nmap <S-Home> v^
vmap <S-Home> ^
imap <S-Home> <Esc>v^
"nmap <Esc>[1;2F v$
"vmap <Esc>[1;2F $
"<S-Home>
"nmap <Esc>[1;2H v^
"vmap <Esc>[1;2H ^

" Enable filetype plugins
filetype plugin on
filetype indent on

" Set to auto read when a file is changed from the outside
set autoread

" https://www.reddit.com/r/vim/comments/1vdrxg/space_is_a_big_key_what_do_you_map_it_to/
"map <space> <leader>

" always keep the cursorline in the middle of the screen except at buffer start and end
set scrolloff=999

" renders the changes onces when the macro completes rather than the default behaviour of simultaneously executing macros and rendering changes
set lazyredraw
set ttyfast

" Because I always forget to type /g and I don't think I've ever had the need to search and replace only one instance on a line.
set gdefault

" adds - as a word character in html and css files, since those are often used in attributes and classes
au FileType html,css setlocal isk+=45

" shows where your cursor
set cursorline

"inoremap <Shift> <ESC>v
" escape insert mode via 'Ctrl+Space'
imap <C-Space> <Esc>

" keep in visual mode after identing by shift+> in vim
" https://superuser.com/questions/310417/how-to-keep-in-visual-mode-after-identing-by-shift-in-vim
vnoremap , <gv
vnoremap . >gv

" Manually sets the mappings
call lexima#set_default_rules()
" https://github.com/cohama/lexima.vim/issues/65
call lexima#insmode#map_hook('before', '<CR>', '')

function! s:my_cr_function() abort
  " Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
  " Coc only does snippet and additional edit on confirm.
  " :h complete_CTRL-Y used to accept completion
  " lexima needs to be triggered manually because it conflicts with <CR>
  return pumvisible() ? "\<C-y>" : "\<C-g>u" . lexima#expand('<CR>', 'i')
endfunction

inoremap <CR> <C-r>=<SID>my_cr_function()<CR>

" shortcut for :%s/.../.../g
nnoremap s :%s///g<LEFT><LEFT><LEFT>
xnoremap s :s///g<LEFT><LEFT><LEFT>

" backup current file
nnoremap <leader>bu :!cp % %.bak<CR><CR>:echomsg "Backed up" expand('%')<CR>

" toggle wrap on current file
nnoremap <leader>w :set wrap!<cr>

" Allows arrow keys to move the cursor left/right to move to the previous/next line
set whichwrap+=<,>,[,]

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" Don't redraw while executing macros (good performance config)
set lazyredraw

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch

" How many tenths of a second to blink when matching brackets
set matchtime=5

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Show the keys that vim is receiving (what you are typing) in command
set showcmd

" applies substitutions globally by default on lines. For example, instead of :%s/foo/bar/g you just type :%s/foo/bar/
set gdefault

" Setup undo history persistent
set undofile                " Save undos after file closes
set undolevels=1000                 " How many undos
set undoreload=10000                " number of lines to save for undo
set backup                          " enable backups
set noswapfile                      " No creating .swap files
set undodir=$HOME/.vim/tmp/undo     " undo files
set backupdir=$HOME/.vim/tmp/backup " backups
set directory=$HOME/.vim/tmp/swap   " swap files

" Make those folders automatically if they don't already exist.
if !isdirectory(expand(&undodir))
	call mkdir(expand(&undodir), "p")
endif
if !isdirectory(expand(&backupdir))
	call mkdir(expand(&backupdir), "p")
endif
if !isdirectory(expand(&directory))
	call mkdir(expand(&directory), "p")
endif


" load fzf for vim
set rtp+=~/.fzf
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set 7 lines to the cursor - when moving vertically using j/k
set scrolloff=7

" Turn on the WiLd menu
set wildmenu
set wildmode=longest:full,full

" Ignore compiled files
set wildignore=*.o,*~,*.pyc
set wildignore+=*/tmp/*
set wildignore+=*/target/*
set wildignore+=*/build/*
set wildignore+=*.so
set wildignore+=*.o
set wildignore+=*.class
set wildignore+=*.swp
set wildignore+=*.zip
set wildignore+=*.pdf
set wildignore+=*.pyc
set wildignore+=*/node_modules/*
set wildignore+=*/vendor/*
set wildignore+=*/bower_components/*
set wildignore+=*/dist/*

" always show current position
set ruler

" Height of the command bar
set cmdheight=2

" Use tabs to switch between brackets
"nnoremap <tab> %
"vnoremap <tab> %

" Go back and forth to cursor position
map <Esc> <C-A-q>
map <C-A-q> <C-O>
map <Esc> <C-A-w>
map <C-A-w> <C-I>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Buffer Settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" This allows buffers to be hidden if you've modified a buffer.
" This is almost a must if you wish to use buffers in this way.
set hidden

" To open a new empty buffer
" This replaces :tabnew which I used to bind to this mapping
nnoremap <leader>T :enew<cr>

" Move to the next buffer
nnoremap <A-PageDown> :bnext<CR>

" Move to the previous buffer
nnoremap <A-PageUp> :bprevious<CR>

autocmd FileType nerdtree noremap <buffer> <A-PageDown> <ESC>:wincmd w <bar> bnext<CR>
autocmd FileType nerdtree noremap <buffer> <A-PageUp> <ESC>:wincmd w <bar> bprevious<CR>

" Close buffer like closing Chrome's tab
function! CloseBuffer() abort
	if &filetype ==? 'nerdtree'
		wincmd w
	endif
	if &buftype ==? 'quickfix'
		cclose
		return 1
	endif
	let l:nerdtreeOpen = g:NERDTree.IsOpen()
	let l:windowCount = winnr('$')
	let l:command = 'bdelete'
	let l:totalBuffers = len(getbufinfo({ 'buflisted': 1 }))
	let l:isNerdtreeLast = l:nerdtreeOpen && l:windowCount ==? 2
	let l:noSplits = !l:nerdtreeOpen && l:windowCount ==? 1
	if l:totalBuffers > 1 && (l:isNerdtreeLast || l:noSplits)
		let l:command = 'bprevious | bdelete! # | NERDTree | wincmd w | NERDTreeFind | wincmd w'
		"for i in range(1, bufnr("$"))
		"if buflisted(i) && getbufvar(i, "&diff")
		"if l:count == a:num
		"exe "buffer " . i
		"return
		"endif
		"endif
		"endfor
	endif
	if l:totalBuffers == 1 && (l:isNerdtreeLast || l:noSplits)
		let l:command = 'quit!'
	endif
	if l:totalBuffers > 1 && !l:nerdtreeOpen && l:windowCount > 1
		let bDiff = filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&diff") && getbufvar(v:val, "&modifiable")')
		if len(bDiff) == 1
			let l:command = l:command . ' | NERDTreeToggle | wincmd w'
			execute "normal! <C-o>"
		endif
	endif
	silent execute l:command

endfunction
nnoremap <C-w> :call CloseBuffer()<cr>

" Show all open buffers and their status
nnoremap <leader>bl :ls<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable syntax highlighting
syntax on
syntax enable

highlight Pmenu guibg=white guifg=black gui=bold
highlight Comment gui=bold
highlight Normal gui=none

set termencoding=utf-8
" Set extra options when running in GUI mode
if has("gui_running")
	set guifont=IBM\ Plex\ Mono\ Semi-Bold\ 10
	set guioptions=abegmrLtT
	"set guioptions-=T
	set guioptions+=e
	set t_Co=256
	set guitablabel=%M\ %t
	" Show popup menu if right click.
	set mousemodel=popup

	" Allow using alt keys in vim for mapping for GUI only
	set winaltkeys=no

	" Don't focus the window when the mouse pointer is moved.
	set nomousefocus
	map <S-Insert> <MiddleMouse>
	map! <S-Insert> <MiddleMouse>
endif

" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8

" Use Unix as the standard file type
set ffs=unix,dos,mac


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use tabs instead of spaces
set autoindent
set noexpandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 4 spaces
set softtabstop=4
set shiftwidth=4
set tabstop=4

" Linebreak on 500 characters
set lbr
set tw=500


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Treat long lines as break lines (useful when moving around in them)
nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

" Disable highlight when <leader><cr> is pressed
noremap <silent> <leader><cr> :noh<cr>

" Smart way to move between windows
"map <A-Right> <C-W>l
"map <A-Left> <C-W>h
"map <A-Up> <C-W>k
"map <A-Down> <C-W>j

" Close the current buffer
noremap <leader>bd :Bclose<cr>

function! SaveCountOfTextOnRegister(text)
	let @c = GetCount(a:text)
endfunction

" see if new plugins were added
function! InstallPlugins(text, code)
	call AutoPlaceMarkBasedOnText(a:text, a:code)

	let l:old_count = @c
	let l:new_count = GetCount("^Plug '")
	let @c = l:new_count
	if l:new_count > l:old_count
		"PlugInstall
		"sleep 500m
		"q
		"wincmd w
	endif
endfunction

" auto place mark on file based on text
function! AutoPlaceMarkBasedOnText(text, code)
	let l:new_position = search(a:text, 'nc')
	call setpos(a:code, [0,l:new_position,1,0])
endfunction

function! GetCount(pattern)
	let l:cnt = 0
	silent execute '%s/' . a:pattern . '/\=execute(''let l:cnt += 1'')/gn'
	return l:cnt
endfunction

" Automatically reload vimrc when it's saved
augroup vimrc
	autocmd!
	autocmd BufWritePost *.vim,.vimrc :echom "Reloading .vimrc"
	autocmd BufWritePost *.vim,.vimrc :sleep 500m
	autocmd BufWritePost *.vim,.vimrc :source $MYVIMRC
	autocmd BufReadPost  .vimrc :call SaveCountOfTextOnRegister("^Plug '")
	autocmd BufWritePost .vimrc :call InstallPlugins('^call plug#end()', "'P")
	autocmd BufWritePost .vimrc :call AutoPlaceMarkBasedOnText('^augroup vimrc', "'a")
augroup END

" Close all the buffers
noremap <leader>ba :1,1000 bd!<cr>

" Use <Tab> to navigate
nmap <Tab> %

" https://stackoverflow.com/questions/21321357/how-can-i-cause-the-quickfix-window-to-close-after-i-select-an-item-in-it
" close quickfix after selecting a file
autocmd FileType qf nnoremap <buffer> <CR> <CR>:cclose<CR>

" Useful mappings for managing tabs
noremap <leader>tn :tabnew<cr>
noremap <leader>to :tabonly<cr>
noremap <leader>tc :tabclose<cr>
noremap <leader>tm :tabmove

" Adds semicolon at the end of the line
inoremap <C-S-L> <C-o>A;

function! ReindentFile()
	let l:win_view = winsaveview()
	let l:old_query = getreg('/')
	execute "normal! gg=G"
	call winrestview(l:win_view)
	call setreg('/', l:old_query)
endfunction
map <Esc> <C-A-L>
nnoremap <C-A-L> :call ReindentFile()<cr>

" change current file to working directory
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
noremap <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

" Specify the behavior when switching between buffers
try
	set switchbuf=useopen,vsplit
	set showtabline=2
catch
endtry

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
			\ if line("'\"") > 0 && line("'\"") <= line("$") |
			\   exe "normal! g`\"" |
			\ endif

" Remember info about open buffers on close
set viminfo^=%
set viminfo+=n~/.vim/.viminfo


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" when searching, you can use Perl's regex rather than using vim's own regex system
"nnoremap / /\v
"vnoremap / /\v


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pressing ,ss will toggle and untoggle spell checking
noremap <F7> :setlocal spell!<cr>

" Shortcuts using <leader>
noremap <leader>sn ]s
noremap <leader>sp [s
noremap <leader>sa zg
noremap <leader>s? z=


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" creates title banner
nnoremap <leader>title 63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`oi<space>
vnoremap <leader>title ydd63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`opi<bs>

function! ReplaceTextUntil(char)
	execute "normal vt" . a:char . "d"
	call feedkeys('i')
endfunc
nnoremap w' :call ReplaceTextUntil("'")<cr>
nnoremap w" :call ReplaceTextUntil('"')<cr>
nnoremap w; :call ReplaceTextUntil(';')<cr>
nnoremap w. :call ReplaceTextUntil('.')<cr>
nnoremap w> :call ReplaceTextUntil('<')<cr>
nnoremap w) :call ReplaceTextUntil(')')<cr>

function! PasteText(mode)
	let old_reg = getreg("c")               " Save the current content of register 'c'
	let old_reg_type = getregtype("c")      " Save the type of the register as well

	if a:mode ==? 'v'
		let [ l:line_start, l:column_start, l:line_end, l:column_end ] = GetVisualSelectionLine()
		if l:line_end == l:line_start
			" gv -> select previously highlighted portion
			" "cy -> copy highlighted portion to register c
			" '> -> to go end of the highlighted portion
			" "cP -> paste from register c
			execute 'normal! gv"cy`>"cP'
		else
			execute 'normal! gv"cy`>j"cP'
		endif
		call setpos("'<", getpos("'["))
		call setpos("'>", getpos("']"))
		execute	"normal! gvl"
	else
		let l:y = line('.')
		let l:x = col('.')
		" Copies current line to register c and then paste line from register c
		execute 'normal! "cY"cp'
		cal cursor(l:y+1, l:x)
	endif

	call setreg("c", old_reg, old_reg_type) " Restore register 'c'
	if a:mode ==? 'i'
		call feedkeys(a:mode)
	endif
endfunc

inoremap <C-d> <esc>:call PasteText('i')<cr>
nnoremap <C-d> <esc>:call PasteText('n')<cr>
vnoremap <C-d> <esc>:call PasteText('v')<cr>
inoremap <C-d> <esc>:call PasteText('i')<cr>

" delete current line
function! DeleteCurrentLine(mode)
	let l:y = line('.')
	let l:x = col('.')
	if a:mode == 'i'
		execute "normal! dd"
		cal cursor(l:y, l:x+1)
		call feedkeys(a:mode)
	elseif a:mode == 'n'
		execute "normal! dd"
		cal cursor(l:y, l:x)
	else
		let [line_start, column_start] = getpos("'<")[1:2]
		let [line_end, column_end] = getpos("'>")[1:2]
		execute line_start . ",". line_end . "d"
	endif
endfunction
inoremap <C-y> <esc>:call DeleteCurrentLine('i')<cr>
nnoremap <C-y> <esc>:call DeleteCurrentLine('n')<cr>
vnoremap <C-y> <esc>:call DeleteCurrentLine('v')<cr>

" clears content from the cursor to the end while in insert mode
"inoremap <C-c> <esc>lc$

" runs macro based on selected lines
function! ExecuteMacroOverVisualRange()
	echo "@".getcmdline()
	execute ":'<,'>normal @".nr2char(getchar())
endfunction
xnoremap @ :<C-u>call ExecuteMacroOverVisualRange()<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Helper functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! GetVisualSelectionLine()
	if mode()=="v"
		let [line_start, column_start] = getpos("v")[1:2]
		let [line_end, column_end] = getpos(".")[1:2]
	else
		let [line_start, column_start] = getpos("'<")[1:2]
		let [line_end, column_end] = getpos("'>")[1:2]
	end
	if (line2byte(line_start)+column_start) > (line2byte(line_end)+column_end)
		let [line_start, column_start, line_end, column_end] =
					\   [line_end, column_end, line_start, column_start]
	end
	" 'selection' is a rarely-used option for overriding whether the last
	" character is included in the selection. Bizarrely, it always affects the
	" last character even when selecting from the end backwards.
	if &selection !=# 'inclusive'
		let column_end -= 1
	endif
	return [line_start, column_start, line_end, column_end]
endfunction

function! VisualSelect()
	let [ line_start, column_start, line_end, column_end ] = GetVisualSelectionLine()
	let lines = getline(line_start, line_end)
	if len(lines) == 0
		return ''
	endif
	let lines[-1] = lines[-1][: column_end - 1]
	let lines[0] = lines[0][column_start - 1:]
	return join(lines, "\n")
endfunction


function! VisualSelection(direction) range
	let l:saved_reg = @"
	execute "normal! vgvy"

	let l:pattern = escape(@", '\\/.*$^~[]')
	let l:pattern = substitute(l:pattern, "\n$", "", "")

	if a:direction == 'b'
		execute "normal ?" . l:pattern . "^M"
	elseif a:direction == 'gv'
		call CmdLine("vimgrep " . '/'. l:pattern . '/' . ' **/*.')
	elseif a:direction == 'replace'
		call CmdLine("%s" . '/'. l:pattern . '/')
	elseif a:direction == 'f'
		execute "normal /" . l:pattern . "^M"
	endif

	let @/ = l:pattern
	let @" = l:saved_reg
endfunction

"  Raza's custom commands
set showmode              " always show what mode we're currently editing in
set nowrap                " don't wrap lines
set shiftround            " use multiple of shiftwidth when indenting with '<' and '>'
set copyindent            " copy the previous indentation on autoindenting
set number                " always show line numbers
set autowrite             " Save on buffer switch
set clipboard=unnamedplus " register to global clipboard
set notimeout             " don't timeout vim mappings
set mouse=a               " enable mouse use in terminal
set splitright            " splitting a window will put the new window right
set splitbelow            " splitting a window will put the new window below
set pastetoggle=<F3>      " before pasting, press F3 to get into paste mode, not needed now

" Move current line or visual block up/down
nnoremap <C-S-Up> <ESC>:m -2<CR>
nnoremap <C-S-Down> <ESC>:m +1<CR>
inoremap <C-S-Up> <ESC>:m -2<CR>
inoremap <C-S-Down> <ESC>:m +1<CR>
vmap <C-S-Up>    <Plug>SchleppIndentUp
vmap <C-S-Down>  <Plug>SchleppIndentDown
vmap <C-S-Left>  <Plug>SchleppLeft
vmap <C-S-Left>  <Plug>SchleppLeft
vmap <C-S-Right> <Plug>SchleppRight
"vmap <C-d> <Plug>SchleppDup

nnoremap <leader>- :new<cr>
nnoremap <leader><bar> :vnew<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Yggdroot/indentLine
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" IndentLine {{
"let g:indentLine_char = ''
"let g:indentLine_first_char = ''
let g:indentLine_showFirstIndentLevel = 1
let g:indentLine_setColors = 0
" }}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Rainbow Parentheses
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:rainbow_active = 1
let g:rainbow_conf = { 'operators': '_,\|=\|+\|\*\|-\|\.\|;\||\|&\|?\|:\|<\|>\|%\|/[^/]_' }


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--EasyAlign Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--KittyVim Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:kitty_navigator_no_mappings = 0
map <A-Left> :KittyNavigateLeft<cr>
map <A-Down> :KittyNavigateDown<cr>
map <A-Up> :KittyNavigateUp<cr>
map <A-Right> :KittyNavigateRight<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Nerdcommenter Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" _ is /
map <C-_> <Plug>NERDCommenterToggle
map <C-_> <Plug>NERDCommenterToggle

" Sets Gitdiff algorithm
set diffopt+=algorithm:patience
" Lets you see nth revision ago of the current file
function! PreviewRevision(n)
	let @d = a:n
	let l:commit = system('git log ' .  expand('%') . ' | grep "commit" | cut -d" " -f2 | sed -n ' . a:n . 'p')
	execute "normal! :Gvdiffsplit " . l:commit
	"NERDTreeClose
endfunction
"autocmd Syntax git setlocal nonumber
autocmd Syntax fugitive <buffer> call <SID>fugitive_settings()
function! s:fugitive_settings()
	"vertical resize 30
	set nowrap
	set winfixwidth
	NERDTreeClose
	set nonumber
endfunction
augroup fugitiveSettings
	autocmd!
	autocmd FileType gitcommit setlocal nolist
	autocmd BufReadPost fugitive://* setlocal bufhidden=delete
	autocmd BufReadPost fugitive://* call s:fugitive_settings()
augroup END
