function dceb --description 'bash shell in a compose service as the current user'
    if test (count $argv) -lt 1
        echo "Usage: dceb CONTAINER_ID"
        return 1
    end
    set -l script /bin/bash
    test -n "$argv[2]"; and set script $argv[2]
    dc exec --user (id -u):(id -g) "$argv[1]" "$script"
end
