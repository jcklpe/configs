# LifeOS Google Sources To-Do

Status: archived. Gmail and Drive v1 are implemented; future ergonomics have been moved to `docs/scratch/lifeos-tools-v2.md`.

Conceptual doc: `docs/archive/lifeos-google-sources.md`.

## Background

LifeOS needs stable local access to Gmail and Google Drive context across multiple Google accounts. Hosted connectors are useful, but they are platform-dependent and account-limited. `lifeos-tools` should provide a cross-agent local CLI surface.

Gmail and Drive should not use the same shape:

- Gmail: bounded generated Markdown snapshots.
- Drive: on-demand search/inspect/read commands.

## Project Organization

Planned config/example files:

```text
lifeos-tools/
  google-accounts.example.json
  google-accounts.json
  google-personal-token.json
  google-professional-token.json
  google-open-austin-token.json
  google-ut-token.json
```

Tracked files:

```text
lifeos-tools/google-accounts.example.json
```

Ignored local files:

```text
lifeos-tools/google-accounts.json
lifeos-tools/google-*-token.json
```

Generated Gmail outputs should go under the private LifeOS vault:

```text
$LIFEOS_VAULT_PATH/sources/gmail/
```

Generated QA/debug snapshots in `lifeos-tools/` should be ignored before they are created.

## General Principles

- Keep all Google account tooling read-only for this spike.
- Prefer explicit account aliases over raw email addresses in commands.
- Keep OAuth token files per account alias.
- Keep Gmail sync bounded by query, count, and body size.
- Keep Drive on-demand and bounded.
- Do not clone or recursively index Drive.
- Do not write auth/config material into the LifeOS vault.
- Add example files with fake values before requiring real local setup.

## Current State Overview

- Trello and Calendar live under the existing `lifeos-tools` spike.
- Calendar already has Google OAuth helpers and a read-only sync flow.
- Google account alias commands are implemented.
- Gmail snapshot commands are implemented and have passed live QA for `personal`, `professional`, and `open-austin`.
- Drive search/meta/read commands are implemented and Drive search smoke QA has passed for `personal`, `professional`, and `open-austin`.
- `lifeos-tools/.gitignore` now explicitly ignores `google-accounts.json` and likely Gmail/Drive QA outputs.
- `lifeos-tools/google-accounts.example.json` now documents the planned alias config shape with fake values.

## To Do

- None for this archived v1 spike.

## Ready For Human QA

- None. User confirmed the LifeOS agent can use the CLI tools successfully.

## Done

- Discussed Gmail versus Drive shape: Gmail snapshots, Drive on-demand connector.
- Settled Gmail default query direction: `in:inbox newer_than:30d`.
- Settled Gmail default max result direction: 150 messages per account.
- Clarified that Google API "export" means read/fetch of Google-native files, not cloning Drive content into LifeOS.
- Confirmed Google Sheets should be part of early Drive read support because Open Austin work often uses Sheets.
- Created this active spike doc pair.
- Added `google-accounts.example.json` with fake alias config.
- Added explicit ignore rules for real Google account alias config and Gmail/Drive QA output.
- Added ignored local `google-accounts.json` scaffold for `personal`, `professional`, `open-austin`, and disabled future `ut`.
- Added `GOOGLE_ACCOUNTS_PATH` to `.env.example`.
- Added generic `google-oauth.py` for per-alias read-only Google OAuth tokens.
- Implemented `lifeos google accounts`.
- Implemented `lifeos google auth ALIAS`.
- Implemented `lifeos gmail sync ALIAS`.
- Implemented `lifeos gmail sync --all`.
- Implemented Gmail `--qa` output under ignored `lifeos-tools/gmail-qa/`.
- Implemented Gmail Markdown rendering with cleaned plain text/HTML bodies and body caps.
- Implemented `lifeos drive accounts`.
- Implemented `lifeos drive search ALIAS QUERY`.
- Implemented `lifeos drive list ALIAS FOLDER_ID`.
- Implemented `lifeos drive meta ALIAS FILE_URL_OR_ID`.
- Implemented `lifeos drive read ALIAS FILE_URL_OR_ID` for Google Docs text.
- Implemented bounded Google Sheets range/table previews.
- Added `--json` to Drive search/list/meta.
- Updated `lifeos doctor` to check alias config and token presence without printing secrets.
- Updated `lifeos-tools/README.md`.
- Updated `lifeos-tools/AGENT.md`; the LifeOS runbook symlink points at this file.
- Added fixture tests for Gmail and Sheets render helpers.
- Fixture coverage includes basic Gmail plain text, HTML cleanup, labels/IDs, attachment presence, and basic Sheets rendering.
- Enabled the needed Google APIs/scopes for personal and professional QA.
- Authenticated `personal`.
- Live QA passed for `lifeos gmail sync personal --qa`.
- Live Drive search smoke QA passed for `personal`.
- Authenticated `professional`.
- Live QA passed for `lifeos gmail sync professional --qa`.
- Live Drive search smoke QA passed for `professional`.
- Enabled the needed Google APIs/scopes for Open Austin QA.
- Authenticated `open-austin`.
- Live QA passed for `lifeos gmail sync open-austin --qa`.
- Live Drive search smoke QA passed for `open-austin`.
- Live all-account QA passed for `lifeos gmail sync --all --qa`.
- Live all-account sync wrote Gmail snapshots to `$LIFEOS_VAULT_PATH/sources/gmail/`.
