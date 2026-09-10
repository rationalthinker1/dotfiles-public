" ~/.config/nvim/config/01-clipboard.vim — clipboard.
"
" The Vim version of this file is ~80 lines: it registers a provider into
" v:clipproviders and appends a backend to 'clipmethod', because on WSLg Vim's
" own candidates both fail (no wlr/ext-data-control protocol for "wayland",
" -xterm_clipboard for "x11") and v:clipmethod lands on "none".
"
" NONE of that exists in Neovim. v:clipproviders and 'clipmethod' are Vim 9.1
" APIs with no counterpart; Neovim discovers a clipboard tool at startup on its
" own, probing wl-copy/wl-paste, xclip, xsel, win32yank and others, and exposes
" the result through g:clipboard. wl-clipboard is installed on this machine, so
" it is found without configuration — verify with :checkhealth provider.
"
" So the correct port of that file is this comment. The 80 lines are not
" translated, because there is nothing to translate them into and nothing for
" them to fix.
"
" Two consequences worth knowing:
"
"   * Neovim shells out to wl-copy on yank exactly as the Vim provider did, so
"     the same per-yank process cost applies. Neovim caches the connection where
"     it can, which is why yanks feel faster here.
"   * If :checkhealth ever reports no clipboard tool, install wl-clipboard
"     (Wayland/WSLg) or xclip (X11) — do not port the Vim provider across.

" Yank and put go through the system clipboard, matching the Vim config.
set clipboard=unnamedplus
