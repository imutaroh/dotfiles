// Comment on Claude Code's latest reply, block by block, and send the comments back together.
//
// Opens in two steps (keys.json: "cmd-u": "mod.open:redpen"):
//   1. mod.open starts it as an invisible 1px popup, which picks the target Claude.
//   2. It opens itself as a pane to the right of that Claude and closes the popup.
// If the tab already has the pane, it focuses that pane and reloads (no second pane).
//
// Target: the focused Claude > the Claude last chosen in this tab > the first Claude in the tab.
// A SessionStart hook stores the transcript path in the terminal label claude.transcript.
// There is deliberately no fallback to "the newest transcript" when the label is missing:
// that would silently open a different conversation.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, Textarea, TextareaState, TextView } from "gpui-base";
import { appHome, closeOverlay, exec, focused, hc, nextCommand, notify, panes, props, run, shared, setShared, terminals, theme } from "herdr";

const MOD = "redpen";
const LAST = "redpen.last";
const QUOTE_LINES = 5;
const QUOTE_LINE_CHARS = 200;
const PAGE_PX = 240;
const LINE_PX = 22;
const WRAP_CHARS = 30;
const WHEEL_BLOCK_PX = 60;

// Splits Markdown into commentable blocks: blank-line separated paragraphs, headings and
// top-level list items. Code blocks and tables stay whole.
export function splitBlocks(markdown) {
  const out = [];
  let current = [], fence = null, inTable = false;
  const flush = () => {
    if (current.length) out.push(current.join("\n"));
    current = [];
    inTable = false;
  };
  for (const line of markdown.replace(/\r\n/g, "\n").split("\n")) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (fence) {
      current.push(line);
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && line.trim() === marker[1]) {
        fence = null;
        flush();
      }
      continue;
    }
    if (marker) {
      flush();
      fence = marker[1];
      current.push(line);
    } else if (!line.trim()) {
      flush();
    } else if (/^#{1,6}\s/.test(line)) {
      flush();
      out.push(line);
    } else if (/^([-*+]|\d+[.)])\s+/.test(line)) {
      flush();
      current.push(line);
    } else {
      const table = /^\s*\|/.test(line);
      if (table !== inTable && current.length) flush();
      inTable = table;
      current.push(line);
    }
  }
  flush();
  return out;
}

function quote(block) {
  const lines = block.split("\n").filter((line) => !/^\s*(`{3,}|~{3,})/.test(line));
  const shown = lines.slice(0, QUOTE_LINES).map((line) => (line.length > QUOTE_LINE_CHARS ? `${line.slice(0, QUOTE_LINE_CHARS)}…` : line));
  if (lines.length > QUOTE_LINES) shown.push("…");
  return shown.map((line) => `> ${line}`).join("\n");
}

// The message sent to Claude. Comments follow the order of the blocks.
export function compose(blocks, comments, overall) {
  const items = [...comments.keys()].sort((a, b) => a - b).map((i) => `${quote(blocks[i])}\n${comments.get(i)}`);
  if (!items.length && !overall) return "";
  const parts = ["Comments on your previous reply. Please address them.", ...items];
  if (overall) parts.push(`Overall comment:\n${overall}`);
  return parts.join("\n\n");
}

export default class Redpen extends View {
  init(_props, cx) {
    const p = props() ?? {};
    this.launcher = Boolean(p.overlay && !p.terminal);
    if (this.launcher) {
      this.launch(p);
      return;
    }
    this.terminal = p.terminal;
    this.blocks = [];
    this.comments = new Map();
    this.active = null;
    this.cursor = 0;
    this.top = 0;
    this.offset = 0;
    this.viewId = 0;
    this.wheelDown = 0;
    this.wheelUp = 0;
    this.handle = cx.focus_handle();
    this.comment = TextareaState.new({ placeholder: "Comment on this block", rows: 3 });
    this.overall = TextareaState.new({ placeholder: "Overall comment (optional)", rows: 2 });
    this.comment.on("focus", (_e, cx) => { this.commentFocused = true; cx.notify(); });
    this.comment.on("blur", (_e, cx) => { this.commentFocused = false; cx.notify(); });
    this.overall.on("focus", (_e, cx) => { this.overallFocused = true; cx.notify(); });
    this.overall.on("blur", (_e, cx) => { this.overallFocused = false; cx.notify(); });
    this.overall.on("change", (_e, cx) => cx.notify());
    this.comment.on("submit", (e, cx) => { if (e.secondary) { this.save(); cx.notify(); } });
    this.overall.on("submit", (e, cx) => { if (e.secondary) this.send(cx); });
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "reload") {
          this.load(cx);
          this.takeKeyboard();
        }
        cx.notify();
      }
    });
    this.load(cx);
    cx.timer.after(100, () => this.takeKeyboard());
    // Take the keyboard when focus comes back to this pane (e.g. pane.go from a keybinding).
    // Only at the moment it arrives: taking it constantly would steal input from pickers opened above.
    cx.timer.every(150, () => {
      const f = focused();
      const own = panes().find((x) => x.mod === MOD && x.tab === props()?.tab);
      const here = Boolean(own && f?.pane === own.pane);
      if (here && !this.wasHere) this.takeKeyboard();
      this.wasHere = here;
    });
  }

  takeKeyboard() {
    if (this.active !== null) this.comment.focus();
    else this.handle.focus();
  }

  // ─── Launch (the invisible popup) ───

  launch(p) {
    const f = focused();
    const here = panes().filter((x) => x.tab === f?.tab);
    const claudes = here.filter((x) => x.terminal && (x.app === "claude-code" || x.program?.key === "claude"));
    const saved = (shared(LAST) ?? {})[f?.tab];
    const chosen = claudes.find((x) => x.pane === f?.pane) ?? claudes.find((x) => x.terminal === saved) ?? claudes[0];
    closeOverlay(p.overlay);
    if (!chosen) {
      notify({ title: "No Claude Code in this tab", level: "warning", timeout: 4000 });
      return;
    }
    const tabs = new Set(panes().map((x) => x.tab));
    const kept = Object.entries(shared(LAST) ?? {}).filter(([tab]) => tabs.has(tab));
    setShared(LAST, { ...Object.fromEntries(kept), [f.tab]: chosen.terminal });
    const open = here.find((x) => x.mod === MOD);
    if (open) {
      run("pane.focus", { pane: open.pane });
      run(`${MOD}.reload`);
    } else {
      run("pane.split", { direction: "right", pane: chosen.pane, mod: MOD, props: { terminal: chosen.terminal, tab: f.tab } });
    }
  }

  // ─── Loading the reply ───

  load(cx) {
    this.terminal = (shared(LAST) ?? {})[props()?.tab] ?? this.terminal;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const reply = await this.fetchReply();
        this.error = reply.error ?? null;
        if (!reply.error) this.apply(reply);
      } catch (err) {
        // 失敗しても loading を残さない。残すと Reload も効かなくなる
        this.error = String(err);
      }
      this.loading = false;
      cx.notify();
    });
  }

  async fetchReply() {
    if (!this.terminal) return { error: "No target Claude was specified." };
    const got = await hc(["get", this.terminal, "--json"]);
    if (got.code !== 0) return { error: `Terminal ${this.terminal} not found. Claude may have exited.` };
    const path = JSON.parse(got.stdout).labels?.["claude.transcript"];
    if (!path) {
      return { error: "This Claude has no transcript label. The label is set on Claude sessions started after the hook was installed. Run /clear or start Claude in a new tab." };
    }
    const r = await exec("python3", [`${appHome()}/mods/${MOD}/extract.py`, path]);
    if (r.code === 3) {
      return { error: `Transcript not found: ${path}\nClaude has not replied yet, or it inherited CLAUDE_CODE_CHILD_SESSION and is not saving transcripts. Start Claude in a new tab.` };
    }
    if (r.code !== 0) return { error: r.stderr || "Could not read the transcript." };
    const reply = JSON.parse(r.stdout);
    return reply.text ? reply : { error: "No reply yet." };
  }

  apply(reply) {
    if (reply.id === this.replyId) {
      this.incoming = null;
    } else if (this.comments.size || this.active !== null) {
      this.incoming = reply; // Never discard unsent comments on its own
    } else {
      this.show(reply);
    }
  }

  show(reply) {
    this.replyId = reply.id;
    this.blocks = splitBlocks(reply.text);
    this.comments = new Map();
    this.active = null;
    this.incoming = null;
    this.sendError = null;
    this.quitArmed = false;
    this.cursor = 0;
    this.reveal();
  }

  // ─── Keyboard movement ───
  // A plain div cannot be scrolled from code, and list() cannot hold text inputs or handlers
  // inside its rows. So "scrolling" is drawing from the block just before the selected one.
  // A new viewId makes a new scroll area, which also resets any position set with the mouse.

  reveal() {
    this.top = Math.max(0, this.cursor - 1);
    this.offset = 0;
    this.viewId++;
    this.wheelDown = 0;
    this.wheelUp = 0;
  }

  move(to) {
    this.cursor = Math.max(0, Math.min(this.blocks.length - 1, to));
    this.reveal();
  }

  // Moves through long blocks. There is no API to measure elements, so it stops at a height
  // estimated from line counts (generously, so nothing is left unread; blank space may appear at the end).
  page(direction) {
    if (direction < 0 && this.offset === 0) {
      this.top = Math.max(0, this.top - 1);
    } else {
      const lines = this.blocks.slice(this.top).flatMap((b) => b.split("\n")).reduce((n, line) => n + 1 + Math.floor(line.length / WRAP_CHARS), 0);
      const limit = Math.max(0, lines * LINE_PX - PAGE_PX);
      this.offset = Math.max(0, Math.min(limit, this.offset + direction * PAGE_PX));
    }
    this.viewId++;
  }

  // Lets the wheel reach earlier blocks after moving ahead with the keyboard.
  // The scroll position cannot be read, so it counts how far the wheel went down to tell whether it is at the top.
  wheel(e, cx) {
    if (e.delta.y < 0) {
      this.wheelDown -= e.delta.y;
      this.wheelUp = 0;
    } else if (this.wheelDown > 0) {
      this.wheelDown = Math.max(0, this.wheelDown - e.delta.y);
    } else if (this.top > 0) {
      this.wheelUp += e.delta.y;
      if (this.wheelUp >= WHEEL_BLOCK_PX) {
        this.wheelUp = 0;
        this.top--;
        cx.notify();
      }
    }
  }

  // ─── Comments ───

  edit(i) {
    this.commit();
    this.cursor = i;
    this.active = i;
    this.comment.set_value(this.comments.get(i) ?? "");
    this.comment.focus();
  }

  // Saves the open comment box. An empty box removes the existing comment.
  commit() {
    if (this.active === null) return;
    const text = this.comment.value().trim();
    if (text) this.comments.set(this.active, text);
    else this.comments.delete(this.active);
    this.active = null;
  }

  save() {
    this.commit();
    this.savedAt = Date.now();
    this.handle.focus();
  }

  cancel() {
    this.active = null;
    this.handle.focus();
  }

  remove(i) {
    this.comments.delete(i);
    if (this.active === i) this.active = null;
    this.handle.focus();
  }

  // ─── Sending ───

  send(cx) {
    this.commit();
    const text = compose(this.blocks, this.comments, this.overall.value().trim());
    if (!text || this.sending) return;
    this.sending = true;
    this.sendError = null;
    cx.spawn(async (cx) => {
      const r = await hc(["send", this.terminal, text]);
      this.sending = false;
      if (r.code === 0) {
        this.leave();
      } else {
        this.sendError = r.code === 9
          ? "Claude is waiting on a permission prompt or a question. Answer it first, then send. Your comments are kept."
          : (r.stderr || "Send failed. Your comments are kept.");
      }
      cx.notify();
    });
  }

  leave() {
    const own = panes().find((x) => x.mod === MOD && x.tab === props()?.tab);
    if (own) run("pane.close", { pane: own.pane });
    run("pane.focus", { terminal: this.terminal });
  }

  // With unsent comments, the first q does not close.
  quit() {
    if (!this.comments.size && !this.overall.value().trim()) return this.leave();
    if (this.quitArmed) return this.leave();
    this.quitArmed = true;
  }

  key(e, cx) {
    const k = e.keystroke;
    if (k === "cmd-enter") {
      if (this.commentFocused || this.overallFocused) return;
      // The Cmd+Enter that saved a comment must not also send it
      if (Date.now() - (this.savedAt ?? 0) > 300) this.send(cx);
      cx.stop_propagation();
      return;
    }
    if (this.active !== null || this.overallFocused) {
      if (k !== "escape") return; // Other keys are text for the input
      if (this.active !== null) this.cancel();
      else this.handle.focus();
      cx.stop_propagation();
      cx.notify();
      return;
    }
    const action = this.keyAction(k, cx);
    if (!action) return;
    if (action !== "q") this.quitArmed = false;
    cx.stop_propagation();
    cx.notify();
  }

  // Returns the key it acted on, or null when unbound (the key goes on to the app).
  keyAction(k, cx) {
    const has = this.blocks.length > 0 && !this.error;
    switch (k) {
      case "j": case "down": if (has) this.move(this.cursor + 1); return "j";
      case "k": case "up": if (has) this.move(this.cursor - 1); return "k";
      case "g": if (has) this.move(0); return "g";
      case "shift-g": if (has) this.move(this.blocks.length - 1); return "G";
      case "ctrl-d": if (has) this.page(1); return "ctrl-d";
      case "ctrl-u": if (has) this.page(-1); return "ctrl-u";
      case "enter": case "i": case "c":
        if (has) { this.reveal(); this.edit(this.cursor); }
        return "enter";
      case "d": case "x": if (has) this.remove(this.cursor); return "d";
      case "a": this.overall.focus(); return "a";
      case "r": if (!this.loading) this.load(cx); return "r";
      case "n": if (this.incoming) this.show(this.incoming); return "n";
      case "q": this.quit(); return "q";
      default: return null;
    }
  }

  // ─── Rendering ───

  button(t, id, text, primary, enabled, action) {
    return h_flex().id(id).flex_none().h(28).px(12).items_center().rounded(7)
      .border_1().border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised)
      .text_color(primary ? t.solid_foreground : t.foreground).text_size(12).font_medium()
      .when(!enabled, (el) => el.opacity(0.45))
      .when(enabled, (el) => el.cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action))
      .child(text);
  }

  textarea(t, state, focused) {
    return Textarea.new(state).w_full().px(10).py(7).rounded(7).border_1()
      .border_color(focused ? t.accent : t.input).bg(t.surface).text_size(13).text_color(t.foreground);
  }

  row(t, block, i) {
    const comment = this.comments.get(i), editing = this.active === i, current = this.cursor === i;
    return v_flex().flex_none().w_full().gap(4)
      .child(div().id(`redpen-block-${i}`).w_full().px(10).py(5).rounded(6).cursor_pointer()
        .border_l(2).border_color(comment || editing || current ? t.accent : t.background)
        .when(editing || current, (el) => el.bg(t.selected))
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.edit(i); cx.notify(); })
        // 返答の中のリモート画像は読み込まない。表示しただけで外部へ通信する経路を作らないため
        .child(TextView.markdown(`redpen-md-${this.replyId}-${i}`, block.replace(/!\[([^\]]*)\]\(\s*<?https?:[^)]*\)/gi, "[画像: $1]")).selectable(false)))
      .when(editing, (el) => el.child(v_flex().pl(12).pr(2).pb(6).gap(6)
        .child(this.textarea(t, this.comment, this.commentFocused))
        .child(h_flex().gap(6).justify_end().items_center()
          .child(div().flex_1().text_size(11).text_color(t.dim).child("⌘↵ save / Esc cancel"))
          .when(Boolean(comment), (el) => el.child(this.button(t, "redpen-remove", "Delete", false, true, (_e, cx) => { this.remove(i); cx.notify(); })))
          .child(this.button(t, "redpen-add", "Save", true, true, (_e, cx) => { this.save(); cx.notify(); })))))
      .when(!editing && Boolean(comment), (el) => el.child(div().id(`redpen-comment-${i}`).ml(12).mr(2).mb(6).px(10).py(7).rounded(7).cursor_pointer()
        .bg(t.raised).border_1().border_color(t.border).text_size(13).text_color(t.foreground)
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.edit(i); cx.notify(); })
        .children(comment.split("\n").map((line) => div().child(line || " ")))));
  }

  hint() {
    if (this.active !== null) return "⌘↵ save · Esc cancel";
    if (this.overallFocused) return "⌘↵ send · Esc back to list";
    return "j/k move · g/G top/bottom · ^D/^U read long blocks · Enter comment · d delete · a overall · r reload · q close";
  }

  render() {
    const t = theme();
    if (this.launcher) return div();
    const state = terminals().find((x) => x.address === this.terminal)?.status;
    const title = panes().find((x) => x.terminal === this.terminal)?.title ?? this.terminal;
    const count = this.comments.size + (this.active !== null ? 1 : 0);
    const canSend = !this.sending && !this.error && (count > 0 || Boolean(this.overall.value().trim()));
    return v_flex().id("redpen-root").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().flex_none().h(38).px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().flex_none().font_semibold().child("Redpen"))
        .child(div().flex_1().truncate().text_size(12).text_color(t.dim).child(`${title} (${this.terminal})`))
        .child(this.button(t, "redpen-reload", "Reload", false, !this.loading, (_e, cx) => { this.load(cx); cx.notify(); })))
      .when(state === "working", (el) => el.child(div().flex_none().px(14).py(6).bg(t.raised).text_size(12).text_color(t.working)
        .child("Claude is working. This may be a partial reply.")))
      .when(Boolean(this.incoming), (el) => el.child(h_flex().flex_none().px(14).py(6).gap(8).items_center().bg(t.raised)
        .child(div().flex_1().text_size(12).text_color(t.muted).child("A new reply is available. Press n to switch; your comments will be discarded."))
        .child(this.button(t, "redpen-switch", "Switch", false, true, (_e, cx) => { this.show(this.incoming); cx.notify(); }))))
      .when(Boolean(this.error), (el) => el.child(v_flex().flex_1().min_h(0).p(16).gap(4).text_size(13).text_color(t.muted)
        .children(this.error.split("\n").map((line) => div().child(line)))))
      .when(!this.error, (el) => el.child(v_flex().id(`redpen-list-${this.viewId}`).flex_1().flex_shrink(1).min_h(0).overflow_y_scrollbar().px(8).py(8)
        .on_scroll_wheel((e, cx) => this.wheel(e, cx))
        .child(v_flex().flex_none().w_full().gap(2).mt(-this.offset)
          .children(this.blocks.slice(this.top).map((block, i) => this.row(t, block, this.top + i))))))
      .child(v_flex().flex_none().px(14).py(10).gap(8).border_t(1).border_color(t.border)
        .child(this.textarea(t, this.overall, this.overallFocused))
        .when(Boolean(this.sendError), (el) => el.child(div().text_size(12).text_color(t.blocked).child(this.sendError)))
        .when(Boolean(this.quitArmed), (el) => el.child(div().text_size(12).text_color(t.blocked).child("You have unsent comments. Press q again to discard them and close.")))
        .child(div().text_size(11).text_color(t.dim).child(this.hint()))
        .child(h_flex().gap(8).items_center()
          .child(div().flex_1().text_size(12).text_color(t.dim).child(`${this.blocks.length ? this.cursor + 1 : 0} / ${this.blocks.length} · ${count} comment${count === 1 ? "" : "s"}`))
          .child(this.button(t, "redpen-send", this.sending ? "Sending…" : "Send to Claude ⌘↵", true, canSend, (_e, cx) => { this.send(cx); cx.notify(); }))));
  }
}
