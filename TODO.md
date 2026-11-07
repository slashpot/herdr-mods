# TODO

## now-playing

- [ ] Linux backend via MPRIS, once there are Linux users
- [ ] Windows backend via GSMTC. In progress: develop it on the Windows machine, with Claude Code running there.

### Windows backend plan

Read `now-playing/README.md` first, especially Design: it states the backend interface.

- **Where it plugs in.** Add `native/windows/backend.js` and register it in `main.js` as `BACKENDS = { macos, windows }`. `window().platform` returns `"windows"` there. Everything that knows Windows stays in `native/windows/`; `main.js` must not name an AUMID or a Windows API.
- **Field mapping to GSMTC** (`GlobalSystemMediaTransportControlsSessionManager`):
  - `bundle` is the session's `SourceAppUserModelId` (AUMID). It is the shared pin's value too.
  - `elected` is the AUMID of `GetCurrentSession()`, or null.
  - `controllable` and `pickable` are true for every session. Unlike MediaRemote, GSMTC can command any session.
  - `art` is an `image()` path relative to `appHome()`. Read `TryGetMediaPropertiesAsync().Thumbnail` and write one file per session under `data/now-playing/`, named by content hash like the macOS backend, so a new picture gets a new path. Remove files no session uses.
  - `elapsed`, `duration` and `timestamp` come from `GetTimelineProperties()`: `Position`, `EndTime - StartTime`, `LastUpdatedTime` in Unix seconds. `rate` is 0 unless `PlaybackStatus` is Playing.
  - `activate` opens the app with `explorer shell:AppsFolder\<AUMID>`.
  - `settleMs` is measured on the machine, not copied from macOS.
- **Send `play` or `pause`, never a toggle.** `main.js` already turns a toggle into whichever the button shows (commit c354647). Map them to `TryPlayAsync` and `TryPauseAsync`, and next and previous to `TrySkipNextAsync` and `TrySkipPreviousAsync`.
- **Helper.** Start with a Windows PowerShell 5.1 script. It needs no build and no package, and it can reach WinRT; PowerShell 7 cannot. Measure its start-up time against the 1500 ms poll. If it is too slow, switch to a small compiled helper.
- **Install.** `install.sh` is POSIX sh and maps non-Darwin, non-Linux to `windows`. It runs `native/windows/build.sh` when that exists. It needs Git Bash on Windows; decide whether to add an `install.ps1`.
- **Verify.** `.claude/skills/verify-now-playing/` is macOS only (sips, osascript, `/usr/bin/perl`). Add Windows support for the same checks before calling the backend done: install, doctor, get, drive each command through `herdr-app do now-playing.<command>`, and shot.
