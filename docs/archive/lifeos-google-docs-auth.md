# Spike: LifeOS Google Docs Authorization
## Purpose
Let the normal LifeOS Google account-token workflow request the Google Docs write scope when a bounded tool needs to edit an existing native Google Doc, without turning permission setup into blanket authorization for Drive writes.

## Boundary
The normal Gmail and Drive alias token remains the shared credential surface. `lifeos google auth ALIAS --docs-write` uses Google's incremental authorization to add the Docs scope. The flag grants capability only; actual document edits remain owned by narrow, dry-run-first tools and their workflow-specific approval rules.

This spike does not add a generic existing-Doc edit command to `lifeos drive`.

## Validation
- Parse the affected shell files with both Bash and Zsh.
- Confirm the help and tool skills explain the difference between OAuth capability and edit authorization.
- Reauthorize the intended account and exercise an authenticated Docs read through a bounded tool before considering the permission path proven.

## Outcome
Completed 2026-07-29. `lifeos google auth ALIAS --docs-write` now adds the Google Docs scope through incremental authorization without adding a generic existing-Doc editing surface to `lifeos drive`. The personal account was reauthorized successfully, the resulting token was exercised through the bounded Open Austin Docs tool, and durable usage and authority guidance now lives in the LifeOS CLI documentation and skills.
