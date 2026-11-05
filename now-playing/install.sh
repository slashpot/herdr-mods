#!/bin/sh
# Builds the helper and copies the mod into herdr-app's mods folder.
# A copy, not a symlink: herdr-app doesn't load svg() icons through a symlinked mod folder.
# herdr-app reloads the mod by itself after the copy.
set -eu
cd "$(dirname "$0")"
./build.sh
dest="${HERDR_APP_HOME:-$HOME/.config/herdr-app}/mods/now-playing"
[ -L "$dest" ] && rm "$dest"
mkdir -p "$dest"
rsync -a --delete --exclude .git --exclude .gitignore --exclude install.sh ./ "$dest/"
herdr-app check "$dest"
