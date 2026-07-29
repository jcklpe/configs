---
tags:
  - spike
  - lifeos-tools
  - open-austin
  - architecture
---
# Spike: Open Austin Tool Boundary
## Status
- Complete and archived on 2026-07-29.

The private CLI now exposes only `open-austin-org path` and `sync`. Public issue creation and bounded shared-Doc tooling live in `~/work/org`; current LifeOS and configs instructions point to that authority.

## Purpose
Reduce the private LifeOS CLI's Open Austin surface to the thin adapter it actually owns: locate the public org repo, invoke its sync, and copy generated snapshots into LifeOS.

Reusable public writes belong in `/Users/aslan/work/org`. GitHub issue creation therefore moves to `work/org/tools/issues/create.sh`; bounded shared Google Docs writes live beside it. LifeOS keeps no duplicate implementation.

## Boundary
- `configs/lifeos-tools`: `open-austin-org path` and `open-austin-org sync` only.
- `work/org`: GitHub inspection, issue creation, weekly-meeting workflow, shared Google Docs reads/writes, and public write safety.
- `LifeOS`: generated snapshot context and private orchestration; never a second public write implementation.

## Compatibility Posture
The old `lifeos open-austin-org create-issue` command is removed rather than retained as a second wrapper. Current skills and docs point directly to the public org tool. Historical archived docs may continue to describe the command that existed at the time.
