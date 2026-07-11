#!/usr/bin/env python3
"""Render bounded Google Sheets values as Markdown."""

import json
import sys


def cell(value):
    return str(value).replace("\n", " ").replace("|", "\\|")


def render_table(values):
    if not values:
        return "_No values returned for this range._\n"
    width = max(len(row) for row in values)
    width = max(width, 1)
    padded = [list(row) + [""] * (width - len(row)) for row in values]
    header = [cell(value) or f"Column {index + 1}" for index, value in enumerate(padded[0])]
    rows = padded[1:]
    lines = [
        "| " + " | ".join(header) + " |",
        "| " + " | ".join(["---"] * width) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(cell(value) for value in row) + " |")
    return "\n".join(lines) + "\n"


def main(argv):
    if len(argv) != 5:
        print("Usage: google-sheets-render.py ALIAS FILE_ID META_JSON VALUES_JSON", file=sys.stderr)
        return 1
    alias, file_id, meta_path, values_path = argv[1:]
    with open(meta_path, "r", encoding="utf-8") as handle:
        meta = json.load(handle)
    with open(values_path, "r", encoding="utf-8") as handle:
        values = json.load(handle)

    title = meta.get("properties", {}).get("title") or file_id
    value_range = values.get("range") or ""
    rows = values.get("values") or []
    print(f"# Google Sheet - {title}\n")
    print(f"Account alias: `{alias}`\n")
    print(f"File ID: `{file_id}`\n")
    print(f"Range: `{value_range}`\n")
    print(render_table(rows), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
