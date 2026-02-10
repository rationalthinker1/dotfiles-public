#!/usr/bin/env bash
# ==============================================================================
# Installation Script for Seedbox Bash Environment
# ==============================================================================
# Bash installation script for restricted seedbox
# ==============================================================================

set -e  # Exit on error

echo "==================================================================="
echo "Installing Bash configuration for restricted seedbox environment"
echo "==================================================================="

# Define HOME as / (seedbox constraint)
HOME_DIR=""  # Empty string so paths become /.oh-my-bash instead of //.oh-my-bash
OMB_DIR="/.oh-my-bash"
DOTFILES_DIR="/.dotfiles/dediseedbox"

# Check if oh-my-bash is already installed
if [ -d "$OMB_DIR" ]; then
    echo "✓ oh-my-bash already installed at $OMB_DIR"
else
    echo "Installing oh-my-bash..."
    git clone --depth=1 https://github.com/ohmybash/oh-my-bash.git "$OMB_DIR"
    echo "✓ oh-my-bash installed"
fi

# Backup existing .bashrc if it exists (only once)
if [ -f "/.bashrc" ] && [ ! -f "/.bashrc.backup" ]; then
    echo "Backing up existing .bashrc to .bashrc.backup..."
    cp "/.bashrc" "/.bashrc.backup"
fi

# Backup existing .bash_profile if it exists (only once)
if [ -f "/.bash_profile" ] && [ ! -f "/.bash_profile.backup" ]; then
    echo "Backing up existing .bash_profile to .bash_profile.backup..."
    cp "/.bash_profile" "/.bash_profile.backup"
fi

# Symlink configuration files (safe to run multiple times)
echo "Creating symlinks for configuration files..."
ln -nfs "${DOTFILES_DIR}/.bashrc" "/.bashrc"
ln -nfs "${DOTFILES_DIR}/.bash_profile" "/.bash_profile"
ln -nfs "${DOTFILES_DIR}/.inputrc" "/.inputrc"
echo "✓ Configuration files symlinked"

# Create /.config directory if it doesn't exist
if [ ! -d "/.config" ]; then
    echo "Creating /.config directory..."
    mkdir -p "/.config"
fi

# Symlink Starship configuration
if [ -f "${DOTFILES_DIR}/starship.toml" ]; then
    echo "Creating symlink for Starship configuration..."
    ln -nfs "${DOTFILES_DIR}/starship.toml" "/.config/starship.toml"
    echo "✓ Starship configuration symlinked"
fi

# Create custom directory for oh-my-bash and symlink custom files
echo "Setting up oh-my-bash custom directory..."
mkdir -p "${OMB_DIR}/custom"

# Symlink each custom .sh file individually
for custom_file in "${DOTFILES_DIR}/custom/"*.sh; do
    if [ -f "$custom_file" ]; then
        filename=$(basename "$custom_file")
        ln -nfs "$custom_file" "${OMB_DIR}/custom/${filename}"
    fi
done
echo "✓ oh-my-bash custom files symlinked"

# Optional: Install Node.js
echo ""
echo "==================================================================="
echo "Optional: Node.js Installation"
echo "==================================================================="

# Target version
TARGET_NODE_VERSION="v22.11.0"
TARGET_NODE_MAJOR=22

# Check if Node.js is already installed
CURRENT_NODE_VERSION=""
SHOULD_INSTALL=false

if command -v node >/dev/null 2>&1; then
    CURRENT_NODE_VERSION=$(node --version 2>/dev/null)
    CURRENT_NODE_MAJOR=$(echo "$CURRENT_NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')

    echo "Node.js found: ${CURRENT_NODE_VERSION}"

    # Compare major versions
    if [ "$CURRENT_NODE_MAJOR" -lt "$TARGET_NODE_MAJOR" ]; then
        echo "  Current version is older than ${TARGET_NODE_VERSION}"
        read -p "Upgrade to Node.js ${TARGET_NODE_VERSION}? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SHOULD_INSTALL=true
        fi
    else
        echo "✓ Node.js ${CURRENT_NODE_VERSION} is up to date"
    fi
else
    read -p "Install Node.js ${TARGET_NODE_VERSION}? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SHOULD_INSTALL=true
    fi
fi

if [ "$SHOULD_INSTALL" = true ]; then
    # Configuration
    NODE_ARCH="linux-x64"
    NODE_PACKAGE="node-${TARGET_NODE_VERSION}-${NODE_ARCH}"
    NODE_URL="https://nodejs.org/dist/${TARGET_NODE_VERSION}/${NODE_PACKAGE}.tar.xz"
    INSTALL_DIR="/.local"
    NODE_DIR="${INSTALL_DIR}/node"

    echo "Downloading Node.js ${TARGET_NODE_VERSION}..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${NODE_URL}" -o "/tmp/${NODE_PACKAGE}.tar.xz"
    else
        wget -q "${NODE_URL}" -O "/tmp/${NODE_PACKAGE}.tar.xz"
    fi

    echo "Extracting Node.js..."
    mkdir -p "${INSTALL_DIR}"
    # Remove old installation if exists
    [ -d "${NODE_DIR}" ] && rm -rf "${NODE_DIR}"
    tar -xJf "/tmp/${NODE_PACKAGE}.tar.xz" -C "${INSTALL_DIR}"
    mv "${INSTALL_DIR}/${NODE_PACKAGE}" "${NODE_DIR}"
    rm "/tmp/${NODE_PACKAGE}.tar.xz"

    # Configure npm prefix
    "${NODE_DIR}/bin/npm" config set prefix "${NODE_DIR}" 2>/dev/null || true

    echo "✓ Node.js ${TARGET_NODE_VERSION} installed to ${NODE_DIR}"
    echo "  Node version: $("${NODE_DIR}/bin/node" --version)"
    echo "  npm version: $("${NODE_DIR}/bin/npm" --version 2>/dev/null || echo 'run: source ~/.bashrc first')"
else
    echo "Skipping Node.js installation"
fi

# Optional: Install Portable CLI Tools
echo ""
echo "==================================================================="
echo "Optional: Portable CLI Tools Installation"
echo "==================================================================="
echo "Install modern CLI tools? (Uses /.local/bin)"
echo ""
read -p "Install tools? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "/.local/bin"
    export PATH="/.local/bin:${PATH}"

    # Category 1: Essential Modern CLI Tools
    echo ""
    echo "=== Essential Modern CLI Tools ==="

    # fzf - Fuzzy Finder
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Installing fzf (Fuzzy Finder)..."
        wget -q https://github.com/junegunn/fzf/releases/download/v0.56.3/fzf-0.56.3-linux_amd64.tar.gz
        tar -xzf fzf-0.56.3-linux_amd64.tar.gz -C /.local/bin/
        rm fzf-0.56.3-linux_amd64.tar.gz
        echo "✓ fzf installed ($(fzf --version 2>/dev/null | head -n1))"
    fi

    # ripgrep - Fast grep
    if ! command -v rg >/dev/null 2>&1; then
        echo "Installing ripgrep (Fast grep)..."
        wget -q https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz
        tar -xzf ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz
        cp ripgrep-14.1.1-x86_64-unknown-linux-musl/rg /.local/bin/
        rm -rf ripgrep-14.1.1-*
        echo "✓ ripgrep installed ($(rg --version 2>/dev/null | head -n1))"
    fi

    # fd - Fast find
    if ! command -v fd >/dev/null 2>&1; then
        echo "Installing fd (Fast find)..."
        wget -q https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-unknown-linux-musl.tar.gz
        tar -xzf fd-v10.2.0-x86_64-unknown-linux-musl.tar.gz
        cp fd-v10.2.0-x86_64-unknown-linux-musl/fd /.local/bin/
        rm -rf fd-v10.2.0-*
        echo "✓ fd installed ($(fd --version 2>/dev/null | head -n1))"
    fi

    # bat - Better cat
    if ! command -v bat >/dev/null 2>&1; then
        echo "Installing bat (Better cat)..."
        wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-x86_64-unknown-linux-musl.tar.gz
        tar -xzf bat-v0.24.0-x86_64-unknown-linux-musl.tar.gz
        cp bat-v0.24.0-x86_64-unknown-linux-musl/bat /.local/bin/
        rm -rf bat-v0.24.0-*
        echo "✓ bat installed ($(bat --version 2>/dev/null | head -n1))"
    fi

    # eza - Modern ls
    if ! command -v eza >/dev/null 2>&1; then
        echo "Installing eza (Modern ls)..."
        wget -q https://github.com/eza-community/eza/releases/download/v0.20.11/eza_x86_64-unknown-linux-musl.tar.gz
        tar -xzf eza_x86_64-unknown-linux-musl.tar.gz -C /.local/bin/
        rm eza_x86_64-unknown-linux-musl.tar.gz
        echo "✓ eza installed ($(eza --version 2>/dev/null | head -n1))"
    fi

    # atuin - Shell history sync
    if ! command -v atuin >/dev/null 2>&1; then
        echo "Installing atuin (Shell history)..."
        wget -q https://github.com/atuinsh/atuin/releases/download/v18.3.0/atuin-x86_64-unknown-linux-musl.tar.gz
        tar -xzf atuin-x86_64-unknown-linux-musl.tar.gz
        cp atuin-x86_64-unknown-linux-musl/atuin /.local/bin/
        chmod +x /.local/bin/atuin
        rm -rf atuin-*
        echo "✓ atuin installed ($(atuin --version 2>/dev/null | head -n1))"
    fi

    # starship - Cross-shell prompt (Rust-based, fast alternative to Powerlevel10k)
    if ! command -v starship >/dev/null 2>&1; then
        echo "Installing starship (Cross-shell prompt)..."
        wget -q https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz
        tar -xzf starship-x86_64-unknown-linux-musl.tar.gz -C /.local/bin/
        rm starship-x86_64-unknown-linux-musl.tar.gz
        echo "✓ starship installed ($(starship --version 2>/dev/null | head -n1))"
    fi

    # Category 2: Data Processing Tools
    echo ""
    echo "=== Data Processing Tools ==="

    # jq - JSON processor
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq (JSON processor)..."
        wget -q https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
        chmod +x jq-linux-amd64
        mv jq-linux-amd64 /.local/bin/jq
        echo "✓ jq installed ($(jq --version 2>/dev/null))"
    fi

    # yq - YAML processor
    if ! command -v yq >/dev/null 2>&1; then
        echo "Installing yq (YAML processor)..."
        wget -q https://github.com/mikefarah/yq/releases/download/v4.44.6/yq_linux_amd64
        chmod +x yq_linux_amd64
        mv yq_linux_amd64 /.local/bin/yq
        echo "✓ yq installed ($(yq --version 2>/dev/null | head -n1))"
    fi

    # sd - Find & replace
    if ! command -v sd >/dev/null 2>&1; then
        echo "Installing sd (Find & replace)..."
        wget -q https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-x86_64-unknown-linux-musl.tar.gz
        tar -xzf sd-v1.0.0-x86_64-unknown-linux-musl.tar.gz
        chmod +x sd-v1.0.0-x86_64-unknown-linux-musl/sd
        mv sd-v1.0.0-x86_64-unknown-linux-musl/sd /.local/bin/
        rm -rf sd-v1.0.0-*
        echo "✓ sd installed ($(sd --version 2>/dev/null | head -n1))"
    fi

    # Category 3: Git Tools
    echo ""
    echo "=== Git Tools ==="

    # delta - Better git diff
    if ! command -v delta >/dev/null 2>&1; then
        echo "Installing delta (Better git diff)..."
        wget -q https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
        tar -xzf delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
        cp delta-0.18.2-x86_64-unknown-linux-musl/delta /.local/bin/
        rm -rf delta-0.18.2-*
        echo "✓ delta installed ($(delta --version 2>/dev/null | head -n1))"
    fi

    # lazygit - Git TUI
    if ! command -v lazygit >/dev/null 2>&1; then
        echo "Installing lazygit (Git TUI)..."
        wget -q https://github.com/jesseduffield/lazygit/releases/download/v0.44.1/lazygit_0.44.1_Linux_x86_64.tar.gz
        tar -xzf lazygit_0.44.1_Linux_x86_64.tar.gz lazygit
        mv lazygit /.local/bin/
        rm lazygit_0.44.1_*
        echo "✓ lazygit installed ($(lazygit --version 2>/dev/null | head -n1))"
    fi

    # git-open
    if [ ! -f "/.local/bin/git-open" ]; then
        echo "Installing git-open..."
        wget -q https://raw.githubusercontent.com/paulirish/git-open/master/git-open
        chmod +x git-open
        mv git-open /.local/bin/
        echo "✓ git-open installed"
    fi

    # Category 4: File/Directory Tools
    echo ""
    echo "=== File/Directory Tools ==="

    # zoxide - Smart cd
    if ! command -v zoxide >/dev/null 2>&1; then
        echo "Installing zoxide (Smart cd)..."
        wget -q https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.6/zoxide-0.9.6-x86_64-unknown-linux-musl.tar.gz
        tar -xzf zoxide-0.9.6-x86_64-unknown-linux-musl.tar.gz
        chmod +x zoxide
        mv zoxide /.local/bin/
        rm zoxide-0.9.6-*
        echo "✓ zoxide installed ($(zoxide --version 2>/dev/null | head -n1))"
    fi

    # yazi - File manager TUI
    if ! command -v yazi >/dev/null 2>&1; then
        echo "Installing yazi (File manager)..."
        wget -q https://github.com/sxyazi/yazi/releases/download/v0.4.2/yazi-x86_64-unknown-linux-musl.zip
        unzip -q yazi-x86_64-unknown-linux-musl.zip
        chmod +x yazi-x86_64-unknown-linux-musl/yazi
        mv yazi-x86_64-unknown-linux-musl/yazi /.local/bin/
        rm -rf yazi-*
        echo "✓ yazi installed ($(yazi --version 2>/dev/null | head -n1))"
    fi

    # duf - Modern df
    if ! command -v duf >/dev/null 2>&1; then
        echo "Installing duf (Modern df)..."
        wget -q https://github.com/muesli/duf/releases/download/v0.8.1/duf_0.8.1_linux_x86_64.tar.gz
        tar -xzf duf_0.8.1_linux_x86_64.tar.gz
        chmod +x duf
        mv duf /.local/bin/
        rm duf_0.8.1_* LICENSE README.md
        echo "✓ duf installed ($(duf --version 2>/dev/null | head -n1))"
    fi

    # dust - Disk usage analyzer
    if ! command -v dust >/dev/null 2>&1; then
        echo "Installing dust (Disk usage)..."
        wget -q https://github.com/bootandy/dust/releases/download/v1.1.1/dust-v1.1.1-x86_64-unknown-linux-musl.tar.gz
        tar -xzf dust-v1.1.1-x86_64-unknown-linux-musl.tar.gz
        chmod +x dust-v1.1.1-x86_64-unknown-linux-musl/dust
        mv dust-v1.1.1-x86_64-unknown-linux-musl/dust /.local/bin/
        rm -rf dust-*
        echo "✓ dust installed ($(dust --version 2>/dev/null | head -n1))"
    fi

    # dua - Disk usage analyzer (alternative)
    if ! command -v dua >/dev/null 2>&1; then
        echo "Installing dua (Disk usage)..."
        wget -q https://github.com/Byron/dua-cli/releases/download/v2.29.4/dua-v2.29.4-x86_64-unknown-linux-musl.tar.gz
        tar -xzf dua-v2.29.4-x86_64-unknown-linux-musl.tar.gz
        chmod +x dua-v2.29.4-x86_64-unknown-linux-musl/dua
        mv dua-v2.29.4-x86_64-unknown-linux-musl/dua /.local/bin/
        rm -rf dua-*
        echo "✓ dua installed ($(dua --version 2>/dev/null | head -n1))"
    fi

    # erdtree - File tree visualizer
    if ! command -v erdtree >/dev/null 2>&1; then
        echo "Installing erdtree (File tree)..."
        wget -q https://github.com/solidiquis/erdtree/releases/download/v3.1.2/erdtree-v3.1.2-x86_64-unknown-linux-musl.tar.gz
        tar -xzf erdtree-v3.1.2-x86_64-unknown-linux-musl.tar.gz
        chmod +x erdtree
        mv erdtree /.local/bin/
        rm erdtree-v3.1.2-* LICENSE
        echo "✓ erdtree installed ($(erdtree --version 2>/dev/null | head -n1))"
    fi

    # ncdu - Interactive disk usage analyzer
    if ! command -v ncdu >/dev/null 2>&1; then
        echo "Installing ncdu (Disk usage analyzer)..."
        # Try to compile from source (requires build tools)
        if command -v make >/dev/null 2>&1 && command -v gcc >/dev/null 2>&1; then
            cd /tmp
            wget -q https://dev.yorhel.nl/download/ncdu-1.19.tar.gz
            tar -xzf ncdu-1.19.tar.gz
            cd ncdu-1.19
            ./configure --prefix=/.local >/dev/null 2>&1
            make >/dev/null 2>&1 && make install >/dev/null 2>&1
            cd /tmp
            rm -rf ncdu-1.19*
            if command -v ncdu >/dev/null 2>&1; then
                echo "✓ ncdu installed ($(ncdu --version 2>/dev/null | head -n1))"
            else
                echo "⚠ ncdu installation failed (build tools may be missing)"
            fi
        else
            echo "⚠ ncdu skipped (requires build tools: make, gcc)"
        fi
    fi

    # Category 5: Editors & Text Tools
    echo ""
    echo "=== Editors & Text Tools ==="

    # micro - Modern text editor
    if ! command -v micro >/dev/null 2>&1; then
        echo "Installing micro (Text editor)..."
        wget -q https://github.com/zyedidia/micro/releases/download/v2.0.15/micro-2.0.15-linux64.tar.gz
        tar -xzf micro-2.0.15-linux64.tar.gz
        cp micro-2.0.15/micro /.local/bin/
        rm -rf micro-2.0.15*
        echo "✓ micro installed ($(micro --version 2>/dev/null | head -n1))"
    fi

    # Category 6: Network & Analysis Tools
    echo ""
    echo "=== Network & Analysis Tools ==="

    # doggo - DNS client
    if ! command -v doggo >/dev/null 2>&1; then
        echo "Installing doggo (DNS client)..."
        wget -q https://github.com/mr-karan/doggo/releases/download/v1.0.5/doggo_1.0.5_linux_amd64.tar.gz
        tar -xzf doggo_1.0.5_linux_amd64.tar.gz
        chmod +x doggo
        mv doggo /.local/bin/
        rm doggo_* LICENSE README.md completions -rf
        echo "✓ doggo installed ($(doggo --version 2>/dev/null | head -n1))"
    fi

    # tokei - Code statistics
    if ! command -v tokei >/dev/null 2>&1; then
        echo "Installing tokei (Code stats)..."
        wget -q https://github.com/XAMPPRocky/tokei/releases/download/v13.0.0-alpha.5/tokei-x86_64-unknown-linux-musl.tar.gz
        tar -xzf tokei-x86_64-unknown-linux-musl.tar.gz
        chmod +x tokei
        mv tokei /.local/bin/
        rm tokei-*
        echo "✓ tokei installed ($(tokei --version 2>/dev/null | head -n1))"
    fi

    # Category 7: Additional Runtimes (Optional)
    echo ""
    echo "=== Additional Runtimes (Optional) ==="
    read -p "Install Go (Golang)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -d "/.local/go" ]; then
            echo "Downloading Go 1.23.5..."
            wget -q https://go.dev/dl/go1.23.5.linux-amd64.tar.gz
            tar -xzf go1.23.5.linux-amd64.tar.gz -C /.local/
            rm go1.23.5.linux-amd64.tar.gz

            # Add to env.sh if not already there
            if ! grep -q "/.local/go/bin" "${OMB_DIR}/custom/env.sh" 2>/dev/null; then
                echo '' >> "${OMB_DIR}/custom/env.sh"
                echo '# Go programming language' >> "${OMB_DIR}/custom/env.sh"
                echo '[[ -d "/.local/go/bin" ]] && export PATH="/.local/go/bin:${PATH}"' >> "${OMB_DIR}/custom/env.sh"
                echo '[[ -d "/.local/go/bin" ]] && export GOPATH="/.local/go"' >> "${OMB_DIR}/custom/env.sh"
            fi
            echo "✓ Go installed ($(/.local/go/bin/go version 2>/dev/null))"
        else
            echo "✓ Go already installed ($(/.local/go/bin/go version 2>/dev/null))"
        fi
    fi

    echo ""
    echo "✓ Portable tools installation complete!"
    echo "  Tools installed in: /.local/bin/"
    echo ""
else
    echo "Skipping portable tools installation"
fi

echo ""
echo "==================================================================="
echo "✓ Installation complete!"
echo ""
echo "To activate the new configuration, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or restart your shell session."
echo "==================================================================="
