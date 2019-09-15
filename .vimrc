"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Vim-Plug Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Automatically install vim-plug and run PlugInstall if vim-plug not found
if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
				\ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'vim-scripts/httplog'
Plug 'vim-scripts/apachelogs.vim'
Plug 'vim-scripts/apachestyle'
Plug 'stanangeloff/php.vim'
Plug 'shawncplus/phpcomplete.vim'
Plug 'scrooloose/nerdtree'
Plug 'noahfrederick/vim-laravel'
Plug 'jwalton512/vim-blade'
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'Yggdroot/indentLine'
Plug 'junegunn/fzf.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Plug 'terryma/vim-multiple-cursors'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'quramy/tsuquyomi'
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'
Plug 'pangloss/vim-javascript'
Plug 'airblade/vim-gitgutter'
Plug 'scrooloose/nerdcommenter'
Plug 'junegunn/vim-easy-align'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'tpope/vim-eunuch'
Plug 'hzchirs/vim-material'
Plug 'daylerees/colour-schemes', { 'rtp': 'vim/' }
Plug 'ekalinin/Dockerfile.vim'
Plug 'stephpy/vim-yaml'
Plug 'luochen1990/rainbow'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'tmux-plugins/vim-tmux'
Plug 'sheerun/vim-polyglot'
Plug 'mileszs/ack.vim'
"Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'evturn/cosmic-barf'
Plug 'dense-analysis/ale'
Plug 'bronson/vim-trailing-whitespace'
Plug 'chr4/nginx.vim'
Plug 'phpactor/phpactor' ,  {'do': 'composer install', 'for': 'php'}
Plug 'tpope/vim-surround'
Plug 'thinca/vim-visualstar'

" Deplete wo
Plug 'roxma/nvim-yarp' | Plug 'roxma/vim-hug-neovim-rpc' | Plug 'Shougo/deoplete.nvim'
Plug 'tbodt/deoplete-tabnine', { 'do': './install.sh' }
Plug 'kristijanhusak/deoplete-phpactor'
Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
Plug 'deoplete-plugins/deoplete-zsh'
Plug 'shougo/neco-vim'
Plug 'shougo/neco-syntax'
call plug#end()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Nerdcommenter Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
nnoremap <C-_> :call NERDComment(0,"toggle")<CR>
vnoremap <C-_> :call NERDComment(0,"toggle")<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Deoplete Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:deoplete#enable_at_startup = 1


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=700

" Enable filetype plugins
filetype plugin on
filetype indent on

" Set to auto read when a file is changed from the outside
set autoread

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ","
let g:mapleader = ","

" Fast saving
nnoremap <leader>w :w!<cr>

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

" load fzf for vim
set rtp+=~/.fzf
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>VIM user interface
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

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Buffer Settings
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

" Setup undo history persistent
set undofile                " Save undos after file closes
set undodir=$HOME/.vim/undo " where to save undo histories
set undolevels=1000         " How many undos
set undoreload=10000        " number of lines to save for undo


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable syntax highlighting
syntax enable
set background=dark
set termguicolors
set termencoding=utf-8
set guifont=Ubuntu\ Mono\ derivative\ Powerline:10
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
" =>Files, backups and undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn backup off, since most stuff is in SVN, git et.c anyway...
set nobackup
set nowb
set noswapfile


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Text, tab and indent related
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
" =>Visual mode related
""""""""""""""""""""""""""""""
" Visual mode pressing * or # searches for the current selection
vnoremap <silent> * :call VisualSelection('f')<CR>
vnoremap <silent> # :call VisualSelection('b')<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Treat long lines as break lines (useful when moving around in them)
nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

" Map <Space> to / (search) and Ctrl-<Space> to ? (backwards search)
nnoremap <space> /
nnoremap <c-space> ?

" Disable highlight when <leader><cr> is pressed
noremap <silent> <leader><cr> :noh<cr>

" Smart way to move between windows
nnoremap <A-Right> <C-W>l
nnoremap <A-Left> <C-W>h
nnoremap <A-Up> <C-W>j
nnoremap <A-Down> <C-W>k

inoremap <A-Right> <C-W>l
inoremap <A-Left> <C-W>h
inoremap <A-Up> <C-W>j
inoremap <A-Down> <C-W>k

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
	autocmd BufWritePost .vimrc :echom "Reloading .vimrc"
	autocmd BufWritePost .vimrc :sleep 500m
	autocmd BufWritePost .vimrc :source $MYVIMRC
	autocmd BufReadPost  .vimrc :call SavePositionOfTextOnRegister('^call plug#end()')
	autocmd BufWritePost .vimrc :call AutoPlaceMarkBasedOnText('^call plug#end()', "'p")
augroup END

" Close all the buffers
noremap <leader>ba :1,1000 bd!<cr>

" Useful mappings for managing tabs
noremap <leader>tn :tabnew<cr>
noremap <leader>to :tabonly<cr>
noremap <leader>tc :tabclose<cr>
noremap <leader>tm :tabmove

nnoremap <S-2> :tabn<CR>
nnoremap <S-4> :tabp<CR>
nnoremap <S-3> :tabnew<CR>

"function! Reindent_File()
"execute "normal! gg=G"
"endfunction

"nnoremap [^L :call Reindent_File()<cr>
"nnoremap ^[^L :call Reindent_File()<cr>

" change current file to working directory
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
noremap <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
noremap <leader>cd :cd %:p:h<cr>:pwd<cr>

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

" NOT WORKING. jumping list aliases
nnoremap <C-A-q> <C-o>
nnoremap <C-A-e> <C-i>

""""""""""""""""""""""""""""""
" =>Status line
""""""""""""""""""""""""""""""
" Always show the status line
set laststatus=2

" Format the status line
set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remap VIM 0 to first non-blank character
nnoremap 0 ^



" Delete trailing white space on save, useful for Python and CoffeeScript ;)
func! DeleteTrailingWS()
	exe "normal mz"
	%s/\s\+$//ge
	exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>vimgrep searching and cope displaying
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
"
noremap <leader>cc :botright cope<cr>
noremap <leader>co ggVGy:tabnew<cr>:set syntax=qf<cr>pgg
noremap <leader>n :cn<cr>
noremap <leader>p :cp<cr>

" when searching, you can use Perl's regex rather than using vim's own regex system
nnoremap / /\v
vnoremap / /\v


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pressing ,ss will toggle and untoggle spell checking
noremap <leader>ss :setlocal spell!<cr>

" Shortcuts using <leader>
noremap <leader>sn ]s
noremap <leader>sp [s
noremap <leader>sa zg
noremap <leader>s? z=


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remove the Windows ^M - when the encodings gets messed up
noremap <Leader>m mmHmt:%s/<C-V><cr>//ge<cr>'tzt'm

" Quickly open a buffer for scripbble
noremap <leader>q :e ~/buffer<cr>

" Toggle paste mode on and off
noremap <leader>pp :setlocal paste!<cr>

" creates title banner
nnoremap <leader>title 63i"<esc><esc>o" =><space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`oi<space>
vnoremap <leader>title ydd63i"<esc><esc>o" =><space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`opi<bs>

" copy current line
function! PasteLineBelow(mode)
	let l:y = line('.')
	let l:x = col('.')
	execute "normal! yyp"
	if a:mode == 'i'
		cal cursor(l:y+1, l:x+1)
		call feedkeys(a:mode)
	else
		cal cursor(l:y+1, l:x)
	endif
endfunc
inoremap <C-d> <esc>:call PasteLineBelow('i')<cr>
nnoremap <C-d> <esc>:call PasteLineBelow('n')<cr>

" delete current line
function! DeleteCurrentLine(mode)
	let l:y = line('.')
	let l:x = col('.')
	execute "normal! dd"
	if a:mode == 'i'
		cal cursor(l:y, l:x+1)
		call feedkeys(a:mode)
	else
		cal cursor(l:y, l:x)
	endif
endfunc
inoremap <C-y> <esc>:call DeleteCurrentLine('i')<cr>
nnoremap <C-y> <esc>:call DeleteCurrentLine('n')<cr>

" clears content from the cursor to the end while in insert mode
inoremap <C-c> <esc>lc$

" runs macro based on selected lines
function! ExecuteMacroOverVisualRange()
	echo "@".getcmdline()
	execute ":'<,'>normal @".nr2char(getchar())
endfunction
xnoremap @ :<C-u>call ExecuteMacroOverVisualRange()<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Helper functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! CmdLine(str)
	exe "menu Foo.Bar :" . a:str
	emenu Foo.Bar
	unmenu Foo
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
vnoremap <C-S-Up> :m '<-2<CR>gv=gv
vnoremap <C-S-Down> :m '>+1<CR>gv=gv


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Theme
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax enable
"set background=dark
"let g:airline_theme='material'
"colorscheme vim-material
colorscheme gloom-contrast
let g:material_style='palenight'

"colorscheme cosmic-barf
"let g:colors_name = 'cosmic-barf'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Airline Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline_theme = 'deus'
let g:UltiSnipsExpandTrigger="<C-Tab>"
let g:airline_powerline_fonts = 1
" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1
" Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>vim-multiple-cursors Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:multi_cursor_use_default_mapping = 0
let g:multi_cursor_start_word_key      = '<A-j>'
let g:multi_cursor_select_all_word_key = '<S-A-j>'
let g:multi_cursor_start_key           = 'g<A-j>'
let g:multi_cursor_select_all_key      = 'g<S-A-j>'
let g:multi_cursor_next_key            = '<A-j>'
let g:multi_cursor_prev_key            = '<C-p>'
let g:multi_cursor_skip_key            = '<C-x>'
let g:multi_cursor_quit_key            = '<Esc>'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>CtrlP Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Setup some default ignores
let g:ctrlp_custom_ignore = {
			\ 'dir':  '\v[\/](\.(git|hg|svn)|\_site)$',
			\ 'file': '\v\.(exe|so|dll|class|png|jpg|jpeg)$',
			\}

" Use the nearest .git directory as the cwd
" This makes a lot of sense if you are working on a project that is in version
" control. It also supports works with .svn, .hg, .bzr.
let g:ctrlp_working_path_mode = 'r'

let g:ctrlp_by_filename  = 0 " ctrlp - don't search by filename by default (use full path instead)
let g:ctrlp_show_hidden  = 1 " ctrlp - search for hidden files
let g:ctrlp_regexp       = 1 " ctrlp - use regexp matching
let g:ctrlp_root_markers = ['package.json', '.git']

" Use a leader instead of the actual named binding
nnoremap <leader>p :CtrlP<cr>

" Easy bindings for its various modes
nnoremap <leader>bb :CtrlPBuffer<cr>
nnoremap <leader>bm :CtrlPMixed<cr>
nnoremap <leader>bs :CtrlPMRU<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>NERDTree Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"noremap <C-n> :NERDTreeToggle<CR>
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
nnoremap <silent> <expr> <C-b> g:NERDTree.IsOpen() ? "\:NERDTreeClose<CR>" : bufexists(expand('%')) ? "\:NERDTreeFind<CR>" : "\:NERDTree<CR>"
let NERDTreeShowHidden = 1
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


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Yggdroot/indentLine
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:indentLine_color_term = 239
let g:indentLine_char = '┊'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>Rainbow Parentheses
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:rainbow_active = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>EasyAlign Configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
