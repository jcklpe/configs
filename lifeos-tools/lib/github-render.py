#!/usr/bin/env python3
"""Render GitHub JSON (from `gh`) into LifeOS source snapshots.

Reads a JSON payload on stdin and writes markdown to stdout. One subcommand per
artifact kind so the shell layer stays a thin orchestrator, matching how
google-*.py helpers are used elsewhere in lib/.

Snapshots are orientation layers, not mirrors (LifeOS decision 0002): the index
files stay scannable and the full text lives in per-item detail files.
"""

import argparse
import json
import sys
from datetime import datetime, timezone

PREVIEW_CHARS = 160


def days_since(stamp):
    if not stamp:
        return None
    try:
        then = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except ValueError:
        return None
    return (datetime.now(timezone.utc) - then).days


def preview(body):
    text = (body or "").replace("\r", " ").replace("\n", " ").strip()
    if len(text) > PREVIEW_CHARS:
        text = text[:PREVIEW_CHARS].rstrip() + "..."
    return text


def header(title, owner, repo, count, noun):
    return [
        "# %s — %s/%s" % (title, owner, repo),
        "",
        "**Generated:** %s" % datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "",
        "**Count:** %d %s" % (count, noun),
        "",
        "---",
        "",
    ]


def names(items, key="login"):
    return ", ".join(i.get(key, "?") for i in items or [])


def label_names(labels):
    return ", ".join("`%s`" % l.get("name", "?") for l in labels or [])


def render_issue_index(data, args):
    items = data.get("items", [])
    noun = "open pull requests" if args.kind == "pr" else "open issues"
    title = "Open Pull Requests" if args.kind == "pr" else "Open Issues"
    out = header(title, args.owner, args.repo, len(items), noun)

    # Group by first label so the index mirrors how work is actually organized.
    grouped, ungrouped = {}, []
    for it in items:
        labels = [l.get("name") for l in it.get("labels") or []]
        (grouped.setdefault(labels[0], []).append(it) if labels else ungrouped.append(it))

    def block(it):
        d = days_since(it.get("updatedAt"))
        line = "### [#%d %s](%s/%d.md)" % (it["number"], it["title"], args.detail_dir, it["number"])
        meta = ["**Updated:** %sd ago" % d if d is not None else "**Updated:** unknown"]
        if it.get("assignees"):
            meta.append("**Assigned:** %s" % names(it["assignees"]))
        if it.get("labels"):
            meta.append("**Labels:** %s" % label_names(it["labels"]))
        chunk = [line, "", " | ".join(meta), ""]
        p = preview(it.get("body"))
        if p:
            chunk += [p, ""]
        chunk += ["---", ""]
        return chunk

    for label in sorted(grouped):
        out += ["## %s" % label.upper(), ""]
        for it in sorted(grouped[label], key=lambda x: -(days_since(x.get("updatedAt")) or 0)):
            out += block(it)
    if ungrouped:
        out += ["## UNLABELED", ""]
        for it in ungrouped:
            out += block(it)
    return "\n".join(out)


def render_item_detail(data, args):
    it = data
    kind = "Pull Request" if args.kind == "pr" else "Issue"
    created, updated = days_since(it.get("createdAt")), days_since(it.get("updatedAt"))
    author = (it.get("author") or {}).get("login", "unknown")
    out = [
        "# #%d — %s" % (it["number"], it["title"]),
        "",
        "**Type:** %s" % kind,
        "",
        "**State:** %s" % it.get("state", "?"),
        "",
        "**Created:** %sd ago by @%s" % (created if created is not None else "?", author),
        "",
        "**Updated:** %sd ago" % (updated if updated is not None else "?"),
        "",
    ]
    if it.get("assignees"):
        out += ["**Assigned:** %s" % names(it["assignees"]), ""]
    if it.get("labels"):
        out += ["**Labels:** %s" % label_names(it["labels"]), ""]
    if it.get("url"):
        out += ["**URL:** %s" % it["url"], ""]
    out += ["---", "", "## Description", "", it.get("body") or "(No description provided)", ""]

    comments = it.get("comments") or []
    if comments:
        out += ["---", "", "## Comments (%d)" % len(comments), ""]
        for c in comments:
            who = (c.get("author") or {}).get("login") or (c.get("user") or {}).get("login", "unknown")
            when = c.get("createdAt") or c.get("created_at") or ""
            try:
                when = datetime.fromisoformat(when.replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M UTC")
            except ValueError:
                pass
            out += ["### @%s — %s" % (who, when), "", c.get("body") or "", "", "---", ""]
    return "\n".join(out)


def render_discussions(data, args):
    items = data.get("items", [])
    out = header("Discussions", args.owner, args.repo, len(items), "discussions")
    by_cat = {}
    for d in items:
        by_cat.setdefault((d.get("category") or {}).get("name", "Uncategorized"), []).append(d)
    for cat in sorted(by_cat):
        out += ["## %s" % cat.upper(), ""]
        for d in by_cat[cat]:
            age = days_since(d.get("updatedAt"))
            out += [
                "### [#%d %s](%s)" % (d["number"], d["title"], d.get("url", "")),
                "",
                "**Updated:** %sd ago | **Author:** @%s | **Comments:** %d%s"
                % (
                    age if age is not None else "?",
                    (d.get("author") or {}).get("login", "unknown"),
                    d.get("commentCount", 0),
                    " | **Answered**" if d.get("isAnswered") else "",
                ),
                "",
            ]
            p = preview(d.get("body"))
            if p:
                out += [p, ""]
            out += ["---", ""]
    return "\n".join(out)


def render_board(data, args):
    items = data.get("items", [])
    out = [
        "# Project #%s — %s" % (args.project_number, args.project_name),
        "",
        "**Generated:** %s" % datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "",
        "**Total items:** %d" % len(items),
        "",
        "---",
        "",
    ]
    by_status = {}
    for it in items:
        by_status.setdefault(it.get("status") or "No Status", []).append(it)
    for status in sorted(by_status):
        rows = by_status[status]
        out += ["## %s" % status, "", "**Count:** %d" % len(rows), ""]
        for it in rows:
            content = it.get("content") or {}
            title = it.get("title") or content.get("title") or "(untitled)"
            out += ["### %s" % title, ""]
            meta = []
            if content.get("number"):
                meta.append("**#%s**" % content["number"])
            if it.get("assignees"):
                a = it["assignees"]
                meta.append("**Assigned:** %s" % (", ".join(a) if isinstance(a, list) else a))
            if it.get("labels"):
                l = it["labels"]
                meta.append("**Labels:** %s" % (", ".join(l) if isinstance(l, list) else l))
            if meta:
                out += [" | ".join(meta), ""]
            out += ["---", ""]
    return "\n".join(out)


RENDERERS = {
    "issue-index": render_issue_index,
    "item-detail": render_item_detail,
    "discussions": render_discussions,
    "board": render_board,
}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("renderer", choices=sorted(RENDERERS))
    p.add_argument("--owner", default="")
    p.add_argument("--repo", default="")
    p.add_argument("--kind", default="issue", choices=["issue", "pr"])
    p.add_argument("--detail-dir", default="issues")
    p.add_argument("--project-number", default="")
    p.add_argument("--project-name", default="")
    args = p.parse_args()
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print("ERROR: could not parse JSON on stdin: %s" % exc, file=sys.stderr)
        return 1
    print(RENDERERS[args.renderer](data, args))
    return 0


if __name__ == "__main__":
    sys.exit(main())
