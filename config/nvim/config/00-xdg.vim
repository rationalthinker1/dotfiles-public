" ~/.config/nvim/config/00-xdg.vim — on-disk state.
"
" DIVERGES SHARPLY from the Vim version of this file, and must.
"
" Vim needed explicit XDG wiring because it defaults to ~/.viminfo and
" ~/.vim/. Neovim is already XDG-native: stdpath('state') gives
" ~/.local/state/nvim, and undo/swap/backup/shada all default underneath it.
" So the correct port is to delete almost all of it rather than translate it.
"
" More than a tidiness point. The Vim file ends with
"     set viminfo+=n$XDG_DATA_HOME/vim/viminfo
" and carrying that across pointed Neovim's ShaDa file at Vim's viminfo. The two
" are different formats, so nvim failed to parse it —
"     E576: Failed to parse ShaDa file: extra bytes in msgpack string
" — then refused to write, leaving viminfo.tmp.b behind. Sharing state between
" the two editors is not merely unnecessary, it corrupts.
"
" Everything below is therefore only what Neovim does NOT already do.

" netrw's history file. Neovim still defaults this to ~/.local/share/nvim, but
" naming it keeps the two editors' netrw histories apart.
let g:netrw_home = stdpath('state')

" Persistent undo. Neovim sets 'undodir' to stdpath('state').'/undo' already;
" 'undofile' itself is off by default, so this is the one line that matters.
set undofile
set undolevels=1000
set undoreload=10000

" Backups: same policy as the Vim config (keep them, skip the transient copy),
" but 'backupdir' is left at Neovim's default.
set backup
set nowritebackup
set noswapfile

" Neovim creates its own state directories on demand, so the mkdir loop the Vim
" version needs is not required here.

" Neovim probes for perl/ruby/node remote-plugin hosts at startup and warns in
" :checkhealth when they are missing. Nothing in this config uses them: mason
" and the language servers are separate processes, not remote-plugin hosts —
" so they are turned off: quieter health output, one less probe each on start.
" The python3 provider is deliberately left enabled: vim-visual-multi has a
" has('python3') fast path, and install.sh already provisions pynvim.
let g:loaded_perl_provider = 0
let g:loaded_ruby_provider = 0
let g:loaded_node_provider = 0
