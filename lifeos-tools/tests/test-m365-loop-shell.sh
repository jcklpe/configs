#!/usr/bin/env bash
##- Verify the bounded Loop dispatcher uses account capability gates before launching a browser helper.
set -eu
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
. "${LIB_DIR}/m365-loop.sh"
loop_test_gate="enabled"
loop_test_write="disabled"
loop_test_calls=0
_err() { printf '%s\n' "$*" >&2; }
_m365_require_enabled() { [ "$1" = fixture ] && [ "$2" = files ] && [ "$loop_test_gate" = enabled ]; }
_m365_files_require_write() { [ "$1" = fixture ] && [ "$loop_test_write" = enabled ]; }
loop_test_python() { loop_test_calls=$((loop_test_calls + 1)); }
LIFEOS_PY=loop_test_python
_m365_loop_dispatch read fixture https://loop.cloud.microsoft/p/test
[ "$loop_test_calls" -eq 1 ]
_m365_loop_dispatch append fixture https://loop.cloud.microsoft/p/test --text preview
[ "$loop_test_calls" -eq 2 ]
if _m365_loop_dispatch append fixture https://loop.cloud.microsoft/p/test --text preview --execute; then exit 1; fi
[ "$loop_test_calls" -eq 2 ]
loop_test_write=enabled
_m365_loop_dispatch append fixture https://loop.cloud.microsoft/p/test --text preview --execute
[ "$loop_test_calls" -eq 3 ]
loop_test_gate=disabled
if _m365_loop_dispatch read fixture https://loop.cloud.microsoft/p/test; then exit 1; fi
[ "$loop_test_calls" -eq 3 ]
printf 'm365 loop shell capability gates passed\n'
