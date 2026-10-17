#!/usr/bin/env python3
"""Normalize Graph group posts for task comment display and duplicate checks."""
import importlib.util
import json
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("m365_render", Path(__file__).with_name("m365-render.py"))
render = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render)
posts = json.load(sys.stdin)["value"]

def body(post):
    value = post.get("body") or {}
    content = value.get("content", "")
    return render.clean_text(content, "html") if value.get("contentType", "text").lower() == "html" else content

if sys.argv[1] == "match":
    wanted = " ".join(Path(sys.argv[2]).read_text().split())
    print(json.dumps([p["id"] for p in posts if " ".join(body(p).split()) == wanted]))
elif sys.argv[1] == "render":
    for post in posts:
        print(f"- {post['id']} | {post.get('createdDateTime', '')}\n{body(post)}")
else:
    raise SystemExit("Expected match or render")
