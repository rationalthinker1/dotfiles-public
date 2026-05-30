function serve --description 'Quick HTTP server in the current directory'
    set -l port $argv[1]
    test -z "$port"; and set port 8000
    echo "🌐 Starting HTTP server on http://localhost:$port"
    python3 -m http.server "$port"
end
