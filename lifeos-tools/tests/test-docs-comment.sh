#!/usr/bin/env bash
##- Test the Google Docs comment payload: quote must be unique, body non-empty, failures name the remedy

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "$TOOL_DIR/lib/google-docs.py" <<'EOF'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("google_docs", sys.argv[1])
docs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs)


def run(text, start=1):
    return {"textRun": {"content": text}, "startIndex": start}


document = {
    "title": "Fixture",
    "body": {"content": [
        {"paragraph": {"elements": [run("M1 (Fri Oct 3): research complete.\n", 1)]}},
        {"table": {"tableRows": [{"tableCells": [
            {"content": [{"paragraph": {"elements": [run("Sep 22 to Oct 3\n", 40)]}}]},
            {"content": [{"paragraph": {"elements": [run("Sep 22 to Oct 3\n", 60)]}}]},
        ]}]}},
    ]},
}


def expect_error(fragment, *args):
    try:
        docs.build_comment_payload(document, [], *args)
    except ValueError as exc:
        if fragment not in str(exc):
            raise SystemExit(f"error {exc!r} lacks {fragment!r}")
        return
    raise SystemExit(f"expected failure containing {fragment!r}")


payload = docs.build_comment_payload(document, [], "Fri Oct 3", "Now Fri Oct 2.")
assert payload == {"content": "Now Fri Oct 2.", "quotedFileContent": {"mimeType": "text/plain", "value": "Fri Oct 3"}}, payload

assert docs.build_comment_payload(document, [], None, "General note.") == {"content": "General note."}

expect_error("found 2", "Sep 22 to Oct 3", "Duplicate cell.")
expect_error("found 0", "Thu Oct 16", "Missing text.")
expect_error("Lengthen the quote", "Sep 22 to Oct 3", "Remedy is named.")
expect_error("must not be empty", "Fri Oct 3", "   ")
expect_error("omit --quote", "", "Empty quote.")
print("docs comment payload tests passed")
EOF
