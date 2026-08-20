// PDFKit で複数PDFを1つに結合する（外部ツール不要・macOS標準機能のみ）。
// 使い方: osascript -l JavaScript mergepdfs.js in1.pdf in2.pdf ... out.pdf
ObjC.import("Quartz");
function run(argv) {
  const outPath = argv[argv.length - 1];
  const merged = $.PDFDocument.alloc.init;
  for (let i = 0; i < argv.length - 1; i++) {
    const d = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[i]));
    if (d.isNil()) return "ERROR: cannot open " + argv[i];
    for (let j = 0; j < d.pageCount; j++) {
      merged.insertPageAtIndex(d.pageAtIndex(j), merged.pageCount);
    }
  }
  if (!merged.writeToFile(outPath)) return "ERROR: write failed";
  return "ok pages=" + merged.pageCount;
}
