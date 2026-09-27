#!/usr/bin/env bash
##- Offline tests for lib/slack.py against a fake Slack Web API. All IDs and text are invented.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "${TOOL_DIR}/lib/slack.py" <<'PYEND'
import importlib.util, io, json, os, sys, tempfile
from contextlib import redirect_stdout

spec = importlib.util.spec_from_file_location("slack", sys.argv[1])
slack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slack)

work = tempfile.mkdtemp()
config = os.path.join(work, "slack-accounts.json")
with open(config, "w") as handle:
    json.dump({"accounts": [{"alias": "work", "team_id": "T1", "user_id": "U1", "token_env": "SLACK_TOKEN_TEST"}]}, handle)
os.environ["SLACK_ACCOUNTS_PATH"] = config
os.environ["SLACK_TOKEN_TEST"] = "xoxp-test"

SCHEMA = [
    {"id": "Col1", "key": "name", "name": "Name", "type": "text", "is_primary_column": True},
    {"id": "Col2", "key": "status", "name": "Status", "type": "select",
     "options": {"choices": [{"value": "not_started", "label": "Not Started"}, {"value": "done", "label": "Done"}]}},
    {"id": "Col3", "key": "owner", "name": "Owner", "type": "user"},
    {"id": "Col4", "key": "due", "name": "Due", "type": "date"},
    {"id": "Col5", "key": "ref", "name": "Source", "type": "link"},
    {"id": "Col6", "key": "votes", "name": "Votes", "type": "vote"},
]

calls = []
state = {"auth": {"ok": True, "team_id": "T1", "user_id": "U1", "team": "Test", "user": "tester"}, "posted_user": "U1"}

def fake_call(acct, method, params=None, json_body=False):
    calls.append((method, params or {}))
    if method == "auth.test":
        return state["auth"]
    if method == "conversations.info":
        return {"ok": True, "channel": {"id": params["channel"], "name": "general"}}
    if method == "users.info":
        return {"ok": True, "user": {"id": params["user"], "profile": {"real_name": "Pat Example"}}}
    if method == "chat.postMessage":
        return {"ok": True, "channel": params["channel"], "ts": "1700000000.000100", "message": {"user": state["posted_user"]}}
    if method == "chat.getPermalink":
        return {"ok": True, "permalink": "https://example.slack.com/archives/C1/p1700000000000100"}
    if method == "conversations.open":
        return {"ok": True, "channel": {"id": "D1"}}
    if method == "slackLists.items.list":
        return {"ok": True, "items": [], "list": {"list_metadata": {"schema": SCHEMA}}}
    if method == "slackLists.items.create":
        return {"ok": True, "item": {"id": "Rec1"}}
    if method == "slackLists.items.update":
        return {"ok": True}
    if method == "slackLists.items.info":
        return {"ok": True, "record": {"id": params["id"], "fields": [{"column_id": "Col1", "text": "Test task"}]}, "list": {"list_metadata": {"schema": SCHEMA}}}
    raise AssertionError(f"unexpected method {method}")

slack.call = fake_call

def run(argv):
    out = io.StringIO()
    with redirect_stdout(out):
        code = slack.main(argv)
    return code, out.getvalue()

def methods():
    return [m for m, _ in calls]

def check(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)

# Dry run shows the plan and sends nothing.
calls.clear()
code, out = run(["post", "work", "--channel", "C1", "--text", "hello there"])
check(code == 0 and "DRY RUN" in out and "hello there" in out and "#general (C1)" in out, "post dry run should print the plan")
check("chat.postMessage" not in methods() and "auth.test" not in methods(), "dry run must not call the API to send")

# Execute checks identity first, posts, and reports the permalink.
calls.clear()
code, out = run(["post", "work", "--channel", "C1", "--text", "hello there", "--execute"])
check(code == 0 and "Permalink:" in out, "post --execute should report the permalink")
check(methods().index("auth.test") < methods().index("chat.postMessage"), "identity check must precede the send")

# Replying via a message URL targets that thread.
calls.clear()
code, out = run(["post", "work", "--url", "https://example.slack.com/archives/C9/p1700000000000100", "--text", "reply", "--execute"])
sent = [p for m, p in calls if m == "chat.postMessage"][0]
check(sent["channel"] == "C9" and sent["thread_ts"] == "1700000000.000100", "URL reply should post into that thread")

# Identity mismatch and bot tokens are refused before sending.
state["auth"] = {"ok": True, "team_id": "T1", "user_id": "U2"}
calls.clear()
code, _ = run(["post", "work", "--channel", "C1", "--text", "x", "--execute"])
check(code == 1 and "chat.postMessage" not in methods(), "identity mismatch must refuse to send")
state["auth"] = {"ok": True, "team_id": "T1", "user_id": "U1", "bot_id": "B1"}
calls.clear()
code, _ = run(["post", "work", "--channel", "C1", "--text", "x", "--execute"])
check(code == 1 and "chat.postMessage" not in methods(), "a bot token must be refused")
state["auth"] = {"ok": True, "team_id": "T1", "user_id": "U1", "team": "Test", "user": "tester"}

# A message attributed to someone else is reported as an error.
state["posted_user"] = "U9"
code, _ = run(["post", "work", "--channel", "C1", "--text", "x", "--execute"])
check(code == 1, "posted-as-another-user must fail")
state["posted_user"] = "U1"

# DM needs a user ID and opens a conversation on execute.
code, _ = run(["dm", "work", "--user", "Pat", "--text", "hi"])
check(code == 1, "dm with a name instead of an ID should fail")
calls.clear()
code, out = run(["dm", "work", "--user", "U5", "--text", "hi", "--execute"])
check(code == 0 and "conversations.open" in methods() and "Pat Example (U5)" in out, "dm should open a conversation and label the recipient")

# Empty text is refused.
code, _ = run(["post", "work", "--channel", "C1", "--text", "   "])
check(code == 1, "empty text should fail")

# Lists: typed fields by column name, choice labels, readback.
calls.clear()
code, out = run(["lists", "create", "work", "F1", "--field", "Name=Test task", "--field", "Status=Done", "--field", "Owner=U3",
                 "--field", "Due=2026-11-02", "--field", "Source=https://example.com/1|Issue 1", "--execute"])
check(code == 0 and "Created item Rec1" in out and "Test task" in out, "lists create should write and read back")
fields = [p for m, p in calls if m == "slackLists.items.create"][0]["initial_fields"]
by_id = {f["column_id"]: f for f in fields}
check(by_id["Col2"]["select"] == ["done"], "select should map a label to its choice value")
check(by_id["Col3"]["user"] == ["U3"] and by_id["Col4"]["date"] == ["2026-11-02"], "user and date fields")
check(by_id["Col5"]["link"] == [{"original_url": "https://example.com/1", "display_name": "Issue 1"}], "link field with label")
check(by_id["Col1"]["rich_text"][0]["elements"][0]["elements"][0]["text"] == "Test task", "text becomes rich_text")
check(methods()[-1] == "slackLists.items.info", "create must end with a readback")

for bad, why in [("Status=Maybe", "unknown choice"), ("Owner=Pat", "user needs an ID"), ("Due=next week", "date format"),
                 ("Votes=3", "unsupported type"), ("Nope=1", "unknown column"), ("Name", "missing =")]:
    code, _ = run(["lists", "update", "work", "F1", "Rec1", "--field", bad])
    check(code == 1, f"field {bad!r} should fail ({why})")

calls.clear()
code, out = run(["lists", "update", "work", "F1", "Rec1", "--field", "Status=Not Started"])
check(code == 0 and "DRY RUN" in out and "slackLists.items.update" not in methods(), "lists update dry run must not write")

# Records show select choice labels, not option IDs.
out = io.StringIO()
with redirect_stdout(out):
    slack.print_record({"id": "Rec2", "fields": [{"column_id": "Col2", "key": "status", "value": "done", "select": ["done"]}]}, SCHEMA)
check("Status: Done" in out.getvalue(), "select values should render as their labels")
out = io.StringIO()
with redirect_stdout(out):
    slack.print_record({"id": "Rec3", "fields": [{"column_id": "Col5", "key": "ref", "value": "{\"originalUrl\":\"https:\\/\\/example.com\\/1\",\"displayName\":\"Issue 1\"}"}]}, SCHEMA)
check("Source: Issue 1 (https://example.com/1)" in out.getvalue(), "link cells should render as label (url): " + out.getvalue())

# URL parsing.
check(slack.parse_message_url("https://x.slack.com/archives/C1/p1700000000000100?thread_ts=1699999999.000200&cid=C1") == ("C1", "1699999999.000200"), "thread_ts from URL")

# Paging fails loudly past the cap.
def endless(acct, method, params=None, json_body=False):
    return {"ok": True, "channels": [{"id": "C1"}], "response_metadata": {"next_cursor": "more"}}
slack.call = endless
try:
    slack.paged(slack.account("work"), "conversations.list", {}, "channels", max_pages=3)
    raise SystemExit("FAIL: runaway paging should raise")
except slack.SlackError:
    pass

print("slack tests passed")
PYEND
