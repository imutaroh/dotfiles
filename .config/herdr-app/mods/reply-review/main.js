// Claude Code の最新の返答にブロック単位でコメントを付け、まとめて送り返す。
//
// 開き方は2段構え（keys.json: "cmd-u": "mod.open:reply-review"）:
//   1. mod.open で 1px の見えないポップアップとして起動し、対象の Claude を決める
//   2. その Claude の右に自分自身をペインとして開き、ポップアップは閉じる
// 同じタブに既にペインがあれば、それにフォーカスして読み直す（ペインは増えない）。
//
// 対象の決め方: フォーカス中の Claude > そのタブで前回選んだ Claude > タブ内の先頭の Claude。
// 会話ログの場所は SessionStart フックが端末のラベル claude.transcript に入れておく。
// ラベルが無いときに「いちばん新しいログ」を拾う代替はしない。別の会話を黙って開くことになる。

import { View, div } from "gpui-kit";
import { v_flex, h_flex, Textarea, TextareaState, TextView } from "gpui-base";
import { appHome, closeOverlay, exec, focused, hc, nextCommand, notify, panes, props, run, shared, setShared, terminals, theme } from "herdr";

const MOD = "reply-review";
const LAST = "reply-review.last";
const QUOTE_LINES = 5;
const QUOTE_LINE_CHARS = 200;
const PAGE_PX = 240;
const LINE_PX = 22;
const WRAP_CHARS = 30;
const WHEEL_BLOCK_PX = 60;

// Markdown をコメントの単位に分ける: 空行区切りの段落、見出し、トップレベルのリスト項目。
// コードブロックと表は分割しない。
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

// Claude に送る文面。コメントはブロックの並び順に並べる。
export function compose(blocks, comments, overall) {
  const items = [...comments.keys()].sort((a, b) => a - b).map((i) => `${quote(blocks[i])}\n${comments.get(i)}`);
  if (!items.length && !overall) return "";
  const parts = ["直前の返答へのレビューです。次の指摘に対応してください。", ...items];
  if (overall) parts.push(`全体へのコメント:\n${overall}`);
  return parts.join("\n\n");
}

export default class ReplyReview extends View {
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
    this.comment = TextareaState.new({ placeholder: "この箇所へのコメント", rows: 3 });
    this.overall = TextareaState.new({ placeholder: "全体へのコメント（任意）", rows: 2 });
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
    // Cmd+H/L などでこのペインに戻ったときにキーボードを受け取る。
    // 変わった瞬間だけ取る（常に取ると、上に開いたピッカーなどの入力を奪う）
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

  // ─── 起動（見えないポップアップ側） ───

  launch(p) {
    const f = focused();
    const here = panes().filter((x) => x.tab === f?.tab);
    const claudes = here.filter((x) => x.terminal && (x.app === "claude-code" || x.program?.key === "claude"));
    const saved = (shared(LAST) ?? {})[f?.tab];
    const chosen = claudes.find((x) => x.pane === f?.pane) ?? claudes.find((x) => x.terminal === saved) ?? claudes[0];
    closeOverlay(p.overlay);
    if (!chosen) {
      notify({ title: "このタブに Claude Code がいません", level: "warning", timeout: 4000 });
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

  // ─── 返答の読み込み ───

  load(cx) {
    this.terminal = (shared(LAST) ?? {})[props()?.tab] ?? this.terminal;
    this.loading = true;
    cx.spawn(async (cx) => {
      const reply = await this.fetchReply();
      this.loading = false;
      this.error = reply.error ?? null;
      if (!reply.error) this.apply(reply);
      cx.notify();
    });
  }

  async fetchReply() {
    if (!this.terminal) return { error: "対象の Claude が指定されていません。" };
    const got = await hc(["get", this.terminal, "--json"]);
    if (got.code !== 0) return { error: `端末 ${this.terminal} が見つかりません。Claude は終了したかもしれません。` };
    const path = JSON.parse(got.stdout).labels?.["claude.transcript"];
    if (!path) {
      return { error: "この Claude には会話ログの印がありません。印はフックの導入後に起動した Claude に付きます。/clear するか、新しいタブで起動し直してください。" };
    }
    const r = await exec("python3", [`${appHome()}/mods/${MOD}/extract.py`, path]);
    if (r.code === 3) {
      return { error: `会話ログがありません: ${path}\nまだ1度も返答していないか、起動時に CLAUDE_CODE_CHILD_SESSION を受け継いで保存が止まっています。新しいタブで起動し直してください。` };
    }
    if (r.code !== 0) return { error: r.stderr || "会話ログを読めませんでした。" };
    const reply = JSON.parse(r.stdout);
    return reply.text ? reply : { error: "まだ返答がありません。" };
  }

  apply(reply) {
    if (reply.id === this.replyId) {
      this.incoming = null;
    } else if (this.comments.size || this.active !== null) {
      this.incoming = reply; // 書きかけのコメントを勝手に捨てない
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

  // ─── キーボード移動 ───
  // 素の div はコードからスクロールできず、list() は行内に入力欄やハンドラを置けない。
  // そこで選択中の 1 つ手前のブロックから描画して「スクロールした」状態を作る。
  // viewId を変えると新しいスクロール領域になり、マウスで動かした位置も先頭に戻る。

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

  // 長いブロックの中を読むための移動。要素の高さを測る API が無いので、行数から見積もった
  // 高さで止める（読み残しを出さないよう多めに見積もる。末尾に余白が出ることはある）
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

  // キーボードで先へ進んだあと、ホイールでも手前のブロックへ戻れるようにする。
  // スクロール領域の位置は読めないので、下へ動かした量を数えて先頭にいるかを判断する。
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

  // ─── コメント ───

  edit(i) {
    this.commit();
    this.cursor = i;
    this.active = i;
    this.comment.set_value(this.comments.get(i) ?? "");
    this.comment.focus();
  }

  // 開いているコメント欄の内容を確定する。空なら既存のコメントを消す。
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

  // ─── 送信 ───

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
          ? "Claude が許可待ちか質問中のため送れません。そちらを先に済ませてから送ってください。コメントは残してあります。"
          : (r.stderr || "送信に失敗しました。コメントは残してあります。");
      }
      cx.notify();
    });
  }

  leave() {
    const own = panes().find((x) => x.mod === MOD && x.tab === props()?.tab);
    if (own) run("pane.close", { pane: own.pane });
    run("pane.focus", { terminal: this.terminal });
  }

  // 書きかけがあるときは、1 回目の q では閉じない
  quit() {
    if (!this.comments.size && !this.overall.value().trim()) return this.leave();
    if (this.quitArmed) return this.leave();
    this.quitArmed = true;
  }

  key(e, cx) {
    const k = e.keystroke;
    if (k === "cmd-enter") {
      if (this.commentFocused || this.overallFocused) return;
      // コメント欄で Cmd+Enter を押した直後の同じ打鍵で送信まで走らせない
      if (Date.now() - (this.savedAt ?? 0) > 300) this.send(cx);
      cx.stop_propagation();
      return;
    }
    if (this.active !== null || this.overallFocused) {
      if (k !== "escape") return; // ほかのキーは入力欄の文字になる
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

  // 実行したキーを返す。割り当てが無いキーは null（アプリ側へ流す）
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

  // ─── 描画 ───

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
      .child(div().id(`rr-block-${i}`).w_full().px(10).py(5).rounded(6).cursor_pointer()
        .border_l(2).border_color(comment || editing || current ? t.accent : t.background)
        .when(editing || current, (el) => el.bg(t.selected))
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.edit(i); cx.notify(); })
        .child(TextView.markdown(`rr-md-${this.replyId}-${i}`, block).selectable(false)))
      .when(editing, (el) => el.child(v_flex().pl(12).pr(2).pb(6).gap(6)
        .child(this.textarea(t, this.comment, this.commentFocused))
        .child(h_flex().gap(6).justify_end().items_center()
          .child(div().flex_1().text_size(11).text_color(t.dim).child("⌘↵ で確定 / Esc で取り消し"))
          .when(Boolean(comment), (el) => el.child(this.button(t, "rr-remove", "削除", false, true, (_e, cx) => { this.remove(i); cx.notify(); })))
          .child(this.button(t, "rr-add", "確定", true, true, (_e, cx) => { this.save(); cx.notify(); })))))
      .when(!editing && Boolean(comment), (el) => el.child(div().id(`rr-comment-${i}`).ml(12).mr(2).mb(6).px(10).py(7).rounded(7).cursor_pointer()
        .bg(t.raised).border_1().border_color(t.border).text_size(13).text_color(t.foreground)
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.edit(i); cx.notify(); })
        .children(comment.split("\n").map((line) => div().child(line || " ")))));
  }

  hint() {
    if (this.active !== null) return "⌘↵ 確定 ・ Esc 取り消し";
    if (this.overallFocused) return "⌘↵ 送信 ・ Esc 一覧へ戻る";
    return "j/k 移動 ・ g/G 先頭/末尾 ・ ^D/^U 長文を読む ・ Enter コメント ・ d 削除 ・ a 全体 ・ r 読み直す ・ q 閉じる";
  }

  render() {
    const t = theme();
    if (this.launcher) return div();
    const state = terminals().find((x) => x.address === this.terminal)?.status;
    const title = panes().find((x) => x.terminal === this.terminal)?.title ?? this.terminal;
    const count = this.comments.size + (this.active !== null ? 1 : 0);
    const canSend = !this.sending && !this.error && (count > 0 || Boolean(this.overall.value().trim()));
    return v_flex().id("rr-root").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().flex_none().h(38).px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().flex_none().font_semibold().child("返答にコメント"))
        .child(div().flex_1().truncate().text_size(12).text_color(t.dim).child(`${title} (${this.terminal})`))
        .child(this.button(t, "rr-reload", "読み直す", false, !this.loading, (_e, cx) => { this.load(cx); cx.notify(); })))
      .when(state === "working", (el) => el.child(div().flex_none().px(14).py(6).bg(t.raised).text_size(12).text_color(t.working)
        .child("Claude は作業中です。表示しているのは途中の発言かもしれません。")))
      .when(Boolean(this.incoming), (el) => el.child(h_flex().flex_none().px(14).py(6).gap(8).items_center().bg(t.raised)
        .child(div().flex_1().text_size(12).text_color(t.muted).child("新しい返答があります。n で切り替えるとコメントは消えます。"))
        .child(this.button(t, "rr-switch", "切り替える", false, true, (_e, cx) => { this.show(this.incoming); cx.notify(); }))))
      .when(Boolean(this.error), (el) => el.child(v_flex().flex_1().min_h(0).p(16).gap(4).text_size(13).text_color(t.muted)
        .children(this.error.split("\n").map((line) => div().child(line)))))
      .when(!this.error, (el) => el.child(v_flex().id(`rr-list-${this.viewId}`).flex_1().flex_shrink(1).min_h(0).overflow_y_scrollbar().px(8).py(8)
        .on_scroll_wheel((e, cx) => this.wheel(e, cx))
        .child(v_flex().flex_none().w_full().gap(2).mt(-this.offset)
          .children(this.blocks.slice(this.top).map((block, i) => this.row(t, block, this.top + i))))))
      .child(v_flex().flex_none().px(14).py(10).gap(8).border_t(1).border_color(t.border)
        .child(this.textarea(t, this.overall, this.overallFocused))
        .when(Boolean(this.sendError), (el) => el.child(div().text_size(12).text_color(t.blocked).child(this.sendError)))
        .when(Boolean(this.quitArmed), (el) => el.child(div().text_size(12).text_color(t.blocked).child("書きかけがあります。もう一度 q で破棄して閉じます。")))
        .child(div().text_size(11).text_color(t.dim).child(this.hint()))
        .child(h_flex().gap(8).items_center()
          .child(div().flex_1().text_size(12).text_color(t.dim).child(`${this.blocks.length ? this.cursor + 1 : 0} / ${this.blocks.length} ・ コメント ${count} 件`))
          .child(this.button(t, "rr-send", this.sending ? "送信中…" : "Claude に送る ⌘↵", true, canSend, (_e, cx) => { this.send(cx); cx.notify(); }))));
  }
}
