# Skills Feedback Log
Cross-project feedback about reusable agent skills and skill-like workflows.

Use this log for evidence-backed observations about skills, not ordinary project backlog. Capture friction here when the same lesson may apply across projects, global seed skills, local skill vendoring, or future skill authoring.

Do not automatically rewrite a skill from a single note. Log the observation, keep the evidence, and triage later.

## Open Feedback
### 2026-07-22 - Weekly Review Needs An Explicit Evidence Window And Source Discipline
Skill or area: LifeOS `weekly-review` workflow and any reusable weekly-review seed derived from it.

Observed behavior: the vault-local skill correctly requires archiving the outgoing review and processing wins, movement, stalls, open loops, sources, decisions, and accomplishments, but it does not define the relationship between the `Week of` date and a late drafting date, identify the minimum sources to refresh, or warn against treating calendar entries as proof of attendance. In the 2026-07-22 review, work from July 20–22 could easily have been credited to the July 13–19 review window, and a calendar-only event could have been described as attended.

Expected better behavior: a review should define its evidence window from the `Week of` date, record the actual drafting date separately, and use late developments only to update current state or open loops. Before drafting, it should refresh or inspect the prior live review, current Trello and Calendar snapshots, `now.md`, relevant focus notes, and accomplishment ledger. Calendar entries should be treated as scheduled commitments unless another source confirms attendance or outcome.

Context/evidence: LifeOS weekly review drafted 2026-07-22 for the week of 2026-07-13. The user explicitly rejected “reconstructing” the review and asked the agent to follow the established skill. The source pass showed meaningful July 20–22 follow-through—financial-aid appeal submission, Parking Perks purchase, INF 391F outreach, resume migration—that belonged in current-state notes but not as accomplishments inside the July 13–19 window. The prior review already contained a correction about calendar-versus-attendance, but that safeguard had not been promoted into the skill.

Candidate change: add a compact “Evidence window and sources” section to the LifeOS weekly-review skill. Define `Week of` versus `Drafted`, list the minimum source pass, state that stale cards and scheduled events are not proof of completion, and link the existing weekly-review template so the procedure and output shape cannot drift apart. Preserve the current archive-first and accomplishment-harvest rules.

Scope: project-local first, potentially global reusable after the LifeOS version proves stable.

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
