#!/bin/bash
echo loading and updating dotfiles
git -C "${HOME}"/dotfiles reset --quiet --hard HEAD
git -C "${HOME}"/dotfiles pull --quiet --rebase
bash "${HOME}"/dotfiles/install.sh
