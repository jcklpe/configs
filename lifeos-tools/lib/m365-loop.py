#!/usr/bin/env python3
"""Experimental, isolated headless Loop reads and plain-text appends."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.parse import parse_qsl, unquote, urlsplit

TOOLS_DIR = Path(__file__).resolve().parents[1]
PRIVATE_ROOT = TOOLS_DIR / "secrets" / "loop-browser"
ENGINE_ROOT = TOOLS_DIR / "tmp" / "loop-browser-engines"
EDITOR_SELECTORS = ('[role="textbox"][aria-label="Canvas"]',)
MAX_TEXT_BYTES = 20_000


class LoopError(RuntimeError):
    pass


class LoginRequired(LoopError):
    pass


def validate_alias(alias: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", alias):
        raise LoopError("Account alias must contain only letters, digits, underscores, and hyphens.")
    return alias


def validate_url(url: str) -> str:
    parsed = urlsplit(url)
    host = (parsed.hostname or "").lower()
    allowed = host in {"loop.cloud.microsoft", "loop.microsoft.com", "loop.office.com"} or host.endswith(".sharepoint.com")
    if parsed.scheme != "https" or not allowed or parsed.username or parsed.password or parsed.port not in (None, 443):
        raise LoopError("Use an HTTPS Loop or SharePoint document URL.")
    return url


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def normalized(text: str) -> str:
    return " ".join(text.split())


def load_text(args) -> str:
    text = args.text if args.text is not None else Path(args.file).read_text(encoding="utf-8")
    text = text.replace("\r\n", "\n").replace("\r", "\n").strip("\n")
    if not text.strip() or len(text.encode("utf-8")) > MAX_TEXT_BYTES:
        raise LoopError(f"Append text must be nonempty and at most {MAX_TEXT_BYTES} UTF-8 bytes.")
    if any(ord(c) < 32 and c not in "\n\t" for c in text):
        raise LoopError("Append text contains unsupported control characters.")
    return text


def private_directory(path: Path):
    # Refuse symlink redirection of authentication state, including any existing parent component.
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise LoopError("Browser state directories must not be symlinks.")
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)


@contextmanager
def account_lock(alias: str):
    private_directory(PRIVATE_ROOT)
    directory = PRIVATE_ROOT / validate_alias(alias)
    private_directory(directory)
    lock_path = directory / "session.lock"
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise LoopError("This account's Loop profile is busy. Close its login window or wait for the other command.") from None
        yield directory


@contextmanager
def browser_session(alias: str, *, headed: bool = False):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        raise LoopError(f"Install the optional browser dependency: cd '{TOOLS_DIR}' && uv sync --extra loop") from None
    os.environ["PLAYWRIGHT_BROWSERS_PATH"] = str(ENGINE_ROOT)
    with account_lock(alias) as directory, sync_playwright() as pw:
        try:
            context = pw.chromium.launch_persistent_context(
                str(directory / "profile"), headless=not headed,
                channel="chromium",
                accept_downloads=False, viewport={"width": 1280, "height": 900},
                timeout=20_000,
            )
        except Exception:
            raise LoopError(
                "Could not launch isolated Chromium. Install its engine with: "
                f"cd '{TOOLS_DIR}' && PLAYWRIGHT_BROWSERS_PATH='{ENGINE_ROOT}' .venv/bin/python -m playwright install chromium"
            ) from None
        try:
            page = context.pages[0] if context.pages else context.new_page()
            page.set_default_timeout(12_000)
            yield context, page, directory
        finally:
            if context.browser and context.browser.is_connected():
                context.close()


def locate_editor(page, timeout: float = 45):
    from playwright.sync_api import Error as BrowserError
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        candidates = []
        try:
            for frame in page.frames:
                for selector in EDITOR_SELECTORS:
                    locator = frame.locator(selector)
                    for i in range(locator.count()):
                        candidate = locator.nth(i)
                        if candidate.is_visible():
                            candidates.append(candidate)
        except BrowserError as exc:
            # Silent authentication can replace a frame while its editor is being queried.
            if "Execution context was destroyed" not in str(exc) and "Frame was detached" not in str(exc):
                raise
            candidates = []
        if len(candidates) == 1:
            return candidates[0]
        if len(candidates) > 1:
            raise LoopError("Multiple Loop canvases are visible; refusing to guess which one to edit.")
        page.wait_for_timeout(250)
    host = (urlsplit(page.url).hostname or "").lower()
    if host in {"login.microsoftonline.com", "login.live.com"} or host.endswith(".login.microsoftonline.com"):
        if page.locator('input[type="email"], input[type="password"], input[name="loginfmt"], input[name="otc"], #idDiv_SAOTCS_Proofs').count():
            raise LoginRequired("The isolated browser needs a Microsoft sign-in. Run 'lifeos m365 loop login ALIAS' yourself.")
        raise LoopError("Microsoft's authentication redirect did not finish. Retry the read before assuming the saved session expired.")
    raise LoopError("No Loop Canvas editor found. Sign into the isolated profile, open a document URL, or check whether the Loop UI changed.")


def open_document(page, url: str):
    parsed = urlsplit(validate_url(url))
    if (parsed.hostname or "").endswith(".sharepoint.com") and unquote(parsed.path).lower().endswith(".loop") and not any(key.lower() == "web" for key, _ in parse_qsl(parsed.query)):
        # Graph webUrl can be a download URL; explicitly request the browser editor.
        parsed = parsed._replace(query=parsed.query + ("&" if parsed.query else "") + "web=1")
    page.goto(parsed.geturl(), wait_until="domcontentloaded", timeout=30_000)
    return locate_editor(page)


def snapshot(editor):
    text = editor.inner_text()
    return {"text": text, "sha256": digest(text)}


def append_text(page, editor, text: str):
    # Selection changes and DevTools keyboard events stay inside this browser. Never read or write the OS clipboard.
    editable = editor.evaluate("el => el.isContentEditable || !!el.querySelector('[contenteditable=true]')")
    if not editable:
        raise LoopError("The Loop Canvas is not editable in this session.")
    editor.click()
    editor.evaluate("""el => {
        const root = el.isContentEditable ? el : el.querySelector('[contenteditable=true]');
        root.focus();
        const range = document.createRange();
        range.selectNodeContents(root); range.collapse(false);
        const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
    }""")
    page.keyboard.press("Enter")
    page.keyboard.press("Enter")
    for i, line in enumerate(text.split("\n")):
        if i:
            page.keyboard.press("Enter")
        if line:
            page.keyboard.insert_text(line)


def record_attempt(directory: Path, record: dict):
    record["at"] = datetime.now(timezone.utc).isoformat()
    fd = os.open(directory / "writes.jsonl", os.O_APPEND | os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a") as log:
        log.write(json.dumps(record) + "\n")
        log.flush()
        os.fsync(log.fileno())


def append_document(context, page, directory, url, text, expected_hash):
    editor = open_document(page, url)
    before = snapshot(editor)
    if before["sha256"] != expected_hash:
        raise LoopError("Document text changed since the preview. Read it again and approve a fresh append.")
    record = {"action": "append", "url_sha256": digest(url), "before_sha256": expected_hash, "append_sha256": digest(text), "status": "started"}
    record_attempt(directory, record.copy())
    try:
        append_text(page, editor, text)
        expected_text = normalized(before["text"] + "\n\n" + text)
        deadline = time.monotonic() + 12
        while normalized(editor.inner_text()) != expected_text:
            if time.monotonic() >= deadline:
                raise LoopError("The editor content did not match the planned append.")
            page.wait_for_timeout(250)
        # A second page checks server persistence. This is bounded polling, never a retry of the mutation.
        page.wait_for_timeout(1500)
        reader = context.new_page()
        try:
            for _ in range(3):
                reloaded = open_document(reader, url)
                after = snapshot(reloaded)
                if normalized(after["text"]) == expected_text:
                    record["status"] = "verified"
                    record["after_sha256"] = after["sha256"]
                    record_attempt(directory, record)
                    return {"status": "appended", "headless": True, "sha256": after["sha256"], "verified_in_second_page": True}
                page.wait_for_timeout(1500)
        finally:
            reader.close()
        raise LoopError("The append was not confirmed from a second page.")
    except Exception:
        record["status"] = "possibly_applied"
        record_attempt(directory, record)
        raise LoopError("POSSIBLY APPLIED: the append started but verification failed. Read the document before retrying; the tool will not retry edits.") from None


def parser():
    result = argparse.ArgumentParser(description="Experimental Loop CLI: isolated Chromium, headless except explicit login; plain-text append only.")
    commands = result.add_subparsers(dest="action", required=True)
    login = commands.add_parser("login", help="Open a separate login window; only this command is visible.")
    login.add_argument("alias", type=validate_alias)
    login.add_argument("--url", default="https://loop.cloud.microsoft/", type=validate_url)
    login.add_argument("--timeout", type=int, default=300)
    for action in ("status", "read", "append"):
        command = commands.add_parser(action)
        command.add_argument("alias", type=validate_alias)
        command.add_argument("url", type=validate_url)
        if action == "append":
            content = command.add_mutually_exclusive_group(required=True)
            content.add_argument("--text")
            content.add_argument("--file")
            command.add_argument("--expect-sha256", help="Required for execution; use the hash printed by read/preview.")
            command.add_argument("--execute", action="store_true")
    return result


def run(args):
    if args.action == "login":
        if not 1 <= args.timeout <= 900:
            raise LoopError("Login timeout must be between 1 and 900 seconds.")
        print("Opening a separate Chromium login window. Sign into the account matching the alias, then close that window. Other browsers remain separate.", file=sys.stderr, flush=True)
        with browser_session(args.alias, headed=True) as (context, page, _):
            page.goto(args.url, wait_until="domcontentloaded", timeout=30_000)
            deadline = time.monotonic() + args.timeout
            while time.monotonic() < deadline and context.pages:
                # Pump Playwright's events so a manually closed window is detected immediately.
                try:
                    page.wait_for_timeout(500)
                except Exception:
                    if page.is_closed():
                        break
                    raise
            closed = not context.pages or page.is_closed()
        return {"status": "login_window_closed" if closed else "login_timeout", "next": "Run a headless status/read command to verify authentication."}
    text = load_text(args) if args.action == "append" else None
    if args.action == "append" and args.execute and not re.fullmatch(r"[a-f0-9]{64}", args.expect_sha256 or ""):
        raise LoopError("Execution requires --expect-sha256 with the hash from a read or dry-run preview.")
    with browser_session(args.alias) as (context, page, directory):
        if args.action == "append" and args.execute:
            return append_document(context, page, directory, args.url, text, args.expect_sha256)
        editor = open_document(page, args.url)
        content = snapshot(editor)
        if args.action == "status":
            return {"status": "editor_available", "headless": True, "sha256": content["sha256"], "editable": editor.evaluate("el => el.isContentEditable || !!el.querySelector('[contenteditable=true]')")}
        if args.action == "read":
            return {"status": "read", "headless": True, **content}
        return {"status": "dry_run", "headless": True, "before": content, "append_text": text, "next": "Review the text, then use --execute --expect-sha256 with the current hash. This check is not an atomic lock against collaborators."}


def main():
    try:
        args = parser().parse_args()
        result = run(args)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except LoginRequired as exc:
        print(json.dumps({"status": "login_required", "error": str(exc)}), file=sys.stderr)
        return 3
    except (LoopError, OSError, ValueError) as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    except Exception:
        # Browser exceptions can contain authentication redirect URLs. Keep those out of command output.
        print(json.dumps({"status": "error", "error": "Browser operation failed; no automatic retry was attempted. Check the session and document URL."}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
