# Track display

The block shows what the system is playing in any player: artwork, title, `artist — album` (or the app name when both are missing), a progress bar with elapsed and total clocks that advance while playing, and a message line when there is nothing to show.

## Sub-features

- `display-track` title and `artist — album` match the player, truncated with an ellipsis when long.
- `display-progress` bar width and clocks match `elapsed`/`duration`; clocks advance about once a second while playing and freeze while paused.
- `display-no-duration` a stream without `duration` hides the bar and clocks.
- `display-nothing` with no session the block reads `Nothing playing`.
- `display-error` a failing backend shows `Now Playing: <error>` instead of a blank block.
- `display-source` the block follows whichever app MediaRemote reports (Music, Spotify, a browser tab).

## How to get to it (user POV)

- Look at the bottom of the sidebar, above Settings, in the `main-now-playing` layout.
- Start or change playback in any player; the block follows within ~1.5 s.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0 and its `backend get` line names a track.

- **Read the session.** Run `$NP get display`. Note `title`, `artist`, `album`, `elapsed`, `duration`, `rate`.
- **See it.** Run `$NP shot display`, open `display.block.png`. Title and subtitle equal the JSON; the right clock equals `duration` as m:ss; the left clock is within 2 s of `elapsed` (plus `now - timestamp` if `rate` is 1).
- **Clocks advance while playing.** If `rate` is 1: `$NP shot tick1`, wait 3 s, `$NP shot tick2`. The left clock moved by about 3 s and the bar grew. If paused, the two clocks are equal.
- **Other source.** Ask the person to play something in Spotify or a browser tab, then `$NP get source` + `$NP shot source`: `app` changes and the block follows.
- **Nothing playing.** Only reachable after a fresh login or after quitting every player: ask the person; do not quit their apps. `$NP get` prints `null` and the block reads `Nothing playing`.

## Gotchas

- MediaRemote keeps reporting the last active app while it is paused: a paused track is not "nothing playing".
- The left clock is extrapolated from `timestamp` and `rate`; compare within a 2 s tolerance, not exactly.
- Your own `$NP get` writes artwork to the run's scratch dir, not the mod's `data/now-playing/`; it never changes what the block shows.
- `display-error` has no safe trigger without breaking the installed copy; verify it only in a throwaway `HERDR_APP_HOME`, or report it as not driven.
