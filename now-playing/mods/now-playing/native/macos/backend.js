// The macOS backend: MediaRemote through /usr/bin/perl (see nowplaying.m),
// plus AppleScript for the players that take it. Everything the mod knows
// about macOS lives in this folder; main.js only sees the backend shape
// documented there.

import { exec, appHome } from "herdr";

const HERE = "mods/now-playing/native/macos"; // under appHome()
const ART_DIR = "data/now-playing"; // under appHome(); image() paths are relative to it
const COMMAND_ID = { play: 0, pause: 1, toggle: 2, next: 4, previous: 5 }; // MRCommand

// MediaRemote only commands the elected app. These apps take the same commands
// over AppleScript whichever app is elected, so they always go that way.
const SCRIPTED = new Set(["com.apple.Music", "com.spotify.client"]);
// Rows of these apps switch the block on click. Podcasts has no AppleScript,
// so its controls still work only while it is elected.
const PICKABLE = new Set([...SCRIPTED, "com.apple.podcasts"]);
const VERB = { play: "play", pause: "pause", toggle: "playpause", next: "next track", previous: "previous track" };

function helper(...rest) {
  const home = appHome();
  return [`${home}/${HERE}/nowplaying.pl`, `${home}/${HERE}/bin/libnowplaying.dylib`, ...rest];
}

export default {
  // MediaRemote shows a pause about 100 ms after the player takes it.
  settleMs: 400,

  async get() {
    const r = await exec("/usr/bin/perl", helper("get", `${appHome()}/${ART_DIR}`));
    if (r.code !== 0) throw new Error(r.stderr.trim() || `exit ${r.code}`);
    const read = JSON.parse(r.stdout);
    for (const s of read.sessions) {
      if (SCRIPTED.has(s.bundle)) s.controllable = true;
      s.pickable = PICKABLE.has(s.bundle);
      if (s.art) s.art = `${ART_DIR}/${s.art}`;
    }
    return read;
  },

  async send(command, bundle) {
    // A denied Automation permission fails the script; MediaRemote still reaches the elected app.
    if (SCRIPTED.has(bundle)) {
      const r = await exec("/usr/bin/osascript", ["-e", `tell application id "${bundle}" to ${VERB[command]}`]);
      if (r.code === 0) return;
    }
    await exec("/usr/bin/perl", helper("send", String(COMMAND_ID[command]), ...(bundle ? [bundle] : [])));
  },

  async activate(track) {
    if (track?.bundle) await exec("/usr/bin/open", ["-b", track.bundle]);
  },
};
