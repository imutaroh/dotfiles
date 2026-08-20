// PDFのページ数を数える／1ページだけ抜き出す（100MB超のPDFはReadツールで
// 読めないため、抜き出してから読む）。
// 使い方:
//   ページ数: osascript -l JavaScript pdfinfo.js count <in.pdf>
//   抜き出し: osascript -l JavaScript pdfinfo.js extract <in.pdf> <out.pdf> <0始まりページ番号>
ObjC.import("Quartz");
function run(argv) {
  const mode = argv[0];
  const d = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[1]));
  if (d.isNil()) return "ERROR: cannot open " + argv[1];
  if (mode === "count") return "" + d.pageCount;
  if (mode === "extract") {
    const out = $.PDFDocument.alloc.init;
    out.insertPageAtIndex(d.pageAtIndex(parseInt(argv[3], 10)), 0);
    return out.writeToFile(argv[2]) ? "ok" : "ERROR: write failed";
  }
  return "ERROR: usage pdfinfo.js count|extract ...";
}
