# 00-env.fish - Environment variables + PATH (Fish analog of zsh/.zshenv)
# ----------------------------------------------------------------------------
# conf.d/*.fish is sourced for EVERY fish session (interactive, login, and
# `fish -c` scripts), so this is the right place for environment that all
# contexts need - exactly like .zshenv on the ZSH side.

# --- Base paths (XDG-compliant) ---
set -gx DOTFILES_ROOT "$HOME/.dotfiles"
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME "$HOME/.local/share"
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx LOCAL_CONFIG "$XDG_CONFIG_HOME"

# ZDOTDIR/ZSH_CACHE_DIR are kept so shared tooling and references resolve the
# same paths whether you are in fish or zsh.
set -gx ZDOTDIR "$XDG_CONFIG_HOME/zsh"
set -gx ZSH_CACHE_DIR "$ZDOTDIR/cache"

# --- Tool-specific envs ---
set -gx RUSTUP_HOME "$XDG_CONFIG_HOME/.rustup"
set -gx CARGO_HOME "$XDG_CONFIG_HOME/.cargo"
set -gx VOLTA_HOME "$XDG_CONFIG_HOME/volta"
set -gx BUN_INSTALL "$XDG_CONFIG_HOME/bun"
set -gx PNPM_HOME "$XDG_CONFIG_HOME/pnpm"
set -gx CLAUDE_CONFIG_DIR "$XDG_CONFIG_HOME/claude"
set -gx CODEX_HOME "$XDG_CONFIG_HOME/codex"
set -gx GNUPGHOME "$XDG_CONFIG_HOME/gnupg"
set -gx PASSWORD_STORE_DIR "$XDG_CONFIG_HOME/password-store"
set -gx ENHANCD_DIR "$XDG_CONFIG_HOME/enhancd"

# --- Terminal & editor defaults ---
set -gx EDITOR vim
set -gx LESS -XRF

# --- AWS ---
set -gx AWS_CONFIG_FILE "$XDG_CONFIG_HOME/.aws/config"
set -gx AWS_SHARED_CREDENTIALS_FILE "$XDG_CONFIG_HOME/.aws/credentials"

# --- fd default exclusions (used by the fdf/fdd functions) ---
set -gx FD_EXCLUDE_PATTERN '{.cargo,node_modules,.git,.cache,cache,vendor,tmp,.npm,*.bak,bundles,build}'

# --- Detect host OS / environment (HOST_OS, HOST_LOCATION, IS_DEVCONTAINER) ---
detect_os

# --- Vim build configuration for mise (Python3 support) ---
# Mirrors .zshenv so `mise install/upgrade vim` builds with Python3 even when
# fish is the login shell.
if command -q python3; and command -q python3-config
    set -l python_prefix (python3 -c "import sys; print(sys.prefix)" 2>/dev/null)
    set -l py3_location (command -v python3)
    if test -n "$py3_location"; and test -n "$python_prefix"
        set -gx ASDF_VIM_CONFIG "--with-tlib=ncurses --with-compiledby=mise --enable-multibyte --enable-cscope --enable-terminal --enable-python3interp --with-python3-command=$py3_location --enable-fail-if-missing --enable-gui=no --without-x"
        set -gx LDFLAGS "-L$python_prefix/lib -Wl,-rpath,$python_prefix/lib $LDFLAGS"
    end
end

# --- PATH (prepended, de-duplicated; -g keeps it per-session/deterministic) ---
fish_add_path --global --move --prepend \
    "$CARGO_HOME/bin" \
    "$HOME/.local/bin" \
    /usr/local/go/bin \
    "$HOME/.yarn/bin" \
    "$XDG_CONFIG_HOME/yarn/global/node_modules/.bin" \
    "$BUN_INSTALL/bin" \
    "$PNPM_HOME/bin"

# --- WSL-specific ---
if test "$HOST_OS" = wsl
    # WSL auto-appends 20+ slow NTFS-mounted Windows dirs to PATH. Trim to the
    # essentials for a large command-lookup speedup (mirrors .zshenv).
    set -l filtered (string match --invert '/mnt/c/*' $PATH)
    set -gx PATH '/mnt/c/Program Files/PowerShell/7' /mnt/c/Windows/System32 /mnt/c/Windows $filtered
    set -gx LIBGL_ALWAYS_INDIRECT 1
    set -gx BROWSER wslview
end
