function dbu --description 'docker build with a tag: dbu <tag>'
    docker build -t=$argv[1] .
end
