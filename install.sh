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
    git grep wget curl zsh fontconfig python3
    csvkit xclip htop p7zip rename unzip xsel
    glances ctags up broot pcre2-utils rsync go
    coreutils gnu-sed  # GNU versions of macOS BSD tools
    autoconf automake libtool pkg-config  # Build dependencies
    openssl@3  # Library dependencies
    pipx  # Python application installer
)

readonly -a LINUX_PACKAGES=(
    build-essential git tmux htop curl zsh powerline fonts-powerline
    python3-venv python3-dev python3-pip python3-pynvim xclip p7zip-full zip unzip
    unrar wipe cmake net-tools xsel exuberant-ctags golang-go rsync
    libncurses5-dev libncursesw5-dev util-linux-extra pcre2-utils jq
    autoconf automake libtool pkg-config  # Build dependencies
    libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev  # Development libraries
    man-db less openssh-client software-properties-common  # Essential utilities
    strace gdb lsb-release shellcheck tree  # Debugging & development tools
    pipx  # Python application installer
)

# Symlink mappings
declare -A DOTFILE_LINKS=(
    [zsh/.zshrc]="${HOME}/.zshrc"
    [zsh/.zshenv]="${HOME}/.zshenv"
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

# Detect operating system
if [[ -f "/proc/sys/kernel/osrelease" ]] && [[ "$(</proc/sys/kernel/osrelease)" == *microsoft* ]]; then
    HOST_OS="wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
    HOST_OS="darwin"
else
    HOST_OS="linux"
fi

# Detect location (desktop vs server)
if [[ "$HOST_OS" == "darwin" ]] || (command -v dpkg-query &>/dev/null && dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed"); then
    HOST_LOCATION="desktop"
else
    HOST_LOCATION="server"
fi

# Get distribution codename (portable, no GNU grep -P)
if [[ -f /etc/os-release ]]; then
    CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | cut -d= -f2 || echo "unknown")
    elif command -v lsb_release &>/dev/null; then
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
else
    CODENAME="unknown"
fi

# Export environment variables
export HOST_OS HOST_LOCATION CODENAME
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
echo "OS: $HOST_OS | Location: $HOST_LOCATION | Codename: $CODENAME"
echo

#---------------------------------------------------------------------------------------
# Install essential packages
# Skipped if zsh is already installed (indicates packages are present)
#---------------------------------------------------------------------------------------
if ! command -v zsh &>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installing essential packages"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ "${HOST_OS}" == "darwin" ]]; then
        # Install Homebrew
        if ! command -v brew &>/dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            {
                echo
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
            } >>"${HOME}/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo "✓ Homebrew already installed"
        fi
        
        echo "Installing packages..."
        if ! brew install "${DARWIN_PACKAGES[@]}"; then
            echo "WARNING: Some Homebrew packages failed to install"
            echo "You may need to install them manually: brew install ${DARWIN_PACKAGES[*]}"
        fi
    else
        # Configure for non-interactive installation (prevents tzdata and other prompts)
        export DEBIAN_FRONTEND=noninteractive
        export TZ=America/New_York
        
        if ! sudo apt-get -y update; then
            echo "ERROR: Failed to update package lists"
            exit 1
        fi
        
        sudo apt-get -y upgrade || echo "WARNING: Package upgrade had issues"
        
        if ! sudo apt-get install -y "${LINUX_PACKAGES[@]}"; then
            echo "WARNING: Some packages failed to install"
            echo "Attempting to continue, but some features may not work"
        fi
    fi
    
    # Install pynvim (Python package for Vim)
    # python3-pynvim is in LINUX_PACKAGES, but verify it's available
    if ! python3 -c "import pynvim" 2>/dev/null; then
        if [[ "${HOST_OS}" == "darwin" ]]; then
            # macOS: use pip3 with --user (no system package available)
            pip3 install --user pynvim || echo "WARNING: Failed to install pynvim"
        else
            # Linux: should already be installed from LINUX_PACKAGES (python3-pynvim)
            # If not, fall back to pipx (should be installed from LINUX_PACKAGES)
            pipx ensurepath
            pipx install pynvim || echo "WARNING: Failed to install pynvim via pipx"
        fi
    else
        echo "✓ pynvim already installed"
    fi
    
    # Configure zsh as default shell
    zsh_path=$(command -v zsh)
    if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
        echo "${zsh_path}" | sudo tee -a /etc/shells >/dev/null
    fi
    sudo chsh -s "${zsh_path}" 2>/dev/null || true
    chsh -s "${zsh_path}" 2>/dev/null || true
    echo "✓ Default shell set to zsh"
    
    # Install zplug
    if [[ ! -d "${HOME}/.zplug" ]]; then
        echo "Installing zplug..."
        curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh || true
    fi
    
    # Set clock (Linux only)
    if [[ "${HOST_OS}" != "darwin" ]]; then
        sudo hwclock --hctosys 2>/dev/null || true
    fi
fi

#---------------------------------------------------------------------------------------
# Install Vim 9+
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Checking Vim version"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

need_vim_install=false

if ! command -v vim &>/dev/null; then
    need_vim_install=true
else
    current_version="$(vim --version 2>/dev/null | awk 'NR==1 {print $5}')"
    major_version="${current_version%%.*}"
    
    if [[ ! "$major_version" =~ ^[0-9]+$ ]]; then
        echo "WARNING: Cannot parse vim version '$current_version', rebuilding"
        need_vim_install=true
        elif (( major_version < VIM_MIN_VERSION )); then
        echo "Vim $current_version outdated, upgrading to ${VIM_MIN_VERSION}+"
        need_vim_install=true
    else
        echo "✓ Vim $current_version meets requirements (>= $VIM_MIN_VERSION)"
    fi
fi

if [[ "$need_vim_install" == "true" ]]; then
    echo "Building Vim ${VIM_MIN_VERSION}+ from source..."
    
    if ! command -v python3-config &>/dev/null; then
        echo "ERROR: python3-dev not found"
        echo "Install it with: sudo apt-get install python3-dev"
        exit 1
    fi
    
    py3_config="$(python3-config --configdir 2>&1)"
    if [[ ! -d "${py3_config}" ]]; then
        echo "ERROR: Invalid python3-config: ${py3_config}"
        exit 1
    fi
    
    # Cleanup function for failed builds
    cleanup_vim() {
        [[ -d vim ]] && rm -rf vim
    }
    trap cleanup_vim EXIT
    
    # Install Vim-specific build dependencies
    # (build-essential, libncurses*, python3-dev, git already in LINUX_PACKAGES)
    sudo apt-get install -y \
    ruby-dev lua5.3 liblua5.3-dev libperl-dev
    
    # Clone and build
    git clone --depth=1 https://github.com/vim/vim.git
    cd vim/src
    
    ./configure \
    --with-features=huge \
    --enable-multibyte \
    --enable-rubyinterp=yes \
    --enable-python3interp=yes \
    --enable-perlinterp=yes \
    --enable-luainterp=yes \
    --enable-cscope \
    --enable-fail-if-missing \
    --disable-gui \
    --without-x \
    --prefix=/usr/local \
    --with-tlib=ncurses \
    --with-python3-config-dir="${py3_config}"
    
    make -j"$(nproc)"
    sudo make install
    
    cd ../..
    rm -rf vim
    trap - EXIT  # Remove trap on success
    echo "✓ Vim ${VIM_MIN_VERSION}+ installed"
fi

#---------------------------------------------------------------------------------------
# Install Rust toolchain
#---------------------------------------------------------------------------------------
if ! command -v cargo &>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installing Rust toolchain"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Download rustup installer
    temp_rustup="/tmp/rustup-init-$$.sh"
    if ! curl https://sh.rustup.rs -sSf -o "$temp_rustup"; then
        echo "ERROR: Failed to download rustup installer"
        rm -f "$temp_rustup"
        exit 1
    fi
    
    # Run installer
    if ! RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup" \
    CARGO_HOME="${XDG_CONFIG_HOME}/.cargo" \
    sh "$temp_rustup" -y; then
        echo "ERROR: Rust installation failed"
        rm -f "$temp_rustup"
        exit 1
    fi
    rm -f "$temp_rustup"
    
    # Source cargo environment
    if [[ -f "${XDG_CONFIG_HOME}/.cargo/env" ]]; then
        source "${XDG_CONFIG_HOME}/.cargo/env"
    else
        echo "ERROR: Cargo environment file not found"
        exit 1
    fi
    
    # Verify cargo is now available
    if ! command -v cargo &>/dev/null; then
        echo "ERROR: Cargo not found after Rust installation"
        exit 1
    fi
    
    rustup install stable || echo "WARNING: Failed to install stable toolchain"
    rustup default stable || echo "WARNING: Failed to set default toolchain"
    
    echo "✓ Rust toolchain installed"
else
    echo "✓ Rust already installed (cargo found)"
fi

#---------------------------------------------------------------------------------------
# Install cargo packages
#---------------------------------------------------------------------------------------
if ! command -v broot &>/dev/null; then
    echo "Installing broot..."
    sudo apt install -y libxcb1-dev libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev 2>/dev/null || true
    cargo install broot --locked --features clipboard
fi

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
            sudo dpkg -i --force-overwrite "$temp_deb"
            rm -f "$temp_deb"
            echo "✓ blackhosts installed"
        fi
    else
        echo "✓ blackhosts already installed"
    fi
fi

if [[ "$HOST_OS" == "wsl" ]] && ! command -v wslvar &>/dev/null; then
    echo "Installing wslu from PPA..."
    sudo add-apt-repository ppa:wslutilities/wslu -y
    sudo apt-get update -y
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
    
    # Backup if target exists and is not a dotfiles symlink
    if [[ -e "$target" ]]; then
        if [[ ! -L "$target" ]] || [[ ! "$(readlink -f "$target" 2>/dev/null)" =~ dotfiles ]]; then
            if [[ -f "$target" || -d "$target" ]]; then
                rsync -a "$target" "${BACKUP_DIR}/" 2>/dev/null || true
                rm -rf "$target"
            fi
        fi
    fi
    
    # Create symlink
    ln -sf "$source" "$target"
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
# Done!
#---------------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
