#!/usr/bin/env bash
# Compatibility route to the portable Google Docs checks.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../agent-hands" && pwd)/skills/use-google-docs/tests/test-docs-inline.sh" "$@"
