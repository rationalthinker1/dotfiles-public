function dstop --description 'Stop all docker containers (with confirmation)'
    read -P "Stop all Docker containers? (y/n): " confirm
    if test "$confirm" != y
        echo "Cancelled"
        return 1
    end
    docker stop (docker ps -a -q)
end
