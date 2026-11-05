// サイドバーの一覧。フォーカス中のペインの Claude Code セッションについて、タスクを全件並べる。
// ペインの見出し（pane-progress）は 1 行の要約で、全体像はこちらで見る。
//
// データの経路は pane-progress と同じ: 端末の foreground.pid → ~/.claude/sessions/<pid>.json →
// ~/.claude/tasks/session-<先頭 8 文字>/。どれも Claude Code の内部形式で、更新で変わることがある。

import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { focused, home, panes, readTextFile, terminals, theme } from "herdr";
import * as fs from "fs/promises";

const POLL_MS = 1000;
// サイドバーを畳んだときの幅。これより狭いと件数だけ出す。
const COLLAPSED_WIDTH = 160;

const MARK = { completed: "✔", in_progress: "◼", pending: "◻" };

// 先頭のスピナー記号などを落とす（付属 agents mod と同じ整形）。
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

// 表示中のタブの Claude Code のうち、フォーカス中のものを優先する。
function targetPane() {
  const tab = focused()?.tab;
  const here = panes().filter((p) => p.tab === tab && p.app === "claude-code");
  return here.find((p) => p.focused) ?? here[0] ?? null;
}

async function readTasks(sessionId) {
  const dir = `${home()}/.claude/tasks/session-${sessionId.slice(0, 8)}`;
  const names = await fs.readdir(dir).catch(() => []);
  const tasks = [];
  for (const name of names) {
    if (!/^\d+\.json$/.test(name)) continue;
    // 読む途中で消えたファイルや書きかけのファイルは、次の周期に任せる。
    const text = await readTextFile(`${dir}/${name}`).catch(() => null);
    try {
      const { id, subject, status } = JSON.parse(text);
      if (status in MARK) tasks.push({ id, subject, status });
    } catch {}
  }
  return tasks.sort((a, b) => Number(a.id) - Number(b.id));
}

async function load(p) {
  const entry = terminals().find((x) => x.address === p.terminal);
  const msg = entry?.report?.msg ?? "";
  const pid = entry?.foreground?.pid;
  const session = pid ? await readTextFile(`${home()}/.claude/sessions/${pid}.json`).catch(() => null) : null;
  const id = session ? JSON.parse(session).sessionId : null;
  return { pane: p.pane, msg, tasks: id ? await readTasks(id) : [] };
}

export default class ProgressPanel extends View {
  init(_props, cx) {
    this.data = null;
    this.key = "";
    this.busy = false;
    this.width = null;
    cx.timer.every(POLL_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    if (this.busy) return;
    const p = targetPane();
    this.busy = true;
    cx.spawn(async (cx) => {
      let next = null;
      try {
        next = p?.terminal ? await load(p) : null;
      } catch (e) {
        console.log("progress-panel:", String(e));
      }
      this.busy = false;
      // 再描画はウィンドウ全体を描き直すので、変わったときだけ通知する。
      const key = JSON.stringify(next);
      if (key !== this.key) {
        this.key = key;
        this.data = next;
        cx.notify();
      }
    });
  }

  row(t, x) {
    const active = x.status === "in_progress";
    const color = x.status === "completed" ? t.dim : active ? t.foreground : t.muted;
    return h_flex().id(`progress-row-${x.id}`).w_full().flex_none().gap(8).px(6).py(4).items_start().rounded(6).text_color(color)
      .when(active, (el) => el.bg(t.selected))
      .child(div().flex_none().text_color(active ? t.accent : color).child(MARK[x.status]))
      .child(div().flex_1().min_w_0().when(active, (el) => el.font_medium()).child(x.subject ?? ""));
  }

  render() {
    const t = theme();
    const tasks = this.data?.tasks ?? [];
    const p = this.data ? panes().find((x) => x.pane === this.data.pane) : null;
    const done = tasks.filter((x) => x.status === "completed").length;
    const total = tasks.length;
    const msg = p?.status === "working" ? this.data?.msg ?? "" : "";
    const collapsed = (this.width ?? Infinity) < COLLAPSED_WIDTH;
    return v_flex().id("progress-panel").size_full().min_h(0).bg(t.chrome).text_size(13)
      .on_size_change((size, cx) => {
        if (size.width !== this.width) {
          this.width = size.width;
          cx.notify();
        }
      })
      .child(h_flex().h(31).flex_none().w_full().pl(16).pr(14).items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(!collapsed, (el) => el.child("Progress"))
        .when(total > 0, (el) => el.child(div().font_medium().text_color(t.muted).child(`${done}/${total}`))))
      .when(!collapsed, (el) => el.child(
        v_flex().id("progress-rows").flex_1().min_h(0).w_full().px(10).pb(8).gap(1).overflow_y_scrollbar()
          .when(Boolean(p), (el) => el.child(div().w_full().flex_none().px(6).pb(5).truncate().text_size(11.5).text_color(t.muted).child(clean(p.title) || p.program?.name || "")))
          .when(total > 0, (el) => el
            .child(div().flex_none().px(6).pb(7).w_full()
              .child(h_flex().w_full().h(4).rounded(2).overflow_hidden().bg(t.border)
                .child(div().h(4).flex_grow(done).bg(t.accent))
                .child(div().h(4).flex_grow(total - done))))
            .children(tasks.map((x) => this.row(t, x))))
          .when(total === 0 && !msg, (el) => el.child(div().flex_none().px(6).text_size(12).text_color(t.dim).child("No tasks")))
          .when(Boolean(msg), (el) => el.child(div().w_full().flex_none().px(6).pt(6).truncate().text_size(11.5).text_color(t.dim).child(msg)))));
  }
}
