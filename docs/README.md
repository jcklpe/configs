# Docs
Project documentation for agent-assisted work in this repo. Each folder below has a different authority level; the differences are the point.

`TODO.md` at the repo root is the coordination map — what is active, what is waiting, what is next. It indexes this folder rather than duplicating it.

## Layout
| Folder | What lives there | Authority |
| --- | --- | --- |
| [active-spikes/](active-spikes/) | The conceptual + `.todo.md` pair for each spike currently in flight | Current thinking for one theme of work |
| [decisions/](decisions/) | Numbered decision records for tradeoffs that outlive a spike | Durable repo rules |
| [scratch/](scratch/) | Rough notes, references, draft outlines, unrouted observations | **Not authoritative.** Promote before relying on it |
| [archive/](archive/) | Finished and superseded spike docs | Historical context, not current rules |
| [deferred-decisions.md](deferred-decisions.md) | Questions intentionally left unanswered, with a revisit trigger | Live open questions, not a backlog |

Durable long-term docs live in `docs/` directly, or in `README.md` and `AGENTS.md` at the repo root, rather than mixed in with active spike work.

## Process
`skills/run-project-spike/SKILL.md` defines how a spike opens, moves, and archives. `skills/triage-project-misc/SKILL.md` routes loose notes out of `scratch/misc.md`. `skills/track-deferred-decisions/SKILL.md` maintains the pin register.

Archived spike docs are allowed to be messy and out of date. The archive keeps the texture; durable docs keep the rule.
