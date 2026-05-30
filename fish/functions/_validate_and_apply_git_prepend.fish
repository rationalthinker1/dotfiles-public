function _validate_and_apply_git_prepend --description 'Safely apply .git_cli_prepend, then run the command'
    set -l cmd $argv
    if test -f .git_cli_prepend
        set -l prepend (string trim <.git_cli_prepend)
        if string match -qr '^[a-zA-Z0-9_/-]+$' -- "$prepend"
            set cmd $prepend $cmd
        else
            set_color red
            echo "⚠️  Unsafe .git_cli_prepend detected (ignored): $prepend" >&2
            set_color normal
        end
    end
    $cmd
end
