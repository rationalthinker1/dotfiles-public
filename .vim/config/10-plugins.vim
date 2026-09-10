" ~/.vim/config/10-plugins.vim — plugin declarations only.
"
" Declarations live here; configuration lives in ~/.vim/after/plugin/, which Vim
" sources *after* these plugins load. The old layout mixed the two inside the
" plug#begin/plug#end block, so every mapping ran before the plugin it configured
" was even on 'runtimepath'.

" Bootstrap vim-plug on a fresh machine.
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

"--- Language support ------------------------------------------------------
" Vim 9.2 bundles syntax for yaml, dockerfile, tmux, json and friends, so only
" the filetypes the runtime handles badly are carried as plugins.
Plug 'chr4/nginx.vim'
Plug 'StanAngeloff/php.vim'
Plug 'yuezk/vim-js'
Plug 'chemzqm/vim-jsx-improve'
Plug 'fladson/vim-kitty'                  " kitty.conf syntax

"--- LSP, completion, snippets ---------------------------------------------
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Snippet *source* only. coc-snippets (see g:coc_global_extensions) reads the
" UltiSnips format directly; the UltiSnips engine itself is gone because its
" <tab> jump trigger fought coc's <tab> completion mapping.
Plug 'honza/vim-snippets'
Plug 'github/copilot.vim'

"--- Editing ---------------------------------------------------------------
Plug 'tpope/vim-surround'                 " cs)} change surround, ds( delete, ysiw} add
Plug 'tpope/vim-repeat'                   " make . repeat plugin maps too
Plug 'tpope/vim-abolish'                  " crm/crc/crs coercion; :Subvert
Plug 'tpope/vim-eunuch'                   " :Rename :Delete :Move :Chmod :Mkdir :SudoWrite
Plug 'tpope/vim-sleuth'                   " detect per-project indent (we default to noexpandtab)
Plug 'tpope/vim-fugitive'                 " :Git commit/diff/log, :Gvdiffsplit
Plug 'junegunn/vim-easy-align'            " ga{=,:,<space>} to align
Plug 'alvan/vim-closetag'                 " auto-close html tags
Plug 'cohama/lexima.vim'                  " auto-close brackets/quotes
Plug 'AndrewRadev/switch.vim'             " true<->false etc.
Plug 'ntpeters/vim-better-whitespace'     " highlight + :StripWhitespace
Plug 'mg979/vim-visual-multi'             " multi-cursor: <C-n>, <M-Down>
Plug 'markonm/traces.vim'                 " live preview for :s, :g, :sort ranges
Plug 'matze/vim-move'                     " move lines/blocks with Alt-Shift-arrows

"--- Text objects / motions ------------------------------------------------
Plug 'wellle/targets.vim'                 " ia/aa arguments, plus pair/quote/separator objects
Plug 'michaeljsmith/vim-indent-object'    " ai/ii indent objects
Plug 'andymass/vim-matchup'               " % across if/endif, while/done
Plug 'rhysd/clever-f.vim'                 " f repeats f instead of needing ;
Plug 'kana/vim-smartword'                 " smarter w/b/e
Plug 'haya14busa/vim-asterisk'            " z* keeps cursor position
Plug 'easymotion/vim-easymotion'          " AceJump analogue: <leader><leader>w

"--- Navigation / UI -------------------------------------------------------
Plug 'preservim/nerdtree'                 " file explorer (Ctrl+B)
Plug 'Xuyuanp/nerdtree-git-plugin'        " git status marks in the explorer
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'itchyny/lightline.vim'
Plug 'mengelbrecht/lightline-bufferline'  " sole owner of 'tabline'
Plug 'mhinz/vim-startify'                 " start screen with recent files
Plug 'kshenoy/vim-signature'              " visualise marks in the gutter
Plug 'mbbill/undotree'                    " F5: undo history
Plug 'airblade/vim-rooter'                " cd to project root
Plug 'simeji/winresizer'                  " <leader>r then hjkl to resize
Plug 'psliwka/vim-smoothie'               " smooth PageUp/PageDown
Plug 'farmergreg/vim-lastplace'           " restore cursor position on reopen
Plug 'luochen1990/rainbow'                " rainbow parentheses
Plug 'christoomey/vim-tmux-navigator'     " one set of keys for vim splits + tmux panes

"--- Colourschemes ---------------------------------------------------------
Plug 'rationalthinker1/cyberpunk.vim'     " active (see 40-ui.vim)
Plug 'joshdick/onedark.vim'
Plug 'rakr/vim-one'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'evturn/cosmic-barf'
Plug 'micke/vim-hybrid'
Plug 'hzchirs/vim-material'
Plug 'simonsmith/material.vim'
Plug 'daylerees/colour-schemes', { 'rtp': 'vim/' }
Plug 'effkay/argonaut.vim'
Plug 'DankNeon/vim'

call plug#end()

" Vim 9.2 ships these as optional packages. Each one replaces a plugin this
" config used to carry:
"   comment      -> nerdcommenter   (<Plug>(comment-toggle), gc/gcc)
"   nohlsearch   -> half of incsearch.vim (clears hlsearch on cursor move)
"   editorconfig -> .editorconfig support, previously absent
"   hlyank       -> briefly highlights the yanked region
"   cfilter      -> :Cfilter/:Lfilter to narrow quickfix lists
" Guarded, because `packadd!` raises E919 for a package that does not exist and
" this config does not always run on the pinned vim. `mise activate` only
" reaches interactive shells, so a clean non-interactive one — `git commit`
" spawned from a script or a GUI — gets Ubuntu's /bin/vim 9.1 instead, where
" comment, nohlsearch and hlyank are all absent. That produced three E919s on
" every such commit.
for s:pack in ['comment', 'nohlsearch', 'editorconfig', 'hlyank', 'cfilter']
  if !empty(globpath(&packpath, 'pack/dist/opt/' . s:pack, 0, 1))
    execute 'packadd! ' . s:pack
  endif
endfor
unlet! s:pack
