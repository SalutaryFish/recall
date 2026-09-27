# Workflow — web first, then native

| | |
|---|---|
| **Document** | foundation/WORKFLOW · **v1.0** · 2026-09-27 |
| **Rule set by** | the user (2026-09-27): "we should never add a feature first to the app directly" |

## The rule

**Every new feature, behaviour or visual change is built in the web prototype first, tested by the
user on their phone, and approved — only then is it added to the iOS app.** Never the other way
round. The app is the *port* of an approved prototype version, never the place where designs are
explored.

Why: the web prototype changes in minutes and runs on the phone instantly, while the native app
needs a CI build and a sideload. Designs are judged in the hand, so iterate where iteration is cheap.

## The pipeline

| Stage | What happens | Exit criterion |
|---|---|---|
| **0 · Design** | A feature doc `docs/features/F-NNN-<slug>.md` is written: problem, decisions, behaviour, visuals, open questions. | The user has answered the open questions that block a first prototype. |
| **1 · Web prototype** | Build it in `web/index.html`. Bump `WEB_VERSION` (MINOR for a feature). Freeze a copy in `web/versions/v<X.Y.Z>/`, list it in `web/versions/index.html`, push (GitHub Pages deploys it), tag `web-v<X.Y.Z>`. | It works on the phone at https://salutaryfish.github.io/recall/. |
| **2 · Phone testing** | The user tries it. Each round of changes is a new PATCH version (frozen, tagged) so every iteration can be compared. | The user says it's approved. The feature doc records **"Approved in web vX.Y.Z"**. |
| **3 · Native port** | Port logic to `RecallCore` first (with tests), then the SwiftUI views. Bump the app (MINOR), set `RecallWebVersion` to the approved web version, push, get CI green. | CI green; `just ipa` produces the IPA. |
| **4 · Device check** | The user installs with iloader and compares it with the approved web version. | The user confirms. The feature doc records **"Shipped in app vX.Y.Z"**; `docs/CHANGELOG.md` is updated. |

A feature doc's `Status` always shows its stage: `Idea → Design → Web (vX.Y.Z) → Approved (web vX.Y.Z) → Native (app vX.Y.Z) → Shipped`.

## What may go straight to the app

Only changes that don't alter how the app looks, feels or behaves: crash and bug fixes that restore
the approved behaviour, performance work, build/CI/tooling, data migrations, accessibility plumbing
that matches the approved design. They still bump the app's PATCH version.

Capabilities that only exist natively (Dynamic Island, Shortcuts, haptics, the share sheet) still
start in the web prototype as a **mock** (e.g. a drawn Dynamic Island, a "simulate shortcut" button)
or, if a mock is impossible, as a written spec in the feature doc that the user approves first.

## Testing the prototype on the phone

- **Published (normal):** push changes under `web/` → the "Web prototype" workflow deploys to
  GitHub Pages in about a minute. Latest: https://salutaryfish.github.io/recall/ · every frozen
  version: https://salutaryfish.github.io/recall/versions/
- **Unpushed changes:** `just serve` on the laptop, then open the printed `http://<laptop-ip>:8000/`
  on the phone (same Wi-Fi). NixOS's firewall blocks the port by default — the recipe prints the
  command to open it (or add `networking.firewall.allowedTCPPorts = [ 8000 ];`).
- Tip: "Add to Home Screen" in Safari runs the prototype full-screen. Each version's data lives in
  that browser (localStorage), separate from the native app.

## Every session

- Start: read the latest handoff (`docs/handoff/README.md`), then the foundation docs if new to them.
- End: write a new handoff version. Update `docs/CHANGELOG.md` if anything was released.
