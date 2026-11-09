# Playback controls

Three buttons under the progress bar control the session the block shows (see sessions.md): previous (skip-back), a play/pause toggle whose icon shows the action available (play icon while paused), and next (skip-forward). The toggle's icon flips at once, before the player confirms.

## Sub-features

- `ctl-toggle-play` toggle while paused starts playback; icon becomes pause; clock starts moving.
- `ctl-toggle-pause` toggle while playing pauses; icon becomes play; clock freezes.
- `ctl-next` next moves to the next track; title, subtitle and artwork update.
- `ctl-previous` previous goes back a track (or restarts the current one if it has played more than a few seconds — the player decides).
- `ctl-target` with several sessions, a button changes only the shown one.
- `ctl-optimistic` the toggle icon changes at once, before the next poll, and a poll already in flight doesn't flip it back.
- `ctl-dimmed` a session that can't take commands has dimmed buttons that do nothing (see sessions.md).

## How to get to it (user POV)

- Click the round icon buttons at the bottom of the Music Remote block. Hover highlights each one.
- The narrow rail keeps only the toggle (see narrow-rail.md).

## Driving it with mr-verify

Preconditions:

- `$MR doctor` exits 0 with a track in the `backend get` line.
- `$MR get before` and `$MR shot before` recorded.

- **Toggle.** Run `$MR do toggle`, then at once `$MR shot opt`, then `$MR wait-rate 0 5 <shown bundle>` if `before` was playing (or `wait-rate 1`). Prints `rate N`. `opt.block.png` already shows the flipped icon (optimistic).
- **See the toggle.** Wait 2 s, run `$MR get toggled` and `$MR shot toggled`. `rate` flipped versus `before`; the middle button shows pause when `rate` is 1 and play when it is 0. For Music and Spotify, `osascript -e 'tell application "Music" to player state'` agrees.
- **Toggle back.** Run `$MR do toggle` and `wait-rate` to the `before` value, then `$MR shot restored`. The icon is back.
- **Next.** Run `$MR do next`, wait 4 s, `$MR get next` + `$MR shot next`. `title` differs from `before`; the block shows the new title and duration.
- **Previous.** Run `$MR do previous` twice within a second, then `$MR get prev`. `title` equals `before`'s again (the track restarts from 0:00). This is also the restore step for `next`.
- **Click.** Hover and the hit area need the person: ask them to click the toggle, then `$MR shot click`.

## Gotchas

- `send` plays real audio on the person's machine. Restore to `before` every time.
- `$MR do <cmd>` is the buttons' path. `$MR send <cmd>` is MediaRemote only: without a bundle it goes to the elected session, which may not be the shown one, and with a non-elected Music or Spotify bundle it exits 4 though the button works (the mod uses AppleScript there).
- `previous` after more than ~3 s of playback restarts the track instead of going back. Send the second one within a second of the first, or it lands past 3 s and restarts again.
- `send` prints `1` when MediaRemote accepted the command, not when the player obeyed; `do` prints only `herdr-app do`'s `{"ok": true}`. Prove either with `get`.
- Spotify sometimes needs ~1 s longer than Music to report the new `rate`; use `wait-rate` with a timeout, not a fixed sleep.
