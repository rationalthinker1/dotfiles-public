# Dotfiles

Modern ZSH configuration with 40+ plugins, optimized for performance and cross-platform compatibility.

## System Requirements

**Supported Operating Systems:**
- Ubuntu 20.04+ / Debian 11+
- macOS 12+ (Monterey or later)
- WSL 2 with Ubuntu

**Required:**
- ZSH 5.8+
- Git 2.30+
- sudo/root access (for installation)

**Package Managers:**
- Linux: APT (Debian/Ubuntu)
- macOS: Homebrew (auto-installed)

**Note:** This configuration is optimized for Debian-based Linux distributions. Other distributions (Fedora, Arch, Alpine) may require manual package installation adjustments.

## Quick Start

```bash
# Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles

# Run installation (requires sudo)
cd ~/.dotfiles
sudo ./install.sh

# Restart shell
exec zsh
```

## Features

- ⚡ Powerlevel10k instant prompt
- 🔍 Fuzzy finding everywhere (fzf, fzf-tab)
- 🎨 Syntax highlighting and autosuggestions
- 📦 40+ modern CLI tools (bat, eza, ripgrep, lazygit, etc.)
- 🚀 Performance optimized (lazy loading, bytecode compilation)
- 🌍 Cross-platform (WSL, Ubuntu, macOS)
- 🔐 Secret management with `pass`

## Documentation

See individual configuration files for detailed documentation:
- `.zshenv` - Environment variables
- `.zshrc` - Interactive shell configuration
- `aliases.zsh` - Functions and aliases

## License

MIT
