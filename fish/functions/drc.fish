function drc --description 'Remove all docker containers (with confirmation)'
    read -P "Remove ALL Docker containers? (y/n): " confirm
    if test "$confirm" != y
        echo "Cancelled"
        return 1
    end
    docker rm (docker ps -a -q)
end
