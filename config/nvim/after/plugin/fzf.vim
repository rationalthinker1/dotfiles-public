" fzf.vim — the file-shaped pickers.
"
" WHY fzf AND NOT snacks FOR THESE
"
" The fzf binary is already part of this machine's shell: zinit installs it for
" fzf-tab, and $FZF_DEFAULT_OPTS / the colour scheme / the key bindings are
" configured once in config/fzf/ and config/zsh/. Using it here means the picker
" in Neovim looks and behaves like the one in the terminal, and matches the Vim
" config key for key.
"
" snacks.picker keeps what it is actually better at — anything LSP-aware
" (<leader>T symbols, Alt+0 diagnostics) plus the dashboard and explorer. See
" lua/plugins/picker.lua.
"
" THE BINARY. fzf#exec() looks in exactly two places: `fzf` on $PATH, and the
" plugin's own bin/fzf (which vim-plug's `do: fzf#install()` hook populates and
" vim.pack has no equivalent for). There is NO g:fzf_bin — pointing one at the
" binary does nothing.
"
" On $PATH is the normal case: zinit puts fzf there for fzf-tab, so Neovim
" launched from the shell already has it. Launched from a desktop entry or any
" context without that PATH, fzf#exec() would prompt "fzf executable not found.
" Download binary? (y/n)" — which in a headless or scripted run just hangs.
"
" So when it is missing, prepend the same binary the shell uses. One directory,
" appended to $PATH for this process only, no second copy of fzf on disk.
if !executable('fzf')
  let s:zinit_bin = expand('~/.local/share/zinit/plugins/junegunn---fzf/bin')
  if executable(s:zinit_bin . '/fzf')
    let $PATH = s:zinit_bin . ':' . $PATH
  endif
endif

if !exists(':Files')
  finish
endif

" ctrl-t/x/r to open in a tab/split/vsplit — same as the Vim config.
let g:fzf_action = {
      \ 'ctrl-t': 'tab split',
      \ 'ctrl-x': 'split',
      \ 'ctrl-r': 'vsplit' }

let g:fzf_history_dir = '~/.config/fzf/fzf-history'

" :Files rooted at the project root, via lua/plugins/rooter.lua (vim.fs.root).
function! s:find_files() abort
  let l:root = luaeval("require('plugins.rooter').root()")
  execute 'Files' l:root
endfunction
command! ProjectFiles call s:find_files()

" :Find <pattern> — ripgrep across the project with a preview pane.
command! -bang -nargs=* Find call fzf#vim#grep(
      \ 'rg --smart-case --column --line-number --no-heading --fixed-strings --hidden --follow '
      \ . '--glob "!{.git,node_modules,vendor,oh-my-zsh,antigen,*.log}" '
      \ . '--color always ' . shellescape(<q-args>) . ' | tr -d "\017"', 1,
      \ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%', '?'),
      \ <bang>0)

" :Registers — fzf.vim has no register source of its own.
function! s:registers_sink(line) abort
  let l:reg = matchstr(a:line, '^\s*"\zs\S\ze')
  if !empty(l:reg)
    execute 'normal! "' . l:reg . 'p'
  endif
endfunction

function! s:registers() abort
  call fzf#run(fzf#wrap('Registers', {
        \ 'source':  split(execute('registers', 'silent!'), "\n")[1:],
        \ 'sink':    function('s:registers_sink'),
        \ 'options': ['+s', '--prompt', 'Registers> ']}))
endfunction
command! Registers call s:registers()

" :History, :Buffers, :Marks and :Commands are fzf.vim's own — nothing to define.
