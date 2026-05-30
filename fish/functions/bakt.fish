function bakt --description 'Copy file/folder with a timestamp suffix'
    if test -z "$argv[1]"
        echo "Error: No file or folder name provided."
        return 1
    end
    set -l f $argv[1]
    if not test -e "$f"
        echo "Error: $f does not exist."
        return 1
    end
    set -l timestamp (date +%S%M%H%d%m%Y)
    set -l target
    if test -d "$f"
        set target "$f"_"$timestamp"_backup
    else
        set -l base (string replace -r '\.[^.]*$' '' -- "$f")
        set -l ext (string match -rg '\.([^.]*)$' -- "$f")
        if test "$base" = "$f"
            set target "$f"_"$timestamp"_backup
        else
            set target "$base"_"$timestamp"_backup."$ext"
        end
    end
    cp -r "$f" "$target"
    echo "Copied $f to $target"
end
