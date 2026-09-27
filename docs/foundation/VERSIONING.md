# Versioning

| | |
|---|---|
| **Document** | foundation/VERSIONING · **v1.0** · 2026-09-27 |
| **Purpose** | never mix up what was tested, approved, built or shipped |

## What gets a version

| Artifact | Name format | Where the number lives | Frozen copy | Git tag |
|---|---|---|---|---|
| **Web prototype** | `web vMAJOR.MINOR.PATCH` | `const WEB_VERSION` + `<title>` in `web/index.html`; shown in the You sheet | `web/versions/v<X.Y.Z>/index.html` + a line in `web/versions/index.html` | `web-v<X.Y.Z>` |
| **iOS app** | `app vMAJOR.MINOR.PATCH (build)` | `MARKETING_VERSION` in `ios/project.yml`; build = CI run number (automatic); `RecallWebVersion` = web version it implements; all shown in the You sheet | the CI artifact `Recall-<run>-<sha>.ipa` | `app-v<X.Y.Z>` on the commit whose green CI run produced the IPA |
| **Spec** | `spec vMAJOR.MINOR` | header of `docs/spec/Recall-UX.md` | git history | `spec-v<X.Y>` when it changes |
| **Feature doc** | `F-NNN` + doc `vMAJOR.MINOR` + status | header table of `docs/features/F-NNN-<slug>.md` | git history | — |
| **Foundation doc** | doc `vMAJOR.MINOR` | header table of each file | git history | — |
| **Handoff** | `HANDOFF-vMAJOR.MINOR.PATCH-YYYY-MM-DD.md` | the file name + header | the file itself (never edited) | — |
| **Data schema** | integer | `RecallData.version` (app) / localStorage key `recall.v<N>` (web) | — | — |

## When to bump

**Web prototype** — *every* change to `web/index.html` bumps it:
- MAJOR: a redesign or a new app structure (tabs, navigation, core model).
- MINOR: a new feature or a visible behaviour change (a feature's first prototype is a MINOR).
- PATCH: tweaks and fixes during phone testing (each testing round = new PATCH).

**App:**
- MINOR: porting an approved web version (usually one feature). PATCH: fixes and non-visible work.
- The app reaches 1.0.0 when the user starts relying on it for real daily use.
- `RecallWebVersion` must always name a web version that exists in `web/versions/`. The app
  **never** contains a feature that isn't in that web version.

**Build numbers** come from the CI run number, so the IPA file name, the You sheet and the GitHub
run all show the same number. Never hand-edit `CURRENT_PROJECT_VERSION`.

**Docs:** foundation docs bump MINOR for additions, MAJOR when a rule changes meaning. Feature docs
bump when decisions change. Handoffs: MAJOR = architecture/pipeline change, MINOR = new feature or
big status change, PATCH = corrections (see `docs/handoff/README.md`).

**Data schema:** changes are additive (new optional fields) whenever possible, decoders stay
lenient; a breaking change bumps the schema number and ships a migration.

## Releasing a web version (checklist)

1. Bump `WEB_VERSION` and the `<title>` in `web/index.html`.
2. Copy to `web/versions/v<X.Y.Z>/index.html`; add a line (date + one-line summary) to
   `web/versions/index.html`.
3. Update the feature doc status and `docs/CHANGELOG.md`.
4. Commit `web vX.Y.Z: <summary>`, push (Pages deploys), `git tag web-vX.Y.Z && git push --tags`.

## Releasing an app version (checklist)

1. Bump `MARKETING_VERSION`; set `RecallWebVersion` in `ios/project.yml`.
2. Commit `app vX.Y.Z: <summary>`, push, `just watch` until green.
3. `git tag app-vX.Y.Z <commit> && git push --tags`; add the row to `docs/CHANGELOG.md`
   (version, build = run number, commit, web version implemented).
4. `just ipa` → the user installs with iloader.

## Frozen means frozen

Never edit a file under `web/versions/`, a released tag, or an old handoff. Fix forward with a new
version.
