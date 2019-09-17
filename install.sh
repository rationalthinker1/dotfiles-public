#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${BASE_DIR}/backup"
export ZSH="${LOCAL_CONFIG}/oh-my-zsh"
#echo $BASE_DIR
#echo $ABSOLUTE_PATH

function updateFiles() {
	dotfiles_file="${1}"
	current_file="${2}"

	if [[ ! -f "${current_file}" ]]; then
		if [[ "${DEBUG}" ]]; then
			echo "FUNCTION updateFiles"
			echo "file current_file: ${current_file} does not exist"
			echo ""
		fi
		createSymlink "${dotfiles_file}" "${current_file}"
		return 0
	fi

	# the /dev/null part is to remove error if the file doesn't exist
	#current_file_sum=$(md5sum "${current_file}" 2>/dev/null || echo 0 | awk '{ print $1 }')
	#dotfiles_file_sum=$(md5sum "${dotfiles_file}" 2>/dev/null || echo 0 | awk '{ print $1 }')

	current_file_sum=$(md5sum "${current_file}" | awk '{ print $1 }')
	dotfiles_file_sum=$(md5sum "${dotfiles_file}" | awk '{ print $1 }')
	
	if [[ "${DEBUG}" ]]; then
		echo "FUNCTION updateFiles"
		echo "current_file: ${current_file}"
		echo "dotfiles_file: ${dotfiles_file}"
		echo "current_file_sum: ${current_file_sum}"
		echo "dotfiles_file_sum: ${dotfiles_file_sum}"
		echo ""
	fi

	if [[ "${dotfiles_file_sum}" != "${current_file_sum}" ]]; then
		echo "file ${dotfiles_file} is being setup"
		backupFile "${current_file}"
		createSymlink "${dotfiles_file}" "${current_file}"
	else
		echo "file ${current_file} does not need backup"
	fi
}

function createSymlink() {
	if [ ! -L $1 ]; then
		if [[ "${DEBUG}" ]]; then
			echo "FUNCTION createSymlink"
			echo "argument 1: ${1}"
			echo "argument 2: ${2}"
			echo ""
		fi
		if [[ ! "${DEBUG}" ]]; then
			ln -nfs $1 $2
		fi
		echo "Link created: $2"
	fi
}

function backupFile() {
	filename=$(basename "${1}")
	if [[ "${DEBUG}" ]]; then
		echo "FUNCTION backupFile"
		echo "argument 1: ${1}"
		echo "filename: ${filename}"
		echo ""
	fi
	if [[ ! -f "${1}" && ! -d "${1}" ]]; then
		echo "${1} does not exist" && return 0
	fi
	#echo "${filename}"
	#echo "${1}"
	#cp -r -H $1 "${BACKUP_DIR}/"

	if [[ ! "${DEBUG}" ]]; then
		rsync -avzhL --quiet --ignore-existing "${1}" "${BACKUP_DIR}/"
	fi
	echo "Backed up ${filename} to ${BACKUP_DIR}"
}

# Installing Oh My Zsh
if [[ ! -e "${ZSH}" ]] ; then
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	echo "oh-my-zsh does not exist"
fi

#backupFile "${HOME}/.zshrc"
#backupFile "${HOME}/.vimrc"
#backupFile "${HOME}/.vim"
#backupFile "${HOME}/.config/zsh"
#backupFile "${HOME}/.config/ranger"
#backupFile "${HOME}/.config/tmux"
#backupFile "${HOME}/.config/oh-my-zsh"
#backupFile "${HOME}/.config/fzf"
#backupFile "${HOME}/.Xresources"

#createSymlink "${BASE_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
#createSymlink "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
#createSymlink "${BASE_DIR}/.vim" "${HOME}/.vim"
#createSymlink "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
#createSymlink "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
#createSymlink "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
#createSymlink "${BASE_DIR}/oh-my-zsh" "${HOME}/.config/oh-my-zsh"
#createSymlink "${BASE_DIR}/fzf" "${HOME}/.config/fzf"
#createSymlink "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"

mkdir -p "${BACKUP_DIR}"
updateFiles "${BASE_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
#updateFiles "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
#updateFiles "${BASE_DIR}/.vim" "${HOME}/.vim"
#updateFiles "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
#updateFiles "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
#updateFiles "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
#updateFiles "${BASE_DIR}/oh-my-zsh" "${HOME}/.config/oh-my-zsh"
#updateFiles "${BASE_DIR}/fzf" "${HOME}/.config/fzf"
#updateFiles "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"


# Installing zsh
#if [ $(dpkg-query -W -f='${Status}' zsh 2>/dev/null | grep -c "ok installed") -eq 0 ];
#then
#echo "installing zsh..."
#sudo apt-get --assume-yes --no-install-recommends install zsh
#sudo echo /usr/bin/zsh | sudo tee -a /etc/shells
#sudo chsh -s /usr/bin/zsh
#else
#echo "zsh is already installed... moving on"
#echo "checking of zsh is your default shell..."
#if [ $SHELL != "/usr/bin/zsh" ] || [ $SHELL != "/bin/zsh" ]; then
#echo "zsh is not your default shell";
#echo "making zsh your default shell...";
#sudo chsh -s /usr/bin/zsh
#else
#echo "zsh is already your default shell... moving on";
#fi
#fi
