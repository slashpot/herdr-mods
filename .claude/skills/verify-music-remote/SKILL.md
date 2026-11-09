---
name: verify-music-remote
description: Verify the herdr-app "Music Remote" mod (music-remote/, a media remote in the herdr-app sidebar, macOS MediaRemote or Windows GSMTC) in the person's running Herdr window — install it, doctor the instance, drive play/pause/next/previous through the mod's own backend, and capture window shots of the sidebar block as proof. Use after any change to music-remote/mods/music-remote/ (main.js, native/macos/, native/windows/, icons/), music-remote/install.sh, music-remote/keys.json or the main-music-remote layout, or when asked to prove the mod works.
---

# Verify the Music Remote mod

The surface is a block at the bottom of herdr-app's sidebar (layout `main-music-remote`): artwork, a title and `artist — album` that scroll when too long, a progress bar with clocks, three icon buttons (previous, play/pause toggle, next) and, with several sessions, a list button that opens a popup of every session. Global keys in `keys.json` drive the same commands through the mod's `nextCommand()`. On macOS its data comes from MediaRemote through `/usr/bin/perl` loading `native/macos/bin/libnowplaying.dylib` (`native/macos/nowplaying.pl`), wrapped by `native/macos/backend.js`. Those paths, and the Windows ones, are under the mod folder `music-remote/mods/music-remote/`; `install.sh` and `keys.json` sit one level up, in `music-remote/`. On Windows it comes from GSMTC through Windows PowerShell 5.1 running `native/windows/nowplaying.ps1`, wrapped by `native/windows/backend.js` (see [Windows](#windows)). The only other surface is that backend CLI, which the helper wraps.

All commands below run from the repo root. The helper is
`.claude/skills/verify-music-remote/scripts/mr-verify` (call it `MR` below):

```sh
MR=.claude/skills/verify-music-remote/scripts/mr-verify
$MR              # prints the usage block
```

## Ground rules (read before driving)

- **There is one window and one media session, and both are the person's.** herdr-app keeps one window per `HERDR_APP_HOME`, and MediaRemote is system-wide: there is no isolated instance. `play`/`next` play real audio in the person's player. Record the state with `$MR sessions` and `$MR get before` first, and put it back before cleanup: every session's track playing or paused as it was.
- **Never synthesize pointer or key events on the display** (herdr-app's own `--skill` forbids it). `$MR do <command>` runs `herdr-app do music-remote.<command>`, the path a `keys.json` binding takes, into the block's own `command()`, the same one the buttons call. That is the default way to drive the controls. `command()` sends Music and Spotify their commands over AppleScript and everything else through MediaRemote. `$MR send <command> <bundle>` is MediaRemote only, so it matches the mod for other apps, and for Music or Spotify only while that app is elected. Otherwise it exits 4 (`has no active player`). Neither path exercises the click hit-target. When a proof needs the click itself (hover, hit area, optimistic icon flip), ask the person to click, then capture with `$MR shot`.
- **Never kill or restart herdr-app or herdr-core.** If the window isn't running, stop and ask.
- Do not drive while another agent is verifying this mod: two runs share the one media session.

## Launch

The window is already the person's. "Launch" means putting the current source into it:

```sh
$MR install      # music-remote/install.sh: clang build (arm64+x86_64) + rsync copy of music-remote/mods/music-remote/ into ~/.config/herdr-app/mods/music-remote + herdr-app check + keys.json merge
```

herdr-app reloads the mod by itself after the copy. When `layouts/main-music-remote.json` is missing, `install.sh` makes it from herdr's `main.json` and shows it. Ready = `$MR doctor` passes. If the layout shown isn't `main-music-remote`, ask before switching: `herdr-app do layout.switch --name main-music-remote`. There is no teardown for the install; it is the deliverable.

Needs Xcode Command Line Tools (`clang`). Something must have played in Music, Spotify or a browser since login, or `$MR sessions` prints `nothing playing` (see features/track-display.md).

## Doctor

```sh
$MR doctor       # read-only; exit 0 = worth driving
```

It checks macOS, `herdr-app` on PATH, a running window for `$HERDR_APP_HOME` (`herdr-app status`), no status errors, that the shown layout contains a `music-remote` block, that the mod is a copy (not a symlink: svg icons break) matching `music-remote/mods/music-remote/`, that the dylib is newer than `nowplaying.m`, that `herdr-app check` passes, that `keys.json` holds every binding in `music-remote/keys.json`, and that the backend `get` returns JSON, listing each session. Each FAIL line names its fix. Run it first, and again whenever anything looks off.

## Drive

| User action | Command | Observable result |
|---|---|---|
| Look at the block | `$MR shot <label>` | `<label>.block.png` (cropped block + footer) and `<label>.png` (whole window) |
| Ask what's playing | `$MR get <label>` | JSON `{elected, sessions: [{title, artist, album, app, bundle, duration, elapsed, rate, timestamp, art, id}]}` |
| List sessions | `$MR sessions` | one line per session, `*` on the elected one |
| Click play/pause, or press `cmd-alt-p` | `$MR do toggle`, then `$MR wait-rate 1 5 <bundle>` or `wait-rate 0 5 <bundle>` | that session's `rate` flips, no other's; the icon flips at once and the clock moves |
| Click next / previous, or `cmd-alt-.` / `cmd-alt-,` | `$MR do next` / `$MR do previous` | `title` changes; artwork follows 1–2 s later |
| Send to one session through MediaRemote | `$MR send <cmd> [bundle]` | prints `1`; no bundle sends to the elected session; exits 4 when that bundle has no active player (a non-elected Music or Spotify included: use `do` for those) |
| Press `cmd-alt-s` | `$MR do cycle` | the block shows the next session; `music-remote.pinned` in `shared.json` names it |
| Click the list button, or `cmd-alt-l` | `$MR do sessions` (opens the popup at the list button); close with `herdr-app do overlay.close` | a popup with one row per session, the shown one highlighted |
| Click a session row | ask the person | a Music, Spotify or Podcasts row is shown in the block and the popup closes; any other row does nothing |
| Check the bindings | `$MR keys` | `all bindings present in <home>/keys.json` |
| Click the artwork | ask the person (no command equivalent), or `open -b <bundle>` as the same call | the player app comes to the front |
| Narrow the sidebar | `$MR sidebar 120` (cleanup restores) | the block shows artwork + toggle only |
| Leave a note in the transcript | `$MR log <text>` | appended to `transcript.md` |

The mod polls every 1500 ms. After a `send`, wait for `wait-rate` or for the next poll (≥ 2 s) before `shot`; never shoot immediately.

The feature map in [features/README.md](features/README.md) is the verification list: one file per user behavior with exact steps and end states.

## Evidence

Everything lands in `.verify/music-remote/<RUN_ID>/` (git-ignored, survives cleanup): `transcript.md` (every helper call, timestamped), `get-<label>.json`, `<label>.png`, `<label>.block.png`. Set `RUN_ID=...` to name a run; otherwise the first call stamps one and later calls reuse it until cleanup.

Proof standards:

- Capture before and after: `get before` + `shot before`, the action, then `get after` + `shot after`. A single final screenshot is not proof.
- The visible block must agree with the backend JSON (title, play/pause icon vs `rate`, clocks vs `elapsed`/`duration`). Open the `.block.png` with Read and state what you saw.
- Side effects: a `send` must change the backend state (`rate`, `title`), not just the picture. Artwork proof includes the file under `~/.config/herdr-app/data/music-remote/` that the mod wrote.
- No mocks. The backend is the real MediaRemote; the window is the real app.
- Say plainly which parts were driven through `send` rather than a real click.

## Cleanup

1. Put playback back the way `sessions` and `get before` recorded it (`$MR send play|pause <bundle>` per session; `previous` after a `next`, then confirm with `$MR sessions`). Close any popup with `herdr-app do overlay.close`.
2. `$MR cleanup`: restores the sidebar width if this run changed it, removes the run's scratch artwork, forgets the current RUN_ID, and lists the evidence it kept.

It kills nothing. Never `pkill herdr*`, never quit Music/Spotify. The mod's own `data/music-remote/` is left alone.

## Windows

`mr-verify` runs in Git Bash on Windows. It picks the OS from `uname`, and every command above works the same way, with these differences:

- `herdr-app` must be on Git Bash's PATH. An install made after the shell started is not: prepend `$LOCALAPPDATA/Programs/herdr-app`.
- The backend is `powershell.exe -File native/windows/nowplaying.ps1` from the installed copy, the same call `backend.js` makes. `bundle` is the session's AUMID, such as `Chrome` or `SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify`. GSMTC takes a command for every session, so every line in `$MR sessions` is `ctl` and `$MR send <cmd> <aumid>` reaches that app whether or not it is elected. `send` exits 4 when no session has that AUMID.
- `install` has nothing to build: `native/windows/build.sh` only checks that Windows PowerShell 5.1 reaches GSMTC. Without rsync, `install.sh` copies with tar.
- `doctor` checks Windows PowerShell 5.1 instead of macOS and the dylib, and compares the installed copy ignoring CR, because herdr-app rewrites `gpui-kit.d.ts` there with CRLF line ends.
- `shot` crops with `scripts/crop.ps1` (System.Drawing). The scale includes herdr's zoom from `herdr-app status`.
- `scripts/scripted-control` and `scripts/marquee-motion` are macOS only (AppleScript, zsh, ffmpeg crop offsets). `scripts/list-toggle` runs on both.
- Spotify starts playing as soon as it is launched. Opening it for a second session changes what the person hears, so ask first and pause it afterward.
- Verified on Windows 11 (26200) with Chrome and Spotify: get, toggle both ways on each, next, previous, cycle, the list popup and `list-toggle`. Real key presses (`cmd` is the Windows key there) and the artwork click were not driven.

## Helpers

- `scripts/mr-verify`: the commands above (POSIX sh + system python3/osascript; no Homebrew needed).
- `scripts/marquee-motion`: samples window shots and prints the marquee text's position over time.
- `scripts/security-check`: the checks in features/security.md (exec, AppleScript, PowerShell, artwork paths, install scope, no network, no tracked binaries). Read-only; exit 0 when all pass.
- `scripts/list-toggle`: presses `sessions` through `herdr-app do` and counts open lists after each press.
- `scripts/crop.js`: JXA PNG crop used by `shot` on macOS (`osascript -l JavaScript crop.js <src> <out> <x> <y> <w> <h>`). `sips -c` ignores the offset on macOS 27, so don't use it.
- `scripts/crop.ps1`: the same crop on Windows, and with only `<src>` it prints the image height.

The crop rectangle comes from the shown layout: sidebar width (a resize click in `layouts/.state/<layout>.json` wins over the file) × the `music-remote` block plus every px block below it, scaled by herdr's zoom and by shot height / `window.json` bounds height.
