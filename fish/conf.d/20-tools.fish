# 20-tools.fish - External tool integrations (interactive only)
# These binaries are installed via mise/zinit and live on PATH regardless of
# shell; here we just wire up their fish init/hooks.

status is-interactive; or return

# --- FZF environment (shared values with the ZSH config) ---
set -gx FZF_DEFAULT_COMMAND "rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND "fd --type d"
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --info=inline"
set -gx FZF_CTRL_T_OPTS "--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# --- Tool config envs ---
set -gx RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/.ripgreprc"
set -gx BAT_THEME OneHalfDark
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx FORGIT_DIFF_GIT_OPTS "-w --ignore-blank-lines"

# --- fzf: key bindings (Ctrl-T files, Alt-C dirs; Ctrl-R is reclaimed by atuin
#     below since atuin initialises last). Uses fzf's built-in fish integration.
if command -q fzf
    fzf --fish | source
end

# --- zoxide: smarter cd (provides `z` and interactive `zi`) ---
if command -q zoxide
    zoxide init fish | source
end

# --- mise: runtime version manager ---
if command -q mise
    mise activate fish | source
end

# --- atuin: shell history with sync/stats (binds Ctrl-R last so it wins) ---
if command -q atuin
    atuin init fish | source
end

# --- broot: directory visualiser (`br`) ---
set -l broot_launcher "$XDG_CONFIG_HOME/broot/launcher/fish/br.fish"
test -f "$broot_launcher"; and source "$broot_launcher"

# --- direnv: per-project env (disabled by default, mirrors the ZSH config) ---
# command -q direnv; and direnv hook fish | source

# --- VS Code shell integration ---
if test "$TERM_PROGRAM" = vscode; and command -q code
    set -l vsc_path (code --locate-shell-integration-path fish 2>/dev/null)
    test -n "$vsc_path"; and test -f "$vsc_path"; and source "$vsc_path"
end
