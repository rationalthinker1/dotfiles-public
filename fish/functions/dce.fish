function dce --description 'docker compose exec as the current user'
    dc exec --user (id -u):(id -g) $argv
end
