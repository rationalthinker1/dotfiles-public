function subl --description 'Open a file in Windows Sublime Text from WSL'
    set -l loc "/mnt/c/Program Files/Sublime Text/subl.exe"
    if not test -f "$loc"
        set loc "/mnt/c/Program Files/Sublime Text 3/subl.exe"
    end
    set -l full (readlink -f "$argv[1]")
    set -l win (wslpath -m "$full")
    "$loc" "$win"
end
