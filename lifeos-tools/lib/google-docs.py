#!/usr/bin/env python3
"""Read Google Docs and perform one exact, revision-guarded replacement.

Ported into lifeos-tools from the Open Austin org repo's google-docs tool
(docs/decisions record: docs-editing-in-lifeos-tools). Self-contained: it takes
its access token from the GOOGLE_ACCESS_TOKEN env var (set by the `lifeos docs`
shell wrapper via the normal per-alias token machinery) rather than doing its
own OAuth, and requires an explicit --document-id. No dependency on any repo.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


DOCS_API = "https://docs.googleapis.com/v1/documents"


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def api_json(method, url, access_token, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Authorization": f"Bearer {access_token}", "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json; charset=utf-8"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Google Docs API returned HTTP {exc.code}: {detail}") from exc


def get_document(document_id, access_token):
    url = f"{DOCS_API}/{urllib.parse.quote(document_id)}?includeTabsContent=true"
    return api_json("GET", url, access_token)


def structural_text(elements):
    chunks = []
    for element in elements or []:
        paragraph = element.get("paragraph")
        if paragraph:
            for paragraph_element in paragraph.get("elements", []):
                text_run = paragraph_element.get("textRun")
                if text_run:
                    chunks.append(text_run.get("content", ""))
        table = element.get("table")
        if table:
            for row in table.get("tableRows", []):
                for cell in row.get("tableCells", []):
                    chunks.append(structural_text(cell.get("content", [])))
        toc = element.get("tableOfContents")
        if toc:
            chunks.append(structural_text(toc.get("content", [])))
    return "".join(chunks)


def utf16_length(value):
    return len(value.encode("utf-16-le")) // 2


def structural_text_with_spans(elements):
    chunks = []
    spans = []
    for element in elements or []:
        paragraph = element.get("paragraph")
        if paragraph:
            for paragraph_element in paragraph.get("elements", []):
                text_run = paragraph_element.get("textRun")
                if not text_run:
                    continue
                content = text_run.get("content", "")
                index = paragraph_element.get("startIndex")
                if index is None:
                    raise ValueError("Google Docs text run is missing startIndex")
                chunks.append(content)
                for character in content:
                    next_index = index + utf16_length(character)
                    spans.append((index, next_index))
                    index = next_index
        table = element.get("table")
        if table:
            for row in table.get("tableRows", []):
                for cell in row.get("tableCells", []):
                    text, cell_spans = structural_text_with_spans(cell.get("content", []))
                    chunks.append(text)
                    spans.extend(cell_spans)
        toc = element.get("tableOfContents")
        if toc:
            text, toc_spans = structural_text_with_spans(toc.get("content", []))
            chunks.append(text)
            spans.extend(toc_spans)
    return "".join(chunks), spans


def structural_links(elements):
    links = []
    for element in elements or []:
        paragraph = element.get("paragraph")
        if paragraph:
            for paragraph_element in paragraph.get("elements", []):
                text_run = paragraph_element.get("textRun")
                link = (text_run or {}).get("textStyle", {}).get("link", {})
                if text_run and link.get("url"):
                    links.append({"text": text_run.get("content", ""), "url": link["url"]})
        table = element.get("table")
        if table:
            for row in table.get("tableRows", []):
                for cell in row.get("tableCells", []):
                    links.extend(structural_links(cell.get("content", [])))
        toc = element.get("tableOfContents")
        if toc:
            links.extend(structural_links(toc.get("content", [])))
    return links


def walk_tabs(tabs):
    for tab in tabs or []:
        properties = tab.get("tabProperties", {})
        document_tab = tab.get("documentTab", {})
        body = document_tab.get("body", {})
        text, spans = structural_text_with_spans(body.get("content", []))
        yield {
            "id": properties.get("tabId", ""),
            "title": properties.get("title", "Untitled tab"),
            "text": text,
            "spans": spans,
            "links": structural_links(body.get("content", [])),
        }
        yield from walk_tabs(tab.get("childTabs", []))


def document_tabs(document):
    tabs = list(walk_tabs(document.get("tabs", [])))
    if tabs:
        return tabs
    text, spans = structural_text_with_spans(document.get("body", {}).get("content", []))
    body = document.get("body", {})
    return [{"id": "", "title": "Document", "text": text, "spans": spans, "links": structural_links(body.get("content", []))}]


def selected_tabs(document, tab_ids):
    tabs = document_tabs(document)
    if not tab_ids:
        return tabs
    wanted = set(tab_ids)
    selected = [tab for tab in tabs if tab["id"] in wanted]
    missing = wanted - {tab["id"] for tab in selected}
    if missing:
        raise ValueError(f"Unknown tab ID(s): {', '.join(sorted(missing))}")
    return selected


def text_argument(value, path, label):
    if value is not None:
        return value
    if path is not None:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    raise ValueError(f"{label} text is required")


def document_id_from(args):
    document_id = (args.document_id or "").strip()
    if not document_id:
        raise ValueError("Provide --document-id")
    return document_id


def access_token():
    token = os.environ.get("GOOGLE_ACCESS_TOKEN", "").strip()
    if not token:
        raise ValueError("GOOGLE_ACCESS_TOKEN is required (normally set by the `lifeos docs` wrapper)")
    return token


def command_read(args):
    document_id = document_id_from(args)
    document = get_document(document_id, access_token())
    print(f"# {document.get('title', 'Untitled document')}")
    print(f"Document ID: {document_id}")
    print(f"Revision ID: {document.get('revisionId', '<missing>')}")
    for tab in selected_tabs(document, args.tab_id):
        print(f"\n## {tab['title']} [{tab['id'] or 'first-tab'}]\n")
        print(tab["text"], end="" if tab["text"].endswith("\n") else "\n")
        if args.show_links:
            print("\nEmbedded links:")
            for link in tab["links"]:
                print(f"- {link['text']} -> {link['url']}")
    return 0


def count_matches(document, tab_ids, old_text):
    return sum(tab["text"].count(old_text) for tab in selected_tabs(document, tab_ids))


def exact_text_range(document, tab_ids, value):
    matches = []
    for tab in selected_tabs(document, tab_ids):
        position = tab["text"].find(value)
        while position >= 0:
            matches.append((tab, position))
            position = tab["text"].find(value, position + 1)
    if len(matches) != 1:
        raise ValueError(f"Exact text must occur once in the selected scope; found {len(matches)}")
    tab, position = matches[0]
    end_position = position + len(value)
    if not value or end_position > len(tab["spans"]):
        raise ValueError("Unable to resolve the exact text to Google Docs indices")
    return {
        "tab_id": tab["id"],
        "start_index": tab["spans"][position][0],
        "end_index": tab["spans"][end_position - 1][1],
    }


def parse_link_specs(specs, new_text):
    links = []
    occupied = []
    for spec in specs or []:
        label, separator, url = spec.partition("=")
        label = label.strip()
        url = url.strip()
        if not separator or not label or not url:
            raise ValueError("Each --link must use the form 'visible text=https://example.com'")
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError(f"Link URL must be HTTP(S): {url}")
        if new_text.count(label) != 1:
            raise ValueError(f"Link text must occur once in the replacement text: {label!r}")
        start = new_text.index(label)
        end = start + len(label)
        if any(start < other_end and other_start < end for other_start, other_end in occupied):
            raise ValueError(f"Link text overlaps another link: {label!r}")
        occupied.append((start, end))
        links.append({"label": label, "url": url, "start": start, "end": end})
    return links


def link_style_requests(old_range, new_text, links):
    requests = []
    for link in links:
        start_index = old_range["start_index"] + utf16_length(new_text[: link["start"]])
        end_index = old_range["start_index"] + utf16_length(new_text[: link["end"]])
        range_value = {"startIndex": start_index, "endIndex": end_index}
        if old_range["tab_id"]:
            range_value["tabId"] = old_range["tab_id"]
        requests.append(
            {
                "updateTextStyle": {
                    "range": range_value,
                    "textStyle": {"link": {"url": link["url"]}},
                    "fields": "link",
                }
            }
        )
    return requests


def print_replacement_plan(document, document_id, tab_ids, old_text, new_text, links):
    print("Google Docs exact replacement plan:")
    print(f"Document: {document.get('title', 'Untitled document')} ({document_id})")
    print(f"Revision read: {document.get('revisionId', '<missing>')}")
    print(f"Tabs: {', '.join(tab_ids) if tab_ids else '<all tabs>'}")
    print("--- current exact text ---")
    print(old_text)
    print("--- proposed replacement ---")
    print(new_text)
    if links:
        print("--- embedded links ---")
        for link in links:
            print(f"{link['label']} -> {link['url']}")
    print("--- end plan ---")


def command_replace_once(args):
    document_id = document_id_from(args)
    old_text = text_argument(args.old, args.old_file, "Old")
    new_text = text_argument(args.new, args.new_file, "New")
    if not old_text:
        raise ValueError("Old text must not be empty")
    token = access_token()
    document = get_document(document_id, token)
    matches = count_matches(document, args.tab_id, old_text)
    if matches != 1:
        raise ValueError(f"Exact old text must occur once in the selected scope; found {matches}")
    links = parse_link_specs(args.link, new_text)
    old_range = exact_text_range(document, args.tab_id, old_text)
    print_replacement_plan(document, document_id, args.tab_id, old_text, new_text, links)
    if not args.execute:
        print("DRY RUN: no Google Doc was changed. Re-run with --execute after approval.")
        return 0

    live_document = get_document(document_id, token)
    live_matches = count_matches(live_document, args.tab_id, old_text)
    if live_matches != 1:
        raise ValueError(f"Document changed before execution; exact old text now occurs {live_matches} times")
    revision_id = live_document.get("revisionId")
    if not revision_id:
        raise ValueError("Google Docs response did not include a revisionId")
    live_old_range = exact_text_range(live_document, args.tab_id, old_text)
    if live_old_range != old_range:
        raise ValueError("Document changed before execution; exact text moved to a different range")
    replace_request = {
        "replaceText": new_text,
        "containsText": {"text": old_text, "matchCase": True, "searchByRegex": False},
    }
    if args.tab_id:
        replace_request["tabsCriteria"] = {"tabIds": args.tab_id}
    requests = [{"replaceAllText": replace_request}]
    requests.extend(link_style_requests(live_old_range, new_text, links))
    payload = {
        "requests": requests,
        "writeControl": {"requiredRevisionId": revision_id},
    }
    url = f"{DOCS_API}/{urllib.parse.quote(document_id)}:batchUpdate"
    try:
        result = api_json("POST", url, token, payload)
    except RuntimeError as exc:
        message = str(exc)
        if "HTTP 403" in message or "PERMISSION_DENIED" in message or "insufficient" in message.lower():
            alias = os.environ.get("LIFEOS_DOCS_ALIAS", "").strip()
            hint = (
                f"run: lifeos google auth {alias} --docs-write"
                if alias
                else "authorize the Docs write scope: lifeos google auth ALIAS --docs-write"
            )
            raise RuntimeError(f"{message}\nHINT: editing needs the Google Docs write scope — {hint}") from exc
        raise
    responses = result.get("replies") or result.get("responses") or []
    changed = 0
    for response in responses:
        changed += response.get("replaceAllText", {}).get("occurrencesChanged", 0)
    if changed != 1:
        raise RuntimeError(f"Google reported {changed} replacements; expected exactly 1")
    print(f"Updated document at revision {result.get('writeControl', {}).get('requiredRevisionId', revision_id)}; replacements: {changed}")
    return 0



# ---- set-body: replace a document's entire body in place (preserves doc id/history/links) ----

def _flatten_tabs(tabs, out):
    for tab in tabs or []:
        props = tab.get("tabProperties", {})
        body = tab.get("documentTab", {}).get("body", {})
        out.append((props.get("tabId", ""), body))
        _flatten_tabs(tab.get("childTabs", []), out)


def get_target_tab(document, tab_ids):
    tabs = document.get("tabs")
    if tabs:
        flat = []
        _flatten_tabs(tabs, flat)
        if not flat:
            return None, document.get("body", {})
        if tab_ids:
            wanted = set(tab_ids)
            for tid, body in flat:
                if tid in wanted:
                    return tid, body
            raise ValueError(f"Unknown tab ID(s): {', '.join(tab_ids)}")
        return flat[0]
    return None, document.get("body", {})


def body_end_index(body):
    end = 1
    for element in body.get("content", []) or []:
        ei = element.get("endIndex")
        if ei is not None and ei > end:
            end = ei
    return end


_INLINE_TOKEN = re.compile(r"\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|\*([^*]+)\*")


def parse_inline(text):
    """Return (plain_text, spans). Spans are code-point ranges into plain_text."""
    plain = ""
    spans = []
    pos = 0
    for match in _INLINE_TOKEN.finditer(text):
        plain += text[pos:match.start()]
        if match.group(1) is not None:
            label, url = match.group(1), match.group(2)
            start = len(plain); plain += label; end = len(plain)
            spans.append({"start": start, "end": end, "link": url})
        elif match.group(3) is not None:
            # Bold may wrap a link, as in **[label](url)**: parse the inside too and shift its spans.
            inner_plain, inner_spans = parse_inline(match.group(3))
            start = len(plain); plain += inner_plain; end = len(plain)
            spans.extend(dict(span, start=span["start"] + start, end=span["end"] + start) for span in inner_spans)
            spans.append({"start": start, "end": end, "bold": True})
        elif match.group(4) is not None:
            seg = match.group(4); start = len(plain); plain += seg; end = len(plain)
            spans.append({"start": start, "end": end, "italic": True})
        pos = match.end()
    plain += text[pos:]
    return plain, spans


_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
_BULLET_RE = re.compile(r"^([ \t]*)[-*]\s+(.*)$")


def parse_markdown_blocks(md):
    blocks = []
    for raw in md.replace("\r\n", "\n").split("\n"):
        line = raw.rstrip()
        if line.strip() == "":
            blocks.append({"style": "NORMAL_TEXT", "bullet": False, "level": 0, "text": "", "spans": []})
            continue
        mh = _HEADING_RE.match(line)
        mb = _BULLET_RE.match(line)
        if mh:
            level = min(len(mh.group(1)), 6)
            plain, spans = parse_inline(mh.group(2).strip())
            blocks.append({"style": f"HEADING_{level}", "bullet": False, "level": 0, "text": plain, "spans": spans})
        elif mb:
            indent = mb.group(1).replace("\t", "  ")
            plain, spans = parse_inline(mb.group(2).strip())
            blocks.append({"style": "NORMAL_TEXT", "bullet": True, "level": len(indent) // 2, "text": plain, "spans": spans})
        else:
            plain, spans = parse_inline(line)
            blocks.append({"style": "NORMAL_TEXT", "bullet": False, "level": 0, "text": plain, "spans": spans})
    while blocks and blocks[-1]["text"] == "" and not blocks[-1]["bullet"]:
        blocks.pop()
    return blocks


def _range(tab_id, start, end):
    value = {"startIndex": start, "endIndex": end}
    if tab_id:
        value["tabId"] = tab_id
    return value


def _location(tab_id, index):
    value = {"index": index}
    if tab_id:
        value["tabId"] = tab_id
    return value


def build_setbody_requests(tab_id, insert_start, blocks):
    final = ""
    metas = []
    for i, block in enumerate(blocks):
        cp_start = len(final)
        final += block["text"]
        cp_text_end = len(final)
        if i != len(blocks) - 1:
            final += "\n"
        metas.append((cp_start, cp_text_end, block))

    def abs_idx(cp):
        return insert_start + utf16_length(final[:cp])

    requests = [{"insertText": {"location": _location(tab_id, insert_start), "text": final}}]
    for cp_start, cp_text_end, block in metas:
        a = abs_idx(cp_start)
        z = abs_idx(cp_text_end)
        para_end = z if z > a else a + 1
        if block["style"].startswith("HEADING_"):
            requests.append({"updateParagraphStyle": {
                "range": _range(tab_id, a, para_end),
                "paragraphStyle": {"namedStyleType": block["style"]},
                "fields": "namedStyleType"}})
        if block["bullet"]:
            requests.append({"createParagraphBullets": {
                "range": _range(tab_id, a, para_end),
                "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"}})
            if block["level"] > 0:
                indent_pt = 18 * (block["level"] + 1)
                requests.append({"updateParagraphStyle": {
                    "range": _range(tab_id, a, para_end),
                    "paragraphStyle": {
                        "indentStart": {"magnitude": indent_pt, "unit": "PT"},
                        "indentFirstLine": {"magnitude": indent_pt, "unit": "PT"}},
                    "fields": "indentStart,indentFirstLine"}})
        for span in block["spans"]:
            s = abs_idx(cp_start + span["start"])
            e = abs_idx(cp_start + span["end"])
            if e <= s:
                continue
            if span.get("link"):
                requests.append({"updateTextStyle": {
                    "range": _range(tab_id, s, e),
                    "textStyle": {"link": {"url": span["link"]}},
                    "fields": "link"}})
            style = {}
            fields = []
            if span.get("bold"):
                style["bold"] = True; fields.append("bold")
            if span.get("italic"):
                style["italic"] = True; fields.append("italic")
            if fields:
                requests.append({"updateTextStyle": {
                    "range": _range(tab_id, s, e),
                    "textStyle": style,
                    "fields": ",".join(fields)}})
    return requests, final


def command_set_body(args):
    document_id = document_id_from(args)
    md = text_argument(args.new, args.file, "Body")
    token = access_token()
    document = get_document(document_id, token)
    tab_id, body = get_target_tab(document, args.tab_id)
    end_index = body_end_index(body)
    blocks = parse_markdown_blocks(md)
    if not blocks:
        raise ValueError("Body content is empty")
    _, final = build_setbody_requests(tab_id, 1, blocks)
    print("Google Docs set-body plan:")
    print(f"Document: {document.get('title', 'Untitled document')} ({document_id})")
    print(f"Revision read: {document.get('revisionId', '<missing>')}")
    print(f"Target tab: {tab_id or '<first / legacy body>'}")
    print(f"Clears existing body [1, {end_index - 1}) and inserts {len(blocks)} block(s) in place (doc id, history, comments, and links preserved).")
    print("--- new body (plain preview) ---")
    print(final)
    print("--- end plan ---")
    if not args.execute:
        print("DRY RUN: no Google Doc was changed. Re-run with --execute after approval.")
        return 0

    live = get_document(document_id, token)
    revision_id = live.get("revisionId")
    if not revision_id:
        raise ValueError("Google Docs response did not include a revisionId")
    live_tab_id, live_body = get_target_tab(live, args.tab_id)
    live_end = body_end_index(live_body)
    requests = []
    if live_end > 2:
        requests.append({"deleteContentRange": {"range": _range(live_tab_id, 1, live_end - 1)}})
    body_requests, _ = build_setbody_requests(live_tab_id, 1, blocks)
    requests.extend(body_requests)
    payload = {"requests": requests, "writeControl": {"requiredRevisionId": revision_id}}
    url = f"{DOCS_API}/{urllib.parse.quote(document_id)}:batchUpdate"
    try:
        api_json("POST", url, token, payload)
    except RuntimeError as exc:
        message = str(exc)
        if "HTTP 403" in message or "PERMISSION_DENIED" in message or "insufficient" in message.lower():
            alias = os.environ.get("LIFEOS_DOCS_ALIAS", "").strip()
            hint = (f"run: lifeos google auth {alias} --docs-write" if alias
                    else "authorize the Docs write scope: lifeos google auth ALIAS --docs-write")
            raise RuntimeError(f"{message}\nHINT: editing needs the Google Docs write scope — {hint}") from exc
        raise
    print(f"Set body of document {document_id} in place ({len(blocks)} blocks).")
    return 0


# ---- comments: list and add Drive comments on a Doc ----

DRIVE_FILES_API = "https://www.googleapis.com/drive/v3/files"
COMMENT_FIELDS = "id,content,quotedFileContent,author(displayName),createdTime,resolved"


def comment_scope_hint(message):
    alias = os.environ.get("LIFEOS_DOCS_ALIAS", "").strip() or "ALIAS"
    return f"{message}\nHINT: commenting needs the full Drive scope — run: lifeos google auth {alias} --docs-comment"


def build_comment_payload(document, tab_ids, quote, body):
    # Google Docs does not anchor API-created comments to a text range; the quote rides along as quotedFileContent and shows in the comment. Uniqueness is still required so the quote cannot point at the wrong passage.
    if not body or not body.strip():
        raise ValueError("Comment body must not be empty")
    payload = {"content": body}
    if quote is not None:
        if not quote:
            raise ValueError("Quote must not be empty; omit --quote for an unquoted comment")
        matches = count_matches(document, tab_ids, quote)
        if matches != 1:
            raise ValueError(f"Quoted text must occur once in the selected scope; found {matches}. Lengthen the quote until it is unique, or check punctuation against `lifeos docs read`.")
        payload["quotedFileContent"] = {"mimeType": "text/plain", "value": quote}
    return payload


def command_comments(args):
    document_id = document_id_from(args)
    token = access_token()
    params = {"fields": f"comments({COMMENT_FIELDS}),nextPageToken", "pageSize": "100", "includeDeleted": "false"}
    comments = []
    while True:
        url = f"{DRIVE_FILES_API}/{urllib.parse.quote(document_id)}/comments?{urllib.parse.urlencode(params)}"
        try:
            result = api_json("GET", url, token)
        except RuntimeError as exc:
            if "HTTP 403" in str(exc):
                raise RuntimeError(comment_scope_hint(str(exc))) from exc
            raise
        comments.extend(result.get("comments", []))
        if not result.get("nextPageToken"):
            break
        params["pageToken"] = result["nextPageToken"]
    print(f"Document ID: {document_id}")
    print(f"Comments: {len(comments)}")
    for comment in comments:
        state = "resolved" if comment.get("resolved") else "open"
        author = comment.get("author", {}).get("displayName", "unknown")
        print(f"\n- [{state}] {author} · {comment.get('createdTime', '')} · id {comment.get('id', '')}")
        quoted = comment.get("quotedFileContent", {}).get("value")
        if quoted:
            print(f"  > {quoted}")
        print(f"  {comment.get('content', '')}")
    return 0


def command_comment(args):
    document_id = document_id_from(args)
    body = text_argument(args.body, args.body_file, "Comment")
    token = access_token()
    document = get_document(document_id, token)
    payload = build_comment_payload(document, args.tab_id, args.quote, body)
    print("Google Docs comment plan:")
    print(f"Document: {document.get('title', 'Untitled document')} ({document_id})")
    print(f"Revision read: {document.get('revisionId', '<missing>')}")
    print("--- quoted text ---")
    print(args.quote if args.quote is not None else "<none: unquoted comment>")
    print("--- comment ---")
    print(body)
    print("--- end plan ---")
    print("NOTE: Google Docs shows API comments with the quote but does not highlight it in the text.")
    if not args.execute:
        print("DRY RUN: no comment was posted. Re-run with --execute after approval.")
        return 0

    if args.quote is not None:
        live_document = get_document(document_id, token)
        payload = build_comment_payload(live_document, args.tab_id, args.quote, body)
    url = f"{DRIVE_FILES_API}/{urllib.parse.quote(document_id)}/comments?fields={urllib.parse.quote(COMMENT_FIELDS)}"
    try:
        result = api_json("POST", url, token, payload)
    except RuntimeError as exc:
        message = str(exc)
        if "HTTP 403" in message or "PERMISSION_DENIED" in message or "insufficient" in message.lower():
            raise RuntimeError(comment_scope_hint(message)) from exc
        raise
    if not result.get("id"):
        raise RuntimeError("Google did not return a comment id; the comment may not have been posted")
    print(f"Posted comment {result['id']} on document {document_id}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Read Google Docs and perform one exact, revision-guarded replacement.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    read_parser = subparsers.add_parser("read", help="Render document text")
    read_parser.add_argument("--document-id")
    read_parser.add_argument("--tab-id", action="append", default=[])
    read_parser.add_argument("--show-links", action="store_true")
    read_parser.set_defaults(func=command_read)

    replace_parser = subparsers.add_parser("replace-once", help="Replace one exact text occurrence; dry-run by default")
    replace_parser.add_argument("--document-id")
    old_group = replace_parser.add_mutually_exclusive_group(required=True)
    old_group.add_argument("--old")
    old_group.add_argument("--old-file")
    new_group = replace_parser.add_mutually_exclusive_group(required=True)
    new_group.add_argument("--new")
    new_group.add_argument("--new-file")
    replace_parser.add_argument("--tab-id", action="append", default=[])
    replace_parser.add_argument(
        "--link",
        action="append",
        default=[],
        metavar="TEXT=URL",
        help="Embed a link on uniquely occurring visible text in the replacement; repeatable",
    )
    replace_parser.add_argument("--execute", action="store_true")
    replace_parser.set_defaults(func=command_replace_once)

    setbody_parser = subparsers.add_parser("set-body", help="Replace the document body in place with formatted content from markdown; dry-run by default")
    setbody_parser.add_argument("--document-id")
    body_group = setbody_parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--file", help="Path to a markdown source file")
    body_group.add_argument("--new", help="Inline markdown body")
    setbody_parser.add_argument("--tab-id", action="append", default=[])
    setbody_parser.add_argument("--execute", action="store_true")
    setbody_parser.set_defaults(func=command_set_body)

    comments_parser = subparsers.add_parser("comments", help="List the document's comments")
    comments_parser.add_argument("--document-id")
    comments_parser.set_defaults(func=command_comments)

    comment_parser = subparsers.add_parser("comment", help="Add one comment, optionally quoting uniquely occurring text; dry-run by default")
    comment_parser.add_argument("--document-id")
    comment_parser.add_argument("--quote", help="Exact document text the comment refers to; must occur once")
    comment_group = comment_parser.add_mutually_exclusive_group(required=True)
    comment_group.add_argument("--body")
    comment_group.add_argument("--body-file")
    comment_parser.add_argument("--tab-id", action="append", default=[])
    comment_parser.add_argument("--execute", action="store_true")
    comment_parser.set_defaults(func=command_comment)
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except Exception as exc:
        return fail(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
