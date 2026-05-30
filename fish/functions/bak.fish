function bak --description 'Swap file with its .bak (or create .bak)'
    if test -z "$argv[1]"
        echo "Error: No file or folder name provided."
        return 1
    end
    set -l f $argv[1]
    if not test -e "$f"; and not test -e "$f.bak"
        echo "Error: Neither $f nor $f.bak exists."
        return 1
    end
    if test -e "$f"; and test -e "$f.bak"
        mv "$f" "$f.tmp"
        mv "$f.bak" "$f"
        mv "$f.tmp" "$f.bak"
        echo "Swapped $f and $f.bak"
    else if test -e "$f"
        mv "$f" "$f.bak"
        echo "Renamed $f to $f.bak"
    else if test -e "$f.bak"
        mv "$f.bak" "$f"
        echo "Renamed $f.bak to $f"
    end
end
