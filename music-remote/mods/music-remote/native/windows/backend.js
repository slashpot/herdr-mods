// The Windows backend: GSMTC (GlobalSystemMediaTransportControlsSessionManager)
// through Windows PowerShell 5.1 (see nowplaying.ps1). Everything the mod knows
// about Windows lives in this folder; main.js only sees the backend shape
// documented there. bundle is the session's AUMID (SourceAppUserModelId).

import { exec, appHome } from "herdr";

const HERE = "mods/music-remote/native/windows"; // under appHome()
const ART_DIR = "data/music-remote"; // under appHome(); image() paths are relative to it
// PowerShell 7 (pwsh) cannot reach WinRT; Windows PowerShell 5.1 can, and ships with Windows.
const POWERSHELL = "powershell.exe";

// App names never change for an AUMID, and looking one up is the slowest part
// of a read, so each is asked for once.
const names = new Map();

function helper(...rest) {
  return ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", `${appHome()}/${HERE}/nowplaying.ps1`, ...rest];
}

export default {
  // Measured on Windows 11 (26200): GSMTC reports a play or pause from Chrome
  // about 35 ms after the command, from Spotify 700 to 860 ms after. A read
  // queries GSMTC about 300 ms into its PowerShell start, so the read after
  // settleMs lands about 1.1 s after the command.
  settleMs: 800,

  async get() {
    const r = await exec(POWERSHELL, helper("get", `${appHome()}/${ART_DIR}`, [...names.keys()].join("|")));
    if (r.code !== 0) throw new Error(r.stderr.trim() || `exit ${r.code}`);
    const read = JSON.parse(r.stdout);
    for (const s of read.sessions) {
      if (s.app) names.set(s.bundle, s.app);
      else s.app = names.get(s.bundle);
      if (s.art) s.art = `${ART_DIR}/${s.art}`;
    }
    return read;
  },

  async send(command, bundle) {
    await exec(POWERSHELL, helper("send", command, ...(bundle ? [bundle] : [])));
  },

  async activate(track) {
    if (track?.bundle) await exec("explorer.exe", [`shell:AppsFolder\\${track.bundle}`]);
  },
};
