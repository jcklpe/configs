# Configs agent policy proposals
This is a review set, not an operative policy adoption. Current [project instructions](../../AGENTS.md), [secrets guidance](../policies/0001-secrets-and-local-env.md) and [commit policy](../policies/0003-agent-commit-policy.md) remain authoritative. No tool permissions, publication rights or other checkout change through these proposals.

[Migration mapping and decision boundary](../active-spikes/agent-policy-migration.md) records source fingerprints, retained owners and the routing changes that require an adoption decision. The three kernel candidates are unchanged copies of the selected shared source. The two operational candidates consolidate existing rules; PROTECT-SECRETS also makes the verification boundary for cleanup claims explicit.

<!-- agent-policies:start -->
| ID | Policy | Type | Scope | Status | Revised |
| --- | --- | --- | --- | --- | --- |
| ADOPT-POLICIES | [Adopt agent policies explicitly](_ADOPT-POLICIES-require-explicit-adoption.md) | kernel | Agent treatment of policy obligations, skill procedures and local policy decisions. | proposed | 2026-11-02 |
| PRESERVE-IDENTITY | [Preserve obligation identity](_PRESERVE-IDENTITY-retain-meaning-and-history.md) | kernel | Agent policy identity, record metadata, change history and retirement. | proposed | 2026-11-02 |
| RESOLVE-DEPENDENCIES | [Resolve prerequisites before loading](_RESOLVE-DEPENDENCIES-load-prerequisites-once.md) | kernel | Agent discovery and loading of applicable adopted policy prerequisites. | proposed | 2026-11-02 |
| BOUND-COMMITS | [Preserve scoped local checkpoints](BOUND-COMMITS-preserve-scoped-local-checkpoints.md) | operational | Agent Git checkpoints, history changes and publication in configs. | proposed | 2026-11-20 |
| PROTECT-SECRETS | [Keep private inputs out of Git](PROTECT-SECRETS-keep-private-inputs-out-of-git.md) | operational | Agent handling of secrets, private configuration and public content in configs. | proposed | 2026-11-20 |
<!-- agent-policies:end -->

Legacy identifiers `0001` and `0003` retain their current meaning. Their bodies remain in place while this set is proposed. Any later retirement must preserve their history and repair incoming links rather than reuse their identities.
