#!/usr/bin/env python3
"""Extract the publisher's 100-entry TOC and conservatively link known games."""
import csv
import hashlib
import html
import json
import re
import sys
from pathlib import Path
from importlib.machinery import SourceFileLoader

PUBLISHER = "https://detail.youzan.com/show/goods?alias=3f1n4cv8qnk3m&from_source=gbox_seo"
ARCHIVE = "https://homepages.cwi.nl/~aeb/go/games/games/Go_Seigen/"
# Dates identify archive files, not inferred book publication dates. Apart from
# 1 and 2, these are explicit catalogue/event matches, not page-by-page checks.
MATCHES = {
    1: "1926-00-00", 2: "1927-11-25", 5: "1928-12-26",
    30: "1939-12-26", 31: "1940-03-15", 32: "1940-06-12", 33: "1940-08-04", 34: "1940-10-16",
    35: "1941-08-07", 36: "1941-10-03", 37: "1941-12-27", 38: "1942-02-25", 39: "1942-05-02",
    41: "1942-12-27", 42: "1943-02-25", 43: "1943-06-02", 44: "1943-09-07", 45: "1944-02-19",
    47: "1946-09-00b", 48: "1946-09-00", 49: "1947-10-03",
    52: "1948-07-20", 53: "1948-11-16",
    64: "1951-12-22", 65: "1952-04-24", 66: "1952-05-14", 67: "1952-06-11",
    70: "1953-11-19", 71: "1954-07-24", 72: "1955-07-19", 73: "1955-08-16", 77: "1956-09-28",
}


def main():
    cache, output = map(Path, sys.argv[1:3])
    source = (cache / "publisher.html").read_text()
    entries, volume = [], None
    for paragraph in re.findall(r"<p\b[^>]*>(.*?)</p>", source, re.S):
        text = " ".join(html.unescape(re.sub("<[^>]+>", "", paragraph)).split())
        if text in ("上卷", "下卷"):
            volume = text
        match = re.fullmatch(r"(\d{1,2})\s+(.+)", text)
        if volume and match:
            local = int(match[1])
            number = local + (50 if volume == "下卷" else 0)
            entries.append({"id": f"book-{number:03}", "book_number": number,
                            "volume": volume, "volume_number": local, "title": match[2],
                            "status": "needs_game_identification", "sgf_file": None})
    assert [e["book_number"] for e in entries] == list(range(1, 101)), "Publisher TOC changed"
    parser = SourceFileLoader("extractor", str(Path(__file__).with_name("extract-go-seigen.py"))).load_module()
    (output / "sgf").mkdir(parents=True, exist_ok=True)
    allowed = {"PB", "PW", "BR", "WR", "DT", "RE", "EV", "RO", "PC", "KM", "HA", "RU", "AB", "AW", "AE", "PL", "TM"}
    for record in entries:
        number = record["book_number"]
        if number not in MATCHES:
            continue
        name = MATCHES[number] + ".sgf"
        raw = (cache / "cwi" / name).read_bytes()
        nodes = parser.sgf_mainline(raw.decode("utf-8"))
        props = {k: v for k, v in nodes[0].items() if k in allowed}
        props.update({"GM": ["1"], "FF": ["4"], "CA": ["UTF-8"], "SZ": ["19"]})
        moves = parser.moves_from_nodes(nodes)
        def escape(value):
            return value.replace("\\", "\\\\").replace("]", "\\]")
        sgf = "(;" + "".join(k + "".join("["+escape(v)+"]" for v in values) for k, values in props.items())
        sgf += "\n" + "".join(f";{color}[{point}]" for color, point in moves) + ")\n"
        relative = f"sgf/{number:03}-{name}"
        (output / relative).write_text(sgf)
        status = "identified_from_publisher_preview" if number in (1, 2) else "matched_by_catalog_title_and_archive_event"
        record.update({"status": status, "sgf_file": relative, "properties": props,
                       "archive_url": ARCHIVE + name, "source_sha256": hashlib.sha256(raw).hexdigest(),
                       "sgf_sha256": hashlib.sha256(sgf.encode()).hexdigest(), "move_count": len(moves),
                       "moves": [{"color": c, "point": p} for c, p in moves],
                       "verification_scope": "对局身份核对；完整落子使用历史档案，未逐手核对全书印刷棋谱。"})
        if number in (1, 2):
            record["evidence"] = {"type": "publisher_preview", "pages": [3, 4] if number == 1 else [5, 6],
                                   "matched_facts": "书中编号、双方、年份/日期和开局落点"}
        else:
            record["evidence"] = {"type": "catalog_inference", "title": record["title"],
                                   "event": props.get("EV", []), "round": props.get("RO", []),
                                   "note": "依目录中的棋手、番棋轮次及上下文年代对应；待原书逐页复核。"}
    manifest = {"schema_version": 1, "collection": "吴清源自选百局", "isbn": "9787559610966",
                "catalog_source": PUBLISHER, "catalog_sha256": hashlib.sha256(source.encode()).hexdigest(),
                "status": "catalog_complete_game_records_partial", "catalog_count": 100,
                "linked_sgf_count": len(MATCHES), "publisher_preview_identified_count": 2,
                "catalog_inferred_count": len(MATCHES)-2, "unresolved_count": 100-len(MATCHES),
                "games": entries}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
    with (output / "catalog.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        columns = ["book_number", "volume", "volume_number", "title", "status", "date", "black", "white", "result", "move_count", "sgf_file", "archive_url"]
        writer = csv.DictWriter(stream, columns)
        writer.writeheader()
        for record in entries:
            row = {k: record.get(k, "") for k in columns}
            for field, prop in [("date", "DT"), ("black", "PB"), ("white", "PW"), ("result", "RE")]:
                row[field] = record.get("properties", {}).get(prop, [""])[0]
            writer.writerow(row)
    print(json.dumps({k: v for k, v in manifest.items() if k != "games"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
