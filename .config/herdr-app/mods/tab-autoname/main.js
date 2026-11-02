import { View, div } from "gpui-kit";
import { spaces, panes, run, nextCommand } from "herdr";

// Claude Code が端末タイトルに書く会話の要約を、タブ名に写す。画面には何も描かない。
// 人が付けた名前は上書きしない。名前を空にして保存すると自動に戻る。
// keys.json の "tab-autoname.wait" で、表示中のタブ名の先頭に待ちマークを付け外しする。
const STORE_KEY = "auto-names";
const MAX_REMEMBERED = 200;
const WAIT_MARK = "⏳ ";

// 付属 agents mod と同じ整形。先頭のスピナー記号などを落とす。
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
const isMarked = (name) => name.startsWith(WAIT_MARK);
const unmarked = (name) => (isMarked(name) ? name.slice(WAIT_MARK.length) : name);

export default class TabAutoname extends View {
  init(_props, cx) {
    // 自分が付けた名前の控え（tab id -> マークを除いた名前）。tab.rename すると named が true になるため、
    // 控えと違う名前を「人が付けた名前」と判定する。
    this.auto = JSON.parse(localStorage.getItem(STORE_KEY) ?? "{}");
    cx.timer.every(2000, () => this.sync());
    this.sync();
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "wait") this.toggleWait();
        cx.notify();
      }
    });
  }

  sync() {
    const all = panes();
    let changed = false;
    for (const tab of spaces().flatMap((s) => s.tabs)) {
      const name = unmarked(tab.name);
      if (tab.named && this.auto[tab.id] !== name) continue;
      const lead = all.find((p) => p.tab === tab.id && p.app === "claude-code");
      const title = clean(lead?.title);
      // 要約が付く前のタイトルはプログラム名（"Claude Code"）なので写さない。
      if (!title || title === lead.program?.name || title === name) continue;
      run("tab.rename", { id: tab.id, name: isMarked(tab.name) ? WAIT_MARK + title : title });
      this.auto[tab.id] = title;
      changed = true;
    }
    if (changed) this.save();
  }

  toggleWait() {
    const tab = spaces().find((s) => s.active)?.tabs.find((t) => t.active);
    if (!tab) return;
    if (isMarked(tab.name)) {
      const name = unmarked(tab.name);
      // 位置番号で呼ばれていたタブは、マークを外すと名前なしに戻す。
      const wasUnnamed = /^\d+$/.test(name) && this.auto[tab.id] === name;
      run("tab.rename", { id: tab.id, name: wasUnnamed ? "" : name });
      return;
    }
    // 名前なしのタブも、要約が付いたら自動で更新できるよう控えに入れる。
    if (!tab.named) {
      this.auto[tab.id] = tab.name;
      this.save();
    }
    run("tab.rename", { id: tab.id, name: WAIT_MARK + tab.name });
  }

  save() {
    // 起動直後は spaces() が揃わないことがあるため、閉じたタブの判定では消さず、件数で古い順に消す。
    const ids = Object.keys(this.auto);
    for (const id of ids.slice(0, Math.max(0, ids.length - MAX_REMEMBERED))) delete this.auto[id];
    localStorage.setItem(STORE_KEY, JSON.stringify(this.auto));
  }

  render() {
    return div();
  }
}
