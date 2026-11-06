// Now Playing: a remote for whatever the system is playing (Apple Music,
// Spotify, YouTube in a browser, ...), not tied to any one player.
//
// The UI only knows the track shape below; where it comes from is a backend
// per OS. macOS is the only backend so far: MediaRemote through /usr/bin/perl
// (see native/nowplaying.m). A backend's get() returns every app that has a
// session, plus the one the OS elected:
//   { elected: bundle | null, sessions: Track[] }
//   Track = { title, artist, album, app, bundle, duration, elapsed, rate, timestamp, art, id, controllable }
// controllable is false for an app the OS lists but won't take commands for
// (a browser tab that isn't the elected player): its controls are dimmed.
// The block shows current(): the session last cycled to or last started playing
// (shared PIN, so every copy agrees), else the elected one, else one that is playing.

import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { exec, theme, appHome, window, layout, shared, setShared, props, nextCommand, openOverlay, closeOverlay } from "herdr";

const MOD = "mods/now-playing";
const ART_DIR = "data/now-playing"; // under appHome(); image() paths are relative to it
const POLL_MS = 1500;
const COMMAND = { play: 0, pause: 1, toggle: 2, next: 4, previous: 5 };
const PIN = "now-playing.pinned";
const LIST = "now-playing.list"; // the open list overlay's id, so a second press closes it
const MARQUEE_PX_PER_S = 30;
const MARQUEE_PAUSE_MS = 1500;
const ROW_PX = 40;

// The layout nodes from the root down to the first one matching `is`.
function trail(node, is, up = []) {
  if (!node) return null;
  if (is(node)) return [...up, node];
  for (const child of node.children ?? []) {
    const found = trail(child, is, [...up, node]);
    if (found) return found;
  }
  return null;
}

// The sidebar collapses to a rail by width (same rule as workspace-chrome).
const narrow = () => (trail(layout(), (n) => n.id === "sidebar")?.at(-1)?.size?.px ?? Infinity) < 160;

// MediaRemote only commands the elected app. These apps take the same commands
// over AppleScript whichever app is elected, so they always go that way.
const SCRIPTED = new Set(["com.apple.Music", "com.spotify.client"]);
// Rows of these apps switch the block on click. Podcasts has no AppleScript,
// so its controls still work only while it is elected.
const PICKABLE = new Set([...SCRIPTED, "com.apple.podcasts"]);
const VERB = { play: "play", pause: "pause", toggle: "playpause", next: "next track", previous: "previous track" };

const macos = {
  args(...rest) {
    const home = appHome();
    return [`${home}/${MOD}/native/nowplaying.pl`, `${home}/${MOD}/bin/libnowplaying.dylib`, ...rest];
  },
  async get() {
    const r = await exec("/usr/bin/perl", this.args("get", `${appHome()}/${ART_DIR}`));
    if (r.code !== 0) throw new Error(r.stderr.trim() || `exit ${r.code}`);
    const read = JSON.parse(r.stdout);
    for (const s of read.sessions) if (SCRIPTED.has(s.bundle)) s.controllable = true;
    return read;
  },
  async send(command, bundle) {
    // A denied Automation permission fails the script; MediaRemote still reaches the elected app.
    if (SCRIPTED.has(bundle)) {
      const r = await exec("/usr/bin/osascript", ["-e", `tell application id "${bundle}" to ${VERB[command]}`]);
      if (r.code === 0) return;
    }
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
    this.listing = props()?.view === "sessions"; // this copy is the session list overlay
    this.sessions = [];
    this.elected = null;
    this.widths = new Map(); // element id -> laid-out width, for the marquee
    this.scrolls = new Map(); // marquee id -> { text, overflow, end, task }
    this.error = null;
    this.loading = true;
    this.backend = window()?.platform === "macos" ? macos : null;
    if (!this.backend) return;
    this.refresh(cx);
    cx.timer.every(POLL_MS, (cx) => this.refresh(cx));
    if (this.listing) return;
    // Moves the progress bar between polls; nothing to redraw while paused.
    cx.timer.every(1000, (cx) => { if (this.current()?.rate) cx.notify(); });
    // keys.json and `herdr-app do now-playing.<command>` reach every copy of
    // the mod; only the sidebar block answers, so a key never acts twice.
    cx.spawn(async (cx) => {
      for (;;) {
        this.hotkey(await nextCommand(), cx);
        cx.notify();
      }
    });
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
        // A session that starts playing takes over the block.
        // The first read has nothing to compare with, so it starts nothing.
        const started = this.loading ? null : sessions.find((s) => s.rate > 0 && !(last.get(s.bundle)?.rate > 0));
        this.sessions = sessions;
        this.elected = elected;
        this.error = null;
        const pinned = shared(PIN);
        if (started && !this.listing && started.bundle !== pinned) setShared(PIN, started.bundle);
        else if (pinned && !sessions.some((s) => s.bundle === pinned)) setShared(PIN, null);
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
    else if (name === "sessions") this.toggleSessions(this.listAnchor());
  }

  // Where the list button sits in the window, so the hotkey opens the list
  // where a click on that button would. Undefined falls back to the pointer.
  listAnchor() {
    const path = trail(layout(), (n) => n.content?.mod === "now-playing");
    if (!path || path.length < 3 || !this.viewport) return undefined;
    const [row, side, block] = path.slice(-3);
    const { width, height } = this.viewport;
    const below = side.children.slice(side.children.indexOf(block)).reduce((sum, c) => sum + (c.size?.px ?? 0), 0);
    const right = row.children?.[0] === side ? side.size?.px ?? 0 : width;
    return { x: right - 30, y: height - below + (block.size?.px ?? 0) - 20 };
  }

  toggleSessions(at) {
    const open = shared(LIST);
    if (open) {
      closeOverlay(open);
      setShared(LIST, null);
      return;
    }
    const height = 12 + 28 + Math.max(1, this.sessions.length) * ROW_PX;
    setShared(LIST, openOverlay({ mod: "now-playing", props: { view: "sessions" }, kind: "popup", at, width: 260, height }));
  }

  // Esc or a click beside the list closes it without a press here.
  async close() {
    if (this.listing && shared(LIST) === props().overlay) setShared(LIST, null);
  }

  pick(bundle) {
    setShared(PIN, bundle);
    closeOverlay(props().overlay);
  }

  cycle() {
    if (this.sessions.length < 2) return;
    const at = this.sessions.indexOf(this.current());
    setShared(PIN, this.sessions[(at + 1) % this.sessions.length].bundle);
  }

  command(name, cx) {
    const target = this.current();
    if (target?.controllable === false) return;
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

  measure(id, part, text) {
    return (size, cx) => {
      const width = Math.round(size.width);
      if (this.widths.get(`${id}-${part}`) === width) return;
      this.widths.set(`${id}-${part}`, width);
      this.scrollFor(id, text, cx);
      cx.notify();
    };
  }

  // Each leg glides at a constant speed, then rests at that end so its start
  // or end can be read. The movement is a native transition; the timer only
  // turns it around, once per leg.
  scrollFor(id, text, cx) {
    const overflow = (this.widths.get(`${id}-text`) ?? 0) - (this.widths.get(`${id}-box`) ?? Infinity);
    const last = this.scrolls.get(id);
    if (last?.text === text && last.overflow === overflow) return;
    last?.task?.cancel();
    const scroll = { text, overflow, end: false, task: null };
    this.scrolls.set(id, scroll);
    if (overflow <= 1) return;
    const leg = (overflow * 1000) / MARQUEE_PX_PER_S;
    const turn = (cx) => {
      scroll.end = !scroll.end;
      cx.notify();
      scroll.task = cx.timer.after(leg + MARQUEE_PAUSE_MS, turn);
    };
    scroll.task = cx.timer.after(MARQUEE_PAUSE_MS, turn);
  }

  // gpui-kit has no text measuring, so the clip box and the unwrapped text
  // report their laid-out widths.
  marquee(id, text, style) {
    const scroll = this.scrolls.get(id);
    const moving = scroll?.text === text && scroll.overflow > 1;
    const label = style(div().id(`${id}-text`).flex_none().whitespace_nowrap().relative())
      .on_size_change(this.measure(id, "text", text))
      .when(moving, (el) => el
        .transition("left", { duration: (scroll.overflow * 1000) / MARQUEE_PX_PER_S, easing: "linear" })
        .left(scroll.end ? -scroll.overflow : 0))
      .child(text);
    return h_flex().id(`${id}-box`).w_full().min_w(0).overflow_hidden()
      .on_size_change(this.measure(id, "box", text))
      .child(label);
  }

  button(id, icon, size, action) {
    const t = theme();
    const enabled = this.current()?.controllable !== false;
    return div().id(id).size(size + 12).flex_none().flex().items_center().justify_center().rounded_full()
      .when(enabled, (el) => el.text_color(t.muted).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click((_e, cx) => this.command(action, cx)))
      .when(!enabled, (el) => el.text_color(t.dim).opacity(0.4))
      .child(svg(`${MOD}/icons/${icon}.svg`).size(size));
  }

  sessionsButton() {
    const t = theme();
    return h_flex().id("sessions").absolute().right(0).h(26).px(6).gap(4).items_center().rounded(6)
      .text_size(11).text_color(t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(() => this.toggleSessions())
      .child(svg(`${MOD}/icons/list.svg`).size(13))
      .child(div().child(String(this.sessions.length)));
  }

  cover(track, size) {
    const t = theme();
    return div().size(size).flex_none().rounded(size > 30 ? 6 : 4).overflow_hidden().bg(t.hover)
      .flex().items_center().justify_center().text_color(t.dim)
      .child(track?.art ? image(`${ART_DIR}/${track.art}`).size(size) : svg(`${MOD}/icons/music.svg`).size(size * 0.45));
  }

  artwork(size) {
    const track = this.current();
    return div().id("art").flex_none()
      .when(Boolean(track?.bundle), (el) => el.cursor_pointer()
        .on_click((_e, cx) => cx.spawn(async () => { await this.backend.activate(track); })))
      .child(this.cover(track, size));
  }

  sessionRow(track, selected) {
    const t = theme();
    const playing = Boolean(track.rate);
    return h_flex().id(`session-${track.bundle}`).h(ROW_PX).flex_none().px(6).gap(8).items_center().rounded(6)
      .when(selected, (el) => el.bg(t.selected))
      .when(PICKABLE.has(track.bundle), (el) => el.cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click(() => this.pick(track.bundle)))
      .child(this.cover(track, 28))
      .child(v_flex().flex_1().min_w(0)
        .child(div().text_size(12).font_medium().text_color(t.foreground).truncate().child(track.title))
        .child(div().text_size(11).text_color(t.muted).truncate().child(track.app || track.bundle)))
      .child(svg(`${MOD}/icons/${playing ? "play" : "pause"}.svg`).size(10).flex_none()
        .text_color(playing ? t.accent : t.dim));
  }

  renderSessions() {
    const t = theme();
    const current = this.current();
    const note = this.error ?? (this.loading ? "" : "Nothing playing");
    return v_flex().size_full().p(6)
      .child(div().h(28).flex_none().px(6).flex().items_center().text_size(11).text_color(t.dim).child("Now Playing"))
      .children(this.sessions.map((s) => this.sessionRow(s, s === current)))
      .when(!this.sessions.length, (el) => el.child(div().px(6).text_size(12).text_color(t.dim).child(note)));
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
    if (this.listing) return this.renderSessions();
    this.viewport = globalThis.window.viewport_size();
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
      .child(h_flex().relative().justify_center().items_center().gap(14)
        .child(this.button("previous", "skip-back", 14, "previous"))
        .child(toggle)
        .child(this.button("next", "skip-forward", 14, "next"))
        .when(this.sessions.length > 1, (el) => el.child(this.sessionsButton())));
  }
}
