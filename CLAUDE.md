# herdr-mods

Mods for herdr-app, the GUI app. They are not herdr CLI/TUI plugins. A mod is JS against gpui-kit and installs into `~/.config/herdr-app/mods/<name>`, or `$HERDR_APP_HOME/mods/<name>` when that is set.

## Mods

- `now-playing/` is a universal media remote in the sidebar. It shows title, artist and artwork, and has play/pause/next/previous. It is not tied to any one player. Read `now-playing/README.md` before changing it.

## Working here

- Install a mod by copying, never by symlinking. Each mod's `install.sh` does this.
- Prove a change in the running Herdr window with the matching verify skill, such as `.claude/skills/verify-now-playing/`.
- Open work lives in `TODO.md`.
