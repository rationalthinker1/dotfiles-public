#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${BASE_DIR}/backup"
export ZSH="${LOCAL_CONFIG}/oh-my-zsh"
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

# Installing Oh My Zsh
if [[ ! -e "${ZSH}" ]] ; then
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

mkdir -p "${BACKUP_DIR}"
backupFile "${HOME}/.zshrc"
backupFile "${HOME}/.vimrc"
backupFile "${HOME}/.vim"
backupFile "${HOME}/.config/zsh"
backupFile "${HOME}/.config/ranger"
backupFile "${HOME}/.config/tmux"
backupFile "${HOME}/.config/oh-my-zsh"
backupFile "${HOME}/.config/fzf"
backupFile "${HOME}/.Xresources"

createSymlink "${BASE_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
createSymlink "${BASE_DIR}/.vimrc" "${HOME}/.vimrc"
createSymlink "${BASE_DIR}/.vim" "${HOME}/.vim"
createSymlink "${BASE_DIR}/zsh" "${HOME}/.config/zsh"
createSymlink "${BASE_DIR}/ranger" "${HOME}/.config/ranger"
createSymlink "${BASE_DIR}/tmux" "${HOME}/.config/tmux"
createSymlink "${BASE_DIR}/oh-my-zsh" "${HOME}/.config/oh-my-zsh"
createSymlink "${BASE_DIR}/fzf" "${HOME}/.config/fzf"
createSymlink "${BASE_DIR}/.Xresources" "${HOME}/.Xresources"


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
