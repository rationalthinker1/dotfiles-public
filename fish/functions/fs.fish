function fs --description 'Top biggest files'
    set -l limit $argv[1]
    test -z "$limit"; and set limit 50
    sudo du --count-links --all --human-readable --exclude /media 2>/dev/null \
        | grep -v -e '^.*K[[:space:]]' | sort -r -n | head -n$limit
end
