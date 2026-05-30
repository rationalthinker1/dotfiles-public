function killp --description 'Kill a process picked via fzf'
    set -l pid (ps aux | fzf | awk '{print $2}')
    if test -n "$pid"
        read -P "Kill PID $pid with SIGKILL? (y/n): " confirm
        test "$confirm" = y; and kill -9 $pid
    end
end
