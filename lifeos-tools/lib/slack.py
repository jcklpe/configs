#!/usr/bin/env python3
"""Bounded Slack client that acts as the user's own account (user OAuth token).

Reads: accounts, whoami, channels, users, thread, lists schema / items / get.
Writes (dry-run unless --execute): post (optionally in a thread), dm, lists create / update.
Every write checks that the token belongs to the configured team and user, then reads back
what it wrote. There are no delete commands.
"""

import argparse
import json
import os
import re
import sys
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


def rich_text(value):
    return [{"type": "rich_text", "elements": [{"type": "rich_text_section", "elements": [{"type": "text", "text": value}]}]}]


def encode_field(column, raw):
    """Turn NAME=VALUE into a typed cell. Unknown or untested types fail rather than guessing."""
    ctype = column.get("type")
    cell = {"column_id": column["id"]}
    if ctype in ("text", "rich_text"):
        cell["rich_text"] = rich_text(raw)
    elif ctype in ("select", "multi_select"):
        choices = ((column.get("options") or {}).get("choices")) or []
        wanted = [part.strip() for part in raw.split(",")] if ctype == "multi_select" else [raw.strip()]
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


def parse_fields(schema, specs):
    cells = []
    for spec in specs or []:
        name, sep, value = spec.partition("=")
        if not sep or not name.strip():
            raise SlackError(f"--field must be NAME=VALUE, got: {spec}")
        column = find_column(schema, name)
        cells.append((column, encode_field(column, value)))
    return cells


def render_value(field):
    for key in ("text", "value"):
        if field.get(key) not in (None, "", []):
            value = field[key]
            return ", ".join(map(str, value)) if isinstance(value, list) else str(value)
    for key in ("select", "user", "date", "checkbox"):
        if field.get(key) not in (None, []):
            value = field[key]
            return ", ".join(map(str, value)) if isinstance(value, list) else str(value)
    if field.get("link"):
        return ", ".join(l.get("original_url", "") for l in field["link"])
    return ""


def print_record(record, schema):
    names = {c.get("key"): c.get("name") for c in schema}
    names.update({c.get("id"): c.get("name") for c in schema})
    print(f"- item {record.get('id')}" + (" (archived)" if record.get("archived") else ""))
    for field in record.get("fields") or []:
        label = names.get(field.get("column_id")) or names.get(field.get("key")) or field.get("key") or field.get("column_id")
        value = render_value(field)
        if value:
            print(f"  {label}: {value}")


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


def print_list_plan(action, acct, list_id, item_id, cells):
    print(f"Slack List {action} plan:")
    print(f"Account: {acct['alias']} (team {acct['team_id']}, acting as user {acct['user_id']})")
    print(f"List: {list_id}" + (f", item {item_id}" if item_id else ""))
    for column, cell in cells:
        value = {k: v for k, v in cell.items() if k != "column_id"}
        print(f"- {column.get('name')} ({column.get('type')}): {json.dumps(value, ensure_ascii=False)}")


def cmd_lists_create(args):
    acct = account(args.alias)
    schema = list_schema(acct, args.list_id)
    cells = parse_fields(schema, args.field)
    if not cells:
        raise SlackError("lists create needs at least one --field NAME=VALUE")
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
    cells = parse_fields(schema, args.field)
    if not cells:
        raise SlackError("lists update needs at least one --field NAME=VALUE")
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
    p = sub.add_parser("users"); p.add_argument("alias"); p.add_argument("query", nargs="?"); p.set_defaults(func=cmd_users)
    p = sub.add_parser("thread"); p.add_argument("alias"); p.add_argument("url", nargs="?"); p.add_argument("--channel"); p.add_argument("--ts"); p.set_defaults(func=cmd_thread)
    for name in ("post", "reply"):
        p = sub.add_parser(name); p.add_argument("alias"); p.add_argument("--channel"); p.add_argument("--thread-ts"); p.add_argument("--url", help="message URL; replies in its thread")
        p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_post)
    p = sub.add_parser("dm"); p.add_argument("alias"); p.add_argument("--user", required=True); p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_dm)
    lists = sub.add_parser("lists").add_subparsers(dest="lists_command", required=True)
    p = lists.add_parser("schema"); p.add_argument("alias"); p.add_argument("list_id"); p.set_defaults(func=cmd_lists_schema)
    p = lists.add_parser("items"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("--limit", type=int); p.add_argument("--archived", action="store_true"); p.set_defaults(func=cmd_lists_items)
    p = lists.add_parser("get"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("item_id"); p.set_defaults(func=cmd_lists_get)
    p = lists.add_parser("create"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("--field", action="append", default=[]); p.add_argument("--parent"); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_lists_create)
    p = lists.add_parser("update"); p.add_argument("alias"); p.add_argument("list_id"); p.add_argument("item_id"); p.add_argument("--field", action="append", default=[]); p.add_argument("--execute", action="store_true"); p.set_defaults(func=cmd_lists_update)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except SlackError as exc:
        return fail(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
