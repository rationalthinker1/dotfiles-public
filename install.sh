#!/usr/bin/env bash

set -euo pipefail

#=======================================================================================
# Configuration
#=======================================================================================
readonly VIM_MIN_VERSION="9"
# Detect actual user's home (handle sudo correctly)
if [[ -n "${SUDO_USER:-}" ]] && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    # Running with sudo: use the actual user's home, not root's
    ACTUAL_USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    readonly DOTFILES_ROOT="${ACTUAL_USER_HOME}/.dotfiles"
else
    readonly DOTFILES_ROOT="${HOME}/.dotfiles"
fi
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
    python3  # Python 3
    node  # Node.js (includes npm)
    go  # Go programming language
    vim  # Vim editor
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
    python3 python3-pip python3-venv python3-dev  # Python 3
    golang-go  # Go programming language
    vim vim-gtk3  # Vim 9.1+ with clipboard support
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
# Root Privilege Check
#=======================================================================================

# This script must run as root for system-wide installation
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: This script must be run as root"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Please run with sudo:"
    echo "  sudo ./install.sh"
    echo
    echo "Or run as root in Docker containers:"
    echo "  docker run -it -v ./:/root/.dotfiles ubuntu:24.04"
    echo
    exit 1
fi

echo "✓ Running as root"

# Detect actual user for file operations (when run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    ACTUAL_USER="${SUDO_USER}"
    ACTUAL_USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    echo "✓ Detected sudo user: ${ACTUAL_USER}"
else
    ACTUAL_USER="${USER}"
    ACTUAL_USER_HOME="${HOME}"
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

    apt-get -y update || { echo "ERROR: apt-get update failed"; exit 1; }
    apt-get -y upgrade || echo "WARNING: Package upgrade had issues"

    # Install packages (apt automatically skips already-installed packages)
    echo "Installing Linux packages..."
    apt-get install -y "${LINUX_PACKAGES[@]}" || echo "WARNING: Some packages failed to install"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Development tools installed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Python 3: $(python3 --version 2>&1)"
echo "✓ Go: $(go version 2>&1)"
echo "✓ Vim: $(vim --version 2>&1 | head -1)"

#---------------------------------------------------------------------------------------
# Install Zinit (as user, not root)
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Zinit for ${ACTUAL_USER}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

user_xdg_data_home="${ACTUAL_USER_HOME}/.local/share"
user_zinit_home="${user_xdg_data_home}/zinit/zinit.git"

if [[ ! -f "${user_zinit_home}/zinit.zsh" ]]; then
    sudo -u "${ACTUAL_USER}" mkdir -p "$(dirname "${user_zinit_home}")"
    sudo -u "${ACTUAL_USER}" git clone https://github.com/zdharma-continuum/zinit.git "${user_zinit_home}"
else
    echo "✓ Zinit already installed"
fi

#---------------------------------------------------------------------------------------
# Install mise for Node.js version management (as user, not root)
#---------------------------------------------------------------------------------------
if [[ "${HOST_OS}" != "darwin" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installing mise and Node.js LTS for ${ACTUAL_USER}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Install mise as the actual user (not root)
    if ! sudo -u "${ACTUAL_USER}" bash -c 'command -v mise' &>/dev/null; then
        echo "Installing mise to ${ACTUAL_USER_HOME}/.local/bin..."
        sudo -u "${ACTUAL_USER}" bash -c 'curl -fsSL https://mise.run | sh'
    else
        echo "✓ mise already installed"
    fi

    # Install Node.js LTS globally via mise (as user)
    echo "Installing Node.js LTS via mise..."
    sudo -u "${ACTUAL_USER}" bash -c "export PATH=\"${ACTUAL_USER_HOME}/.local/bin:\${PATH}\" && mise use --global node@lts"

    # Verify installation
    if sudo -u "${ACTUAL_USER}" bash -c "export PATH=\"${ACTUAL_USER_HOME}/.local/bin:\${PATH}\" && mise which node" &>/dev/null; then
        NODE_VERSION=$(sudo -u "${ACTUAL_USER}" bash -c "export PATH=\"${ACTUAL_USER_HOME}/.local/bin:\${PATH}\" && mise exec -- node --version" 2>&1)
        NPM_VERSION=$(sudo -u "${ACTUAL_USER}" bash -c "export PATH=\"${ACTUAL_USER_HOME}/.local/bin:\${PATH}\" && mise exec -- npm --version" 2>&1)
        echo "✓ Node.js: ${NODE_VERSION}"
        echo "✓ npm: ${NPM_VERSION}"
    else
        echo "⚠ Node.js installation via mise may need verification"
    fi
fi

#---------------------------------------------------------------------------------------
# Install pynvim (Python package for Vim)
#---------------------------------------------------------------------------------------
echo "Installing pynvim for Vim..."
sudo -u "${ACTUAL_USER}" -H python3 -m pip install --user pynvim 2>/dev/null || echo "  (skipping - may already be installed)"
sudo -u "${ACTUAL_USER}" -H python3 -c "import pynvim" 2>/dev/null || echo "  (pynvim installation may need verification)"
echo "✓ pynvim installed"

# Configure zsh as default shell
zsh_path=$(command -v zsh)
if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "${zsh_path}" | tee -a /etc/shells >/dev/null
fi
# Change shell (use appropriate method based on privileges)
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    chsh -s "${zsh_path}" "${SUDO_USER:-$USER}" 2>/dev/null || true
else
    chsh -s "${zsh_path}" "$USER" 2>/dev/null || true
fi
echo "✓ Default shell set to zsh"

# Set clock (Linux only)
if [[ "${HOST_OS}" != "darwin" ]]; then
    hwclock --hctosys 2>/dev/null || true
fi

#---------------------------------------------------------------------------------------
# Install platform-specific tools
#---------------------------------------------------------------------------------------
if [[ "$HOST_OS" == "wsl" ]] && ! command -v wslvar &>/dev/null; then
    echo "Installing wslu from PPA..."
    add-apt-repository ppa:wslutilities/wslu -y
    apt-get update -y
    apt-get install -y wslu
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

            mkdir -p "${font_directory}/opentype/${last_folder}" "${font_directory}/truetype/${last_folder}"

            shopt -s nullglob
            otf_files=("${directory}"/*.otf)
            ttf_files=("${directory}"/*.ttf)
            shopt -u nullglob

            if (( ${#otf_files[@]} > 0 )); then
                cp -t "${font_directory}/opentype/${last_folder}/" -- "${otf_files[@]}" 2>/dev/null || true
            fi
            if (( ${#ttf_files[@]} > 0 )); then
                cp -t "${font_directory}/truetype/${last_folder}/" -- "${ttf_files[@]}" 2>/dev/null || true
            fi

            if command -v fc-cache &>/dev/null; then
                echo "Updating font cache..."
                fc-cache -f -v | grep -q "${last_folder}" && echo "✓ Fonts installed: ${last_folder}"
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

   # Skip if target is already pointing to the source
    [[ -L "$target" && "$(readlink "$target")" == "$source" ]] && continue
    
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
    if windows_profile="$(wslvar USERPROFILE 2>/dev/null)"; then
        if windows_home="$(wslpath "$windows_profile" 2>/dev/null)"; then
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
# Done!
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
