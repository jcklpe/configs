# LifeOS Microsoft 365 Mail Read — To Do
Concept: [lifeos-m365-mail-read.md](lifeos-m365-mail-read.md).

## Current State
- 2026-10-05: read and search built, tested offline, and live-checked on the UT alias. Only the optional sync scope remains, deferred until a caller needs a scratch file rather than stdout.

## To Do
- [ ] Optional: `m365 mail sync ALIAS (--folder … | --search …) --output FILE`, refused without `--output`. Deferred; `mail read` and `mail list --search` covered the first real use.

## Ready For Human QA
- `lifeos m365 mail list ut --search 'from:someone received>=2026-10-01'`, then `lifeos m365 mail read ut --message ID` on a hit in Archive or Sent Items.

## Done
- [x] Spike sketched (2026-10-05).
- [x] Decision settled as an inline amendment to 0004 (2026-10-05).
- [x] `m365 mail read ALIAS --message ID [--full] [--json]`: headers, recipients, text body, attachment names, folder, web link; any folder (2026-10-05).
- [x] Web link in `m365 mail list` output, text and `--json` (2026-10-05).
- [x] `m365 mail list ALIAS --search "KQL" [--folder …]`: mailbox-wide by default, Junk Email left out unless named, folder per hit (2026-10-05).
- [x] Offline fixture tests, mutation-checked (2026-10-05).
- [x] Live check: an archived reply and a sent reply read in full; a phrase search and a `received>=` search across Archive and Sent Items (2026-10-05).
- [x] Docs: `lifeos-m365` skill, README, `lifeos help` (2026-10-05).
