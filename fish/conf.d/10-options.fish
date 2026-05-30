# 10-options.fish - Interactive shell behaviour
# Fish provides autosuggestions, syntax highlighting, completion, prefix history
# search (up-arrow), implicit cd (AUTO_CD), and directory stack out of the box,
# so most of the ZSH `setopt` block has no equivalent to port.

status is-interactive; or return

# Quiet startup (no fish greeting banner)
set -g fish_greeting ''
