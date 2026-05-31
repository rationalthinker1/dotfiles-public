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

#=======================================================================================
# Argument parsing
#=======================================================================================
TARGET_SHELL="zsh"   # default shell to install/configure; override with --fish
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
  • Essential system packages (git, tmux, zsh, fish, etc.)
  • Development tools via mise (Node.js, Python, Rust, Vim, etc.)
  • Claude Code (AI-powered coding assistant)
  • Dotfile symlinks (shell, vim, git, tmux configs)
  • Powerline fonts
  • Shell configuration (zsh by default, or fish with --fish)

USAGE:
  ./install.sh [OPTIONS]

OPTIONS:
  --zsh         Install and configure zsh as the default shell (default)
  --fish        Install and configure fish as the default shell
                (installs Fisher + the Tide prompt and sets fish as login shell)
  --skip-fonts  Skip Powerline/Nerd font installation
  -h, --help    Show this help message

EXAMPLES:
  # Standard installation (zsh)
  ./install.sh

  # Fish installation
  ./install.sh --fish

  # Test in Docker (Ubuntu 24.04)
  docker run -it --rm -v "$(pwd)":/root/.dotfiles ubuntu:24.04 bash
  cd /root/.dotfiles && ./install.sh --fish

NOTES:
  • Script uses sudo for system operations (apt/pacman, chsh, fonts)
  • Development tools are installed via mise for easy version management
  • Run 'mise upgrade' to update all managed tools later
  • Existing configs are backed up to ~/.dotfiles/backup/
  • --zsh and --fish are additive across runs (run both to set up both shells)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
            exit 0
            ;;
        --fish)
            TARGET_SHELL="fish"
            shift
            ;;
        --zsh)
            TARGET_SHELL="zsh"
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
readonly TARGET_SHELL SKIP_FONTS

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
    git grep wget curl zsh fish fontconfig
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
    build-essential git tmux htop curl wget zsh fish fonts-powerline
    xclip p7zip-full zip unzip
    pdftk-java  # PDF manipulation tool
    unrar wipe cmake exuberant-ctags rsync
    libncurses-dev util-linux-extra pcre2-utils
    autoconf automake libtool pkg-config  # Build dependencies
    libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev  # Development libraries
    libbz2-dev libsqlite3-dev tk-dev liblzma-dev  # Python build dependencies (required for mise)
    python3-dev libpython3-dev  # Python dev headers (required for building vim with Python3 support)
    man-db less openssh-client software-properties-common  # Essential utilities
    strace gdb lsb-release shellcheck tree lsof ncdu  # Debugging & development tools
    pass gnupg2 pinentry-curses  # Secret management
		libx11-dev libxt-dev libxpm-dev libgtk-3-dev
    # NOTE: Python, Node.js, Go, Rust, Vim, Yarn, and uv are installed via mise
)

readonly -a ARCH_PACKAGES=(
    # Arch Linux equivalents of LINUX_PACKAGES (Manjaro/EndeavourOS share pacman).
    # base-devel already bundles autoconf/automake/libtool/pkgconf/make/gcc, but they
    # are listed explicitly for parity; --needed makes the duplicates harmless.
    base-devel git tmux htop curl wget zsh fish powerline-fonts
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
#
# Links are split so `--zsh` and `--fish` install only their own shell config,
# while SHARED_LINKS (incl. the zsh/ directory, which carries the shared command
# references + detect_os.sh used by both shells) are always installed. The active
# set is composed in the symlink section based on ${TARGET_SHELL}.
declare -A SHARED_LINKS=(
    [.vimrc]="${HOME}/.vimrc"
    [.vim]="${HOME}/.vim"
    [.gitconfig]="${HOME}/.gitconfig"
    [.aws]="${XDG_CONFIG_HOME:-${HOME}/.config}/.aws"
    [zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zsh"
    [ranger]="${XDG_CONFIG_HOME:-${HOME}/.config}/ranger"
    [sheldon]="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon"
    [ripgrep]="${XDG_CONFIG_HOME:-${HOME}/.config}/ripgrep"
    [kitty]="${XDG_CONFIG_HOME:-${HOME}/.config}/kitty"
    [broot]="${XDG_CONFIG_HOME:-${HOME}/.config}/broot"
    [alacritty]="${XDG_CONFIG_HOME:-${HOME}/.config}/alacritty"
    [tmux]="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux"
    [.Xresources]="${HOME}/.Xresources"
    [rc.sh]="${HOME}/.ssh/rc"
    [claude/commands]="${CLAUDE_CONFIG_DIR}/commands"
    [password-store]="${PASSWORD_STORE_DIR}"
)

declare -A ZSH_LINKS=(
    [zsh/.zshrc]="${HOME}/.zshrc"
    [zsh/.zshenv]="${HOME}/.zshenv"
    [zsh/.zprofile]="${HOME}/.zprofile"
    [zsh/.zlogin]="${HOME}/.zlogin"
    [zsh/.zlogout]="${HOME}/.zlogout"
    [fzf/fzf.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/fzf/fzf.zsh"
    [zi/init.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh"
)

declare -A FISH_LINKS=(
    [fish]="${XDG_CONFIG_HOME:-${HOME}/.config}/fish"
)


#=======================================================================================
# Environment Detection & Initialization
#=======================================================================================

# Source centralized POSIX-compatible OS detection
# Shared with .zshrc for consistency
if [[ ! -f "${DOTFILES_ROOT}/zsh/functions/detect_os.sh" ]]; then
    echo "ERROR: detect_os.sh not found at ${DOTFILES_ROOT}/zsh/functions/detect_os.sh"
    echo "Your dotfiles repository may be incomplete or corrupted"
    exit 1
fi

source "${DOTFILES_ROOT}/zsh/functions/detect_os.sh"
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

    sudo apt-get -y update || { echo "ERROR: apt-get update failed"; exit 1; }
    # Install packages (apt automatically skips already-installed packages)
    echo "Installing Linux packages..."
    failed_packages=()
    for pkg in "${LINUX_PACKAGES[@]}"; do
        sudo apt-get install -y "${pkg}" || failed_packages+=("${pkg}")
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
    mkdir -p "$(dirname "${zinit_home}")"
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
    echo "✓ mise already installed"
fi

# Activate mise for the current script session
export PATH="${HOME}/.local/bin:${PATH}"

# Install development tools globally via mise
echo "Installing development tools via mise..."

# Node.js LTS
echo "  → Node.js LTS..."
mise use --global node@lts 2>/dev/null || echo "    (skipped - may already be installed)"

# Yarn (v1 - Classic)
echo "  → Yarn (v1 Classic)..."
mise use --global yarn@1 2>/dev/null || echo "    (skipped - may already be installed)"

# Python (latest stable)
echo "  → Python..."
mise use --global python@latest 2>/dev/null || echo "    (skipped - may already be installed)"

# Rust (latest stable)
echo "  → Rust..."
mise use --global rust@latest 2>/dev/null || echo "    (skipped - may already be installed)"

# uv (fast Python package installer)
echo "  → uv..."
mise use --global uv@latest 2>/dev/null || echo "    (skipped - may already be installed)"

# Vim (with Python3 support)
echo "  → Vim with Python3 support..."
# Check if vim should be installed/upgraded (only on major.minor version changes)
should_install_vim=false
if mise which vim &>/dev/null; then
    # Extract major.minor from current vim version (e.g., "9.1" from "9.1.2001")
    current_vim_version=$(mise exec -- vim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1)
    # Get major.minor from latest vim version
    latest_vim_version=$(mise latest vim 2>/dev/null | grep -oP '^\d+\.\d+' | head -1)

    if [[ -n "${current_vim_version}" && -n "${latest_vim_version}" ]]; then
        if [[ "${current_vim_version}" != "${latest_vim_version}" ]]; then
            echo "    Current: vim ${current_vim_version}, Latest: vim ${latest_vim_version} - upgrading..."
            should_install_vim=true
        else
            echo "    (skipped - vim ${current_vim_version} already installed, same major.minor as latest)"
        fi
    else
        # Can't determine versions - verify vim works before reinstalling
        if mise exec -- vim --version &>/dev/null; then
            echo "    (skipped - vim already installed and functional)"
            should_install_vim=false
        else
            echo "    Can't determine versions, installing to be safe..."
            should_install_vim=true
        fi
    fi
else
    echo "    Installing vim for the first time..."
    should_install_vim=true
fi

if [[ "${should_install_vim}" == "true" ]]; then
    # Get mise Python paths (don't use 'mise exec' to avoid triggering vim installation)
    PYTHON_PREFIX=$(mise exec -- python3 -c "import sys; print(sys.prefix)" 2>/dev/null)
    PY3_FILE_LOCATION=$(mise which python3 2>/dev/null)

    if [[ -n "${PY3_FILE_LOCATION}" && -n "${PYTHON_PREFIX}" ]]; then
        # Embed Python library path into vim binary using rpath
        # This ensures vim can find Python libraries at runtime without needing LD_LIBRARY_PATH
        export LDFLAGS="-L${PYTHON_PREFIX}/lib -Wl,-rpath,${PYTHON_PREFIX}/lib ${LDFLAGS:-}"
        export ASDF_VIM_CONFIG="--with-tlib=ncurses --with-compiledby=mise --enable-multibyte --enable-cscope --enable-terminal --enable-python3interp --with-python3-command=${PY3_FILE_LOCATION} --enable-fail-if-missing --enable-gui=no --without-x"
        mise use --global vim@latest 2>/dev/null || echo "    (installation failed)"
        # Unset to prevent triggering vim installation on subsequent mise commands
        unset ASDF_VIM_CONFIG LDFLAGS
    else
        echo "    WARNING: python3-config not found, vim may not have Python3 support"
        mise use --global vim@latest 2>/dev/null || echo "    (installation failed)"
    fi
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

# Verify vim has Python3 support
echo ""
if mise exec -- vim --version | grep -q '+python3'; then
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

# Configure the chosen shell as default (skip in containers - shell is pre-configured)
if [[ "${IS_DEVCONTAINER}" != "true" ]]; then
    target_shell_path="$(command -v "${TARGET_SHELL}" || true)"
    if [[ -n "${target_shell_path}" ]]; then
        if ! grep -qxF "${target_shell_path}" /etc/shells 2>/dev/null; then
            echo "${target_shell_path}" | sudo tee -a /etc/shells >/dev/null
        fi
        sudo chsh -s "${target_shell_path}" "${USER}" 2>/dev/null || true
        echo "✓ Default shell set to ${TARGET_SHELL}"
    else
        echo "⚠ ${TARGET_SHELL} not found on PATH - skipping default-shell change"
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
        echo "Installing wslu from PPA..."
        # Add PPA only if not already present
        if ! grep -q "wslutilities/wslu" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            sudo add-apt-repository ppa:wslutilities/wslu -y
            sudo apt-get update -y
        fi
        sudo apt-get install -y wslu
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
        mkdir -p "${install_dir}"

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

            sudo mkdir -p "${font_directory}/opentype/${last_folder}" "${font_directory}/truetype/${last_folder}"

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
# Create dotfile symlinks
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing dotfile symlinks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "${BACKUP_DIR}"
mkdir -p "${XDG_CONFIG_HOME}/zi"

# GPG requires strict permissions on its directory
if [[ ! -d "${GNUPGHOME}" ]]; then
    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"
    echo "✓ Created GNUPGHOME at ${GNUPGHOME}"
fi

# Compose the active link set: SHARED_LINKS always, plus the selected shell's.
# (Sets are additive across runs; running --zsh then --fish installs both.)
declare -A DOTFILE_LINKS=()
for source_path in "${!SHARED_LINKS[@]}"; do
    DOTFILE_LINKS["${source_path}"]="${SHARED_LINKS[${source_path}]}"
done
if [[ "${TARGET_SHELL}" == "fish" ]]; then
    for source_path in "${!FISH_LINKS[@]}"; do
        DOTFILE_LINKS["${source_path}"]="${FISH_LINKS[${source_path}]}"
    done
else
    for source_path in "${!ZSH_LINKS[@]}"; do
        DOTFILE_LINKS["${source_path}"]="${ZSH_LINKS[${source_path}]}"
    done
fi

for source_path in "${!DOTFILE_LINKS[@]}"; do
    dotfile_source="${DOTFILES_ROOT}/${source_path}"
    target="${DOTFILE_LINKS[${source_path}]}"

    # Skip if source doesn't exist in dotfiles (e.g. password-store not yet committed)
    [[ ! -e "${dotfile_source}" ]] && continue

    # Ensure parent directory exists (needed before computing relative path)
    mkdir -p "$(dirname "${target}")"

    # Compute relative symlink path so it works across different $HOME environments (host vs container)
    relative_source="$(relative_path "${dotfile_source}" "$(dirname "${target}")")"

    # Skip if target is already pointing to the correct relative source
    if [[ -L "${target}" ]]; then
        current="$(readlink "${target}")"
        [[ "${current}" == "${relative_source}" ]] && continue
    fi

    # Backup if target exists and is not a symlink to THIS dotfiles repo
    if [[ -e "${target}" ]]; then
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
done

echo "✓ Dotfile symlinks installed"

#---------------------------------------------------------------------------------------
# Fish: Fisher plugin manager + Tide prompt (only for --fish)
#---------------------------------------------------------------------------------------
# Runs after symlinks so ~/.config/fish/fish_plugins is in place for `fisher update`.
# CLI binaries (bat, eza, fd, rg, delta, zoxide, atuin, ...) are declared as zinit
# turbo plugins in zsh/.zshrc; the zsh bootstrap step below drives one headless zsh
# run so those tools get fetched and become available to fish too.
if [[ "${TARGET_SHELL}" == "fish" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Configuring fish (Fisher + Tide)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if command -v fish &>/dev/null; then
        # Install Fisher if missing (idempotent)
        if ! fish -c 'type -q fisher' 2>/dev/null; then
            echo "Installing Fisher..."
            fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' || true
        else
            echo "✓ Fisher already installed"
        fi

        # Install/update the plugins listed in ~/.config/fish/fish_plugins
        echo "Installing fish plugins (tide, autopair)..."
        fish -c 'fisher update' || true

        # Configure the Tide prompt non-interactively (only once)
        if fish -c 'type -q tide' 2>/dev/null && ! fish -c 'set -q tide_left_prompt_items' 2>/dev/null; then
            echo "Configuring Tide prompt..."
            fish -c 'tide configure --auto --style=Lean --prompt_colors="True color" --show_time="24-hour format" --lean_prompt_height="Two lines" --prompt_connection=Disconnected --prompt_spacing=Sparse --icons="Many icons" --transient=No' || true
        else
            echo "✓ Tide already configured"
        fi
    else
        echo "⚠ fish not found on PATH - skipping Fisher/Tide setup"
    fi

    #-----------------------------------------------------------------------------------
    # Bootstrap zinit-managed CLI tools so they are available to fish
    #-----------------------------------------------------------------------------------
    # bat/eza/fd/rg/delta/zoxide/atuin/... are turbo (`wait`) plugins that only fetch
    # when zsh runs. Feed a headless interactive zsh a series of no-op commands so its
    # precmd-driven turbo scheduler fires and installs them. ZDOTDIR points at the
    # shared, already-symlinked config; zsh itself stays installed but is not the
    # default shell.
    if command -v zsh &>/dev/null && [[ -f "${XDG_CONFIG_HOME}/zsh/.zshrc" ]]; then
        echo "Bootstrapping zinit-managed CLI tools via a one-time zsh run (may take a few minutes)..."
        # Each piped 'sleep 1' is a separate prompt cycle -> precmd -> scheduler tick,
        # letting the wait'0/1/2' plugins load. `|| true` since SIGPIPE/timeout are expected.
        yes 'sleep 1' | head -n 60 \
            | ZDOTDIR="${XDG_CONFIG_HOME}/zsh" timeout 600 zsh -i >/dev/null 2>&1 || true
        echo "✓ zinit tool bootstrap complete"
    fi
fi

#---------------------------------------------------------------------------------------
# Install Vim plugins
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Vim plugins"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if vim-plug is available before installing plugins
if [[ -f "${HOME}/.vim/autoload/plug.vim" ]] || [[ -f "${HOME}/.local/share/vim/autoload/plug.vim" ]]; then
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