function unzipd --description 'Unzip into a directory named after the archive'
    set -l filename $argv[1]
    set -l directory (string replace -r '\.zip$' '' -- "$filename")
    set directory (basename "$directory")
    unzip "$filename" -d "$directory"
end
