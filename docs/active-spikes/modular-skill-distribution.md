---
attention: live
opened: 2026-10-24
tags: [skills, cli, distribution, architecture]
---

# Modular Skill Distribution
Slug: `modular-skill-distribution`.

Tasks: [modular-skill-distribution.todo.md](modular-skill-distribution.todo.md).

## Status and authorization
This spike captures the user's agreed architecture and migration intent from the design discussion through 2026-10-24. The initial request authorized documentation only. A subsequent instruction on 2026-10-24 authorizes a repository privacy check, committing the spike and checkpointing the existing work to a clean tree, then beginning implementation. Complete that baseline before starting extraction. Remote publication, history rewriting, credential changes, and unresolved external choices retain their own authorization boundaries.

The taxonomy and distribution boundaries below are agreed. Detailed implementation choices and unfinished decisions are identified separately. The requested privacy review is recorded below; historical exposure is not resolved by a clean working tree. Agents never push under the current repository policy; creating an origin or proposing a distribution plan does not authorize a GitHub write, history rewrite, or publication.

## Purpose and design rationale
Make the useful capabilities independently adoptable without requiring the rest of the author's configuration or personal workspace. Someone should be able to obtain a skill collection, point an agent at its setup entry, configure only the services they want, and use it in an unrelated project.

Keep the custom CLI implementations. The discussion did not establish that replacing them wholesale with MCPs would improve the system: existing capabilities, deterministic restrictions, and customization matter, and maintenance burden should be assessed from observed work rather than presumed. Include relevant MCPs alongside the CLIs where useful.

Use skill folders as the discoverable distribution unit: concise action-oriented instructions, supporting code, assets, examples, and explicit dependencies. Use moderate granularity around a coherent service/domain, combining reads and supported writes in `use-*` skills. Comments are part of the relevant use skill. Avoid one skill for every API action, one giant platform skill, and a single runtime that makes every service depend on every other service.

Separate three questions: where a skill's source lives, which collection someone downloads, and which agent/project installs or invokes it. A globally available skill need not be copied into every repository. A folder in a package does not imply authorization to execute its writes.

## Agreed taxonomy
| Collection | Ownership and distribution | Boundary |
| --- | --- | --- |
| `agent-hands` | Shareable repository, included in configs as one submodule; service/tool capabilities, provider authorization, setup, neutral CLI code, and relevant MCP documentation. | No required LifeOS vault, personal accounts, task conventions, or project-workflow package. |
| `project-workflows` | Separate shareable repository, included in configs and adopting projects as a submodule. | The procedures needed to organize and continue a project's work; no automatic dependency on general skills or service tooling. |
| `general-skills` | Ordinary configs folder initially, with individually installable procedures. | Includes the LifeOS entry point, skill authoring/review/maintenance, and both Kaizen skills. It is not brought into every adopting project. |

The final placement is explicit: **both `log-kaizen` and `improve-agent-workflows` belong in `general-skills`, not `project-workflows`.** Their procedures can be adopted separately when wanted. `draft-approval-slate` belongs in `project-workflows`. `track-changes` and `write-skills` remain in `general-skills`.

`project-workflows` is the settled collection name for this proposal, replacing earlier working labels `workflow-skills` and `project-management-skills`. Accordingly, the setup/update pair is `setup-project-workflows` and `update-project-workflows`. `improve-agent-workflows` retains the plural spelling used in the detailed proposal; its capture/review scope and trigger text are now implemented.

## Target folder structure
This is the target structure. All six `general-skills` entries and the independent local `project-workflows` repository now exist. The independent local `agent-hands` repository now includes Odoo, Slack, Trello, GitHub, and Google capabilities with provider/setup support. Microsoft and rendering paths remain proposed; neither new GitHub repository has been created or published. The initial documentation capture did not create implementation files.

```text
configs/
├── agent-hands/                         # Submodule: independent shareable repo
│   ├── README.md
│   ├── mcp-integrations.md
│   └── skills/
│       ├── setup-agent-hands/
│       ├── setup-google-services/
│       ├── authorize-google/
│       ├── use-gmail/
│       ├── use-google-drive/
│       ├── use-google-docs/
│       ├── use-google-sheets/
│       ├── use-google-calendar/
│       ├── use-google-contacts/
│       ├── setup-microsoft-services/
│       ├── authorize-microsoft/
│       ├── use-outlook-mail/
│       ├── use-outlook-calendar/
│       ├── use-outlook-contacts/
│       ├── use-microsoft-files/
│       ├── use-excel-workbooks/
│       ├── use-planner/
│       ├── setup-trello/
│       ├── authorize-trello/
│       ├── use-trello/
│       ├── setup-slack/
│       ├── authorize-slack/
│       ├── use-slack-messages/
│       ├── use-slack-lists/
│       ├── setup-odoo/
│       ├── authorize-odoo/
│       ├── use-odoo-projects/
│       ├── setup-github/
│       ├── authorize-github/
│       ├── use-github-issues/
│       ├── use-github-projects/
│       ├── use-github-pull-requests/
│       ├── use-github-discussions/
│       └── render-markdown-pdf/
│           ├── SKILL.md
│           ├── scripts/
│           └── assets/themes/
├── project-workflows/                   # Submodule: shared/default checkout
│   ├── README.md
│   ├── workflow.toml
│   ├── .gitignore
│   ├── setup-project-workflows/
│   │   ├── SKILL.md
│   │   └── assets/templates/
│   ├── update-project-workflows/
│   ├── run-project-spike/
│   ├── triage-project-misc/
│   ├── draft-approval-slate/
│   ├── commit-work/
│   └── capture-for-later/
├── general-skills/
│   ├── operate-lifeos/
│   ├── write-skills/
│   ├── track-changes/
│   ├── update-derived-skills/
│   ├── log-kaizen/
│   └── improve-agent-workflows/
└── agents/
    ├── AGENTS.global.md
    └── integrations.md
```

The broad service breakdown is agreed; exact provider setup names, command entrypoints, and module internals are design proposals to settle during implementation planning. A separate authorization skill is useful where it owns actual shared provider machinery, not merely to duplicate an existing login command.

An adopting project uses the collection directly at its root:

```text
example-project/
├── .gitmodules
├── AGENTS.md                            # Routes to adopted project instructions
├── TODO.md
├── docs/                                # This project's actual working history
└── project-workflows/                   # Submodule pinned to the adopted commit
    ├── README.md
    ├── workflow.toml                    # Tracked on the project's branch
    ├── .gitignore
    ├── setup-project-workflows/
    │   └── assets/templates/
    └── …                               # Other complete skill directories
```

Keep workflow configuration inside the submodule, not scattered across the parent root. Real project documentation stays in the parent; reusable templates stay in `setup-project-workflows/assets/templates/`. The parent still needs its own routing instructions and Git submodule metadata. A workflow branch must never accumulate the actual document history of unrelated adopting projects.

## Project and general skill breakdown
| Current source | Target | Intended change |
| --- | --- | --- |
| `skills/setup-project-docs` and `skills/setup-local-skills` | `project-workflows/setup-project-workflows` | Combine documentation adoption, skill distribution, initial project branch, configuration, templates, and agent routing in one setup procedure. |
| `skills/update-local-skills` | `project-workflows/update-project-workflows` | Replace copy-versus-seed reconciliation with explicit submodule ancestry and project-branch reconciliation, preserving semantic judgment. |
| `skills/run-project-spike` | Same skill in `project-workflows/` | Preserve conceptual/task pairing, scope, history, QA, and closure conventions. |
| `skills/triage-project-misc` | Same skill in `project-workflows/` | Preserve scratch routing without requiring unrelated global skills. |
| `skills/draft-approval-slate` | Same skill in `project-workflows/` | Keep concrete review of proposed writes in the project operating package. |
| `skills/commit-work` | Same skill in `project-workflows/` | Preserve scoped commits and local authority; audit references to installed/global paths. |
| `skills/pin-issue`, `skills/log-future-idea` | `project-workflows/capture-for-later`; old entrypoints removed | Save possibilities and deliberately parked subjects as individual scratch notes; status describes intent, with no infrastructure-only restriction or automatic work commitment. Existing notes remain in place. |
| `skills/lifeos-handoff` | `general-skills/operate-lifeos` | Broaden into a thin configured entry point; discover the vault and follow its authoritative instructions. Preserve useful handoff behavior through the vault's owning procedures rather than embedding its private structure. |
| `skills/write-skills` | `general-skills/write-skills` | Keep skill-authoring guidance available independently of ordinary project operations. |
| `skills/track-changes` | `general-skills/track-changes` | Preserve the locally adapted review workflow and explicit upstream provenance. |
| No dedicated companion before this spike | `general-skills/update-derived-skills` | Implemented maintenance procedure for upstream-derived skills, with track-changes as the concrete first case. Not required for ordinary document review. |
| `skills/kaizen` | `general-skills/log-kaizen` and `general-skills/improve-agent-workflows` | Separate incident capture from review and improvement work; both remain outside the project package. Preserve explicit user authority over standing-rule changes. |
| `skills/log-skills-feedback` | Retire | Remove the compatibility entry and repair its references; do not carry an alias indefinitely. |

Kaizen placement and the first implementation contract are settled. `log-kaizen` owns capture, dated follow-up evidence, and immediate concern links; `improve-agent-workflows` owns broader review, proposals, approved interventions, outcome tracking, and retention review. They use the same two-record data contract without requiring each other to be installed. `log-kaizen` does not claim to improve a workflow merely by logging an incident. Both use private configured destinations, with blank public configuration templates.

The project package must function when none of these general skills is installed. Existing mandatory Kaizen references in project skills and exported guidance need deliberate treatment during migration; simply moving files does not make the dependency optional. Do not silently remove the user's current global preferences or project-specific rules.

## Agent-hands service breakdown and dependencies
These are preservation targets and operation boundaries, not claims that every API operation is currently implemented. `use-*` means “the supported operations in this domain,” not full write/delete coverage. Audit current commands and guardrails before extraction, including work in active spikes and uncommitted changes.

| Provider/domain | Target use skills | Shared support and capability boundary |
| --- | --- | --- |
| Google mail | `use-gmail` | `authorize-google`; existing reads, labels, filing/archive behavior, filters, and other implemented mail operations. No new sending capability implied. |
| Google files | `use-google-drive` | `authorize-google`; file discovery, metadata, reading/export/download, and supported file operations. Personal bounded-index selection and destinations move to LifeOS. |
| Google documents | `use-google-docs` | `authorize-google`; native document reads and supported content changes, including comments in the same skill. |
| Google spreadsheets | `use-google-sheets` | `authorize-google`; preserve currently implemented spreadsheet reading/rendering. New spreadsheet writes require their own capability decision. |
| Google calendar | `use-google-calendar` | `authorize-google`; supported calendar/event reads and writes, time zones, attendees, recurrence, and event settings. No implicit Microsoft call. |
| Google contacts | `use-google-contacts` | `authorize-google`; explicit Google provider scope, preserving supported lookup/contact operations. Personal cross-service aliases remain caller context. |
| Microsoft mail, calendar, contacts | `use-outlook-mail`, `use-outlook-calendar`, `use-outlook-contacts` | `authorize-microsoft`; retain existing domain operations and bounded permissions. |
| Microsoft files | `use-microsoft-files` | `authorize-microsoft`; OneDrive/SharePoint file transport, metadata, and supported file operations. Uploading a DOCX is not native Word document editing. |
| Excel | `use-excel-workbooks` | `authorize-microsoft`; worksheet/table/range semantics and supported edits warrant a separate skill from generic file transport. |
| Planner | `use-planner` | `authorize-microsoft`; supported plan/bucket/task reads and task writes, metadata, labels, and comments. |
| Trello | `use-trello` | `authorize-trello`; boards/lists/cards, labels, checklists, comments, and neutral bidirectional linking/chain inspection. |
| Slack | `use-slack-messages`, `use-slack-lists` | `authorize-slack`; messaging/conversation operations and Lists operations respectively. Preserve identity checks, discovery limits, and known comment/link limitations. |
| Odoo | `use-odoo-projects` | `authorize-odoo`; project/stage/task reads and currently supported task writes/comments. |
| GitHub | `use-github-issues`, `use-github-projects`, `use-github-pull-requests`, `use-github-discussions` | `authorize-github`, building on the existing `gh` route where appropriate; supported reads/writes only. Discussion writing is explicitly deferred. |
| Local document rendering | `render-markdown-pdf` | No service authorization; explicit Markdown input, theme, output, and renderer dependencies. Generalization beyond the existing résumé pipeline must be demonstrated. |

Existing entry points for extraction are `lifeos-tools/lifeos.sh`, `lib/common.sh`, `lib/google.sh` and Google helpers, `lib/m365*.sh`/`lib/m365*.py`/`lib/m365-graph.ps1`, `lib/trello.sh`, `lib/slack.sh`/`lib/slack.py`, `lib/odoo.sh`, `lib/github.sh`/`lib/github-render.py`, and `lib/resume.sh` with its theme assets. The current tool skills live under `lifeos-tools/skills/`. These paths identify current owners, not a requirement to preserve the dispatcher or directory shape.

### Shared authorization, setup, and runtime
Provider authorization is the main intended inter-skill dependency. `authorize-google` owns Google credential/token handling and refresh; `authorize-microsoft` owns the corresponding Microsoft authentication/cache mechanics. Other providers own their actual shared account support, using established clients where that avoids duplicating authentication.

Setup and authorization have different triggers. `setup-agent-hands` helps a new user select and bootstrap capabilities; provider setup skills guide obtaining the needed application/account configuration; authorization skills maintain usable account access. Ordinary service use should not rerun onboarding or load all setup instructions.

Skill instructions are the discoverable interface, not a substitute for code dependency declarations. Put supporting code and needed assets with the owning skill. Declare real Python/package dependencies, entrypoints, and configuration lookup explicitly. Prefer a service skill depending on its provider authorization support over one use skill importing another use skill just to acquire tokens.

Do not force every common function into authorization to satisfy a slogan. HTTP transport, pagination, response normalization, error handling, or domain-specific helpers may be genuine additional sharing. First keep small helpers local; duplicate trivial code where that is simpler. Extract a narrow support library only when concrete overlap justifies it, document it, and avoid a central runtime that installs unrelated providers. Shared Gmail message parsing is not automatically a separate agent-facing skill; it may simply belong inside `use-gmail`.

Limited shared provider support may carry a Python library while retaining a skill-facing setup/auth interface. The exact package names, import layout, lockfile boundaries, and invocation paths are still open. Do not implement a giant workspace environment just because everything ships in one repository.

### Deterministic behavior versus guidance
Tool code owns its actual restrictions: implemented operation set, bounded reads, explicit targets, ambiguity checks, applicable revision guards, identity checks, allowlists, existing preview/execute behavior, and honest partial-failure reporting. Skill text explains those mechanics. LifeOS selects targets and workflows. Preserve the actual per-command safety model; do not assume all existing tools share the same dry-run behavior.

For Trello, the neutral capability is to link two items bidirectionally with explicit inputs and idempotent recovery/reporting. LifeOS supplies task-boundary meaning and successor conventions. “An atomic task” as a work unit is different from an all-or-nothing API transaction: two remote writes can partially complete. Preserve the useful compound operation without promising transactional behavior that the service does not provide.

## Configuration and onboarding
Keep configuration adjacent to the skill that owns it. Use tailored tracked examples, ignored real values, and structured token/cache files where their native format requires them. Do not add a `local/` or `tool-configuration/` layer solely to hold a few files.

Illustrative provider folder, not a finalized schema:

```text
authorize-google/
├── SKILL.md
├── scripts/
├── pyproject.toml
├── uv.lock
├── .env.example
├── .env                         # Ignored
├── oauth-client.example.json
├── oauth-client.json            # Ignored
├── token.json                   # Ignored, generated
└── .gitignore
```

The examples must match the actual owning skill's needs, support configured account/profile names, and contain no real account identifiers. Never force structured Google tokens or Microsoft caches into environment-variable strings just to use one file format. Exact filenames, multi-account layout, and credential lookup precedence remain implementation choices. Add ignore rules before creating or moving real configuration; ignored does not mean previously tracked history disappears.

Projects normally select a configured account/target without copying provider credentials into every project. Co-located per-skill credentials remain the user-facing default design; explicitly needed project-specific configuration remains possible. Load configuration for the invoked capability, not from global shell startup.

`workflow.toml` contains public-safe project-wide choices and is tracked on an adopting project's branch. The canonical configs checkout instead uses shared `main` and neutral defaults. The speculative workflow env example was removed after checking the six selected consumers: none has a required dependency on it. Preserve each project's existing private-context mechanism and explicit access rules; do not create a new env contract without an observed need. Specify path resolution relative to the owning project/skill, not the caller's incidental working directory.

The current CLI already has a uv project and lockfile, with MSAL as a direct dependency and Python >=3.11 declared. The migration extends that into a modular distribution; it does not start from no environment management.

`setup-agent-hands` should let a nondeveloper give the repository to an agent and proceed through a clear setup route:
1. Detect the operating system, available tools, and requested capabilities.
2. Explain and install uv when needed under the user's setup authorization; do not assume Python or Bash already exists.
3. Provision a compatible Python version and locked dependencies for the selected capabilities.
4. Check external executables required by those capabilities, such as shell utilities, `gh`, PowerShell, or PDF renderers; uv does not supply every external program.
5. Run only the relevant provider setup and authorization procedure.
6. Verify identity and a bounded read or local render, then expose the selected skills to the chosen agent client.

A small native bootstrap for macOS/Linux and Windows is a proposed way to start when uv is absent. Exact supported OS matrix and whether remaining Bash glue is supplied or ported must be decided before promising Windows support. Keep Python; a Rust rewrite and compiled-binary distribution are deferred. Do not install every service dependency for a person who wants one service.

## Submodules and project-specific branches
Use two shareable repositories, one for `agent-hands` and one for `project-workflows`, rather than a repository/submodule per skill. Their source folders remain separable within each collection. `general-skills` stays an ordinary configs folder initially. No additional flattening symlink layer inside configs is necessary merely to make unlike source collections appear under one `skills/` directory.

An adopting project gets its own project-specific branch from initial adoption, even when it initially points to the same commit as the shared default branch. Do not create an artificial localization commit just to establish the branch. The parent records the exact adopted submodule commit. The branch provides a place to develop project-specific history; it does not replace the parent's pin.

`setup-project-workflows` combines the current docs and skill setup procedures. It must document the initial branch, submodule placement at the project root, configuration inside that submodule, reusable templates, existing-doc adaptation, parent routing, and reproducible cloning.

`update-project-workflows` must document:
- checking the current pin and branch, including selecting/creating the intended branch before edits when a submodule checkout has detached HEAD;
- comparing shared upstream changes, project changes, and their shared ancestor;
- preserving intentional local procedure changes, not restricting customization to TOML or environment values;
- reconciling nonconflicting and conflicting behavior with agent/human judgment rather than treating text merge success as semantic agreement;
- offering reusable local improvements upstream as focused changes, keeping project-only changes on the project's branch;
- updating templates deliberately without overwriting existing project document history;
- recording the accepted child commit by updating the parent's submodule pointer.

A configured remote called `origin` is not sufficient by itself: the referenced child commits must actually be published to a remote collaborators can access. Parent-repository publication does not publish child history. Branch metadata in `.gitmodules` can identify an update target but is not a substitute for the exact commit pin or attached development branch. Under current policy, agents prepare changes and the human handles pushes.

The user selected public repositories under `jcklpe` with AGPL licensing on 2026-10-24: `https://github.com/jcklpe/agent-hands.git` and `https://github.com/jcklpe/project-workflows.git`. New packages use AGPL-3.0-only and preserve applicable source notices. Shared branches start at `main`; project adaptations now use `project/<slug>` under the user's 2026-10-25 platform-neutral naming choice. The canonical configs installation now uses shared `main`; other projects keep their adaptation branches. The earlier `codex/project-<slug>` names remain historical; current reconciliation and nested-pin evidence are in [Workflow Reconciliation](workflow-reconciliation.md). These destination choices do not create or publish the repositories. A public upstream must not receive private project configuration or sensitive local adaptations; use a suitable accessible remote if a project branch cannot be public.

## General skill maintenance and global installation
`operate-lifeos` is a workspace entry point. Its ignored configuration may identify the vault, potentially retaining `LIFEOS_VAULT_PATH` there. The reusable service tools must no longer require that variable. The entry skill reads the vault's actual instructions rather than copying private context or policies into public configs. It is not included with project-workflows.

`track-changes` derives from the public Obsidian Track Changes reviewer skill. Its adjacent provenance record owns the adopted source identity and compatibility checks. Preserve upstream attribution/license obligations and intentional local behavior; the completed comparison is recorded under [Derived review skill reconciliation](#derived-review-skill-reconciliation).

The proposed `update-derived-skills` companion maintains a known upstream baseline, compares new upstream changes and local adaptations against it, reconciles intentionally, checks compatibility with the relevant tool, and updates provenance. A short record of intentional local differences may help. It does not need to be installed in every project or loaded to review a document. This has a different trigger from updating a project's branch of an entire workflow collection.

Both Kaizen skills are independently installable general procedures. Private store contents and actual routing values stay out of these shareable collections. Their optional use in a project must not secretly depend on access to LifeOS.

Global installation is a separate unresolved selection, not implied by the taxonomy. Preserve existing useful access during migration, then explicitly decide which source folders are exposed to each client. Repo-local adopted procedures retain local authority. Use the existing simple symlink installation style unless actual complexity justifies a different mechanism. No new manifest engine is required merely to reorganize directories.

## MCP catalog and installation selections
`agent-hands/mcp-integrations.md` travels with the shareable package. It covers relevant service/tool MCPs, including useful capabilities without custom CLI equivalents: official sources, capability scope, supported clients, transport/install method, version information where meaningful, setup/authentication requirements, and overlap with CLI operations. Mark optional integrations clearly. A catalog entry is not a claim that the integration is installed, connected, authorized, or equivalent to the CLI's deterministic restrictions.

`configs/agents/integrations.md` records the user's client selections and additional integrations outside that package's scope, referring to catalog entries rather than duplicating their instructions. Do not turn installation inventory into miscellaneous skill folders. Keep private endpoints and account values in ignored configuration.

Distinguish standalone MCP servers from client-managed plugins that can bundle skills, tools, and connection flows. Listing an integration should not silently enable it or change the preferred route. A machine-readable manifest can be considered if a concrete installer needs one; a readable source/setup catalog is the initial plan. This spike does not reopen the wholesale MCP-replacement audit.

## What moves into LifeOS
| Concern currently coupled to tooling | Reusable capability retained | LifeOS ownership |
| --- | --- | --- |
| Vault opening, context suggestions, “sync everything,” and default snapshot paths | Explicit commands and caller-selected inputs/outputs | Workspace discovery, source selection, orchestration, refresh habits, and private destinations. |
| Combined Google/Microsoft agenda | Independent provider reads and neutral data normalization/rendering helpers where justified | Which calendars to combine, presentation choices, missing-source expectations, and when to refresh the combined view. |
| Bounded Drive/source orientation indexes | Bounded listing/search/export/render primitives | Which material matters to the workspace, index placement, curation, and refresh procedure. |
| Task chains and successor conventions | Neutral bidirectional item links, chain inspection, metadata operations, and honest partial-failure recovery | Meaning of task boundaries, gates, successor criteria, preferred labels/lists, and workflow-specific text. |
| Account/repository/calendar choices and local contact aliases | Explicit account profiles and target parameters | Personal mappings, cross-service identity preferences, chosen resources, and project context. |
| Résumé source/content/destination conventions | General Markdown-to-PDF rendering with caller-supplied theme and output | Content selection, career evidence, output destinations, and résumé workflow. |
| Approval preferences and operating policies | Actual command restrictions plus an accurate description of them | When the user's workflow permits a supported action and how the proposal is approved. |

Keep useful deterministic compound helpers with the capability they help when the inputs and behavior can be neutral. The vault's prohibition on executable scripts remains: do not solve separation by copying Python or shell helpers into LifeOS. For example, a neutral Trello linking helper can stay with `use-trello`; a calendar normalization/rendering helper can operate on explicitly supplied data without choosing personal accounts. The precise home of any genuinely cross-provider renderer must be settled before removing the working combined-agenda path.

Public document themes can stay with `render-markdown-pdf/assets/themes/`, including generalized résumé/letter/compact themes. Audit the existing theme assets and their relationship to the public theme repository before reuse; refreshing the résumé theme and selecting an academic-paper theme are follow-on design choices, not approved theme redesigns. Renaming the renderer alone does not prove arbitrary Markdown works.

LifeOS skill names and divisions can be reconsidered when that migration is authorized; current ad hoc groupings are not sacred. This spike defines the boundary, not a new private-vault taxonomy.

## Migration sequence after explicit go-ahead
1. **Inventory and preservation baseline.** Map current commands, imports, configuration, credentials/cache locations, safety behavior, clients, symlinks, consumers, tests, and active work. Reconcile documented capability with implementation; avoid losing recently added Excel, Planner, Slack, calendar, or Trello behavior. Capture a recovery plan without moving anything.
2. **Resolve extraction details.** Decide remote ownership/licensing, exact service/setup boundaries, independent dependency declarations, supported operating systems, configuration discovery, and the neutral helper homes. Finalize what is private versus distributable before copying material into new repositories.
3. **Create modular service packages.** Extract provider support and service implementations with adjacent tailored examples and ignores. Replace vault requirements with explicit inputs. Preserve command behavior and guardrails while changing ownership. Add the setup entry and capability-specific environment provisioning.
4. **Establish the project-workflow package.** Move the agreed eight skills, combine the two setup sources, implement the update procedure, and add templates/configuration. Remove mandatory dependencies on Kaizen/general skills while preserving explicit per-project adoption. Establish submodule/branch workflows.
5. **Establish general skills.** Move review and authoring skills, create the thin configured LifeOS entry, split Kaizen capture/review, and add the bounded derived-skill maintenance procedure. Retire the old feedback compatibility entry and repair references.
6. **Move personal conventions to their owners.** Update LifeOS procedures and neutral helper callers together under an authorized scope. Maintain usable calendar, task, snapshot, and résumé workflows throughout the transition. Do not put executable scripts or credentials in the vault.
7. **Wire distribution and consumers.** Install chosen source skills through the existing client-linking approach; update configs documentation and current consumers. Pilot a project-specific branch in a designated project after approval. Do not require all existing projects to migrate in one sweep.
8. **Verify and review privacy before commits/publication.** Inspect proposed content and history, examples, file paths, aliases, account references, templates, documentation, and real ignore behavior. Separate actual secrets from incidental identifiers when assessing exposure; determine whether any published material needs action. Do not rewrite history or force-push automatically. Earlier uncommitted work is separate scope.
9. **Prepare reviewed release/cutover.** Confirm clean installation, dependency independence, project cloneability, recovery, and the selected global installation list. Prepare scoped commits only after the privacy hold is satisfied; publication and remote operations retain their own authorization. Retire obsolete entrypoints only after affected callers are repaired and verified.

The sequence is a dependency order, not a promise of a single large cutover. A temporary compatibility route may be useful while consumers migrate, but its scope/retirement must be explicit. The user already wants `log-skills-feedback` retired; do not invent indefinite compatibility requirements for it.

## Validation and non-goals
Use meaningful checks tied to the migration risk: selected-service setup without unrelated providers, imports and help paths without vault access, existing guardrail behavior, parser/output compatibility, neutral rendering examples, idempotent setup, ignored real configuration with tracked examples, and project-submodule ancestry/pin/clone behavior. Reuse relevant existing checks. There are already tool-specific tests in this repository; the plan is not to add a ceremonial suite or a test for every trivial rename.

Live writes require the relevant authorization and a concrete reviewable target; prefer bounded reads, dry runs where supported, and isolated/local validation until that exists. Do not claim a dry run proves a live write. Human QA is needed for actual first-machine onboarding, client skill discovery, document appearance, and real project update ergonomics.

Non-goals: replace all CLIs with MCPs; rewrite in Rust; add GitHub Discussion writes or native Word editing by implication; restore the retired Loop tool; create a repository per skill; add mandatory global dependencies to adopting projects; expose private account/workspace information; force every project into identical procedures; perform automatic history rewriting or push.

## Open decisions
- Private project adaptations need an appropriately accessible private remote; public project branches must contain only public-safe configuration and procedures.
- The global skill selection for each client; source placement does not settle installation.
- Precise per-provider setup skill names, package/lockfile boundaries, executable interfaces, and supported OS/bootstrap matrix.
- The minimum provenance/adaptation record and exact scope for `update-derived-skills`.
- Placement of any nontrivial shared transport or cross-provider rendering code without rebuilding a monolith.
- Configs is the initial local workflow adopter. A later real upstream reconciliation and fresh collaborator clone remain to be verified after publication.
- Which MCPs belong in the portable catalog, installation/version tracking details, and actual client capabilities.
- Theme provenance, possible academic theme, and generalized renderer acceptance examples.
- Findings of the separate privacy/history pass; no decision that a force push or history removal is needed has been made.

## Privacy review and implementation authorization, 2026-10-24
A custom local, redacted scan examined 300 current tracked/nonignored files and all 3,708 reachable historical blobs across local refs (about 502 MB), including legacy binary IDE caches. No blob was skipped for size. It checked recognizable credential patterns and exact matches against 16 current secret values, without printing those values. No current-file credential-pattern hits or current-secret matches were found. All 18 inspected local tool-configuration files were ignored. This does not certify every possible secret format or private fact; submodule repositories, unreachable objects, image interpretation, and full semantic review of every historical file were outside scope.

Historical caches under the retired WebStorm runtime tree contain 41 distinct Google API-key-shaped strings. The three key-bearing blobs are reachable from the locally cached origin/master history; no fresh remote publication check or key-validity test was performed. Ownership, restrictions, and current validity are unknown. Other credential-in-URL hits include synthetic negative tests and unclassified historical cache material. Do not copy the values into public records. The old cache tree is absent from the current working tree; an explicit ignore rule now prevents reintroducing that runtime directory.

Targeted current review found public Git identity configuration, synthetic examples, and LifeOS-specific workflow/path references. Those references are not authentication secrets, but their coupling and unnecessary personal assumptions belong in the planned separation. The Slack edits checkpointed with the baseline remove private-conversation framing and named-account associations. The new spike records contain architecture and public-safe examples rather than private source content.

The scan's detailed redacted findings remain outside this repository. Historical cleanup is an unresolved follow-up: determine ownership and desired remediation before considering rotation or a separately authorized history rewrite. No push or rewrite is authorized by this review. New package repositories should begin from reviewed source rather than importing the unrelated configs history.

After the clean baseline, the first implementation slice is the general-skills review/authoring boundary: relocate track-changes and write-skills with compatibility for existing installed links, add the derived-skill update procedure, and update source routing. The Kaizen split was completed in the subsequent slice recorded below. Provider extraction and new remote repositories remain later work, so existing service tools stay usable during the initial cutover.

## First implementation slice, 2026-10-24
The privacy review and scoped baseline checkpoints are complete, and the working tree was verified clean before implementation. Loop retirement, Slack privacy corrections, a Trello guidance-link correction, the spike records, and shared coordination updates were checkpointed according to their actual scope.

`track-changes` and `write-skills` now live under `general-skills/`. The installer targets those owners directly; temporary file symlinks in the old skill folders preserve existing client installations and source references. These links hold no duplicated implementation and are a migration bridge, not a permanent flattened collection. Existing Codex and Claude skill links were verified to resolve to the new owners without rerunning the full installer. `write-skills` and its agent metadata are byte-identical to the prior versions. Track Changes retains its review procedure and source attribution; its frontmatter is now trigger-focused, and adjacent `upstream.toml` records the previously claimed baseline and local preservation requirements.

`update-derived-skills` now describes three-way reconciliation, provenance uncertainty, local adaptations, relevant behavioral verification, and scoped propagation. It has no required dependency on another skill, client, or personal workspace. It is available in the source collection but has not been added to the global installer. The recorded Track Changes upstream revision was not retrieved or synchronized in this slice; relocation and metadata validation do not establish upstream/plugin compatibility.

Validation covered YAML frontmatter for all three skills, TOML parsing, installed and compatibility-link resolution, preservation of moved content, installer syntax under Bash and Zsh, relative documentation links, and whitespace. The standard Python skill validator could not run because PyYAML was absent from the checked runtimes; frontmatter was parsed with the available Ruby YAML parser instead. No test suite, live service operation, full installer run, or new global installation was introduced. Runtime discovery in a newly started client and eventual bridge removal remain cutover checks.

## Current evidence and related work
The LifeOS entry migration is implemented. `operate-lifeos` reads only configured location pointers and delegates roles, handoff format, and saving rules to the private workspace. The existing handoff sections and attribution requirements were preserved in a vault-owned procedure with private routing links; they are no longer embedded in the public skill. The adjacent `.env.example` is blank except for the generic entry filename, while real pointers remain in an ignored owner-only local file. Both client links now select the new entry. The old source path has only a temporary routing stub for remaining consumers; no private content was copied into public configuration or documentation. The private checkpoint preserves unrelated vault work.

The Kaizen split is implemented in `general-skills`. Each skill has an adjacent `.env.example` and explicit ignore rules. The configuration contract selects an explicit `KAIZEN_ENV_FILE`, otherwise the skill's `.env`, with legacy JSON discovery only when neither env source applies; invalid selected configuration never silently redirects capture. The existing private pointers were copied into ignored, owner-readable local files without moving records or changing legacy configuration. Public files contain no actual destinations. Global routing and the installer now select both replacement skills; targeted Codex/Claude links were updated and verified. The feedback compatibility entry is removed. A short `skills/kaizen` source route remains only for old private references until those consumers migrate.

The continued implementation corrected the installer's directory-link replacement before further cutover. Existing symlinks are replaced without following their destination; real files and directories are preserved with an explicit refusal. Temporary Bash and Zsh fixtures verified relinking, repeated invocation, dangling/fresh links, and preservation of existing contents. No full installer or live service operation was run for this check.

Read-only inspection during capture found the existing `skills/` library and `lifeos-tools/` implementation, the uv manifest, current spike/index conventions, and existing uncommitted changes. Those changes were preserved during capture, then reviewed and checkpointed under the later clean-baseline authorization. Loop retirement is committed with archived notes and must not be reintroduced. Current implementation state is recorded above; the remaining migration checklist is still active.

Current owners and relevant work:
- [Skill authoring guidance](../../general-skills/write-skills/SKILL.md), [project adoption/documentation setup](../../project-workflows/setup-project-workflows/SKILL.md), and [project updates](../../project-workflows/update-project-workflows/SKILL.md).
- [Track Changes provenance](../../general-skills/track-changes/upstream.toml), [derived-skill updates](../../general-skills/update-derived-skills/SKILL.md), [Kaizen capture](../../general-skills/log-kaizen/SKILL.md), and [workflow review](../../general-skills/improve-agent-workflows/SKILL.md).
- [Tool README](../../lifeos-tools/README.md), [uv project](../../lifeos-tools/pyproject.toml), [secret/configuration hygiene](../policies/0001-secrets-and-local-env.md), and [client symlink installer](../../install-script/functions/symlinks.sh).
- [Excel](lifeos-m365-excel.md), [Planner labels/comments](lifeos-planner-labels-comments.md), [Slack conversation reads](lifeos-slack-conversation-reads.md), [Slack List comments](lifeos-slack-list-comments.md), [calendar settings](lifeos-calendar-event-settings.md), and [Trello checklists](lifeos-trello-checklists.md) are capability-preservation inputs; consult their current task records before extraction.
- [Loop retirement](../archive/lifeos-loop-headless.md), [earlier skill taxonomy](../archive/skill-taxonomy.md), and [earlier workflow refinement](../archive/project-workflow-refinement.md) supply history, not substitute operating rules.

Reference sources for later implementation verification:
- [Git submodule workflow](https://git-scm.com/book/en/v2/Git-Tools-Submodules) and [gitmodules reference](https://git-scm.com/docs/gitmodules).
- [uv installation](https://docs.astral.sh/uv/getting-started/installation/) and [Python provisioning](https://docs.astral.sh/uv/guides/install-python/).
- [Track Changes upstream skill](https://github.com/philphilphil/obsidian-track-changes/blob/main/docs/SKILL.md).
- [Existing public résumé theme repository](https://github.com/jcklpe/typora-resume-theme), supplied in the discussion; current correspondence with local assets remains unverified.


## Project workflow extraction
The collection is now an independent local Git repository, registered as a configs submodule with the selected public origin and a `codex/project-configs` branch. Shared `main` contains the reusable seed; the project branch records real configs adoption metadata in `workflow.toml`. No old configs history was imported. The original MIT notice is retained with the AGPL-3.0-only package license.

Six existing procedures preserve their bodies and assets, with local precedence updated for adopted collections. The combined setup and replacement update procedures cover branch-from-adoption, templates, config, manual copied-skill migration, shared ancestry, semantic reconciliation, and exact parent pins. Real project documents stay in the parent. No general/service skill, Python environment, or credentials are required. Temporary source bridges preserve old callers while the installer and selected client links use the new owners.

Ruby YAML, TOML, preserved body/asset comparison, relative references, Bash/Zsh syntax, privacy patterns, and standalone ignore checks passed. An isolated local Git fixture verified an initial same-commit project branch, divergent project configuration plus upstream changes, shared-ancestor merging, parent pinning, and a fresh recursive local clone. This does not establish GitHub reachability or real collaborator access. Neither new remote repository has been created or pushed; publishing the parent before its child commits are available would leave the submodule unavailable to fresh clones. The spike stays active for service extraction, publication preparation, and remaining QA.

## First Agent Hands capability
Agent Hands now starts from reviewed source in an independent local repository, with AGPL-3.0-only and the original source notice. Odoo is the first implemented capability: `authorize-odoo` owns account access, transport, and pacing; `use-odoo-projects` owns the bounded operations; `setup-odoo` and `setup-agent-hands` provide scoped onboarding. This shell capability requires Bash/jq/curl and ordinary Unix utilities, without Python, uv, another provider, or a vault. Per-capability Python environments remain later extraction work, not a new shared runtime.

The operation body preserves the existing commands and limits: project/stage/task/comment reads; task create/update/comment; dry-run by default; explicit execute; required task readback; no deletion, archive, or generic API command. Existing timestamp pacing is retained and is not claimed as a concurrent lock. The new provider env loader reads literal ODOO-prefixed values, never evaluates them, preserves exported overrides, anchors relative paths to configuration, and fails on a missing explicit env source. API-key lookup no longer evaluates its value. Examples are synthetic; actual configuration remains ignored.

The old `lifeos odoo` dispatcher delegates to the new implementation with a small compatibility wrapper preserving its existing account/state paths and env-loading route. Existing private files and installed legacy Odoo skill links remain in place; the source skill routes to the new operation guidance. A future standalone configuration/client cutover must deliberately migrate those consumers instead of silently changing their credentials or claims of readiness.

Validation passed on the current macOS host: retained read/write request fixtures, literal env/injection/override/redaction checks, missing explicit configuration failure, cwd-independent paths, help/dry run without credentials or vault variables, YAML/resources/shell syntax, and running both offline checks with only the two runtime skill folders copied outside configs. The legacy wrapper passes its original fixture checks. No live Odoo operation was performed. Fresh Linux/WSL/native-Windows setup, other providers, MCP catalog, and real GitHub cloneability remain outstanding.

## Slack extraction boundary
Slack now has separate `use-slack-messages` and `use-slack-lists` implementations, each depending only on `authorize-slack` for provider configuration/transport/identity and shared message helpers. `setup-slack` handles selected-capability onboarding. Each Python skill declares its own uv manifest/lock; only the standard library is required. Legacy commands keep their previous private config and snapshot destinations; the standalone exporter requires an explicit output. No live credentials or account-specific verification narrative was copied. Existing token rotation is not changed, automatic refresh remains unsupported, and the former undocumented endpoint override is retired to prevent configuration from redirecting credentials.

## Trello extraction boundary
Trello now has `authorize-trello`, `setup-trello`, and `use-trello`, requiring Bash/curl/jq and no unrelated provider or Python environment. Existing direct-write semantics remain explicit. Portable scheduling requires a destination list; consumer rules choose task boundaries, start-date automation, labels, and snapshot paths. Legacy `snooze`/`sync` callers retain their previous defaults without copying private credentials.

Export previously continued after failed board metadata and stopped comment paging on transport errors while still publishing success. The new explicit-output exporter preserves the previous file on failed/malformed retrieval, stalled or capped pagination, and rendering errors. Pipeline status now propagates within operation-local subshells without changing the parent shell. Bidirectional linking resolves canonical card identities and reports partial outcomes; recovery uses the existing successor rather than repeating creation. These paths are verified with synthetic offline fixtures, not live mutations.

## GitHub extraction boundary
Four GitHub use skills now share gh-backed authorization/configuration and small common response/export helpers. Issue and PR shapes justify one shared collector/renderer; Discussion and Project code stays with those domains. Literal owner/repo operations work without a private alias file. Each use skill has its own Python manifest/lock, while shell requests require Bash/gh/jq. Legacy aggregate exports retain private repo selection and destination routing.

Existing issue-create and organization-project Status writes remain preview/execute gated. The migration does not add Discussion writes, PR creation/merging, arbitrary issue edits, or pushes. Exports stage retrieval/rendering before publication; failed reads and cap hits do not overwrite prior domain artifacts. Multi-file publication is not a transaction. Discussion indexes declare their existing bounds and detail files identify known nested reply truncation. Fixtures/examples carried into the new history use synthetic identities and mappings, without copying existing private configuration.

## Google Docs extraction boundary
Google Docs now owns existing-document reads, exact replacement, tab-body Markdown replacement, and comment listing/creation in `use-google-docs`. It depends only on `authorize-google`; setup is a companion skill. Both Python owners have independent standard-library uv manifests/locks. Authorization retains alias-based scopes and adds an explicit Docs-only read configuration, with a separate opt-in for reading comments. No token or private account settings were copied.

The legacy command sources shared provider functions while retaining its original private path/runtime rules; the old Python paths are compatibility loaders. Gmail/Drive callers continue using those function names. New adjacent env parsing is literal, relative paths are cwd-independent, and real JSON/token/temp files are ignored. OAuth endpoint validation rejects non-Google destinations; temporary token files now start owner-readable, with atomic publication and failure cleanup. Whole-tab replacement now rejects a revision change after its initial preview read, before the existing revision-guarded request.

Retained formatting/comment fixtures, mocked preview/concurrency/write-control checks, token-permission/failure checks, env/scope checks, legacy mail checks, and isolated two-skill execution pass offline. API responses confirm the existing writes; independent readback is a caller verification step, not an implemented guarantee. No OAuth consent, token refresh against a real account, remote document read/write, or client install was performed. Gmail, Drive, Sheets, Calendar, Contacts, and the Google/Microsoft agenda boundary remain pending.

## Google Contacts extraction boundary
`use-google-contacts` now owns the read-only People lookup, independent of Calendar and local nickname files. It takes an explicit account alias through `authorize-google`, shares only provider support, and has its own standard-library Python/uv manifest. The provider's optional Contacts scope selection requests saved/other-contact reads. Existing calendar callers retain their credential slot, aliases, and attendee-selection rules while delegating the remote candidate lookup; production token passing now uses a process-local environment instead of command arguments.

The existing saved-contact substring search, case-insensitive email deduplication, and up-to-20 other-contact fallback are retained. Repeated/nonterminating pagination fails without printing a partial candidate list. Synthetic checks cover paging, duplicate candidates, fallback precedence, incomplete-read failure, scope selection, and standalone two-skill routing. No live contact data was read, token migrated, consent changed, or message/invitation sent. This is not a contact-management/write API; private composition still awaits migration to its workflow owner.

## Google Sheets extraction boundary
`use-google-sheets` now reads an explicit sheet/range with only Google provider support and its own standard-library Python/uv environment. A Sheets-only read scope can be selected without enabling Drive; the old Drive scope route remains compatible. The existing small Markdown table formatter is provider-shared because both direct Sheets reads and the legacy Drive reader consume the same response shape. Range selection and API requests remain in the capability. This is bounded value reading, not a spreadsheet-write or fidelity-preserving export feature.

Default first-tab `A1:Z200` behavior, configurable row limits, and explicit A1 ranges are retained. New request staging cleans private temporary responses on success and failure. Synthetic renderer fixtures, URL/range routing, failed-read handling, cleanup, scope selection, and isolated capability execution pass. Old fixture identities were replaced before moving them to the child; obsolete duplicates were removed and the combined legacy renderer check delegates to the new owner. No real sheet or account operation was performed.

## Google Drive extraction boundary
`use-google-drive` now owns searches, folder listing, metadata, Docs/Sheets reads, downloads, bounded index export, and the existing preview/execute-gated native Doc import. It depends only on Google provider support, sharing the small Sheets formatter rather than another use skill. The portable index requires an explicit output and has no private folder-name defaults. Legacy `sync` retains its original private destination/QA/exclusion choices while delegating to the portable export.

The extraction fixes confirmed output-destruction and false-success paths: downloads stage before publication, reject unsafe remote path names/symlink targets, and preserve prior files when transport fails; index listing validates response shapes, propagates folder/child/recent failures, renders before publication, and states truncation. Private request temporary files are cleaned. Existing index exclusion semantics were narrower than their old privacy wording: they skip top-level child traversal, not account-wide recent results or other queries. Portable and compatibility guidance now state that limit; no stronger privacy filtering is claimed or silently introduced.

Synthetic checks cover failed-download preservation, overwrite refusal, path/symlink handling, failed index retrieval, bounded output, import opt-in and preview gates, cleanup, and isolated provider-plus-capability use. Legacy mail/calendar checks still pass after sourcing the smaller Google module. No live Drive read/upload, credential change, private snapshot regeneration, or global install occurred. Gmail, Calendar, Microsoft services, renderer generalization, and remaining consumer/cutover work stay open.

## Gmail extraction boundary
`use-gmail` now owns bounded listing/export, labels/archive, Spam rescue, and limited filters. It depends only on Google provider support, with a capability-local standard-library Python/uv environment. Explicit export paths and queries replace private defaults in the portable route; the legacy wrapper retains its original configuration, default query, snapshot/index orchestration, retry setting, and shared audit destination. Microsoft mail remains separate. Shared atomic output publication now lives with the Google provider because Drive and Gmail both consume it.

Existing write opt-ins, preview/execute gates, target bounds, restricted actions, and label readback are retained. Filter deletion now requires a successful list readback showing absence; a failed read cannot confirm deletion. Sequential changes can partially apply, and early failures can leave incomplete audit records; documentation states that limit rather than promising atomic writes. New portable audit files start owner-only and are ignored. Synthetic exports preserve prior output on retrieval failure.

Retained mail/render/transport fixtures, new failure-path checks, legacy mixed-provider checks, and isolated provider-plus-Gmail execution pass offline. Examples contain synthetic identities. No live mailbox read/write, consent, token migration, snapshot refresh, or client install occurred. Calendar, Microsoft services, renderer generalization, and remaining consumer/cutover work stay open.

## Google Calendar extraction boundary
`use-google-calendar` owns Google-only reads, bounded search, explicit-output agenda export, event-body building, and create/update operations. Shared authorization now supports an optional Calendar account block with independent read/write scopes; Contacts access is not implicit. Portable attendees are explicit emails, and write destinations are configured allowlists. The selected account's read window, page cap, and description-omission settings are adjacent private configuration. The capability uses only Google provider support and its own standard-library uv environment.

The legacy caller keeps its separate Calendar credential slot, existing scope set, local nickname/contact selection, snapshot destinations, and combined Google/Microsoft orchestration. It delegates OAuth to the existing secure shared implementation and rendering/writes to the new capability through adapters. This preserves the old combined agenda while removing Microsoft dependencies from the portable Google tool; moving the remaining orchestration into its private workflow owner is still open.

Calendar lists/exports have bounded paging and command-local cleanup. Failed exports preserve existing output. Search retains its 50-event-per-calendar bound and now warns on continuation. Existing write gates, no-notification default, timezone refusal, recurring-instance targeting, and partial settings-readback behavior remain. An explicitly empty attendee replacement now sends an empty array instead of silently omitting the requested field. Updates still lack ETag concurrency protection, and only explicitly requested transparency/reminder fields receive independent readback.

Existing settings, timezone, render, and combined-agenda checks plus isolated scope/routing/failure checks pass with synthetic fixtures. Personal examples were replaced before entering the child history. No token migration/consent, live calendar read/write, invitation, snapshot regeneration, or global install occurred. Microsoft services, rendering, private composition, and final cutover remain open.

## Microsoft provider extraction boundary
`authorize-microsoft` and `setup-microsoft-services` now own shared delegated authorization, configuration, transport, and paging. MSAL has its own locked uv environment; the Graph PowerShell route remains optional. Literal env parsing and cwd-independent config paths match the other portable providers. Real account JSON, env files, tokens, and staging files are ignored; no private tenant/client IDs were copied.

Request destinations are constrained to public Microsoft Graph, authority destinations to public Microsoft identity, and token staging starts owner-only. Paged reads preserve prior caller output on failure and warn at the configured result bound. Portable PowerShell aliases require an expected account and check the SDK identity before a service request. The legacy adapter retains existing account paths/runtime and permits absent expected-account configuration; no credential or SDK-context migration was performed. Its existing broad service scope mapping is documented without importing tenant-specific rationale.

Config, pagination, cache-failure, and synthetic PowerShell identity tests pass; locked MSAL dependencies install and import in the provider environment. Existing Microsoft service fixtures exercise the adapter. These are offline/synthetic checks, not evidence of live tenant access or consent. Individual Microsoft capabilities and remaining private workflow ownership still require extraction.

## Outlook Contacts extraction boundary
`use-outlook-contacts` owns bounded default-folder contact lookup, explicit-output export, and existing previewed create/update operations. It depends only on `authorize-microsoft`; its payload/render environment has no external Python dependencies. Small Graph text and atomic publication helpers are provider support, independent of MSAL imports. The legacy caller retains private snapshot destination/index routing and delegates contact mechanics and Python builders/renderers.

Exports now clean temporary data and preserve existing output if any retrieval/render step fails. Bash 3.2 empty email/phone arrays work for scalar-only changes. Existing broad Contacts.ReadWrite scopes, service enablement, preview/execute gates, and API-response confirmation remain; there is no new delete operation, duplicate prevention, ETag guard, or independent write readback. Synthetic checks and retained legacy fixtures pass, including isolated provider-only execution. Live contact and fresh-machine checks remain unperformed.

## Microsoft Files extraction boundary
`use-microsoft-files` owns file search/metadata/link resolution, binary download, upload, replacement, and folder creation. File addressing and the file-write flag are small provider helpers for both file and workbook capabilities. The portable skill has its own Python environment and ignored audit destination; legacy callers retain the established private audit route.

Preview/execute, file-write opt-in, upload size/OneNote restrictions, conflict refusal, ETag replacement, and metadata readback remain. Missing replacement ETags fail closed; OneNote refusal also checks a renamed upload's destination. Downloads publish privately without clobbering old output on failure or following output symlinks. Search warns on continuation. Write readback is metadata-only, audit remains best-effort after readback, and ambiguous failures must not be retried blindly. Synthetic and legacy checks pass; no remote file or credential operation occurred.

## Excel Workbooks extraction boundary
`use-excel-workbooks` owns worksheet/table/range reads and the existing bounded edit surface. It depends only on Microsoft provider support, including file addressing/write opt-in, and has its own small locked Python environment and private audit route. Legacy dispatch/helper entrypoints retain their audit destination. Shared Microsoft source-path resolution now supports direct Bash/Zsh consumers.

The extraction preserves preview hashing, immediate preflight rereads, required pre-write audit, payload/range limits, readback verification, and uncertain-outcome reporting without blind mutation retries. These are not atomic transactions. The original synthetic workbook checks and isolated provider-only cases pass without a live workbook or account. Mail, Calendar, and Planner remain to migrate.

## Outlook Calendar extraction boundary
`use-outlook-calendar` now owns bounded calendar/event reads, explicit-output export, and previewed event writes with Microsoft provider support only. Portable account configuration owns timezone/window choices (UTC, 14 days back/30 ahead by default). The legacy caller retains its existing timezone/global window, private nickname resolver, combined agenda, and snapshot destinations; no private account configuration moved.

Writable-calendar selection, attendee notification acknowledgment, online-meeting body protection, and existing API-response confirmation remain. Explicit empty writable lists now allow no writes; explicit empty attendee replacement sends an empty list. Temporary event data is cleaned and failed exports preserve old output. The existing implementation still lacks independent write readback, ETag concurrency checks, and a separate recurrence-scope guard. Synthetic and legacy fixture checks, including combined calendars, pass without live service access. Mail and Planner remain to extract.

## Planner extraction boundary
`use-planner` depends only on Microsoft provider support. It retains plan/bucket/task reads, labels, conditional task updates, experimental same-group beta moves, and journaled group-conversation comments. Portable exports require an explicit output; legacy snapshot destinations, audit routing, and recovery locations remain with the compatibility caller. Missing batch responses and failed requested task details now fail instead of publishing a fresh-looking incomplete export. Failed name resolution warns and retains IDs.

Existing synthetic command/comment recovery checks and bounded export/batch checks preserve the safety model without live account activity. Comments are not atomic with task linking, audit remains best-effort, and uncertain writes are not retried automatically. Outlook Mail remains the final service extraction; private composition, rendering, client cutover, and publication remain separate work.

## Outlook Mail extraction boundary
`use-outlook-mail` depends only on Microsoft provider support and its own standard-library Python environment. It preserves message reads/search, bounded Inbox export, attachment saves, folder moves, categories, Junk rescue, and Inbox rules. Legacy sync destinations, indexes, and audit routing remain with the caller. No send, forward, direct message deletion, or permanent-delete capability was added. Existing tightly scoped rules that move future incoming mail to Deleted Items are preserved and documented accurately, including recipient substring matching.

Attachment downloads now validate the returned identity and safe filename, decode before replacing any existing files, and refuse symlinks. Rule deletion requires a successful complete collection read showing absence; lookup failure is not confirmation. Failed protected-folder identity reads and incomplete child-folder lists are refused. The PowerShell provider disables retries for non-GET requests, including batch POSTs, to avoid replaying uncertain side effects. Existing checks plus synthetic failure cases and provider-only isolation validate local behavior without real mail or credentials.

All planned service capability extractions are now present. Private workflow ownership, client installation/cutover, Markdown-to-PDF generalization/themes, the MCP catalog, fresh-platform QA, publication, and historical privacy remediation remain separate open work; the overall spike stays active.

## Markdown-to-PDF renderer and theme extraction
`render-markdown-pdf` now owns the explicit Markdown/theme/output pipeline, its own WeasyPrint 69.0 uv lock, and bundled plain, résumé, and compact themes. Pandoc and native Pango/fonts remain platform prerequisites; macOS Homebrew library discovery is handled for uv-managed Python. No authorization skill or private configuration is required. The public upstream résumé CSS matches the previous copy exactly, with source/license provenance preserved. The compact and letter variants share the same existing margin override; no new résumé design or formal academic theme was selected.

The renderer strips leading YAML metadata, rejects an incomplete block, resolves Markdown images and stylesheet imports against their source locations, and only reads additional local resources from explicit asset grants or the bundled theme directory. It refuses network resources, drops PDF attachments and local-file links, and preserves prior output on conversion/resource/write failures. Temporary/final output uses private permissions; overwrite requires an explicit flag in the portable entry. These are resource controls, not an OS sandbox for hostile documents.

The legacy résumé command retains its output/theme defaults, directory creation, overwrite behavior, and optional macOS opening through a thin adapter. Existing CSS paths remain links to the new owner. Synthetic regression checks and visual inspection cover a two-page report, normal and compact résumés, relative images, metadata omission, output preservation, and denied resources. The résumé fixture's rendered page is pixel-identical to the previous pipeline on this machine. Fresh Windows/Linux setup, font-equivalent pagination elsewhere, academic-theme design, private composition, MCP catalog, and final consumer cutover remain separate work.

## Optional integrations catalog and client inventory
The portable `agent-hands/mcp-integrations.md` now identifies vendor setup sources and distinguishes MCP servers, client plugins, and CLI skills. It records current documented Google Workspace preview, Slack Lists, Trello, GitHub, Microsoft, Notion, and Figma surfaces, with explicit limits where capability or account parity has not been verified. It separates enforced tool/resource controls from approval guidance and retains the CLI implementations rather than treating documented overlap as a migration decision.

`agents/integrations.md` records only public-safe integration names, observed local enablement/installation states, and relevant client setup references. It links to the portable catalog instead of copying service configuration, account identities, private endpoints, tokens, or installation arguments. Documentation review and a dated inventory do not establish authenticated service access. No MCP connection, permission, global installation, or real configuration changed.

## Derived review skill reconciliation
`track-changes` now has a verified upstream comparison, not only a carried-forward source note. The recorded 2.2.0 baseline and current 2.3.0 upstream have identical skill, parser, and source-edit operation content. Local project precedence, review-only behavior, explicit chat-only requests, and author attribution remain intact. Two examples are clarified: agent-added highlight anchors carry attribution, and replies must share a source line because any newline separates threads. The upstream MIT notice travels with the adapted skill.

Temporary synthetic checks passed for all six mark forms, metadata, anchors, human replies, newline boundaries, suggestion/rationale cleanup, finalize behavior, malformed prefixes, and literal code examples. The installed plugin manifest remains 2.2.0. No plugin upgrade, live panel check, human-document edit, or project-local copy update was performed. Exact upstream identities and verification limits are recorded beside the skill.

## Private résumé workflow routing
The private résumé procedure now calls `render-markdown-pdf` directly and supplies its own source, theme, destination, and intentional overwrite choice. Its content, retention, and publication rules remain private and unchanged. Public package documentation contains only generic rendering mechanics and synthetic examples; the legacy renderer command remains available for existing callers. Links, frontmatter, and preservation of the private policy sections were verified. No actual résumé artifact was regenerated or published.

Remaining ownership work concerns task conventions, account/resource mappings, source-index destinations, and combined-calendar orchestration. Final source/client cutover remains conditional on chosen installations and consumer verification; it is not achieved by finishing the renderer or this one private caller.

## Calendar composition and private workflow separation
`render-calendar-agenda` now owns offline event normalization and detailed/compact rendering with no provider authorization or workspace dependency. Google and Outlook expose `export-data` with explicit instant bounds and complete, versioned source bundles. Google Markdown exports have an explicit small dependency on the neutral renderer; Google data/API operations and Microsoft operations remain independently usable. Provider JSON output never enumerates another provider's accounts.

The renderer requires explicit expected sources, sufficient window coverage, a display timezone, and an output. Missing sources preserve previous output by default; deliberate incomplete output is visibly marked and returns status 2. Microsoft complete-data exports reject result truncation. Account-local event IDs are namespaced while shared iCalendar UIDs still merge duplicate invitations. Synthetic checks cover those failure/identity/timezone boundaries, isolated renderer use, and existing formatting/recurrence fixtures. A seven-digit Graph fractional timestamp remains compatible with the old adapter runtime. No live calendar data was fetched or published.

The private workspace now owns its source selection, availability interpretation, time windows, snapshot destinations, and refresh procedure, with its source-map, agent routing, and retrospective consumer updated. The public legacy calendar guide no longer carries personal calendar interpretations or private attendee examples. Compatibility export commands use existing credentials without moving tokens; the old combined sync retains its behavior until its remaining callers migrate. This is not yet removal of all legacy orchestration or evidence of live cutover. Task conventions, other source/index workflows, installed-client choices, historical privacy remediation, and publication remain open.

## Source-refresh and context ownership
The private workspace now owns a task-scoped source-refresh procedure covering source selection, snapshot destinations, coverage/freshness checks, and aggregate-sync limits. Its existing task-mapping procedure explicitly owns task phases, board choices, labels, and automation; sequential bidirectional-link failure recovery is distinguished from the workflow's atomic task model. The public CLI's context command now points only to the configured workspace entrypoint rather than maintaining private context-file recommendations.

A boundary review found that folder child-listing exclusions do not constrain the separate account-wide recent-file query. Drive `export-index --recent 0` now skips that query and marks the section disabled. The private workflow supplies this choice and retains its own exclusions; the portable tool introduces no personal folder names or workspace defaults. Synthetic request tracing confirms omission of the broad query, while existing output-preservation and import-gate checks pass. This does not establish that old private exports exposed particular files; no live export or historical content audit was performed.

Remaining compatibility bindings are explicit: legacy calendar sync still performs its old two-window/provider composition; aggregate sync still selects configured service families; legacy Trello scheduling, Drive exclusion, and per-service snapshot wrappers retain existing caller defaults. These are migration bridges, not authority for the new private procedures. Remove them only with caller discovery and verified replacement. Global/client selection, actual platform/live-access checks, historical privacy remediation, and publication remain unfinished.


### 2026-10-24 — retire legacy aggregate and calendar composition
Caller discovery found live public guides/policies and private refresh/source-map/focus guidance still recommending the aggregate command. Those callers now route to scoped service exports or the private refresh procedures. Historical review/archive records remain historical. The public CLI no longer implements automatic service-family selection, enabled-account calendar merging, or the two-window publication pipeline. Old aggregate/combined commands fail with status 2 before loading dependencies or configuration and explain the replacement; they do not silently produce narrower output. Individual service compatibility commands retain their existing configuration while later caller/configuration migration continues.

Offline verification covers the retirement boundary without installed dependencies, an executable config sentinel, preservation of an existing snapshot, provider exports, calendar write/settings gates, merge/timezone/compact rendering, and missing-source checks. No live sources were refreshed, no ignored configuration changed, and no remote operation occurred. Private caller repairs live only in LifeOS. Other legacy defaults and general-skill compatibility routes remain separate cutover work.


### 2026-10-24 — move remaining list/exclusion defaults to callers
The Drive exporter accepts repeatable additive `--exclude-folder` choices; malformed configured exclusions stop before remote listing and preserve old output. The legacy Drive sync no longer embeds a private folder default and requires either a caller exclusion flag or an explicit configured array. The private workflow now supplies its required exclusion while retaining other configured choices. Trello's legacy scheduling and missing-start-date rendering no longer select private list names; the private workflow supplies the target and warning lists. Existing explicitly configured choices remain usable, and no ignored settings were rewritten.

Synthetic request traces verify that both configured and caller exclusions suppress the child fetch, malformed settings preserve output without querying, and old callers cannot silently fall back to broader sampling. Scheduling checks use stubbed transport to verify explicit list/start-date arguments and missing-list refusal; existing renderer/checklist fixtures pass. Private meaning and list/folder names remain only in LifeOS. Per-service destination adapters, actual account/configuration migration, general source bridges, global client selection, and live onboarding remain open.

### 2026-10-25 — remove general-skill source bridges
The existing Codex and Claude review/authoring links now point directly to `general-skills`; no new skill was selected for global installation. Current tracked configs guidance, private workspace guidance, and the adjacent organization workspace were checked for old callers. The remaining private attribution reference now points to its actual private handoff owner. The temporary review/authoring file links and the public Kaizen/handoff migration stubs are removed. Historical references and project-local precedence examples remain history/examples, not active callers.

Both installed client directories resolve the unchanged skill bodies and supporting provenance files through their new owners. The installer already names those owners; no full installer run was needed. This verifies filesystem discovery, not a fresh client process reloading its catalog. Private Kaizen copies remain authoritative in their workspaces. Service-client selection, other repository consumers outside the inspected scope, and fresh-session/platform QA are not asserted complete.

## Provider configuration and caller cutover — 2026-10-25
All configured services now use their provider-owned ignored configuration through both standalone and compatibility entrypoints. Existing grants, account/resource mappings, query choices, calendar windows, audit histories, and recovery records were preserved; the Microsoft SDK retains its protected cache and its expected identity is pinned. Calendar's formerly separate Google authorization remains a distinct profile/token. No authentication consent, token refresh, service request, or push was performed.

Service exports now require explicit destinations. Shared env evaluation, vault-path discovery, automatic mail indexes, and private nickname routing are retired from the CLI. LifeOS procedures own selected sources, destinations, retained nickname preferences, disambiguation, and per-source failure reporting. Old files remain ignored recovery sources; active commands do not read them. Live account health and client discovery remain QA, and the historical privacy question remains separate.

## Public publication — 2026-10-25
The user explicitly authorized a security/privacy review followed by publication of both child repositories. This was a task-specific override of the standing agent no-push rule, not a change to that policy. The audit covered all reachable blobs and commits, credential-pattern and known-local-secret matches, private identifier/path candidates, tracked secret-like filenames, ignore behavior, and source/license notices. Candidates were synthetic fixtures or parser code; no publication-blocking finding remained. The historical privacy issue in parent configs is outside these independent histories and remains unresolved.

Both repositories are public under AGPLv3 with main as the default branch. Project Workflows also publishes the public-safe codex/project-configs branch needed by the current parent pin. Anonymous fresh clones contain the adopted commits. Only these child refs were pushed; parent configs and LifeOS were not published by this action. Remaining client/platform QA, account-specific access issues, and overall spike closure remain separate.


## Cutover and selective retirement — 2026-10-25
The local cutover is implemented: the public dispatcher, adapters, routing guides, and maintained regression checks live in `agent-hands/compat/lifeos/`; the shell resolves `agent-hands/bin/lifeos`; installers provide selective setup guidance and both clients resolve the selected native and compatibility skills. Retired integrations remain retired. No publication, authentication change, or unrelated project change is part of this work.

The initial whole-tree archive proposal was superseded by authorized selective cleanup after an explanatory inventory. Git already preserves the 98 tracked legacy entries and the obsolete shared-runtime installer. Reconciled private copies, generated runtimes/caches, QA exports, retired browser state, and obsolete recovery metadata were moved to recoverable local Trash. No unresolved unique private record remained. Do not empty Trash or rewrite history as part of this task.

The approved path-only review checked 32 settings in 11 provider configuration files and found no old-tree dependency. Subsequent local content comparisons reconciled all 18 private configuration/token/backup/alias files without exposing values: unchanged provider mappings/credentials, account configurations preserved as subsets, newer access tokens with the same refresh credentials and grants, superseded backup settings, and aliases already owned by the private workspace. All 579 audit records match the five destination logs with exact field/duplicate coverage and order within each log; all six comment-recovery files are byte-identical. Active provider files remain authoritative and must not be rewritten.

The retired browser profile and actual credential paths are ignored and absent from the index and available refs/reflogs, including the cached remote-tracking history. This bounded check cannot rule out copies elsewhere or unavailable history. The profile contains cookie and local/session storage files; their current usability was not tested. Trash is reversible retention, not session revocation or secure erasure.

Cleanup is complete: the old tree and obsolete installer are absent; 99 tracked entries are recoverable from the pre-cleanup Git tree, and 7,269 untracked files/symlinks plus prior cutover metadata are retained in the owner-only local Trash bundle `~/.Trash/lifeos-tools-cleanup-2026-10-25/`. Its `RESTORE.md` and sanitized receipt document restoration without overwriting current work. Each moved leaf retained its inode, mode, size, timestamp, and symlink text. This does not reclaim the space occupied by the Trash bundle.

Post-removal checks pass: all 31 offline compatibility entrypoints, fresh Bash/zsh launch resolution and help, installer syntax and repeatable setup check, 45 selected skill targets/frontmatter per client, and the repeated 32-setting private-path check. Metadata for 29 active provider/configuration/audit files is unchanged. Old-path strings remain only in historical material and deliberate stale-PATH/link removal guards in the inspected active surfaces. No remote service request, authentication change, or push occurred.

Keep this spike active for fresh-client catalog and platform QA, remaining live-access questions, child/parent publication, and separate historical privacy work. Agent Hands remains at local compatibility checkpoint `dbf1aa1`; its nested workflow pin and the configs workflow pin are unchanged. Publish required child commits separately before any containing pin, and do not infer permission to publish the outer repository's unrelated outgoing history.
