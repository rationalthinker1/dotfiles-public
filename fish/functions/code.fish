function code --description 'Open a file/dir in Windows VS Code from WSL'
    set -l base "$WINDOWS_USER_PROFILE"
    test -z "$base"; and set base "/mnt/c/Users/$USER"
    set -l code_exe "$base/AppData/Local/Programs/Microsoft VS Code/Code.exe"
    if not test -x "$code_exe"
        echo "Error: VS Code not found at $code_exe" >&2
        return 1
    end
    "$code_exe" $argv
end
