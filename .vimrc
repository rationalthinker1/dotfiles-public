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
Plug 'cakebaker/scss-syntax.vim'
Plug 'tmux-plugins/vim-tmux'

Plug 'mg979/vim-visual-multi', {'branch': 'master'} " Ctrl+N to select multi-line edits and press c to change, i to add and d to delete
Plug 'tpope/vim-fugitive'                 " :Git commit :Git diff :Git log :Git difftool :Gedit HEAD~3:%
Plug 'alvan/vim-closetag'                 " autocomplete html tags
Plug 'tpope/vim-abolish'                  " foo_bar => fooBar 'crm' 'crc' 'crs' 'cr-'; :%Subvert/facilit{y,ies}/building{,s}/g
Plug 'scrooloose/nerdcommenter'           " Ability to comment out lines from many files
Plug 'Yggdroot/indentLine'                " Displays thin vertical lines at each indentation level
Plug 'junegunn/vim-easy-align'            " Highlight area, press ga{=,:, } to align by it
Plug 'tpope/vim-eunuch'                   " Adds methods like :Rename :Delete :Move :Chmod :Mkdir :SudoWrite
Plug 'luochen1990/rainbow'                " Rainbow Parentheses
Plug 'sheerun/vim-polyglot'               " Language packs for Vim
Plug 'bronson/vim-trailing-whitespace'    " Adds command :FixWhitespace
Plug 'tpope/vim-surround'                 " cs)} -> change surrounding from ) to }; ds( -> delete surrounding (; ysiw} -> yank surrounding inside word }
Plug 'tpope/vim-repeat'                   " repeat using . for non-ing . for non-native commands too
Plug 'ConradIrwin/vim-bracketed-paste'    " enables transparent pasting into vim. (i.e. no more :set paste!)
Plug 'farmergreg/vim-lastplace'           " reopen files at your last edit position
Plug 'chip/vim-fat-finger'                " Automatically corrects common misspellings and typos as you type
Plug 'mhinz/vim-startify'                 " vim start menu showing last open files on vim
Plug 'psliwka/vim-smoothie'               " Smooth scroll
Plug 'easymotion/vim-easymotion'          " Press <leader><leader>w and type one of the highlighted characters
Plug 'kshenoy/vim-signature'              " Shows bookmarks visually on the left
Plug 'tmux-plugins/vim-tmux-focus-events' " Focus is gain when switching back and forth with tmux screens
Plug 'christoomey/vim-tmux-navigator'     " Using same keys to move between tmux and vim panes
Plug 'rhysd/clever-f.vim'                 " Extends f, F, t and T mappings. Key f is available to repeat after you type f{char} or F{char}

"=== Themes
Plug 'micke/vim-hybrid'
Plug 'hzchirs/vim-material'
Plug 'daylerees/colour-schemes', { 'rtp': 'vim/' }
Plug 'simonsmith/material.vim'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'evturn/cosmic-barf'
Plug 'zirrostig/vim-schlepp'

"=== Custom configurations
source ~/.vim/custom-coc.vim       " Autocomplete for many languages
source ~/.vim/custom-lightline.vim " Shows little bar at the bottom
source ~/.vim/custom-fzf.vim       " Fast search by pressing f
source ~/.vim/custom-gutentags.vim " Creates tag automatically
source ~/.vim/custom-nerdtree.vim  " Show files and folders in current directory by pressing Ctrl+b
source ~/.vim/custom-tagbar.vim    " Tagbar to show methods/variable by pressing F9
source ~/.vim/custom-snippets.vim  " A bunch of useful language related snippets (ultisnips is the engine).
call plug#end()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set zsh aliases
set shell=zsh\ -i
let $BASH_ENV = "~/.dotfiles/zsh/aliases.zsh"

" https://vim.fandom.com/wiki/Set_working_directory_to_the_current_file
autocmd BufEnter * silent! lcd %:p:h

" Sets how many lines of history VIM has to remember
set history=700

" v$ doesn't select newline
" https://vi.stackexchange.com/questions/12607/extend-visual-selection-til-the-last-character-on-the-line-excluding-the-new-li
set selection=exclusive

" Enable filetype plugins
filetype plugin on
filetype indent on

" Set to auto read when a file is changed from the outside
set autoread

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ","
let g:mapleader = ","

" https://www.reddit.com/r/vim/comments/1vdrxg/space_is_a_big_key_what_do_you_map_it_to/
map <space> <leader>

" shows where your cursor
set cursorline

" https://vim.fandom.com/wiki/Map_Ctrl-S_to_save_current_or_new_files
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
nnoremap <silent> <C-S> :<C-u>Update<CR>
inoremap <c-s> <Esc>:Update<CR>
vmap <C-s> <esc>:w<CR>gv

" escape insert mode via 'aa'
inoremap aa <ESC>
"inoremap <Shift> <ESC>v
" escape insert mode via 'Ctrl+Space'
map <C-Space> <Esc>

" keep in visual mode after identing by shift+> in vim
" https://superuser.com/questions/310417/how-to-keep-in-visual-mode-after-identing-by-shift-in-vim
vnoremap < <gv
vnoremap > >gv

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" shortcut for :%s/.../.../g
nnoremap S :%s//g<LEFT><LEFT>
xnoremap S :s//g<LEFT><LEFT>

" backup current file
nnoremap <leader>bu :!cp % %.bak<CR><CR>:echomsg "Backed up" expand('%')<CR>

" Fast saving
nnoremap <leader>w :set wrap!<cr>

" Configure backspace so it acts as it should act
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

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
set undolevels=1000         " How many undos
set undoreload=10000        " number of lines to save for undo

set backup                        " enable backups
set noswapfile                    " it's 2013, Vim.

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

" Allow using alt keys in vim for mapping
set winaltkeys=no

" Go back and forth to cursor position
map <Esc> <C-A-q>
nnoremap <C-A-q> <C-O>
map <Esc> <C-A-w>
nnoremap <C-A-w> <C-I>


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

" Close buffer like closing Chrome's tab
nnoremap <C-w> :bd<CR>

" Close the current buffer and move to the previous one
" This replicates the idea of closing a tab
nnoremap <leader>bq :bp <BAR> bd #<CR>

" Show all open buffers and their status
nnoremap <leader>bl :ls<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable syntax highlighting
syntax enable
syntax on
set background=dark
set termguicolors
color dracula

highlight Pmenu guibg=white guifg=black gui=bold
highlight Comment gui=bold
highlight Normal gui=none

set termencoding=utf-8
set guifont=IBM\ Plex\ Mono\ Semi-Bold\ 10
" Set extra options when running in GUI mode
if has("gui_running")
	set guioptions=abegmrLtT
	"set guioptions-=T
	set guioptions+=e
	set t_Co=256
	set guitablabel=%M\ %t
	" Show popup menu if right click.
	set mousemodel=popup

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
"--Files, backups and undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn backup off, since most stuff is in SVN, git et.c anyway...
set nobackup
set nowb
set noswapfile


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


""""""""""""""""""""""""""""""
"--Visual mode related
""""""""""""""""""""""""""""""
" Visual mode pressing * or # searches for the current selection
vnoremap <silent> * :call VisualSelection('f')<CR>
vnoremap <silent> # :call VisualSelection('b')<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Treat long lines as break lines (useful when moving around in them)
nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

" Disable highlight when <leader><cr> is pressed
noremap <silent> <leader><cr> :noh<cr>

" Smart way to move between windows
nnoremap <A-Right> <C-W>l
nnoremap <A-Left> <C-W>h
nnoremap <A-Up> <C-W>k
nnoremap <A-Down> <C-W>j

inoremap <A-Right> <C-W>l
inoremap <A-Left> <C-W>h
inoremap <A-Up> <C-W>k
inoremap <A-Down> <C-W>j

" Close the current buffer
noremap <leader>bd :Bclose<cr>

function! SavePositionOfTextOnRegister(text)
	let @p = search(a:text, 'nc')
endfunction

" auto place mark on file based on text
function! AutoPlaceMarkBasedOnText(text, code)
	let l:old_position = @p
	let l:new_position = search(a:text, 'nc')
	call setpos(a:code, [0,l:new_position,1,0])
	if l:old_position != l:new_position
		let @p = search(a:text, 'nc')
		PlugInstall
	endif
endfunction

" Automatically reload vimrc when it's saved
augroup vimrc
	autocmd!
	autocmd BufWritePost *.vim,.vimrc :echom "Reloading .vimrc"
	autocmd BufWritePost *.vim,.vimrc :sleep 500m
	autocmd BufWritePost *.vim,.vimrc :source $MYVIMRC
	autocmd BufReadPost  .vimrc :call SavePositionOfTextOnRegister('^call plug#end()')
	autocmd BufWritePost .vimrc :call AutoPlaceMarkBasedOnText('^call plug#end()', "'p")
augroup END

" Close all the buffers
noremap <leader>ba :1,1000 bd!<cr>

" delete lines without copying it (use x to cut)
nnoremap d "_d
vnoremap d "_d

" Useful mappings for managing tabs
noremap <leader>tn :tabnew<cr>
noremap <leader>to :tabonly<cr>
noremap <leader>tc :tabclose<cr>
noremap <leader>tm :tabmove

" Needed to fix up pasting (highlighted and paste right after cursor)
" https://unix.stackexchange.com/questions/5056/cursor-position-after-pasting-in-vi-vim
noremap p gP
noremap P gP
noremap gp p
noremap gP P
noremap y ygv<Esc>

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
	set switchbuf=useopen,usetab,newtab
	set stal=2
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


""""""""""""""""""""""""""""""
"--Status line
""""""""""""""""""""""""""""""
" Always show the status line
set laststatus=2

" Format the status line
set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remap VIM 1 to first non-blank character and 2 to the last non-blank character
nnoremap 1 ^
nnoremap 2 $


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--vimgrep searching and cope displaying
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" When you press gv you vimgrep after the selected text
vnoremap <silent> gv :call VisualSelection('gv')<CR>

" Open vimgrep and put the cursor in the right position
noremap <leader>g :vimgrep // **/*.<left><left><left><left><left><left><left>

" Vimgreps in the current file
noremap <leader><space> :vimgrep // <C-R>%<C-A><right><right><right><right><right><right><right><right><right>

" When you press <leader>r you can search and replace the selected text
vnoremap <silent> <leader>r :call VisualSelection('replace')<CR>

" Do :help cope if you are unsure what cope is. It's super useful!
"
" When you search with vimgrep, display your results in cope by doing:
"   <leader>cc
"
" To go to the next search result do:
"   <leader>n
"
" To go to the previous search results do:
"   <leader>p

noremap <leader>cc :botright cope<cr>
" Makes a copy of the current buffer and pastes it in a new tab
noremap <leader>co ggVGy:tabnew<cr>:set syntax=qf<cr>pgg

" when searching, you can use Perl's regex rather than using vim's own regex system
nnoremap / /\v
vnoremap / /\v


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pressing ,ss will toggle and untoggle spell checking
noremap <leader>ss :setlocal spell!<cr>

" Shortcuts using <leader>
noremap <leader>sn ]s
noremap <leader>sp [s
noremap <leader>sa zg
noremap <leader>s? z=


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remove the Windows ^M - when the encodings gets messed up
noremap <Leader>m mmHmt:%s/<C-V><cr>//ge<cr>'tzt'm

" Quickly open a buffer for scripbble
noremap <leader>q :e ~/buffer<cr>

" Toggle paste mode on and off
noremap <leader>pp :setlocal paste!<cr>

" creates title banner
nnoremap <leader>title 63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`oi<space>
vnoremap <leader>title ydd63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`opi<bs>

function! ReplaceTextUntil(char)
	let l:line = getline('.')
	let l:y = line('.')
	let l:x = col('.')
	let l:index = stridx(l:line, a:char, l:x)
	let l:portion = strpart(l:line, l:x, l:index - l:x)
	let l:bar = substitute(l:line, l:portion, "", "")
	call setline(l:y, l:bar)
	call cursor(l:y, l:x + 1)
	call feedkeys('i')
endfunc
nnoremap w' :call ReplaceTextUntil("'")<cr>
nnoremap w" :call ReplaceTextUntil('"')<cr>
nnoremap w; :call ReplaceTextUntil(';')<cr>
nnoremap w. :call ReplaceTextUntil('.')<cr>
nnoremap w> :call ReplaceTextUntil('<')<cr>
nnoremap w) :call ReplaceTextUntil(')')<cr>

" copy current line
function! PasteLineBelow(mode)
	let l:y = line('.')
	let l:x = col('.')
	if a:mode ==? 'i'
		execute "normal! yyp"
		call cursor(l:y+1, l:x+1)
		call feedkeys(a:mode)
	elseif a:mode ==? 'n'
		execute "normal! yyp"
		call cursor(l:y+1, l:x)
	else
		let [ l:line_start, l:column_start, l:line_end, l:column_end ] = GetVisualSelectionLine()
		let l:lines = VisualSelect()
		if( l:line_end == l:line_start)
			let l:line = getline('.')
			let l:size = (l:column_end - l:column_start) + 1
			let l:portion = strpart(l:line, l:column_start - 1, l:size)
			let l:bar = substitute(l:line, l:portion, l:portion . l:portion, "")
			call setline(l:line_start, l:bar)
			call cursor(l:line_end, l:column_end + 1)
			execute "normal! " . (l:size) . "v"
			"call cursor(l:line_end, l:column_end + (l:size * 2) + 1)
			"echom "l:column_start: " . l:column_start
			"echom "l:column_end: " . l:column_end
			"echom "l:line_start: " . l:line_start
			"echom "l:line_end: " . l:line_end
			"echom "l:portion: " . l:portion
			"echom "l:size: " . l:size
			"echom "l:bar: " . l:bar
		else
			"echom l:lines
			let l:size = len(split(l:lines, "\n"))
			call append(l:line_end, split(l:lines, "\n"))
			call cursor(l:line_end+(l:size), l:x)
		endif
	endif
endfunc
inoremap <C-d> <esc>:call PasteLineBelow('i')<cr>
nnoremap <C-d> <esc>:call PasteLineBelow('n')<cr>
vnoremap <C-d> <esc>:call PasteLineBelow('v')<cr>
inoremap <C-d> <esc>:call PasteLineBelow('i')<cr>
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
function! CmdLine(str)
	exe "menu Foo.Bar :" . a:str
	emenu Foo.Bar
	unmenu Foo
endfunction

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


" Returns true if paste mode is enabled
function! HasPaste()
	if &paste
		return 'PASTE MODE  '
	en
	return ''
endfunction

" Don't close window, when deleting a buffer
command! Bclose call <SID>BufcloseCloseIt()
function! <SID>BufcloseCloseIt()
	let l:currentBufNum = bufnr("%")
	let l:alternateBufNum = bufnr("#")

	if buflisted(l:alternateBufNum)
		buffer #
	else
		bnext
	endif

	if bufnr("%") == l:currentBufNum
		new
	endif

	if buflisted(l:currentBufNum)
		execute("bdelete! ".l:currentBufNum)
	endif
endfunction

"  Raza's custom commands
set showmode              " always show what mode we're currently editing in
set nowrap                " don't wrap lines
set shiftround            " use multiple of shiftwidth when indenting with '<' and '>'
set copyindent            " copy the previous indentation on autoindenting
set number                " always show line numbers
set autowrite             " Save on buffer switch
set clipboard=unnamedplus " register to global clipboard
set notimeout
set mouse=a
set splitright
set pastetoggle=<F3>

" Move current line or visual block up/down
nnoremap <C-S-Up> :m -2<CR>
nnoremap <C-S-Down> :m +1<CR>
inoremap <C-S-Up> :m -2<CR>
inoremap <C-S-Down> :m +1<CR>
"vnoremap <C-S-Up> :m '<-2<CR>gv=gv
"vnoremap <C-S-Down> :m '>+1<CR>gv=gv
vmap <C-S-Up>    <Plug>SchleppUp
vmap <C-S-Down>  <Plug>SchleppDown
"vmap <C-left>  <Plug>SchleppLeft
"vmap <C-right> <Plug>SchleppRight

nnoremap <leader>- :new<cr>
nnoremap <leader><bar> :vnew<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Airline Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline_theme = 'material'
let g:airline_powerline_fonts = 1
" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1
" Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Yggdroot/indentLine
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:indentLine_color_term = 239
let g:indentLine_char = '┊'

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
"--ALE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:ale_lint_on_insert_leave = 0
let g:ale_fixers = {
			\   '*': ['remove_trailing_lines', 'trim_whitespace'],
			\   'javascript': ['prettier'],
			\   'javascript.jsx': ['prettier'],
			\   'typescript': ['prettier'],
			\   'typescript.tsx': ['prettier'],
			\   'python': ['yapf'],
			\   'json': ['prettier'],
			\   'html': ['prettier'],
			\   'css': ['prettier', 'stylelint'],
			\   'scss': ['prettier', 'stylelint'],
			\}
let g:ale_linters = {
			\   'javascript': ['eslint'],
			\   'javascript.jsx': ['eslint'],
			\   'typescript': ['eslint'],
			\   'typescript.tsx': ['eslint'],
			\   'python': ['flake8'],
			\   'json': ['jsonlint'],
			\   'html': ['htmlhint'],
			\   'css': ['stylelint'],
			\   'scss': ['stylelint'],
			\}
let g:ale_fix_on_save = 1
let g:ale_echo_msg_error_str = 'E'
let g:ale_echo_msg_warning_str = 'W'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
let g:ale_open_list = 1
let g:ale_list_window_size = 5

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"--Nerdcommenter Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" _ is /
nnoremap <C-_> :call NERDComment(0,"toggle")<CR>
vnoremap <C-_> :call NERDComment(0,"toggle")<CR>

