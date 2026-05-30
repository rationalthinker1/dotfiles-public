# ==============================================================================
# Local Machine-Specific Configuration (Fish)
# ==============================================================================
# Machine-specific settings that should NOT be version controlled.
# Copy this file to 'local.fish' (gitignored) and customise per machine.
# It is sourced last, by conf.d/90-local.fish.

# ------------------------------------------------------------------------------
# SSH shortcuts (example)
# ------------------------------------------------------------------------------
# abbr -a eco 'ssh -p 222 user@host'
# abbr -a box 'ssh -p 22 user@1.2.3.4'

# ------------------------------------------------------------------------------
# Project shortcuts (example)
# ------------------------------------------------------------------------------
# abbr -a portal 'cd ~/Projects/portal'

# ------------------------------------------------------------------------------
# API keys and secrets
# ------------------------------------------------------------------------------
# IMPORTANT: keep secrets here (gitignored), never in version-controlled config.
# Prefer `pass` (password-store) where possible.
#
# set -gx OPENAI_API_KEY    "your-key-here"
# set -gx ANTHROPIC_API_KEY "your-key-here"
# set -gx GITHUB_TOKEN      "your-token-here"
