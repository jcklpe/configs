---
id: PROTECT-SECRETS
type: operational
scope: "Agent handling of secrets, private configuration and public content in configs."
status: proposed
authority: ""
revised: "2026-11-20"
depends_on: []
related_to: ["BOUND-COMMITS"]
---
# Keep private inputs out of Git
Never commit API keys, OAuth credentials or tokens, generated private snapshots, private local configuration, or unauthorized private source material. Review content for the public repository's audience before recording it and before committing it. Ignoring a file does not untrack it or remove earlier history.

Real secret-bearing files may live inside the local checkout only when their exact ignore rules are in place before creation or use. A tool introducing private local files must define their locations and ignore rules in the same change. Keep adjacent examples tracked with synthetic values; a default-deny secrets directory must still allow its tracked examples. Do not force-add ignored files.

Tools load their own secrets and configuration at runtime. Do not load secrets from global shell startup unless the shell module explicitly documents that behavior. Do not save private memories through a client feature that writes into the tracked global instructions.

Treat a committed secret as compromised and rotate it; deleting the working copy is insufficient. Do not claim a broader cleanup than the verified local and remote surfaces support. Follow the user's separately authorized remediation scope; this policy does not authorize deleting history, resetting credentials, or publishing changes.

Human setup examples and rationale remain in [Secrets and local environment hygiene](../policies/0001-secrets-and-local-env.md). The [Commit Work procedure](../../project-workflows/commit-work/SKILL.md) owns scoped review and recording mechanics. Tool-specific private storage and cleanup stay with their maintained owners.
