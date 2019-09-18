#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${BASE_DIR}/backup"
export ZSH="${LOCAL_CONFIG}/oh-my-zsh"
#decho $BASE_DIR
#decho $ABSOLUTE_PATH

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

	#if [[ ! -f "${current_file}" && -d "${current_file}" ]]; then
	## directory exists
	#decho "FUNCTION updateFiles"
	#decho "directory exists: ${current_file}"
	#decho ""
	#createSymlink "${dotfiles_file}" "${current_file}"

		#return 0
		#elif [[ -f "${current_file}" && ! -d "${current_file}" ]]; then
		## file exists
		## the /dev/null part is to remove error if the file doesn't exist
		##current_file_sum=$(md5sum "${current_file}" 2>/dev/null || echo 0 | awk '{ print $1 }')
		##dotfiles_file_sum=$(md5sum "${dotfiles_file}" 2>/dev/null || echo 0 | awk '{ print $1 }')

		#current_file_sum=$(md5sum "${current_file}" | awk '{ print $1 }')
		#dotfiles_file_sum=$(md5sum "${dotfiles_file}" | awk '{ print $1 }')

		#decho "FUNCTION updateFiles"
		#decho "current_file: ${current_file}"
		#decho "dotfiles_file: ${dotfiles_file}"
		#decho "current_file_sum: ${current_file_sum}"
		#decho "dotfiles_file_sum: ${dotfiles_file_sum}"
		#decho ""

		#if [[ "${dotfiles_file_sum}" != "${current_file_sum}" ]]; then
		#echo "file ${dotfiles_file} is being setup"
		#backupFile "${current_file}"
		#createSymlink "${dotfiles_file}" "${current_file}"
		#else
		#decho "file ${current_file} does not need to be updated"
		#fi

		#return 0
		#elif [[ ! -f "${current_file}" ]]; then
		## file does not exists
		#decho "FUNCTION updateFiles"
		#decho "file current_file: ${current_file} does not exist"
		#decho ""
		#createSymlink "${dotfiles_file}" "${current_file}"

		#return 0
		#elif [[ ! -d "${current_file}"  ]]; then
		## directory does not exists
		#decho "FUNCTION updateFiles"
		#decho "directory current_file: ${current_file} does not exist"
		#decho ""
		#createSymlink "${dotfiles_file}" "${current_file}"

		#return 0
		#fi

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
			echo "Link created: $2"
		fi
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
	decho "oh-my-zsh does not exist"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
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
updateFiles "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
updateFiles "${BASE_DIR}/.vim" "${HOME}/.vim"
updateFiles "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
updateFiles "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
updateFiles "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
updateFiles "${BASE_DIR}/oh-my-zsh" "${HOME}/.config/oh-my-zsh"
updateFiles "${BASE_DIR}/fzf" "${HOME}/.config/fzf"
updateFiles "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"

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
