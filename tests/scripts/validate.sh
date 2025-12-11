#!/usr/bin/env bash
set -euo pipefail

# Validation script for install.sh testing
# Checks all critical installation outcomes

TEST_TYPE="${1:-linux-server}"
PASS=0
FAIL=0

# Color output for readability
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_test() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"

    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name${details:+ - $details}"
        ((FAIL++))
    fi
}

# 1. Check Vim version >= 9
check_vim() {
    if command -v vim &>/dev/null; then
        local version=$(vim --version 2>/dev/null | awk 'NR==1 {print $5}')
        local major_version="${version%%.*}"
        if [[ -n "$major_version" && "$major_version" -ge 9 ]]; then
            log_test "Vim version >= 9" "PASS" "(v$version)"
        else
            log_test "Vim version >= 9" "FAIL" "version is $version"
        fi
    else
        log_test "Vim installed" "FAIL" "vim command not found"
    fi
}

# 2. Check Rust toolchain
check_rust() {
    if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
        local rust_version=$(rustc --version 2>/dev/null | awk '{print $2}')
        log_test "Rust toolchain installed" "PASS" "(v$rust_version)"
    else
        log_test "Rust toolchain installed" "FAIL" "rustc or cargo not found"
    fi
}

# 3. Check cargo packages (only broot now)
check_cargo_packages() {
    local packages=("broot")
    for pkg in "${packages[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            log_test "Cargo package: $pkg" "PASS"
        else
            log_test "Cargo package: $pkg" "FAIL" "not found in PATH"
        fi
    done
}

# 4. Check critical Linux packages
check_system_packages() {
    local packages=("zsh" "git" "tmux" "htop" "curl")
    for pkg in "${packages[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            log_test "System package: $pkg" "PASS"
        else
            log_test "System package: $pkg" "FAIL" "not found"
        fi
    done
}

# 5. Check symlinks (17 total)
check_symlinks() {
    local expected_links=(
        "$HOME/.zshrc"
        "$HOME/.zshenv"
        "$HOME/.vimrc"
        "$HOME/.vim"
        "$HOME/.gitconfig"
        "$HOME/.config/zsh"
        "$HOME/.config/ranger"
        "$HOME/.config/sheldon"
        "$HOME/.config/ripgrep"
        "$HOME/.config/kitty"
        "$HOME/.config/broot"
        "$HOME/.config/alacritty"
        "$HOME/.config/tmux"
        "$HOME/.config/fzf/fzf.zsh"
        "$HOME/.Xresources"
        "$HOME/.ssh/rc"
        "$HOME/.config/zi/init.zsh"
    )

    for link in "${expected_links[@]}"; do
        local link_name=$(basename "$link")
        if [[ -L "$link" ]]; then
            local target=$(readlink -f "$link" 2>/dev/null || echo "")
            if [[ "$target" =~ dotfiles ]]; then
                log_test "Symlink: $link_name" "PASS"
            else
                log_test "Symlink: $link_name" "FAIL" "points to wrong location: $target"
            fi
        elif [[ -e "$link" ]]; then
            log_test "Symlink: $link_name" "FAIL" "exists but is not a symlink"
        else
            log_test "Symlink: $link_name" "FAIL" "does not exist"
        fi
    done
}

# 6. Check log file exists and has success indicators
check_logs() {
    local log_file="$HOME/.dotfiles/install.log"

    if [[ -f "$log_file" ]]; then
        log_test "Install log exists" "PASS"

        # Check for error markers
        if grep -qi "\\[ERROR\\]" "$log_file"; then
            local error_count=$(grep -ci "\\[ERROR\\]" "$log_file")
            log_test "No errors in log" "FAIL" "$error_count ERROR entries found"
        else
            log_test "No errors in log" "PASS"
        fi

        # Check completion marker
        if grep -qi "Installation complete" "$log_file"; then
            log_test "Installation completed marker" "PASS"
        else
            log_test "Installation completed marker" "FAIL" "completion message not found in log"
        fi
    else
        log_test "Install log exists" "FAIL" "$log_file not found"
        # Skip dependent checks
        ((FAIL+=2))
        echo -e "${RED}✗ FAIL${NC}: No errors in log - log file missing"
        echo -e "${RED}✗ FAIL${NC}: Installation completed marker - log file missing"
    fi
}

# 7. Check Vim plugins installed
check_vim_plugins() {
    if [[ -d "$HOME/.vim/plugged" ]]; then
        local plugin_count=$(find "$HOME/.vim/plugged" -maxdepth 1 -type d 2>/dev/null | wc -l)
        # Subtract 1 for the plugged directory itself
        ((plugin_count--)) || true

        if [[ $plugin_count -gt 10 ]]; then
            log_test "Vim plugins installed" "PASS" "($plugin_count plugins found)"
        else
            log_test "Vim plugins installed" "FAIL" "only $plugin_count plugins found (expected >10)"
        fi
    else
        log_test "Vim plugins installed" "FAIL" "~/.vim/plugged directory not found"
    fi
}

# 8. Check backup directory created
check_backup() {
    if [[ -d "$HOME/.dotfiles/backup" ]]; then
        log_test "Backup directory exists" "PASS"
    else
        log_test "Backup directory exists" "FAIL" "~/.dotfiles/backup not found"
    fi
}

# 9. WSL-specific checks
check_wsl_specific() {
    if [[ "$TEST_TYPE" =~ wsl ]]; then
        # Check wslu installed
        if command -v wslvar &>/dev/null; then
            log_test "WSL: wslu package installed" "PASS"
        else
            log_test "WSL: wslu package installed" "FAIL" "wslvar command not found"
        fi
    fi
}

# 10. Desktop-specific checks (fonts)
check_desktop_specific() {
    if [[ "$TEST_TYPE" =~ desktop ]]; then
        if [[ -f "$HOME/.dotfiles/fonts/.installed" ]]; then
            log_test "Desktop: fonts installed marker" "PASS"
        else
            log_test "Desktop: fonts installed marker" "FAIL" "fonts/.installed marker not found"
        fi
    fi
}

# Main validation execution
main() {
    echo "=========================================="
    echo "Validation Test Suite"
    echo "Test Type: $TEST_TYPE"
    echo "=========================================="
    echo ""

    check_vim
    check_rust
    check_cargo_packages
    check_system_packages
    check_symlinks
    check_logs
    check_vim_plugins
    check_backup
    check_wsl_specific
    check_desktop_specific

    echo ""
    echo "=========================================="
    echo "Test Results: $PASS passed, $FAIL failed"
    echo "=========================================="

    # Exit with failure count (0 = success)
    exit $FAIL
}

main "$@"
