# ref - Quick reference file viewer
# View, edit, and list CLI command reference cheat sheets
#
# Usage:
#   ref <topic>           Print reference content to stdout
#   ref -e <topic>        Open reference in $EDITOR
#   ref -ls | --list      List all available reference topics
#   ref --help | -h       Show this help message

function ref() {
	local references_dir="${ZDOTDIR}/references"

	case "${1}" in
		--help|-h)
			cat <<'EOF'
Usage: ref <topic>           Print reference content to stdout
       ref -e <topic>        Open reference in $EDITOR
       ref -ls | --list      List all available reference topics
       ref --help | -h       Show this help message

Examples:
  ref fd                     Print the fd cheat sheet
  ref -e rg                  Edit the rg reference in $EDITOR
  ref --list                 Show all available topics
EOF
			return 0
			;;

		-ls|--list)
			if [[ -d "${references_dir}" ]]; then
				local files=("${references_dir}"/*.md(N))
				if (( ${#files} == 0 )); then
					echo "No reference topics found in ${references_dir}"
					return 1
				fi
				echo "Available reference topics:"
				for f in "${files[@]}"; do
					echo "  - ${${f:t}%.md}"
				done
			else
				echo "References directory not found: ${references_dir}"
				return 1
			fi
			return 0
			;;

		-e)
			if [[ -z "${2}" ]]; then
				echo "Usage: ref -e <topic>"
				return 1
			fi
			local file="${references_dir}/${2}.md"
			if [[ ! -f "${file}" ]]; then
				mkdir -p "${references_dir}"
				touch "${file}"
			fi
			"${EDITOR:-vim}" "${file}"
			return 0
			;;

		"")
			ref --help
			return 0
			;;

		-*)
			echo "Unknown option: ${1}"
			echo "Run 'ref --help' for usage."
			return 1
			;;

		*)
			local file="${references_dir}/${1}.md"
			if [[ ! -f "${file}" ]]; then
				echo "No reference found for '${1}'"
				ref -ls
				return 1
			fi
			command cat "${file}"
			return 0
			;;
	esac
}
