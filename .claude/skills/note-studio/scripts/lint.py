#!/usr/bin/env python3
"""note-studio 文体 lint。

使い方:  python3 lint.py <記事ファイル.md>

style-guide.md の「禁止リスト」「版面規約」を機械測定する。
FAIL が1件でもあれば終了コード 1。判断が要るものは WARN で出す（自動では直さない）。
"""
import re
import sys

# --- 禁止語辞書 -------------------------------------------------------------
EXCUSE = ["など", "いろんな", "様々", "さまざま", "といった"]
CLICHE = ["行われた", "開催された", "抜けるような", "言葉にできない",
          "改めて感じた", "ふと思った", "肩をふるわせ", "痛感した", "身をもって"]
ONOMATO = ["ワクワク", "ドキドキ", "サクッと", "ガンガン", "しみじみ", "じわじわ",
           "エモい", "バズ", "マジで", "ガチで", "エグい", "めちゃくちゃ", "めっちゃ",
           "ざっくり", "もやもや", "ぼんやり", "ふわっと", "ヒヤリ", "ぐっと", "ぎゅっと"]
FIRST_PERSON_NG = ["わたし", "私", "自分は"]  # 一人称は「僕」で固定
WEAK_END = ["という気がする", "かもしれない", "と思います", "気がした"]
ADJ = ["すごい", "大きい", "小さい", "嬉しい", "楽しい", "悲しい", "怖い", "面白い",
       "新しい", "古い", "早い", "速い", "遅い", "高い", "低い", "多い", "少ない",
       "美しい", "寒い", "暑い", "強い", "弱い", "深い", "浅い"]
BANAL_OPEN = re.compile(r"(に行った|について書き|を始めまし|してきました)")
TIMEPLACE_OPEN = re.compile(r"^(\d+時|午前|午後|今年|去年|昨年|\d+月|\d+年|"
                            r"[ぁ-んァ-ヶ一-龥]{2,6}(駅|市|区|町|オフィス|会議室))")
HIRAGANA_END = set("たるいだすねよかなんうくきせれめびぶつでてにをはもらりろわ")


def load(path):
    """frontmatter と「## メモ・経緯」節を落とし、(本文行, 元の行番号) を返す。"""
    raw = open(path, encoding="utf-8").read().split("\n")
    i = 0
    if raw and raw[0].strip() == "---":
        i = 1
        while i < len(raw) and raw[i].strip() != "---":
            i += 1
        i += 1
    out, skip = [], False
    for n in range(i, len(raw)):
        line = raw[n]
        if line.startswith("## "):
            skip = "メモ" in line or "経緯" in line
        if not skip:
            out.append((n + 1, line))
    return out


def sentences(text):
    return [s for s in re.split(r"(?<=[。？！])", text) if s.strip()]


def main(path):
    body = load(path)
    text = "\n".join(l for _, l in body)
    fails, warns, passes = [], [], []

    def excerpt(line, word):
        """ヒットした語の前後を切り出す（先頭50字ではなく該当箇所を見せる）。"""
        i = line.find(word)
        s = max(0, i - 20)
        return f"…{line[s:i + len(word) + 20].strip()}… ← 「{word}」"

    def scan(label, words, bucket):
        hits = [(n, l, w) for n, l in body for w in words if w in l]
        if hits:
            bucket.append((label, [f"  L{n}: {excerpt(l, w)}" for n, l, w in hits[:8]],
                           len(hits)))
        else:
            passes.append(label)

    scan("エクスキューズ語（第3発）", EXCUSE, fails)
    scan("常套句・としたもんだ表現（第4発）", CLICHE, fails)
    scan("オノマトペ・流行語（第5発）", ONOMATO, fails)
    scan("言うまでもなく（第6発）", ["言うまでもなく"], fails)
    scan("弱い述部（第16発）", WEAK_END, warns)
    scan("一人称は「僕」で固定", FIRST_PERSON_NG, fails)

    # 笑いの合図
    warai = [(n, l) for n, l in body
             if re.search(r"[（(]笑[）)]|[ぁ-んァ-ヶ一-龥]w+(?=[。、\s]|$)|草。", l)]
    if warai:
        fails.append(("笑いの合図（第7発）",
                      [f"  L{n}: …{l.strip()[:50]}…" for n, l in warai[:8]], len(warai)))
    else:
        passes.append("笑いの合図（第7発）")

    # ぶっちゃけは1回まで
    b = text.count("ぶっちゃけ")
    if b > 1:
        warns.append(("「ぶっちゃけ」は1記事1回まで", [f"  {b}回"], b))
    else:
        passes.append("「ぶっちゃけ」の回数")

    # --- 書き出し（第1発） ---
    opening = next((l for _, l in body if l.strip() and not l.startswith(("#", ">", "!", "|"))), "")
    if opening:
        first = sentences(opening)[0] if sentences(opening) else opening
        head140 = re.sub(r"\s", "", text)[:140]
        checks = [
            ("一文目の体言止め",
             first.rstrip("。").strip() and first.rstrip("。")[-1] not in HIRAGANA_END),
            ("凡庸出だし", bool(BANAL_OPEN.search(first))),
            ("時日・場所からの書き出し", bool(TIMEPLACE_OPEN.search(first.strip()))),
        ]
        for label, bad in checks:
            if bad:
                fails.append((f"書き出し: {label}（第1・4発）",
                              [f"  一文目: {first.strip()[:60]}"], 1))
            else:
                passes.append(f"書き出し: {label}なし")
        if re.search(r"[0-9０-９]", head140):
            warns.append(("冒頭140字に数詞（第1・3発）",
                          ["  記事を動かすデータか確認する。違うなら削る",
                           f"  冒頭: {head140[:60]}…"], 1))
        else:
            passes.append("冒頭の数詞なし")
        if len(first) > 60:
            warns.append(("書き出しが長い", [f"  一文目 {len(first)}字（三行以内で撃つ）"], 1))

    # --- 版面 ---
    bold = len(re.findall(r"\*\*[^*]+\*\*", text))
    if bold > 3:
        fails.append(("太字は1記事3箇所まで", [f"  {bold}箇所"], bold))
    else:
        passes.append("太字3箇所以内")

    long_h = [(n, l) for n, l in body if l.startswith("## ") and len(l[3:].strip()) > 20]
    if long_h:
        fails.append(("見出しは20字以内",
                      [f"  L{n}: {l[3:].strip()}（{len(l[3:].strip())}字）" for n, l in long_h], len(long_h)))
    else:
        passes.append("見出し20字以内")

    # 段落の行数
    para, start, longp = [], None, []
    for n, l in body + [(0, "")]:
        if l.strip() and not l.startswith("#"):
            para.append(l)
            start = start or n
        else:
            if len(para) >= 5:
                longp.append((start, len(para)))
            para, start = [], None
    if longp:
        fails.append(("5行以上の段落は割る", [f"  L{n}: {c}行" for n, c in longp], len(longp)))
    else:
        passes.append("段落は4行以内")

    # 文の長さ
    long_s = [s.strip() for s in sentences(re.sub(r"[#*>|`]", "", text)) if len(s.strip()) > 60]
    if long_s:
        warns.append(("60字超の文（二つに分けられないか・第2/16発）",
                      [f"  {s[:55]}…（{len(s)}字）" for s in long_s[:6]], len(long_s)))
    else:
        passes.append("文の長さ")

    # 一文に形容詞2つ以上
    multi_adj = [s.strip() for s in sentences(text) if sum(a in s for a in ADJ) >= 2]
    if multi_adj:
        warns.append(("形容詞は一文にひとつ（第18発）",
                      [f"  {s[:55]}…" for s in multi_adj[:6]], len(multi_adj)))
    else:
        passes.append("形容詞は一文にひとつ")

    # --- 出力 ---
    print(f"== note-studio lint: {path} ==\n")
    for tag, bucket in (("FAIL", fails), ("WARN", warns)):
        for label, lines, count in bucket:
            print(f"[{tag}] {label}  ({count}件)")
            for l in lines:
                print(l)
            print()
    print(f"[PASS] {len(passes)}項目: " + " / ".join(passes))
    print(f"\n合計: FAIL {len(fails)} / WARN {len(warns)}")
    print("※ 転の有無・銃の回収・場面の実在は機械測定できない。style-guide.md の「完成判定」で人が見る。")
    return 1 if fails else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
