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
    csvkit xclip htop p7zip rename unzip
    glances ctags up pcre2-utils rsync
    coreutils gnu-sed  # GNU versions of macOS BSD tools
    autoconf automake libtool pkg-config  # Build dependencies
    openssl@3  # Library dependencies
    pass gnupg pinentry-mac  # Secret management
)

readonly -a LINUX_PACKAGES=(
    build-essential git tmux htop curl wget zsh fonts-powerline
    xclip p7zip-full zip unzip
    unrar wipe cmake exuberant-ctags rsync
    libncurses5-dev libncursesw5-dev util-linux-extra pcre2-utils
    autoconf automake libtool pkg-config  # Build dependencies
    libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev  # Development libraries
    libbz2-dev libsqlite3-dev tk-dev liblzma-dev  # Python build dependencies
    man-db less openssh-client software-properties-common  # Essential utilities
    strace gdb lsb-release shellcheck tree lsof ncdu  # Debugging & development tools
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
            echo "ERROR: Homebrew installation failed - brew binary not found"
            exit 1
        fi

        {
            echo
            echo "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
        } >>"${HOME}/.zprofile"
        eval "$(${brew_prefix}/bin/brew shellenv)"
    fi

    # Install packages (brew automatically skips already-installed packages)
    echo "Installing Homebrew packages..."
    brew install "${DARWIN_PACKAGES[@]}" || echo "WARNING: Some packages failed to install"
else
    # Linux package installation
    export DEBIAN_FRONTEND=noninteractive
    export TZ=America/New_York

    ${SUDO} apt-get -y update || { echo "ERROR: apt-get update failed"; exit 1; }
    ${SUDO} apt-get -y upgrade || echo "WARNING: Package upgrade had issues"

    # Install packages (apt automatically skips already-installed packages)
    echo "Installing Linux packages..."
    ${SUDO} apt-get install -y "${LINUX_PACKAGES[@]}" || echo "WARNING: Some packages failed to install"
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

# Add python plugin (ignore error if already exists)
asdf plugin add python 2>/dev/null || true

# Install latest Python 3 (skip if already installed)
asdf install python latest:3 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set python latest:3 --home 2>/dev/null || true

# Reshim to ensure python is available
asdf reshim python

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

# Add uv plugin (ignore error if already exists)
asdf plugin add uv 2>/dev/null || true

# Install latest uv (skip if already installed)
asdf install uv latest 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set uv latest --home 2>/dev/null || true

# Reshim to ensure uv is available
asdf reshim uv

# Verify installation
if ! uv --version; then
    echo "ERROR: uv not available after asdf installation"
    exit 1
fi

echo "✓ uv installed via asdf: $(uv --version)"

# Configure zsh as default shell
zsh_path=$(command -v zsh)
if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "${zsh_path}" | ${SUDO} tee -a /etc/shells >/dev/null
fi
# Change shell (use appropriate method based on privileges)
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    chsh -s "${zsh_path}" "${SUDO_USER:-$USER}" 2>/dev/null || true
else
    ${SUDO} chsh -s "${zsh_path}" "$USER" 2>/dev/null || true
fi
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

# Install Vim-specific build dependencies (asdf-vim builds from source)
# (build-essential, libncurses*, python3-dev, git already in LINUX_PACKAGES)
if [[ "${HOST_OS}" != "darwin" ]]; then
    ${SUDO} apt-get install -y ruby-dev lua5.3 liblua5.3-dev libperl-dev 2>/dev/null || true
fi

# Add vim plugin (ignore error if already exists)
asdf plugin add vim 2>/dev/null || true

# Configure Vim build options (Python3, Ruby, Lua, Perl support)
export ASDF_VIM_CONFIG="--with-features=huge --enable-rubyinterp=yes --enable-python3interp=yes --enable-perlinterp=yes --enable-luainterp=yes --enable-cscope --enable-fail-if-missing --disable-gui --without-x"

# Install latest Vim (asdf-vim builds from source, skip if already installed)
asdf install vim latest 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set vim latest --home 2>/dev/null || true

# Reshim to ensure vim is available
asdf reshim vim

# Verify installation
if ! vim --version | head -1; then
    echo "ERROR: Vim not available after asdf installation"
    exit 1
fi

echo "✓ Vim installed via asdf: $(vim --version | head -1)"

#---------------------------------------------------------------------------------------
# Install Rust via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Rust via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Add rust plugin (ignore error if already exists)
asdf plugin add rust 2>/dev/null || true

# Install latest stable Rust (asdf-rust uses standalone installers, not rustup, skip if already installed)
asdf install rust latest 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set rust latest --home 2>/dev/null || true

# Reshim to ensure cargo/rustc are available
asdf reshim rust

# Verify installation
if ! cargo --version; then
    echo "ERROR: Cargo not available after asdf installation"
    exit 1
fi

echo "✓ Rust installed via asdf: $(cargo --version)"

#---------------------------------------------------------------------------------------
# Install Go via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Go via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Add golang plugin (ignore error if already exists)
asdf plugin add golang 2>/dev/null || true

# Install latest Go (skip if already installed)
asdf install golang latest 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set golang latest --home 2>/dev/null || true

# Reshim to ensure go is available
asdf reshim golang

# Verify installation
if ! go version; then
    echo "ERROR: Go not available after asdf installation"
    exit 1
fi

echo "✓ Go installed via asdf: $(go version)"

#---------------------------------------------------------------------------------------
# Install Node.js via asdf
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Node.js via asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Add nodejs plugin (ignore error if already exists)
asdf plugin add nodejs 2>/dev/null || true

# Install latest Node.js LTS (skip if already installed)
asdf install nodejs lts 2>/dev/null || echo "  (skipping - may already be installed)"

# Set as global default
asdf set nodejs lts --home 2>/dev/null || true

# Reshim to ensure node/npm are available
asdf reshim nodejs

# Verify installation
if ! node --version; then
    echo "ERROR: Node.js not available after asdf installation"
    exit 1
fi

if ! npm --version; then
    echo "ERROR: npm not available after Node.js installation"
    exit 1
fi

echo "✓ Node.js installed via asdf: $(node --version)"
echo "✓ npm installed: $(npm --version)"

#---------------------------------------------------------------------------------------
# Install platform-specific tools
#---------------------------------------------------------------------------------------
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
        source "${DOTFILES_ROOT}/zsh/aliases.zsh" || true
        if command -v install-font-subdirectories &>/dev/null; then
            install-font-subdirectories "$install_dir"
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
        # Get resolved path (macOS-compatible)
        if [[ "$HOST_OS" == "darwin" ]]; then
            resolved_path="$(readlink "$target" 2>/dev/null || echo "")"
        else
            resolved_path="$(readlink -f "$target" 2>/dev/null || echo "")"
        fi
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

# Check if vim-plug is available before installing plugins
if [[ -f "${HOME}/.vim/autoload/plug.vim" ]] || [[ -f "${HOME}/.local/share/vim/autoload/plug.vim" ]]; then
    if vim -E -c PlugInstall -c qall!; then
        echo "✓ Vim plugins installed"
    else
        echo "WARNING: Vim plugin installation failed"
    fi
else
    echo "WARNING: vim-plug not found, skipping plugin installation"
fi

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
