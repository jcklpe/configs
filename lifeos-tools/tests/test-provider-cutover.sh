#!/usr/bin/env bash
# Check configuration selection and fail-before-request export behavior with isolated synthetic profiles.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/empty"
printf 'GITHUB_REPOS_PATH="repos.json"\n' > "$WORK/.env"
printf '{"repos":[{"alias":"fixture","owner":"example","repo":"demo"}]}\n' > "$WORK/repos.json"
GITHUB_CONFIG_DIR="$WORK" bash "$ROOT/lifeos-tools/lifeos.sh" github list-repos > "$WORK/repos.out"
grep -F 'fixture | example/demo' "$WORK/repos.out" >/dev/null
printf 'ODOO_ACCOUNTS_PATH="accounts.json"\n' > "$WORK/.env"
printf '{"accounts":[{"alias":"fixture","base_url":"https://example.invalid","api_key_env":"ODOO_API_KEY"}]}\n' > "$WORK/accounts.json"
ODOO_CONFIG_DIR="$WORK" bash "$ROOT/lifeos-tools/lifeos.sh" odoo accounts > "$WORK/accounts.out"
grep -F 'fixture' "$WORK/accounts.out" >/dev/null
printf 'SLACK_ACCOUNTS_PATH="accounts.json"\n' > "$WORK/.env"
printf '{"accounts":[{"alias":"fixture","team_id":"T1","user_id":"U1","token_env":"SLACK_TOKEN"}]}\n' > "$WORK/accounts.json"
SLACK_ENV_FILE="$WORK/.env" SLACK_PYTHON=python3 bash "$ROOT/lifeos-tools/lifeos.sh" slack accounts > "$WORK/slack.out"
grep -F 'fixture' "$WORK/slack.out" >/dev/null
for service in trello github slack; do
    if TRELLO_CONFIG_DIR="$WORK/empty" GITHUB_CONFIG_DIR="$WORK/empty" SLACK_ENV_FILE="$WORK/.env" SLACK_PYTHON=python3 bash "$ROOT/lifeos-tools/lifeos.sh" "$service" sync > "$WORK/fail.out" 2>&1; then
        echo "Unexpected success without destination: $service" >&2; exit 1
    fi
    grep -F -- '--output' "$WORK/fail.out" >/dev/null
 done
printf 'PASS: selected provider configuration and explicit export destinations\n'
