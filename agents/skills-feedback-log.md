# Skills Feedback Log
Cross-project feedback about reusable agent skills and skill-like workflows.

Use this log for evidence-backed observations about skills, not ordinary project backlog. Capture friction here when the same lesson may apply across projects, global seed skills, local skill vendoring, or future skill authoring.

Do not automatically rewrite a skill from a single note. Log the observation, keep the evidence, and triage later.

## Open Feedback
### 2026-09-24 - Commit-Work Needs An Explicit Off-Ramp For Work Without A Spike
Skill or area: `commit-work`, and its coupling to `run-project-spike`.

Observed behavior: an agent added `lifeos docs comment` / `comments` to `lifeos-tools` on the fly, in a LifeOS meeting-prep session, to post date-correction comments on a shared Google Doc. No spike existed for it. When the user asked for commits via `commit-work`, the skill's model of scope, trailers, and completion boundaries is written almost entirely around a spike; the no-spike case is a single bullet ("draft the message, show it, commit on a conversational yes... do not write a `Spike:` trailer"). The user had to tell the agent to treat it as a standalone patch, and there is no named convention for how such a commit identifies itself or where, if anywhere, it gets recorded.

Expected better behavior: `commit-work` names the no-spike path as a first-class case rather than an exception. It should say how to scope a standalone patch (the files the unplanned change touched, including its tests and docs), whether the commit carries any marker in place of `Spike:`, whether anything outside git needs a note (a TODO line, a decision, nothing), and that the conversational "yes" can be the user's request to commit.

Context/evidence: 2026-09-24, `lifeos-tools` Drive comment support (`lib/google-docs.py`, `lib/google.sh`, `lifeos.sh`, `tests/test-docs-comment.sh`, README and the `lifeos-docs` / `lifeos-cli` skills), committed without a spike at the user's direction.

Candidate change: add a short "Work without a spike" section to `commit-work` covering scope, message and trailer (for example no trailer, or an agreed `Patch:` marker if the user wants one queryable), and the confirmation rule. Decide whether ad hoc capability additions should at least leave a line in the repo's `TODO.md` or a decision record.

Scope: global reusable.

### 2026-09-23 - Prototype Evidence Needs An Explicit Integration Boundary
Skill or area: `run-project-spike`, diagnostic prototyping, and cross-agent handoff.

Observed behavior: a production-only website animation defect led to frozen-artifact previews and injected rendering experiments. This preserved useful controlled comparisons, but the successful shader prototype acquired fixture-specific image loading, Canvas2D interception, and redraw scheduling outside application ownership. A later application port failed repeatedly; its final rewrite replaced the exact prototype fragment with invalid GLSL. A motion commit also bundled inherited dirty code with newer edits, obscuring provenance. A subsequent user report exposed a likely continued-hover redraw gap in the prototype itself.

Expected better behavior: retain frozen controls and treat prototype divergences as potential optimization or architecture evidence. The user corrected the initial audit’s blanket preference for source-backed candidates: direct static-artifact manipulation may itself be a useful workflow, and its value remains open for later discussion. Validate a minimal real-application path before claiming integration, without making that a prohibition on independent experimentation. Distinguish experimental success, application verification and user acceptance. Neither a commit title nor a prior agent's diagnosis establishes correctness or authorship of inherited working-tree content.

Context/evidence: my-website interaction-polish and performance-optimization spikes, Sep 23 audit. Initial port fragment at 13d4330 is byte-identical to S55; f4dad59 changes its return type and removes essential shader stages. Preserved S56/S57 snapshots show prefetch changes already dirty before 28193d7. S55 redraw scheduling watches pointer entry/exit for 400ms but not pointer movement or parallax style changes; click wakes it again. Hover-zone behavior and its connection to click jitter remain hypotheses pending reproduction.

Candidate change: add a compact experimental-work handoff section to run-project-spike: record baseline revision plus dirty patch, exact served artifact, controlled variable, temporary adapters, evidence limits and next integration boundary. Record intentional divergences and compare source-backed, direct-artifact and hybrid approaches on measured behavior and reproducibility; do not impose a blanket preference. Separate build tooling, runtime rendering ownership and static delivery when discussing architectural lessons. Share the core implementation where useful or verify transfer identity and explain intentional changes. Validate sustained interaction, handoff, static delivery and fallback in the actual app before claiming integration. Preserve this as feedback for skill review, not an automatic new mandatory process.

Scope: global reusable, with concrete project-local evidence.

### 2026-07-19 - Future-Idea Skill Confused Vault Infrastructure With Domain Ideas
Skill or area: `log-future-idea` and possible general LifeOS idea-capture routing.

Observed behavior: when the user offered the essay concept “the analogical overlap between Indra’s Net and holography and neural networks,” the agent triggered `log-future-idea` and proposed placing it in `docs/scratch/future-ideas.md`. The user clarified that this file and skill are intended for meta-level changes to LifeOS vault infrastructure, not writing concepts or other ideas within the vault’s focus threads.

Expected better behavior: `log-future-idea` should route only future LifeOS infrastructure, workflow, and buildout ideas into `docs/scratch/future-ideas.md`. Ordinary domain ideas should land in their natural focus-thread systems—for example, essay concepts in `writing/scratch/` and the writing index—without being treated as vault backlog.

Context/evidence: LifeOS conversation on 2026-07-19. The repo-local skill is already narrower than the global seed and says “active LifeOS buildout work,” but the phrase “capture a LifeOS future idea” and the broader global description made a writing concept look in-scope to the agent. The same failure recurred on 2026-07-21 when the user offered the political-economy essay concept “elite underconsumption”: the agent again invoked `log-future-idea` and began routing it toward `docs/scratch/future-ideas.md` despite this existing feedback entry. The turn was interrupted before the wrong file was modified, and the idea was subsequently routed to `writing/scratch/elite-underconsumption.md`.

Candidate change: tighten the global and local trigger language with an explicit exclusion for writing, art, research, and other domain/content ideas. The trigger should say that “future idea” alone is insufficient; the idea must concern LifeOS infrastructure, workflow, or buildout. Separately evaluate a `log-idea` or idea-routing skill that can locate the relevant focus thread, add or update the appropriate scratch note and index, and use `docs/scratch/future-ideas.md` only when the idea is about LifeOS itself. Because this has now recurred after being logged once, prioritize the trigger correction rather than treating it as isolated ambiguity.

Scope: global reusable behavior with LifeOS-local routing conventions.

### 2026-07-13 - Ready-For-Human-QA Items Should Move To Done, Not Just Tick
Skill or area: `run-project-spike` (spike QA/close-out workflow).

Observed behavior: when describing how to close a spike, an agent said an approved `Ready for Human QA` item should be checkmarked "in place" (tick the box). The user corrected that items with human approval should be *moved* out of the `Ready for Human QA` holding area into the `Done` section, not merely ticked.

Expected better behavior: the skill should state explicitly that `Ready for Human QA` is a holding area, and approved items leave it — they get moved into `Done` — so the QA list only ever shows still-pending review, never resolved items.

Context/evidence: Open Austin org repo, closing the `docs-taxonomy-refresh` spike on 2026-07-13. The `run-project-spike` "Archiving A Spike" and "Human QA" sections describe the QA list but do not spell out the move-to-Done transition, so an agent defaulted to ticking in place.

Candidate change: add a sentence to `run-project-spike` (Human QA and/or Archiving section) making the move-to-Done transition explicit; consider mirroring into any local copies.

Scope: global reusable.

### 2026-07-16 - Trello Comment Text Must Be Protected From Shell Expansion
Skill or area: `lifeos-trello` and reusable CLI invocation patterns for writing user-authored prose.

Observed behavior: an agent passed a Trello comment containing `$0` through a shell command as double-quoted `--text`. The shell expanded `$0` to `/bin/zsh`, so the durable Trello comment incorrectly said "the current /bin/zsh payment." Because the CLI does not edit comments, a second correction comment was required.

Expected better behavior: arbitrary prose sent to Trello or another external system should arrive byte-for-byte without shell interpolation. Dollar signs, command substitutions, backticks, quotes, and other shell-significant characters must not be evaluated as code.

Context/evidence: LifeOS MOHELA task-chain update on 2026-07-16. The intended phrase was "the current $0 payment." The write used `lifeos trello comment --text` inside a shell command, and the generated Trello snapshot exposed the corruption immediately after sync.

Candidate change: add a shell-safety warning and a recommended safe text-passing pattern to `lifeos-trello`; preferably extend the CLI with `trello comment --text-file` or stdin support so agents can use a temporary file instead of embedding prose in a shell command. Apply the same principle to other commands that accept durable free-form text.

Scope: global reusable.

### 2026-09-05 - A Write Path Whose Dry Run Was The Only Thing Ever Exercised
Skill or area: `lifeos-drive`, and reusable guidance for any dry-run-gated write command.

Observed behavior: `lifeos drive import-doc --execute` had never once succeeded on macOS. Its temp-file templates ended in `.XXXXXX.json`, and BSD `mktemp` only substitutes X's at the very end of a template, so every execute died at `mkstemp failed ... File exists` before reaching the API. The bug survived undetected because the dry-run path never touches those files, and dry run is what agents are told to run first. A second latent bug rode along: `.md` was mapped to `text/plain`, so any successful execute would have produced a Doc with literal `## Heading` and `**bold**` — the opposite of the command's stated purpose.

Expected better behavior: a command that is dry-run by default has two code paths, and the safe one gets all the exercise. The unexercised path should not be assumed to work because the plan output looks right. Verification of a write command means performing a real write and reading the result back through a different route, not re-reading the plan.

Context/evidence: LifeOS Drive import work, 2026-09-05. Fixed in configs `b5ae896`. Verified by importing a fixture with headings, a table, a list and bold text, then exporting the created Doc back as HTML and confirming real `h1`/`h2`/`table`/`ul`/`li` and bold styling with no literal Markdown. The `Upload type:` line was added to the plan output because the MIME type decides whether formatting survives and was previously invisible.

Candidate change: add to the dry-run guidance across the lifeos skills that a dry run proves the plan, not the write, and that the first real `--execute` of any command should be treated as untested. Where a command's whole purpose is a format conversion, the verification must inspect the converted artifact rather than the request.

Scope: global reusable.

### 2026-09-08 - The Skill Validator Rejects The LifeOS Vault's Own Frontmatter Convention
Skill or area: `write-skills` validation step, and vault-local skill authoring generally.

Observed behavior: `write-skills` says to run `quick_validate.py` when creating a skill. Running it against a newly written vault skill (`audit-vault-consistency`) produced: *"Unexpected key(s) in SKILL.md frontmatter: tags. Allowed properties are: allowed-tools, description, license, metadata, name."* Every vault-local skill in LifeOS carries a `tags:` block, deliberately — it is what makes skills visible in Obsidian's tag graph alongside the rest of the vault, and Aslan asked for `tags` to be *added* to `update-parents` on 2026-09-07 when it was found to be missing them.

Expected better behavior: the validator's schema and the vault's convention disagree, and the vault's convention is the correct one for its context. An agent that runs the validator, sees a failure, and "fixes" it by stripping `tags` would silently degrade the vault to satisfy a tool that does not know about it. `write-skills` should say that a validator complaint about `tags` in a vault-local skill is expected and must not be acted on.

Context/evidence: LifeOS session 2026-09-08. Also, the documented invocation still does not work — `quick_validate.py` imports `yaml`, absent from both system python3 and the lifeos-tools venv, so `python3 <path>` fails with ModuleNotFoundError and it only runs under `uv run --with pyyaml`. Logged once before, during the `lifeos-docs-skill` spike on 2026-09-06.

**Correction 2026-09-08, and the more important part of this entry.** An earlier version of this note said a second occurrence "is the threshold that spike history says should prioritize a fix rather than another log entry." **Aslan has never agreed to any such rule, and no such rule exists.** It was generalized from a single sentence in the 2026-07-19 `log-future-idea` entry, which was itself written by an agent recommending a specific fix — not establishing a policy. Manufacturing a standing rule out of one prior agent's suggestion, and then citing it as authority to change a skill, is exactly the failure this log exists to prevent: **this log records observations for Aslan to triage. It does not authorize anyone to act on them.**

**On the validator's standing.** `quick_validate.py` lives in `~/.codex/skills/.system/skill-creator/` and encodes Anthropic's own SKILL.md schema for its skill-creator tooling. **It has no authority over this vault's conventions.** A vault-local skill carrying `tags:` is not a defect the validator caught; it is the validator not knowing about the vault. Treating its output as a finding rather than as one host's opinion was a mistake in the original version of this entry.

Candidate change (for Aslan to accept or reject, not for an agent to apply): correct the invocation in `write-skills` to the `uv run --with pyyaml` form, and note that the validator encodes one host's schema and that host-specific frontmatter is not a defect. Possibly drop the validation step for vault-local skills entirely.

Scope: global (`write-skills`), with a vault-local consequence.
