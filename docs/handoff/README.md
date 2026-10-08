# Handoffs

Session-state snapshots for the next session (human or LLM). The project's enduring rules are in
`../foundation/` — handoffs describe *where things stand*, not *how things must be done*.

**Latest: [v1.3.0 — 2026-10-08](HANDOFF-v1.3.0-2026-10-08.md)** · web v2.2.0 · app v0.1.1

| Version | Date | Summary |
|---|---|---|
| [v1.3.0](HANDOFF-v1.3.0-2026-10-08.md) | 2026-10-08 | F-002 automatic capture designed (LiveContainer + one tweak, used unmodified) and built as web v2.2.0 with the event stream simulated; 3 bugs fixed; F-001 and F-002 now await the same phone testing |
| [v1.2.0](HANDOFF-v1.2.0-2026-09-27.md) | 2026-09-27 | F-001 background tracks built as web v2.1.0 (published, in phone testing); 2 user decisions; 3 v2.0.0 bugs fixed; app v0.1.1 CI has a failing UI test |
| [v1.1.0](HANDOFF-v1.1.0-2026-09-27.md) | 2026-09-27 | Web-first workflow, strict versioning, docs/ layout, web v2.0.0 on GitHub Pages, app v0.1.1; next: F-001 as web v2.1.0 |
| [v1.0.0](HANDOFF-v1.0.0-2026-09-27.md) | 2026-09-27 | First native build: architecture, build pipeline, gotchas, tests (paths predate the docs/ move) |

## Rules

- **Never edit an old handoff.** Write a new file and update the "Latest" line and the table.
- File name: `HANDOFF-v<MAJOR>.<MINOR>.<PATCH>-<YYYY-MM-DD>.md`.
- Bump **MAJOR** for an architecture or build-pipeline change, **MINOR** for a new feature or a
  big status change, **PATCH** for corrections.
- Start each file with the header table (version, date, previous version, commit, web version,
  app version), and link the previous handoff.
