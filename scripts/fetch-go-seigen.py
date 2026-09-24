#!/usr/bin/env python3
"""Fetch public source records, without guessing missing collection entries.

Run from the project root. Downloads stay in the ignored research cache.
The CWI archive is used only to identify the publicly listed game records.
"""
import argparse
import html
import re
import tarfile
import time
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen


def fetch(url, path):
    if path.exists() and path.stat().st_size:
        return path.read_bytes()
    request = Request(url, headers={"User-Agent": "GoKit historical game research/1.0"})
    with urlopen(request, timeout=30) as response:
        data = response.read(20_000_001)
    if len(data) > 20_000_000:
        raise ValueError("Unexpected response size")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_bytes(data)
    temporary.replace(path)
    time.sleep(0.25)
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path(".build/research"))
    args = parser.parse_args()
    cache = args.cache
    fetch("https://detail.youzan.com/show/goods?alias=3f1n4cv8qnk3m&from_source=gbox_seo", cache / "publisher.html")
    links = {}
    for offset in (0, 30, 60, 90):
        page = fetch(f"https://qjql.net/newgo/sgf_dong.asp?offset={offset}", cache / f"gif-index{offset}.html")
        for value in re.findall(r'gifname=([^"<>]+)', page.decode("utf-8", errors="replace")):
            value = html.unescape(value)
            match = re.fullmatch(r"名人棋谱/吴清源自战百局(\d{3})\.gif", value)
            if match:
                links[int(match[1])] = "https://qjql.net/newgo/dongtu/" + quote(value)
    for number, url in sorted(links.items()):
        data = fetch(url, cache / "gifs" / f"{number:03}.gif")
        if not data.startswith((b"GIF87a", b"GIF89a")):
            raise ValueError(f"Not GIF: {url}")
    fetch("https://homepages.cwi.nl/~aeb/go/games/go_seigen.tgz", cache / "go-seigen.tgz")
    (cache / "cwi").mkdir(exist_ok=True)
    with tarfile.open(cache / "go-seigen.tgz") as archive:
        for member in archive.getmembers():
            path = Path(member.name)
            if member.isfile() and len(path.parts) == 2 and path.parts[0] == "Go_Seigen" and path.suffix == ".sgf":
                (cache / "cwi" / path.name).write_bytes(archive.extractfile(member).read())
    print(f"Downloaded {len(links)} listed records; missing: {sorted(set(range(1,101))-set(links))}")


if __name__ == "__main__":
    main()
