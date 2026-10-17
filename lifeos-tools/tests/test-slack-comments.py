#!/usr/bin/env python3
"""Offline List discussion tests; invented IDs and text only."""
import contextlib
import importlib.util
import io
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('slack', Path(__file__).resolve().parents[1] / 'lib/slack.py')
slack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slack)


class CommentsTest(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.acct = {'alias': 'work', 'team_id': 'T1', 'user_id': 'U1'}
        self.root = {'ts': '1700000000.000001', 'team': 'T1', 'subtype': 'list_record_comment', 'slack_list': {'list_id': 'F1', 'list_record_id': 'Rec1'}}
        self.reply = {'ts': '1700000001.000002', 'thread_ts': self.root['ts'], 'user': 'U1', 'text': 'hello'}
        self.url = 'https://example.slack.com/archives/C1/p1700000001000002?thread_ts=1700000000.000001&cid=C1'
        self.base = ['work', 'F1', 'Rec1', '--url', self.url]
        self.auth = {'team_id': 'T1', 'user_id': 'U1'}
        self.failure = None
        self.more_pages = False
        self.no_permalink = False
        self.missing_readback = False
        self.patches = [patch.object(slack, 'account', return_value=self.acct), patch.object(slack, 'call', side_effect=self.call)]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop)

    def call(self, acct, method, params=None, json_body=False):
        self.calls.append((method, params or {}, json_body))
        if self.failure == method:
            raise slack.SlackError('missing_scope (needed: channels:history)')
        if method == 'auth.test':
            return self.auth
        if method == 'conversations.replies':
            if 'oldest' in params:
                return {'messages': [] if self.missing_readback else [self.reply]}
            if params['limit'] == 1:
                return {'messages': [self.root]}
            if self.more_pages and not params.get('cursor'):
                return {'messages': [self.root], 'response_metadata': {'next_cursor': 'page2'}}
            return {'messages': [self.root, self.reply]}
        if method == 'chat.postMessage':
            self.assertTrue(json_body)
            self.assertEqual(params['thread_ts'], self.root['ts'])
            self.assertEqual(params['channel'], 'C1')
            self.assertFalse(params['unfurl_links'])
            return {'channel': 'C1', 'ts': self.reply['ts']}
        if method == 'chat.getPermalink':
            return {} if self.no_permalink else {'permalink': 'https://example.slack.com/api-returned-link'}
        self.fail('unexpected API method: ' + method)

    def run_cli(self, command='comment', *extra):
        out, err = io.StringIO(), io.StringIO()
        args = ['lists', command] + self.base + (['--text', 'hello'] if command == 'comment' else []) + list(extra)
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = slack.main(args)
        return code, out.getvalue(), err.getvalue()

    def test_dry_run_validates_target_without_sending(self):
        code, out, _ = self.run_cli()
        self.assertEqual(code, 0)
        self.assertIn('DRY RUN', out)
        self.assertIn('item Rec1', out)
        self.assertEqual([x[0] for x in self.calls], ['auth.test', 'conversations.replies'])

    def test_execute_readback_and_api_permalink(self):
        code, out, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 0, err)
        self.assertIn('Verified comment by U1: hello', out)
        self.assertIn('https://example.slack.com/api-returned-link', out)
        methods = [x[0] for x in self.calls]
        self.assertEqual(methods, ['auth.test', 'conversations.replies', 'chat.postMessage', 'conversations.replies', 'chat.getPermalink'])
        readback = self.calls[3][1]
        self.assertEqual(readback['oldest'], self.reply['ts'])
        self.assertEqual(readback['latest'], self.reply['ts'])

    def test_wrong_item_list_or_non_list_root_refused(self):
        for change in ({'slack_list': {'list_id': 'F1', 'list_record_id': 'Rec2'}}, {'slack_list': {'list_id': 'F2', 'list_record_id': 'Rec1'}}, {'subtype': 'message'}, {'ts': '1700000000.000099'}, {'team': 'T2'}):
            with self.subTest(change=change):
                original = self.root.copy()
                self.root.update(change)
                code, _, err = self.run_cli('comment', '--execute')
                self.assertEqual(code, 1)
                self.assertIn('root does not identify', err)
                self.assertNotIn('chat.postMessage', [x[0] for x in self.calls])
                self.root = original

    def test_identity_and_bot_refused(self):
        for auth in ({'team_id': 'T2', 'user_id': 'U1'}, {'team_id': 'T1', 'user_id': 'U2'}, {'team_id': 'T1', 'user_id': 'U1', 'bot_id': 'B1'}):
            self.auth = auth
            self.calls.clear()
            self.assertEqual(self.run_cli('comment', '--execute')[0], 1)
            self.assertEqual([x[0] for x in self.calls], ['auth.test'])

    def test_read_pages_comments_without_system_root(self):
        self.more_pages = True
        code, out, err = self.run_cli('comments')
        self.assertEqual(code, 0, err)
        self.assertIn('[1700000001.000002] U1: hello', out)
        self.assertNotIn('- [1700000000.000001]', out)
        self.assertIn('Discussion permalink:', out)
        self.assertTrue(any(p.get('cursor') == 'page2' for _, p, _ in self.calls))

    def test_missing_scope_before_send(self):
        self.failure = 'conversations.replies'
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('needed: channels:history', err)
        self.assertNotIn('chat.postMessage', [x[0] for x in self.calls])

    def test_post_failure_never_retries(self):
        self.failure = 'chat.postMessage'
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('uncertain outcome', err)
        self.assertEqual(sum(m == 'chat.postMessage' for m, _, _ in self.calls), 1)

    def test_partial_readback_and_permalink_failures(self):
        for field, value in [('user', 'U2'), ('thread_ts', '1700000099.000001'), ('text', 'different')]:
            with self.subTest(field=field):
                old = self.reply.copy()
                self.reply[field] = value
                code, _, err = self.run_cli('comment', '--execute')
                self.assertEqual(code, 1)
                self.assertIn('PARTIAL:', err)
                self.assertIn('Do not resend', err)
                self.reply = old
        self.missing_readback = True
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('PARTIAL:', err)
        self.missing_readback = False
        self.no_permalink = True
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('PARTIAL:', err)

    def test_reject_bad_url(self):
        for url in ('https://evil.example/archives/C1/p1700000001000002', 'http://example.slack.com/archives/C1/p1700000001000002', 'https://example.slack.com/archives/C1/p1700000001000002?thread_ts=Rec1'):
            self.base[-1] = url
            self.assertEqual(self.run_cli()[0], 1)
        self.assertEqual(self.calls, [])

    def test_empty_text_and_text_file(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(slack.main(['lists', 'comment'] + self.base + ['--text', '   ']), 1)
        self.assertEqual(self.calls, [])
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'comment.txt'
            file.write_text('hello\n')
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = slack.main(['lists', 'comment'] + self.base + ['--text-file', str(file)])
            self.assertEqual(code, 0)
            self.assertIn('hello', out.getvalue())

    def test_refuse_silently_truncated_page(self):
        with patch.object(slack, 'call', return_value={'messages': [], 'has_more': True}):
            with self.assertRaisesRegex(slack.SlackError, 'without a cursor'):
                slack.paged(self.acct, 'conversations.replies', {}, 'messages')


if __name__ == '__main__':
    unittest.main()
