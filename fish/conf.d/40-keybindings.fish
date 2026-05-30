# 40-keybindings.fish - Key bindings
# Fish defaults already cover most of the ZSH bindkey table: prefix history
# search (up/down arrows), Ctrl-A/E, Alt-arrow word motion, Ctrl-W kill-word,
# etc. fzf (Ctrl-T/Alt-C) and atuin (Ctrl-R) bind themselves in 20-tools.fish.
# Only the extras that aren't default are added here.

status is-interactive; or return

# Edit the current command line in $EDITOR (Ctrl-X Ctrl-E, like zsh)
bind \cx\ce edit_command_buffer
