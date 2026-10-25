#!/usr/bin/env bash
##- Old workflow commands must stop before loading config, dependencies, or source data.
set -eu
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-retired-sync.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cp "$TOOL_DIR/lifeos.sh" "$WORK/lifeos.sh"
mkdir "$WORK/secrets"
printf '%s\n' 'DO_NOT_LOAD=$(touch "$POISON_MARKER")' > "$WORK/secrets/.env"
export POISON_MARKER="$WORK/config-was-loaded"
# The isolated copy has no lib or provider packages: these paths must work without them.
check() {
    local status=0
    bash "$WORK/lifeos.sh" "$@" > "$WORK/out" 2> "$WORK/err" || status=$?
    [ "$status" -eq 2 ] || { cat "$WORK/err"; echo "wrong exit: $status"; exit 1; }
    [ ! -s "$WORK/out" ] || { echo 'unexpected success output'; exit 1; }
    grep -F 'no sources were refreshed' "$WORK/err" >/dev/null
    grep -F 'operate-lifeos' "$WORK/err" >/dev/null
    grep -F 'render-calendar-agenda' "$WORK/err" >/dev/null
    if grep -E 'No such file|not found|unbound variable' "$WORK/err"; then exit 1; fi
    [ ! -e "$POISON_MARKER" ] || { echo 'loaded credentials'; exit 1; }
    [ "$(cat "$WORK/existing.md")" = 'previous snapshot' ] || { echo 'changed output'; exit 1; }
}
printf '%s\n' 'previous snapshot' > "$WORK/existing.md"
check sync
check sync --all --output "$WORK/existing.md"
check calendar sync
check calendar sync --google-only --qa --output "$WORK/existing.md"
printf '%s\n' 'PASS: retired routes stop before dependencies/config and preserve snapshots'
