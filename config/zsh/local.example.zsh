#!/bin/zsh
# ==============================================================================
# Local Machine-Specific Configuration
# ==============================================================================
# This file is for machine-specific settings that should NOT be version controlled
# Copy this file to 'local.zsh' and customize for each machine

# ==============================================================================
# SSH Aliases (Example)
# ==============================================================================
alias eco="ssh -p 222 raza@178.156.136.67"
alias raza.codes="ssh -p 22 raza@134.122.46.182"
alias guhs="ssh -p 22 raza@5.161.239.206"

# ==============================================================================
# Project Shortcuts (Example)
# ==============================================================================
alias portal="cd ~/Projects/portal"

# ==============================================================================
# API Keys and Secrets
# ==============================================================================
# IMPORTANT: Keep your API keys here, NOT in .zshrc!
# This file should be in .gitignore to prevent credential exposure

# OpenAI API Key
# export OPENAI_API_KEY="your-key-here"

# AWS Credentials (if not using aws-vault)
# export AWS_ACCESS_KEY_ID="your-key-id"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"

# GitHub Token (for CLI operations)
# export GITHUB_TOKEN="your-github-token"

# Other API Keys
# export ANTHROPIC_API_KEY="your-anthropic-key"
# export GOOGLE_API_KEY="your-google-key"
