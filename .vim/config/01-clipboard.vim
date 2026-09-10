" ~/.vim/config/01-clipboard.vim — clipboard provider.
"
" Sourced before plugins because it has to exist before anything touches a register.
"
" Vim 9.1+ resolves 'clipmethod' at runtime, and on WSL neither candidate works:
" WSLg's compositor exposes no wlr/ext-data-control protocol (so "wayland" fails)
" and this binary is -xterm_clipboard (so "x11" is compiled out). v:clipmethod
" lands on "none" and every access to + warns "W23: Clipboard register not
" available, using register 0". Bridge + and * through an external tool instead.
"
" NOTE (verified 2026-08-31, Vim 9.2.0926): this binary is now +wayland
" +wayland_clipboard with 'clipmethod' defaulting to "wayland,x11", which looks
" like it should make this block redundant. It is not — v:clipmethod still
" resolves to "none" under WSLg. Re-check with:
"     vim -c 'echo v:clipmethod' -c q
" and only delete this block if it reports something other than "none".
"
" Appended to 'clipmethod' with += rather than ^=: Vim probes left to right and
" falls through cleanly, so a machine whose built-in wayland/x11 clipboard does
" work keeps using it and never pays for a fork.
"
" macOS and the GUI are excluded — their clipboard is native and 'clipmethod' is
" ignored there by design. Headless (no WAYLAND_DISPLAY, no DISPLAY) selects no
" backend and the whole block is a no-op; there is no clipboard to reach.
if has('clipboard_provider') && !has('gui_running') && !has('mac') && !has('macunix')
    " "+" is CLIPBOARD, "*" is PRIMARY per Vim convention. Where the compositor
    " has no primary selection (WSLg) those commands just fail and the register
    " is left unchanged.
    let s:clipbackend = {}
    if !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
        let s:clipbackend = {
            \ 'name': 'wl',
            \ 'copy':  { '+': 'wl-copy --type text/plain',
            \            '*': 'wl-copy --primary --type text/plain' },
            \ 'paste': { '+': 'wl-paste --no-newline --type text/plain',
            \            '*': 'wl-paste --primary --no-newline --type text/plain' },
            \ }
    elseif !empty($DISPLAY) && executable('xclip')
        let s:clipbackend = {
            \ 'name': 'xclip',
            \ 'copy':  { '+': 'xclip -selection clipboard -in',
            \            '*': 'xclip -selection primary -in' },
            \ 'paste': { '+': 'xclip -selection clipboard -out',
            \            '*': 'xclip -selection primary -out' },
            \ }
    endif

    if !empty(s:clipbackend)
        function! s:ClipCopy(reg, type, lines) abort
            " system()'s {input} always appends a trailing NL, which would turn
            " every charwise yank linewise — write the exact bytes ourselves.
            let l:lines = a:type[0] ==# 'V' ? a:lines + [''] : a:lines
            let l:tmp = tempname()
            call writefile(l:lines, l:tmp, 'b')
            " Redirect the fds: these tools daemonize to serve the selection and
            " would otherwise hold system()'s pipe open, hanging vim on yank.
            call system(s:clipbackend.copy[a:reg] . ' <' . shellescape(l:tmp) . ' >/dev/null 2>&1')
            call delete(l:tmp)
        endfunction

        function! s:ClipPaste(reg) abort
            let l:out = system(s:clipbackend.paste[a:reg] . ' 2>/dev/null')
            if v:shell_error
                return ['', []]
            endif
            " A trailing NL is the linewise signal; both backends emit the
            " selection verbatim, so it is only present if it was yanked.
            if l:out =~# "\n$"
                return ['V', split(l:out, "\n", 1)[0:-2]]
            endif
            return ['v', split(l:out, "\n", 1)]
        endfunction

        let v:clipproviders[s:clipbackend.name] = {
            \ 'copy':  { '+': function('s:ClipCopy'),  '*': function('s:ClipCopy')  },
            \ 'paste': { '+': function('s:ClipPaste'), '*': function('s:ClipPaste') },
            \ }
        execute 'set clipmethod+=' . s:clipbackend.name
    endif
endif
