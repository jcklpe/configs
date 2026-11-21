---
attention: historical
---
# Retain legacy 0001 policy history
Retired 2026-11-21 by the user’s explicit D19 approval. The agent obligation is consolidated into the adopted mnemonic policy; the original source is preserved below. Legacy identity `0001` remains reserved. The replacement obligation is [PROTECT-SECRETS](../../agent-policies/PROTECT-SECRETS-keep-private-inputs-out-of-git.md).

Original source: `docs/policies/0001-secrets-and-local-env.md`. Exact original SHA-256: `830946b9ae6d79c11d42dc4d7e538e871e74b7f0b0a09f304d3bc7cbf6af9a1e`. The literal block preserves the complete original source.

````markdown
# 0001 Secrets And Local Env Hygiene
## Current Approach
Use a personal dotfiles tool hygiene pattern:

- Real secret-bearing files may live inside the local `configs/` working tree.
- Real secret-bearing files must be ignored before they are created or used.
- Tracked example files with fake values should sit next to the real files.
- Future tools should define their own exact local files and ignore rules as part of the same change that introduces the tool.

Preferred adjacent-file pattern:

```text
configs/
  some-tool/
    tool.sh
    .env.example              # tracked fake values
    .env                      # ignored real values
    google-token.example.json # tracked fake values
    google-token.json         # ignored real values
    config.example.json       # tracked fake values/placeholders, if useful
    config.json               # tracked only if public; ignored per-tool if private
```

If a `secrets/` folder is useful for a tool, use a default-deny ignore pattern that still allows tracked example files. Do not blanket-ignore examples away from git.

Do not load secrets from global shell startup by default. Tools should load their own env/config at runtime, or a shell module should make any secret-loading behavior explicit.

## Rationale
This public-safe dotfiles and setup repository also carries tools that need API credentials, tokens, and private local configuration. Adjacent ignored real files and tracked fake examples make those tools usable after cloning without publishing local secrets.

## Operating Notes
This keeps the workflow simple and portable: local secrets can travel with the local checkout on a machine, while git only sees public-safe source, docs, examples, and templates.

The main risk is accidental tracking. Mitigate that by adding ignore rules before creating real files, committing fake examples, and checking `git status --short` before commits.

If a secret is committed, assume it is compromised and rotate it. Removing it from the working tree is not enough.

## Links
- [AGENTS.md](../../AGENTS.md)
- [TODO.md](../../TODO.md)
- [Archived secrets/env spike](../archive/secrets-env.md)
````
