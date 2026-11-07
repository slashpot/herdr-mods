# Artwork and open player

The square at the left of the block shows the track's cover (a music-note placeholder when there is none). While the same track's cover is still loading, the last picture stays rather than flashing the placeholder; a new track whose cover hasn't arrived shows the placeholder briefly. Clicking the cover brings the playing app to the front.

## Sub-features

- `art-show` the cover for the current track; placeholder icon when the player gives none.
- `art-refresh` after a track change the cover switches within ~3 s; the mod's `data/now-playing/` holds one image per session, named `<bundle>-<content hash>` (a session still waiting for its cover may keep an older file).
- `art-open` clicking the cover runs `open -b <bundle>`: the player comes to the front.

## How to get to it (user POV)

- Look at the left of the block; change track to see it change.
- Click the cover (pointer cursor appears when a player is known).

## Driving it with np-verify

Preconditions:

- `$NP get before` shows an `art` field on the shown session (Music library tracks and Spotify both provide one).

- **Cover shown.** Run `ls ~/.config/herdr-app/data/now-playing/` and `$NP shot art`. One `<bundle>-<16 hex>.jpg|png` file per session in `$NP sessions` exists and `art.block.png` shows a cover, not the note icon.
- **Refresh.** Run `$NP do next`, wait 4 s, `ls ~/.config/herdr-app/data/now-playing/` and `$NP shot art-next`. If the new track has a different cover, that session's file has a new name and its old one is gone; the block shows the new cover and the new title. A track from the same album has the same cover, so the same file name. Restore with `$NP do previous` twice within a second (see playback-controls.md).
- **Open player.** Ask the person to click the cover, or reproduce the exact call with the shown session's bundle (`now-playing.pinned` in `~/.config/herdr-app/shared.json`, else the `*` line of `$NP sessions`): `open -b <bundle>`. The player's window becomes frontmost (`osascript -e 'tell application "System Events" to name of first process whose frontmost is true'`).

## Gotchas

- Artwork arrives 1–2 s after the title; a shot taken immediately after `next` legitimately shows the placeholder (or the previous cover if the title hasn't changed yet either).
- Browser sources often have no artwork: the placeholder is correct there, not a failure.
- Bringing the player to the front steals focus from the person's window: tell them before you do it.
