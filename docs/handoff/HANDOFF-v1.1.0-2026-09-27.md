# Recall — project handoff

| | |
|---|---|
| **Handoff version** | **v1.1.0** |
| **Date** | 2026-09-27 |
| **Previous version** | [v1.0.0](HANDOFF-v1.0.0-2026-09-27.md) — still the detailed reference for architecture; its *paths* are outdated (see §2) |
| **Repo** | https://github.com/SalutaryFish/recall · local `~/Development/active/ui-design/AI-UI-004-Recall` |
| **Commit** | `195353c` (main) · tags `web-v2.0.0`, `app-v0.1.0` (`app-v0.1.1` once its CI is green) |
| **Web prototype** | **web v2.0.0** — https://salutaryfish.github.io/recall/ |
| **App** | **app v0.1.1** (build = CI run number) · implements web 2.0.0 |
| **Written by** | Claude (Opus 5.5), same session as v1.0.0 |

This handoff is about **session state**. The rules of the project now live in
`docs/foundation/` and are not repeated here — read them before building anything.

## 1. TL;DR

- The native app works (v1.0.0 story: first CI build compiled, IPA installed via iloader).
- This session added the **project's operating rules**: *web first* (never add a feature to the
  app before it's prototyped on the web, phone-tested and approved), *strict versioning* (every
  web/app change bumps a version; releases are frozen and tagged), and a **docs/** layout that
  separates enduring rules (foundation) from session state (handoff).
- The prototype is now **web v2.0.0**, published with GitHub Pages; the app shows which web
  version it implements.
- **Next task:** build **F-001 background tracks** as **web v2.1.0** in `web/index.html`, publish,
  and iterate with the user on the phone. Don't touch the app for it until the user approves a
  web version. Spec: `docs/features/F-001-background-tracks.md` (decisions recorded, 4 small open
  questions to settle during testing).

## 2. What moved (v1.0.0 paths → now)

| Before | Now |
|---|---|
| `Recall.proto.html` | `web/index.html` (latest) + `web/versions/v2.0.0/index.html` (frozen) |
| `Recall-UX.md` | `docs/spec/Recall-UX.md` |
| `Recall.dc.html`, `v2_Recall.dc.html`, `ios-frame.jsx`, `support.js`, `.thumbnail` | `docs/archive/v1-canvas/` |
| `handoff/` | `docs/handoff/` |

Code comments that say "Recall-UX.md §x" or "Recall.proto.html" mean these files by name.

## 3. Read in this order

1. `docs/README.md` — map + the three golden rules.
2. `docs/foundation/WORKFLOW.md`, `VERSIONING.md`, `PRINCIPLES.md`, `ENGINEERING.md`.
3. `docs/features/F-001-background-tracks.md` — the next feature.
4. `docs/handoff/HANDOFF-v1.0.0-2026-09-27.md` — architecture, build pipeline, gotchas, tests
   (still accurate apart from the paths above).
5. `docs/CHANGELOG.md` — which web/app versions exist.

## 4. What changed this session (after v1.0.0)

- **Web:** `web/index.html` got `const WEB_VERSION = '2.0.0'`, the version in `<title>` and in the
  You sheet; frozen copy + `web/versions/index.html` list; `.github/workflows/pages.yml` deploys
  `web/` to Pages on every push that touches it (Pages enabled with `build_type=workflow`).
  `just serve [port]` serves `web/` on the LAN for unpushed changes (NixOS firewall note printed).
  `python3` added to the flake for it.
- **App v0.1.1:** You sheet shows `APP <version> (<build>) · IMPLEMENTS WEB <version>`;
  `RecallWebVersion` key in `ios/project.yml`; CI passes `CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER`
  so the build number = the CI run number = the number in `Recall-<run>-<sha>.ipa`.
- **Docs:** `docs/` created (foundation, features, spec, handoff, archive, CHANGELOG); root and
  `ios/README.md` updated.
- **Tags:** `web-v2.0.0` (545920a), `app-v0.1.0` (0c83113). Tag `app-v0.1.1` on 195353c once
  run 36295377639 is green, and put its build number in `docs/CHANGELOG.md`.

## 5. User decisions this session (F-001)

1. Background tracks need a main task. 2. Stopping the main task offers *stop everything* or
*keep* tracks (a kept track is promoted to main). 3. Sources are modular providers; start with
YouTube / music / typed, add podcasts, audiobooks, movies later. 4. Manual "next" by default,
auto-advance optional (pause-aware); length fetching comes much later. 5. Design for multiple
tracks and nesting (School → Math → Restroom break) from the start. Full detail in the F-001 doc.

## 6. Next steps (in order)

1. Confirm `app-v0.1.1` CI is green → tag it, update CHANGELOG, `just ipa` if the user wants it.
2. Build F-001 in the prototype as **web v2.1.0** (follow the "Releasing a web version" checklist
   in `VERSIONING.md`); keep the prototype's style and gesture rules; data model per F-001 (`lane`,
   `parentID`, `pauses`, `advance`, `name`) in the prototype's localStorage store (bump to
   `recall.v2` with a migration from `recall.v1`).
3. User tests on the phone → PATCH versions until approved → record "Approved in web vX.Y.Z".
4. Only then port to RecallCore + SwiftUI (app v0.2.0, `RecallWebVersion` = approved version).

## 7. Environment reminders

- `nix develop`; `just` lists tasks (`core-test`, `serve`, `ci`, `watch`, `logs`, `ipa`, `crashes`, …).
- gh (SalutaryFish) has the `workflow` scope; HTTPS + repo-local gh credential helper; SSH doesn't work.
- iloader is the user's GUI — never launch it. Free Apple ID installs expire after 7 days.
