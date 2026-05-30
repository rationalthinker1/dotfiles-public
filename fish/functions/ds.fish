function ds --description 'Top biggest directories'
    set -l limit $argv[1]
    test -z "$limit"; and set limit 50
    sudo du --human-readable --max-depth=1 --exclude /media 2>/dev/null \
        | sort -r -h | head -n(math $limit + 1)
end
