" ~/.config/nvim/config/05-plugin-vars.vim — plugin variables, set BEFORE plugins load.
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
"                                  the explorer toggle
"   g:winresizer_start_key         was ignored -> winresizer kept <C-e>, which is
"                                  Recent Files
"   g:switch_mapping               was ignored -> switch.vim kept its default gs
"
" So the rule for this config is:
"
"   VARIABLES  ->  here, before plug#end()
"   MAPPINGS   ->  ~/.config/nvim/after/plugin/, after the <Plug> targets exist
"
" Setting a variable for a plugin that is not installed is harmless, so nothing
" here needs a guard.

"--- (coc.nvim removed) ------------------------------------------------------
" g:coc_global_extensions and the snippet-jump keys lived here. Their
" replacements are Lua and configure themselves: see lua/plugins/lsp.lua and
" lua/plugins/completion.lua.

"--- (fzf removed) -----------------------------------------------------------
" Replaced by snacks.picker; configured in lua/plugins/picker.lua. The fzf
" BINARY is untouched and still used by the shell.

"--- (NERDTree removed) ------------------------------------------------------
" Replaced by snacks.explorer; see lua/plugins/picker.lua.

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

"--- (lexima removed) --------------------------------------------------------
" Replaced by nvim-autopairs, which decides from the syntax tree rather than a
" rule table; configured in lua/plugins/pairs.lua.


"--- vim-tmux-navigator ----------------------------------------------------
" Own mappings only; see after/plugin/navigation.vim for why.
let g:tmux_navigator_no_mappings = 1

"--- winresizer ------------------------------------------------------------
" <C-e> is Recent Files in the IDE layer.
let g:winresizer_start_key = '<leader>r'


"--- (vim-closetag removed) --------------------------------------------------
" Replaced by nvim-ts-autotag, which closes and renames tags from the syntax
" tree; configured in lua/plugins/ui-extras.lua.

"--- (rainbow removed) -------------------------------------------------------
" Replaced by rainbow-delimiters.nvim, which colours by treesitter node rather
" than by regex; configured in lua/plugins/ui-extras.lua.

"--- vim-better-whitespace -------------------------------------------------
let g:better_whitespace_enabled = 1
let g:strip_whitespace_on_save = 0
let g:better_whitespace_filetypes_blacklist =
      \ ['diff', 'git', 'gitcommit', 'fugitive', 'markdown', 'help',
      \  'snacks_dashboard', 'snacks_picker_list', 'snacks_picker_input']


"--- (startify removed) ------------------------------------------------------
" Replaced by snacks.dashboard; configured in lua/plugins/picker.lua.

"--- (lightline removed) -----------------------------------------------------
" Replaced by lualine, which also absorbs lightline-bufferline; see
" lua/plugins/statusline.lua.

"--- copilot.vim -------------------------------------------------------------
" Take <Tab> away from Copilot and give it an explicit key.
"
" By default copilot.vim maps <Tab> in insert mode GLOBALLY to copilot#Accept().
" blink.cmp maps <Tab> BUFFER-LOCALLY on InsertEnter. A buffer-local mapping
" beats a global one — but only on buffers blink has reached, so which of the
" two owned <Tab> depended on timing rather than intent. That is not a thing to
" leave to chance in the key you press most.
"
" With this, <Tab> is unambiguously blink's (accept the completion) and Copilot
" suggestions are accepted with Alt+L. Alt+L is free: vim-move uses the
" Alt+Shift+arrows and Ctrl+L is tmux pane navigation.
let g:copilot_no_tab_map = v:true
imap <silent><script><expr> <M-l> copilot#Accept("\<CR>")
let g:copilot_assume_mapped = v:true
