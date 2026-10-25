# Legacy service compatibility
Portable service implementations now live in [Agent Hands](../agent-hands/README.md). This directory retains the `lifeos` command spelling and small adapters while callers migrate. New installations should use [setup-agent-hands](../agent-hands/skills/setup-agent-hands/SKILL.md) and the selected provider/capability skills.

## Configuration ownership
Compatibility and portable commands use the same adjacent ignored provider `.env` and account files. Each service owns its uv environment and audit/recovery output. No service command reads the old `secrets/.env`, requires a vault path, or uses the former shared Python environment. Existing credential files may remain ignored recovery copies; do not edit them expecting active commands to change. Never commit actual configuration, tokens, audit records, or exports.

Migration preserves account identities, OAuth grants, resource allowlists, operation bounds, and write safeguards. PowerShell identity checks require `expected_account` while its protected token cache stays SDK-owned. Google Calendar can retain a separate profile/token from mail and files. Audit history must be separated by service without losing entries, and Planner recovery journals/locks must remain beside its audit log. Copying configuration does not prove live connectivity or authorize any external action.

## Commands and caller responsibilities
Run `bash lifeos.sh help` for current syntax and read [lifeos-cli](skills/lifeos-cli/SKILL.md) for the capability-owner map.

- Individual exports require `--output`; create the intended parent directory where the capability requires it.
- Google Calendar requires an account alias after the command. Its previous standalone source label is not an implicit credential selector.
- Calendar attendees must be full email addresses. Private nickname preferences and disambiguation belong to the caller.
- Drive compatibility exports require explicit exclusions or an explicit configured exclusion array. Exclusions skip matching top-level child samples, not arbitrary reads; `--recent 0` suppresses the separate recent-file query.
- Trello `snooze` remains a spelling of `schedule-card`, requiring an explicit list. Warning lists are caller-configured. Bidirectional links are sequential and can partially succeed; recover using the existing successor.
- No implicit private snapshot destinations, automatic mail indexes, or `--qa` paths remain. Gmail `--all` is retired; workflows select accounts and handle their results individually.

`sync`, `calendar sync`, `setup`, `doctor`, `open`, `context`, and private People alias-management commands are retired with explicit errors. Use provider setup instructions for installation/diagnosis and [operate-lifeos](../general-skills/operate-lifeos/SKILL.md) for the private workspace entrypoint. Combined agendas use explicit provider bundles and [render-calendar-agenda](../agent-hands/skills/render-calendar-agenda/SKILL.md); source coverage and availability interpretation belong to the consuming workflow.

## Verification and publication
Compatibility checks live in `tests/`; provider and capability checks live beside their owners in Agent Hands. Use offline fixtures for routing, preserved guards, failure propagation, and output preservation. Do not use actual accounts merely to smoke-test a refactor. A successful fixture is not evidence of live service access or fresh-machine onboarding.

The local modular migration is not published. Child repositories and parent pins must be published in dependency order by the user before fresh remote clones are reproducible. Agents do not push. The [active spike](../docs/active-spikes/modular-skill-distribution.todo.md) tracks remaining work and human QA.
