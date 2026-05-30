function dcebr --description 'bash shell in a compose service as root'
    if test (count $argv) -lt 1
        echo "Usage: dcebr CONTAINER_ID"
        return 1
    end
    set -l script /bin/bash
    test -n "$argv[2]"; and set script $argv[2]
    dc exec --user root:root "$argv[1]" "$script"
end
