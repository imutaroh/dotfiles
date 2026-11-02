import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, layout, nextCommand } from "herdr";

// workspace-status の複製。表示は元のまま、キーの受け口を足しただけ。
// keys.json の "status-keys.cycle"（閉→Files→Changes→閉）/ "status-keys.files" / "status-keys.changes" で右パネルを操作する。
// 動きはタブバー右端の Files / Changes ボタンと同じ（表示中なら閉じる、それ以外なら切り替えて開く）。
const PANELS = ["files", "changes"];

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

function togglePanel(id) {
  const root = layout();
  const panel = find(root, "panel"), body = find(root, "panel-body");
  if (!panel) return;
  if (!panel.hidden && body?.active === id) run("layout.hide", { id: "panel" });
  else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
}

// 閉じている → Files → Changes → 閉じる、の順に1段進める
function cyclePanel() {
  const root = layout();
  const panel = find(root, "panel"), body = find(root, "panel-body");
  if (!panel) return;
  const now = panel.hidden ? null : body?.active ?? null;
  const next = now === null ? PANELS[0] : PANELS[PANELS.indexOf(now) + 1];
  if (!next) run("layout.hide", { id: "panel" });
  else { run("layout.select", { stack: "panel-body", child: next }); run("layout.show", { id: "panel" }); }
}

// 右パネルを開いている間はターミナル領域（main）を隠し、パネルを全幅で見せる。
// タブバーのボタンで開閉した場合も拾えるよう、キー処理ではなく状態を見て合わせる。
function syncFullPanel() {
  const root = layout();
  const panel = find(root, "panel"), main = find(root, "main");
  if (!panel || !main) return;
  const panelShown = !panel.hidden;
  if (Boolean(main.hidden) !== panelShown) run(panelShown ? "layout.hide" : "layout.show", { id: "main" });
}

export default class WorkspaceStatus extends View {
  init(_props, cx) {
    cx.timer.every(250, () => syncFullPanel());
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "cycle") cyclePanel();
        else if (PANELS.includes(c)) togglePanel(c);
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    const list = agents();
    const needs = list.filter(a => a.status === "blocked").length;
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .child(div().id("palette").text_color(t.dim).on_click(() => run("app.palette")).child(`${window()?.platform === "macos" ? "⌘" : "Ctrl"} Shift P  commands`));
  }
}
