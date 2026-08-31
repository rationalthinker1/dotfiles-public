#!/usr/bin/env bash

set -euo pipefail

verify_tool() {
    local tool="${1}"
    local version_cmd="${2}"
    if mise which "${tool}" &>/dev/null; then
        local version=$(mise exec -- ${version_cmd} 2>&1 | head -1)
        echo "✓ ${tool}: ${version}"
        return 0
    else
        echo "⚠ ${tool}: not found (may need manual verification)"
    fi
}

# Create a directory, treating "it is already there" as success.
#
# `mkdir -p` is required by POSIX to be a silent no-op on an existing directory, but the
# rust-coreutils (uutils 0.8.0) that Ubuntu 26.04 ships as its DEFAULT userland exits 1
# with "mkdir: Already exists" instead. Under `set -euo pipefail` that aborts the whole
# install on a rerun — every path here exists by the second run. Since this script is
# re-run for months across machines whose coreutils provider we do not control, never call
# `mkdir -p` directly; go through this.
#
# The dangling-symlink branch is not about uutils: a ~/.config entry left pointing at the
# pre-config/ layout fails `mkdir -p` on GNU too, and link_dotfile would die here before
# reaching the `ln -nfs` that would have repointed it. Only symlinks resolving to nothing
# are removed — a link to a real file is left alone so mkdir fails loudly instead.
ensure_dir() {
    local dir
    for dir in "$@"; do
        [[ -d "${dir}" ]] && continue
        if [[ -L "${dir}" && ! -e "${dir}" ]]; then
            rm -f "${dir}"
        fi
        mkdir -p "${dir}" || { [[ -d "${dir}" ]] || return 1; }
    done
}

# ensure_dir's contract for system paths that need root. Deliberately does NOT clear
# dangling symlinks — nothing outside $HOME should be silently unlinked by this script.
ensure_dir_root() {
    local dir
    for dir in "$@"; do
        [[ -d "${dir}" ]] && continue
        sudo mkdir -p "${dir}" || { [[ -d "${dir}" ]] || return 1; }
    done
}

# Compute relative path from target_dir to source (cross-platform)
relative_path() {
    local source="${1}"
    local target_dir="${2}"
    # GNU coreutils realpath supports --relative-to; macOS does not
    if realpath --relative-to="${target_dir}" "${source}" 2>/dev/null; then
        return
    fi
    python3 -c "import os; print(os.path.relpath('${source}', '${target_dir}'))"
}

# Link one tracked dotfile into place, backing up whatever was there before.
# Idempotent: a target already pointing at the right relative source is left untouched.
# Extracted from the bulk symlink loop so individual links (notably config/mise/config.toml)
# can be established early, before the steps that consume them.
link_dotfile() {
    local source_path="${1}"
    local target="${2}"
    local dotfile_source="${DOTFILES_ROOT}/${source_path}"

    # Skip if source doesn't exist in dotfiles (e.g. password-store not yet committed)
    [[ ! -e "${dotfile_source}" ]] && return 0

    # Ensure parent directory exists (needed before computing relative path)
    ensure_dir "$(dirname "${target}")" "${BACKUP_DIR}"

    # Compute relative symlink path so it works across different $HOME environments (host vs container)
    local relative_source
    relative_source="$(relative_path "${dotfile_source}" "$(dirname "${target}")")"

    # Skip if target is already pointing to the correct relative source
    if [[ -L "${target}" ]]; then
        [[ "$(readlink "${target}")" == "${relative_source}" ]] && return 0
    fi

    # Backup if target exists and is not a symlink to THIS dotfiles repo
    if [[ -e "${target}" ]]; then
        local resolved_path
        resolved_path="$(readlink -f "${target}" 2>/dev/null || echo "")"
        # Only skip if symlink points to our dotfiles directory
        if [[ ! -L "${target}" ]] || [[ "${resolved_path}" != "${DOTFILES_ROOT}"/* ]]; then
            if [[ -f "${target}" || -d "${target}" ]]; then
                echo "  Backing up existing: ${target}"
                rsync -a "${target}" "${BACKUP_DIR}/" 2>/dev/null || true
                rm -rf "${target}"
            fi
        fi
    fi

    # Create relative symlink so it resolves correctly on both host and container
    ln -nfs "${relative_source}" "${target}"
}

# Relocate leftovers from the pre-config/ repo layout.
#
# The directories that get symlinked into ~/.config moved from the repo root into config/.
# `git pull` relocates the TRACKED half of that automatically, but anything untracked or
# gitignored — zsh/local.zsh, zsh/cache/, the *.zwc bytecode, .aws/credentials, password
# entries not yet committed — is invisible to git and stays stranded at the old path. A
# machine that has not been updated in months recovers in a single ./install.sh because of
# this function; keep it permanently, it costs one [[ -d ]] test per directory per run.
#
# The dangling ~/.config/* symlinks need no handling here: link_dotfile's `[[ -e target ]]`
# test follows the link, so it is false for a dangling one — the backup branch is skipped
# and ln -nfs simply repoints it at the new source.
migrate_to_config() {
    local dir old new

    if ! command -v rsync &>/dev/null; then
        echo "⚠ rsync not available yet — skipping config/ migration (re-run install.sh after the package phase)"
        return 0
    fi

    for dir in "${MIGRATED_CONFIG_DIRS[@]}"; do
        old="${DOTFILES_ROOT}/${dir}"
        new="${DOTFILES_ROOT}/config/${dir}"

        # Nothing to do on a fresh clone or an already-migrated machine
        [[ -d "${old}" && ! -L "${old}" ]] || continue

        ensure_dir "${new}"
        # --ignore-existing never clobbers a tracked file with a stale copy from the old
        # tree; --remove-source-files unlinks ONLY what actually transferred, so anything
        # skipped survives at the old path and gets reported below instead of vanishing.
        rsync -a --ignore-existing --remove-source-files "${old}/" "${new}/"
        find "${old}" -depth -type d -empty -delete 2>/dev/null || true

        if [[ -d "${old}" ]]; then
            echo "⚠ ${old} still holds files that also exist under config/ — reconcile by hand:"
            find "${old}" -type f | sed 's|^|    |'
        else
            echo "✓ Migrated leftovers: ${dir}/ → config/${dir}/"
        fi
    done
}

#=======================================================================================
# Argument parsing
#=======================================================================================
SKIP_FONTS=false     # set by --skip-fonts to bypass font installation

while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -h|--help)
            cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Dotfiles Installation Script
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Installs and configures a development environment with:
  • Essential system packages (git, tmux, zsh, etc.)
  • Development tools via mise (Node.js, Python, Rust, Vim, etc.)
  • Claude Code (AI-powered coding assistant)
  • Dotfile symlinks (shell, vim, git, tmux configs)
  • Powerline fonts
  • ZSH configuration (zinit plugins, Powerlevel10k prompt)

USAGE:
  ./install.sh [OPTIONS]

OPTIONS:
  --skip-fonts  Skip Powerline/Nerd font installation
  -h, --help    Show this help message

EXAMPLES:
  # Standard installation
  ./install.sh

  # Test in Docker (Ubuntu 24.04)
  docker run -it --rm -v "$(pwd)":/root/.dotfiles ubuntu:24.04 bash
  cd /root/.dotfiles && ./install.sh

NOTES:
  • Script uses sudo for system operations (apt/pacman, chsh, fonts)
  • Development tools are installed via mise for easy version management
  • Run 'mise upgrade' to update all managed tools later
  • Existing configs are backed up to ~/.dotfiles/backup/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
            exit 0
            ;;
        --zsh)
            # Accepted for backwards compatibility (zsh is the only shell now)
            shift
            ;;
        --skip-fonts)
            SKIP_FONTS=true
            shift
            ;;
        *)
            echo "Unknown option: ${1}" >&2
            echo "Run './install.sh --help' for usage." >&2
            exit 1
            ;;
    esac
done
readonly SKIP_FONTS

#=======================================================================================
# Configuration
#=======================================================================================
readonly VIM_MIN_VERSION="9"
readonly DOTFILES_ROOT="${HOME}/.dotfiles"
readonly BACKUP_DIR="${DOTFILES_ROOT}/backup"
readonly FONTS_DIR="${DOTFILES_ROOT}/fonts"
export XDG_CONFIG_HOME="${HOME}/.config"
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"
export PASSWORD_STORE_DIR="${XDG_CONFIG_HOME}/password-store"
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"

# Package definitions
readonly -a DARWIN_PACKAGES=(
    git grep wget curl zsh fontconfig
    csvkit xclip htop p7zip rename unzip
    pdftk  # PDF manipulation tool
    glances ctags up pcre2-utils rsync
    coreutils gnu-sed  # GNU versions of macOS BSD tools
    autoconf automake libtool pkg-config  # Build dependencies
    openssl@3  # Library dependencies
    pass gnupg pinentry-mac  # Secret management
    # NOTE: Python, Node.js, Go, Rust, Vim, Yarn, and uv are installed via mise
)

readonly -a LINUX_PACKAGES=(
    build-essential git tmux htop curl wget zsh fonts-powerline
    xclip p7zip-full zip unzip
    pdftk-java  # PDF manipulation tool
    unrar wipe cmake exuberant-ctags rsync   # unrar: see LINUX_PACKAGE_ALTS
    libncurses-dev util-linux-extra pcre2-utils
    autoconf automake libtool pkg-config  # Build dependencies
    libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev  # Development libraries
    libbz2-dev libsqlite3-dev tk-dev liblzma-dev  # Python build dependencies (required for mise)
    python3-dev libpython3-dev  # Python dev headers (required for building vim with Python3 support)
    man-db less openssh-client software-properties-common  # Essential utilities
    strace gdb lsb-release shellcheck tree lsof ncdu  # Debugging & development tools
    earlyoom  # Kills the biggest consumer before RAM+swap exhaustion takes the box down
    pass gnupg2 pinentry-curses  # Secret management
		libx11-dev libxt-dev libxpm-dev libgtk-3-dev
    # NOTE: Python, Node.js, Go, Rust, Vim, Yarn, and uv are installed via mise
)

# Fallbacks for packages that aren't universally available. Ubuntu carries `unrar` in
# multiverse, but Debian ships it only in non-free — a main-only bookworm box has no
# candidate at all. `unrar-free` is in Debian main and handles classic RAR (not RAR5).
readonly -A LINUX_PACKAGE_ALTS=(
    [unrar]="unrar-free"
)

readonly -a ARCH_PACKAGES=(
    # Arch Linux equivalents of LINUX_PACKAGES (Manjaro/EndeavourOS share pacman).
    # base-devel already bundles autoconf/automake/libtool/pkgconf/make/gcc, but they
    # are listed explicitly for parity; --needed makes the duplicates harmless.
    base-devel git tmux htop curl wget zsh powerline-fonts
    xclip p7zip zip unzip
    unrar cmake ctags rsync
    ncurses util-linux pcre2
    autoconf automake libtool pkgconf
    openssl zlib libffi readline  # Library dependencies (Arch ships headers with the lib)
    bzip2 sqlite tk xz            # Python build dependencies (required for mise)
    python                        # Python + headers (required for building vim with Python3)
    man-db less openssh           # Essential utilities
    strace gdb lsb-release shellcheck tree lsof ncdu  # Debugging & development tools
    pass gnupg pinentry           # Secret management (gnupg provides gpg2, pinentry provides -curses)
    libx11 libxt libxpm gtk3
    # Not packaged in the official repos (AUR only): pdftk, wipe, software-properties-common
    # NOTE: Python, Node.js, Go, Rust, Vim, Yarn, and uv are installed via mise
)

# Symlink mappings
declare -A SHARED_LINKS=(
    [.vimrc]="${HOME}/.vimrc"
    [.vim]="${HOME}/.vim"
    [config/.aws]="${XDG_CONFIG_HOME:-${HOME}/.config}/.aws"
    [config/atuin]="${XDG_CONFIG_HOME:-${HOME}/.config}/atuin"
    [config/zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zsh"
    [config/ranger]="${XDG_CONFIG_HOME:-${HOME}/.config}/ranger"
    [config/sheldon]="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon"
    [config/ripgrep]="${XDG_CONFIG_HOME:-${HOME}/.config}/ripgrep"
    [config/kitty]="${XDG_CONFIG_HOME:-${HOME}/.config}/kitty"
    [config/broot]="${XDG_CONFIG_HOME:-${HOME}/.config}/broot"
    [config/alacritty]="${XDG_CONFIG_HOME:-${HOME}/.config}/alacritty"
    [config/tmux]="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux"
    [config/mise/config.toml]="${XDG_CONFIG_HOME:-${HOME}/.config}/mise/config.toml"
    [config/gh/config.yml]="${XDG_CONFIG_HOME:-${HOME}/.config}/gh/config.yml"
    [config/git/ignore]="${XDG_CONFIG_HOME:-${HOME}/.config}/git/ignore"
    [config/git/aliases.gitconfig]="${XDG_CONFIG_HOME:-${HOME}/.config}/git/aliases.gitconfig"
    [mimeapps.list]="${XDG_CONFIG_HOME:-${HOME}/.config}/mimeapps.list"
    [.Xresources]="${HOME}/.Xresources"
    [rc.sh]="${HOME}/.ssh/rc"
    [config/claude/commands]="${CLAUDE_CONFIG_DIR}/commands"
    [config/claude/agents]="${CLAUDE_CONFIG_DIR}/agents"
    [config/claude/skills]="${CLAUDE_CONFIG_DIR}/skills"
    [config/claude/CLAUDE.md]="${CLAUDE_CONFIG_DIR}/CLAUDE.md"
    [config/password-store]="${PASSWORD_STORE_DIR}"
    [scripts/memwatch]="${HOME}/.local/bin/memwatch"
)

# Directories that moved from the repo root into config/. Consumed by migrate_to_config to
# rescue untracked/gitignored leftovers on machines cloned before the move. This is exactly
# the set of link sources that land under ~/.config — keep it in sync with SHARED_LINKS and
# ZSH_LINKS above.
readonly -a MIGRATED_CONFIG_DIRS=(
    .aws alacritty atuin broot claude fzf gh git kitty mise
    password-store ranger ripgrep sheldon tmux zi zsh
)

declare -A ZSH_LINKS=(
    [config/zsh/.zshrc]="${HOME}/.zshrc"
    [config/zsh/.zshenv]="${HOME}/.zshenv"
    [config/zsh/.zprofile]="${HOME}/.zprofile"
    [config/zsh/.zlogin]="${HOME}/.zlogin"
    [config/zsh/.zlogout]="${HOME}/.zlogout"
    [config/fzf/fzf.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/fzf/fzf.zsh"
    [config/zi/init.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh"
)


#=======================================================================================
# Environment Detection & Initialization
#=======================================================================================

# Rescue leftovers from the pre-config/ layout BEFORE anything reads a repo path, so every
# step below — starting with the detect_os.sh source right after — sees the final layout.
[[ -d "${DOTFILES_ROOT}" ]] && migrate_to_config

# Source centralized POSIX-compatible OS detection
# Shared with .zshrc for consistency
if [[ ! -f "${DOTFILES_ROOT}/config/zsh/functions/detect_os.sh" ]]; then
    echo "ERROR: detect_os.sh not found at ${DOTFILES_ROOT}/config/zsh/functions/detect_os.sh"
    echo "Your dotfiles repository may be incomplete or corrupted"
    exit 1
fi

source "${DOTFILES_ROOT}/config/zsh/functions/detect_os.sh"
export LOCAL_CONFIG="${HOME}/.config"
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}"
export ZSH_CACHE_DIR="${ZSH}/cache"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export TERM=xterm-256color
export EDITOR=vim
export LESS="-XRF"

#=======================================================================================
# User Detection
#=======================================================================================

echo "Running as user: ${USER}"

#=======================================================================================
# Main Installation
#=======================================================================================

# Validate that dotfiles directory exists
if [[ ! -d "${DOTFILES_ROOT}" ]]; then
    echo "ERROR: ${DOTFILES_ROOT} does not exist"
    echo "Please clone your dotfiles repository first"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting dotfiles installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OS: ${HOST_OS} | Location: ${HOST_LOCATION}"
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing essential packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${HOST_OS}" == "darwin" ]]; then
    # Install Homebrew if needed
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Detect Homebrew installation path
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            brew_prefix="/opt/homebrew"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            brew_prefix="/usr/local"
        else
            echo "ERROR: Homebrew installation failed - brew binary not found"
            exit 1
        fi

        # Add Homebrew to shell profile if not already present
        if ! grep -q "brew shellenv" "${HOME}/.zprofile" 2>/dev/null; then
            {
                echo
                echo "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
            } >>"${HOME}/.zprofile"
        fi
        eval "$("${brew_prefix}"/bin/brew shellenv)"
    fi

    # Install packages (brew automatically skips already-installed packages)
    echo "Installing Homebrew packages..."
    failed_packages=()
    for pkg in "${DARWIN_PACKAGES[@]}"; do
        brew install "${pkg}" || failed_packages+=("${pkg}")
    done
    if (( ${#failed_packages[@]} > 0 )); then
        echo "WARNING: The following packages failed to install: ${failed_packages[*]}"
    fi
elif command -v pacman &>/dev/null; then
    # Arch Linux (and pacman-based derivatives: Manjaro, EndeavourOS, ...)
    echo "Detected pacman — installing Arch Linux packages..."
    # Refresh the keyring first so signature checks don't fail on long-idle systems.
    sudo pacman -Sy --noconfirm --needed archlinux-keyring 2>/dev/null || true
    # One transaction: sync DB + full upgrade + install. Arch does not support partial
    # upgrades, so we never `-Sy` then `-S` separately. --needed makes it idempotent.
    if ! sudo pacman -Syu --noconfirm --needed "${ARCH_PACKAGES[@]}"; then
        echo "WARNING: Batch install failed (likely one bad/AUR-only package) — retrying individually..."
        failed_packages=()
        for pkg in "${ARCH_PACKAGES[@]}"; do
            sudo pacman -S --noconfirm --needed "${pkg}" || failed_packages+=("${pkg}")
        done
        if (( ${#failed_packages[@]} > 0 )); then
            echo "WARNING: The following packages failed to install: ${failed_packages[*]}"
            echo "         (some may live in the AUR — install them with a helper, e.g. yay/paru)"
        fi
    fi
elif command -v apt-get &>/dev/null; then
    # Debian / Ubuntu
    export DEBIAN_FRONTEND=noninteractive
    export TZ=America/New_York

    # --allow-releaseinfo-change: accept benign repo metadata changes (Label/Origin)
    # unattended — signatures are still verified. Without it, a PPA renaming itself
    # hard-fails the whole install (e.g. ondrej/php in 2026).
    sudo apt-get -y update --allow-releaseinfo-change || { echo "ERROR: apt-get update failed"; exit 1; }
    # Install packages (apt automatically skips already-installed packages)
    echo "Installing Linux packages..."
    failed_packages=()
    for pkg in "${LINUX_PACKAGES[@]}"; do
        sudo apt-get install -y "${pkg}" && continue
        # Retry with the distro-specific fallback before declaring the package failed
        alt="${LINUX_PACKAGE_ALTS[${pkg}]:-}"
        if [[ -n "${alt}" ]]; then
            echo "  '${pkg}' unavailable on this distro — falling back to '${alt}'"
            sudo apt-get install -y "${alt}" && continue
        fi
        failed_packages+=("${pkg}")
    done
    if (( ${#failed_packages[@]} > 0 )); then
        echo "WARNING: The following packages failed to install: ${failed_packages[*]}"
    fi
else
    echo "WARNING: No supported package manager found (pacman/apt-get) — skipping system package installation"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Essential packages installed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NOTE: Development tools (Python, Node.js, Go, Rust, Vim, Yarn, uv) will be installed via mise"

#---------------------------------------------------------------------------------------
# Install Zinit
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Zinit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

zinit_home="${HOME}/.local/share/zinit/zinit.git"

if [[ ! -f "${zinit_home}/zinit.zsh" ]]; then
    ensure_dir "$(dirname "${zinit_home}")"
    git clone https://github.com/zdharma-continuum/zinit.git "${zinit_home}"
else
    echo "✓ Zinit already installed"
fi

#---------------------------------------------------------------------------------------
# Install mise and development tools
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing mise and development tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install mise
if ! command -v mise &>/dev/null; then
    echo "Installing mise to ${HOME}/.local/bin..."
    curl -fsSL https://mise.run | sh
else
    # A stale mise can't install current tool releases (e.g. python-build-standalone
    # layout changes), so keep the binary itself updated on reruns
    echo "✓ mise already installed — checking for updates..."
    mise self-update -y 2>/dev/null || echo "    (self-update unavailable — mise managed externally)"
fi

# Activate mise for the current script session
export PATH="${HOME}/.local/bin:${PATH}"

# The tracked mise config is the single source of truth for tool versions, so it has to be
# linked BEFORE anything installs. `mise use --global` would otherwise write a *real* file
# here on a fresh machine and the repo's pins (notably the concrete vim patch) would never
# apply — the bulk symlink pass runs much later and would only find, and back up, that
# generated file. Linking here also keeps install.sh from rewriting the tracked config.
link_dotfile "config/mise/config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"

echo "Installing development tools via mise (versions pinned in config/mise/config.toml)..."

# `mise install` skips already-installed tools, so this is idempotent and replaces the
# hand-rolled per-tool version comparison. Stderr is deliberately NOT suppressed: vim
# compiles from source here and swallowing its output made a multi-minute build look
# like a hang, then hid the error when it failed.
#
# The vim build flags (ASDF_VIM_CONFIG/LDFLAGS) used to be exported here and mirrored by
# a mise() wrapper in config/zsh/aliases.zsh. They now live in the [env] block of
# config/mise/config.toml — symlinked to ~/.config/mise/config.toml just above — so mise applies
# them to EVERY invocation instead of only the two that remembered to. Any other route to
# the compiler (a script, a non-interactive shell, `command mise`) silently built a
# -python3 vim and broke UltiSnips. See that file for the full rationale; do NOT re-add
# them here. The build now links against the system python3, so python3-dev from the apt
# phase above is what it needs, not a mise python installed first.
mise_install_failed=false
echo "  → Python, Node, Yarn, Rust, uv, Vim (compiled with Python3 support)..."
mise install || mise_install_failed=true

if [[ "${mise_install_failed}" == "true" ]]; then
    echo ""
    echo "⚠ ERROR: one or more mise tools failed to install (see the output above)."
    echo "         Re-run manually to see the full error:  mise install"
    echo "         Installation continues, but tools depending on them will be skipped."
fi

# Verify installations
echo ""
echo "Verifying mise installations..."
verify_tool "node" "node --version"
verify_tool "yarn" "yarn --version"
verify_tool "python" "python --version"
verify_tool "rustc" "rustc --version"
verify_tool "cargo" "cargo --version"
verify_tool "uv" "uv --version"
verify_tool "vim" "vim --version | head -1"

# Verify vim has Python3 support. Gated on `mise which vim`: without it, `mise exec` would
# try to auto-install the very tool that just failed, re-running a doomed build.
echo ""
if ! mise which vim &>/dev/null; then
    echo "⚠ WARNING: vim is not installed — skipping Python3 support check"
elif mise exec -- vim --version 2>/dev/null | grep -q '+python3'; then
    echo "✓ Vim has Python3 support enabled"
else
    echo "⚠ WARNING: Vim may not have Python3 support"
fi

echo ""
echo "To update all tools to latest versions, run:"
echo "  mise upgrade"

#---------------------------------------------------------------------------------------
# Install pynvim (Python package for Vim)
#---------------------------------------------------------------------------------------
echo "Installing pynvim for Vim..."
mise exec -- uv pip install --user pynvim 2>/dev/null || echo "  (skipping - may already be installed)"
mise exec -- python -c 'import pynvim' 2>/dev/null && echo "✓ pynvim installed" || echo "  (pynvim installation may need verification)"

#---------------------------------------------------------------------------------------
# Install Claude Code
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Claude Code"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v claude &>/dev/null || [[ -x "${HOME}/.local/bin/claude" ]]; then
    claude_version=$(claude --version 2>/dev/null || "${HOME}/.local/bin/claude" --version 2>/dev/null || echo "version unknown")
    echo "✓ Claude Code already installed (${claude_version})"
else
    echo "Installing Claude Code via native installer..."
    if curl -fsSL https://claude.ai/install.sh | bash; then
        # Verify installation
        if command -v claude &>/dev/null || [[ -x "${HOME}/.local/bin/claude" ]]; then
            claude_version=$(claude --version 2>/dev/null || "${HOME}/.local/bin/claude" --version 2>/dev/null || echo "version unknown")
            echo "✓ Claude Code installed (${claude_version})"
        else
            echo "⚠ Claude Code installed but not in PATH — add ~/.local/bin to PATH"
        fi
    else
        echo "⚠ Claude Code installation failed (network issue or unsupported platform)"
    fi
fi

# Configure zsh as the default shell (skip in containers - shell is pre-configured)
if [[ "${IS_DEVCONTAINER}" != "true" ]]; then
    target_shell_path="$(command -v zsh || true)"
    if [[ -n "${target_shell_path}" ]]; then
        if ! grep -qxF "${target_shell_path}" /etc/shells 2>/dev/null; then
            echo "${target_shell_path}" | sudo tee -a /etc/shells >/dev/null
        fi
        sudo chsh -s "${target_shell_path}" "${USER}" 2>/dev/null || true
        echo "✓ Default shell set to zsh"
    else
        echo "⚠ zsh not found on PATH - skipping default-shell change"
    fi
else
    echo "✓ Skipping shell change (container environment)"
fi

# Set clock (Linux only, skip in containers - no hardware clock access)
if [[ "${HOST_OS}" != "darwin" && "${IS_DEVCONTAINER}" != "true" ]]; then
    sudo hwclock --hctosys 2>/dev/null || true
fi

#---------------------------------------------------------------------------------------
# Install platform-specific tools (skip in containers)
#---------------------------------------------------------------------------------------
if [[ "${HOST_OS}" == "wsl" && "${IS_DEVCONTAINER}" != "true" ]] && ! command -v wslvar &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        echo "Installing wslu..."
        # Run in a subshell so a failure here doesn't abort the whole script (set -e)
        # wslu ships in the distro repos (Ubuntu universe / Debian) — no PPA needed
        (
            sudo apt-get install -y wslu
        ) || echo "⚠ wslu install failed — continuing (install manually with: sudo apt-get install wslu)"
    elif command -v pacman &>/dev/null; then
        # wslu is only in the AUR on Arch — install via a helper if one is present
        if command -v yay &>/dev/null; then
            yay -S --noconfirm --needed wslu || echo "⚠ wslu install failed (install manually from the AUR)"
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm --needed wslu || echo "⚠ wslu install failed (install manually from the AUR)"
        else
            echo "⚠ wslu is in the AUR but no helper (yay/paru) was found — install wslu manually"
        fi
    fi
fi

#---------------------------------------------------------------------------------------
# Install fonts (desktop Linux only)
#---------------------------------------------------------------------------------------
if [[ "${SKIP_FONTS}" != "true" && "${HOST_LOCATION}" == "desktop" && "${HOST_OS}" == "linux" ]]; then
    if [[ ! -f "${FONTS_DIR}/.installed" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Installing fonts"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        install_dir="${FONTS_DIR}/installations"
        ensure_dir "${install_dir}"

        # Extract all font archives
        for zipfile in "${FONTS_DIR}"/*.zip; do
            [[ -f "${zipfile}" ]] && unzip -qo "${zipfile}" -d "${install_dir}"
        done
        
        install_font_folder() {
            local directory="${1}"
            local font_directory="/usr/share/fonts"
            local last_folder
            local -a otf_files
            local -a ttf_files

            if [[ -z "${directory}" ]]; then
                echo "Error: No directory provided"
                return 1
            fi
            if [[ ! -d "${directory}" ]]; then
                echo "Error: Directory does not exist: ${directory}"
                return 1
            fi

            last_folder="$(basename "${directory}")"
            echo "Installing fonts from: ${directory}"

            ensure_dir_root "${font_directory}/opentype/${last_folder}" "${font_directory}/truetype/${last_folder}"

            shopt -s nullglob
            otf_files=("${directory}"/*.otf)
            ttf_files=("${directory}"/*.ttf)
            shopt -u nullglob

            if (( ${#otf_files[@]} > 0 )); then
                sudo cp -t "${font_directory}/opentype/${last_folder}/" -- "${otf_files[@]}" 2>/dev/null || true
            fi
            if (( ${#ttf_files[@]} > 0 )); then
                sudo cp -t "${font_directory}/truetype/${last_folder}/" -- "${ttf_files[@]}" 2>/dev/null || true
            fi

            if command -v fc-cache &>/dev/null; then
                echo "Updating font cache..."
                sudo fc-cache -f -v | grep -q "${last_folder}" && echo "✓ Fonts installed: ${last_folder}"
            fi
        }

        install_font_subdirectories() {
            local directory="${1}"
            local subdirectory

            if [[ -z "${directory}" ]]; then
                echo "Error: No directory provided"
                return 1
            fi
            if [[ ! -d "${directory}" ]]; then
                echo "Error: Directory does not exist: ${directory}"
                return 1
            fi

            for subdirectory in "${directory}"/*; do
                [[ -d "${subdirectory}" ]] || continue
                install_font_folder "${subdirectory}"
            done
        }

        install_font_subdirectories "${install_dir}"
        
        rm -rf "${install_dir}"
        touch "${FONTS_DIR}/.installed"
        echo "✓ Fonts installed"
    else
        echo "✓ Fonts already installed"
    fi
fi

#---------------------------------------------------------------------------------------
# Migrate legacy dotfile locations to XDG paths
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Migrating legacy paths to XDG locations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# config/zsh/.zshenv redirects these tools to XDG paths. Without moving the existing
# files, a machine pulling that change silently loses git identity, npm auth
# tokens, docker logins, GPG keyrings, etc. — the env var points at an empty
# location while the real data sits abandoned at the old path.
migrate_to_xdg() {
    local old="${1}" new="${2}"
    # Symlinked old paths belong to a previous symlink scheme — leave them alone
    [[ -L "${old}" || ! -e "${old}" ]] && return 0
    if [[ -e "${new}" ]]; then
        echo "⚠ Skipped ${old} — ${new} already exists, reconcile manually"
        return 0
    fi
    ensure_dir "$(dirname "${new}")"
    mv "${old}" "${new}"
    echo "✓ Migrated ${old} → ${new}"
}

migrate_to_xdg "${HOME}/.gitconfig"      "${XDG_CONFIG_HOME}/git/config"
migrate_to_xdg "${HOME}/.npmrc"          "${XDG_CONFIG_HOME}/npm/npmrc"
migrate_to_xdg "${HOME}/.npm"            "${XDG_CACHE_HOME:-${HOME}/.cache}/npm"
migrate_to_xdg "${HOME}/.docker"         "${XDG_CONFIG_HOME}/docker"
migrate_to_xdg "${HOME}/.wgetrc"         "${XDG_CONFIG_HOME}/wget/wgetrc"
migrate_to_xdg "${HOME}/.viminfo"        "${XDG_DATA_HOME:-${HOME}/.local/share}/vim/viminfo"
migrate_to_xdg "${HOME}/.vim/tmp/undo"   "${XDG_CACHE_HOME:-${HOME}/.cache}/vim/undo"
migrate_to_xdg "${HOME}/.vim/tmp/backup" "${XDG_CACHE_HOME:-${HOME}/.cache}/vim/backup"
migrate_to_xdg "${HOME}/.vim/tmp/swap"   "${XDG_CACHE_HOME:-${HOME}/.cache}/vim/swap"
migrate_to_xdg "${HOME}/.gnupg"          "${GNUPGHOME}"
migrate_to_xdg "${HOME}/.cargo"          "${XDG_CONFIG_HOME}/.cargo"
migrate_to_xdg "${HOME}/.rustup"         "${XDG_CONFIG_HOME}/.rustup"
migrate_to_xdg "${HOME}/go"              "${XDG_DATA_HOME:-${HOME}/.local/share}/go"

# npm config may carry a registry auth token — keep it private
[[ -f "${XDG_CONFIG_HOME}/npm/npmrc" ]] && chmod 600 "${XDG_CONFIG_HOME}/npm/npmrc"
# Remove the old vim tmp dir once its contents have moved
rmdir "${HOME}/.vim/tmp" 2>/dev/null || true

#---------------------------------------------------------------------------------------
# Create dotfile symlinks
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing dotfile symlinks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ensure_dir "${BACKUP_DIR}"
ensure_dir "${XDG_CONFIG_HOME}/zi"

# GPG requires strict permissions on its directory
if [[ ! -d "${GNUPGHOME}" ]]; then
    ensure_dir "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"
    echo "✓ Created GNUPGHOME at ${GNUPGHOME}"
fi

# wget aborts every invocation if WGETRC (set in config/zsh/.zshenv) points to a missing file
if [[ ! -f "${XDG_CONFIG_HOME}/wget/wgetrc" ]]; then
    ensure_dir "${XDG_CONFIG_HOME}/wget"
    touch "${XDG_CONFIG_HOME}/wget/wgetrc"
    echo "✓ Created empty wgetrc at ${XDG_CONFIG_HOME}/wget/wgetrc"
fi

# Compose the active link set: SHARED_LINKS plus ZSH_LINKS.
declare -A DOTFILE_LINKS=()
for source_path in "${!SHARED_LINKS[@]}"; do
    DOTFILE_LINKS["${source_path}"]="${SHARED_LINKS[${source_path}]}"
done
for source_path in "${!ZSH_LINKS[@]}"; do
    DOTFILE_LINKS["${source_path}"]="${ZSH_LINKS[${source_path}]}"
done

for source_path in "${!DOTFILE_LINKS[@]}"; do
    link_dotfile "${source_path}" "${DOTFILE_LINKS[${source_path}]}"
done

echo "✓ Dotfile symlinks installed"

#---------------------------------------------------------------------------------------
# Git aliases: portable aliases (diffplus/diffminus) ship as a TRACKED include, while
# identity stays in the per-machine, untracked ${XDG_CONFIG_HOME}/git/config. This block
# is idempotent and also migrates older machines that defined these aliases inline.
#---------------------------------------------------------------------------------------
git_config_file="${XDG_CONFIG_HOME}/git/config"
if [[ -f "${DOTFILES_ROOT}/config/git/aliases.gitconfig" ]]; then
    # Wire the include once (git config --add creates the file if it doesn't exist yet)
    if ! git config --file "${git_config_file}" --get-all include.path 2>/dev/null | grep -qx "aliases.gitconfig"; then
        git config --file "${git_config_file}" --add include.path "aliases.gitconfig"
        echo "✓ Linked tracked git aliases via include.path"
    fi
    # Drop any inline copies so the tracked include is the single source of truth
    git config --file "${git_config_file}" --unset-all alias.diffplus  2>/dev/null || true
    git config --file "${git_config_file}" --unset-all alias.diffminus 2>/dev/null || true
fi

#---------------------------------------------------------------------------------------
# Install Vim plugins
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Vim plugins"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check that vim itself installed before asking it to install plugins — otherwise
# `mise exec` would retry the failed vim build instead of reporting the real problem
if ! mise which vim &>/dev/null; then
    echo "WARNING: vim is not installed, skipping plugin installation"
elif [[ -f "${HOME}/.vim/autoload/plug.vim" ]] || [[ -f "${HOME}/.local/share/vim/autoload/plug.vim" ]]; then
    if mise exec -- vim -E -c PlugInstall -c qall!; then
        echo "✓ Vim plugins installed"
    else
        echo "WARNING: Vim plugin installation failed"
    fi
else
    echo "WARNING: vim-plug not found, skipping plugin installation"
fi

#---------------------------------------------------------------------------------------
# Configure WSL environment (skip in containers)
#---------------------------------------------------------------------------------------
if [[ "${HOST_OS}" == "wsl" && "${IS_DEVCONTAINER}" != "true" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Configuring WSL environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Setup Windows home
    if windows_profile="$(wslvar USERPROFILE 2>/dev/null)"; then
        if windows_home="$(wslpath "${windows_profile}" 2>/dev/null)"; then
            echo "Windows home: ${windows_home}"
            if [[ -f "${DOTFILES_ROOT}/.wslconfig" ]]; then
                cp "${DOTFILES_ROOT}/.wslconfig" "${windows_home}/.wslconfig"
                echo "✓ Copied .wslconfig"
            fi
        fi
    fi

    # Setup wsl.conf (idempotent: only if not exists)
    if [[ -f "${DOTFILES_ROOT}/wsl.conf" && ! -f "/etc/wsl.conf" ]]; then
        sudo cp "${DOTFILES_ROOT}/wsl.conf" /etc/wsl.conf
        echo "✓ Installed wsl.conf (run 'update-wsl-settings' to sync changes)"
    fi

    # Setup memwatch — records memory pressure so a WSL power-off (RAM+swap
    # exhaustion => 9p stall => reboot(RB_POWER_OFF)) leaves evidence behind.
    # A system unit, not --user: user@${UID}.service is unreliable under WSL.
    # Idempotent: only reinstalls when the rendered unit differs from what's live.
    if [[ -f "${DOTFILES_ROOT}/scripts/memwatch.service" ]] && (( $(id -u) != 0 )); then
        memwatch_unit="/etc/systemd/system/memwatch.service"
        memwatch_staged="$(mktemp)"
        # A system unit can't expand %h, so bake in the invoking user's path.
        sed "s|^ExecStart=.*|ExecStart=${HOME}/.local/bin/memwatch|" \
            "${DOTFILES_ROOT}/scripts/memwatch.service" >"${memwatch_staged}"

        if sudo cmp -s "${memwatch_staged}" "${memwatch_unit}" 2>/dev/null; then
            echo "✓ memwatch.service already current"
        else
            sudo cp "${memwatch_staged}" "${memwatch_unit}"
            sudo systemctl daemon-reload
            sudo systemctl enable --now memwatch.service
            echo "✓ Installed memwatch.service (logs: /var/log/memwatch/)"
        fi
        rm -f "${memwatch_staged}"
        unset memwatch_unit memwatch_staged
    fi

    # Tune earlyoom (installed via LINUX_PACKAGES). Without it nothing ever gets
    # OOM-killed here, so exhaustion escalates to a full VM power-off.
    if [[ -f "${DOTFILES_ROOT}/scripts/earlyoom.default" ]] && command -v earlyoom &>/dev/null; then
        if sudo cmp -s "${DOTFILES_ROOT}/scripts/earlyoom.default" /etc/default/earlyoom 2>/dev/null; then
            echo "✓ earlyoom config already current"
        else
            sudo cp "${DOTFILES_ROOT}/scripts/earlyoom.default" /etc/default/earlyoom
            sudo systemctl restart earlyoom
            echo "✓ Configured earlyoom"
        fi
    fi

    # Setup Windows Terminal
    if command -v powershell.exe &>/dev/null; then
        windows_user="$(powershell.exe '$env:UserName' 2>&1 | tr -d '\r\n')"
        
        if [[ -n "${windows_user}" && ! "${windows_user}" =~ ^[Ee]rror ]]; then
            settings_src="${DOTFILES_ROOT}/windows-terminal/settings.json"
            settings_dest="/mnt/c/Users/${windows_user}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"

            if [[ -f "${settings_src}" ]]; then
                # Backup original settings only if no backup exists
                if [[ -f "${settings_dest}" && ! -f "${settings_dest}.bak" ]]; then
                    cp "${settings_dest}" "${settings_dest}.bak"
                fi
                cp "${settings_src}" "${settings_dest}"
                echo "✓ Windows Terminal configured"
            fi
        fi
    fi
fi

#---------------------------------------------------------------------------------------
# Install git hooks
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing git hooks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

git_hooks_src="${DOTFILES_ROOT}/git-hooks"
git_hooks_dest="${DOTFILES_ROOT}/.git/hooks"

if [[ -d "${git_hooks_dest}" ]]; then
    for hook in "${git_hooks_src}"/*; do
        hook_name="$(basename "${hook}")"
        dest="${git_hooks_dest}/${hook_name}"
        if [[ "${HOST_OS}" == "darwin" ]]; then
            resolved_hook="$(readlink "${dest}" 2>/dev/null || echo "")"
        else
            resolved_hook="$(readlink -f "${dest}" 2>/dev/null || echo "")"
        fi
        if [[ -L "${dest}" && "${resolved_hook}" == "${hook}" ]]; then
            echo "✓ git hook already linked: ${hook_name}"
        else
            rel_hook="$(relative_path "${hook}" "$(dirname "${dest}")")"
            ln -nfs "${rel_hook}" "${dest}"
            echo "✓ git hook installed: ${hook_name}"
        fi
    done
else
    echo "⚠ .git/hooks directory not found — skipping git hooks"
fi

#---------------------------------------------------------------------------------------
# Done!
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"