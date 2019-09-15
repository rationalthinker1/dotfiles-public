#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${BASE_DIR}/backup"
#echo $BASE_DIR
#echo $ABSOLUTE_PATH
function createSymlink() {
	if [ ! -L $1 ]; then
		ln -nfs $1 $2
		echo "Link created: $2"
	fi
}

function backupFile() {
	filename=$(basename "${1}")
	if [[ ! -f "${1}" && ! -d "${1}" ]]; then
		echo "${1} does not exist" && return 1
	fi
	#echo "${filename}"
	#echo "${1}"
	#cp -r -H $1 "${BACKUP_DIR}/"
	rsync -avzhL --quiet --ignore-existing "${1}" "${BACKUP_DIR}/"
	echo "Backed up ${filename} to ${BACKUP_DIR}"
}

mkdir -p "${BACKUP_DIR}"
backupFile "${HOME}/.zshrc"
backupFile "${HOME}/.vimrc"
backupFile "${HOME}/.vim"
backupFile "${HOME}/.config/zsh"
backupFile "${HOME}/.config/ranger"
backupFile "${HOME}/.config/tmux"
backupFile "${HOME}/.config/oh-my-zsh"
backupFile "${HOME}/.Xresources"

createSymlink "${BASE_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
createSymlink "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
createSymlink "${BASE_DIR}/.vim" "${HOME}/.vim"
createSymlink "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
createSymlink "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
createSymlink "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
createSymlink "${BASE_DIR}/.oh-my-zsh" "${HOME}/.config/oh-my-zsh"
createSymlink "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"
