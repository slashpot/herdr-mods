// Now Playing: a remote for whatever the system is playing (Apple Music,
// Spotify, YouTube in a browser, ...), not tied to any one player.
//
// The UI only knows the track shape below; where it comes from is a backend
// per OS. macOS is the only backend so far: MediaRemote through /usr/bin/perl
// (see native/nowplaying.m). A backend's get() returns every app that has a
// session, plus the one the OS elected:
//   { elected: bundle | null, sessions: Track[] }
//   Track = { title, artist, album, app, bundle, duration, elapsed, rate, timestamp, art, id }
// The block shows current(): the session the person picked (shared PIN, so
// every copy agrees), else the elected one, else one that is playing.

import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { exec, theme, appHome, window, layout, shared, setShared, props, nextCommand } from "herdr";

const MOD = "mods/now-playing";
const ART_DIR = "data/now-playing"; // under appHome(); image() paths are relative to it
const POLL_MS = 1500;
const COMMAND = { play: 0, pause: 1, toggle: 2, next: 4, previous: 5 };
const PIN = "now-playing.pinned";
const MARQUEE_PX_PER_S = 30;
const MARQUEE_MIN_MS = 4000;

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar collapses to a rail by width (same rule as workspace-chrome).
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

const macos = {
  args(...rest) {
    const home = appHome();
    return [`${home}/${MOD}/native/nowplaying.pl`, `${home}/${MOD}/bin/libnowplaying.dylib`, ...rest];
  },
  async get() {
    const r = await exec("/usr/bin/perl", this.args("get", `${appHome()}/${ART_DIR}`));
    if (r.code !== 0) throw new Error(r.stderr.trim() || `exit ${r.code}`);
    return JSON.parse(r.stdout);
  },
  async send(command, bundle) {
    await exec("/usr/bin/perl", this.args("send", String(COMMAND[command]), ...(bundle ? [bundle] : [])));
  },
  async activate(track) {
    if (track?.bundle) await exec("open", ["-b", track.bundle]);
  },
};

const sameTrack = (a, b) => a && b && a.title === b.title && a.artist === b.artist && a.bundle === b.bundle;

function position(track) {
  if (!track?.duration) return 0;
  const drift = track.timestamp ? (Date.now() / 1000 - track.timestamp) * (track.rate ?? 0) : 0;
  return Math.min(track.duration, Math.max(0, (track.elapsed ?? 0) + drift));
}

function clock(seconds) {
  const s = Math.floor(seconds);
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = String(s % 60).padStart(2, "0");
  return h ? `${h}:${String(m).padStart(2, "0")}:${r}` : `${m}:${r}`;
}

export default class NowPlaying extends View {
  init(_props, cx) {
    this.sessions = [];
    this.elected = null;
    this.widths = new Map(); // element id -> laid-out width, for the marquee
    this.error = null;
    this.loading = true;
    this.backend = window()?.platform === "macos" ? macos : null;
    if (!this.backend) return;
    this.refresh(cx);
    cx.timer.every(POLL_MS, (cx) => this.refresh(cx));
    // keys.json and `herdr-app do now-playing.<command>` reach every copy of
    // the mod; only the sidebar block answers, so a key never acts twice.
    if (props()?.view !== "sessions") {
      cx.spawn(async (cx) => {
        for (;;) {
          this.hotkey(await nextCommand(), cx);
          cx.notify();
        }
      });
    }
    // Moves the progress bar between polls; nothing to redraw while paused.
    cx.timer.every(1000, (cx) => { if (this.current()?.rate) cx.notify(); });
  }

  current() {
    const find = (bundle) => bundle && this.sessions.find((s) => s.bundle === bundle);
    return find(shared(PIN)) ?? find(this.elected) ?? this.sessions.find((s) => s.rate > 0) ?? this.sessions[0] ?? null;
  }

  refresh(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const { elected, sessions } = await this.backend.get();
        const last = new Map(this.sessions.map((s) => [s.bundle, s]));
        // Artwork lands a second or two after a track change: keep the last
        // picture while it's the same track, rather than flashing the placeholder.
        for (const s of sessions) {
          const before = last.get(s.bundle);
          if (!s.art && sameTrack(s, before)) s.art = before.art;
        }
        this.sessions = sessions;
        this.elected = elected;
        this.error = null;
        const pinned = shared(PIN);
        if (pinned && !sessions.some((s) => s.bundle === pinned)) setShared(PIN, null);
      } catch (e) {
        this.error = String(e?.message ?? e);
      }
      this.busy = false;
      this.loading = false;
      cx.notify();
    });
  }

  hotkey(name, cx) {
    if (name in COMMAND) this.command(name, cx);
    else if (name === "cycle") this.cycle();
  }

  cycle() {
    if (this.sessions.length < 2) return;
    const at = this.sessions.indexOf(this.current());
    setShared(PIN, this.sessions[(at + 1) % this.sessions.length].bundle);
  }

  command(name, cx) {
    const target = this.current();
    // Answer the click at once; the next read confirms it.
    if (target && (name === "toggle" || name === "play" || name === "pause")) {
      const playing = name === "toggle" ? !target.rate : name === "play";
      const flipped = { ...target, elapsed: position(target), timestamp: Date.now() / 1000, rate: playing ? 1 : 0 };
      this.sessions = this.sessions.map((s) => (s === target ? flipped : s));
      cx.notify();
    }
    cx.spawn(async (cx) => {
      await this.backend.send(name, target?.bundle);
      cx.timer.after(400, (cx) => this.refresh(cx));
    });
  }

  measure(id) {
    return (size, cx) => {
      const width = Math.round(size.width);
      if (this.widths.get(id) === width) return;
      this.widths.set(id, width);
      cx.notify();
    };
  }

  // gpui-kit has no text measuring, so the clip box and the unwrapped text
  // report their laid-out widths; text wider than its box swings to show its end.
  marquee(id, text, style) {
    const overflow = (this.widths.get(`${id}-text`) ?? 0) - (this.widths.get(`${id}-box`) ?? Infinity);
    const label = style(div().id(`${id}-text`).flex_none().whitespace_nowrap().relative())
      .on_size_change(this.measure(`${id}-text`))
      .when(overflow > 1, (el) => el.loop("left", {
        from: 0,
        to: -overflow,
        period: Math.max(MARQUEE_MIN_MS, (2000 * overflow) / MARQUEE_PX_PER_S),
        easing: "ease-in-out",
      }))
      .child(text);
    return h_flex().id(`${id}-box`).w_full().min_w(0).overflow_hidden()
      .on_size_change(this.measure(`${id}-box`))
      .child(label);
  }

  button(id, icon, size, action) {
    const t = theme();
    return div().id(id).size(size + 12).flex_none().flex().items_center().justify_center().rounded_full()
      .text_color(t.muted).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => this.command(action, cx))
      .child(svg(`${MOD}/icons/${icon}.svg`).size(size));
  }

  artwork(size) {
    const t = theme();
    const track = this.current();
    return div().id("art").size(size).flex_none().rounded(6).overflow_hidden().bg(t.hover)
      .flex().items_center().justify_center().text_color(t.dim)
      .when(Boolean(track?.bundle), (el) => el.cursor_pointer()
        .on_click((_e, cx) => cx.spawn(async () => { await this.backend.activate(track); })))
      .child(track?.art ? image(`${ART_DIR}/${track.art}`).size(size) : svg(`${MOD}/icons/music.svg`).size(size * 0.45));
  }

  message(text) {
    const t = theme();
    return h_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(12).gap(8).items_center()
      .text_size(12).text_color(t.dim)
      .child(svg(`${MOD}/icons/music.svg`).size(14).flex_none())
      .when(!narrow(), (el) => el.child(div().flex_1().min_w(0).truncate().child(text)));
  }

  render() {
    const t = theme();
    if (!this.backend) return this.message("Now Playing supports macOS only for now");
    if (this.error) return this.message(`Now Playing: ${this.error}`);
    const track = this.current();
    if (!track) return this.message(this.loading ? "" : "Nothing playing");

    const playing = Boolean(track.rate);
    const toggle = this.button("toggle", playing ? "pause" : "play", 16, "toggle");

    if (narrow()) {
      return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).py(8).gap(6).items_center()
        .child(this.artwork(36)).child(toggle);
    }

    const at = position(track);
    const pct = track.duration ? `${((at / track.duration) * 100).toFixed(2)}%` : "0%";
    const subtitle = [track.artist, track.album].filter(Boolean).join(" — ") || track.app || "";

    return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(12).pt(10).pb(6).gap(8)
      .child(h_flex().gap(10).items_center()
        .child(this.artwork(44))
        .child(v_flex().flex_1().min_w(0).gap(2)
          .child(this.marquee("title", track.title, (el) => el.text_size(13).font_medium().text_color(t.foreground)))
          .child(this.marquee("subtitle", subtitle, (el) => el.text_size(12).text_color(t.muted)))))
      .when(Boolean(track.duration), (el) => el.child(v_flex().gap(3)
        .child(div().h(3).w_full().rounded(2).bg(t.border).overflow_hidden()
          .child(div().h_full().w(pct).rounded(2).bg(t.accent)))
        .child(h_flex().justify_between().text_size(10).text_color(t.dim)
          .child(div().child(clock(at))).child(div().child(clock(track.duration))))))
      .child(h_flex().justify_center().items_center().gap(14)
        .child(this.button("previous", "skip-back", 14, "previous"))
        .child(toggle)
        .child(this.button("next", "skip-forward", 14, "next")));
  }
}
