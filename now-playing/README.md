# Now Playing

A herdr-app sidebar block that controls whatever the system is playing, such as Apple Music, Spotify, or YouTube in a browser. It shows artwork, title, artist, album and progress, with previous, play/pause and next buttons.

## Install

```sh
./install.sh
```

This builds `bin/libnowplaying.dylib` with clang (arm64 + x86_64, needs the Xcode Command Line Tools), copies the mod into herdr-app's mods folder, and runs `herdr-app check`. herdr-app reloads the mod by itself.

The mod uses the `main-now-playing` layout. It is a clone of `main` with a 132px `now-playing` block between `agents` and `sidebar-footer`.

## Design

The UI only knows one track shape. Each OS gets its own data backend that produces it. See the top of `main.js` for the shape.

- macOS is the only backend in v1. It uses MediaRemote.
- Linux (MPRIS) and Windows (GSMTC) come later, once there are users on them.
- We build our own helper instead of requiring `brew install media-control`, so the mod has no package dependency.
- The Spotify Web API was rejected. Since February 2026 its dev-mode rules cap an app at 5 users, and both the owner and the controlling user need Premium.

## How the macOS backend works

- Since macOS 15.4, MediaRemote checks entitlements. A normally compiled binary gets empty data.
- `/usr/bin/perl` is entitled. `native/nowplaying.pl` loads our dylib into it through DynaLoader and calls `nowplaying_main`. The technique comes from ungive/mediaremote-adapter.
- Commands sent through `send` are 0 play, 1 pause, 2 toggle, 4 next, 5 previous.
- Verified on macOS 27.2 with Apple Music and Spotify.

## Gotchas

- herdr-app does not render `svg()` icons from a symlinked mod folder. `image()` files under `data/` work either way. That is why `install.sh` copies the mod.
- Artwork arrives 1 to 2 seconds after a track change. The mod re-fetches until it is present.
- MediaRemote reports only one now-playing app. It stays on the last active app even while that app is paused.

## Verify

Use the `verify-now-playing` skill in `.claude/skills/verify-now-playing/`. It drives the real media session, so it records the state before it starts and restores it afterward.
