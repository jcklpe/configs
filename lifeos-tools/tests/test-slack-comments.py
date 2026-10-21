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
        self.history = [self.root]
        self.history_more = False
        self.hide_root = False
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
        if method == 'conversations.history':
            if self.history_more and not params.get('cursor'):
                return {'messages': [], 'response_metadata': {'next_cursor': 'next'}}
            return {'messages': self.history}
        if method == 'conversations.replies':
            if 'oldest' in params:
                return {'messages': [] if self.missing_readback else [self.reply]}
            if params['limit'] == 1:
                return {'messages': [] if self.hide_root else [self.root]}
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

    def configure_discovery(self):
        self.base = self.base[:3]
        self.acct['lists'] = [{'id': 'F1', 'discussion_channel_id': 'C1'}]

    def test_automatic_discovery_without_url(self):
        self.configure_discovery()
        code, out, err = self.run_cli('comments')
        self.assertEqual(code, 0, err)
        self.assertIn('discussion C1 / 1700000000.000001', out)
        self.assertEqual([x[0] for x in self.calls[:3]], ['auth.test', 'conversations.history', 'conversations.replies'])

    def test_first_user_comment_uses_existing_empty_root(self):
        self.configure_discovery()
        self.root['reply_count'] = 0
        self.history_more = True
        code, out, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 0, err)
        self.assertIn('Verified comment', out)
        self.assertTrue(any(m == 'conversations.history' and p.get('cursor') == 'next' for m, p, _ in self.calls))
        self.assertEqual(sum(m == 'chat.postMessage' for m, _, _ in self.calls), 1)

    def test_explicit_channel_without_configuration(self):
        self.base = self.base[:3] + ['--channel', 'C1']
        self.assertEqual(self.run_cli()[0], 0)
        self.assertIn('conversations.history', [m for m, _, _ in self.calls])

    def test_missing_mapping_never_guesses_a_channel(self):
        self.base = self.base[:3]
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('no ID will be guessed', err)
        self.assertEqual(self.calls, [])

    def test_missing_and_ambiguous_roots_refused(self):
        self.configure_discovery()
        for history, error in [([], 'No verified discussion root'), ([self.root, dict(self.root, ts='1700000009.000001')], 'Multiple discussion roots')]:
            self.history = history
            code, _, err = self.run_cli('comment', '--execute')
            self.assertEqual(code, 1)
            self.assertIn(error, err)
            self.assertNotIn('chat.postMessage', [m for m, _, _ in self.calls])

    def test_discovered_root_rechecked_before_send(self):
        self.configure_discovery()
        self.hide_root = True
        code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('root does not identify', err)
        self.assertNotIn('chat.postMessage', [m for m, _, _ in self.calls])

    def test_history_failure_refuses_send(self):
        self.configure_discovery()
        self.failure = 'conversations.history'
        self.assertEqual(self.run_cli('comment', '--execute')[0], 1)
        self.assertNotIn('chat.postMessage', [m for m, _, _ in self.calls])

    def test_history_paging_cap_refuses_send(self):
        self.configure_discovery()
        with patch.object(slack, 'paged', side_effect=slack.SlackError('more than 20 pages')):
            code, _, err = self.run_cli('comment', '--execute')
        self.assertEqual(code, 1)
        self.assertIn('more than 20 pages', err)
        self.assertNotIn('chat.postMessage', [m for m, _, _ in self.calls])

    def test_malformed_root_metadata_refused(self):
        self.configure_discovery()
        for metadata in [dict(self.root, ts=None), dict(self.root, slack_list=['F1', 'Rec1']), dict(self.root, thread_ts='1700000099.000001')]:
            self.history = [metadata]
            self.assertEqual(self.run_cli('comment', '--execute')[0], 1)
        self.assertNotIn('chat.postMessage', [m for m, _, _ in self.calls])

    def test_bad_or_conflicting_configured_channels_refused(self):
        self.configure_discovery()
        for entries in [[{'id': 'F1', 'discussion_channel_id': ['C1']}], [{'id': 'F1', 'discussion_channel_id': 'C1'}, {'id': 'F1', 'discussion_channel_id': 'C2'}]]:
            self.acct['lists'] = entries
            self.assertEqual(self.run_cli('comment', '--execute')[0], 1)
        self.assertEqual(self.calls, [])


class ConversationReadsTest(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.responses = {}
        self.acct = {'alias': 'work', 'team_id': 'T1', 'user_id': 'U1'}
        for patcher in (patch.object(slack, 'account', return_value=self.acct), patch.object(slack, 'call', side_effect=self.call)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def call(self, acct, method, params=None, json_body=False):
        self.calls.append((method, params or {}))
        self.assertIn(method, ('auth.test', 'conversations.list', 'conversations.members', 'conversations.history', 'search.messages', 'chat.getPermalink'))
        response = self.responses.get(method, {'team_id': 'T1', 'user_id': 'U1'} if method == 'auth.test' else {})
        if isinstance(response, Exception):
            raise response
        return response(params or {}) if callable(response) else response

    def run_cli(self, command, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = slack.main([command, 'work', *args])
        return code, out.getvalue(), err.getvalue()

    def test_discovery_pages_and_filters_existing_dm_and_group(self):
        self.responses['conversations.list'] = lambda p: ({'channels': [{'id': 'D1', 'is_im': True, 'user': 'U2'}, {'id': 'D2', 'is_im': True, 'user': 'U3'}], 'response_metadata': {'next_cursor': 'next'}} if not p.get('cursor') else {'channels': [{'id': 'G1', 'is_mpim': True, 'name': 'group'}, {'id': 'C1', 'name': 'general'}]})
        self.responses['conversations.members'] = {'members': ['U1', 'U2']}
        code, out, err = self.run_cli('conversations', '--types', 'im,mpim', '--user', 'U2')
        self.assertEqual(code, 0, err)
        self.assertIn('DM with U2 | id: D1', out)
        self.assertIn('group DM group | id: G1', out)
        self.assertNotIn('D2', out)
        self.assertNotIn('#general', out)
        self.assertEqual(self.calls[1][1]['types'], 'im,mpim')
        self.assertEqual(self.calls[2][1]['cursor'], 'next')

    def test_discovery_refuses_partial_results(self):
        self.responses['conversations.list'] = {'channels': [], 'has_more': True}
        code, out, err = self.run_cli('conversations')
        self.assertEqual(code, 1)
        self.assertEqual(out, '')
        self.assertIn('without a cursor', err)

    def test_history_bounds_cursor_thread_metadata_and_end(self):
        self.responses['conversations.history'] = {'messages': [{'ts': '1700000001.000001', 'user': 'U2', 'text': 'hello', 'reply_count': 2}], 'has_more': True, 'response_metadata': {'next_cursor': 'older'}}
        code, out, err = self.run_cli('history', '--channel', 'D1', '--limit', '20', '--cursor', 'start', '--oldest', '1700000000', '--latest', '1800000000', '--inclusive')
        self.assertEqual(code, 0, err)
        self.assertIn('Next cursor: older', out)
        self.assertIn('replies: 2', out)
        self.assertEqual(self.calls[-1][1], {'channel': 'D1', 'limit': 20, 'cursor': 'start', 'oldest': '1700000000', 'latest': '1800000000', 'inclusive': 'true'})
        self.responses['conversations.history'] = {'messages': []}
        self.assertIn('End of accessible history', self.run_cli('history', '--channel', 'D1')[1])

    def test_history_refuses_missing_cursor(self):
        self.responses['conversations.history'] = {'messages': [{'text': 'hidden partial'}], 'has_more': True}
        code, out, err = self.run_cli('history', '--channel', 'D1')
        self.assertEqual(code, 1)
        self.assertEqual(out, '')
        self.assertIn('narrow the time range', err)

    def test_search_page_and_permalink(self):
        self.responses['search.messages'] = {'messages': {'total': 30, 'paging': {'pages': 3}, 'matches': [{'channel': {'id': 'D1', 'name': 'U2'}, 'ts': '1700000001.000001', 'user': 'U2', 'text': 'hello', 'permalink': 'https://example.slack.com/actual-link'}]}}
        code, out, err = self.run_cli('search', 'from:<@U2>', '--page', '2', '--limit', '10')
        self.assertEqual(code, 0, err)
        self.assertIn('page 2 of 3; total 30', out)
        self.assertIn('https://example.slack.com/actual-link', out)
        self.assertEqual(self.calls[-1][1], {'query': 'from:<@U2>', 'count': 10, 'page': 2, 'sort': 'timestamp', 'sort_dir': 'desc', 'highlight': 'false'})
        self.responses['chat.getPermalink'] = {'permalink': 'https://example.slack.com/actual-link'}
        self.assertEqual(self.run_cli('permalink', '--channel', 'D1', '--ts', '1700000001.000001')[1].strip(), 'https://example.slack.com/actual-link')

    def test_missing_scope_reported_once_without_writes(self):
        for command, method, args in [('search', 'search.messages', ['hello']), ('history', 'conversations.history', ['--channel', 'D1']), ('conversations', 'conversations.list', [])]:
            self.calls.clear()
            self.responses[method] = slack.SlackError('missing_scope (needed: read-scope)')
            code, _, err = self.run_cli(command, *args)
            self.assertEqual(code, 1)
            self.assertIn('needed: read-scope', err)
            self.assertEqual(sum(m == method for m, _ in self.calls), 1)

    def test_identity_mismatch_blocks_content_reads(self):
        self.responses['auth.test'] = {'team_id': 'T2', 'user_id': 'U1'}
        self.assertEqual(self.run_cli('history', '--channel', 'D1')[0], 1)
        self.assertEqual([m for m, _ in self.calls], ['auth.test'])

    def test_argument_bounds_before_api_calls(self):
        for args in (['history', 'work', '--channel', 'D1', '--limit', '0'], ['search', 'work', 'hello', '--page', '101'], ['conversations', 'work', '--types', 'invalid']):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                slack.main(args)
        self.assertEqual(self.calls, [])


if __name__ == '__main__':
    unittest.main()
