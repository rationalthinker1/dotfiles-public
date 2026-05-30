function killport --description 'Kill the process listening on a port'
    if test (count $argv) -lt 1
        echo "Usage: killport <port>"
        echo "Example: killport 3000"
        return 1
    end
    set -l port $argv[1]
    set -l pid (lsof -ti:"$port")
    if test -n "$pid"
        read -P "Kill PID $pid on port $port with SIGKILL? (y/n): " confirm
        if test "$confirm" = y
            echo "🔫 Killing process $pid on port $port..."
            kill -9 $pid
            echo "✓ Process killed"
        else
            echo "❌ Cancelled"
        end
    else
        echo "❌ No process found on port $port"
    end
end
