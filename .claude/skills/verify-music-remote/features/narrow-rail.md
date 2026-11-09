# Narrow sidebar rail

When the sidebar is narrower than 160 px (the same rule as workspace-chrome's rail) the block collapses to the artwork above a single play/pause button, and message states show only the note icon.

## Sub-features

- `rail-compact` sidebar < 160 px: 36 px artwork and the toggle, no text, no bar, no prev/next.
- `rail-restore` back above 160 px: the full block returns.

## How to get to it (user POV)

- Narrow the sidebar (or use a layout whose sidebar is a rail). `main-music-remote` sets `resizable: false`, so the person's route is a layout edit or `layout.resize`.

## Driving it with mr-verify

Preconditions:

- `$MR doctor` exits 0; a track is loaded.

- **Collapse.** Run `$MR sidebar 120`, wait 1 s, `$MR shot rail`. `rail.block.png` shows only the cover and one play/pause icon.
- **Toggle from the rail.** Optional: `$MR do toggle` + `wait-rate`, `$MR shot rail-toggled`; the one icon flips. Toggle back.
- **Restore.** Run `$MR cleanup` (it puts back the width `sidebar` recorded), then `$MR shot wide`; the full block is back. Don't restore with `$MR sidebar 268`: 268 is the layout file's default, and the person's live width in `layouts/.state/main-music-remote.json` may differ.

## Gotchas

- `layout.resize` is saved in `layouts/.state/main-music-remote.json`: the helper records the original width and cleanup restores it. Don't skip cleanup.
- The other sidebar mods also collapse at this width; the screenshot crop still covers the right area.
