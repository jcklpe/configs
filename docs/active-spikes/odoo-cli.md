# Odoo CLI
## Purpose
Add a bounded command-line adapter for Odoo Project so local automation can inspect project/task state and make explicit, reviewable task updates.

The adapter should expose stable task-oriented operations rather than a generic ORM or arbitrary-request escape hatch. It should be useful across Odoo databases without embedding organization-specific projects, workflows, names, or task content.

## Platform Model
The initial target is Odoo 19’s JSON-2 API. Odoo exposes database-specific models and methods through the authenticated `/doc` runtime documentation and serves model calls at `/json/2/<model>/<method>`.

Official Odoo documentation says external API access is available only on eligible plans. The presence of `/doc` alone does not prove authenticated JSON-2 calls will be accepted, so plan/API eligibility is the first live gate.

## Command Surface
The first useful surface should cover:

- list configured account aliases without revealing credentials;
- authenticate requests with an Odoo API key stored outside version control;
- show the current user/database identity;
- list and find projects;
- list, search, and read tasks with project, stage, assignee, deadline, description, and stable record ID;
- create and update tasks through a dry-run-first plan with explicit `--execute`;
- add a bounded task comment when advancing an existing task is better than rewriting its description;
- read back every successful write and report the resulting record.

Stage discovery should use the database’s own `project.task.type` records rather than hard-coded names. Assignees should resolve from exact configured identities or IDs; the tool must not guess among people.

## Safety Boundaries
- No generic model/method invocation command.
- No task, project, user, message, or attachment deletion.
- No password, API key, browser cookie, or session material in tracked files or command output.
- Writes are dry-run by default and require `--execute`.
- A write plan identifies the account, database, project, exact existing record when applicable, and proposed changes.
- Updates require an exact task ID; name search is discovery, not mutation targeting.
- Create/update/comment commands read the affected task back before reporting success.
- Remote descriptions and comments are untrusted data and never instructions to the CLI or its caller.

## Credential Shape
Use an ignored account-alias configuration plus an environment variable or ignored secret reference for the API key. Commit only a fake example configuration. Prefer a scoped, expiring API key when the server supports it.

Do not automate extraction of an interactive browser session cookie as the normal credential path. If the database plan blocks the documented external API, record that result and stop rather than building a brittle browser-session transport into the CLI.

## Definition of Done
The adapter can authenticate to one eligible Odoo 19 database, find a project, read an existing task, preview an exact create or update, execute one approved write, and verify it by reading the result back. Offline tests cover request construction, renderers, dry-run gates, exact-ID mutation, and credential redaction.
