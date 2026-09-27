# Handoffs

Snapshots of the whole project for the next session (human or LLM) to start from.

**Latest: [v1.0.0 — 2026-09-27](HANDOFF-v1.0.0-2026-09-27.md)** · commit `0c83113` · CI green

| Version | Date | Summary |
|---|---|---|
| [v1.0.0](HANDOFF-v1.0.0-2026-09-27.md) | 2026-09-27 | First native build: SwiftUI app, RecallCore, nix flake, GitHub Actions IPA, iloader install; background-media feature designed (not built) |

## Rules

- **Never edit an old handoff.** Write a new file and update the "Latest" line and the table.
- File name: `HANDOFF-v<MAJOR>.<MINOR>.<PATCH>-<YYYY-MM-DD>.md`.
- Bump **MAJOR** for an architecture or build-pipeline change, **MINOR** for a new feature or a
  big status change, **PATCH** for corrections.
- Start each file with the header table (version, date, previous version, commit, last CI run,
  app version), then keep the same section order so versions are easy to diff.
