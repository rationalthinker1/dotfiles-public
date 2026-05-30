# 05-plugins.fish - Fisher plugin loader
# ----------------------------------------------------------------------------
# ~/.config/fish is a symlink into the (version-controlled) dotfiles repo, so we
# redirect Fisher's install location to $XDG_DATA_HOME/fisher. That keeps plugin
# files (tide, autopair, ...) out of the repo, and we wire their function /
# completion / conf.d paths in here - per Fisher's documented custom-path setup.

set -q fisher_path; or set -gx fisher_path "$XDG_DATA_HOME/fisher"

if test -d "$fisher_path"
    set fish_complete_path $fish_complete_path[1] "$fisher_path/completions" $fish_complete_path[2..-1]
    set fish_function_path $fish_function_path[1] "$fisher_path/functions" $fish_function_path[2..-1]
    for file in "$fisher_path"/conf.d/*.fish
        test -f "$file"; and source "$file"
    end
end
