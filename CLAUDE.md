# herdr-mods

Mods for herdr-app, the GUI app. They are not herdr CLI/TUI plugins. A mod is JS against gpui-kit and installs into `~/.config/herdr-app/mods/<name>`, or `$HERDR_APP_HOME/mods/<name>` when that is set.

## Mods

- `music-remote/` is a universal media remote in the sidebar. It shows title, artist and artwork, and has play/pause/next/previous. It is not tied to any one player. Read `music-remote/README.md` before changing it. `music-remote/` is laid out as a herdr.dev gallery entry: the mod's files are in `music-remote/mods/music-remote/`, and `install.sh`, `keys.json` and the gallery files sit at the entry root.

## Working here

- Install a mod by copying, never by symlinking. Each mod's `install.sh` does this.
- Prove a change in the running Herdr window with the matching verify skill, such as `.claude/skills/verify-music-remote/`.
- Commit verified work straight to `main` and push. Use no branch and no PR. Work that is not verified yet does not go to `main`.
- Open work lives in `TODO.md`.
- Reply to the person in Traditional Chinese (繁體中文). Code, commit messages and docs stay in English.
