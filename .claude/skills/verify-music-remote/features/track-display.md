# Track display

The block shows what the system is playing in any player: artwork, title, `artist — album` (or the app name when both are missing), a progress bar with elapsed and total clocks that advance while playing, and a message line when there is nothing to show.

## Sub-features

- `display-track` title and `artist — album` match the player; long ones scroll (see marquee.md).
- `display-progress` bar width and clocks match `elapsed`/`duration`; clocks advance about once a second while playing and freeze while paused.
- `display-no-duration` a stream without `duration` hides the bar and clocks.
- `display-nothing` with no session the block reads `Nothing playing`.
- `display-error` a failing backend shows `Music Remote: <error>` instead of a blank block.
- `display-source` the block follows the picked session, else the one MediaRemote elected (Music, Spotify, a browser tab). See sessions.md.

## How to get to it (user POV)

- Look at the bottom of the sidebar, above Settings, in the `main-music-remote` layout.
- Start or change playback in any player; the block follows within ~1.5 s.

## Driving it with mr-verify

Preconditions:

- `$MR doctor` exits 0 and its `backend get` line names a track.

- **Read the session.** Run `$MR get display`. Note `title`, `artist`, `album`, `elapsed`, `duration`, `rate`.
- **See it.** Run `$MR shot display`, open `display.block.png`. Title and subtitle equal the JSON; the right clock equals `duration` as m:ss (h:mm:ss from an hour up); the left clock is within 2 s of `elapsed` (plus `now - timestamp` if `rate` is 1).
- **Clocks advance while playing.** If `rate` is 1: `$MR shot tick1`, wait 3 s, `$MR shot tick2`. The left clock moved by about 3 s and the bar grew. If paused, the two clocks are equal.
- **Other source.** Ask the person to start something in Spotify or a browser tab, then `$MR get source` + `$MR shot source`: the session that started playing becomes `music-remote.pinned` and the block shows it, whatever `elected` says.
- **Nothing playing.** Only reachable after a fresh login or after quitting every player: ask the person; do not quit their apps. `$MR sessions` prints `nothing playing` and the block reads `Nothing playing`.

## Gotchas

- MediaRemote keeps listing an app while it is paused: a paused track is not "nothing playing".
- The left clock is extrapolated from `timestamp` and `rate`; compare within a 2 s tolerance, not exactly.
- Your own `$MR get` writes artwork to the run's scratch dir, not the mod's `data/music-remote/`; it never changes what the block shows.
- `display-error` has no safe trigger without breaking the installed copy; verify it only in a throwaway `HERDR_APP_HOME`, or report it as not driven.
