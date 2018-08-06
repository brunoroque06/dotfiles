#!/bin/bash

FILES=".aliases bin .gitconfig .spoud .vimrc .zshrc"

for file in $FILES; do
  s=$(pwd)/$file
  t=$HOME/$file
  echo "Symlinking: $s -> $t."
  ln -fns $s $t
done

source $HOME/.zshrc

sh brew.sh
