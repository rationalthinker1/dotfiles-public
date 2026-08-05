# 50-hooks.fish - Context-aware hooks (port of zsh/hooks.zsh)
# ZSH precmd/chpwd become fish_title + a `--on-variable PWD` event handler.

status is-interactive; or return

# Terminal title: user@host: cwd  (ZSH _set_terminal_title)
function fish_title
    echo (whoami)'@'(hostname -s)': '(prompt_pwd)
end

# Smart directory-context hook - runs after every directory change.
# Keep this hook silent on stdout: it fires inside command substitutions too, so
# anything echoed here is captured by callers like `set f (cd $dir; and some-command)`
# and corrupts their result. Informational output belongs on stderr (>&2).
function _context_aware_pwd --on-variable PWD
    status is-interactive; or return

    # Auto-activate a Python venv if present
    if test -d .venv/bin; and not set -q VIRTUAL_ENV; and test -f .venv/bin/activate.fish
        source .venv/bin/activate.fish
    end

    # Auto-source .dirrc, but only from trusted locations ($HOME and below)
    if test -f .dirrc
        switch $PWD
            case "$HOME" "$HOME/*"
                source .dirrc
            case '*'
                # stderr: this hook also fires inside command substitutions, so
                # stdout here would be captured by the caller, not shown to the user.
                echo (set_color yellow)"⚠️  Found .dirrc in untrusted location: $PWD" >&2
                echo "Run 'source .dirrc' to load it manually"(set_color normal) >&2
        end
    end
end
