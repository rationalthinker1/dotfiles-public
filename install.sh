#!/usr/bin/env bash

set -euo pipefail

#=======================================================================================
# Configuration
#=======================================================================================
readonly VIM_MIN_VERSION="9"
readonly DOTFILES_ROOT="${HOME}/.dotfiles"
readonly BACKUP_DIR="${DOTFILES_ROOT}/backup"
readonly FONTS_DIR="${DOTFILES_ROOT}/fonts"

# Package definitions
readonly -a DARWIN_PACKAGES=(
    git grep wget curl zsh fontconfig
    csvkit xclip htop p7zip rename unzip xsel
    glances ctags up pcre2-utils rsync
    coreutils gnu-sed  # GNU versions of macOS BSD tools
    autoconf automake libtool pkg-config  # Build dependencies
    openssl@3  # Library dependencies
    pass gnupg pinentry-mac  # Secret management
)

readonly -a LINUX_PACKAGES=(
    build-essential git tmux htop curl zsh fonts-powerline
    xclip p7zip-full zip unzip
    unrar wipe cmake net-tools xsel exuberant-ctags rsync
    libncurses5-dev libncursesw5-dev util-linux-extra pcre2-utils jq
    autoconf automake libtool pkg-config  # Build dependencies
    libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev  # Development libraries
    libbz2-dev libsqlite3-dev tk-dev liblzma-dev  # Python build dependencies
    man-db less openssh-client software-properties-common  # Essential utilities
    strace gdb lsb-release shellcheck tree  # Debugging & development tools
    pass gnupg2 pinentry-curses  # Secret management
)

# Symlink mappings
declare -A DOTFILE_LINKS=(
    [zsh/.zshrc]="${HOME}/.zshrc"
    [zsh/.zshenv]="${HOME}/.zshenv"
    [zsh/.zprofile]="${HOME}/.zprofile"
    [zsh/.zlogin]="${HOME}/.zlogin"
    [zsh/.zlogout]="${HOME}/.zlogout"
    [.vimrc]="${HOME}/.vimrc"
    [.vim]="${HOME}/.vim"
    [.gitconfig]="${HOME}/.gitconfig"
    [.tool-versions]="${HOME}/.tool-versions"
    [zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zsh"
    [ranger]="${XDG_CONFIG_HOME:-${HOME}/.config}/ranger"
    [sheldon]="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon"
    [ripgrep]="${XDG_CONFIG_HOME:-${HOME}/.config}/ripgrep"
    [kitty]="${XDG_CONFIG_HOME:-${HOME}/.config}/kitty"
    [broot]="${XDG_CONFIG_HOME:-${HOME}/.config}/broot"
    [alacritty]="${XDG_CONFIG_HOME:-${HOME}/.config}/alacritty"
    [tmux]="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux"
    [fzf/fzf.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/fzf/fzf.zsh"
    [.Xresources]="${HOME}/.Xresources"
    [rc.sh]="${HOME}/.ssh/rc"
    [zi/init.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh"
)


#=======================================================================================
# Environment Detection & Initialization
#=======================================================================================

# Source centralized POSIX-compatible OS detection
# Shared with .zshrc for consistency
if [[ -f "${DOTFILES_ROOT}/zsh/functions/detect_os.sh" ]]; then
    source "${DOTFILES_ROOT}/zsh/functions/detect_os.sh"
else
    # Fallback if detect_os.sh doesn't exist yet (first-time bootstrap)
    echo "WARNING: detect_os.sh not found, using inline detection"
    case "${OSTYPE}" in
        linux-gnu*)
            if [[ -f /proc/sys/kernel/osrelease ]] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
                HOST_OS="wsl"
            else
                HOST_OS="linux"
            fi
            ;;
        darwin*)
            HOST_OS="darwin"
            ;;
        *)
            HOST_OS="linux"
            ;;
    esac

    if [[ "${HOST_OS}" == "darwin" ]] || (command -v dpkg-query &>/dev/null && dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed"); then
        HOST_LOCATION="desktop"
    else
        HOST_LOCATION="server"
    fi

    export HOST_OS HOST_LOCATION
fi
export LOCAL_CONFIG="${HOME}/.config"
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}"
export ZSH_CACHE_DIR="${ZSH}/cache"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export NVM_DIR="${XDG_CONFIG_HOME}/.nvm"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export TERM=xterm-256color
export EDITOR=vim
export LESS="-XRF"

# Source profiles if they exist (allow failures to not break script)
[[ -f "${XDG_CONFIG_HOME}/zsh/.zprofile" ]] && source "${XDG_CONFIG_HOME}/zsh/.zprofile" || true
[[ -f "${HOME}/.zprofile" ]] && source "${HOME}/.zprofile" || true

#=======================================================================================
# Sudo/Root Detection
#=======================================================================================

# Determine if we need sudo (empty if running as root)
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    SUDO=""
    echo "✓ Running as root user"
else
    # Check if sudo is available
    if ! command -v sudo &>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ERROR: This script requires root privileges"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "You are not running as root and sudo is not available."
        echo
        echo "Please either:"
        echo "  1. Run as root:"
        echo "     sudo ./install.sh"
        echo
        echo "  2. For Docker containers, run without -u flag:"
        echo "     docker run -it -v ./:/home/ubuntu/.dotfiles ubuntu:24.04"
        echo
        echo "  3. Install sudo first (as root):"
        echo "     apt-get update && apt-get install -y sudo"
        echo "     usermod -aG sudo <your-username>"
        echo
        exit 1
    fi

    # Verify sudo works (won't prompt in containers with NOPASSWD)
    if ! sudo -n true 2>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ERROR: sudo requires authentication"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "sudo is available but requires a password."
        echo
        echo "Please either:"
        echo "  1. Run with sudo:"
        echo "     sudo ./install.sh"
        echo
        echo "  2. For Docker containers, run as root (without -u flag)"
        echo
        echo "  3. Configure passwordless sudo (run as root):"
        echo "     echo '<your-username> ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/<your-username>"
        echo
        exit 1
    fi

    SUDO="sudo"
    echo "✓ Running with sudo access"
fi

#=======================================================================================
# Main Installation
#=======================================================================================

# Validate that dotfiles directory exists
if [[ ! -d "$DOTFILES_ROOT" ]]; then
    echo "ERROR: $DOTFILES_ROOT does not exist"
    echo "Please clone your dotfiles repository first"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting dotfiles installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OS: $HOST_OS | Location: $HOST_LOCATION"
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
            brew_prefix="/opt/homebrew"
        fi

        {
            echo
            echo "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
        } >>"${HOME}/.zprofile"
        eval "$(${brew_prefix}/bin/brew shellenv)"
    fi

    # Install packages individually
    for pkg in "${DARWIN_PACKAGES[@]}"; do
        if ! brew list "${pkg}" &>/dev/null; then
            echo "Installing ${pkg}..."
            brew install "${pkg}" || echo "WARNING: Failed to install ${pkg}"
        else
            echo "✓ ${pkg} already installed"
        fi
    done
else
    # Linux package installation
    export DEBIAN_FRONTEND=noninteractive
    export TZ=America/New_York

    ${SUDO} apt-get -y update || { echo "ERROR: apt-get update failed"; exit 1; }
    ${SUDO} apt-get -y upgrade || echo "WARNING: Package upgrade had issues"

    # Install packages individually
    for pkg in "${LINUX_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -xq "${pkg}"; then
            echo "Installing ${pkg}..."
            ${SUDO} apt-get install -y "${pkg}" || echo "WARNING: Failed to install ${pkg}"
        else
            echo "✓ ${pkg} already installed"
        fi
    done
fi

#---------------------------------------------------------------------------------------
# Install asdf version manager
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing asdf version manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# XDG-compliant asdf installation (v0.16.0+ is a Go binary, not Bash scripts)
readonly ASDF_VERSION="v0.16.0"
export ASDF_DATA_DIR="${XDG_CONFIG_HOME}/asdf"
export ASDF_DIR="${ASDF_DATA_DIR}"

# Create necessary directories
mkdir -p "${ASDF_DATA_DIR}/bin"
mkdir -p "${ASDF_DATA_DIR}/shims"

# Detect OS and architecture for binary download
if [[ "$OSTYPE" == "darwin"* ]]; then
    ASDF_OS="darwin"
    if [[ "$(uname -m)" == "arm64" ]]; then
        ASDF_ARCH="arm64"
    else
        ASDF_ARCH="amd64"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ASDF_OS="linux"
    ASDF_ARCH="amd64"
else
    echo "ERROR: Unsupported OS: $OSTYPE"
    exit 1
fi

# Download asdf binary if not already installed
if [[ ! -f "${ASDF_DATA_DIR}/bin/asdf" ]]; then
    echo "Downloading asdf ${ASDF_VERSION} for ${ASDF_OS}-${ASDF_ARCH}..."

    ASDF_DOWNLOAD_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-${ASDF_OS}-${ASDF_ARCH}.tar.gz"
    ASDF_TEMP_DIR="$(mktemp -d)"

    if curl -fsSL "${ASDF_DOWNLOAD_URL}" -o "${ASDF_TEMP_DIR}/asdf.tar.gz"; then
        tar -xzf "${ASDF_TEMP_DIR}/asdf.tar.gz" -C "${ASDF_TEMP_DIR}"
        mv "${ASDF_TEMP_DIR}/asdf" "${ASDF_DATA_DIR}/bin/asdf"
        chmod +x "${ASDF_DATA_DIR}/bin/asdf"
        rm -rf "${ASDF_TEMP_DIR}"
        echo "✓ asdf ${ASDF_VERSION} installed"
    else
        echo "ERROR: Failed to download asdf binary from ${ASDF_DOWNLOAD_URL}"
        rm -rf "${ASDF_TEMP_DIR}"
        exit 1
    fi
else
    echo "✓ asdf binary found at ${ASDF_DATA_DIR}/bin/asdf"
fi

# Add asdf to PATH for this script
export PATH="${ASDF_DATA_DIR}/bin:${ASDF_DATA_DIR}/shims:${PATH}"

# Verify asdf is functional
if ! command -v asdf &>/dev/null; then
    echo "ERROR: asdf not found after installation"
    exit 1
fi

echo "asdf version: $(asdf --version)"

#---------------------------------------------------------------------------------------
# Install Python via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Python via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing Python installation
if command -v python3 &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/python3" ]]; then
    existing_python="$(command -v python3)"
    echo "⚠ Existing Python installation: ${existing_python}"
    echo "  asdf-managed Python will take precedence"
fi

# Add python plugin
if ! asdf plugin add python; then
    echo "ERROR: Failed to add python plugin"
    exit 1
fi

# Install latest Python 3
if ! asdf install python latest:3; then
    echo "ERROR: Failed to install Python"
    exit 1
fi

# Set as global default
asdf set python latest:3 --home

# Verify installation
if ! python3 --version; then
    echo "ERROR: Python not available after asdf installation"
    exit 1
fi

echo "✓ Python installed via asdf: $(python3 --version)"

#---------------------------------------------------------------------------------------
# Install pynvim (Python package for Vim)
#---------------------------------------------------------------------------------------
echo "Installing pynvim for Vim..."

# Use asdf-managed Python's pip
if ! python3 -m pip install --user pynvim; then
    echo "ERROR: pynvim installation failed"
    exit 1
fi

# Verify pynvim is available
if ! python3 -c "import pynvim" 2>/dev/null; then
    echo "ERROR: pynvim not importable after installation"
    exit 1
fi

echo "✓ pynvim installed"

#---------------------------------------------------------------------------------------
# Install uv (fast Python package and project manager)
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing uv via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing uv installation
if command -v uv &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/uv" ]]; then
    existing_uv="$(command -v uv)"
    echo "⚠ Existing uv installation: ${existing_uv}"
    echo "  asdf-managed uv will take precedence"
fi

# Add uv plugin
if ! asdf plugin add uv; then
    echo "WARNING: Failed to add uv plugin, skipping"
else
    # Install latest uv
    if ! asdf install uv latest; then
        echo "WARNING: Failed to install uv, skipping"
    else
        # Set as global default
        asdf set uv latest --home

        # Verify installation
        if uv --version; then
            echo "✓ uv installed via asdf: $(uv --version)"
        else
            echo "WARNING: uv not available after asdf installation"
        fi
    fi
fi

# Configure zsh as default shell
zsh_path=$(command -v zsh)
if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "${zsh_path}" | ${SUDO} tee -a /etc/shells >/dev/null
fi
${SUDO} chsh -s "${zsh_path}" 2>/dev/null || true
chsh -s "${zsh_path}" 2>/dev/null || true
echo "✓ Default shell set to zsh"

# Set clock (Linux only)
if [[ "${HOST_OS}" != "darwin" ]]; then
    ${SUDO} hwclock --hctosys 2>/dev/null || true
fi

#---------------------------------------------------------------------------------------
# Install Vim via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Vim via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing Vim installation
if command -v vim &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/vim" ]]; then
    existing_vim="$(command -v vim)"
    echo "⚠ Existing Vim installation: ${existing_vim}"
    echo "  asdf-managed Vim will take precedence"
fi

# Install Vim-specific build dependencies (asdf-vim builds from source)
# (build-essential, libncurses*, python3-dev, git already in LINUX_PACKAGES)
if [[ "${HOST_OS}" != "darwin" ]]; then
    ${SUDO} apt-get install -y ruby-dev lua5.3 liblua5.3-dev libperl-dev 2>/dev/null || true
fi

# Add vim plugin
if ! asdf plugin add vim; then
    echo "WARNING: Failed to add vim plugin, skipping"
else
    # Configure Vim build options (Python3, Ruby, Lua, Perl support)
    export ASDF_VIM_CONFIG="--with-features=huge --enable-multibyte --enable-rubyinterp=yes --enable-python3interp=yes --enable-perlinterp=yes --enable-luainterp=yes --enable-cscope --enable-fail-if-missing --disable-gui --without-x"

    # Install latest Vim (asdf-vim builds from source)
    if ! asdf install vim latest; then
        echo "WARNING: Failed to install Vim, skipping"
    else
        # Set as global default
        asdf set vim latest --home

        # Verify installation
        if vim --version | head -1; then
            echo "✓ Vim installed via asdf: $(vim --version | head -1)"
        else
            echo "WARNING: Vim not available after asdf installation"
        fi
    fi
fi

# NOTE: Old source-build installation preserved below for reference
# Commented out - Vim is now managed by asdf
#
# need_vim_install=false
#
# if ! command -v vim &>/dev/null; then
#     need_vim_install=true
# else
#     current_version="$(vim --version 2>/dev/null | awk 'NR==1 {print $5}')"
#     major_version="${current_version%%.*}"
#
#     if [[ ! "$major_version" =~ ^[0-9]+$ ]]; then
#         echo "WARNING: Cannot parse vim version ${current_version}, rebuilding"
#         need_vim_install=true
#         elif (( major_version < VIM_MIN_VERSION )); then
#         echo "Vim $current_version outdated, upgrading to ${VIM_MIN_VERSION}+"
#         need_vim_install=true
#     else
#         echo "✓ Vim $current_version meets requirements (>= $VIM_MIN_VERSION)"
#     fi
# fi
#
# if [[ "$need_vim_install" == "true" ]]; then
#     echo "Building Vim ${VIM_MIN_VERSION}+ from source..."
#
#     if ! command -v python3-config &>/dev/null; then
#         echo "ERROR: python3-dev not found"
#         echo "Install it with: sudo apt-get install python3-dev"
#         exit 1
#     fi
#
#     py3_config="$(python3-config --configdir 2>&1)"
#     if [[ ! -d "${py3_config}" ]]; then
#         echo "ERROR: Invalid python3-config: ${py3_config}"
#         exit 1
#     fi
#
#     # Cleanup function for failed builds
#     cleanup_vim() {
#         [[ -d vim ]] && rm -rf vim
#     }
#     trap cleanup_vim EXIT
#
#     # Install Vim-specific build dependencies
#     # (build-essential, libncurses*, python3-dev, git already in LINUX_PACKAGES)
#     sudo apt-get install -y \
#     ruby-dev lua5.3 liblua5.3-dev libperl-dev
#
#     # Clone with retry logic
#     max_retries=3
#     retry_count=0
#     while (( retry_count < max_retries )); do
#         if git clone --depth=1 https://github.com/vim/vim.git; then
#             break
#         fi
#         ((retry_count++))
#         if (( retry_count < max_retries )); then
#             echo "Clone failed, retrying (${retry_count}/${max_retries})..."
#             sleep 2
#         else
#             echo "ERROR: Failed to clone Vim repository after ${max_retries} attempts"
#             exit 1
#         fi
#     done
#
#     cd vim/src
#
#     ./configure \
#     --with-features=huge \
#     --enable-multibyte \
#     --enable-rubyinterp=yes \
#     --enable-python3interp=yes \
#     --enable-perlinterp=yes \
#     --enable-luainterp=yes \
#     --enable-cscope \
#     --enable-fail-if-missing \
#     --disable-gui \
#     --without-x \
#     --prefix=/usr/local \
#     --with-tlib=ncurses \
#     --with-python3-config-dir="${py3_config}"
#
#     # Cap parallel jobs to avoid OOM on low-memory systems (e.g., 1GB VPS)
#     nproc_count=$(nproc)
#     max_jobs=$((nproc_count < 4 ? nproc_count : 4))
#     make -j"${max_jobs}"
#     sudo make install
#
#     cd ../..
#     rm -rf vim
#     trap - EXIT  # Remove trap on success
#     echo "✓ Vim ${VIM_MIN_VERSION}+ installed"
# fi

#---------------------------------------------------------------------------------------
# Install Rust via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Rust via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing Rust installation
if command -v cargo &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/cargo" ]]; then
    existing_cargo="$(command -v cargo)"
    echo "⚠ Existing Rust installation: ${existing_cargo}"
    echo "  asdf-managed Rust will take precedence"
fi

# Add rust plugin
if ! asdf plugin add rust; then
    echo "WARNING: Failed to add rust plugin, skipping"
else
    # Install latest stable Rust (asdf-rust uses standalone installers, not rustup)
    if ! asdf install rust latest; then
        echo "WARNING: Failed to install Rust, skipping"
    else
        # Set as global default
        asdf set rust latest --home

        # Verify installation
        if cargo --version; then
            echo "✓ Rust installed via asdf: $(cargo --version)"
        else
            echo "WARNING: Cargo not available after asdf installation"
        fi
    fi
fi

# NOTE: Old rustup-based installation preserved below for reference
# Commented out - Rust is now managed by asdf
#
# if ! command -v cargo &>/dev/null; then
#     echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#     echo "  Installing Rust toolchain"
#     echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#
#     # Download rustup installer
#     temp_rustup="/tmp/rustup-init-$$.sh"
#     if ! curl https://sh.rustup.rs -sSf -o "$temp_rustup"; then
#         echo "ERROR: Failed to download rustup installer"
#         rm -f "$temp_rustup"
#         exit 1
#     fi
#
#     # Run installer
#     if ! RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup" \
#     CARGO_HOME="${XDG_CONFIG_HOME}/.cargo" \
#     sh "$temp_rustup" -y; then
#         echo "ERROR: Rust installation failed"
#         rm -f "$temp_rustup"
#         exit 1
#     fi
#     rm -f "$temp_rustup"
#
#     # Source cargo environment
#     if [[ -f "${XDG_CONFIG_HOME}/.cargo/env" ]]; then
#         source "${XDG_CONFIG_HOME}/.cargo/env"
#     else
#         echo "ERROR: Cargo environment file not found"
#         exit 1
#     fi
#
#     # Verify cargo is now available
#     if ! command -v cargo &>/dev/null; then
#         echo "ERROR: Cargo not found after Rust installation"
#         exit 1
#     fi
#
#     rustup install stable || echo "WARNING: Failed to install stable toolchain"
#     rustup default stable || echo "WARNING: Failed to set default toolchain"
#
#     echo "✓ Rust toolchain installed"
# else
#     echo "✓ Rust already installed (cargo found)"
# fi

#---------------------------------------------------------------------------------------
# Install Go via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Go via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing Go installation
if command -v go &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/go" ]]; then
    existing_go="$(command -v go)"
    echo "⚠ Existing Go installation: ${existing_go}"
    echo "  asdf-managed Go will take precedence"
fi

# Add golang plugin
if ! asdf plugin add golang; then
    echo "WARNING: Failed to add golang plugin, skipping"
else
    # Install latest Go
    if ! asdf install golang latest; then
        echo "WARNING: Failed to install Go, skipping"
    else
        # Set as global default
        asdf set golang latest --home

        # Verify installation
        if go version; then
            echo "✓ Go installed via asdf: $(go version)"
        else
            echo "WARNING: Go not available after asdf installation"
        fi
    fi
fi

#---------------------------------------------------------------------------------------
# Install Node.js via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Node.js via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing Node.js installation
if command -v node &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/node" ]]; then
    existing_node="$(command -v node)"
    echo "⚠ Existing Node.js installation: ${existing_node}"
    echo "  asdf-managed Node.js will take precedence"
fi

# Add nodejs plugin
if ! asdf plugin add nodejs; then
    echo "WARNING: Failed to add nodejs plugin, skipping"
else
    # Install latest Node.js LTS
    if ! asdf install nodejs lts; then
        echo "WARNING: Failed to install Node.js, skipping"
    else
        # Set as global default
        asdf set nodejs lts --home

        # Verify installation
        if node --version && npm --version; then
            echo "✓ Node.js installed via asdf: $(node --version)"
            echo "✓ npm installed: $(npm --version)"
        else
            echo "WARNING: Node.js not available after asdf installation"
        fi
    fi
fi

#---------------------------------------------------------------------------------------
# Install broot via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing broot via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for existing broot installation
if command -v broot &>/dev/null && [[ ! -f "${ASDF_DATA_DIR}/shims/broot" ]]; then
    existing_broot="$(command -v broot)"
    echo "⚠ Existing broot installation: ${existing_broot}"
    echo "  asdf-managed broot will take precedence"
fi

# Add broot plugin
if ! asdf plugin add broot https://github.com/cmur2/asdf-broot.git; then
    echo "WARNING: Failed to add broot plugin, skipping"
else
    # Install latest broot (uses pre-built binaries, no Rust compilation needed)
    if ! asdf install broot latest; then
        echo "WARNING: Failed to install broot, skipping"
    else
        # Set as global default
        asdf set broot latest --home

        # Verify installation
        if broot --version; then
            echo "✓ broot installed via asdf: $(broot --version)"
        else
            echo "WARNING: broot not available after asdf installation"
        fi
    fi
fi

# NOTE: Old cargo-based installation preserved below for reference
# Commented out - broot is now managed by asdf
#
# if ! command -v broot &>/dev/null; then
#     echo "Installing broot..."
#     sudo apt install -y libxcb1-dev libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev 2>/dev/null || true
#     cargo install broot --locked --features clipboard
# fi

#---------------------------------------------------------------------------------------
# Install platform-specific tools
#---------------------------------------------------------------------------------------
if [[ "$HOST_LOCATION" == "desktop" && "$HOST_OS" == "linux" ]]; then
    if ! command -v blackhosts &>/dev/null; then
        echo "Installing blackhosts..."
        # Find latest .deb release (excluding musl builds)
        url="$(curl -fsSL https://api.github.com/repos/Lateralus138/blackhosts/releases/latest | \
            jq -r '.assets[] | select(.name | contains("blackhosts.deb") and (contains("musl") | not)) | .browser_download_url' | \
        head -n 1)"
        
        if [[ -n "$url" ]]; then
            temp_deb="/tmp/${url##*/}"
            curl -fsSL -o "$temp_deb" "$url"
            ${SUDO} dpkg -i --force-overwrite "$temp_deb"
            rm -f "$temp_deb"
            echo "✓ blackhosts installed"
        fi
    else
        echo "✓ blackhosts already installed"
    fi
fi

if [[ "$HOST_OS" == "wsl" ]] && ! command -v wslvar &>/dev/null; then
    echo "Installing wslu from PPA..."
    ${SUDO} add-apt-repository ppa:wslutilities/wslu -y
    ${SUDO} apt-get update -y
    ${SUDO} apt-get install -y wslu
fi

#---------------------------------------------------------------------------------------
# Install fonts (desktop Linux only)
#---------------------------------------------------------------------------------------
if [[ "$HOST_LOCATION" == "desktop" && "$HOST_OS" == "linux" ]]; then
    if [[ ! -f "${FONTS_DIR}/.installed" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Installing fonts"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        install_dir="${FONTS_DIR}/installations"
        mkdir -p "$install_dir"
        
        # Extract all font archives
        for zipfile in "${FONTS_DIR}"/*.zip; do
            [[ -f "$zipfile" ]] && unzip -q "$zipfile" -d "$install_dir"
        done
        
        # Install fonts (source aliases with error handling)
        if [[ -f "${DOTFILES_ROOT}/zsh/aliases.zsh" ]]; then
            source "${DOTFILES_ROOT}/zsh/aliases.zsh" || true
            if command -v install-font-subdirectories &>/dev/null; then
                install-font-subdirectories "$install_dir"
            fi
        fi
        
        rm -rf "$install_dir"
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

mkdir -p "$BACKUP_DIR"
mkdir -p "${XDG_CONFIG_HOME}/zi"

for source_path in "${!DOTFILE_LINKS[@]}"; do
    source="${DOTFILES_ROOT}/${source_path}"
    target="${DOTFILE_LINKS[$source_path]}"
    
    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")"
    
    # Backup if target exists and is not a symlink to THIS dotfiles repo
    if [[ -e "$target" ]]; then
        resolved_path="$(readlink -f "$target" 2>/dev/null || echo "")"
        # Only skip if symlink points to our dotfiles directory
        if [[ ! -L "$target" ]] || [[ "${resolved_path}" != "${DOTFILES_ROOT}"/* ]]; then
            if [[ -f "$target" || -d "$target" ]]; then
                echo "  Backing up existing: ${target}"
                rsync -a "$target" "${BACKUP_DIR}/" 2>/dev/null || true
                rm -rf "$target"
            fi
        fi
    fi
    
    # Create symlink
    ln -nfs "$source" "$target"
done

echo "✓ Dotfile symlinks installed"

#---------------------------------------------------------------------------------------
# Install Vim plugins
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Vim plugins"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
vim -E -c PlugInstall -c qall! 2>/dev/null || echo "WARNING: Vim plugin installation failed"

#---------------------------------------------------------------------------------------
# Configure WSL environment
#---------------------------------------------------------------------------------------
if [[ "$HOST_OS" == "wsl" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Configuring WSL environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Setup Windows home
    if windows_profile="$(wslvar USERPROFILE 2>&1)"; then
        if windows_home="$(wslpath "$windows_profile" 2>&1)"; then
            echo "Windows home: $windows_home"
            if [[ -f "${DOTFILES_ROOT}/.wslconfig" ]]; then
                cp "${DOTFILES_ROOT}/.wslconfig" "${windows_home}/.wslconfig"
                echo "✓ Copied .wslconfig"
            fi
        fi
    fi
    
    # Setup Windows Terminal
    if command -v powershell.exe &>/dev/null; then
        windows_user="$(powershell.exe '$env:UserName' 2>&1 | tr -d '\r\n')"
        
        if [[ -n "$windows_user" && ! "$windows_user" =~ ^[Ee]rror ]]; then
            settings_src="${DOTFILES_ROOT}/windows-terminal/settings.json"
            settings_dest="/mnt/c/Users/$windows_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
            
            if [[ -f "$settings_src" ]]; then
                if [[ -f "$settings_dest" ]]; then
                    cp "$settings_dest" "${settings_dest}.bak.$(date +%s)"
                fi
                cp "$settings_src" "$settings_dest"
                echo "✓ Windows Terminal configured"
            fi
        fi
    fi
fi

#---------------------------------------------------------------------------------------
# Verify asdf-managed tools
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verifying asdf-managed tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# List installed plugins
echo "Installed asdf plugins:"
asdf plugin list

# List installed versions
echo ""
echo "Installed tool versions:"
asdf list

# Verify shims are in PATH
echo ""
echo "asdf shims directory: ${ASDF_DATA_DIR}/shims"
if [[ ":${PATH}:" == *":${ASDF_DATA_DIR}/shims:"* ]]; then
    echo "✓ asdf shims are in PATH"
else
    echo "⚠ asdf shims NOT in PATH (will be added by .zshrc)"
fi

# Reshim to ensure all executables are available
asdf reshim

echo "✓ asdf verification complete"

#---------------------------------------------------------------------------------------
# Done!
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
