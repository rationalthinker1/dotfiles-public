" ~/.vim/config/05-plugin-vars.vim — plugin variables, set BEFORE plugins load.
"
" WHY THIS FILE COMES BEFORE 10-plugins.vim
"
" Many plugins read their configuration once, in their plugin/ file, at the
" moment `plug#end()` puts them on 'runtimepath'. A variable set after that point
" is simply ignored, and the plugin has already installed its defaults — usually
" including mappings that then shadow yours.
"
" That is not hypothetical. With these same settings in after/plugin/ instead:
"   g:VM_default_mappings=0        was ignored -> visual-multi took <C-Up>/<C-Down>,
"                                  which are 5k/5j in 30-keymap-core.vim
"   g:smoothie_no_default_mappings was ignored -> smoothie took <C-b>, which is the
"                                  NERDTree toggle
"   g:winresizer_start_key         was ignored -> winresizer kept <C-e>, which is
"                                  Recent Files
"   g:switch_mapping               was ignored -> switch.vim kept its default gs
"
" So the rule for this config is:
"
"   VARIABLES  ->  here, before plug#end()
"   MAPPINGS   ->  ~/.vim/after/plugin/, after the <Plug> targets exist
"
" Setting a variable for a plugin that is not installed is harmless, so nothing
" here needs a guard.

"--- coc.nvim --------------------------------------------------------------
let g:coc_global_extensions = [
      \ 'coc-tsserver',
      \ 'coc-eslint',
      \ 'coc-pyright',
      \ 'coc-emmet',
      \ 'coc-css',
      \ 'coc-snippets',
      \ 'coc-docker',
      \ 'coc-sh',
      \ 'coc-html',
      \ 'coc-json',
      \ 'coc-yank',
      \ 'coc-prettier',
      \ 'coc-phpls',
      \ 'coc-tailwindcss',
      \ 'coc-git',
      \ 'coc-highlight',
      \]
" Snippet jumps. These were <tab>/<s-tab> under UltiSnips, colliding head-on with
" coc's <tab> completion mapping.
let g:coc_snippet_next = '<C-j>'
let g:coc_snippet_prev = '<C-k>'

"--- fzf -------------------------------------------------------------------
let g:fzf_action = {
      \ 'ctrl-t': 'tab split',
      \ 'ctrl-x': 'split',
      \ 'ctrl-r': 'vsplit' }
let g:fzf_history_dir = '~/.config/fzf/fzf-history'

"--- NERDTree --------------------------------------------------------------
let g:NERDTreeRespectWildIgnore = 1
let g:NERDTreeIgnore = ['\.DS_Store$', '\.git$', 'node_modules', '\.sublime-project',
      \ '\.sublime-workspace', '\.idea$']
let g:NERDTreeShowHidden = 1
let g:NERDTreeMouseMode = 2
let g:NERDTreeMinimalUI = 1
let g:NERDTreeDirArrows = 1
let g:NERDTreeShowLineNumbers = 0

"--- vim-smoothie ----------------------------------------------------------
" Without this, smoothie claims <C-b>, <C-d>, <C-e>, <C-f>, <C-u> and <C-y> —
" five of which this config binds to IDE actions.
let g:smoothie_no_default_mappings = 1

"--- vim-visual-multi ------------------------------------------------------
" Defaults disabled wholesale: VM claims <C-Up>/<C-Down>, bound to 5k/5j.
let g:VM_default_mappings = 0
let g:VM_maps = {
      \ 'Find Under':         '<C-n>',
      \ 'Find Subword Under': '<C-n>',
      \ 'Select All':         '<C-S-l>',
      \ 'Add Cursor Down':    '<C-M-Down>',
      \ 'Add Cursor Up':      '<C-M-Up>',
      \ 'Skip Region':        '<C-x>',
      \ 'Remove Region':      '<C-S-x>',
      \ }

"--- vim-move --------------------------------------------------------------
let g:move_map_keys = 0
let g:move_auto_indent = 1

"--- switch.vim ------------------------------------------------------------
" `-` switches forward, `_` backward. The old config bound <C-a>/<C-x>, taking
" Vim's increment/decrement (now on g<C-a> / g<C-x>).
let g:switch_mapping = '-'
let g:switch_reverse_mapping = '_'
let g:switch_custom_definitions = [
      \ ['true', 'false'],
      \ ['next', 'previous'],
      \ ['dark', 'light'],
      \ ['yes', 'no'],
      \ ['on', 'off'],
      \ ['left', 'right'],
      \ ['!=', '=='],
      \ ['&&', '||'],
      \ [': ', '='],
      \ ['min', 'max'],
      \ ['@', 'this.'],
      \]

"--- lexima ----------------------------------------------------------------
" Basic rules off at load; after/plugin/editing.vim installs them explicitly so
" the <CR> hook is registered against a known rule set.
let g:lexima_enable_basic_rules = 0

"--- clever-f --------------------------------------------------------------
let g:clever_f_not_overwrites_standard_mappings = 1

"--- vim-tmux-navigator ----------------------------------------------------
" Own mappings only; see after/plugin/navigation.vim for why.
let g:tmux_navigator_no_mappings = 1

"--- winresizer ------------------------------------------------------------
" <C-e> is Recent Files in the IDE layer.
let g:winresizer_start_key = '<leader>r'

"--- vim-rooter ------------------------------------------------------------
let g:rooter_patterns = ['.git', 'package.json', 'composer.json', 'Cargo.toml', 'go.mod']
let g:rooter_silent_chdir = 1

"--- vim-closetag ----------------------------------------------------------
let g:closetag_filenames = '*.html,*.xhtml,*.phtml,*.vue,*.jsx,*.tsx'
let g:closetag_regions = {
      \ 'typescript.tsx': 'jsxRegion,tsxRegion',
      \ 'javascript.jsx': 'jsxRegion',
      \ }

"--- rainbow parentheses ---------------------------------------------------
let g:rainbow_active = 1
let g:rainbow_conf = { 'operators': '_,\|=\|+\|\*\|-\|\.\|;\||\|&\|?\|:\|<\|>\|%\|/[^/]_' }

"--- vim-better-whitespace -------------------------------------------------
let g:better_whitespace_enabled = 1
let g:strip_whitespace_on_save = 0
let g:better_whitespace_filetypes_blacklist =
      \ ['diff', 'git', 'gitcommit', 'fugitive', 'markdown', 'startify', 'nerdtree', 'help']

"--- easymotion ------------------------------------------------------------
let g:EasyMotion_do_mapping = 1
let g:EasyMotion_smartcase = 1

"--- startify --------------------------------------------------------------
let g:startify_change_to_vcs_root = 1
let g:startify_session_dir = $XDG_DATA_HOME . '/vim/sessions'
let g:startify_lists = [
      \ { 'type': 'dir',       'header': ['   Recent in ' . getcwd()] },
      \ { 'type': 'files',     'header': ['   Recent'] },
      \ { 'type': 'sessions',  'header': ['   Sessions'] },
      \ { 'type': 'bookmarks', 'header': ['   Bookmarks'] },
      \ ]

"--- lightline -------------------------------------------------------------
" component_function names are resolved at render time, so the functions
" themselves can live in after/plugin/lightline.vim.
let g:lightline = {
      \ 'colorscheme': 'one',
      \ 'active': {
      \   'left':  [ [ 'mode', 'paste' ],
      \              [ 'gitbranch', 'gitstatus', 'filename' ] ],
      \   'right': [ [ 'percent', 'lineinfo' ],
      \              [ 'cocstatus' ],
      \              [ 'fileformat', 'fileencoding', 'filetype' ] ]
      \ },
      \ 'tabline': { 'left': [['buffers']], 'right': [[]] },
      \ 'component_expand': { 'buffers': 'lightline#bufferline#buffers' },
      \ 'component_type':   { 'buffers': 'tabsel' },
      \ 'component_function': {
      \   'gitbranch': 'LightlineGitBranch',
      \   'gitstatus': 'LightlineGitStatus',
      \   'cocstatus': 'coc#status',
      \   'readonly':  'LightlineReadonly',
      \   'modified':  'LightlineModified',
      \   'filename':  'LightlineFilename'
      \ },
      \ 'subseparator': { 'left': '>', 'right': '' }
      \ }
