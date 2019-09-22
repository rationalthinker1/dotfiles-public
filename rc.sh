#!/bin/bash
# if you place this file in ~/.ssh/rc, then this script will run everytime someone will log in
# if shell is in interactive-mode
if [ -t 0 ]; then
	echo loading and updating dotfiles
	git -C "${HOME}"/dotfiles reset --quiet --hard HEAD
	git -C "${HOME}"/dotfiles pull --quiet --rebase
	bash "${HOME}"/dotfiles/install.sh
fi
