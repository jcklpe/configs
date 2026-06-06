# 0001 Secrets And Local Env Hygiene

## Context

This repo is a personal dotfiles and setup repo that may be public. It has historically managed shell, editor, terminal, installer, and symlink config without much secret-bearing local state.

LifeOS tooling needs API keys, OAuth credentials, OAuth tokens, and local private paths. Those values need to be available to local scripts, but they must not be committed.

## Decision

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

## Consequences

This keeps the workflow simple and portable: local secrets can travel with the local checkout on a machine, while git only sees public-safe source, docs, examples, and templates.

The main risk is accidental tracking. Mitigate that by adding ignore rules before creating real files, committing fake examples, and checking `git status --short` before commits.

If a secret is committed, assume it is compromised and rotate it. Removing it from the working tree is not enough.

## Links

- [AGENTS.md](../../AGENTS.md)
- [TODO.md](../../TODO.md)
- [Archived secrets/env spike](../archive/secrets-env.md)
