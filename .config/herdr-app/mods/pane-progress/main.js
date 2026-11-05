// ペインの見出し。Claude Code のペインでは、そのセッションのタスクの流れを 1 行で出す。
//   2/4 ▬▬── ◼ 今の作業  ◻ 次の作業  ◻ その次  +2
// タスクが無い回は、Claude Code が報告した今の動作を出す。
// 見出しの行に描くので、端末の文章には被らず、ペインごとに付いて回る。全件の一覧はサイドバーの progress-panel が出す。
// 名前の欄には、プログラム名の代わりにエージェントのセッションのタイトルを出す。
//
// Changed from the `pane` mod shipped with Herdr (https://github.com/herdrdev/herdr-app, Apache-2.0):
// added the task flow, and named agent panes after their session.
//
// データの経路: 端末の foreground.pid → ~/.claude/sessions/<pid>.json → ~/.claude/tasks/session-<先頭 8 文字>/
// どれも Claude Code の内部形式で、更新で変わることがある。読めないときは付属と同じ見出しに戻る。

import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { focused, home, panes, props, readTextFile, run, terminals, theme } from "herdr";
import * as fs from "fs/promises";

const POLL_MS = 1500;
// 見出しの幅の見積もり（px）。アイコン・余白・件数・バー・スピナー・+N の合計と、各項目の上限。
const CHROME_WIDTH = 200;
const GAP = 10;
const CURRENT_MAX_WIDTH = 420;
const REST_MAX_WIDTH = 260;
const MIN_TRUNCATED_WIDTH = 90;
// 名前の欄の上限。狭いペインではタスクの場所を残すため、ペインの幅の 3 分の 1 までにする。
const NAME_MAX_WIDTH = 260;
// これより狭いペインでは、タスクを優先してフォルダを出さない。
const FOLDER_MIN_PANE_WIDTH = 960;
const FOLDER_MAX_WIDTH = 180;

const MARK = { completed: "✔", in_progress: "◼", pending: "◻" };

// 付属 agents mod と同じ整形。先頭のスピナー記号などを落とす。
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

// エージェントが端末タイトルに書いたセッションの名前。プログラム名・フォルダ・ホストしか言っていないときは null。
// clean は先頭の ~ や / も落とすので、パスかどうかは clean の前に見る。
function sessionTitle(p) {
  const live = clean(p.title);
  const isPath = /^[^\p{L}\p{N}~/]*[~/]/u.test(p.title ?? "") || /^[A-Za-z]:\\/.test(live);
  const telling = live && live !== p.program?.name && !isPath && !live.includes("@") && live.toLowerCase() !== p.program?.key;
  return telling ? live : null;
}

function displayName(p) {
  return (p.program?.agent && sessionTitle(p)) || ((p.program?.agent || p.program?.shell) && p.program.name) || p.title || p.program?.name || "shell";
}

// 文字幅の見積もり（text_size 12 で全角 12.5px、半角 7px）。マークと空白の分を足す。
function labelWidth(text) {
  return [...(text ?? "")].reduce((w, c) => w + (c.charCodeAt(0) > 255 ? 12.5 : 7), 20);
}

// 残りのタスクのうち、見出しに入る分を返す。切れて読めない項目は出さず、+N に回す。
function fitRest(rest, room, hasCurrent) {
  const fitted = [];
  let left = room;
  for (const x of rest) {
    const width = Math.min(REST_MAX_WIDTH, labelWidth(x.subject)) + GAP;
    if (width > left) {
      if (left >= MIN_TRUNCATED_WIDTH || (!hasCurrent && fitted.length === 0)) fitted.push(x);
      break;
    }
    fitted.push(x);
    left -= width;
  }
  return fitted;
}

function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

function folder(cwd) {
  if (!cwd) return "";
  const h = home();
  return cwd === h ? "~" : cwd.startsWith(h + "/") ? "~" + cwd.slice(h.length) : cwd;
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

function counts(tasks) {
  return { done: tasks.filter((x) => x.status === "completed").length, total: tasks.length };
}

export default class PaneProgress extends View {
  init(_props, cx) {
    this.hovered = false;
    this.width = null;
    this.data = null;
    this.key = "";
    this.busy = false;
    cx.timer.every(POLL_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  me() {
    return panes().find((p) => p.pane === props()?.pane);
  }

  // 見出しは表示中でないタブにも残って動き続けるので、見えているときだけ読む。
  refresh(cx) {
    const p = this.me();
    if (p?.app !== "claude-code" || !p.terminal) {
      if (this.data) {
        this.data = null;
        this.key = "";
        cx.notify();
      }
      return;
    }
    if (this.busy || focused()?.tab !== p.tab) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      let next = null;
      try {
        next = await this.load(p.terminal);
      } catch (e) {
        console.log("pane-progress:", String(e));
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

  async load(terminal) {
    const entry = terminals().find((x) => x.address === terminal);
    const msg = entry?.report?.msg ?? "";
    const pid = entry?.foreground?.pid;
    if (!pid) return { tasks: [], msg };
    const session = await readTextFile(`${home()}/.claude/sessions/${pid}.json`).catch(() => null);
    const id = session ? JSON.parse(session).sessionId : null;
    return { tasks: id ? await readTasks(id) : [], msg };
  }

  showsFolder() {
    return (this.width ?? 0) >= FOLDER_MIN_PANE_WIDTH;
  }

  nameMaxWidth() {
    return Math.min(NAME_MAX_WIDTH, Math.floor((this.width ?? Infinity) / 3));
  }

  bar(t, done, total) {
    const width = 44;
    return div().flex_none().w(width).h(4).rounded(2).bg(t.border)
      .child(div().h(4).w(total ? Math.round((width * done) / total) : 0).rounded(2).bg(t.accent));
  }

  flow(t, p, tasks) {
    const { done, total } = counts(tasks);
    const current = tasks.filter((x) => x.status === "in_progress");
    const rest = tasks.filter((x) => x.status === "pending");
    const currentWidth = current.reduce((w, x) => w + Math.min(CURRENT_MAX_WIDTH, labelWidth(x.subject)) + GAP, 0);
    const folderWidth = this.showsFolder() ? Math.min(FOLDER_MAX_WIDTH, labelWidth(folder(p.cwd))) : 0;
    const nameWidth = Math.min(this.nameMaxWidth(), labelWidth(displayName(p)));
    const fitted = fitRest(rest, (this.width ?? 800) - CHROME_WIDTH - nameWidth - folderWidth - currentWidth, current.length > 0);
    const hidden = rest.length - fitted.length;
    return h_flex().flex_1().min_w_0().h_full().px(6).gap(10).items_center().overflow_hidden()
      .child(div().flex_none().font_medium().text_color(t.muted).child(`${done}/${total}`))
      .child(this.bar(t, done, total))
      .children(current.map((x) =>
        div().min_w_0().max_w(CURRENT_MAX_WIDTH).truncate().font_medium().text_color(t.foreground).child(`${MARK.in_progress} ${x.subject}`)))
      .children(fitted.map((x) =>
        div().min_w_0().max_w(REST_MAX_WIDTH).flex_shrink(1).truncate().text_color(t.muted).child(`${MARK.pending} ${x.subject}`)))
      .when(hidden > 0, (el) => el.child(div().flex_none().text_color(t.dim).child(`+${hidden}`)))
      .when(done === total, (el) => el.child(div().flex_none().text_color(t.dim).child(`${MARK.completed} すべて完了`)));
  }

  button(t, id, icon, command, args) {
    return div()
      .id(id)
      .p(3)
      .rounded(4)
      .text_color(t.dim)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => {
        cx.stop_propagation();
        run(command, args);
      })
      .child(svg(`mods/pane/${icon}.svg`).size(14));
  }

  render() {
    const t = theme();
    const p = this.me();
    if (!p) return div();
    const tasks = this.data?.tasks ?? [];
    const pic = icon(p.program, 14, t.dim);
    const st = p.status;
    const pane = p.pane;
    const msg = st === "working" ? this.data?.msg ?? "" : "";
    return h_flex()
      .id(`pane-head-${pane}`)
      .size_full()
      .px(10)
      .gap(8)
      .items_center()
      .bg(t.background)
      .border_b(1)
      .border_color(t.border)
      .text_size(12)
      .on_size_change((size, cx) => {
        if (size.width !== this.width) {
          this.width = size.width;
          cx.notify();
        }
      })
      .on_hover((hovered, cx) => { this.hovered = hovered; cx.notify(); })
      .on_click(() => run("pane.focus", { pane }))
      .when(Boolean(pic), (el) => el.child(pic))
      .child(div().flex_none().truncate().max_w(this.nameMaxWidth()).font_medium().text_color(t.foreground).child(displayName(p)))
      .when(tasks.length > 0, (el) => el
        .when(this.showsFolder(), (el) => el.child(div().flex_none().truncate().max_w(FOLDER_MAX_WIDTH).text_color(t.dim).child(folder(p.cwd))))
        .child(this.flow(t, p, tasks)))
      .when(tasks.length === 0 && !msg, (el) => el.child(div().flex_1().truncate().text_color(t.dim).child(folder(p.cwd))))
      .when(tasks.length === 0 && Boolean(msg), (el) => el
        .child(div().flex_none().truncate().max_w(240).text_color(t.dim).child(folder(p.cwd)))
        .child(div().flex_1().min_w_0().truncate().text_color(t.muted).child(msg)))
      .when(st === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
      .when(st === "blocked", el => el.child(div().flex_none().px(6).h(18).flex().items_center().rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).child("Needs you")))
      .when(st === "done", el => el.child(div().size(7).flex_none().rounded(4).bg(t.done)))
      .when(this.hovered, el => el
        .child(this.button(t, `ph-r-${pane}`, "split-right", "pane.split", { direction: "right", pane }))
        .child(this.button(t, `ph-d-${pane}`, "split-down", "pane.split", { direction: "down", pane }))
        .child(this.button(t, `ph-z-${pane}`, p.zoomed ? "unzoom" : "zoom", "pane.zoom", { pane }))
        .child(this.button(t, `ph-x-${pane}`, "close", "pane.close", { pane })));
  }
}
