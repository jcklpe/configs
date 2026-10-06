#!/usr/bin/env python3
"""Exercise actual headless browser input against an offline Loop-shaped editor."""

from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

LIB = Path(__file__).resolve().parents[1] / "lib" / "m365-loop.py"
spec = importlib.util.spec_from_file_location("loop_adapter", LIB)
loop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(loop)

URL = "https://loop.cloud.microsoft/p/offline-fixture"
FIXTURE = """<!doctype html><title>Offline editor</title>
<div role="textbox" aria-label="Canvas" contenteditable="true">Existing <strong>formatted</strong> text</div>
<script>
const editor = document.querySelector('[contenteditable]');
editor.innerHTML = localStorage.getItem('saved') || editor.innerHTML;
editor.addEventListener('input', () => { SAVE });
Object.defineProperty(navigator, 'clipboard', {value: {
  writeText: () => {throw new Error('clipboard access forbidden')},
  readText: () => {throw new Error('clipboard access forbidden')}
}});
</script>"""


class HeadlessLoopTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from playwright.sync_api import sync_playwright
        os.environ["PLAYWRIGHT_BROWSERS_PATH"] = str(loop.ENGINE_ROOT)
        cls.pw = sync_playwright().start()
        cls.browser = cls.pw.chromium.launch(headless=True, channel="chromium")

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.pw.stop()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="loop-fixture-")
        self.directory = Path(self.tmp.name).resolve()
        self.context = self.browser.new_context()
        self.save = True
        def route(request):
            if request.request.url.startswith("https://loop.cloud.microsoft/"):
                code = "localStorage.setItem('saved', editor.innerHTML)" if self.save else ""
                request.fulfill(body=FIXTURE.replace("SAVE", code), content_type="text/html")
            else:
                request.abort()
        self.context.route("**/*", route)
        self.page = self.context.new_page()

    def tearDown(self):
        self.context.close()
        self.tmp.cleanup()

    @contextmanager
    def session(self, alias, *, headed=False):
        self.assertFalse(headed)
        yield self.context, self.page, self.directory

    def test_dry_run_is_read_only(self):
        args = loop.parser().parse_args(["append", "fixture", URL, "--text", "Proposed note"])
        with patch.object(loop, "browser_session", self.session):
            result = loop.run(args)
        self.assertEqual(result["status"], "dry_run")
        self.assertEqual(self.page.locator('[contenteditable]').inner_text(), "Existing formatted text")
        self.assertFalse((self.directory / "writes.jsonl").exists())

    def test_append_preserves_formatting_and_persists_without_clipboard(self):
        before = loop.snapshot(loop.open_document(self.page, URL))
        result = loop.append_document(self.context, self.page, self.directory, URL, "New note\nSecond line", before["sha256"])
        self.assertTrue(result["verified_in_second_page"])
        self.assertEqual(self.page.locator("strong").inner_text(), "formatted")
        self.assertEqual(loop.normalized(self.page.locator('[contenteditable]').inner_text()), "Existing formatted text New note Second line")
        records = [json.loads(line) for line in (self.directory / "writes.jsonl").read_text().splitlines()]
        self.assertEqual([record["status"] for record in records], ["started", "verified"])
        self.assertEqual((self.directory / "writes.jsonl").stat().st_mode & 0o777, 0o600)

    def test_stale_preview_refuses_input(self):
        with self.assertRaisesRegex(loop.LoopError, "changed since the preview"):
            loop.append_document(self.context, self.page, self.directory, URL, "New note", "0" * 64)
        self.assertEqual(self.page.locator('[contenteditable]').inner_text(), "Existing formatted text")
        self.assertFalse((self.directory / "writes.jsonl").exists())

    def test_uncertain_persistence_never_retries_the_append(self):
        self.save = False
        before = loop.snapshot(loop.open_document(self.page, URL))
        with self.assertRaisesRegex(loop.LoopError, "POSSIBLY APPLIED"):
            loop.append_document(self.context, self.page, self.directory, URL, "One insertion", before["sha256"])
        self.assertEqual(self.page.locator('[contenteditable]').inner_text().count("One insertion"), 1)
        records = [json.loads(line) for line in (self.directory / "writes.jsonl").read_text().splitlines()]
        self.assertEqual(records[-1]["status"], "possibly_applied")

    def test_ambiguous_canvases_refuse_editing(self):
        loop.open_document(self.page, URL)
        self.page.locator("body").evaluate("el => el.appendChild(el.firstElementChild.cloneNode(true))")
        with self.assertRaisesRegex(loop.LoopError, "Multiple Loop canvases"):
            loop.locate_editor(self.page, timeout=1)

    def test_silent_auth_redirect_is_allowed_to_finish(self):
        auth_url = "https://login.microsoftonline.com/offline-auth"
        self.context.route(auth_url, lambda route: route.fulfill(body=f'<title>Working...</title><script>setTimeout(() => location.replace({json.dumps(URL)}), 500)</script>', content_type="text/html"))
        self.page.goto(auth_url)
        editor = loop.locate_editor(self.page, timeout=3)
        self.assertEqual(editor.inner_text(), "Existing formatted text")

    def test_stalled_auth_redirect_is_not_reported_as_expired_login(self):
        auth_url = "https://login.microsoftonline.com/offline-auth"
        self.context.route(auth_url, lambda route: route.fulfill(body='<title>Working...</title>', content_type="text/html"))
        self.page.goto(auth_url)
        with self.assertRaisesRegex(loop.LoopError, "redirect did not finish") as raised:
            loop.locate_editor(self.page, timeout=0.2)
        self.assertNotIsInstance(raised.exception, loop.LoginRequired)

    def test_interactive_auth_is_reported_after_redirect_wait(self):
        auth_url = "https://login.microsoftonline.com/offline-auth"
        self.context.route(auth_url, lambda route: route.fulfill(body='<input type="email" name="loginfmt">', content_type="text/html"))
        self.page.goto(auth_url)
        with self.assertRaises(loop.LoginRequired):
            loop.locate_editor(self.page, timeout=0.2)

    def test_sharepoint_loop_download_urls_request_browser_view(self):
        page = Mock()
        for url, expected in [
            ("https://example.sharepoint.com/Documents/Test.loop", "https://example.sharepoint.com/Documents/Test.loop?web=1"),
            ("https://example.sharepoint.com/Documents/Test.loop?d=fixture#section", "https://example.sharepoint.com/Documents/Test.loop?d=fixture&web=1#section"),
            ("https://example.sharepoint.com/Documents/Test.loop?web=1", "https://example.sharepoint.com/Documents/Test.loop?web=1"),
            (URL, URL),
        ]:
            with self.subTest(url=url), patch.object(loop, "locate_editor"):
                loop.open_document(page, url)
                page.goto.assert_called_with(expected, wait_until="domcontentloaded", timeout=30_000)

    def test_execute_requires_preview_hash_before_launch(self):
        args = loop.parser().parse_args(["append", "fixture", URL, "--text", "Note", "--execute"])
        with patch.object(loop, "browser_session", side_effect=AssertionError("Browser must not launch")):
            with self.assertRaisesRegex(loop.LoopError, "requires --expect-sha256"):
                loop.run(args)

    def test_only_explicit_login_requests_a_headed_window(self):
        page = Mock()
        page.wait_for_timeout.side_effect = RuntimeError("window closed")
        page.is_closed.return_value = True
        context = Mock()
        context.pages = [page]
        @contextmanager
        def login_session(alias, *, headed=False):
            self.assertTrue(headed)
            yield context, page, self.directory
        args = loop.parser().parse_args(["login", "fixture"])
        with patch.object(loop, "browser_session", login_session):
            result = loop.run(args)
        self.assertEqual(result["status"], "login_window_closed")

    def test_profile_lock_and_private_permissions(self):
        with patch.object(loop, "PRIVATE_ROOT", self.directory / "private"):
            with loop.account_lock("fixture") as profile:
                self.assertEqual(profile.stat().st_mode & 0o777, 0o700)
                with self.assertRaisesRegex(loop.LoopError, "profile is busy"):
                    with loop.account_lock("fixture"):
                        self.fail("Concurrent profile access allowed")

    def test_targets_and_aliases_are_bounded(self):
        for url in ["https://example.org", "http://loop.cloud.microsoft", "https://loop.cloud.microsoft.evil.test", "https://user:password@loop.cloud.microsoft", "https://loop.cloud.microsoft:9222"]:
            with self.assertRaises(loop.LoopError):
                loop.validate_url(url)
        for alias in ["../chrome", "", "a/b"]:
            with self.assertRaises(loop.LoopError):
                loop.validate_alias(alias)


if __name__ == "__main__":
    unittest.main()
