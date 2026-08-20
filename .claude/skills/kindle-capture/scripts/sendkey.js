// CGEventPostToPid で対象プロセスに矢印キーの down/up を直送する。
// フォーカスを奪わず、他アプリにキーが漏れない（実機検証済み）。
// 使い方: osascript -l JavaScript sendkey.js <pid> <keycode>
//   keycode: 123=左矢印（日本語の本の次ページ） 124=右矢印（前ページ/英語の本の次ページ）
function run(argv) {
  ObjC.import("CoreGraphics");
  const pid = parseInt(argv[0], 10);
  const keyCode = parseInt(argv[1], 10);
  if (!pid || isNaN(keyCode)) return "error: usage sendkey.js <pid> <keycode>";
  const down = $.CGEventCreateKeyboardEvent($(), keyCode, true);
  const up = $.CGEventCreateKeyboardEvent($(), keyCode, false);
  $.CGEventPostToPid(pid, down);
  delay(0.03);
  $.CGEventPostToPid(pid, up);
  return "ok";
}
