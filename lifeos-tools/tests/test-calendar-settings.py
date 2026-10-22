#!/usr/bin/env python3
"""Offline calendar settings tests; synthetic events only, with all transport stubbed."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
HELPER = TOOL / 'lib/google-calendar-write.py'


class BuilderTest(unittest.TestCase):
    def build(self, *args):
        return subprocess.run([sys.executable, str(HELPER), 'build-event', *args], capture_output=True, text=True)

    def verify(self, expected, event):
        return subprocess.run([sys.executable, str(HELPER), 'verify-settings'], input=json.dumps({'expected': expected, 'event': event}), capture_output=True, text=True)

    def test_defaults_omitted(self):
        result = self.build('--title', 'Example event', '--start', '2030-01-02')
        self.assertEqual(result.returncode, 0, result.stderr)
        body = json.loads(result.stdout)
        self.assertNotIn('transparency', body)
        self.assertNotIn('reminders', body)

    def test_transparency_only_patch_both_values(self):
        for value in ('transparent', 'opaque'):
            result = self.build('--transparency', value)
            self.assertEqual(json.loads(result.stdout), {'transparency': value})

    def test_popup_zero_and_upper_bound(self):
        for minutes in (0, 40320):
            result = self.build('--popup-minutes', str(minutes))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': minutes}]}})

    def test_invalid_options(self):
        for args in (('--transparency', 'free'), ('--popup-minutes', '-1'), ('--popup-minutes', '40321'), ('--popup-minutes', '1.5'), ('--popup-minutes', 'no')):
            result = self.build(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')

    def test_recurrence_and_timed_fields_preserved(self):
        result = self.build('--title', 'Example event', '--start', '2030-01-02T09:00', '--tz', 'Etc/UTC', '--recurrence', 'RRULE:FREQ=WEEKLY;BYDAY=WE', '--transparency', 'transparent', '--popup-minutes', '0')
        body = json.loads(result.stdout)
        self.assertEqual(body['start']['timeZone'], 'Etc/UTC')
        self.assertEqual(body['end']['dateTime'], '2030-01-02T10:00:00')
        self.assertEqual(body['recurrence'], ['RRULE:FREQ=WEEKLY;BYDAY=WE'])
        self.assertEqual(body['transparency'], 'transparent')

    def test_verification_accepts_documented_busy_default(self):
        result = self.verify({'transparency': 'opaque'}, {})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Busy', result.stdout)
        self.assertNotEqual(self.verify({'transparency': 'transparent'}, {}).returncode, 0)

    def test_popup_readback_checks_override_and_defaults(self):
        expected = {'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 0}]}}
        self.assertEqual(self.verify(expected, expected).returncode, 0)
        for event in ({}, {'reminders': {'useDefault': True}}, {'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 5}]}}, {'reminders': {'useDefault': False, 'overrides': [{'method': 'email', 'minutes': 0}]}}):
            self.assertNotEqual(self.verify(expected, event).returncode, 0)


SHELL = r'''
set -e
SCRIPT_DIR="$TEST_TOOL"
LIB_DIR="$TEST_TOOL/lib"
export LIFEOS_CALENDAR_WRITABLE_IDS=primary
. "$LIB_DIR/common.sh"
. "$LIB_DIR/google.sh"
LIFEOS_PY="$TEST_PY"
_calendar_token_ready() { :; }
_calendar_access_token() { echo 'FAIL: network authentication must never run in this test' >&2; return 1; }
_calendar_write() {
    printf '%s' "$1 $2" > "$TEST_DIR/write-endpoint"
    printf '%s' "$3" > "$TEST_DIR/body.json"
    printf '%s' '{"id":"synthetic-event","htmlLink":"https://example.invalid/event"}'
}
_calendar_get() {
    printf '%s\n' "$1" >> "$TEST_DIR/reads"
    if [ -f "$TEST_DIR/body.json" ]; then
        [ "$TEST_MODE" != fail ] || return 1
        "$LIFEOS_PY" - "$TEST_DIR/body.json" "$TEST_MODE" "$1" <<'PY_STUB'
import json, sys
body = json.load(open(sys.argv[1]))
event = {'id': sys.argv[3].rsplit('/', 1)[-1], 'summary': 'Example event', 'transparency': 'opaque', 'reminders': {'useDefault': True}}
event.update(body)
mode = sys.argv[2]
if mode == 'mismatch': event['transparency'] = 'opaque'
if mode == 'popup-mismatch': event['reminders'] = {'useDefault': True}
if mode == 'wrong-id': event['id'] = 'other-event'
if mode == 'omit-default': event.pop('transparency', None)
print(json.dumps(event))
PY_STUB
    else
        printf '%s' '{"id":"synthetic-event","summary":"Example event","recurringEventId":"synthetic-series","transparency":"transparent","reminders":{"useDefault":true}}'
    fi
}
command="$1"; shift
if [ "$command" = create ]; then
    _calendar_create_event --title 'Example event' --start 2030-01-02T09:00 --tz Etc/UTC "$@"
else
    _calendar_update_event --event synthetic-event "$@"
fi
'''


class ShellTest(unittest.TestCase):
    def run_cli(self, command, *args, mode='ok'):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, TEST_DIR=directory, TEST_TOOL=str(TOOL), TEST_PY=sys.executable, TEST_MODE=mode)
            result = subprocess.run(['/bin/bash', '-c', SHELL, 'calendar-test', command, *args], env=env, capture_output=True, text=True)
            root = Path(directory)
            body = json.loads((root/'body.json').read_text()) if (root/'body.json').exists() else None
            endpoint = (root/'write-endpoint').read_text() if (root/'write-endpoint').exists() else ''
            reads = (root/'reads').read_text().splitlines() if (root/'reads').exists() else []
            return result, body, endpoint, reads

    def test_dry_run_no_write_or_verification_fetch(self):
        for command in ('create', 'update'):
            result, body, _, reads = self.run_cli(command, '--transparency', 'transparent', '--popup-minutes', '0')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIsNone(body)
            self.assertIn('DRY RUN', result.stdout)
            self.assertEqual(len(reads), 0 if command == 'create' else 1)
            self.assertIn('transparent', result.stdout)

    def test_create_serialization_readback_and_no_attendee_email(self):
        result, body, endpoint, reads = self.run_cli('create', '--transparency', 'transparent', '--popup-minutes', '0', '--execute')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(body['transparency'], 'transparent')
        self.assertEqual(body['reminders']['overrides'], [{'method': 'popup', 'minutes': 0}])
        self.assertEqual(endpoint, 'POST /calendars/primary/events?sendUpdates=none')
        self.assertEqual(reads, ['/calendars/primary/events/synthetic-event'])
        self.assertIn('Verified transparency: transparent (Free)', result.stdout)
        self.assertIn('Verified popup reminder: 0', result.stdout)

    def test_update_settings_only_does_not_touch_times_or_title(self):
        result, body, endpoint, reads = self.run_cli('update', '--transparency', 'opaque', '--popup-minutes', '0', '--execute')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(body), {'transparency', 'reminders'})
        self.assertIn('PATCH /calendars/primary/events/synthetic-event?', endpoint)
        self.assertEqual(len(reads), 2)
        self.assertIn('Busy', result.stdout)

    def test_omitted_options_preserve_default_behavior(self):
        for command, args in (('create', []), ('update', ['--title', 'Changed example'])):
            result, body, _, reads = self.run_cli(command, *args, '--execute')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('transparency', body)
            self.assertNotIn('reminders', body)
            self.assertEqual(len(reads), 0 if command == 'create' else 1)

    def test_explicit_notify_remains_separate_from_popup(self):
        result, _, endpoint, _ = self.run_cli('create', '--popup-minutes', '0', '--notify', '--execute')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(endpoint.endswith('sendUpdates=all'))

    def test_partial_readback_failures_not_reported_as_success(self):
        for command in ('create', 'update'):
            for mode in ('mismatch', 'fail', 'wrong-id', 'popup-mismatch'):
                result, body, endpoint, _ = self.run_cli(command, '--transparency', 'transparent', '--popup-minutes', '0', '--execute', mode=mode)
                self.assertNotEqual(result.returncode, 0, (command, mode, result.stdout))
                self.assertIn('PARTIAL', result.stderr)
                self.assertIsNotNone(body)
                self.assertIn('events', endpoint)

    def test_busy_default_can_be_omitted_by_api(self):
        result, _, _, _ = self.run_cli('create', '--transparency', 'opaque', '--execute', mode='omit-default')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Verified transparency: opaque (Busy)', result.stdout)

    def test_invalid_arguments_never_write(self):
        for command in ('create', 'update'):
            for args in (['--transparency', 'invalid'], ['--popup-minutes', '-1'], ['--popup-minutes', '40321']):
                result, body, _, _ = self.run_cli(command, *args, '--execute')
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(body)

    def test_series_update_reads_back_master(self):
        result, body, endpoint, reads = self.run_cli('update', '--series', '--transparency', 'transparent', '--execute')
        self.assertIn('/events/synthetic-series?', endpoint)
        self.assertEqual(reads[-1], '/calendars/primary/events/synthetic-series')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Verified transparency', result.stdout)


if __name__ == '__main__':
    unittest.main()
