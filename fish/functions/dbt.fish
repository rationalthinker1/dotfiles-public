function dbt --description 'docker build from a directory with optional tags'
    if test (count $argv) -lt 1
        echo "Usage: dbt DIRNAME [TAGNAME ...]"
        return 1
    end
    set -l args $argv[1]
    set -e argv[1]
    if test (count $argv) -ge 1
        set args $args -t $argv
    end
    docker build $args
end
