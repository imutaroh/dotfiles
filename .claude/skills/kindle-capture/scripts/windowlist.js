// Kindle のウィンドウ（pid / windowID / bounds）を JSON で返す。
// 使い方: osascript -l JavaScript windowlist.js
// 出力例: {"found":true,"pid":38296,"windowID":47561,"x":1045,"y":1473,"width":1470,"height":923}
//
// 罠: CGWindowListCopyWindowInfo の戻り値は ObjC.castRefToObject を挟まないと
// deepUnwrap が undefined になる（実機で確認済み。削除しない）。
// kCGWindowListOptionAll を使うのは、別 Space のウィンドウも発見するため。
// Kindle は layer 0 に空タイトルのバー状ウィンドウを多数持つので最大面積で本体を選ぶ。
ObjC.import("CoreGraphics");
const ref = $.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, $.kCGNullWindowID);
const arr = ObjC.deepUnwrap(ObjC.castRefToObject(ref));
const names = ["Kindle", "Amazon Kindle"];
let best = null;
for (const w of arr) {
  if (!names.includes(w.kCGWindowOwnerName)) continue;
  if (w.kCGWindowLayer !== 0) continue;
  const area = w.kCGWindowBounds.Width * w.kCGWindowBounds.Height;
  if (!best || area > best.area || (area === best.area && w.kCGWindowNumber < best.windowID)) {
    best = { area: area, pid: w.kCGWindowOwnerPID, windowID: w.kCGWindowNumber,
             x: w.kCGWindowBounds.X, y: w.kCGWindowBounds.Y,
             width: w.kCGWindowBounds.Width, height: w.kCGWindowBounds.Height };
  }
}
best ? JSON.stringify({found: true, pid: best.pid, windowID: best.windowID,
                       x: best.x, y: best.y, width: best.width, height: best.height})
     : JSON.stringify({found: false});
