# TODO

This file is the coordination map for active work in this repo. Keep detailed thinking in spike docs, decisions, or scratch notes; keep this file short enough to scan.

## Active Spikes

- None.

## Scratch / Future

- LifeOS tools v2 ideas: `docs/scratch/lifeos-tools-v2.md`, `docs/scratch/lifeos-tools-v2.todo.md`
- LifeOS Bitwarden cleanup (parked): `docs/scratch/lifeos-bitwarden.md`, `docs/scratch/lifeos-bitwarden.todo.md`

## Recently Shipped

- LifeOS Google Calendar writes: `calendar create-event` / `update-event` (dry-run by default, writable-calendar allowlist, no delete), attendee invites with layered name resolution (alias map → People API) and a `people` command group, single-occurrence-vs-`--series` edits. Recorded in `docs/decisions/0002-lifeos-calendar-writes.md`. First live `--execute` write was a real vault-agent task (no separate smoke test run).

## Next

- Decide when a `docs/runbooks/` folder is useful enough to create.
- Decide whether any remaining `docs/scratch/lifeos-tools-v2.md` theme (Trello write-safety pass, Drive read expansion, read-only `calendar find`, setup helper, agent wrapper) should become an active spike. Calendar writes are now done.

## Waiting For Human QA

- None.

## Later

- New-machine runbooks for macOS, Fedora, NixOS, and WSL.
- Shell recovery runbook for broken startup config.
- Leaked-secret rotation runbook if CLI tools start depending on API credentials.
- Decision record for where personal CLI tools should live in this repo.

## Notes

- Finished LifeOS v1 spike history lives in `docs/archive/lifeos-tools.md`, `docs/archive/lifeos-tools.todo.md`, `docs/archive/lifeos-google-sources.md`, and `docs/archive/lifeos-google-sources.todo.md`.
- Use `docs/how-to-spike.md` for spike workflow.
- Use `docs/scratch/` for rough, non-authoritative notes.
- Use `docs/archive/` for finished spike history.
- Use `docs/decisions/` for durable tradeoffs and settled repo direction.
- Secrets/local env hygiene is recorded in `docs/decisions/0001-secrets-and-local-env.md`.
- LifeOS calendar writes and attendee resolution are recorded in `docs/decisions/0002-lifeos-calendar-writes.md`.
