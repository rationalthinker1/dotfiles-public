# config.fish - Fish entry point
# ----------------------------------------------------------------------------
# The real configuration is split into auto-sourced units:
#   conf.d/*.fish   environment, tool init, abbreviations, hooks, keybindings
#   functions/*.fish  lazily autoloaded functions (one per file)
# Fish sources conf.d/ before this file and functions/ on first use, so there
# is little to do here. This file is the place for anything that must run
# AFTER plugins (tide, etc.) have loaded.

status is-interactive; or return

# (intentionally empty - tide/fzf/atuin/zoxide wire themselves up in conf.d)
