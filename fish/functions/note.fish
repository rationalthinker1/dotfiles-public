function note --description 'Quick note taking in ~/notes'
    set -l notes_dir "$HOME/notes"
    mkdir -p "$notes_dir"
    if test (count $argv) -eq 0
        echo "📝 Recent notes:"
        ls -lt "$notes_dir" | head -10
    else
        set -l note_file "$notes_dir/"(date +%Y-%m-%d)"-$argv[1].md"
        echo "# $argv[1]" >"$note_file"
        echo "" >>"$note_file"
        echo "Date: "(date) >>"$note_file"
        echo "" >>"$note_file"
        vim "$note_file"
    end
end
