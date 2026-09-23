#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$(dirname "$TEST_DIR")"
LIB_DIR="$CONFIGS/lib"
ENV_FILE="$CONFIGS/.env.test"
export SCRIPT_DIR="$CONFIGS"
export TMPDIR="$(mktemp -d)"
touch "$ENV_FILE"

source "$LIB_DIR/common.sh"

test_dir="$(mktemp -d)"
# Use a custom cleanup for the test harness so it doesn't conflict with the tested trap
cleanup_test() {
    rm -rf "$test_dir"
}
trap cleanup_test EXIT HUP INT TERM

out_file="$test_dir/snapshot.md"
echo "old snapshot" > "$out_file"

# Test 1: Successful atomic write
(
    source "$LIB_DIR/common.sh"
    tmp_out="$(mktemp "$(dirname "$out_file")/.$(basename "$out_file").XXXXXX")"
    _register_temp_file "$tmp_out"
    echo "new snapshot" > "$tmp_out"
    mv "$tmp_out" "$out_file"
)
if [ "$(cat "$out_file")" != "new snapshot" ]; then
    echo "FAIL: file not replaced"
    exit 1
fi
# Check for any remaining hidden temp files
temp_remains="$(find "$test_dir" -name '.*.XXXXXX*' | wc -l)"
if [ "$temp_remains" -ne 0 ]; then
    echo "FAIL: temp files left behind on success"
    exit 1
fi

echo "old snapshot" > "$out_file"

# Test 2: Failure before replacement
(
    source "$LIB_DIR/common.sh"
    tmp_out="$(mktemp "$(dirname "$out_file")/.$(basename "$out_file").XXXXXX")"
    _register_temp_file "$tmp_out"
    echo "new snapshot" > "$tmp_out"
    # simulate failure
    exit 1
) || true

if [ "$(cat "$out_file")" != "old snapshot" ]; then
    echo "FAIL: old snapshot replaced on failure"
    exit 1
fi
temp_remains="$(find "$test_dir" -name '.*.XXXXXX*' | wc -l)"
if [ "$temp_remains" -ne 0 ]; then
    echo "FAIL: temp file left behind on failure"
    exit 1
fi

echo "PASS: atomic write helpers"
