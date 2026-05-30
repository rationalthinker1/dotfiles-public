function cat --description 'bat-powered cat in interactive terminals'
    if not status is-interactive; or not command -q bat; or not isatty stdout
        command cat $argv
        return
    end
    bat $argv
end
