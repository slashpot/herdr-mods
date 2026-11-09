# Security

The mod handles values that other apps control: a track title, a macOS bundle id from the playing app's Info.plist, a Windows AUMID, artwork bytes. None of them may pick a program to run, become script source, or choose where a file is written or deleted. The mod reaches no network, and the repo ships no prebuilt binary.

## Sub-features

- `sec-exec-argv` every `exec` names a literal program and passes values as argv, never through a shell. On macOS the program is an absolute path, so PATH can't swap it.
- `sec-applescript` `osascript` runs only for a bundle in `SCRIPTED`, so the interpolated `tell application id "…"` is always one of two fixed ids.
- `sec-powershell-file` the Windows helper runs with `-File`, so its arguments bind to `param()` as plain strings and are never evaluated.
- `sec-art-path` an artwork file name keeps only `[A-Za-z0-9._-]` of the bundle id (`safeName` in `nowplaying.m`, `SafeName` in `nowplaying.ps1`), so a bundle id like `../../x` stays inside `data/music-remote`.
- `sec-art-prune` pruning deletes only inside the artwork folder and keeps a waiting session's last picture by its cleaned name.
- `sec-install-scope` `install.sh` deletes only under `$dest`, which always ends in `mods/music-remote`.
- `sec-no-network` the mod makes no `fetch` or `hc` call: track data and artwork stay on the machine.
- `sec-no-binaries` `native/macos/bin/` is git-ignored; the dylib is built from `nowplaying.m` on install.

## How to get to it (user POV)

- There is nothing to see in the block. A person notices only when it fails, as a file outside `~/.config/herdr-app/data/music-remote/` or a program they didn't expect running.

## Driving it with mr-verify

Preconditions:

- Run from the repo root. The artwork harness needs macOS and `clang`; elsewhere it prints `skip`.

- **Run the check.** `.claude/skills/verify-music-remote/scripts/security-check`. Every line reads `ok` and it exits 0. Each `FAIL` names the file and line or the escaped path.
- **The artwork harness.** On macOS the script compiles a small program that includes `nowplaying.m`, calls `saveArtwork` with the bundle ids `../../evil`, `a/b` and `com.some-app` into a temp folder, then calls `pruneArtwork` with `../../evil` waiting for art. It passes when nothing named `evil` lands outside the art folder, the waiting session's file survives, and the unused ones are gone. It touches neither the person's window nor `data/music-remote`.
- **After a change.** Run it after any change to `main.js`, `native/`, or `install.sh`, alongside `$MR doctor`. A change that adds an `exec`, a file write, or a new value from the player needs a new line in the script, not only a read of the diff.

## Gotchas

- The script checks the source with grep, plus one compiled harness. It doesn't prove a property the grep can't see, such as a new `exec` whose program comes from a variable defined elsewhere. Read the diff for that too.
- `explorer.exe shell:AppsFolder\<aumid>` in the Windows `activate` is not checked. Whether a crafted AUMID makes explorer open something else is untested, and it needs a Windows run to settle.
- The expected art file names hard-code the SHA-1 prefix of the byte `x` (`11f6ad8ec52a2984`). Change the bytes and the names change with them.
