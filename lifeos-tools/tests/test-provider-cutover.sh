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
printf 'M365_ACCOUNTS_PATH="accounts.json"\n' > "$WORK/.env"
printf '{"accounts":[{"alias":"fixture","auth_provider":"graph-powershell","expected_account":"reader@example.invalid","mail":{"enabled":true},"calendar":{"enabled":true},"contacts":{"enabled":true},"planner":{"enabled":true,"plans":[{"id":"plan-1"}]}}]}\n' > "$WORK/accounts.json"
M365_CONFIG_DIR="$WORK" bash "$ROOT/lifeos-tools/lifeos.sh" m365 accounts > "$WORK/microsoft.out"
grep -F 'fixture' "$WORK/microsoft.out" >/dev/null
for domain in mail calendar contacts planner; do
    if M365_CONFIG_DIR="$WORK" M365_PYTHON=python3 bash "$ROOT/lifeos-tools/lifeos.sh" m365 "$domain" sync fixture > "$WORK/fail.out" 2>&1; then
        echo "Unexpected Microsoft export success without destination: $domain" >&2; exit 1
    fi
    grep -F -- 'output' "$WORK/fail.out" >/dev/null || { cat "$WORK/fail.out" >&2; exit 1; }
done
printf 'GOOGLE_ACCOUNTS_PATH="accounts.json"\n' > "$WORK/.env"
printf '{"accounts":[{"alias":"fixture","credentials_path":"absent.json","token_path":"absent-token.json","gmail":{"enabled":true},"drive":{"enabled":true,"index_exclude":[]},"calendar":{"enabled":true}}]}\n' > "$WORK/accounts.json"
GOOGLE_CONFIG_DIR="$WORK" bash "$ROOT/lifeos-tools/lifeos.sh" google accounts > "$WORK/google.out"
grep -F 'fixture' "$WORK/google.out" >/dev/null
for domain in gmail drive; do
    if GOOGLE_CONFIG_DIR="$WORK" GOOGLE_PYTHON=python3 bash "$ROOT/lifeos-tools/lifeos.sh" "$domain" sync fixture > "$WORK/fail.out" 2>&1; then
        echo "Unexpected Google export success without destination: $domain" >&2; exit 1
    fi
    grep -F -- 'output' "$WORK/fail.out" >/dev/null
done
if GOOGLE_CONFIG_DIR="$WORK" bash "$ROOT/lifeos-tools/lifeos.sh" gmail sync --all > "$WORK/fail.out" 2>&1; then exit 1; fi
grep -F 'retired' "$WORK/fail.out" >/dev/null
for command in setup doctor open context 'people list-aliases' 'people add-alias'; do
    # This fixture deliberately splits a fixed literal command list under Bash.
    if bash "$ROOT/lifeos-tools/lifeos.sh" $command > "$WORK/fail.out" 2>&1; then exit 1; fi
    grep -E 'retired|operate-lifeos' "$WORK/fail.out" >/dev/null
done
printf 'PASS: selected provider configuration and explicit export destinations\n'
