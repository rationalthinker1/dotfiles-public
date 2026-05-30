function dcip --description 'IP addresses of all compose containers'
    docker inspect --format '{{$e := . }}{{with .NetworkSettings}} {{$e.Name}}
{{range $index, $net := .Networks}}{{$index}} IP:{{.IPAddress}}; Gateway:{{.Gateway}}
{{end}}{{end}}' (dcp -q)
end
