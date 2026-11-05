# Sessions

Every app with a now-playing session is listed, not only the one macOS elected. With more than one, a list button with the count sits at the right end of the controls. It opens a popup with one row per session: artwork, title, app name and a play or pause mark, with the shown session highlighted. Clicking a row makes the block show and control that session until it goes away.

## Sub-features

- `sessions-list` the backend reports each app that has a title, and which one macOS elected.
- `sessions-button` the list button and count show only with two or more sessions.
- `sessions-popup` the popup rows match `$NP sessions`, with the shown one highlighted.
- `sessions-pick` clicking a row shows that session in the block and closes the popup (needs the person).
- `sessions-default` with no pick, the block shows the elected session, else one that is playing, else the first.
- `sessions-forget` when the picked app's session disappears, the pick is cleared and the default applies.
- `sessions-target` the controls act on the shown session only.
- `sessions-inactive` a listed session with no active player, such as a paused browser tab, ignores the controls rather than sending them elsewhere.

## How to get to it (user POV)

- Have two players with sessions, such as Music and a YouTube tab. Click the list button under the progress bar, then click a row.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0 and its `backend get` lines list two or more sessions. If only one shows, ask the person to start something in a second player.
- `$NP sessions` and `$NP shot before` recorded.

- **List.** Run `$NP sessions`. One line per session; `*` marks the elected one.
- **Button.** Run `$NP shot button`. The controls row ends in the list icon and the session count.
- **Popup.** Run `$NP do sessions`, wait 2 s, `$NP shot list`. Rows match `$NP sessions`; the shown session is highlighted. Close it with `herdr-app do overlay.close`.
- **Switch.** Run `$NP do cycle`, wait 1 s, `$NP shot switched`. The block shows the next session's title and artwork.
- **Target.** With a session that has an active player shown, run `$NP do toggle` and `$NP wait-rate 1 5 <bundle>`. In `$NP sessions`, only that line's `rate` changed. Toggle back.
- **Inactive.** `$NP send toggle <bundle of a paused browser tab>` exits non-zero with `has no active player`, and `$NP sessions` is unchanged.
- **Pick.** Ask the person to click a row; then `$NP shot picked`.

## Gotchas

- MediaRemote lists a paused browser tab as a client with full info, but only active player paths take a targeted command. Sent to an inactive client, MediaRemote delivers it to the elected player instead. The backend refuses that send (exit 4), so the shown play icon reverts on the next poll.
- A session going from paused to playing becomes the pick: pin Chrome with `$NP do cycle`, `$NP send play com.apple.Music` (Music must be active), and within one poll `now-playing.pinned` is `com.apple.Music` and the block shows Music. Pause Music afterward.
- The pick lives in `shared("now-playing.pinned")`, so the block and the popup agree, and it survives a restart.
- Sessions keep MediaRemote's client order. Cycle follows it.
- The popup is its own copy of the mod and polls the backend while open.
