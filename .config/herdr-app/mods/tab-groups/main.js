import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex, InputState, Input } from "gpui-base";
import { spaces, panes, run, openOverlay, closeOverlay, theme, window, shared, setShared, layout, settings, props, keys, machines } from "herdr";

// Tab groups for Herdr, like the ones in Chrome. Runs as a layout's tab bar.
//
// Changed from the `tabs` mod shipped with Herdr (https://github.com/herdrdev/herdr-app, Apache-2.0):
// added the groups and their chips, the picker, the group editor, and the group items in the tab menu.
// Tabs have one width, and a line under each name shows its panes (see paneLine).
//
// One folder, four views, chosen by props:
//   Tab bar   click a chip to fold or unfold it, right-click it to edit; drag tabs and chips to move them
//   Tab menu  right-click a tab: the shipped items, plus moving it between groups
//   Picker    mod.open (Cmd+O in keys.json): a number moves the tab, f folds, n creates, e edits, x removes
//   Editor    name, color, fold, delete
//
// Folded tabs are put away with tab.settle: Cmd+number and tab.next skip settled tabs, so the numbers
// match the bar. Herdr lifts a tab's settle in these cases, and the sync every second answers:
//   Shown         stays out while shown, put away again once you leave
//   Finished      put away again; the chip shows a dot
//   Needs input   stays out: the tab shows next to its chip
const KEY = "tab-groups";
// The same colors as the shipped spaces mod.
const COLORS = { ansi2: "#3fae6a", ansi4: "#5b8def", ansi3: "#e3814f", ansi5: "#8b7cf6", ansi6: "#22a99a", ansi1: "#d9649a" };
const FIRST_RUN = {
  groups: [
    { id: "doing", name: "Doing", color: "ansi2", folded: false },
    { id: "later", name: "Later", color: "ansi4", folded: true },
    { id: "waiting", name: "Waiting", color: "ansi3", folded: false },
  ],
  tabs: {},
};
// Every tab has the same width, and its bottom line is cut into one piece per pane, colored by that pane's status.
// 右パネルのボタン。アイコンは付属の svg（別 mod が書き出す画像には頼らない）。
const PANEL_BUTTONS = [
  { id: "files", label: "Files", icon: "mods/files/file.svg" },
  { id: "changes", label: "Changes", icon: "mods/changes/changes.svg" },
  { id: "issues", label: "Issues", icon: "mods/workspace-chrome/circle-check.svg" },
];
const TAB_WIDTH = 180;
const PICKER = { kind: "popup", at: "top", offset: 40, width: 340 };
const EDITOR = { kind: "popup", width: 250 };

const state = () => shared(KEY) ?? FIRST_RUN;
const groupOf = (s, id) => s.groups.find((g) => g.id === s.tabs[id]);
const allTabs = () => spaces().flatMap((sp) => sp.tabs);
const hidden = (tab, group) => Boolean(group?.folded) && !tab.active && tab.status !== "blocked";

// Members sit together, where the group's first tab is.
function inOrder(tabs, s) {
  const out = [];
  for (const tab of tabs) {
    if (out.includes(tab)) continue;
    const g = groupOf(s, tab.id);
    if (g) out.push(...tabs.filter((t) => groupOf(s, t.id) === g));
    else out.push(tab);
  }
  return out;
}

function applyOrder(space, ids) {
  const now = space.tabs.map((t) => t.id);
  ids.forEach((id, i) => {
    if (now[i] === id) return;
    run("tab.move", { id, index: i + 1 });
    now.splice(now.indexOf(id), 1);
    now.splice(i, 0, id);
  });
}

// Makes the real tabs (settle and order) match the state. Safe to call any number of times.
function sync(s) {
  for (const space of spaces()) {
    for (const tab of space.tabs) {
      const hide = hidden(tab, groupOf(s, tab.id));
      if (hide !== tab.settled) run(hide ? "tab.settle" : "tab.unsettle", { id: tab.id });
    }
    applyOrder(space, inOrder(space.tabs, s).map((t) => t.id));
  }
}

function save(next) {
  setShared(KEY, next);
  sync(next);
}

// Forgets closed tabs. Right after a start spaces() is incomplete, so this waits for every machine to load.
function prune(s) {
  if (!machines().every((m) => m.layout === "ready")) return s;
  const live = new Set(allTabs().map((t) => t.id));
  const entries = Object.entries(s.tabs);
  const kept = entries.filter(([id]) => live.has(id));
  if (kept.length === entries.length) return s;
  const next = { ...s, tabs: Object.fromEntries(kept) };
  setShared(KEY, next);
  return next;
}

// Puts the shown tab away and moves to a neighbor. sync has already hidden the group's other tabs,
// so the neighbor is outside the group. Settling a settled tab doesn't move on, so it's unsettled first.
function putAway(tabId, next) {
  const tab = allTabs().find((t) => t.id === tabId);
  if (!tab?.active || !hidden({ ...tab, active: false }, groupOf(next, tabId))) return;
  run("tab.unsettle", { id: tabId });
  run("tab.settle", { id: tabId });
}

// Moves a tab to the end of a group. A null gid takes it out of its group.
function join(tabId, gid, base = state()) {
  const space = spaces().find((sp) => sp.tabs.some((t) => t.id === tabId));
  if (!space) return;
  const tabs = { ...base.tabs };
  if (gid) {
    tabs[tabId] = gid;
    const ids = space.tabs.map((t) => t.id).filter((id) => id !== tabId);
    const last = ids.findLastIndex((id) => base.tabs[id] === gid);
    if (last >= 0) {
      ids.splice(last + 1, 0, tabId);
      applyOrder(space, ids);
    }
  } else {
    delete tabs[tabId];
  }
  const next = { ...base, tabs };
  // run's results don't reach spaces() in the same turn, so a sync here would use the old order. The next tick does it.
  setShared(KEY, next);
  putAway(tabId, next);
}

function setFolded(gid, folded) {
  const s = state();
  const next = { ...s, groups: s.groups.map((g) => (g.id === gid ? { ...g, folded } : g)) };
  save(next);
  const active = spaces().find((sp) => sp.active)?.tabs.find((t) => t.active);
  if (folded && active && next.tabs[active.id] === gid) putAway(active.id, next);
}

function edit(gid, patch) {
  const s = state();
  setShared(KEY, { ...s, groups: s.groups.map((g) => (g.id === gid ? { ...g, ...patch } : g)) });
}

function removeGroup(gid) {
  const s = state();
  save({ groups: s.groups.filter((g) => g.id !== gid), tabs: Object.fromEntries(Object.entries(s.tabs).filter(([, g]) => g !== gid)) });
}

// Reuses a group with that name. A new one gets the least used color.
function ensureGroup(name) {
  const s = state();
  const found = s.groups.find((g) => g.name === name);
  if (found) return { next: s, gid: found.id };
  const uses = (c) => s.groups.filter((g) => g.color === c).length;
  const color = Object.keys(COLORS).reduce((best, c) => (uses(c) < uses(best) ? c : best));
  const gid = `g${Date.now().toString(36)}`;
  return { next: { ...s, groups: [...s.groups, { id: gid, name, color, folded: false }] }, gid };
}

function moveGroup(gid, to, space) {
  const s = state();
  const ids = space.tabs.map((t) => t.id);
  const mine = ids.filter((id) => s.tabs[id] === gid);
  const other = to.group ?? groupOf(s, to.tab)?.id;
  const target = other ? ids.filter((id) => s.tabs[id] === other) : [to.tab];
  if (target.some((id) => mine.includes(id))) return;
  const rest = ids.filter((id) => !mine.includes(id));
  const rightward = ids.indexOf(mine[0]) < ids.indexOf(target[0]);
  rest.splice(rightward ? rest.indexOf(target.at(-1)) + 1 : rest.indexOf(target[0]), 0, ...mine);
  applyOrder(space, rest);
}

// One piece per pane, in the order panes() gives. The focused pane of the shown tab is drawn at full strength.
function paneLine(t, tab, tabPanes) {
  const color = (p) => t[p.status] ?? (p.status ? t.unknown : t.idle) ?? t.dim;
  // Fades a #rrggbb color. Other forms are left as they are.
  const faded = (c) => (/^#[0-9a-f]{6}$/i.test(c) ? `${c}99` : c);
  return h_flex().h(3).mx(2).mb(2).gap(3).flex_none()
    .children(tabPanes.map((p) => div().flex_1().h_full().rounded(2)
      .bg(tab.active && p.focused ? color(p) : faded(color(p)))));
}

const dot = (color) => h_flex().w(14).flex_none().justify_center().child(div().size(10).rounded(5).bg(color));
const icon = (t, name) => svg(`mods/workspace-chrome/${name}.svg`).size(14).flex_none().text_color(t.muted);
const shortcut = (name) => keys().find((b) => b.section === "global" && b.action === name)?.keys ?? "";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

class Bar {
  constructor(cx) {
    this.pressed = null;
    this.panels = JSON.parse(localStorage.getItem("panels") ?? "{}");
    cx.timer.every(1000, () => {
      const s = prune(state());
      this.followClose(s);
      sync(s);
    });
    sync(state());
  }

  // Closing the shown tab makes Herdr pick a neighbor regardless of settle. If that's in a folded group, move on to a visible tab.
  followClose(s) {
    const active = spaces().find((p) => p.active)?.tabs.find((t) => t.active);
    if (!active) return;
    if (active.id !== this.activeId && this.activeId && !allTabs().some((t) => t.id === this.activeId)) putAway(active.id, s);
    this.activeId = active.id;
  }

  // The shipped tab bar ignores settled, so leaving this layout brings every tab back. Coming back, sync hides them again.
  close() {
    for (const tab of allTabs()) if (tab.settled) run("tab.unsettle", { id: tab.id });
  }

  // The side panel is remembered per space: switching shows that space's choice
  // (closed if it never had one), and opening or closing it records it.
  syncPanel(space, panel, body, enabled) {
    if (!space || !panel) return;
    const now = panel.hidden ? null : body?.active ?? null;
    if (space.id !== this.space) {
      const first = this.space === undefined;
      this.space = space.id; this.pending = null;
      if (!(first && !(space.id in this.panels))) {
        const stored = this.panels[space.id] ?? null, want = enabled.includes(stored) ? stored : null;
        if (want !== now) {
          this.pending = { want, until: Date.now() + 1000 };
          if (want) { run("layout.select", { stack: "panel-body", child: want }); run("layout.show", { id: "panel" }); }
          else run("layout.hide", { id: "panel" });
          return;
        }
      }
    }
    // Until the restore lands (or something else won), the old state isn't a choice.
    if (this.pending) {
      if (this.pending.want !== now && Date.now() < this.pending.until) return;
      this.pending = null;
    }
    if (this.panels[space.id] === now) return;
    this.panels[space.id] = now;
    localStorage.setItem("panels", JSON.stringify(this.panels));
  }

  // A drop: a tab joins the group it lands in, and dropping it on an ungrouped tab takes it out.
  drop(from, to, space) {
    if (from.group) return moveGroup(from.group, to, space);
    if (to.group) return join(from.tab, to.group);
    const s = state();
    const tabs = { ...s.tabs };
    const g = groupOf(s, to.tab);
    if (g) tabs[from.tab] = g.id;
    else delete tabs[from.tab];
    run("tab.move", { id: from.tab, index: space.tabs.findIndex((x) => x.id === to.tab) + 1 });
    const next = { ...s, tabs };
    setShared(KEY, next);
    putAway(from.tab, next);
  }

  render() {
    const t = theme();
    const s = state();
    const space = spaces().find((p) => p.active);
    const shown = inOrder(space?.tabs ?? [], s);
    this.followClose(s);
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const item = (c, inGroup) => {
      const tabPanes = panes().filter((p) => p.tab === c.id);
      const program = tabPanes.find((p) => p.program?.agent)?.program ?? tabPanes[0]?.program;
      const name = /^tb\d+$/.test(c.name) ? program?.name ?? "Terminal" : c.name;
      const idle = inGroup ? "#00000000" : t.chrome;
      const row = h_flex().flex_1().min_h(0).px(10).gap(7).items_center()
        .when(Boolean(program?.icon), (el) => el.child(program.tint ? svg(program.icon).size(14).flex_none().text_color(t.muted) : image(program.icon).size(14).flex_none()))
        .child(div().flex_1().min_w(0).truncate().child(c.zoomed ? `${name} Z` : name))
        .when(c.status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(c.status === "blocked" || c.status === "done", (el) => el.child(div().size(6).flex_none().rounded(3).bg(t[c.status])))
        .when(c.active, (el) => el.child(div().id(`close-${c.id}`).flex_none().text_color(t.dim).on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child(svg("mods/pane/close.svg").size(12))));
      return v_flex().id(`tab-${c.id}`).h(29).w(TAB_WIDTH).rounded(7).flex_none().text_size(12.8)
        .border(1).border_color(c.active ? t.border : idle).bg(c.active ? t.raised : idle).text_color(c.active ? t.foreground : t.muted)
        .hover((s) => s.bg(t.hover))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.pressed = { tab: c.id }; if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from && from.tab !== c.id) this.drop(from, { tab: c.id }, space);
          else run("tab.select", { id: c.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: KEY, kind: "popup", width: 240, props: { target: { id: c.id, space: space.id } } }); })
        .child(row)
        .child(paneLine(t, c, tabPanes));
    };
    const block = (g, members) => {
      const color = COLORS[g.color] ?? t.accent;
      const away = members.filter((m) => hidden(m, g));
      const visible = members.filter((m) => !hidden(m, g));
      const status = ["done", "working"].find((st) => away.some((m) => m.status === st));
      const chip = h_flex().id(`chip-${g.id}`).h(23).px(8).gap(5).flex_none().items_center().rounded(6)
        .bg(color).text_color("#ffffff").text_size(11.5).font_semibold().cursor_pointer()
        .hover((s) => s.opacity(0.85))
        .on_mouse_down("left", (_e, cx) => { cx.stop_propagation(); this.pressed = { group: g.id }; })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from?.group === g.id) setFolded(g.id, !g.folded);
          else if (from) this.drop(from, { group: g.id }, space);
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: KEY, ...EDITOR, props: { group: g.id } }); })
        .child(div().max_w(120).truncate().child(g.name))
        .when(g.folded, (el) => el.child(div().opacity(0.8).font_medium().child(String(members.length))));
      return h_flex().id(`block-${g.id}`).h(33).gap(3).flex_none().items_center().rounded(9)
        .when(visible.length > 0, (el) => el.px(3).bg(`${color}26`))
        .child(chip)
        .when(status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(status === "done", (el) => el.child(div().size(6).rounded(3).bg(t.done)))
        .children(visible.map((m) => item(m, true)));
    };
    const strip = [];
    for (const tab of shown) {
      const g = groupOf(s, tab.id);
      if (!g) strip.push(item(tab, false));
      else if (tab === shown.find((x) => groupOf(s, x.id) === g)) strip.push(block(g, shown.filter((x) => groupOf(s, x.id) === g)));
    }
    const root = layout(), sidebar = find(root, "sidebar"), w = window();
    // Old saved rails and a dragged-narrow sidebar can be smaller than the window buttons.
    const lightsPadding = w?.platform === "macos" && w.titlebar === "none" && !w.fullscreen && root?.traffic_lights
      ? Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0))
      : 10;
    const panel = find(root, "panel"), body = find(root, "panel-body");
    // shared("workspace.panels") には Herdr が files と changes だけを入れる。足した分は常に出す。
    const enabled = [...new Set([...(shared("workspace.panels") ?? []), ...PANEL_BUTTONS.map((b) => b.id)])];
    this.syncPanel(space, panel, body, enabled);
    const panelButton = (id, label, panelIcon) => {
      const on = panel && !panel.hidden && body?.active === id;
      return h_flex().id(`panel-${id}`).h(26).px(8).gap(5).flex_none().items_center().rounded(6)
        .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
        .hover((s) => s.bg(t.hover)).on_mouse_down("left", stop)
        .on_click(() => {
          if (on) run("layout.hide", { id: "panel" });
          else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
        }).child(svg(panelIcon).size(14)).child(label);
    };
    return h_flex().size_full().min_w(0).px(10).pl(lightsPadding).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .on_mouse_up("left", () => { this.pressed = null; })
      .on_scroll_wheel((e) => { if (Math.abs(e.delta.y) >= 1) run(e.delta.y > 0 ? "tab.prev" : "tab.next"); })
      .child(h_flex().id("tab-scroll").flex_1().min_w(0).h_full().items_center().gap(3).overflow_x_scrollbar().children(strip))
      .child(button("tab-new", "+", () => openOverlay({ mod: "new-menu", kind: "popup", width: 250, height: 512 })))
      .children(PANEL_BUTTONS.filter((b) => enabled.includes(b.id)).map((b) => panelButton(b.id, b.label, b.icon)))
      .when(w?.buttons, (el) => el.child(button("minimize", w.platform === "windows" ? svg("mods/tabs/win-min.svg").size(16) : "−", () => run("window.minimize")))
        .child(button("maximize", w.platform === "windows" ? svg(`mods/tabs/${w.maximized ? "win-restore" : "win-max"}.svg`).size(16) : "□", () => run("window.maximize")))
        .child(button("close-window", w.platform === "windows" ? svg("mods/tabs/win-close.svg").size(16) : svg("mods/pane/close.svg").size(13), () => run("window.close"))));
  }
}

// Right-click on a tab, styled like the shipped menu mod. Up and down move, Enter runs.
class TabMenu {
  constructor(p, cx) {
    this.p = p;
    this.at = 0;
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  items() {
    const { id, space } = this.p.target;
    const s = state();
    return [
      { label: "Rename", icon: "square-pen", hint: shortcut("tab.rename"), act: () => run("tab.rename", { id }) },
      { label: "New tab", icon: "plus", hint: shortcut("tab.new"), act: () => run("tab.new", { space }) },
      ...s.groups.map((g, i) => ({ label: g.name, color: g.color, current: s.tabs[id] === g.id, line: i === 0, act: () => join(id, g.id) })),
      { label: "New group…", icon: "plus", line: s.groups.length === 0, act: () => openOverlay({ mod: KEY, ...PICKER, props: { tab: id, create: true } }) },
      ...(groupOf(s, id) ? [{ label: "Remove from group", icon: "x", act: () => join(id, null) }] : []),
      { label: "Close", icon: "x", hint: shortcut("tab.close"), line: true, act: () => run("tab.close", { id }) },
    ];
  }

  choose(it) {
    closeOverlay(this.p.overlay);
    it?.act();
  }

  render() {
    const t = theme();
    const list = this.items();
    return v_flex().id("tg-menu").track_focus(this.handle).w_full().min_h(0).p(5).bg(t.popover).text_size(12.8)
      .on_key_down((e, cx) => {
        if (e.key === "down") this.at = (this.at + 1) % list.length;
        else if (e.key === "up") this.at = (this.at + list.length - 1) % list.length;
        else if (e.key === "enter") this.choose(list[this.at]);
        else if (e.key === "escape") closeOverlay(this.p.overlay);
        else return;
        cx.notify();
      })
      .children(list.map((it, i) =>
        v_flex()
          .when(it.line, (el) => el.child(div().mx(7).my(4).h(1).bg(t.border)))
          .child(h_flex().id(`mi-${i}`).h(31).px(8).gap(9).rounded(7).items_center().justify_between().text_color(t.foreground)
            .when(i === this.at, (el) => el.bg(t.selected))
            .hover((s) => s.bg(t.hover))
            .on_click(() => this.choose(it))
            .child(it.color ? dot(COLORS[it.color] ?? t.accent) : icon(t, it.icon))
            .child(div().flex_1().truncate().child(it.label))
            .child(div().text_size(11).text_color(t.dim).child(it.current ? "✓" : it.hint ?? "")))));
  }
}

// The picker. It moves the tab shown when it opened, or the tab it was opened for.
class Picker {
  constructor(p, cx) {
    this.p = p;
    this.tabId = p.tab ?? spaces().find((sp) => sp.active)?.tabs.find((t) => t.active)?.id;
    const s = state();
    this.at = Math.max(0, s.groups.findIndex((g) => g.id === s.tabs[this.tabId]));
    this.handle = cx.focus_handle();
    this.input = InputState.new({ placeholder: "New group name" });
    this.input.on("submit", () => this.create());
    this.creating = false;
    if (p.create) this.startCreating(cx);
    else this.handle.focus();
  }

  dismiss() {
    closeOverlay(this.p.overlay);
  }

  startCreating(cx) {
    this.creating = true;
    this.input.focus();
    // Focus can be taken away right after opening, so focus again, like the shipped prompt mod.
    cx.timer.after(600, () => this.input.focus());
  }

  create() {
    const name = this.input.value().trim();
    this.dismiss();
    if (!name) return;
    const { next, gid } = ensureGroup(name);
    if (this.tabId) join(this.tabId, gid, next);
    else setShared(KEY, next);
  }

  pick(g) {
    if (!g) return;
    this.dismiss();
    if (this.tabId && state().tabs[this.tabId] !== g.id) join(this.tabId, g.id);
  }

  ungroup() {
    this.dismiss();
    if (this.tabId) join(this.tabId, null);
  }

  editor(g) {
    if (!g) return;
    this.dismiss();
    openOverlay({ mod: KEY, ...EDITOR, at: "top", offset: 40, props: { group: g.id } });
  }

  key(e, cx) {
    if (this.creating) {
      if (e.key === "escape") this.dismiss();
      return;
    }
    if (e.modifiers?.platform || e.modifiers?.control) return;
    const groups = state().groups;
    const k = e.key;
    if (k === "escape") this.dismiss();
    else if (k === "down" || k === "j") this.at = (this.at + 1) % Math.max(1, groups.length);
    else if (k === "up" || k === "k") this.at = (this.at + groups.length - 1) % Math.max(1, groups.length);
    else if (k === "enter") this.pick(groups[this.at]);
    else if (/^[1-9]$/.test(k)) this.pick(groups[Number(k) - 1]);
    else if (k === "f" && groups[this.at]) { this.dismiss(); setFolded(groups[this.at].id, !groups[this.at].folded); }
    else if (k === "e") this.editor(groups[this.at]);
    else if (k === "n") this.startCreating(cx);
    else if (k === "x") this.ungroup();
    else return;
    cx.stop_propagation();
    cx.notify();
  }

  render() {
    const t = theme();
    const s = state();
    const tabs = allTabs();
    const tab = tabs.find((x) => x.id === this.tabId);
    const inGroup = Boolean(groupOf(s, this.tabId));
    this.at = Math.max(0, Math.min(this.at, s.groups.length - 1));
    const row = (id, on, action) => h_flex().id(id).h(31).px(8).gap(9).rounded(7).items_center().text_color(t.foreground).cursor_pointer()
      .when(on, (el) => el.bg(t.selected)).hover((st) => st.bg(t.hover)).on_click(action);
    const count = (g) => tabs.filter((x) => s.tabs[x.id] === g.id).length;
    return v_flex().id("tg-picker").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .w_full().min_h(0).p(5).bg(t.popover).text_size(12.8)
      .child(div().px(8).pt(5).pb(6).text_size(11.5).text_color(t.dim).truncate().child(tab ? `Move “${tab.name}” to` : "Groups"))
      .children(s.groups.map((g, i) => row(`pick-${g.id}`, !this.creating && i === this.at, () => this.pick(g))
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); this.editor(g); })
        .child(div().w(10).flex_none().text_size(11).text_color(t.dim).child(i < 9 ? String(i + 1) : ""))
        .child(dot(COLORS[g.color] ?? t.accent))
        .child(div().flex_1().truncate().child(g.name))
        .child(div().text_size(11).text_color(t.dim).child(`${s.tabs[this.tabId] === g.id ? "✓  " : ""}${count(g)} ${g.folded ? "▸" : "▾"}`))))
      .child(div().mx(7).my(4).h(1).bg(t.border))
      .when(this.creating, (el) => el.child(h_flex().h(36).mx(3).px(8).gap(8).items_center().rounded(8).border_1().border_color(t.accent).bg(t.background)
        .child(icon(t, "plus"))
        .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground))))
      .when(!this.creating, (el) => el.child(row("pick-new", false, (_e, cx) => { this.startCreating(cx); cx.notify(); })
        .child(div().w(10).flex_none().text_size(11).text_color(t.dim).child("n"))
        .child(icon(t, "plus"))
        .child("New group")))
      .when(!this.creating && inGroup, (el) => el.child(row("pick-out", false, () => this.ungroup())
        .child(div().w(10).flex_none().text_size(11).text_color(t.dim).child("x"))
        .child(icon(t, "x"))
        .child("Remove from group")))
      .child(div().px(8).pt(7).pb(4).text_size(11).text_color(t.dim).child(this.creating ? "enter create · esc close" : "1-9 move · f fold · e edit · j/k select"));
  }
}

// The group editor, opened by right-clicking a chip or e in the picker. The name applies as you type.
class GroupEditor {
  constructor(p, cx) {
    this.p = p;
    const name = state().groups.find((g) => g.id === p.group)?.name ?? "";
    this.input = InputState.new({ value: name, placeholder: "Group name" });
    if (name) this.input.set_selected_range({ start: 0, end: name.length });
    this.input.on("change", () => {
      const next = this.input.value().trim();
      if (next) edit(p.group, { name: next });
    });
    this.input.on("submit", () => closeOverlay(p.overlay));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.handle = cx.focus_handle();
  }

  render() {
    const t = theme();
    const p = this.p;
    const g = state().groups.find((x) => x.id === p.group);
    if (!g) return div();
    const row = (id, iconName, label, action) => h_flex().id(id).h(31).px(8).gap(9).rounded(7).items_center().text_color(t.foreground).cursor_pointer()
      .hover((st) => st.bg(t.hover))
      .on_click(() => { closeOverlay(p.overlay); action(); })
      .child(icon(t, iconName)).child(label);
    return v_flex().id("tg-editor").track_focus(this.handle).w_full().min_h(0).p(6).gap(7).bg(t.popover).text_size(12.8)
      .on_key_down((e, cx) => { if (e.key === "escape") { closeOverlay(p.overlay); cx.stop_propagation(); } })
      .child(Input.new(this.input).h(32).px(9).rounded(8).border_1().border_color(t.accent).bg(t.background).text_size(12.8).text_color(t.foreground))
      .child(h_flex().gap(7).px(3).py(2).children(Object.keys(COLORS).map((c) =>
        div().id(`color-${c}`).size(22).rounded(11).bg(COLORS[c]).cursor_pointer().border(2).border_color(g.color === c ? t.foreground : t.popover)
          .hover((st) => st.opacity(0.8))
          .on_click(() => edit(p.group, { color: c })))))
      .child(v_flex()
        .child(row("edit-fold", "square", g.folded ? "Unfold" : "Fold", () => setFolded(g.id, !g.folded)))
        .child(row("edit-delete", "x", "Delete group (keep tabs)", () => removeGroup(g.id))));
  }
}

export default class TabGroups extends View {
  init(_props, cx) {
    const p = props() ?? {};
    if (!p.overlay) this.ui = new Bar(cx);
    else if (p.group) this.ui = new GroupEditor(p, cx);
    else if (p.target) this.ui = new TabMenu(p, cx);
    else this.ui = new Picker(p, cx);
  }

  async close() {
    this.ui.close?.();
  }

  render() {
    return this.ui.render();
  }
}
