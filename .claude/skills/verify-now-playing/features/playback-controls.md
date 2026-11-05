# Playback controls

Three buttons under the progress bar control whichever player is active: previous (skip-back), a play/pause toggle whose icon shows the action available (play icon while paused), and next (skip-forward). The toggle's icon flips at once, before the player confirms.

## Sub-features

- `ctl-toggle-play` toggle while paused starts playback; icon becomes pause; clock starts moving.
- `ctl-toggle-pause` toggle while playing pauses; icon becomes play; clock freezes.
- `ctl-next` next moves to the next track; title, subtitle and artwork update.
- `ctl-previous` previous goes back a track (or restarts the current one if it has played more than a few seconds — the player decides).
- `ctl-optimistic` the toggle icon changes on click, before the next poll (click-only; needs the person).

## How to get to it (user POV)

- Click the round icon buttons at the bottom of the Now Playing block. Hover highlights each one.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0 with a track in the `backend get` line.
- `$NP get before` and `$NP shot before` recorded.

- **Toggle.** Run `$NP send toggle`. Prints `1` (or `true`). Then `$NP wait-rate 1` if `before` was paused (or `wait-rate 0` if it was playing). Prints `rate N`.
- **See the toggle.** Wait 2 s, run `$NP get toggled` and `$NP shot toggled`. `rate` flipped versus `before`; the middle button shows pause when `rate` is 1 and play when it is 0.
- **Toggle back.** Run `$NP send toggle` and `wait-rate` to the `before` value, then `$NP shot restored`. The icon is back.
- **Next.** Run `$NP send next`, wait 3 s, `$NP get next` + `$NP shot next`. `title` differs from `before`; the block shows the new title.
- **Previous.** Run `$NP send previous` (twice if the first only restarted the track), then `$NP get prev`. `title` equals `before`'s again. This is also the restore step for `next`.
- **Optimistic flip.** Ask the person to click the toggle while you run `$NP shot click` within half a second. The icon has flipped even if `get` still shows the old `rate`.

## Gotchas

- `send` plays real audio on the person's machine. Restore to `before` every time.
- `previous` after more than ~3 s of playback restarts the track instead of going back; send it again.
- `send` prints `1` when MediaRemote accepted the command, not when the player obeyed. Prove it with `get`.
- Spotify sometimes needs ~1 s longer than Music to report the new `rate`; use `wait-rate` with a timeout, not a fixed sleep.
