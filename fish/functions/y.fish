function y --description 'yazi file manager; cd to the chosen dir on exit'
    if not command -q yazi
        echo "Error: requires 'yazi' to be installed." >&2
        return 1
    end
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    command yazi $argv --cwd-file="$tmp"
    set -l cwd (command cat -- "$tmp")
    if test -n "$cwd"; and test "$cwd" != "$PWD"
        cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
