# Configs agent policy index
The user approved these five project-owned policies and their migration on 2026-11-21 (D19). Adopted policies govern agents within their stated scopes; package updates, structural checks and this index do not grant service or publication permissions. [Migration evidence](../archive/agent-policy-migration.md) records the obligation mapping and retained owners.

<!-- agent-policies:start -->
| ID | Policy | Type | Scope | Status | Revised |
| --- | --- | --- | --- | --- | --- |
| ADOPT-POLICIES | [Adopt agent policies explicitly](_ADOPT-POLICIES-require-explicit-adoption.md) | kernel | Agent treatment of policy obligations, skill procedures and local policy decisions. | adopted | 2026-11-21 |
| PRESERVE-IDENTITY | [Preserve obligation identity](_PRESERVE-IDENTITY-retain-meaning-and-history.md) | kernel | Agent policy identity, record metadata, change history and retirement. | adopted | 2026-11-21 |
| RESOLVE-DEPENDENCIES | [Resolve prerequisites before loading](_RESOLVE-DEPENDENCIES-load-prerequisites-once.md) | kernel | Agent discovery and loading of applicable adopted policy prerequisites. | adopted | 2026-11-21 |
| BOUND-COMMITS | [Preserve scoped local checkpoints](BOUND-COMMITS-preserve-scoped-local-checkpoints.md) | operational | Agent Git checkpoints, history changes and publication in configs. | adopted | 2026-11-21 |
| PROTECT-SECRETS | [Keep private inputs out of Git](PROTECT-SECRETS-keep-private-inputs-out-of-git.md) | operational | Agent handling of secrets, private configuration and public content in configs. | adopted | 2026-11-21 |
<!-- agent-policies:end -->

## Retired numeric identities
The user approved retirement of these numeric agent-policy identities on 2026-11-21 under D19. Their IDs remain reserved and their exact original sources remain historical, not operative prerequisites. Human secrets/setup guidance stays in `docs/policies/`.

| Legacy ID | Historical record | Replacement | Status | Retired |
| --- | --- | --- | --- | --- |
| 0001 | [Original secrets policy](../archive/agent-policy-retirements/0001-secrets-and-local-env.md) | PROTECT-SECRETS | retired | 2026-11-21 |
| 0003 | [Original commit policy](../archive/agent-policy-retirements/0003-agent-commit-policy.md) | BOUND-COMMITS | retired | 2026-11-21 |
