#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${BASE_DIR}/backup"
LOCAL_CONFIG="${HOME}/.config"
export ZSH="${LOCAL_CONFIG}/oh-my-zsh"

function decho() {
	if [[ "${DEBUG}" ]]; then
		echo "${1}"
	fi
}

function updateFiles() {
	dotfiles_file="${1}"
	current_file="${2}"

	decho "FUNCTION updateFiles"
	decho "current_file: ${current_file}"
	decho "dotfiles_file: ${dotfiles_file}"

	# if the link is not symbolic link or if the file is a symbolic link and the target does not contain string "dotfiles"
	if [[ ( ! -L "${current_file}" ) || ( -L "${current_file}" && (! $(readlink -f "${current_file}") =~ "dotfiles" ) ) ]]; then
		echo "file ${dotfiles_file} is being setup"
		backupFile "${current_file}"
		createSymlink "${dotfiles_file}" "${current_file}"
		return 0
	fi

	decho "file ${current_file} does not need to be updated"
	return 0
}

function createSymlink() {
	if [ ! -L $1 ]; then
		decho "FUNCTION createSymlink"
		decho "argument 1: ${1}"
		decho "argument 2: ${2}"
		decho ""
		if [[ ! "${DEBUG}" ]]; then
			ln -nfs $1 $2
		fi
		echo "Link created: $2"
	fi
}

function backupFile() {
	filename=$(basename "${1}")
	decho "FUNCTION backupFile"
	decho "argument 1: ${1}"
	decho "filename: ${filename}"
	decho ""
	if [[ ! -f "${1}" && ! -d "${1}" ]]; then
		decho "${1} does not exist" && return 0
	fi

	if [[ ! "${DEBUG}" ]]; then
		rsync -avzhL --quiet "${1}" "${BACKUP_DIR}/"
		rm -rf "${1}"
	fi
	echo "Backed up ${filename} to ${BACKUP_DIR}"
}

# Installing zsh
if [[ ! $(zsh --version 2>/dev/null) ]]; then
	decho "zsh does not exist"
	sudo apt install --assume-yes --no-install-recommends zsh powerline fonts-powerline python3-pip
	pip3 install --user pynvim
	sudo echo $(which zsh) | sudo tee -a /etc/shells
	sudo chsh -s $(which zsh)
fi

# Installing Oh My Zsh
if [[ ! -d "${ZSH}" ]] ; then
	decho "oh-my-zsh does not exist"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

mkdir -p "${BACKUP_DIR}"
updateFiles "${BASE_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
updateFiles "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
updateFiles "${BASE_DIR}/.vim" "${HOME}/.vim"
updateFiles "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
updateFiles "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
updateFiles "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
updateFiles "${BASE_DIR}/fzf" "${HOME}/.config/fzf"
updateFiles "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"
updateFiles "${BASE_DIR}/rc.sh" "${HOME}/.ssh/rc"

# Installing tmux plugins
if [[ ! -d "${LOCAL_CONFIG}/tmux/plugins/tmux-yank" ]]; then
	decho "Installing tmux-yank plugin"
	git clone https://github.com/tmux-plugins/tmux-yank "${LOCAL_CONFIG}"/tmux/plugins/tmux-yank
fi

# Installing tmux plugins
if [[ ! -d "${LOCAL_CONFIG}/tmux/plugins/tmux-better-mouse-mode" ]]; then
	decho "Install tmux-better-mouse-mode plugin"
	git clone https://github.com/tmux-plugins/tmux-better-mouse-mode "${LOCAL_CONFIG}"/tmux/plugins/tmux-better-mouse-mode
fi

# Installing vim plugins
decho "Installing vim plugins"
#vim -E -c PlugInstall -c qall!
