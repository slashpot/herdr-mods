# Now Playing verification map

The maintained verification list for the herdr-app Now Playing mod. Read this index, then use the matching feature file as the recipe. All commands assume `NP=.claude/skills/verify-now-playing/scripts/np-verify` from the repo root.

## Baseline preconditions

- macOS; herdr-app window running with layout `main-now-playing` (the person's window — there is no second instance).
- `$NP install` done for the commit under test, then `$NP doctor` exits 0.
- A player has a now-playing session: Music or Spotify has played at least one track since login. `$NP get` returns an object, not `null`.
- Record `$NP get before` and `$NP shot before` at the start of every run.

## Driving conventions

- Buttons are driven with `$NP send <command>`: the same call the click handler makes. A proof that needs the physical click asks the person to click.
- Wait for state (`$NP wait-rate`, or ≥ 2 s for one 1.5 s poll) before `$NP shot`.
- Restore playback to the `before` state, then `$NP cleanup`. Cleanup keeps `.verify/now-playing/<RUN_ID>/`.

## Proof and skip reporting

- Each step: the action, the backend JSON after it, and a `.block.png` you opened and described.
- The block must agree with the JSON (title, subtitle, icon vs `rate`, clocks).
- Report a path you could not reach (no player, no artwork, Linux) with the command tried and the unmet precondition. Do not report it as verified through another path.
- Say which steps went through `send` instead of a real click.

## Feature entry contract

Each feature file has an H1, one paragraph of user-visible behavior, then exactly four H2s: `Sub-features`, `How to get to it (user POV)`, `Driving it with np-verify`, `Gotchas`.

## Features

- [Track display](./track-display.md) — title, subtitle, artwork, progress and clocks; empty and error states.
- [Playback controls](./playback-controls.md) — play/pause toggle, next, previous.
- [Artwork and open player](./artwork-open-player.md) — artwork refresh on track change and clicking it to bring the player forward.
- [Narrow sidebar rail](./narrow-rail.md) — the compact block when the sidebar is under 160 px.
- [Install and reload](./install-reload.md) — building, copying and live reload with icons intact.
