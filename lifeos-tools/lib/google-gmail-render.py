#!/usr/bin/env python3
"""Render bounded Gmail message snapshots as Markdown."""

import base64
import email.utils
import html
import json
import re
import sys
from datetime import datetime, timezone
from html.parser import HTMLParser


class HtmlCleaner(HTMLParser):
    block_tags = {"br", "div", "li", "p", "tr", "table", "ul", "ol", "blockquote", "h1", "h2", "h3", "h4"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.links = []

    def newline(self):
        if self.parts and not self.parts[-1].endswith("\n"):
            self.parts.append("\n")

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        attrs = dict(attrs)
        if tag in self.block_tags:
            self.newline()
        if tag == "li":
            self.parts.append("- ")
        if tag == "a":
            self.links.append((attrs.get("href") or "", len(self.parts)))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "a" and self.links:
            href, start = self.links.pop()
            text = "".join(self.parts[start:]).strip()
            if href and href not in text:
                self.parts.append(f" ({href})" if text else href)
        if tag in self.block_tags and tag != "br":
            self.newline()

    def handle_data(self, data):
        self.parts.append(data)

    def text(self):
        return "".join(self.parts)


def header(message, name):
    wanted = name.lower()
    for item in message.get("payload", {}).get("headers", []) or []:
        if (item.get("name") or "").lower() == wanted:
            return item.get("value") or ""
    return ""


def decode_data(value):
    if not value:
        return ""
    padding = "=" * ((4 - len(value) % 4) % 4)
    try:
        return base64.urlsafe_b64decode((value + padding).encode("ascii")).decode("utf-8", errors="replace")
    except Exception:
        return ""


def walk_parts(part):
    yield part
    for child in part.get("parts") or []:
        yield from walk_parts(child)


def attachment_present(message):
    for part in walk_parts(message.get("payload", {}) or {}):
        body = part.get("body") or {}
        if part.get("filename") or body.get("attachmentId"):
            return True
    return False


def message_body(message):
    plain = []
    html_parts = []
    for part in walk_parts(message.get("payload", {}) or {}):
        mime_type = part.get("mimeType") or ""
        data = (part.get("body") or {}).get("data") or ""
        if not data:
            continue
        if mime_type == "text/plain":
            plain.append(decode_data(data))
        elif mime_type == "text/html":
            html_parts.append(decode_data(data))

    if plain:
        return "\n".join(plain)
    if html_parts:
        cleaner = HtmlCleaner()
        cleaner.feed("\n".join(html_parts))
        cleaner.close()
        return cleaner.text()
    return message.get("snippet") or ""


def clean_text(text):
    text = html.unescape(text or "").replace("\r", "").replace("\xa0", " ")
    lines = []
    blank = False
    for line in text.split("\n"):
        line = re.sub(r"[ \t]+", " ", line).strip()
        if not line:
            if lines and not blank:
                lines.append("")
            blank = True
            continue
        lines.append(line)
        blank = False
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines)


def truncate(text, limit):
    if len(text) <= limit:
        return text
    clipped = text[:limit].rstrip()
    split_at = max(clipped.rfind("\n"), clipped.rfind(" "))
    if split_at > limit * 0.7:
        clipped = clipped[:split_at].rstrip()
    return f"{clipped}\n\n[message body truncated]"


def display_date(message):
    date_header = header(message, "Date")
    if date_header:
        parsed = email.utils.parsedate_to_datetime(date_header)
        if parsed:
            if parsed.tzinfo:
                parsed = parsed.astimezone(timezone.utc)
            return parsed.replace(microsecond=0).isoformat().replace("+00:00", "Z")
    internal = message.get("internalDate")
    if internal:
        try:
            parsed = datetime.fromtimestamp(int(internal) / 1000, tz=timezone.utc)
            return parsed.replace(microsecond=0).isoformat().replace("+00:00", "Z")
        except ValueError:
            pass
    return "unknown date"


def quote(text, indent="    "):
    return "\n".join(f"{indent}> {line}" for line in text.split("\n"))


def render(alias, email_address, query, max_results, body_limit, refreshed, data):
    messages = data.get("messages") or []
    lines = [
        f"# Gmail - {alias}",
        "",
        f"Last refreshed: {refreshed}",
        "",
        f"Account alias: `{alias}`",
        "",
        f"Account email: `{email_address}`",
        "",
        f"Query: `{query}`",
        "",
        f"Max results: {max_results}",
        "",
        "## Messages",
        "",
    ]
    if not messages:
        lines.append("_No messages matched this query._")
        return "\n".join(lines) + "\n"

    for message in messages:
        subject = header(message, "Subject") or "(no subject)"
        date = display_date(message)
        body = truncate(clean_text(message_body(message)), body_limit)
        labels = ", ".join(message.get("labelIds") or [])
        lines.extend(
            [
                f"### {date} - {subject}",
                "",
                f"- From: {header(message, 'From') or 'unknown'}",
                f"- To: {header(message, 'To') or ''}",
                f"- Cc: {header(message, 'Cc') or ''}",
                f"- Labels: {labels}",
                f"- Thread ID: `{message.get('threadId') or ''}`",
                f"- Message ID: `{message.get('id') or ''}`",
                f"- Attachments: {'yes' if attachment_present(message) else 'no'}",
            ]
        )
        if body:
            lines.extend(["- Body:", "", quote(body), ""])
        else:
            lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main(argv):
    if len(argv) != 8:
        print("Usage: google-gmail-render.py ALIAS EMAIL QUERY MAX_RESULTS BODY_LIMIT REFRESHED MESSAGES_JSON", file=sys.stderr)
        return 1
    alias, email_address, query, max_results, body_limit, refreshed, messages_path = argv[1:]
    with open(messages_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    print(render(alias, email_address, query, max_results, int(body_limit), refreshed, data), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
