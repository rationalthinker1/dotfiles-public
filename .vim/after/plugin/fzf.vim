" fzf.vim — fuzzy finding.
"
" The pickers used to be bound to bare capital letters (F H B T M S R), which
" cost the back-find, WORD-back, screen-top/middle, till-back and
" substitute-line motions. They now live on IDE chords and <leader>; see
" config/31-keymap-ide.vim and docs/VIM_KEYMAP.md.

" Command defined by fzf.vim's plugin file, so it is reliably present here;
" exists('*fzf#run') would depend on whether an autoload file happened to have
" been pulled in already.
if !exists(':Files')
  finish
endif

" g:fzf_action and g:fzf_history_dir are in config/05-plugin-vars.vim.

" :Files, rooted at the project root when vim-rooter can find one.
function! s:find_files() abort
  let l:root = exists('*FindRootDirectory') ? FindRootDirectory() : ''
  if !empty(l:root)
    execute 'Files' l:root
  else
    execute 'Files'
  endif
endfunction
command! ProjectFiles call s:find_files()

" :Find <pattern> — ripgrep across the project with a preview pane.
"   --smart-case   case-insensitive unless the pattern has a capital
"   --hidden       search dotfiles
"   --follow       follow symlinks
"   --glob         skip vendored and generated trees
command! -bang -nargs=* Find call fzf#vim#grep(
      \ 'rg --smart-case --column --line-number --no-heading --fixed-strings --hidden --follow '
      \ . '--glob "!{.git,node_modules,vendor,oh-my-zsh,antigen,.vim/plugged,*.log,.viminfo}" '
      \ . '--color always ' . shellescape(<q-args>) . ' | tr -d "\017"', 1,
      \ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%', '?'),
      \ <bang>0)

" :Registers — pick a register and paste it.
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
