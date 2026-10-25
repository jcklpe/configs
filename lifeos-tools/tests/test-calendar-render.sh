#!/usr/bin/env bash
set -eu
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../agent-hands/skills/use-google-calendar/tests" && pwd)/test-render.sh"
