# Sessions

Every app with a now-playing session is listed, not only the one macOS elected. With more than one, a list button with the count sits at the right end of the controls. It opens a popup with one row per session: artwork, title, app name and a play or pause mark, with the shown session highlighted. Clicking a Music, Spotify or Podcasts row shows that session in the block and closes the popup. Other rows, such as a browser tab, are information only. `cmd-alt-s` (`cycle`) changes the shown session.

## Sub-features

- `sessions-list` the backend reports each app that has a title, and which one macOS elected.
- `sessions-button` the list button and count show only with two or more sessions.
- `sessions-popup` the popup rows match `$NP sessions`, with the shown one highlighted.
- `sessions-pick` clicking a Music, Spotify or Podcasts row sets `now-playing.pinned` to that bundle and closes the popup (needs the person).
- `sessions-readonly` clicking any other row does nothing: no pointer cursor, no hover, the popup stays open (needs the person).
- `sessions-default` with no pick, the block shows the elected session, else one that is playing, else the first.
- `sessions-forget` when the picked app's session disappears, the pick is cleared and the default applies.
- `sessions-target` the controls act on the shown session only.
- `sessions-inactive` a listed session with no active player, such as a browser tab that isn't elected, shows dimmed controls that ignore clicks and hotkeys rather than sending them elsewhere.
- `sessions-scripted` Music and Spotify take every control over AppleScript, elected or not, so they are never dimmed. Podcasts has no AppleScript: its row is pickable, but its controls are dimmed while it isn't elected.

## How to get to it (user POV)

- Have two players with sessions, such as Music and a YouTube tab. Click the list button under the progress bar.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0 and its `backend get` lines list two or more sessions. If only one shows, ask the person to start something in a second player.
- `$NP sessions` and `$NP shot before` recorded.

- **List.** Run `$NP sessions`. One line per session; `*` marks the elected one.
- **Button.** Run `$NP shot button`. The controls row ends in the list icon and the session count.
- **Popup.** Run `$NP do sessions`, wait 2 s, `$NP shot list`. Rows match `$NP sessions`; the shown session is highlighted. Close it with `herdr-app do overlay.close`.
- **Switch.** Run `$NP do cycle`, wait 1 s, `$NP shot switched`. The block shows the next session's title and artwork.
- **Target.** With a session that has an active player shown, run `$NP do toggle` and `$NP wait-rate 1 5 <bundle>`. In `$NP sessions`, only that line's `rate` changed. Toggle back.
- **Inactive.** Use a paused Podcasts session or a browser tab that isn't elected. `$NP sessions` marks it `---` instead of `ctl`. `$NP send toggle <that bundle>` exits non-zero with `has no active player`. Pin it with `$NP do cycle`, `$NP shot dimmed`: prev, toggle and next are dimmed. `$NP do toggle`, then `$NP shot dimmed-toggle` within half a second: the icon did not flip, and `$NP sessions` is unchanged.
- **Scripted.** Run `.claude/skills/verify-now-playing/scripts/scripted-control Music` and `… Spotify`, each while another app is elected. It cycles the block to that app, toggles it twice through `do`, and checks the app's own `player state` flips and comes back. `$NP sessions` still shows them `---` when not elected, because it reads the backend before `main.js` marks them controllable.
- **Check the pin before any `do toggle`.** The pin follows whatever started playing last, so it may name a session that is playing for the person. Pausing a browser tab can drop it from MediaRemote with no way to resume it from here.
- **Pick.** Open the popup and ask the person to click a Music, Spotify or Podcasts row that isn't shown. `now-playing.pinned` in `~/.config/herdr-app/shared.json` is that bundle, `herdr-app status` lists no overlay, and the block shows it.
- **Read-only.** Ask the person to click a browser row; then `$NP shot row-click`. The popup is still open and `now-playing.pinned` did not change.

## Gotchas

- MediaRemote lists a paused browser tab as a client with full info, but only active player paths take a targeted command. Sent to an inactive client, MediaRemote delivers it to the elected player instead. The backend refuses that send (exit 4), and the block dims that session's controls.
- A session going from paused to playing becomes the pick: pin Chrome with `$NP do cycle`, `$NP send play com.apple.Music` (Music must be active), and within one poll `now-playing.pinned` is `com.apple.Music` and the block shows Music. Pause Music afterward.
- The pick lives in `shared("now-playing.pinned")`, so the block and the popup agree, and it survives a restart.
- Sessions keep MediaRemote's client order. Cycle follows it.
- The popup is its own copy of the mod and polls the backend while open.
