" ~/.config/nvim/config/31-keymap-ide.vim — the VSCode/IntelliJ keymap layer.
"
" Full reference: docs/VIM_KEYMAP.md in the dotfiles repo.
"
" TERMINAL ENCODING
" A legacy terminal cannot encode Ctrl+Shift+<letter>, Ctrl+/, or Alt+Enter: it
" collapses them onto the plain Ctrl form or drops the modifier. Vim's
" 'keyprotocol' fixes that where the terminal supports it — kitty's own protocol,
" or xterm's modifyOtherKeys.
"
" Vim's default 'keyprotocol' already covers kitty/foot/ghostty/wezterm/xterm and
" config/kitty/kitty.conf sets `term xterm-kitty`, so native kitty needs nothing
" here. Inside tmux &term is tmux-256color, which matches no default entry, so it
" is added below; tmux.conf enables the matching `extended-keys on`.
"
" Every binding that needs the protocol also has a <leader> fallback, so ssh
" sessions and Windows Terminal lose no functionality. The Ctrl+Shift+* forms are
" safe to define unconditionally: Vim stores <C-S-F> as a distinct key from
" <C-F>, so on a legacy terminal they simply never fire rather than shadowing the
" plain Ctrl mapping.
" NOTHING TO DO HERE — and that is the single nicest thing about this port.
" Neovim has no 'keyprotocol' option because it negotiates the kitty keyboard
" protocol automatically wherever the terminal advertises it. The Vim config
" needs an explicit tmux*:mok2 entry plus a matching `extended-keys on` in
" tmux.conf; here Ctrl+/, Alt+Enter and Ctrl+Shift+<letter> simply arrive.

"===========================================================================
" Navigation and search
"===========================================================================
" Go to file            Ctrl+P / Ctrl+Shift+N   (reclaims F)
nnoremap <silent> <C-p>   :ProjectFiles<CR>
nnoremap <silent> <C-S-n> :ProjectFiles<CR>
nnoremap <silent> <leader>p :ProjectFiles<CR>

" Find in path          Ctrl+Shift+F            (reclaims S)
nnoremap <C-S-f>   :Find<space>
nnoremap <leader>/ :Find<space>

" Recent files          Ctrl+E                  (reclaims H)
nnoremap <silent> <C-e>      :History<CR>
nnoremap <silent> <leader>e  :History<CR>

" Open buffers          Ctrl+Shift+E            (reclaims B)
nnoremap <silent> <C-S-e>   :Buffers<CR>

" Command palette       Ctrl+Shift+P
nnoremap <silent> <C-S-p>   :Commands<CR>
nnoremap <silent> <leader>: :Commands<CR>

" Marks and registers   (reclaim M and R)
nnoremap <silent> <leader>m :Marks<CR>
nnoremap <silent> <leader>" :Registers<CR>

" Find in file          Ctrl+F, then F3 / Shift+F3 to step
" Note: this takes Ctrl+F from page-forward, which remains on <PageDown>.
nnoremap <C-f> /
nnoremap <F3>   n
nnoremap <S-F3> N

" Go to line            Ctrl+G
nnoremap <C-g> :<C-u>

" Navigate BACK through the jumplist — <C-o> is Vim's "go to older position".
" Ctrl+Alt+Q is the primary key: keybindings.json binds it to navigateBack and
" explicitly unbinds ctrl+alt+left from it. The arrow is kept as an alias.
nnoremap <C-A-q>    <C-o>
nnoremap <C-A-Left> <C-o>

" Navigate FORWARD through the jumplist — <C-i> is "go to newer position".
" Note <C-i> and <Tab> are the same byte (0x09), so `:nmap <C-A-w>` reports the
" right-hand side as <Tab>; that is the same key, not a mis-mapping. This only
" works because <Tab> was reclaimed — the old config mapped it to %.
nnoremap <C-A-w>     <C-i>
nnoremap <C-A-Right> <C-i>

" Back to the last EDIT location (not just the last jump) — Vim's g; walks the
" changelist. IntelliJ spells this Ctrl+Shift+Backspace.
nnoremap <C-S-BS> g;

" Historical note: the old .vimrc tried to bind exactly these two keys, but had
" the operands reversed —
"     map <Esc> <C-A-q> | map <C-A-q> <C-O>
" which bound <Esc> itself rather than <C-A-q>. That is what made Esc reindent
" the whole buffer and then hang on an ambiguous mapping prefix.

"===========================================================================
" Code intelligence
"===========================================================================
" Code intelligence now lives in Lua: lua/plugins/lsp.lua (servers, diagnostics,
" document highlight), after/plugin/lsp-keymaps.lua (gd/gy/gi/gr/K) and
" after/plugin/lsp-ide-keymaps.lua (the IDE chords that used to be here).
"
" They moved out of this file because every one of them was bound to a
" <Plug>(coc-*) target that no longer exists, and because the native API is
" Lua-only — there is no vimscript spelling of vim.lsp.buf.code_action().

"===========================================================================
" Editing
"===========================================================================
" Comment line / selection     Ctrl+/
" DIVERGES from the Vim config. There, Vim 9.2's bundled `comment` package
" supplies <Plug>(comment-toggle-line) and Ctrl+/ is mapped onto it.
"
" Neovim has commenting built in since 0.10, but exposes it ONLY as the default
" gc/gcc mappings — there is no <Plug> target. Carrying the Vim lines across
" produced a mapping that existed and did nothing: :nmap reported the <Plug>
" right-hand side quite happily, and pressing Ctrl+/ left the line untouched.
" So these map onto gcc/gc directly, and must stay recursive (nmap/xmap, not
" nnoremap/xnoremap) because gcc and gc are themselves mappings.
nmap <C-_> gcc
nmap <C-/> gcc
xmap <C-_> gc
xmap <C-/> gc

" Duplicate line / selection   Ctrl+D
nnoremap <silent> <C-d> :call DuplicateLine('n')<CR>
inoremap <silent> <C-d> <Esc>:call DuplicateLine('i')<CR>
xnoremap <silent> <C-d> :<C-u>call DuplicateLine('v')<CR>

" Delete line                  Ctrl+Y
nnoremap <silent> <C-y> :call DeleteLine('n')<CR>
inoremap <silent> <C-y> <Esc>:call DeleteLine('i')<CR>
xnoremap <silent> <C-y> :<C-u>call DeleteLine('v')<CR>

" Select all                   Ctrl+A
" switch.vim already took <C-a> from Vim's increment; increment moves to g<C-a>.
nnoremap <C-a> ggVG
" Vim's increment/decrement, displaced by Select All and by switch.vim's <C-x>.
nnoremap g<C-a> <C-a>
xnoremap g<C-a> <C-a>
nnoremap g<C-x> <C-x>
xnoremap g<C-x> <C-x>

" Save                         Ctrl+S
" <C-o> rather than <Esc> in insert mode, so the cursor stays where it was and
" you stay in insert — the way every GUI editor behaves.
nnoremap <silent> <C-s> :<C-u>Update<CR>
inoremap <silent> <C-s> <C-o>:Update<CR>
xnoremap <silent> <C-s> <Esc>:Update<CR>gv

" Undo / redo                  Ctrl+Z / Ctrl+Shift+Z
" Requires config/kitty/linux.conf to stop intercepting ctrl+z with
" `signal_child SIGTSTP`; suspend moves to <leader>z.
nnoremap <C-z> u
inoremap <C-z> <C-o>u
nnoremap <C-S-z> <C-r>
inoremap <C-S-z> <C-o><C-r>
nnoremap <leader>z <C-z>

" Replace in file              Ctrl+Shift+H     (reclaims s)
" Ctrl+H is deliberately NOT used: it is the vim-tmux-navigator / kitty
" pass_keys.py left-pane key, wired through three layers outside Vim.
nnoremap <C-S-h>   :%s///g<LEFT><LEFT><LEFT>
nnoremap <leader>h :%s///g<LEFT><LEFT><LEFT>
xnoremap <C-S-h>   :s///g<LEFT><LEFT><LEFT>
xnoremap <leader>h :s///g<LEFT><LEFT><LEFT>

" Complete statement           Ctrl+Shift+L / Ctrl+Enter — append a semicolon
inoremap <C-S-l> <C-o>A;
inoremap <C-CR>  <C-o>A;

" Move line or block           Alt+Shift+Up/Down, Ctrl+Shift+Up/Down (vim-move)
" Mapped in after/plugin/editing.vim, once vim-move's <Plug> targets exist.

" Join lines                   Ctrl+Shift+J    (IntelliJ, exact match for J)
nnoremap <C-S-j> J
xnoremap <C-S-j> J

" Jump to matching bracket     Ctrl+Shift+M    (IntelliJ) — vim-matchup owns %
nmap <C-S-m> %

" Start a new line without splitting the current one, from anywhere on it.
"   Shift+Enter      below   (IntelliJ "start new line")
"   Ctrl+Alt+Enter   above   (IntelliJ "start new line before current")
nnoremap <S-CR>   o
inoremap <S-CR>   <C-o>o
nnoremap <C-A-CR> O
inoremap <C-A-CR> <C-o>O

" Block comment                Ctrl+Shift+/    (IntelliJ)
" Ctrl+/ toggles a line comment; this comments the selection as a block.
xmap <C-S-_> gc
xmap <C-S-/> gc

" Folding                      Ctrl+- / Ctrl+= / Ctrl+.  and the Shift variants
" 'foldmethod' is set in 20-options.vim; without it these would be no-ops.
nnoremap <C-->   zc
nnoremap <C-=>   zo
nnoremap <C-.>   za
nnoremap <C-S-->  zM
nnoremap <C-S-=>  zR

" Copy the current file's path Ctrl+Shift+C    (IntelliJ "copy path")
nnoremap <silent> <C-S-c> :let @+ = expand('%:p') <bar> echo 'Copied ' . expand('%:p')<CR>

" Delete word forward          Ctrl+Delete     (Ctrl+W already deletes back)
inoremap <C-Del> <C-o>dw

"===========================================================================
" Workbench
"===========================================================================
" Close buffer                 Ctrl+W    (window commands moved to <leader>w)
nnoremap <silent> <C-w> :call CloseBuffer()<CR>

" Toggle terminal              Ctrl+` , Alt+F12 (IntelliJ)
nnoremap <silent> <C-`> :botright terminal<CR>
tnoremap <silent> <C-`> <C-w>:quit<CR>
nnoremap <silent> <A-F12> :botright terminal<CR>
tnoremap <silent> <A-F12> <C-w>:quit<CR>

" File explorer                Ctrl+B and Alt+1
" Ctrl+B is the VSCode sidebar toggle; Alt+1 is IntelliJ's Project tool window,
" which is what the real VSCode keymap uses. Both hit snacks.explorer, which
" replaced NERDTree + nerdtree-git-plugin (git marks come built in).
nnoremap <silent> <C-b> :ExplorerToggle<CR>
nnoremap <silent> <A-1> :ExplorerToggle<CR>

" Cycle buffers                Ctrl+PageDown / Ctrl+PageUp (and Alt+ the same)
nnoremap <silent> <C-PageDown> :bnext<CR>
nnoremap <silent> <C-PageUp>   :bprevious<CR>
nnoremap <silent> <A-PageDown> :bnext<CR>
nnoremap <silent> <A-PageUp>   :bprevious<CR>

 " Undo tree                    <leader>u
" Moved off F5, which is now start/continue debugging — see
" after/plugin/dap-keymaps.lua. F5 = start debugging is close to universal and
" the debugger has no other free spelling here (IntelliJ's F7/F8/Shift+F8 are
" taken by spell-check and problem navigation).

" Paste in a terminal buffer
tnoremap <expr> <C-v> '<C-\><C-N>pi'

"===========================================================================
" <leader> + capital pickers
"===========================================================================
" The pre-rewrite bindings were the bare capitals F H B S T M R. Those are back
" to being Vim motions; the pickers keep the same letters behind <leader>, so
" the association survives without costing back-find, screen-top, WORD-back,
" substitute-line, till-backwards, screen-middle or Replace mode.
"
" Still additional to the chords: Ctrl+P, Ctrl+E, Ctrl+Shift+F and the
" lowercase fallbacks all continue to work.
nnoremap <silent> <leader>F :ProjectFiles<CR>
nnoremap <silent> <leader>H :History<CR>
nnoremap <silent> <leader>B :Buffers<CR>
nnoremap          <leader>S :Find<space>
nnoremap <silent> <leader>M :Marks<CR>
nnoremap <silent> <leader>R :Registers<CR>
nnoremap <silent> <leader>T :lua Snacks.picker.lsp_symbols()<CR>
