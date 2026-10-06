# LifeOS Loop Headless
Build a bounded CLI adapter for Microsoft Loop using an isolated Playwright Chromium profile. Ordinary commands run headlessly and emit small JSON results. The user's working browser, mouse, keyboard, and OS clipboard must stay available.

## Scope
Start with explicit login, document status, readable text, and dry-run-first plain-text appends. Do not claim rich Markdown conversion, full-page replacement, component creation, or direct binary editing. A Loop editor must be uniquely identified before any input is sent.

## Authentication
Graph authentication does not authenticate the Loop website. Each configured alias gets an independent browser profile under ignored `lifeos-tools/secrets/loop-browser/`. The only headed operation is an explicit `login` command. Never attach to, copy, or scan existing browser profiles or debugging ports. Reauthentication may be necessary when the tenant session expires.

Use full Chromium for both headed and headless launches. On 2026-10-06, the default headless shell stalled on Microsoft's blank “Working…” authentication page, while full Chromium reused the signed-in profile successfully. Allow silent redirects to finish before classifying a login requirement. SharePoint file URLs from Graph may download the binary; request `web=1` for a `.loop` URL without an existing browser-view parameter. Two new headless CLI processes successfully read the live Canvas and reported editable status after the sign-in browser closed. This proves immediate reuse, not any specific session lifetime or a persisted live edit.

## Editing
Use browser-local selection and Playwright keyboard insertion. Do not use the OS clipboard, even when headless. Executed appends require a hash from the current text and an enabled file-write capability. The hash detects a stale preview but cannot provide an atomic concurrency guard against another editor. Verify persistence from a separate page; uncertain results are reported as possibly applied and never retried automatically.

## Evidence
On 2026-10-06, a local synced `.loop` was readable as binary and its content was exported through Graph HTML conversion. That establishes reading, not a binary editing contract. The upstream [Loop browser adapter](https://github.com/2mattias/loop-mcp) documents a Canvas textbox and headless profile mode; its clipboard-based paste is unsuitable for this user's uninterrupted desktop requirement. [Playwright persistent contexts](https://playwright.dev/python/docs/api/class-browsertype#browser-type-launch-persistent-context) supply separate browser state.
