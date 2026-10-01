#!/usr/bin/env bash
##- Offline tests for `docs replace-once --markdown` request building in lib/google-docs.py.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "${TOOL_DIR}/lib/google-docs.py" <<'PYEND'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("gdocs", sys.argv[1])
gdocs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gdocs)

md = "- Anchor line\n### Beat-by-beat\n- **00:17** · Arrival\n  - Fixed audio é\n- [link](https://example.com)"
blocks = gdocs.parse_markdown_blocks(md)
old_range = {"tab_id": "t.0", "start_index": 100, "end_index": 112}
requests, final = gdocs.build_markdown_replace_requests("t.0", old_range, blocks)
assert final == "Anchor line\nBeat-by-beat\n00:17 · Arrival\n\tFixed audio é\nlink", final
end = 100 + gdocs.utf16_length(final)

# Order: delete the match, insert at its start, reset inherited style, then apply Markdown styles.
assert requests[0] == {"deleteContentRange": {"range": {"startIndex": 100, "endIndex": 112, "tabId": "t.0"}}}, requests[0]
assert requests[1]["insertText"]["location"] == {"index": 100, "tabId": "t.0"}, requests[1]
assert requests[1]["insertText"]["text"] == final
assert requests[2] == {"deleteParagraphBullets": {"range": {"startIndex": 100, "endIndex": end, "tabId": "t.0"}}}, requests[2]
assert requests[3]["updateParagraphStyle"]["paragraphStyle"]["namedStyleType"] == "NORMAL_TEXT"
assert requests[4]["updateTextStyle"]["fields"] == "bold,italic,link"

rest = requests[5:]
headings = [r for r in rest if r.get("updateParagraphStyle", {}).get("paragraphStyle", {}).get("namedStyleType") == "HEADING_3"]
assert len(headings) == 1 and headings[0]["updateParagraphStyle"]["range"]["startIndex"] == 112, headings
bullets = [r["createParagraphBullets"]["range"] for r in rest if "createParagraphBullets" in r]
# Two runs (the anchor bullet, then the three bullets after the heading), created last and in reverse order so tab removal never shifts a pending index.
assert [(b["startIndex"], b["endIndex"]) for b in bullets] == [(125, end), (100, 111)], bullets
assert all("createParagraphBullets" in r for r in rest[-2:]), rest[-2:]
assert not any("indentStart" in r.get("updateParagraphStyle", {}).get("paragraphStyle", {}) for r in rest)
assert any(r.get("updateTextStyle", {}).get("textStyle", {}).get("bold") for r in rest)
links = [r for r in rest if r.get("updateTextStyle", {}).get("fields") == "link"]
assert links and links[0]["updateTextStyle"]["textStyle"]["link"]["url"] == "https://example.com", links

# Every index stays inside the inserted span.
for r in rest:
    rng = next(iter(r.values()))["range"]
    assert 100 <= rng["startIndex"] and rng["endIndex"] <= end + 1, r
print("docs markdown replace tests passed")
PYEND
