" ~/.config/nvim/config/20-options.vim — every 'set' in one place, assigned once.
"
" The old .vimrc set several of these twice with different values (scrolloff was
" 999 then 7, gdefault/lazyredraw/encoding/background all appeared twice). Each
" option now has exactly one authoritative line.

"--- Encoding and file formats ---------------------------------------------
" 'encoding' is utf-8 in Neovim and cannot be changed; 'termencoding' was
" removed outright (setting it raises E519). Both are simply gone here.
" Line-ending detection, tried in order. 'unix' first so a file with mixed
" endings is treated as LF rather than being flagged [dos] and rewritten.
set fileformats=unix,dos,mac

"--- Files, buffers, state -------------------------------------------------
set hidden                  " allow switching away from a modified buffer
set autoread                " reload files changed outside vim
set autowrite               " write on buffer switch
set history=700             " remembered ":" commands and search patterns
" Where :sbuffer, :cc and friends open a buffer: reuse a window that already
" shows it, otherwise make a vertical split rather than hijacking the current one.
set switchbuf=useopen,vsplit

" undofile/backup/swap are set in 00-xdg.vim, against Neovim's own state dirs.

"--- Search ----------------------------------------------------------------
set ignorecase              " case-insensitive matching by default …
set smartcase               " … unless the pattern contains an uppercase letter
set hlsearch                " highlight every match of the last search
set incsearch               " since Vim 8.0 this highlights *all* matches while
                            " typing, which is what incsearch.vim used to add
set magic                   " regex metacharacters work unescaped (Vim's default,
                            " stated explicitly because :s patterns here assume it)
set gdefault                " :s substitutes all matches on a line without /g
" Live preview of :s as you type it, in a split showing every affected line.
" This is what markonm/traces.vim provided on the Vim side; Neovim has had it
" built in since 0.1, so the plugin was pure duplication here.
set inccommand=split

"--- Editing ---------------------------------------------------------------
set backspace=indent,eol,start  " backspace over autoindent, line breaks and the
                            " insert start point — not the default in plain Vim
set whichwrap+=<,>,[,]      " let arrow keys wrap across lines
set virtualedit+=onemore    " $ can sit after the last character
set selection=exclusive     " so v$ does not swallow the newline
set nojoinspaces            " J inserts one space, not two
set nrformats-=octal        " 007 increments to 008, not 010

"--- Indentation -----------------------------------------------------------
" Tabs by default; vim-sleuth overrides per project from surrounding files.
set autoindent              " carry the current line's indent to the next
set noexpandtab             " insert real tabs, not spaces
set smarttab                " <Tab> at line start inserts one 'shiftwidth'
set shiftround              " round < and > to a multiple of shiftwidth
set copyindent              " reuse the existing indent's exact whitespace mix
set softtabstop=4           " how far <Tab>/<BS> move when editing
set shiftwidth=4            " width of one < or > indent step
set tabstop=4               " display width of a literal tab

"--- Display ---------------------------------------------------------------
set termguicolors           " 24-bit colour; required by the cyberpunk scheme
set number                  " absolute line numbers
set cursorline              " highlight the line the cursor is on
set ruler                   " line/column position in the bottom right
set showcmd                 " show partially typed commands
set noshowmode              " lightline already renders the mode
set laststatus=2            " lightline requires this; the default (1) hides it
                            " entirely when only one window is open
set showtabline=2           " lightline-bufferline owns the tabline
set cmdheight=1             " one line for the command area
set display=truncate        " mark a truncated last line with @@@ instead of hiding it
set scrolloff=7             " keep 7 lines of context above/below the cursor
set nowrap                  " long lines run off screen rather than wrapping
set linebreak               " when wrap is toggled on, break at word boundaries
set textwidth=0             " never hard-wrap while typing
set showmatch               " briefly jump to the matching bracket when one is typed
set matchtime=5             " …for half a second (tenths)
set lazyredraw              " do not redraw mid-macro
" ('ttyfast' was here and has been removed: Vim 8+ always assumes a fast
" terminal, so the option is a no-op. Do not re-add it.)

" Indent guides and invisible characters, replacing the indentLine plugin — which
" drove them through 'conceallevel' and so hid quotes in JSON and markdown.
"
" Each item below:
"   tab:▏␣             a tab renders as a thin bar plus filler — the indent guide
"                      for this config's default noexpandtab
"   leadmultispace:▏␣␣␣  same guide for space-indented files; the 4-character unit
"                      repeats every 4 columns to match 'shiftwidth'
"   trail:·            trailing whitespace (vim-better-whitespace also flags it)
"   nbsp:␣             non-breaking space, otherwise invisible and a real bug source
"   extends:›          the line continues past the right edge ('nowrap')
"   precedes:‹         the line continues past the left edge when scrolled
set list                    " render the characters configured below
set listchars=tab:▏\ ,leadmultispace:▏\ \ \ ,trail:·,nbsp:␣,extends:›,precedes:‹

"--- Folding ---------------------------------------------------------------
" Enabled so the IntelliJ fold keys in 31-keymap-ide.vim (Ctrl+-, Ctrl+=,
" Ctrl+., and the Shift variants) have something to act on; with the default
" foldmethod=manual there are no folds and every one of them is a no-op.
set foldmethod=indent       " structural enough for most code, and free
set foldlevelstart=99       " but open everything when a file loads
set foldnestmax=10          " stop generating folds past 10 levels deep

"--- Completion and messages -----------------------------------------------
set wildmenu                " show a menu of matches when completing on ":"
set wildmode=longest:full,full  " first <Tab> completes the longest common prefix
                            " and opens the menu; the next cycles through it
" Never offer these to :e / :find. (snacks.picker does NOT read 'wildignore' —
" it filters through ripgrep/fd and respects .gitignore instead, configured in
" lua/plugins/picker.lua.)
set wildignore=*.o,*~,*.pyc,*.so,*.class,*.swp,*.zip,*.pdf  " compiled and binary artefacts
set wildignore+=*/tmp/*,*/target/*,*/build/*,*/dist/*       " build output trees
set wildignore+=*/node_modules/*,*/vendor/*,*/bower_components/*  " vendored dependencies

set shortmess+=c            " no "match 1 of 2" noise during completion
set signcolumn=yes          " always reserve the gutter so diagnostics do not shift text
set updatetime=300          " drives LSP document-highlight on CursorHold
                            " (lua/plugins/lsp.lua); the 4000ms default feels broken

"--- Timeouts --------------------------------------------------------------
" The old config set 'notimeout', which combined with mapped <Esc> prefixes meant
" Vim waited forever after Esc. Mappings time out; terminal key sequences get a
" short window, long enough for Alt-chords that arrive as ESC+key.
set timeout                 " time out on an incomplete mapping …
set timeoutlen=500          " … after half a second
set ttimeout                " time out on an incomplete terminal key code …
set ttimeoutlen=25          " … quickly, but not so fast that ESC+key Alt-chords
                            " over ssh get split into two separate keys

"--- Windows and mouse -----------------------------------------------------
set splitright              " :vsplit puts the new window on the right
set splitbelow              " :split puts the new window below
set mouse=a                 " mouse in all modes (select, resize splits, scroll)
set mousemodel=popup        " right-click opens a context menu rather than
                            " extending the visual selection

"--- Bells -----------------------------------------------------------------
" Belt and braces: 'belloff=all' covers modern Vim, the other three silence the
" paths that predate it.
set noerrorbells            " no beep on an error
set novisualbell            " no screen flash either …
set belloff=all             " … for any event at all
" ('t_vb' does not exist in Neovim; 'belloff=all' above covers it.)

"--- Subprocesses ----------------------------------------------------------
" Vim defaults 'shell' to $SHELL, which here is zsh, and the old config pinned it
" to /bin/zsh explicitly with the comment "Set zsh aliases" — which it does not
" do: a non-interactive shell loads no aliases. All it bought was zsh's startup
" cost on every system() call. Measured on this machine: 14.6ms for zsh against
" 1.5ms for sh, paid by fzf, fugitive, coc, and — because clipboard=unnamedplus
" routes through the provider in 01-clipboard.vim — every single yank.
set shell=/bin/sh

"--- Diff ------------------------------------------------------------------
set diffopt+=algorithm:patience  " far better hunks than the default Myers when
                            " code has been moved or reordered

" 'clipboard' is set in 01-clipboard.vim, next to the note on how Neovim finds
" a clipboard tool without the provider the Vim config has to register.

" The Vim config clears 't_ut' here to stop background-colour tearing in kitty.
" Neovim has no t_* options at all, and drives the terminal through its own
" TUI layer which does not emit the offending background-erase sequence — so
" there is nothing to clear and no tearing to fix.
