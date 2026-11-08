#!/bin/sh
# Builds this OS's backend helper, copies the mod into herdr-app's mods folder
# and adds the mod's hotkeys to keys.json. herdr-app reloads both by itself.
# A copy, not a symlink: herdr-app doesn't load svg() icons through a symlinked mod folder.
set -eu
cd "$(dirname "$0")"
case "$(uname -s)" in
  Darwin) platform=macos ;;
  Linux) platform=linux ;;
  *) platform=windows ;;
esac
if [ -x "native/$platform/build.sh" ]; then
  "native/$platform/build.sh"
else
  echo "no backend for $platform yet; installing anyway, the block will say so"
fi
home="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
dest="$home/mods/now-playing"
[ -L "$dest" ] && rm "$dest"
mkdir -p "$dest"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude .git --exclude .gitignore --exclude install.sh ./ "$dest/"
else
  # Git Bash on Windows has no rsync: empty the copy and unpack a fresh one.
  find "$dest" -mindepth 1 -delete
  tar -cf - --exclude .git --exclude .gitignore --exclude install.sh . | tar -xf - -C "$dest"
fi
herdr-app check "$dest"

# Adds only keys the person hasn't bound, and writes nothing when there is
# nothing to add: any edit makes keys.json theirs, which stops herdr-app from
# upgrading its default shortcuts.
# Windows may have only `python`, and a `python3` that is the Microsoft Store stub.
python=python3
command -v python3 >/dev/null 2>&1 && python3 -c '' >/dev/null 2>&1 || python=python
"$python" - keys.json "$home/keys.json" <<'PY'
import json, os, sys
ours_path, path = sys.argv[1], sys.argv[2]
ours = json.load(open(ours_path))
if not os.path.exists(path):
    print(f"keys: {path} does not exist; add the bindings in {ours_path} by hand")
    sys.exit(0)
theirs = json.load(open(path))
added = []
for section, binds in ours.items():
    have = theirs.setdefault(section, {})
    for key, action in binds.items():
        if have.get(key) == action:
            continue
        if key in have:
            print(f"keys: skipped {key} -> {action}: {section} already binds it to {json.dumps(have[key])}")
        elif action in have.values():
            print(f"keys: skipped {key} -> {action}: {section} already binds {action} to another key")
        else:
            have[key] = action
            added.append(f"{key} -> {action}")
if not added:
    print("keys: nothing to add")
    sys.exit(0)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(theirs, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
for line in added:
    print(f"keys: added {line}")
PY
