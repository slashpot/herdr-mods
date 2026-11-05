# Install and reload

`now-playing/install.sh` builds the MediaRemote helper and copies the mod into herdr-app's mods folder; the running window reloads it by itself, with svg icons intact. A broken edit keeps the last good version running and reports an error in `herdr-app status`.

## Sub-features

- `install-build` `build.sh` produces a universal (arm64 + x86_64) `bin/libnowplaying.dylib`.
- `install-copy` the mod lands as a real folder (not a symlink) and `herdr-app check` passes.
- `install-reload` the window picks up a change without restart.
- `install-icons` play, pause, skip and note icons render (they don't through a symlinked folder).

## How to get to it (user POV)

- Run `now-playing/install.sh` from the repo (or `$NP install`).

## Driving it with np-verify

Preconditions:

- Xcode Command Line Tools installed (`xcode-select -p` succeeds).

- **Install.** Run `$NP install`. Ends with `built bin/libnowplaying.dylib` and a passing check, exit 0.
- **Universal binary.** Run `lipo -archs ~/.config/herdr-app/mods/now-playing/bin/libnowplaying.dylib`. Prints `x86_64 arm64`.
- **Healthy.** Run `$NP doctor`. Exit 0, `installed copy matches the repo`, `status errors: none`.
- **Reload.** Make a visible, harmless edit only if the task is a change under test (for example the one being verified), install, wait 2 s, `$NP shot reloaded`. The block shows the change with no restart.
- **Icons.** In the latest `.block.png`, the three control icons are drawn (not blank squares).

## Gotchas

- Never symlink the mod folder into `mods/`: svg icons silently stop rendering.
- A passing `herdr-app check` does not lay out the mod or run async states; the window shot is still required.
- A broken install leaves the old version on screen. Check `herdr-app status` errors, don't trust the picture alone.
