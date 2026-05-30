function psg --description 'Show processes matching a pattern'
    if test (count $argv) -eq 0
        echo "Usage: psg <pattern>"
        return 1
    end
    ps aux | grep -v grep | grep -i -e "$argv"
end
