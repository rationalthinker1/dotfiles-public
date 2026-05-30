function extract --description 'Extract any archive type'
    if test (count $argv) -lt 1
        echo "Usage: extract <file>"
        return 1
    end
    set -l file $argv[1]
    if not test -f "$file"
        echo "File '$file' not found"
        return 1
    end
    switch "$file"
        case '*.tar.bz2'
            tar xjf "$file"
        case '*.tar.gz'
            tar xzf "$file"
        case '*.tar.xz'
            tar xJf "$file"
        case '*.tar.zst'
            tar --zstd -xf "$file" 2>/dev/null; or begin
                zstd -d "$file" | tar xf -
            end
        case '*.tar.lz4'
            lz4 -d "$file" | tar xf -
        case '*.bz2'
            bunzip2 "$file"
        case '*.rar'
            unrar x "$file"
        case '*.gz'
            gunzip "$file"
        case '*.tar'
            tar xf "$file"
        case '*.tbz2'
            tar xjf "$file"
        case '*.tgz'
            tar xzf "$file"
        case '*.zip'
            unzip "$file"
        case '*.Z'
            uncompress "$file"
        case '*.7z'
            7z x "$file"
        case '*.xz'
            unxz "$file"
        case '*.zst'
            unzstd "$file"
        case '*.lz4'
            unlz4 "$file"
        case '*'
            echo "Cannot extract '$file' - unknown format"
    end
end
