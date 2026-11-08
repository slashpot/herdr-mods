# TODO

## now-playing

- [ ] Linux backend via MPRIS, once there are Linux users
- [ ] Re-verify on macOS. The Windows work touched shared files that only a Mac can prove: `main.js` now imports `native/windows/backend.js` too, `install.sh` falls back to tar without rsync and to `python` when `python3` doesn't run, and `np-verify` scales the shot crop by herdr's zoom. Run the `verify-now-playing` skill there.
- [ ] Windows: try the hotkeys with real presses. `cmd` is the Windows key there, and Windows reserves some Win+Alt combinations.
- [ ] Windows: click the artwork for Chrome. `explorer shell:AppsFolder\Chrome` may open a new window instead of bringing the playing one forward. Spotify's came forward.
- [ ] `install.sh` doesn't make the `main-now-playing` layout. On a new machine it has to be made by hand (see the Windows section of the verify skill).
