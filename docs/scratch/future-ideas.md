# Future Ideas
Conceptual someday material that is not ready for active spike work.

Use this for broader future directions, feature families, or process concepts that need to be remembered but are not scoped enough to become active spikes.

Do not use it for raw QA nits, bugs, issue intake, or rambling reaction logs. Those belong in `docs/scratch/misc.md`.

## LifeOS Tools V2 Future Ideas
Concept: Future LifeOS CLI improvements beyond the shipped v1 sync/read tooling, Trello task-chain commands, Calendar create/update writes, and read-only `calendar find`.

Why it may matter: the CLI is now the durable boundary for LifeOS source snapshots and guarded writes. The remaining ideas are mostly ergonomics, safety previews, fixture coverage, setup polish, and possible agent-callable wrappers rather than one active implementation theme.

Current blockers or reasons not now: none of these is urgent enough to keep `lifeos-tools-v2` open as an active spike. Promote one concrete theme into a new active spike when actual use shows it is worth implementing.

Candidate themes:

- **Trello write safety and expansion:** add `--dry-run` / preview output to write commands, return before/after state, re-fetch card state before edits, decide whether successful writes should auto-run `trello sync`, consider `set-due`, consider `archive-card`, and keep hard delete out of scope.
- **Calendar ergonomics:** decide whether generated snapshots should expose event IDs inline or keep IDs behind `calendar find`, decide whether successful writes should auto-run `calendar sync`, add filtering controls only if configured calendars become noisy, and consider richer time parsing if explicit timestamps prove clumsy.
- **Gmail snapshots:** decide whether `lifeos sync` should include Gmail or keep Gmail as an explicit manual sync; add per-account query tuning, JSON/debug output, fixture coverage, or a combined index only if actual use shows the need. Do not add Gmail mutations without a separate high-safety spike.
- **Drive read expansion:** add explicit `--max-*` controls for `drive read` if default caps are not enough, richer fixture coverage if renderer behavior gets more complex, Slides read support, richer Sheets extraction, Google Docs comment reading, or configured folder aliases if repeated Drive searches are clumsy. Do not clone or recursively index whole Drives.
- **Agent callable wrapper:** consider MCP/plugin-style functions only if CLI access becomes clumsy. Any wrapper should call the CLI rather than becoming a separate source of truth, and should preserve read-only defaults, explicit writes, dry-run/preview for writes, bounded outputs, and no credential exposure.
- **Setup/install helpers:** add checks for which Google aliases are authenticated without printing secrets, migration notes for new machines, or other setup helpers if repeated setup friction appears.

Safety boundaries:

- Do not add Gmail mutations.
- Do not add Drive-wide cloning or recursive indexing.
- Do not add `calendar delete-event`.
- Do not relax the writable-calendar allowlist or the `--notify`-gated email-out.
- Do not replace the CLI with MCP/plugin tooling.
