# Secrets And Local Env Scratch Spike

Status: archived. Durable lessons were folded into `AGENTS.md`, `.gitignore`, and `docs/decisions/0001-secrets-and-local-env.md`.

## Outcome

We chose a personal dotfiles tool hygiene pattern:

- Real secret-bearing files may live inside the local `configs/` working tree.
- Real files must be ignored before they are created or used.
- Fake example files should be committed next to the real files they document.
- Future tools should add their required ignore rules and examples as part of the same change.
- Global shell startup should not automatically load secrets by default.

Preferred shape:

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

## Original Question

How should this public dotfiles repo support tools that need secrets or private local configuration without committing secrets, credentials, tokens, generated personal data, or machine-specific private state?

## Notes

LifeOS tooling triggered this spike, but the resulting rule is repo-wide. The LifeOS spike should define its exact `.env`, token, and config file names later.

If a secret is committed, assume it is compromised, rotate it in the upstream service, remove it from the repo, and strengthen the relevant ignore rules.
