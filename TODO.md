# TODO

## now-playing

- [ ] Linux backend via MPRIS, once there are Linux users
- [ ] Windows: try the hotkeys with real presses. `cmd` is the Windows key there, and Windows reserves some Win+Alt combinations.
- [ ] Windows: click the artwork for Chrome. `explorer shell:AppsFolder\Chrome` may open a new window instead of bringing the playing one forward. Spotify's came forward.
- [ ] Windows: find out whether a crafted AUMID makes `explorer.exe shell:AppsFolder\<aumid>` in `activate` open something other than the app. Any app can set its own AUMID. If it can, call explorer only for AUMIDs shaped like `Package!App` or a plain name, and add the check to `scripts/security-check`.
- [ ] Windows: `np-verify shot` crops the wrong rectangle while the window is maximized, because `window.json` keeps the restored bounds. macOS does not show this: after `window.maximize` there, `window.json` holds the new size. One fix is to take the scale from the window's DPI (`GetDpiForWindow` / 96) in `crop.ps1` instead of from the bounds.
- [ ] Windows: run `install.sh` once on a home without `layouts/main-now-playing.json`. The step that makes the layout was only run on macOS.
