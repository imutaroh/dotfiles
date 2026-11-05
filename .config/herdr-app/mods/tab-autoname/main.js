import { View, div } from "gpui-kit";
import { spaces, panes, run, nextCommand, shared, setShared } from "herdr";

// Claude Code が端末タイトルに書く会話の要約を、タブ名に写す。画面には何も描かない。
// 人が付けた名前は上書きしない。名前を空にして保存すると自動に戻る。
// keys.json の "tab-autoname.wait" で、表示中のタブ名の先頭に待ちマークを付け外しする。
// mine.json にはブロックとして載せる。付属の main は構造を変えられないので、mod.json の overlay で
// 大きさ 0 の keep 付きウィンドウとして動かす（main の表示中に mod.open を 1 回実行する。再度実行すると閉じる）。
const OLD_STORE_KEY = "auto-names";
const STORE_KEY = "tab-autoname.names";
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
    // localStorage はコピーごとに別で、開き直した窓や別のレイアウトへ引き継がれないので shared に置く。
    const old = localStorage.getItem(OLD_STORE_KEY);
    if (old) {
      setShared(STORE_KEY, { ...JSON.parse(old), ...shared(STORE_KEY) });
      localStorage.removeItem(OLD_STORE_KEY);
    }
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
    const auto = { ...shared(STORE_KEY) };
    let changed = false;
    for (const tab of spaces().flatMap((s) => s.tabs)) {
      const name = unmarked(tab.name);
      if (tab.named && auto[tab.id] !== name) continue;
      const lead = all.find((p) => p.tab === tab.id && p.app === "claude-code");
      const title = clean(lead?.title);
      // 要約が付く前のタイトルはプログラム名（"Claude Code"）なので写さない。
      if (!title || title === lead.program?.name || title === name) continue;
      run("tab.rename", { id: tab.id, name: isMarked(tab.name) ? WAIT_MARK + title : title });
      auto[tab.id] = title;
      changed = true;
    }
    if (changed) this.save(auto);
  }

  toggleWait() {
    const tab = spaces().find((s) => s.active)?.tabs.find((t) => t.active);
    if (!tab) return;
    if (isMarked(tab.name)) {
      const name = unmarked(tab.name);
      // 位置番号で呼ばれていたタブは、マークを外すと名前なしに戻す。
      const wasUnnamed = /^\d+$/.test(name) && shared(STORE_KEY)?.[tab.id] === name;
      run("tab.rename", { id: tab.id, name: wasUnnamed ? "" : name });
      return;
    }
    // 名前なしのタブも、要約が付いたら自動で更新できるよう控えに入れる。
    if (!tab.named) this.save({ ...shared(STORE_KEY), [tab.id]: tab.name });
    run("tab.rename", { id: tab.id, name: WAIT_MARK + tab.name });
  }

  save(auto) {
    // 起動直後は spaces() が揃わないことがあるため、閉じたタブの判定では消さず、件数で古い順に消す。
    const ids = Object.keys(auto);
    for (const id of ids.slice(0, Math.max(0, ids.length - MAX_REMEMBERED))) delete auto[id];
    setShared(STORE_KEY, auto);
  }

  render() {
    return div();
  }
}
