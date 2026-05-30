#!/usr/bin/env bash
# ==============================================================================
# Script: Migrate Secrets to pass Password Manager
# ==============================================================================
# Usage: ./migrate_secrets_to_pass.sh
#
# This script helps migrate plaintext secrets from local.zsh to pass

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Migrate Secrets to pass Password Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Check if pass is installed
if ! command -v pass &>/dev/null; then
    echo "ERROR: pass is not installed"
    echo "Install with: sudo apt-get install pass gnupg2"
    exit 1
fi

# Check if GPG is installed
if ! command -v gpg &>/dev/null; then
    echo "ERROR: gpg is not installed"
    echo "Install with: sudo apt-get install gnupg2"
    exit 1
fi

# Check if password store is initialized
if [[ ! -d ~/.password-store ]] && [[ ! -d ~/.local/share/password-store ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 1: Initialize pass"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Check if user has GPG keys
    if ! gpg --list-keys 2>/dev/null | grep -q uid; then
        echo "No GPG keys found. Generating new GPG key..."
        echo "Please answer the following prompts:"
        echo
        gpg --full-generate-key
    fi

    echo
    echo "Available GPG keys:"
    gpg --list-keys | grep -A 1 uid
    echo
    read -p "Enter your GPG key ID or email: " gpg_id

    # Initialize pass
    pass init "$gpg_id"
    echo "✓ pass initialized with GPG key: $gpg_id"
    echo
fi

# Migrate OpenAI API key
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 2: Migrate OpenAI API Key"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

local_zsh="${HOME}/.config/zsh/local.zsh"

if [[ -f "$local_zsh" ]]; then
    # Extract OpenAI key
    openai_key=$(grep 'OPENAI_API_KEY=' "$local_zsh" 2>/dev/null | cut -d'"' -f2 || true)

    if [[ -n "$openai_key" ]]; then
        echo "Found OpenAI API key in local.zsh"
        read -p "Migrate to pass? (y/n) " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$openai_key" | pass insert -m openai/api_key
            echo "✓ OpenAI API key stored in pass"

            # Comment out the old key in local.zsh
            sed -i.bak 's/^export OPENAI_API_KEY=/#export OPENAI_API_KEY=/' "$local_zsh"
            echo "✓ Commented out key in local.zsh (backup saved as local.zsh.bak)"
            echo
            echo "To use the key from pass, add to ~/.config/zsh/.zshrc:"
            echo "  load_secret \"openai/api_key\" \"OPENAI_API_KEY\""
        fi
    else
        echo "No OpenAI API key found in local.zsh"
    fi
else
    echo "local.zsh not found at: $local_zsh"
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Migration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Useful pass commands:"
echo "  pass                     - List all passwords"
echo "  pass show openai/api_key - Show the OpenAI key"
echo "  pass insert github/token - Add a new secret"
echo "  pass edit openai/api_key - Edit existing secret"
echo "  pass rm openai/api_key   - Remove a secret"
echo
