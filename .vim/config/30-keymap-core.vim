" ~/.vim/config/30-keymap-core.vim — Vim-native keys and the helpers behind them.
"
" WHAT LIVES WHERE
"
" The split against 31-keymap-ide.vim is by *kind*, not by spirit — several
" IDE-style keys are in this file, deliberately. The rule:
"
"   31-keymap-ide.vim   the IDE chords themselves. Ctrl+S, Ctrl+D, Alt+Enter,
"                       Ctrl+Shift+F and friends, each with its <leader> fallback.
"                       A flat, readable list of bindings, no logic.
"
"   this file           three kinds of thing:
"
"     1. Vim-native keys — j/k by screen line, $ to g$, d/c to the black hole,
"        < and > keeping the selection.
"
"     2. The IMPLEMENTATIONS the IDE layer maps onto. :Update backs Ctrl+S,
"        CloseBuffer() backs Ctrl+W, DuplicateLine()/DeleteLine() back
"        Ctrl+D/Ctrl+Y. They live here so 31 stays a list of bindings rather
"        than a mix of bindings and forty lines of buffer-juggling.
"
"     3. IDE-style keys that are NOT chords, and so would read oddly in a file
"        of chords — Shift+arrow selection (lines 63-81), <Del> to the black
"        hole, Ctrl+Up/Down fast scroll, and <leader>w, which exists only
"        because the IDE layer took Ctrl+W.
"
" So: changing which key does something -> 31. Changing what it does -> here.
"
" RECLAIMED — these were mapped and are now back to their built-in behaviour:
"   y   was `viwy<Esc>`, which stopped y being an operator: yy, y$, yap, yi( all
"       broke. Word-yank now lives on <leader>y.
"   x   was `viwc`. Back to delete-character.
"   s   was `:%s///g`. That moved to Ctrl+H / <leader>h.
"   1 2 were `^` and `$`, so every count starting with 1 or 2 (2dd, 12j, 10gg)
"       was swallowed.
"   p P were a reindent-on-paste pair that pasted in the wrong direction. Vim's
"       own ]p / ]P already paste with the surrounding indent.
"   <Tab>   was `%`; <Tab> is <C-i>, so jumplist-forward was dead. vim-matchup
"           owns % already.
"   <Esc>   was mapped three times (see 31-keymap-ide.vim for the replacement).
"   w       was a prefix for w'/w"/w;/w. — which made the plain w motion wait on
"           a timeout. Those did the same job as Vim's native ct' ct" ct; ct.
"   F H B T M S R  were grabbed by fzf; see 31-keymap-ide.vim for their new homes.
"   <C-Space> in insert was <Esc>, which killed coc's trigger-completion.
"   <C-x>     in insert was a word-change, which killed all of ins-completion
"             (<C-x><C-o>, <C-x><C-f>, …).

"--- Typo-tolerant command line --------------------------------------------
" Holding Shift a beat too long after ':' turns :w into :W and Vim answers
" "E492: Not an editor command". These map the shouted forms back to the real
" ones. cnoreabbrev (not cabbrev) so the expansion is never re-expanded, and the
" abbreviation fires on the next non-keyword character — so :W<CR> and :W foo
" both work.
" CAUTION: :abbreviate takes the rest of the line as the expansion, exactly like
" :map. A trailing " comment becomes part of what gets typed — `cnoreabbrev W w
" " write` expands :W to `:w      " write`, which writes to a file named
" `" write`. Comments go above these lines, never beside them. ('set' is the
" exception and does accept trailing comments — hence their use in 20-options.vim.)
"
" Forced variants — write a readonly file, or quit discarding changes:
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qall! qall!
" Write then quit; write every modified buffer:
cnoreabbrev Wq wq
cnoreabbrev Wa wa
" Shift tends to stick across both keys rather than just the first, so the
" half-shouted spellings are accepted in either order:
cnoreabbrev wQ wq
cnoreabbrev WQ wq
" The plain forms: write, quit this window, quit every window.
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qall qall

"--- Motion ----------------------------------------------------------------
" Move by screen line unless a count was given, so 5j still jumps 5 real lines.
nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

" $ to the last character rather than past it.
noremap $ g$

" Fast vertical movement — five lines a press, for scanning without leaving the
" home position. Deliberately a plain count, not a scroll: the cursor moves and
" the view follows via 'scrolloff', so the jumplist and marks behave normally.
"
" These are the reason g:VM_default_mappings is 0 in 05-plugin-vars.vim.
" vim-visual-multi claims Ctrl+Up/Ctrl+Down for add-cursor-above/below, and
" being a plugin it loads after this file — so without that variable it silently
" won these two keys back. Multi-cursor add-above/below is on Ctrl+Alt+Up/Down.
nnoremap <C-Up> 5k
nnoremap <C-Down> 5j

"--- Deleting without clobbering the clipboard -----------------------------
" Deliberate: with clipboard=unnamedplus, an unqualified d/c would overwrite the
" system clipboard on every edit. Use x to cut, or "add for an explicit register.
nnoremap d "_d
xnoremap d "_d
nnoremap D "_D
xnoremap D "_D
nnoremap c "_c
xnoremap c "_c
nnoremap C "_C
xnoremap C "_C
nnoremap <Del> "_x
xnoremap <Del> "_x

"--- Selection with shift+arrows -------------------------------------------
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

" Keep the selection after indenting. The old config bound these to , and . in
" visual mode — but , is <leader>, so every visual-mode <leader> mapping was
" unreachable.
xnoremap < <gv
xnoremap > >gv

"--- Search ----------------------------------------------------------------
" Clear the highlight left over from the last search, without disturbing the
" search itself — n and N still work, and @/ keeps the pattern (which matters,
" because cgn and :%s//new/ both reuse it).
"
" Mostly a manual override: Vim 9.2's bundled `nohlsearch` package (packadd in
" 10-plugins.vim) already drops the highlight as soon as the cursor moves. This
" is for clearing it while standing still.
noremap <silent> <leader><cr> :nohlsearch<cr>

"--- Yank ------------------------------------------------------------------
" Word-yank, displaced from the bare y that used to shadow the operator.
nnoremap <leader>y viwy

"--- Windows ---------------------------------------------------------------
" Ctrl+W closes the buffer (IDE convention, see 31-keymap-ide.vim), so the
" window-command prefix moves to <leader>w: <leader>ws splits, <leader>wo onlys,
" <leader>w= equalises, and so on. noremap, so the RHS is the built-in prefix
" rather than the CloseBuffer mapping.
nnoremap <leader>w <C-w>

nnoremap <leader>- :new<cr>
nnoremap <leader><bar> :vnew<cr>

"--- Buffers and tabs ------------------------------------------------------
" <leader>T is the symbol picker now; a new empty buffer is <leader>N.
nnoremap <leader>N :enew<cr>
" NOTE: <leader>b is deliberately NOT a mapping — it is the prefix for these.
" It used to open the buffer picker as well, which made every <leader>b*
" press wait out 'timeoutlen' first. The picker is <leader>B.
nnoremap <leader>bl :ls<CR>
noremap <leader>ba :1,1000 bd!<cr>
noremap <leader>tn :tabnew<cr>
noremap <leader>to :tabonly<cr>
noremap <leader>tc :tabclose<cr>
noremap <leader>tm :tabmove
noremap <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

"--- Misc ------------------------------------------------------------------
nnoremap <leader>W :set wrap!<cr>
nnoremap <leader>bu :!cp % %.bak<CR><CR>:echomsg "Backed up" expand('%')<CR>

" Spell checking. Off by default ('spell' is unset in 20-options.vim) because it
" flags every identifier in source code; toggle it on for prose and commits.
" setlocal, so it applies to the current buffer only.
"
" The added-words file is 'spellfile', which defaults to the first writable
" directory in 'runtimepath' — here ~/.vim/spell/, gitignored so machine-specific
" vocabulary does not sync.
" Comments above rather than beside, because :noremap takes the rest of the line
" as the {rhs} — see the caution in the abbreviation block above.
"
"   <F7>        toggle spell checking for this buffer
"   <leader>sn  next misspelling                        (]s)
"   <leader>sp  previous misspelling                    ([s)
"   <leader>sa  add the word under the cursor to the dictionary (zg)
"   <leader>s?  list suggested corrections, pick by number      (z=)
noremap <F7> :setlocal spell!<cr>
noremap <leader>sn ]s
noremap <leader>sp [s
noremap <leader>sa zg
noremap <leader>s? z=

" Run a macro over every line of a visual selection.
function! s:ExecuteMacroOverVisualRange() abort
  echo '@' . getcmdline()
  execute ":'<,'>normal @" . nr2char(getchar())
endfunction
xnoremap @ :<C-u>call <SID>ExecuteMacroOverVisualRange()<CR>

" Title banner, matching the comment style used throughout this config.
nnoremap <leader>title 63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`oi<space>
vnoremap <leader>title ydd63i"<esc><esc>o"--<space><space><esc>moi<cr><esc>63i"<esc><esc>a<cr><esc>`opi<bs>

" :FixTabs [width] — convert the current buffer to spaces at the given width.
function! s:FixTabs(...) abort
  let l:width = get(a:, 1, 2)
  let &l:tabstop = l:width
  let &l:shiftwidth = l:width
  setlocal expandtab
  retab
endfunction
command! -bang -nargs=? FixTabs call <SID>FixTabs(<args>)

"--- Save ------------------------------------------------------------------
" Write only if modified; prompt for a name if the buffer has never been saved.
" https://vim.fandom.com/wiki/Map_Ctrl-S_to_save_current_or_new_files
command! -nargs=0 -bar Update
      \ if &modified |
      \   if empty(bufname('%')) |
      \     browse confirm write |
      \   else |
      \     confirm write |
      \   endif |
      \ endif

"--- Buffer close (backing the Ctrl+W mapping in 31-keymap-ide.vim) ---------
" Closes the buffer the way a browser closes a tab: keep the window layout, keep
" the file tree open, and only quit Vim when the last real buffer goes.
function! CloseBuffer() abort
  if &filetype ==? 'nerdtree'
    wincmd w
  endif
  if &buftype ==? 'quickfix'
    cclose
    return
  endif

  let l:nerdtree_open = exists('g:NERDTree') && g:NERDTree.IsOpen()
  let l:window_count = winnr('$')
  let l:total_buffers = len(getbufinfo({ 'buflisted': 1 }))
  let l:nerdtree_last = l:nerdtree_open && l:window_count == 2
  let l:no_splits = !l:nerdtree_open && l:window_count == 1

  if l:total_buffers == 1 && (l:nerdtree_last || l:no_splits)
    quit!
    return
  endif

  if l:total_buffers > 1 && (l:nerdtree_last || l:no_splits)
    bprevious | bdelete! #
    if l:nerdtree_open
      NERDTreeFind | wincmd w
    endif
    return
  endif

  bdelete
endfunction

"--- Duplicate / delete line (Ctrl+D / Ctrl+Y in the IDE layer) -------------
" Both used to hand-roll register save/restore through register "c. :t and :d
" with an explicit black-hole register do the same job without touching any
" user-visible register.
function! DuplicateLine(mode) abort
  if a:mode ==? 'v'
    " :t copies the selected lines below the selection without going near a
    " register — which matters, because clipboard=unnamedplus would otherwise
    " make duplicating a line overwrite the system clipboard.
    '<,'>t'>
    return
  endif
  let l:col = col('.')
  t.
  call cursor(line('.'), l:col)
  if a:mode ==? 'i'
    startinsert
  endif
endfunction

function! DeleteLine(mode) abort
  let l:col = col('.')
  if a:mode ==? 'v'
    '<,'>delete _
  else
    delete _
  endif
  call cursor(line('.'), l:col)
  if a:mode ==? 'i'
    startinsert
  endif
endfunction
