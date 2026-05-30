function pa --description 'Docker-based Laravel artisan'
    dce php php -dxdebug.client_host=host.docker.internal artisan $argv
end
