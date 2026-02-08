#!/usr/bin/env bash

set -euo pipefail

verify_tool() {
    local tool=$1
    local version_cmd=$2
    if mise which ${tool} &>/dev/null; then
        local version=$(mise exec -- ${version_cmd} 2>&1 | head -1)
        echo "✓ ${tool}: ${version}"
        return 0
    else
        echo "⚠ ${tool}: not found (may need manual verification)"
        return 1
    fi
}

#=======================================================================================
# Help
#=======================================================================================
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Dotfiles Installation Script
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Installs and configures development environment with:
  • Essential system packages (git, tmux, zsh, etc.)
  • Development tools via mise (Node.js, Python, Rust, Vim, etc.)
  • Dotfile symlinks (zsh, vim, git, tmux configs)
  • Powerline fonts
  • Shell configuration (zsh as default)

USAGE:
  ./install.sh [OPTIONS]

OPTIONS:
  -h, --help    Show this help message

EXAMPLES:
  # Standard installation
  ./install.sh

  # Test in Docker (Ubuntu 24.04)
  docker run -it --rm -v "$(pwd)":/root/.dotfiles ubuntu:24.04 bash
  cd /root/.dotfiles && ./install.sh

  # Test in Docker (Debian)
  docker run -it --rm -v "$(pwd)":/root/.dotfiles debian:latest bash
  cd /root/.dotfiles && ./install.sh

NOTES:
  • Script uses sudo for system operations (apt, chsh, fonts)
  • Development tools are installed via mise for easy version management
  • Run 'mise upgrade' to update all managed tools later
  • Existing configs are backed up to ~/.dotfiles/backup/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    exit 0
fi

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
    pdftk-java  # PDF manipulation tool
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
    unrar wipe cmake exuberant-ctags rsync
    libncurses5-dev libncursesw5-dev util-linux-extra pcre2-utils
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
    [.aws]="${XDG_CONFIG_HOME:-${HOME}/.config}/.aws"
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
# User Detection
#=======================================================================================

echo "Running as user: ${USER}"

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

        # Add Homebrew to shell profile if not already present
        if ! grep -q "brew shellenv" "${HOME}/.zprofile" 2>/dev/null; then
            {
                echo
                echo "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
            } >>"${HOME}/.zprofile"
        fi
        eval "$(${brew_prefix}/bin/brew shellenv)"
    fi

    # Install packages (brew automatically skips already-installed packages)
    echo "Installing Homebrew packages..."
    brew install "${DARWIN_PACKAGES[@]}" || echo "WARNING: Some packages failed to install"
else
    # Linux package installation
    export DEBIAN_FRONTEND=noninteractive
    export TZ=America/New_York

    sudo apt-get -y update || { echo "ERROR: apt-get update failed"; exit 1; }
    # Install packages (apt automatically skips already-installed packages)
    echo "Installing Linux packages..."
    sudo apt-get install -y "${LINUX_PACKAGES[@]}" || echo "WARNING: Some packages failed to install"
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

# Install development tools globally via mise
echo "Installing development tools via mise..."

# Node.js LTS
echo "  → Node.js LTS..."
mise use --global node@lts 2>/dev/null || echo "    (skipped - may already be installed)"

# Yarn (latest version 1.x - classic)
echo "  → Yarn 1.x (classic)..."
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

    if [[ -n "$current_vim_version" && -n "$latest_vim_version" ]]; then
        if [[ "$current_vim_version" != "$latest_vim_version" ]]; then
            echo "    Current: vim $current_vim_version, Latest: vim $latest_vim_version - upgrading..."
            should_install_vim=true
        else
            echo "    (skipped - vim $current_vim_version already installed, same major.minor as latest)"
        fi
    else
        # Can't determine versions, install to be safe
        should_install_vim=true
    fi
else
    echo "    Installing vim for the first time..."
    should_install_vim=true
fi

if [[ "$should_install_vim" == "true" ]]; then
    # Get mise Python paths (don't use 'mise exec' to avoid triggering vim installation)
    PYTHON_PREFIX=$(python3 -c "import sys; print(sys.prefix)" 2>/dev/null)
    PY3_FILE_LOCATION=$(which python3 2>/dev/null)

    if [[ -n "$PY3_FILE_LOCATION" && -n "$PYTHON_PREFIX" ]]; then
        # Embed Python library path into vim binary using rpath
        # This ensures vim can find Python libraries at runtime without needing LD_LIBRARY_PATH
        export LDFLAGS="-L${PYTHON_PREFIX}/lib -Wl,-rpath,${PYTHON_PREFIX}/lib ${LDFLAGS:-}"
        export ASDF_VIM_CONFIG="--with-tlib=ncurses --with-compiledby=mise --enable-multibyte --enable-cscope --enable-terminal --enable-python3interp --with-python3-command=$PY3_FILE_LOCATION --enable-fail-if-missing --enable-gui=no --without-x"
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

# Configure zsh as default shell
zsh_path=$(command -v zsh)
if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "${zsh_path}" | sudo tee -a /etc/shells >/dev/null
fi
sudo chsh -s "${zsh_path}" "$USER" 2>/dev/null || true
echo "✓ Default shell set to zsh"

# Set clock (Linux only)
if [[ "${HOST_OS}" != "darwin" ]]; then
    sudo hwclock --hctosys 2>/dev/null || true
fi

#---------------------------------------------------------------------------------------
# Install platform-specific tools
#---------------------------------------------------------------------------------------
if [[ "$HOST_OS" == "wsl" ]] && ! command -v wslvar &>/dev/null; then
    echo "Installing wslu from PPA..."
    # Add PPA only if not already present
    if ! grep -q "wslutilities/wslu" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        sudo add-apt-repository ppa:wslutilities/wslu -y
        sudo apt-get update -y
    fi
    sudo apt-get install -y wslu
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
                # Backup original settings only if no backup exists
                if [[ -f "$settings_dest" && ! -f "${settings_dest}.bak" ]]; then
                    cp "$settings_dest" "${settings_dest}.bak"
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