#!/usr/bin/env bash
##- Offline tests for set-body inline Markdown parsing in lib/google-docs.py.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "${TOOL_DIR}/lib/google-docs.py" <<'PYEND'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("gdocs", sys.argv[1])
gdocs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gdocs)

plain, spans = gdocs.parse_inline("**[Go](https://example.com/a)** now, **bold**, *it*, [l](https://example.com/b)")
assert plain == "Go now, bold, it, l", plain
assert {"start": 0, "end": 2, "link": "https://example.com/a"} in spans, spans
assert {"start": 0, "end": 2, "bold": True} in spans, spans
assert {"start": 8, "end": 12, "bold": True} in spans, spans
assert {"start": 14, "end": 16, "italic": True} in spans, spans
assert {"start": 18, "end": 19, "link": "https://example.com/b"} in spans, spans
print("docs inline tests passed")
PYEND
