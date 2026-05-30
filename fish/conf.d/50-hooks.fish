# 50-hooks.fish - Context-aware hooks (port of zsh/hooks.zsh)
# ZSH precmd/chpwd become fish_title + a `--on-variable PWD` event handler.

status is-interactive; or return

# Terminal title: user@host: cwd  (ZSH _set_terminal_title)
function fish_title
    echo (whoami)'@'(hostname -s)': '(prompt_pwd)
end

# Smart directory-context hook - runs after every directory change.
function _context_aware_pwd --on-variable PWD
    status is-interactive; or return

    # Auto-activate a Python venv if present
    if test -d .venv/bin; and not set -q VIRTUAL_ENV; and test -f .venv/bin/activate.fish
        source .venv/bin/activate.fish
    end

    # Show a hint if a README is present
    test -f README.md; and echo "📄 README.md present"

    # Auto-source .dirrc, but only from trusted locations ($HOME and below)
    if test -f .dirrc
        switch $PWD
            case "$HOME" "$HOME/*"
                source .dirrc
            case '*'
                set_color yellow
                echo "⚠️  Found .dirrc in untrusted location: $PWD"
                echo "Run 'source .dirrc' to load it manually"
                set_color normal
        end
    end
end
