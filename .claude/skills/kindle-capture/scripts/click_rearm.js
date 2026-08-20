// Kindle のキー受付状態を再アームする（数秒だけ前面化してページ本文をクリックし、
// マウス位置と前面アプリを復元する）。
// 使い方: osascript -l JavaScript click_rearm.js <clickX> <clickY>
//   clickX/clickY: グローバル座標。ページ本文の中央を指定する
//   （タイトルバーのクリックでは再アームされない。ページ送りゾーン=左右端は避ける）
//
// ガード: 前面化が確認できなければクリックせず "ABORT" を返す。
// これを外すとユーザーの作業中アプリに誤クリックが飛ぶ（実機で事故済み。必須）。
function run(argv) {
  ObjC.import("Cocoa");
  const ws = $.NSWorkspace.sharedWorkspace;
  const prevName = ws.frontmostApplication.localizedName.js;
  const mouse = $.NSEvent.mouseLocation; // Cocoa座標（左下原点）
  const mainH = $.NSScreen.mainScreen.frame.size.height;
  const prevX = mouse.x, prevY = mainH - mouse.y; // CG座標（左上原点）へ変換

  let front = "";
  for (let i = 0; i < 3; i++) {
    Application("Kindle").activate();
    delay(2.0);
    front = ws.frontmostApplication.localizedName.js;
    if (front === "Kindle" || front === "Amazon Kindle") break;
  }
  if (front !== "Kindle" && front !== "Amazon Kindle") {
    return "ABORT: frontmost is " + front;
  }
  const pt = { x: parseFloat(argv[0]), y: parseFloat(argv[1]) };
  $.CGWarpMouseCursorPosition(pt);
  delay(0.2);
  const down = $.CGEventCreateMouseEvent($(), $.kCGEventLeftMouseDown, pt, $.kCGMouseButtonLeft);
  const up = $.CGEventCreateMouseEvent($(), $.kCGEventLeftMouseUp, pt, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, down);
  delay(0.08);
  $.CGEventPost($.kCGHIDEventTap, up);
  delay(0.4);
  // マウスを元の位置へ戻し、前面アプリを復元
  $.CGWarpMouseCursorPosition({ x: prevX, y: prevY });
  Application(prevName).activate();
  return "ok: restored " + prevName;
}
