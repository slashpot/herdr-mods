# Hotkeys

The block's controls have global shortcuts, set in herdr-app's `keys.json`: `cmd-alt-p` play/pause, `cmd-alt-.` next, `cmd-alt-,` previous, `cmd-alt-s` show the next session, `cmd-alt-l` open the session list. They work while the herdr-app window has focus. `herdr-app do now-playing.<command>` runs the same commands from outside the app.

## Sub-features

- `keys-install` `install.sh` adds each binding the person hasn't bound, prints what it added and what it skipped, and leaves `keys.json` untouched when nothing is new.
- `keys-control` `toggle`, `play`, `pause`, `next`, `previous` act on the session the block shows.
- `keys-cycle` `cycle` shows the next session in list order, wrapping at the end.
- `keys-sessions` `sessions` toggles the session list as the same popup the list button opens, placed at the list button. A second press closes it, and presses never stack a second list. The list button does the same.
- `keys-once` one press acts once, even while the session list is open.
- `keys-physical` the key presses themselves (needs the person).

## How to get to it (user POV)

- Press the shortcuts in the herdr-app window.
- Bind `herdr-app do now-playing.toggle` and the rest in Raycast or skhd for keys that work from any app.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0, including its `keys.json` line.
- `$NP sessions` and `$NP shot before` recorded.

- **Install merge.** Run `$NP install` twice. The first run on a fresh `keys.json` prints `keys: added …` lines. The second prints `keys: nothing to add`, and `md5 ~/.config/herdr-app/keys.json` is the same before and after it.
- **Check bindings.** Run `$NP keys`. It prints `all bindings present`.
- **Toggle.** Run `$NP do toggle`, then `$NP wait-rate 1 5 <bundle of the shown session>`. Only that session's `rate` changes in `$NP sessions`. Run `$NP do toggle` again to restore.
- **Cycle.** Run `$NP do cycle`, wait 1 s, `$NP shot cycled`. The block shows the next session from `$NP sessions`. `now-playing.pinned` in `~/.config/herdr-app/shared.json` names its bundle.
- **List.** Run `$NP do sessions`, wait 2 s, `$NP shot list`. `list.png` shows the popup next to the list button, at the bottom of the sidebar, with one row per session. Close it with `herdr-app do overlay.close`.
- **List toggles.** Run `.claude/skills/verify-now-playing/scripts/list-toggle`. Every line is `ok`: presses alternate open and closed, an outside close (as Esc) is noticed, and six presses in a row leave no stacked list.
- **Physical keys.** Ask the person to press `cmd-alt-p` while you run `$NP wait-rate`.

## Gotchas

- `herdr-app do now-playing.<command>` is the path a `keys.json` binding takes (`<mod>.<command>` goes to that mod's `nextCommand()`). It proves the handler, not the key spelling. On macOS, Option changes the typed character, so a `cmd-alt-.` press is only proven by the person pressing it.
- Every copy of the mod receives the command. Only the sidebar block reads `nextCommand()`; the list overlay never does.
- Any edit to `keys.json` makes the file the person's, and herdr-app then stops adding new default shortcuts on upgrade. That is why install writes nothing when nothing is new.
- Install never replaces a key the person bound, and skips a binding whose action already has another key.
