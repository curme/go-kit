#!/usr/bin/env python3
"""Recover main-line moves from public animated records; match a SGF archive.

Usage: python scripts/extract-go-seigen.py CACHE_DIRECTORY
Requires Pillow. Inputs: gifs/NNN.gif and cwi/*.sgf. Research output only;
the public collection's numbering is NOT the printed book's numbering.
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageSequence


def sgf_mainline(text):
    # Tokenize property values atomically (including escaped brackets/semicolons).
    tokens = re.findall(r"[A-Z]+(?:\s*\[(?:\\[\s\S]|[^\\\]])*\])+|[();]", text)
    index = 0

    def tree():
        nonlocal index
        assert tokens[index] == "("
        index += 1
        nodes, first_child = [], True
        while index < len(tokens):
            token = tokens[index]
            if token == ")":
                index += 1
                return nodes
            if token == "(":
                child = tree()
                if first_child:
                    nodes.extend(child)
                    first_child = False
                continue
            index += 1
            if token == ";":
                nodes.append({})
            else:
                key = re.match(r"[A-Z]+", token)[0]
                values = re.findall(r"\[((?:\\[\s\S]|[^\\\]])*)\]", token)
                nodes[-1][key] = [re.sub(r"\\([\s\S])", r"\1", v) for v in values]
        raise ValueError("Unclosed SGF")

    return tree()


def moves_from_nodes(nodes):
    return [(color, node[color][0]) for node in nodes for color in ("B", "W") if color in node]


def board_from_frame(frame):
    if frame.size != (499, 519):
        raise ValueError(f"Unsupported GIF dimensions: {frame.size}")
    image = frame.convert("RGB")
    pixels = image.load()
    board = []
    for y in range(19):
        for x in range(19):
            # Inside the stone, outside the move-number glyph and grid lines.
            r, g, b = pixels[21 + 25*x, 43 + 25*y]
            board.append("B" if r < 100 and g < 100 and b < 100 else
                         "W" if r > 220 and g > 220 and b > 220 else "")
    return board


def extract_gif(path):
    previous, initial, moves, issues = None, None, [], []
    for n, frame in enumerate(ImageSequence.Iterator(Image.open(path))):
        current = board_from_frame(frame)
        if previous is None:
            initial = current
        else:
            added = [(i, c) for i, c in enumerate(current) if c and not previous[i]]
            if len(added) == 1:
                i, color = added[0]
                moves.append((color, chr(97+i%19)+chr(97+i//19)))
                if len(moves) >= 30:
                    break
            elif current != previous:
                removed = sum(bool(a) and not b for a, b in zip(previous, current))
                if not added and removed < 50:
                    # The source animates captures in a separate frame.
                    pass
                else:
                    issues.append({"frame": n, "additions": len(added), "removed": removed})
                    break
        previous = current
    setup = {c: [chr(97+i%19)+chr(97+i//19) for i, v in enumerate(initial) if v == c] for c in ("B", "W")}
    return setup, moves, issues


def transform(point, symmetry):
    if not point or point == "tt":
        return point
    x, y = ord(point[0])-97, ord(point[1])-97
    if symmetry >= 4:
        x = 18-x
    for _ in range(symmetry % 4):
        x, y = 18-y, x
    return chr(97+x)+chr(97+y)


def main():
    cache = Path(sys.argv[1])
    archive = []
    print("Loading archive", flush=True)
    for path in sorted((cache / "cwi").glob("*.sgf")):
        nodes = sgf_mainline(path.read_text(encoding="utf-8", errors="replace"))
        archive.append((path.name, nodes, moves_from_nodes(nodes)))
    print(f"Loaded {len(archive)} records", flush=True)
    lookup = {}
    for name, nodes, other in archive:
        for symmetry in range(8):
            key = tuple((c, transform(p, symmetry)) for c, p in other[:15])
            lookup.setdefault(key, []).append((name, nodes, other, symmetry))
    output = []
    for path in sorted((cache / "gifs").glob("*.gif")):
        setup, moves, issues = extract_gif(path)
        matches = []
        for name, nodes, other, symmetry in lookup.get(tuple(moves[:15]), []):
                aligned = [(c, transform(p, symmetry)) for c, p in other]
                prefix = 0
                for a, b in zip(moves, aligned):
                    if a != b:
                        break
                    prefix += 1
                if prefix >= 15:
                    matches.append({"file": name, "symmetry": symmetry, "prefix": prefix,
                                    "archive_move_count": len(other), "metadata": nodes[0]})
        matches.sort(key=lambda m: m["prefix"], reverse=True)
        item = {"public_number": int(path.stem), "setup": setup, "moves": moves,
                "extraction_scope": "first_30_moves_for_game_identification",
                "extraction_issues": issues, "matches": matches[:3]}
        output.append(item)
        (cache / "extracted.json").write_text(json.dumps(output, ensure_ascii=False, indent=2)+"\n")
        print(path.stem, len(moves), [(m["file"], m["prefix"]) for m in matches[:2]], issues, flush=True)
    (cache / "extracted.json").write_text(json.dumps(output, ensure_ascii=False, indent=2)+"\n")


if __name__ == "__main__":
    main()
