# 15-zinit-path.fish - expose zinit-installed CLI binaries to fish
# ----------------------------------------------------------------------------
# bat/eza/fd/rg/delta/zoxide/atuin/... are installed by zinit (as turbo command
# plugins) under $XDG_DATA_HOME/zinit/plugins/. zinit only adds those dirs to
# PATH inside zsh at runtime, so fish can't see the binaries. Here we add the
# plugin dirs that actually contain an executable, giving fish the same tools.
# (`./install.sh --fish` runs a one-time zsh session to populate these.)

status is-interactive; or return

set -l zp "$XDG_DATA_HOME/zinit/plugins"
test -d "$zp"; or return

# Binaries live either at the plugin root or one extracted subdir deeper.
for d in "$zp"/* "$zp"/*/*
    test -d "$d"; or continue
    for x in "$d"/*
        if test -f "$x"; and test -x "$x"
            fish_add_path --global --append "$d"
            break
        end
    end
end
