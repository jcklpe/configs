#!/usr/bin/env python3
"""Bounded Slack client that acts as the user's own account (user OAuth token).

Reads: accounts, whoami, channels, conversations (including existing DMs), users, history, search, permalink, thread, lists schema / items / get / comments, and sync (a Markdown snapshot of configured Lists).
Writes (dry-run unless --execute): post (optionally in a thread), dm, lists create / update / comment.
Every write checks that the token belongs to the configured team and user, then reads back
what it wrote. There are no delete commands.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE = os.environ.get("LIFEOS_SLACK_API_BASE", "https://slack.com/api")

HINTS = {
    "not_authed": "no token was sent; check the alias's token_env in secrets/.env",
    "invalid_auth": "the token is invalid; reinstall the app and paste the new User OAuth Token",
    "token_revoked": "the token was revoked; reinstall the app and paste the new User OAuth Token",
    "token_expired": "the token expired; token rotation may be on for this app, turn it off or reinstall",
    "account_inactive": "the Slack account behind this token is deactivated",
    "missing_scope": "the app lacks a scope; add it under OAuth & Permissions > User Token Scopes and reinstall",
    "channel_not_found": "no such channel, or this user cannot see it",
    "not_in_channel": "this user is not a member of that channel",
    "user_not_found": "no such user in this workspace",
    "ratelimited": "Slack rate-limited the request; wait and retry",
    "list_not_found": "no such List, or this user cannot see it",
    "team_access_not_granted": "the app is not approved for this workspace; ask a workspace admin",
}


class SlackError(Exception):
    pass


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


# ---- configuration ----

def accounts_path():
    path = os.environ.get("SLACK_ACCOUNTS_PATH", "").strip()
    if path:
        return path
    return os.path.join(os.environ.get("SECRETS_DIR", "."), "slack-accounts.json")


def load_accounts():
    path = accounts_path()
    if not os.path.isfile(path):
        raise SlackError(f"Slack account config does not exist: {path}\nNEXT: cp {os.path.join(os.path.dirname(path), 'slack-accounts.example.json')} {path}")
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    accounts = data.get("accounts")
    if not isinstance(accounts, list):
        raise SlackError("Slack account config must contain an accounts array")
    return accounts


def account(alias):
    for item in load_accounts():
        if item.get("alias") == alias:
            for field in ("team_id", "user_id", "token_env"):
                if not item.get(field):
                    raise SlackError(f"Slack alias '{alias}' needs {field}")
            return item
    raise SlackError(f"Unknown Slack account alias: {alias}")


def token_for(acct):
    env = acct["token_env"]
    if not re.fullmatch(r"[A-Za-z0-9_]+", env):
        raise SlackError(f"Invalid token_env for alias '{acct['alias']}'")
    value = os.environ.get(env, "").strip()
    if not value:
        raise SlackError(f"{env} is not set (expected in secrets/.env)")
    return value


# ---- transport ----

def call(acct, method, params=None, json_body=False):
    """One Web API call. Reads are form-encoded; writes with structured arguments send JSON."""
    token = token_for(acct)
    url = f"{API_BASE}/{method}"
    headers = {"Authorization": f"Bearer {token}"}
    params = {k: v for k, v in (params or {}).items() if v is not None}
    if json_body:
        data = json.dumps(params).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    else:
        data = urllib.parse.urlencode({k: (json.dumps(v) if isinstance(v, (list, dict)) else v) for k, v in params.items()}).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise SlackError(f"{method}: rate limited (retry after {exc.headers.get('Retry-After', '?')}s)")
        raise SlackError(f"{method}: HTTP {exc.code}")
    except (urllib.error.URLError, TimeoutError):
        raise SlackError(f"{method}: network request failed; for writes, check the destination before retrying")
    if not body.get("ok"):
        error = body.get("error", "unknown_error")
        detail = f" (needed: {body['needed']})" if body.get("needed") else ""
        hint = HINTS.get(error)
        raise SlackError(f"{method}: {error}{detail}" + (f"\nHINT: {hint}" if hint else ""))
    return body


def paged(acct, method, params, key, limit=None, max_pages=20):
    """Follow response_metadata.next_cursor. Fails loudly rather than returning a silently truncated result."""
    results = []
    cursor = None
    for _ in range(max_pages):
        page = call(acct, method, dict(params, cursor=cursor))
        results.extend(page.get(key) or [])
        if limit and len(results) >= limit:
            return results[:limit]
        cursor = ((page.get("response_metadata") or {}).get("next_cursor") or "").strip()
        if not cursor:
            if page.get("has_more"):
                raise SlackError(f"{method}: more results reported without a cursor; refusing a partial result")
            return results
    raise SlackError(f"{method}: more than {max_pages} pages; narrow the request")


# ---- identity ----

def verify_identity(acct):
    who = call(acct, "auth.test")
    if who.get("team_id") != acct["team_id"] or who.get("user_id") != acct["user_id"]:
        raise SlackError(
            f"Token identity mismatch for alias '{acct['alias']}': token is team {who.get('team_id')} user {who.get('user_id')}, "
            f"config expects team {acct['team_id']} user {acct['user_id']}. Refusing to act."
        )
    if who.get("bot_id"):
        raise SlackError(f"Alias '{acct['alias']}' holds a bot token; a User OAuth Token (xoxp-) is required so actions appear as the user")
    return who


# ---- helpers ----

def read_text(args):
    if getattr(args, "text", None) is not None and getattr(args, "text_file", None):
        raise SlackError("Use only one of --text or --text-file")
    if getattr(args, "text_file", None):
        with open(args.text_file, "r", encoding="utf-8") as handle:
            text = handle.read()
    else:
        text = args.text or ""
    if not text.strip():
        raise SlackError("Message text must not be empty")
    return text.rstrip("\n")


def parse_message_url(value):
    """https://x.slack.com/archives/C123/p1726700000000100?thread_ts=... -> (channel, thread ts)."""
    parsed = urllib.parse.urlparse(value)
    match = re.search(r"/archives/([A-Z0-9]+)/p(\d{16})", parsed.path)
    if not match:
        raise SlackError(f"Not a Slack message URL: {value}")
    channel, digits = match.groups()
    query = urllib.parse.parse_qs(parsed.query)
    thread_ts = (query.get("thread_ts") or [None])[0]
    return channel, thread_ts or f"{digits[:10]}.{digits[10:]}"


def channel_label(acct, channel_id):
    try:
        info = call(acct, "conversations.info", {"channel": channel_id}).get("channel") or {}
    except SlackError:
        return channel_id
    if info.get("is_im"):
        return f"DM ({channel_id})"
    return f"#{info.get('name', '?')} ({channel_id})"


def user_label(acct, user_id):
    try:
        user = call(acct, "users.info", {"user": user_id}).get("user") or {}
    except SlackError:
        return user_id
    profile = user.get("profile") or {}
    name = profile.get("real_name") or profile.get("display_name") or user.get("name") or "?"
    return f"{name} ({user_id})"


def print_message_plan(action, acct, target, thread_ts, text):
    print(f"Slack {action} plan:")
    print(f"Account: {acct['alias']} (team {acct['team_id']}, acting as user {acct['user_id']})")
    print(f"Target: {target}" + (f", in thread {thread_ts}" if thread_ts else ""))
    print("--- message ---")
    print(text)
    print("--- end ---")


def send(acct, channel, text, thread_ts):
    verify_identity(acct)
    sent = call(acct, "chat.postMessage", {"channel": channel, "text": text, "thread_ts": thread_ts}, json_body=True)
    ts = sent.get("ts")
    channel = sent.get("channel") or channel
    posted = ((sent.get("message") or {}).get("user"))
    if posted and posted != acct["user_id"]:
        raise SlackError(f"Posted message is attributed to {posted}, not {acct['user_id']}; check the token type")
    link = call(acct, "chat.getPermalink", {"channel": channel, "message_ts": ts}).get("permalink", "")
    print(f"Sent as {acct['user_id']} to {channel} at ts {ts}")
    if link:
        print(f"Permalink: {link}")


# ---- Lists field encoding ----

def list_schema(acct, list_id):
    body = call(acct, "slackLists.items.list", {"list_id": list_id, "limit": 1, "include_list": "true"})
    schema = (((body.get("list") or {}).get("list_metadata") or {}).get("schema")) or []
    if not schema:
        raise SlackError(f"List {list_id} returned no column schema")
    return schema


def find_column(schema, name):
    lowered = name.strip().lower()
    for column in schema:
        if lowered in {str(column.get("id", "")).lower(), str(column.get("key", "")).lower(), str(column.get("name", "")).lower()}:
            return column
    names = ", ".join(str(c.get("name")) for c in schema)
    raise SlackError(f"No column named '{name}'. Columns: {names}")


INLINE = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)|\*\*(.+?)\*\*|`([^`]+)`")
LIST_ITEM = re.compile(r"^(\s*)(?:[-*]|(\d+)\.)\s+(.*)$")


def inline_elements(text):
    """Markdown inline -> rich_text elements: [label](url), **bold**, `code`; everything else is plain text."""
    elements, pos = [], 0
    for match in INLINE.finditer(text):
        if match.start() > pos:
            elements.append({"type": "text", "text": text[pos:match.start()]})
        if match.group(1):
            elements.append({"type": "link", "text": match.group(1), "url": match.group(2)})
        elif match.group(3):
            elements.append({"type": "text", "text": match.group(3), "style": {"bold": True}})
        else:
            elements.append({"type": "text", "text": match.group(4), "style": {"code": True}})
        pos = match.end()
    if pos < len(text):
        elements.append({"type": "text", "text": text[pos:]})
    return elements


def rich_text(value):
    """Markdown -> Slack rich_text: paragraphs (blank-line separated), bullet and numbered lists, and inline links, bold, and code. Plain text passes through as one section."""
    parts = []  # ("para", text) or ("list", style, indent, [items])
    for line in value.strip("\n").split("\n"):
        item = LIST_ITEM.match(line)
        if item:
            style = "ordered" if item.group(2) else "bullet"
            indent = len(item.group(1).replace("\t", "  ")) // 2
            if parts and parts[-1][0] == "list" and parts[-1][1] == style and parts[-1][2] == indent:
                parts[-1][3].append(item.group(3))
            else:
                parts.append(("list", style, indent, [item.group(3)]))
        elif parts and parts[-1][0] == "para":
            parts[-1] = ("para", parts[-1][1] + "\n" + line)
        else:
            parts.append(("para", line))
    elements = []
    for index, part in enumerate(parts):
        if part[0] == "list":
            elements.append({"type": "rich_text_list", "style": part[1], "indent": part[2],
                             "elements": [{"type": "rich_text_section", "elements": inline_elements(t)} for t in part[3]]})
            continue
        text = re.sub(r"\n{3,}", "\n\n", part[1]).strip("\n")
        if not text:
            continue
        # Slack separates a paragraph that follows a list with a leading newline.
        if index and parts[index - 1][0] == "list":
            text = "\n" + text
        elements.append({"type": "rich_text_section", "elements": inline_elements(text)})
    if not elements:
        elements = [{"type": "rich_text_section", "elements": [{"type": "text", "text": value}]}]
    return [{"type": "rich_text", "elements": elements}]


def encode_field(column, raw):
    """Turn NAME=VALUE into a typed cell. Unknown or untested types fail rather than guessing."""
    ctype = column.get("type")
    cell = {"column_id": column["id"]}
    if ctype in ("text", "rich_text"):
        cell["rich_text"] = rich_text(raw)
    elif ctype in ("select", "multi_select"):
        choices = ((column.get("options") or {}).get("choices")) or []
        # Slack marks a multi-select as type "select" with options.format "multi_select".
        multi = ctype == "multi_select" or (column.get("options") or {}).get("format") == "multi_select"
        wanted = [part.strip() for part in raw.split(",")] if multi else [raw.strip()]
        values = []
        for label in wanted:
            match = next((c for c in choices if label.lower() in (str(c.get("label", "")).lower(), str(c.get("value", "")).lower())), None)
            if not match:
                raise SlackError(f"'{label}' is not a choice for column '{column.get('name')}'. Choices: " + ", ".join(str(c.get("label")) for c in choices))
            values.append(match["value"])
        cell["select"] = values
    elif ctype in ("user", "assignee", "todo_assignee"):
        ids = [part.strip() for part in raw.split(",") if part.strip()]
        if not all(re.fullmatch(r"[UW][A-Z0-9]+", i) for i in ids):
            raise SlackError(f"Column '{column.get('name')}' needs Slack user IDs (U...); resolve names with `lifeos slack users`")
        cell["user"] = ids
    elif ctype in ("date", "due_date", "todo_due_date"):
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", raw.strip()):
            raise SlackError(f"Column '{column.get('name')}' needs a YYYY-MM-DD date")
        cell["date"] = [raw.strip()]
    elif ctype == "link":
        url, _, label = raw.partition("|")
        if not url.startswith(("http://", "https://")):
            raise SlackError(f"Column '{column.get('name')}' needs an http(s) URL, optionally URL|label")
        link = {"original_url": url.strip()}
        if label.strip():
            link["display_name"] = label.strip()
        cell["link"] = [link]
    elif ctype in ("checkbox", "completed", "todo_completed"):
        if raw.strip().lower() not in ("true", "false"):
            raise SlackError(f"Column '{column.get('name')}' needs true or false")
        cell["checkbox"] = raw.strip().lower() == "true"
    else:
        raise SlackError(f"Column '{column.get('name')}' has type '{ctype}', which this tool does not write yet")
    return cell


def parse_fields(schema, specs, file_specs=None):
    cells = []
    for spec in specs or []:
        name, sep, value = spec.partition("=")
        if not sep or not name.strip():
            raise SlackError(f"--field must be NAME=VALUE, got: {spec}")
        column = find_column(schema, name)
        cells.append((column, encode_field(column, value)))
    for spec in file_specs or []:
        name, sep, path = spec.partition("=")
        if not sep or not name.strip():
            raise SlackError(f"--field-file must be NAME=PATH, got: {spec}")
        column = find_column(schema, name)
        if column.get("type") not in ("text", "rich_text"):
            raise SlackError(f"--field-file only fills text columns; '{column.get('name')}' is {column.get('type')}")
        try:
            with open(path) as handle:
                content = handle.read()
        except OSError as exc:
            raise SlackError(f"cannot read {path}: {exc}")
        if path.endswith(".json"):
            # Exact rich_text blocks, for edits that must preserve an item's existing formatting.
            try:
                blocks = json.loads(content)
            except ValueError as exc:
                raise SlackError(f"{path} is not valid JSON: {exc}")
            if not isinstance(blocks, list) or not all(isinstance(b, dict) and b.get("type") == "rich_text" for b in blocks):
                raise SlackError(f"{path} must hold a JSON list of rich_text blocks")
            cells.append((column, {"column_id": column["id"], "rich_text": blocks}))
        else:
            cells.append((column, encode_field(column, content)))
    return cells


def render_link(link):
    url = link.get("original_url") or link.get("originalUrl") or ""
    name = link.get("display_name") or link.get("displayName") or ""
    return f"{name} ({url})" if name and url else url or name


def render_value(field):
    if field.get("link"):
        links = field["link"] if isinstance(field["link"], list) else [field["link"]]
        return ", ".join(render_link(l) for l in links if isinstance(l, dict))
    raw = field.get("value")
    if isinstance(raw, str) and raw.startswith("{") and "riginal" in raw:
        # Link cells can arrive as a JSON string in `value`.
        try:
            return render_link(json.loads(raw))
        except ValueError:
            pass
    for key in ("text", "value"):
        if field.get(key) not in (None, "", []):
            value = field[key]
            return ", ".join(map(str, value)) if isinstance(value, list) else str(value)
    for key in ("select", "user", "date", "checkbox"):
        if field.get(key) not in (None, []):
            value = field[key]
            return ", ".join(map(str, value)) if isinstance(value, list) else str(value)
    return ""


def record_fields(record, schema):
    """Yield (column, label, field) for each cell, with select values shown as their choice labels."""
    columns = {c.get("key"): c for c in schema}
    columns.update({c.get("id"): c for c in schema})
    for field in record.get("fields") or []:
        column = columns.get(field.get("column_id")) or columns.get(field.get("key")) or {}
        label = column.get("name") or field.get("key") or field.get("column_id")
        choices = {str(c.get("value")): c.get("label") for c in ((column.get("options") or {}).get("choices")) or []}
        if choices and field.get("select"):
            # Show choice labels, not Slack's internal option IDs.
            field = dict(field, select=[choices.get(str(v), v) for v in field["select"]], value=None, text=None)
        yield column, label, field


def print_record(record, schema):
    print(f"- item {record.get('id')}" + (" (archived)" if record.get("archived") else ""))
    for _column, label, field in record_fields(record, schema):
        value = render_value(field)
        if value:
            print(f"  {label}: {value}")


# ---- snapshot ----

def inline_markdown(element, users):
    kind = element.get("type")
    if kind == "text":
        text = element.get("text", "")
        style = element.get("style") or {}
        if text.strip() and style.get("code"):
            text = f"`{text}`"
        if text.strip() and style.get("bold"):
            text = f"**{text}**"
        if text.strip() and style.get("italic"):
            text = f"*{text}*"
        return text
    if kind == "link":
        url = element.get("url", "")
        return f"[{element.get('text') or url}]({url})"
    if kind == "user":
        return "@" + users(element.get("user_id", ""))
    if kind == "channel":
        return f"#{element.get('channel_id', '')}"
    if kind == "emoji":
        return f":{element.get('name', '')}:"
    return element.get("text", "")


def rich_text_markdown(blocks, users):
    """Render Slack rich_text blocks as Markdown, keeping links, lists, and quotes."""
    lines = []
    for block in blocks or []:
        previous = None
        for part in block.get("elements") or []:
            kind = part.get("type")
            if kind == "rich_text_list":
                # Blank lines around a list so the Markdown does not fold it into the next paragraph.
                if lines and lines[-1] and previous != "rich_text_list":
                    lines.append("")
                indent = "  " * int(part.get("indent") or 0)
                for number, item in enumerate(part.get("elements") or [], 1):
                    marker = f"{number}." if part.get("style") == "ordered" else "-"
                    lines.append(f"{indent}{marker} " + "".join(inline_markdown(e, users) for e in item.get("elements") or []).strip())
            elif kind == "rich_text_preformatted":
                lines.extend(["```", "".join(e.get("text", "") for e in part.get("elements") or []), "```"])
            else:
                text = "".join(inline_markdown(e, users) for e in part.get("elements") or [])
                prefix = "> " if kind == "rich_text_quote" else ""
                if lines and lines[-1] and previous == "rich_text_list":
                    lines.append("")
                lines.extend(prefix + line if line.strip() else "" for line in text.split("\n"))
            previous = kind
    return "\n".join(lines).strip()


def list_markdown(acct, list_id, now):
    meta = call(acct, "slackLists.items.list", {"list_id": list_id, "limit": 1, "include_list": "true"}).get("list") or {}
    schema = ((meta.get("list_metadata") or {}).get("schema")) or []
    if not schema:
        raise SlackError(f"List {list_id} returned no column schema")
    records = paged(acct, "slackLists.items.list", {"list_id": list_id, "limit": 100}, "items")
    names = {}

    def users(user_id):
        if user_id not in names:
            label = user_label(acct, user_id)
            names[user_id] = label.rsplit(" (", 1)[0] if label != user_id else user_id
        return names[user_id]

    base = meta.get("permalink") or ""
    status_col = next((c for c in schema if c.get("type") == "select" and str(c.get("name", "")).lower() == "status"), None)
    order = [c.get("label") for c in ((status_col or {}).get("options") or {}).get("choices") or []]
    groups = {}
    for record in records:
        cells = {}
        for column, label, field in record_fields(record, schema):
            cells[label] = (column, field)
        status = render_value(cells["Status"][1]) if "Status" in cells else ""
        groups.setdefault(status or "No status", []).append((record, cells))

    title = meta.get("title") or meta.get("name") or list_id
    out = [f"# Slack List — {title}", "", f"**Generated:** {now}", "", f"**Source:** {base or list_id}", "", f"**Count:** {len(records)} items", ""]
    ordered = [g for g in order if g in groups] + sorted(g for g in groups if g not in order)
    out += ["**By status:** " + " · ".join(f"{g} {len(groups[g])}" for g in ordered), "", "---", ""]
    for group in ordered:
        out += [f"## {group}", ""]
        items = sorted(groups[group], key=lambda rc: int(rc[0].get("updated_timestamp") or rc[0].get("date_created") or 0), reverse=True)
        for record, cells in items:
            name = render_value(cells["Name"][1]) if "Name" in cells else record.get("id")
            url = f"{base}?record_id={record.get('id')}" if base else record.get("id")
            out += [f"### [{name}]({url})", ""]
            meta_line = []
            description = ""
            for label, (column, field) in cells.items():
                ctype = column.get("type")
                if label in ("Name", "Status"):
                    continue
                if ctype in ("text", "rich_text"):
                    description = rich_text_markdown(field.get("rich_text"), users) or render_value(field)
                    continue
                if ctype in ("user", "assignee", "todo_assignee"):
                    value = ", ".join(users(u) for u in field.get("user") or [])
                elif ctype in ("checkbox", "completed", "todo_completed"):
                    value = "yes" if field.get("checkbox") else ""
                else:
                    value = render_value(field)
                if value:
                    meta_line.append(f"**{label}:** {value}")
            updated = record.get("updated_timestamp") or record.get("date_created")
            if updated:
                meta_line.append("**Updated:** " + time.strftime("%Y-%m-%d", time.gmtime(int(updated))))
            if record.get("parent_record_id"):
                meta_line.append(f"**Subtask of:** {record['parent_record_id']}")
            out += [" | ".join(meta_line), ""]
            if description:
                out += [description, ""]
            out += [f"`{record.get('id')}`", "", "---", ""]
    return "\n".join(out).rstrip() + "\n"


def cmd_sync(args):
    now = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    chosen = [account(args.alias)] if args.alias else load_accounts()
    written = 0
    for acct in chosen:
        lists = acct.get("lists") or []
        if args.alias and not lists:
            raise SlackError(f"Slack alias '{acct.get('alias')}' has no \"lists\" configured to sync")
        for entry in lists:
            if not re.fullmatch(r"[A-Za-z0-9_-]+", str(entry.get("name", ""))) or not entry.get("id"):
                raise SlackError(f"Slack alias '{acct.get('alias')}': each list needs an id and a simple name")
            dest = os.path.join(args.output, acct["alias"])
            os.makedirs(dest, exist_ok=True)
            path = os.path.join(dest, f"list-{entry['name']}.md")
            text = list_markdown(acct, entry["id"], now)
            with open(path + ".tmp", "w") as handle:
                handle.write(text)
            os.replace(path + ".tmp", path)
            print(f"  {acct['alias']}/list-{entry['name']}: {text.count(chr(10) + '### ')} items -> {path}")
            written += 1
    if not written:
        raise SlackError("no Slack Lists are configured to sync; add \"lists\": [{\"id\": \"F...\", \"name\": \"...\"}] to an account")
    return 0


# ---- commands ----

def cmd_accounts(args):
    for item in load_accounts():
        print(f"- {item.get('alias')} | team: {item.get('team_id')} | user: {item.get('user_id')} | token env: {item.get('token_env')}")
    return 0


def cmd_whoami(args):
    acct = account(args.alias)
    who = verify_identity(acct)
    print(f"Account: {acct['alias']}")
    print(f"Workspace: {who.get('team')} ({who.get('team_id')}) {who.get('url', '')}".rstrip())
    print(f"User: {who.get('user')} ({who.get('user_id')})")
    print("Identity matches the configured team and user; token is a user token.")
    return 0


def cmd_channels(args):
    acct = account(args.alias)
    channels = paged(acct, "conversations.list", {"types": "public_channel,private_channel", "exclude_archived": "true", "limit": 200}, "channels")
    query = (args.query or "").lower()
    for ch in sorted(channels, key=lambda c: c.get("name", "")):
        if query and query not in ch.get("name", "").lower():
            continue
        member = "member" if ch.get("is_member") else "not a member"
        print(f"- #{ch.get('name')} | id: {ch.get('id')} | {'private' if ch.get('is_private') else 'public'} | {member}")
    return 0


def positive_limit(value):
    value = int(value)
    if not 1 <= value <= 100:
        raise argparse.ArgumentTypeError("must be between 1 and 100")
    return value


def conversation_types(value):
    types = value.split(",")
    if not types or any(t not in ("public_channel", "private_channel", "im", "mpim") for t in types):
        raise argparse.ArgumentTypeError("types must be comma-separated public_channel,private_channel,im,mpim")
    return value


def cmd_conversations(args):
    acct = account(args.alias)
    verify_identity(acct)
    conversations = paged(acct, "conversations.list", {"types": args.types, "exclude_archived": "false" if args.archived else "true", "limit": 200}, "channels")
    selected = []
    for ch in conversations:
        if args.user:
            if ch.get("is_im"):
                if ch.get("user") != args.user:
                    continue
            elif ch.get("is_mpim"):
                members = paged(acct, "conversations.members", {"channel": ch["id"], "limit": 200}, "members")
                if args.user not in members:
                    continue
            else:
                continue
        if ch.get("is_im"):
            label = "DM with " + ch.get("user", "?")
        elif ch.get("is_mpim"):
            label = "group DM " + ch.get("name", "")
        else:
            label = "#" + ch.get("name", "?")
        selected.append(f"- {label} | id: {ch.get('id')} | archived: {bool(ch.get('is_archived'))}")
    print("Existing visible conversations; listing never opens or joins a conversation.")
    print("\n".join(selected) if selected else "No matching visible conversations.")
    return 0


def print_history_message(message):
    suffix = f" | thread: {message['thread_ts']}" if message.get("thread_ts") else ""
    if message.get("reply_count"):
        suffix += f" | replies: {message['reply_count']}"
    print(f"- [{message.get('ts')}] {message.get('user') or message.get('bot_id') or '?'}{suffix}: {message.get('text', '')}")


def cmd_history(args):
    acct = account(args.alias)
    verify_identity(acct)
    page = call(acct, "conversations.history", {"channel": args.channel, "limit": args.limit, "cursor": args.cursor, "oldest": args.oldest, "latest": args.latest, "inclusive": "true" if args.inclusive else "false"})
    cursor = ((page.get("response_metadata") or {}).get("next_cursor") or "").strip()
    if page.get("has_more") and not cursor:
        raise SlackError("conversations.history: more results reported without a cursor; narrow the time range")
    print(f"History in {args.channel}, newest first; one page, up to {args.limit} messages. Thread replies require `thread`.")
    for message in page.get("messages") or []:
        print_history_message(message)
    print(f"Next cursor: {cursor}" if cursor else "End of accessible history in the requested time range.")
    return 0


def cmd_search(args):
    if not args.query.strip():
        raise SlackError("search needs a nonempty query")
    acct = account(args.alias)
    verify_identity(acct)
    result = call(acct, "search.messages", {"query": args.query, "count": args.limit, "page": args.page, "sort": "timestamp", "sort_dir": "desc", "highlight": "false"}).get("messages") or {}
    paging = result.get("paging") or {}
    pagination = result.get("pagination") or {}
    total = result.get("total", paging.get("total", pagination.get("total_count", "unknown")))
    pages = paging.get("pages", pagination.get("page_count", "unknown"))
    print(f"Search results newest first: page {args.page} of {pages}; total {total}. Search visibility and Slack search filters apply.")
    for message in result.get("matches") or []:
        channel = message.get("channel") or {}
        print(f"Conversation: {channel.get('name', '?')} ({channel.get('id', '?')})")
        print_history_message(message)
        if message.get("permalink"):
            print(f"Permalink: {message['permalink']}")
    return 0


def search_page(value):
    value = int(value)
    if not 1 <= value <= 100:
        raise argparse.ArgumentTypeError("page must be between 1 and 100")
    return value


def cmd_permalink(args):
    acct = account(args.alias)
    verify_identity(acct)
    link = call(acct, "chat.getPermalink", {"channel": args.channel, "message_ts": args.ts}).get("permalink")
    if not link:
        raise SlackError("chat.getPermalink returned no permalink")
    print(link)
    return 0


def cmd_users(args):
    acct = account(args.alias)
    users = paged(acct, "users.list", {"limit": 200}, "members")
    query = (args.query or "").lower()
    for user in sorted(users, key=lambda u: (u.get("profile") or {}).get("real_name", "")):
        if user.get("deleted") or user.get("is_bot"):
            continue
        profile = user.get("profile") or {}
        names = " ".join(filter(None, [profile.get("real_name"), profile.get("display_name"), user.get("name")]))
        if query and query not in names.lower():
            continue
        print(f"- {profile.get('real_name') or user.get('name')} | display: {profile.get('display_name') or '-'} | id: {user.get('id')}")
    return 0


def cmd_thread(args):
    acct = account(args.alias)
    if args.url:
        channel, ts = parse_message_url(args.url)
    elif args.channel and args.ts:
        channel, ts = args.channel, args.ts
    else:
        raise SlackError("thread needs a message URL, or --channel ID --ts TS")
    messages = paged(acct, "conversations.replies", {"channel": channel, "ts": ts, "limit": 200}, "messages")
    print(f"Thread {ts} in {channel_label(acct, channel)}")
    for message in messages:
        print(f"- [{message.get('ts')}] {message.get('user') or message.get('bot_id') or '?'}: {message.get('text', '')}")
    return 0


def cmd_post(args):
    acct = account(args.alias)
    text = read_text(args)
    channel, thread_ts = args.channel, args.thread_ts
    if args.url:
        channel, thread_ts = parse_message_url(args.url)
    if not channel:
        raise SlackError("post needs --channel ID (or --url of a message to reply in its thread)")
    print_message_plan("reply" if thread_ts else "post", acct, channel_label(acct, channel), thread_ts, text)
    if not args.execute:
        print("DRY RUN: nothing was sent. Re-run with --execute after approval.")
        return 0
    send(acct, channel, text, thread_ts)
    return 0


def cmd_dm(args):
    acct = account(args.alias)
    text = read_text(args)
    if not re.fullmatch(r"[UW][A-Z0-9]+", args.user):
        raise SlackError("--user needs a Slack user ID (U...); resolve names with `lifeos slack users ALIAS NAME`")
    print_message_plan("direct message", acct, f"DM with {user_label(acct, args.user)}", None, text)
    if not args.execute:
        print("DRY RUN: nothing was sent. Re-run with --execute after approval.")
        return 0
    verify_identity(acct)
    channel = (call(acct, "conversations.open", {"users": args.user}).get("channel") or {}).get("id")
    if not channel:
        raise SlackError("conversations.open returned no channel")
    send(acct, channel, text, None)
    return 0


def cmd_lists_schema(args):
    acct = account(args.alias)
    for column in list_schema(acct, args.list_id):
        line = f"- {column.get('name')} | id: {column.get('id')} | key: {column.get('key')} | type: {column.get('type')}"
        choices = ((column.get("options") or {}).get("choices")) or []
        if choices:
            line += " | choices: " + ", ".join(f"{c.get('label')} ({c.get('value')})" for c in choices)
        print(line)
    return 0


def cmd_lists_items(args):
    acct = account(args.alias)
    schema = list_schema(acct, args.list_id)
    params = {"list_id": args.list_id, "limit": 100}
    if args.archived:
        params["archived"] = "true"
    for record in paged(acct, "slackLists.items.list", params, "items", limit=args.limit):
        print_record(record, schema)
    return 0


def cmd_lists_get(args):
    acct = account(args.alias)
    body = call(acct, "slackLists.items.info", {"list_id": args.list_id, "id": args.item_id})
    schema = (((body.get("list") or {}).get("list_metadata") or {}).get("schema")) or []
    print_record(body.get("record") or {}, schema)
    return 0


def is_list_comment_root(message, acct, list_id, item_id):
    link = message.get("slack_list") or {}
    ts = message.get("ts", "")
    return (isinstance(link, dict) and message.get("subtype") == "list_record_comment"
            and link.get("list_id") == list_id and link.get("list_record_id") == item_id
            and message.get("team") in (None, acct["team_id"])
            and isinstance(ts, str) and bool(re.fullmatch(r"[0-9]{10}\.[0-9]{6}", ts))
            and message.get("thread_ts", ts) == ts)


def list_comment_target(acct, args):
    """Find a verified root by real permalink or history in a known List conversation."""
    if args.url:
        parsed = urllib.parse.urlparse(args.url)
        if parsed.scheme != "https" or not (parsed.hostname or "").endswith(".slack.com") or not re.fullmatch(r"/archives/[A-Z0-9]+/p[0-9]{16}", parsed.path):
            raise SlackError("Use a copied HTTPS Slack comment permalink for --url")
        channel, ts = parse_message_url(args.url)
        if not re.fullmatch(r"[0-9]{10}\.[0-9]{6}", ts):
            raise SlackError("Invalid discussion thread timestamp in --url")
    else:
        ts = None
        channel = args.channel
        if not channel:
            configured = [entry.get("discussion_channel_id") for entry in acct.get("lists", []) if entry.get("id") == args.list_id and entry.get("discussion_channel_id")]
            if any(not isinstance(value, str) for value in configured):
                raise SlackError("Configured discussion_channel_id must be a Slack conversation ID string")
            configured = set(configured)
            if len(configured) > 1:
                raise SlackError("Conflicting discussion_channel_id values for this List in account configuration")
            channel = next(iter(configured), None)
        if not channel:
            raise SlackError("List discussion conversation is not configured. Set lists[].discussion_channel_id to its verified conversation ID, or supply --channel ID (or --url). The current scopes/API responses do not expose this List-to-conversation lookup; no ID will be guessed.")
        if not re.fullmatch(r"[CG][A-Z0-9]+", channel):
            raise SlackError("List discussion channel must be a real Slack conversation ID (C... or G...)")
    verify_identity(acct)
    if ts is None:
        # Roots exist even for observed items with no user comments. Scan the known List conversation, never guess a root timestamp.
        history = paged(acct, "conversations.history", {"channel": channel, "limit": 100}, "messages")
        matches = {message["ts"] for message in history if is_list_comment_root(message, acct, args.list_id, args.item_id)}
        if not matches:
            raise SlackError("No verified discussion root found for this List item in the supplied/configured conversation. Check the channel and item; a missing root may reflect retention or API visibility. No public root-creation route is established, so nothing will be posted.")
        if len(matches) != 1:
            raise SlackError("Multiple discussion roots identify this List item; supply --url to select the intended discussion")
        ts = matches.pop()
    page = call(acct, "conversations.replies", {"channel": channel, "ts": ts, "limit": 1})
    root = next((m for m in page.get("messages", []) if m.get("ts") == ts), {})
    if not is_list_comment_root(root, acct, args.list_id, args.item_id):
        raise SlackError("Discussion root does not identify the requested List and item; refusing to use this thread")
    return channel, ts


def cmd_lists_comments(args):
    acct = account(args.alias)
    channel, ts = list_comment_target(acct, args)
    messages = paged(acct, "conversations.replies", {"channel": channel, "ts": ts, "limit": 100}, "messages")
    print(f"List {args.list_id}, item {args.item_id}: discussion {channel} / {ts}")
    for message in messages:
        if message.get("ts") != ts:
            print(f"- [{message.get('ts')}] {message.get('user') or message.get('bot_id') or '?'}: {message.get('text', '')}")
    link = call(acct, "chat.getPermalink", {"channel": channel, "message_ts": ts}).get("permalink")
    if link:
        print(f"Discussion permalink: {link}")
    return 0


def cmd_lists_comment(args):
    acct = account(args.alias)
    text = read_text(args)
    if len(text) > 40000:
        raise SlackError("Comment exceeds Slack's 40,000 character message limit")
    channel, ts = list_comment_target(acct, args)
    print_message_plan("List item comment", acct, f"List {args.list_id}, item {args.item_id}, channel {channel}", ts, text)
    if not args.execute:
        print("DRY RUN: nothing was sent. Re-run with --execute after approval.")
        return 0
    # The target and acting identity have been checked above, including on dry runs.
    try:
        sent = call(acct, "chat.postMessage", {"channel": channel, "thread_ts": ts, "text": text, "unfurl_links": False, "unfurl_media": False}, json_body=True)
    except SlackError as exc:
        raise SlackError(f"Comment send failed or has an uncertain outcome: {exc}. Check the discussion before retrying; no automatic retry.")
    message_ts = sent.get("ts")
    print(f"Slack accepted comment: channel {channel}, ts {message_ts or '(missing)'}; verifying readback")
    try:
        if not message_ts or sent.get("channel") != channel:
            raise SlackError("Send response lacks a timestamp or reports a different channel")
        page = call(acct, "conversations.replies", {"channel": channel, "ts": ts, "oldest": message_ts, "latest": message_ts, "inclusive": "true", "limit": 100})
        message = next((m for m in page.get("messages", []) if m.get("ts") == message_ts), {})
        if message.get("user") != acct["user_id"] or message.get("thread_ts") != ts or message.get("text") != text:
            raise SlackError("Readback does not confirm the exact comment text, author, and discussion")
        link = call(acct, "chat.getPermalink", {"channel": channel, "message_ts": message_ts}).get("permalink")
        if not link:
            raise SlackError("chat.getPermalink returned no permalink")
    except SlackError as exc:
        raise SlackError(f"PARTIAL: comment accepted at {channel} / {message_ts}, but verification failed: {exc}. Do not resend; inspect this discussion first.")
    print(f"Verified comment by {message['user']}: {message['text']}")
    print(f"Permalink: {link}")
    return 0


def print_list_plan(action, acct, list_id, item_id, cells):
    print(f"Slack List {action} plan:")
    print(f"Account: {acct['alias']} (team {acct['team_id']}, acting as user {acct['user_id']})")
    print(f"List: {list_id}" + (f", item {item_id}" if item_id else ""))
    for column, cell in cells:
        if cell.get("rich_text"):
            # Show text as the Markdown it will render as, so the plan can be read and approved.
            rendered = rich_text_markdown(cell["rich_text"], lambda user_id: user_id)
            print(f"- {column.get('name')} ({column.get('type')}):")
            print("\n".join("    " + line for line in rendered.split("\n")))
            continue
        value = {k: v for k, v in cell.items() if k != "column_id"}
        print(f"- {column.get('name')} ({column.get('type')}): {json.dumps(value, ensure_ascii=False)}")


def cmd_lists_create(args):
    acct = account(args.alias)
    schema = list_schema(acct, args.list_id)
    cells = parse_fields(schema, args.field, args.field_file)
    if not cells:
        raise SlackError("lists create needs at least one --field NAME=VALUE or --field-file NAME=PATH")
    print_list_plan("create", acct, args.list_id, None, cells)
    if args.parent:
        print(f"Parent item: {args.parent}")
    if not args.execute:
        print("DRY RUN: nothing was written. Re-run with --execute after approval.")
        return 0
    verify_identity(acct)
    created = call(acct, "slackLists.items.create", {"list_id": args.list_id, "initial_fields": [cell for _, cell in cells], "parent_item_id": args.parent}, json_body=True)
    item_id = (created.get("item") or {}).get("id") or created.get("id")
    if not item_id:
        raise SlackError("slackLists.items.create returned no item id; check the List before retrying")
    readback = call(acct, "slackLists.items.info", {"list_id": args.list_id, "id": item_id})
    print(f"Created item {item_id}; read back:")
    print_record(readback.get("record") or {}, schema)
    return 0


def cmd_lists_update(args):
    acct = account(args.alias)
    schema = list_schema(acct, args.list_id)
    cells = parse_fields(schema, args.field, args.field_file)
    if not cells:
        raise SlackError("lists update needs at least one --field NAME=VALUE or --field-file NAME=PATH")
    print_list_plan("update", acct, args.list_id, args.item_id, cells)
    if not args.execute:
        print("DRY RUN: nothing was written. Re-run with --execute after approval.")
        return 0
    verify_identity(acct)
    call(acct, "slackLists.items.update", {"list_id": args.list_id, "cells": [dict(cell, row_id=args.item_id) for _, cell in cells]}, json_body=True)
    readback = call(acct, "slackLists.items.info", {"list_id": args.list_id, "id": args.item_id})
    print(f"Updated item {args.item_id}; read back:")
    print_record(readback.get("record") or {}, schema)
    return 0


def build_parser():
    parser = argparse.ArgumentParser(prog="lifeos slack", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("accounts").set_defaults(func=cmd_accounts)
    p = sub.add_parser("whoami"); p.add_argument("alias"); p.set_defaults(func=cmd_whoami)
    p = sub.add_parser("channels"); p.add_argument("alias"); p.add_argument("query", nargs="?"); p.set_defaults(func=cmd_channels)
    p = sub.add_parser("conversations", help="list existing channels, DMs and group DMs without opening or joining")
    p.add_argument("alias"); p.add_argument("--types", type=conversation_types, default="public_channel,private_channel,im,mpim"); p.add_argument("--user", help="filter existing DMs/group DMs by verified user ID"); p.add_argument("--archived", action="store_true"); p.set_defaults(func=cmd_conversations)
    p = sub.add_parser("history", help="read one page of conversation history; use thread for replies")
    p.add_argument("alias"); p.add_argument("--channel", required=True); p.add_argument("--limit", type=positive_limit, default=50); p.add_argument("--cursor"); p.add_argument("--oldest"); p.add_argument("--latest"); p.add_argument("--inclusive", action="store_true"); p.set_defaults(func=cmd_history)
    p = sub.add_parser("search", help="read one page of message search; requires existing search:read scope")
    p.add_argument("alias"); p.add_argument("query"); p.add_argument("--limit", type=positive_limit, default=50); p.add_argument("--page", type=search_page, default=1); p.set_defaults(func=cmd_search)
    p = sub.add_parser("permalink", help="get Slack's permalink for an existing message")
    p.add_argument("alias"); p.add_argument("--channel", required=True); p.add_argument("--ts", required=True); p.set_defaults(func=cmd_permalink)
    p = sub.add_parser("users"); p.add_argument("alias"); p.add_argument("query", nargs="?"); p.set_defaults(func=cmd_users)
    p = sub.add_parser("thread"); p.add_argument("alias"); p.add_argument("url", nargs="?"); p.add_argument("--channel"); p.add_argument("--ts"); p.set_defaults(func=cmd_thread)
    for name in ("post", "reply"):
        p = sub.add_parser(name); p.add_argument("alias"); p.add_argument("--channel"); p.add_argument("--thread-ts"); p.add_argument("--url", help="message URL; replies in its thread")
        p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_post)
    p = sub.add_parser("dm"); p.add_argument("alias"); p.add_argument("--user", required=True); p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_dm)
    p = sub.add_parser("sync"); p.add_argument("alias", nargs="?"); p.add_argument("--output", required=True, help="directory; writes <alias>/list-<name>.md"); p.set_defaults(func=cmd_sync)
    lists = sub.add_parser("lists").add_subparsers(dest="lists_command", required=True)
    p = lists.add_parser("schema"); p.add_argument("alias"); p.add_argument("list_id"); p.set_defaults(func=cmd_lists_schema)
    p = lists.add_parser("items"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("--limit", type=int); p.add_argument("--archived", action="store_true"); p.set_defaults(func=cmd_lists_items)
    p = lists.add_parser("get"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("item_id"); p.set_defaults(func=cmd_lists_get)
    for name, func in (("comments", cmd_lists_comments), ("comment", cmd_lists_comment)):
        p = lists.add_parser(name); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("item_id"); target = p.add_mutually_exclusive_group()
        target.add_argument("--url", help="copied comment permalink; root must match List/item")
        target.add_argument("--channel", help="known List discussion conversation; otherwise use lists[].discussion_channel_id")
        if name == "comment":
            p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--execute", action="store_true")
        p.set_defaults(func=func)
    p = lists.add_parser("create"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("--field", action="append", default=[]); p.add_argument("--field-file", action="append", default=[], help="NAME=PATH: Markdown file, or .json rich_text blocks"); p.add_argument("--parent"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_lists_create)
    p = lists.add_parser("update"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("item_id"); p.add_argument("--field", action="append", default=[]); p.add_argument("--field-file", action="append", default=[], help="NAME=PATH: Markdown file, or .json rich_text blocks"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_lists_update)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except SlackError as exc:
        return fail(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
