# Now Playing

A herdr-app sidebar block that controls what the system is playing, such as Apple Music, Spotify, or YouTube in a browser. It shows artwork, title, artist, album and progress, with previous, play/pause and next buttons. A title or subtitle too long for the block scrolls. When several apps have a session, a list button or `cmd-alt-l` toggles a list of all of them. Clicking a Music, Spotify or Podcasts row shows that session; other rows are read-only. The block shows the session that started playing last, and `cmd-alt-s` cycles through them.

## Install

```sh
./install.sh
```

On macOS this runs `native/macos/build.sh`, which builds `native/macos/bin/libnowplaying.dylib` with clang (arm64 + x86_64, needs the Xcode Command Line Tools). It then copies the mod into herdr-app's mods folder, runs `herdr-app check`, and adds the mod's hotkeys to `keys.json`. herdr-app reloads the mod and the keys by itself.

The mod uses the `main-now-playing` layout. It is a clone of `main` with a 132px `now-playing` block between `agents` and `sidebar-footer`.

## Hotkeys

| Key | Command | Does |
|---|---|---|
| `cmd-alt-p` | `now-playing.toggle` | play or pause the shown session |
| `cmd-alt-.` | `now-playing.next` | next track |
| `cmd-alt-,` | `now-playing.previous` | previous track |
| `cmd-alt-s` | `now-playing.cycle` | show the next session |
| `cmd-alt-l` | `now-playing.sessions` | open the session list |

`now-playing.play` and `now-playing.pause` also exist, unbound.

The keys live in the `global` section of `$HERDR_APP_HOME/keys.json`, default `~/.config/herdr-app/keys.json`. `install.sh` adds only keys you have not bound. It skips a key bound to something else and an action that already has a key, and says so. It writes nothing when there is nothing to add, because any edit makes `keys.json` yours and herdr-app then stops adding its new default shortcuts on upgrade.

The keys work while the herdr-app window has focus. For keys that work from any app, bind a shell command in Raycast or skhd:

```sh
herdr-app do now-playing.toggle
```

## Design

The UI knows one data shape. Each OS gets its own backend in `native/<platform>/`, and everything that knows the OS lives in that folder: the `backend.js` that `main.js` imports, its native helper, and the `build.sh` that `install.sh` runs. `main.js` picks the backend by `window().platform`. A backend exports:

```
get()                 -> { elected: bundle | null, sessions: Track[] }
send(command, bundle)    command: play | pause | toggle | next | previous
activate(track)          brings the track's app to the front
settleMs                 how long the OS takes to report a command
Track = { title, artist, album, app, bundle, duration, elapsed, rate, timestamp, art, id, controllable, pickable }
```

- `bundle` is the backend's stable key for an app. On macOS it is the bundle id. `elected` is the app the OS sends untargeted commands to, or null where the OS has no such app.
- `timestamp` is when `elapsed` was read, in Unix seconds. `art` is an `image()` path relative to `appHome()`, or empty.
- `controllable` is false for an app the OS lists but won't take commands from. `pickable` marks the list rows that switch the block on click.

- The block shows `current()`: the pinned session, else the elected one, else one that is playing, else the first.
- The pin is `shared("now-playing.pinned")`, a bundle id. The block and the list popup are two copies of the mod, and shared state keeps them in agreement. A session that starts playing becomes the pick by itself, so the block follows whatever you just started. A pin set by `cycle` holds until another session starts. When the picked app's session goes away, the pick is cleared.
- Every control goes to the shown session's bundle.
- Play/pause sends `play` or `pause`, whichever the button shows, never a blind toggle. The block learns of a pause made in the player only at the next poll, and a toggle sent before then would start playback while the block flipped to paused.
- The list popup is the same mod opened with `props: { view: "sessions" }`. It polls the backend itself. Only the sidebar copy reads `nextCommand()`, so a key never acts twice.
- The marquee measures the clip box and the unwrapped text with `on_size_change`, since gpui-kit has no text measuring. Text wider than its box rests 1.5 s at its start, glides to its end at a constant 30 px/s through a native `.transition("left")`, rests again and glides back. A timer only turns it around, once per leg. The first build used `.loop("left")` with ease-in-out: its peak speed was about three times the average and its ends crawled a pixel at a time, which read as stutter.
- `cmd-alt-l` opens the list as the same popup the list button opens, placed where the list button sits. That spot is computed from the layout's block sizes and the viewport.
- macOS is the only backend in v1. It lives in `native/macos/` and uses MediaRemote.
- Linux (MPRIS) and Windows (GSMTC) come later, once there are users on them.
- We build our own helper instead of requiring `brew install media-control`, so the mod has no package dependency.
- The Spotify Web API was rejected. Since February 2026 its dev-mode rules cap an app at 5 users, and both the owner and the controlling user need Premium.

## How the macOS backend works

- Since macOS 15.4, MediaRemote checks entitlements. A normally compiled binary gets empty data.
- `/usr/bin/perl` is entitled. `native/macos/nowplaying.pl` loads our dylib into it through DynaLoader and calls `nowplaying_main`. The technique comes from ungive/mediaremote-adapter.
- `get [art-dir]` lists clients with `MRMediaRemoteGetNowPlayingClients` and reads each one with `MRMediaRemoteGetNowPlayingInfoForPlayer` on a path from `MRNowPlayingPlayerPathCreate`. A client without a title is left out. `elected` is the bundle of `MRMediaRemoteGetNowPlayingApplicationPID`.
- Artwork is one file per session, `<bundle>-<content hash>.jpg|png`. A new picture is a new path, so `image()` never shows a stale cache. After each `get`, files no session uses are removed, except a session's last one while its next picture is still on the way.
- `send <command-id> [bundle]` sends 0 play, 1 pause, 2 toggle, 4 next, 5 previous. With a bundle it uses `MRMediaRemoteSendCommandToPlayer` on that app's active player path. Without one it uses `MRMediaRemoteSendCommand`, which goes to the elected app.
- Music and Spotify skip MediaRemote for commands. `backend.js` sends them `osascript -e 'tell application id "<bundle>" to playpause'` (or `play`, `pause`, `next track`, `previous track`) and marks them controllable, because AppleScript reaches them whichever app is elected. If the script fails, such as when the person denied Automation access, the send falls back to MediaRemote.
- Verified on macOS 27.2: reading with Apple Music, Spotify and Chrome, targeted control with Apple Music, and AppleScript control of Music and Spotify while another app is elected. Podcasts: picked from the list, dimmed while not elected, and paused and resumed through MediaRemote while elected.

## Gotchas

- herdr-app does not render `svg()` icons from a symlinked mod folder. `image()` files under `data/` work either way. That is why `install.sh` copies the mod.
- Artwork arrives 1 to 2 seconds after a track change. The mod keeps the session's last picture while it is the same track.
- MediaRemote lists every app with a session, including paused ones, and keeps the last active app elected while it is paused.
- Only an active player path takes a targeted command. A paused browser tab is listed with full info, but a command sent to its path, its app or its client object reaches the elected player instead. The backend refuses that send (exit 4). `get` marks each session `controllable` when it has an active player, and the block dims the controls of one that isn't, so a press and a hotkey do nothing. Clicking the artwork still opens that app. In practice the active player is always the elected app alone. A Chrome tab that keeps playing after Music is started and paused stays listed but uncontrollable, and Music stays elected while paused. The election moves only when an app starts playing. `MRMediaRemoteSetNowPlayingPlayer` returns no error and changes nothing, and `MRMediaRemoteSetNowPlayingClientForOrigin` answers "Operation not permitted" from perl, so the mod cannot pick the elected app. A browser tab paused through MediaRemote can drop out of the list entirely, with no path left to resume it.
- The first AppleScript command to each app makes macOS ask whether Herdr may control it. Until the person answers, that `osascript` waits and the press does nothing. A command that starts playback, such as `play` or `playpause` on a paused app, also moves the election to that app. `pause` does not.
- Spotify starts playing on `next track` even while paused.
- A live stream reports an infinite duration. JSON cannot carry it, so `get` drops any non-finite number and the block shows no progress bar for that session.
- Sessions keep MediaRemote's client order, and `cycle` follows it.
- On macOS, Option changes the character a key types. `herdr-app do` proves each command, but not that `cmd-alt-.` and `cmd-alt-,` match a real press on every keyboard layout.

## Verify

Use the `verify-now-playing` skill in `.claude/skills/verify-now-playing/`. It drives the real media sessions, so it records each session's state before it starts and restores it afterward.
