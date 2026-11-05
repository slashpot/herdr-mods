# Artwork and open player

The square at the left of the block shows the track's cover (a music-note placeholder when there is none). After a track change the old cover stays until the new one arrives rather than flashing the placeholder. Clicking the cover brings the playing app to the front.

## Sub-features

- `art-show` the cover for the current track; placeholder icon when the player gives none.
- `art-refresh` after a track change the cover switches within ~3 s; the mod's `data/now-playing/` holds exactly one image, named after its content.
- `art-open` clicking the cover runs `open -b <bundle>`: the player comes to the front.

## How to get to it (user POV)

- Look at the left of the block; change track to see it change.
- Click the cover (pointer cursor appears when a player is known).

## Driving it with np-verify

Preconditions:

- `$NP get before` shows an `art` field (Music library tracks and Spotify both provide one).

- **Cover shown.** Run `ls ~/.config/herdr-app/data/now-playing/` and `$NP shot art`. Exactly one `<16 hex>.jpg|png` file exists and `art.block.png` shows a cover, not the note icon.
- **Refresh.** Run `$NP send next`, wait 4 s, `ls ~/.config/herdr-app/data/now-playing/` and `$NP shot art-next`. One file, with a new name; the block shows the new cover and the new title. Restore with `$NP send previous`.
- **Open player.** Ask the person to click the cover, or reproduce the exact call: `open -b "$(python3 -c 'import json;print(json.load(open(".verify/now-playing/'"$(cat .verify/now-playing/current)"'/get-before.json"))["bundle"])')"`. The player's window becomes frontmost (`osascript -e 'tell application "System Events" to name of first process whose frontmost is true'`).

## Gotchas

- Artwork arrives 1–2 s after the title; a shot taken immediately after `next` legitimately shows the previous cover.
- Browser sources often have no artwork: the placeholder is correct there, not a failure.
- Bringing the player to the front steals focus from the person's window: tell them before you do it.
