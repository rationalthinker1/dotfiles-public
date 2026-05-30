function wcsv --description 'Download a URL and preview the first N lines'
    set -l limit $argv[2]
    test -z "$limit"; and set limit 10
    wget "$argv[1]" -qO - | head -$limit
end
