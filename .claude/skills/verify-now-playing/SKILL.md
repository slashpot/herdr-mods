---
name: verify-now-playing
description: Verify the herdr-app "Now Playing" mod (now-playing/, a macOS media remote in the herdr-app sidebar) in the person's running Herdr window — install it, doctor the instance, drive play/pause/next/previous through the mod's own MediaRemote backend, and capture window shots of the sidebar block as proof. Use after any change to now-playing/main.js, native/, icons/ or the main-now-playing layout, or when asked to prove the mod works.
---

# Verify the Now Playing mod

The surface is a block at the bottom of herdr-app's sidebar (layout `main-now-playing`): artwork, a title and `artist — album` that scroll when too long, a progress bar with clocks, three icon buttons (previous, play/pause toggle, next) and, with several sessions, a list button that opens a popup of every session. Global keys in `keys.json` drive the same commands through the mod's `nextCommand()`. Its data comes from macOS MediaRemote through `/usr/bin/perl` loading `bin/libnowplaying.dylib` (`native/nowplaying.pl`). The only other surface is that backend CLI, which the helper wraps.

All commands below run from the repo root. The helper is
`.claude/skills/verify-now-playing/scripts/np-verify` (call it `NP` below):

```sh
NP=.claude/skills/verify-now-playing/scripts/np-verify
$NP              # prints the usage block
```

## Ground rules (read before driving)

- **There is one window and one media session, and both are the person's.** herdr-app keeps one window per `HERDR_APP_HOME`, and MediaRemote is system-wide: there is no isolated instance. `play`/`next` play real audio in the person's player. Record the state with `$NP sessions` and `$NP get before` first, and put it back before cleanup: every session's track playing or paused as it was.
- **Never synthesize pointer or key events on the display** (herdr-app's own `--skill` forbids it). `$NP do <command>` runs `herdr-app do now-playing.<command>`, the path a `keys.json` binding takes, into the block's own handler. The buttons call the same `command()`, which runs `backend.send(<command>, <shown bundle>)`, so `$NP send <command> <bundle>` drives the backend call. It does not exercise the click hit-target. When a proof needs the click itself (hover, hit area, optimistic icon flip), ask the person to click, then capture with `$NP shot`.
- **Never kill or restart herdr-app or herdr-core.** If the window isn't running, stop and ask.
- Do not drive while another agent is verifying this mod: two runs share the one media session.

## Launch

The window is already the person's. "Launch" means putting the current source into it:

```sh
$NP install      # now-playing/install.sh: clang build (arm64+x86_64) + rsync copy into ~/.config/herdr-app/mods/now-playing + herdr-app check + keys.json merge
```

herdr-app reloads the mod by itself after the copy. Ready = `$NP doctor` passes. If the layout shown isn't `main-now-playing`, ask before switching: `herdr-app do layout.switch --name main-now-playing`. There is no teardown for the install; it is the deliverable.

Needs Xcode Command Line Tools (`clang`). Something must have played in Music, Spotify or a browser since login, or `$NP sessions` prints `nothing playing` (see features/track-display.md).

## Doctor

```sh
$NP doctor       # read-only; exit 0 = worth driving
```

It checks macOS, `herdr-app` on PATH, a running window for `$HERDR_APP_HOME` (`herdr-app status`), no status errors, that the shown layout contains a `now-playing` block, that the mod is a copy (not a symlink: svg icons break) matching the repo, that the dylib is newer than `nowplaying.m`, that `herdr-app check` passes, that `keys.json` holds every binding in `now-playing/keys.json`, and that the backend `get` returns JSON, listing each session. Each FAIL line names its fix. Run it first, and again whenever anything looks off.

## Drive

| User action | Command | Observable result |
|---|---|---|
| Look at the block | `$NP shot <label>` | `<label>.block.png` (cropped block + footer) and `<label>.png` (whole window) |
| Ask what's playing | `$NP get <label>` | JSON `{elected, sessions: [{title, artist, album, app, bundle, duration, elapsed, rate, timestamp, art, id}]}` |
| List sessions | `$NP sessions` | one line per session, `*` on the elected one |
| Click play/pause, or press `cmd-alt-p` | `$NP do toggle`, then `$NP wait-rate 1 5 <bundle>` or `wait-rate 0 5 <bundle>` | that session's `rate` flips, no other's; within ~1.5 s the icon flips and the clock moves |
| Click next / previous, or `cmd-alt-.` / `cmd-alt-,` | `$NP do next` / `$NP do previous` | `title` changes; artwork follows 1–2 s later |
| Send to one session directly | `$NP send <cmd> [bundle]` | prints `1`; no bundle sends to the elected session; exits non-zero when that bundle has no active player |
| Press `cmd-alt-s` | `$NP do cycle` | the block shows the next session; `now-playing.pinned` in `shared.json` names it |
| Click the list button, or `cmd-alt-l` | `$NP do sessions` (opens the popup at the list button); close with `herdr-app do overlay.close` | a popup with one row per session, the shown one highlighted |
| Click a session row | ask the person | nothing: the rows are read-only |
| Check the bindings | `$NP keys` | `all bindings present` |
| Click the artwork | ask the person (no command equivalent), or `open -b <bundle>` as the same call | the player app comes to the front |
| Narrow the sidebar | `$NP sidebar 120` (cleanup restores) | the block shows artwork + toggle only |
| Leave a note in the transcript | `$NP log <text>` | appended to `transcript.md` |

The mod polls every 1500 ms. After a `send`, wait for `wait-rate` or for the next poll (≥ 2 s) before `shot`; never shoot immediately.

The feature map in [features/README.md](features/README.md) is the verification list: one file per user behavior with exact steps and end states.

## Evidence

Everything lands in `.verify/now-playing/<RUN_ID>/` (git-ignored, survives cleanup): `transcript.md` (every helper call, timestamped), `get-<label>.json`, `<label>.png`, `<label>.block.png`. Set `RUN_ID=...` to name a run; otherwise the first call stamps one and later calls reuse it until cleanup.

Proof standards:

- Capture before and after: `get before` + `shot before`, the action, then `get after` + `shot after`. A single final screenshot is not proof.
- The visible block must agree with the backend JSON (title, play/pause icon vs `rate`, clocks vs `elapsed`/`duration`). Open the `.block.png` with Read and state what you saw.
- Side effects: a `send` must change the backend state (`rate`, `title`), not just the picture. Artwork proof includes the file under `~/.config/herdr-app/data/now-playing/` that the mod wrote.
- No mocks. The backend is the real MediaRemote; the window is the real app.
- Say plainly which parts were driven through `send` rather than a real click.

## Cleanup

1. Put playback back the way `sessions` and `get before` recorded it (`$NP send play|pause <bundle>` per session; `previous` after a `next`, then confirm with `$NP sessions`). Close any popup with `herdr-app do overlay.close`.
2. `$NP cleanup`: restores the sidebar width if this run changed it, removes the run's scratch artwork, forgets the current RUN_ID, and lists the evidence it kept.

It kills nothing. Never `pkill herdr*`, never quit Music/Spotify. The mod's own `data/now-playing/` is left alone.

## Helpers

- `scripts/np-verify`: the commands above (POSIX sh + system python3/osascript; no Homebrew needed).
- `scripts/marquee-motion`: samples window shots and prints the marquee text's position over time.
- `scripts/list-toggle`: presses `sessions` through `herdr-app do` and counts open lists after each press.
- `scripts/crop.js`: JXA PNG crop used by `shot` (`osascript -l JavaScript crop.js <src> <out> <x> <y> <w> <h>`). `sips -c` ignores the offset on macOS 27, so don't use it.

The crop rectangle comes from the shown layout: sidebar width (a resize click in `layouts/.state/<layout>.json` wins over the file) × the `now-playing` block plus every px block below it, scaled by shot height / `window.json` bounds height.
