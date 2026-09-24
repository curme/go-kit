#!/usr/bin/env python3
"""Build a provenance-preserving research dataset from the extraction report."""
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

from importlib.machinery import SourceFileLoader


def main():
    cache = Path(sys.argv[1])
    destination = Path(sys.argv[2])
    parser = SourceFileLoader("extractor", str(Path(__file__).with_name("extract-go-seigen.py"))).load_module()
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "sgf").mkdir(exist_ok=True)
    raw = json.loads((cache / "extracted.json").read_text())
    sample_path = cache / "full-comparison-sample.json"
    full_samples = {r["public_number"]: r for r in json.loads(sample_path.read_text())} if sample_path.exists() else {}
    allowed = {"PB", "PW", "BR", "WR", "DT", "RE", "EV", "RO", "PC", "KM", "HA", "RU", "SZ", "AB", "AW", "AE", "PL", "TM"}
    records = []
    for item in raw:
        number = item["public_number"]
        record = {"id": f"qjql-{number:03}", "public_number": number, "book_number": None,
                  "book_membership": "unverified", "gif_sample_move_count": len(item["moves"]),
                  "gif_comparison_scope": item["extraction_scope"],
                  "gif_sha256": hashlib.sha256((cache / "gifs" / f"{number:03}.gif").read_bytes()).hexdigest(),
                  "gif_url": "https://qjql.net/newgo/dongtu/" + quote(f"名人棋谱/吴清源自战百局{number:03}.gif"),
                  "extraction_issues": item["extraction_issues"]}
        matches = item["matches"]
        if not matches or len(matches) > 1 and matches[0]["prefix"] == matches[1]["prefix"]:
            record["status"] = "unresolved"
            record["candidates"] = matches
            records.append(record)
            continue
        match = matches[0]
        path = cache / "cwi" / match["file"]
        original = path.read_bytes()
        nodes = parser.sgf_mainline(original.decode("utf-8"))
        properties = {k: v for k, v in nodes[0].items() if k in allowed}
        properties.update({"GM": ["1"], "FF": ["4"], "CA": ["UTF-8"], "SZ": ["19"]})
        moves = parser.moves_from_nodes(nodes)
        def escape(v):
            return v.replace("\\", "\\\\").replace("]", "\\]")
        sgf = "(;" + "".join(k + "".join("["+escape(v)+"]" for v in vs) for k, vs in properties.items())
        sgf += "\n" + "".join(f";{color}[{point}]" for color, point in moves) + ")\n"
        name = f"sgf/{number:03}-{path.name}"
        (destination / name).write_text(sgf)
        exact = match["prefix"] == len(item["moves"])
        record.update({"status": "identified_by_30_move_prefix" if exact else "identified_with_sample_differences",
                       "sgf_file": name, "sgf_sha256": hashlib.sha256(sgf.encode()).hexdigest(),
                       "archive_url": "https://homepages.cwi.nl/~aeb/go/games/games/Go_Seigen/"+path.name,
                       "archive_sha256": hashlib.sha256(original).hexdigest(),
                       "matching_prefix_moves": match["prefix"], "matching_symmetry": match["symmetry"],
                       "move_count": len(moves), "properties": properties,
                       "moves": [{"color": c, "point": p} for c, p in moves]})
        sample = full_samples.get(number)
        if sample and sample["matches"]:
            comparison = sample["matches"][0]
            same = comparison["prefix"] == len(sample["moves"]) == comparison["archive_move_count"]
            record["additional_full_gif_comparison"] = {
                "gif_move_count": len(sample["moves"]), "matching_prefix_moves": comparison["prefix"],
                "archive_move_count": comparison["archive_move_count"],
                "result": "identical" if same else "differences_detected",
                "extraction_issues": sample["extraction_issues"]}
        records.append(record)
    missing = sorted(set(range(1, 101)) - {r["public_number"] for r in records})
    result = {"schema_version": 1, "requested_collection": "吴清源自选百局",
              "source_collection": "吴清源自战百局（曲靖泉龙公开动图目录）",
              "status": "different_public_collection_not_requested_book", "expected_count": 100,
              "downloaded_count": len(records), "missing_public_numbers": missing,
              "generated_at": datetime.now(timezone.utc).isoformat(),
              "notes": ["公开目录编号不是已核实的书中编号。", "SGF采用已识别的CWI历史档案主线；动画差异在逐局字段中保留。", "不含书中评注或分析变化；未接入iOS界面。"],
              "games": records}
    (destination / "manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    columns = ["public_number", "book_number", "black", "white", "date", "result", "move_count", "status", "sgf_file", "archive_url", "gif_url"]
    with (destination / "games.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, columns)
        writer.writeheader()
        for r in records:
            row = {k: r.get(k, "") for k in columns}
            for field, prop in [("black", "PB"), ("white", "PW"), ("date", "DT"), ("result", "RE")]:
                row[field] = r.get("properties", {}).get(prop, [""])[0]
            writer.writerow(row)
    print(json.dumps({"downloaded": len(records), "sgf": sum("sgf_file" in r for r in records), "prefix_match": sum(r["status"] == "identified_by_30_move_prefix" for r in records), "missing": missing}))


if __name__ == "__main__":
    main()
