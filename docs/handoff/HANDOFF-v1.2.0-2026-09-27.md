# Recall — project handoff

| | |
|---|---|
| **Handoff version** | **v1.2.0** |
| **Date** | 2026-09-27 |
| **Previous version** | [v1.1.0](HANDOFF-v1.1.0-2026-09-27.md) (rules, docs layout) · [v1.0.0](HANDOFF-v1.0.0-2026-09-27.md) (architecture; paths outdated) |
| **Repo** | https://github.com/SalutaryFish/recall · local `~/Development/active/ui-design/Recall` |
| **Commit** | `caab935` (main) · tags `web-v2.1.0`, `web-v2.0.0`, `app-v0.1.0` |
| **Web prototype** | **web v2.1.0** — https://salutaryfish.github.io/recall/ (Pages run 36298678217, green) |
| **App** | app v0.1.1 · implements web 2.0.0 · **not tagged** (see §6) |
| **Written by** | Claude (Opus 5.5) |

## 1. TL;DR

- **F-001 background tracks is built as web v2.1.0** and published. It's the first prototype,
  now waiting for the user's phone testing. The feature doc
  (`docs/features/F-001-background-tracks.md`, v0.3) has the status, both new decisions, the
  defaults, "where things are" and the test checklist, left unticked for the user.
- The iOS app was **not touched**, per the web-first rule.
- **Next:** the user tests on the phone → each round of feedback is a PATCH (2.1.1, …) → once
  approved, record "Approved in web vX.Y.Z" and port to RecallCore + SwiftUI as app 0.2.0.

## 2. What the user decided this session

1. **Mini bar above the main live bar**, not under it: ⊕ covers the slot under the bar.
2. **Data is kept across days** in the prototype. Only a samples-only store is re-seeded on a new
   day, and timers are midnight-safe. Web v2.0.0 wiped everything on the first open of each day.

Everything else that looks like a decision is a **default**. Each is listed in the F-001 doc under
"Defaults in web v2.1.0", so the user can confirm or change it:
- switching carries tracks over;
- promotion ends the track and starts a new main entry at the same moment;
- the track name lives in `title`;
- YouTube titles come from oEmbed;
- times keep seconds;
- the open-question defaults. Q1 and Q4 have switches in You → F-001 OPEN QUESTIONS.

## 3. What's in web v2.1.0 (`web/index.html`)

| Section | What it holds |
|---|---|
| CSS "5b · BACKGROUND TRACKS" | the dock (mini bars), rail, chip, ribbon lane, sheet pieces; `--dock-h` raises the toast and the timeline padding |
| §4 store | `recall.v2` + `loadStore()`. Migration from v1 copies today's data and never writes v1. The `sample` rule. `nowAt(date)` / `dayDiff` / `rebase` for midnight-safe minutes. Lane helpers: `isMain`, `entriesFor` and `liveEntry` are main-lane only, plus `liveTracks`, `itemsOf`, `currentItem`, `playingMins`, `playSpans`, `trackPlaying`, `deleteEntry` (cascades) |
| §4b providers | `PROVIDERS` registry (`id · name · glyph · matches(url) · resolve(url) · caps`); `SOURCES` is derived from it; `parseInput`, `resolveLink` (cached), `linkFallback`, `parseLen` |
| §4c track model | `startTrack · startItem · addItem · pauseTrack · resumeTrack · stopItem · stopTrack · setAdvance · setSleep · playEndOf · tickTracks · stopMain`. These are pure changes to `S`, named to port 1:1 to RecallCore |
| §5 today | row spans → `decorateRow` / `railNode` / `chipNode`; `refreshLiveRow` (every 30 s); ribbon lane |
| §6 / 6b live | carry-over in `startBlock`; `stopLive` stops everything; `askStop` → stop sheet; dock and mini bars; the 1 s tick runs `tickTracks`; sheets: start track, add item (paste + oEmbed preview), track sheet, stop main |
| You sheet | STOP WITH ♫ PLAYING (ASK/STOP ALL), KEPT TRACK BECOMES (ITEM/TRACK), MAX TRACKS (1/2) |

**v2.0.0 bugs fixed along the way** (all in `docs/CHANGELOG.md`):
- The ribbon's now-marker, scrub cursor and bubble were 20 px (~80 min) off.
- Tapping the live bar did nothing: `drag()` only sets `tap` for long-press drags, so the bar now
  checks "never passed the intent lock".
- `openSheet` retargeted the spring on the next frame, so a closing sheet that came to rest in
  between wiped the new sheet's content.

## 4. How it was verified

- A **Deno script driving headless Chromium over the DevTools protocol** (402×874, a local
  `python3 -m http.server`). It ran **121 checks, all green, with no page errors**:
  - every item in the F-001 checklist, through the real UI (taps and swipes via
    `Input.dispatchMouseEvent`);
  - real YouTube oEmbed lookups;
  - auto-advance and sleep timers, by back-dating stored times;
  - invariants after every step;
  - reload persistence and the next-day rules;
  - midnight-crossing entries;
  - the v1 → v2 migration, and that frozen web v2.0.0 still runs on its own v1 data.
- A smoke test of the existing flows (quick add, backfill, detail, share, You, tabs, density,
  split, delete, arc) passed.
- Screenshots were reviewed in light and dark at all three densities. That review caught the ⏸
  glyph not rendering (now CSS-drawn), a missing chip for a just-started track, and a stray "·" and
  "0%" on promoted typed items. All fixed.
- After deploying, the title lookup was re-checked **from https://salutaryfish.github.io** in the
  headless browser.
- The script lived in the session scratchpad and is **not in the repo**. If phone-testing rounds
  need regression checks, it could become `just web-test`. That would be new tooling, so ask the
  user first.

## 5. Known limitations (by design for this version)

- A promoted main task has no "next" (a main-lane track is a follow-up).
- Deferred to later versions: on-demand promote/demote, retro-editing, track frequents / ⊕ ♫ slot,
  the Insights soundtrack section.
- Retiming a main task doesn't move its tracks. Rails and chips are drawn by time overlap, so they
  stay honest about when the media actually played.
- A block that crosses midnight stays on its start day (the next day's page doesn't show it).
- Migrated v1 entries count as user data. After updating, **Reset** in You loads the new sample
  days with tracks.

## 6. Open items outside F-001

- **App v0.1.1 CI** (run 36295377639): the IPA built, but the UI test
  `testHoldCaptureAndSlideStartsAFrequent` failed: no element with the `toast` identifier was
  found. It passed in the previous run (36291417879), so it's probably timing-flaky: the toast
  hides after ~1.9 s. It's not tagged. Look at it before tagging `app-v0.1.1`; this counts as CI
  work, so it may go straight to the app.

## 7. Next steps (in order)

1. The user tests web v2.1.0 on the phone (F-001 checklist and the two switches in You). Each
   round of changes is a new PATCH: bump `WEB_VERSION` and `<title>`, freeze
   `web/versions/v2.1.x/`, add a line to the versions list, the CHANGELOG and the F-001 doc,
   commit `web v2.1.x: …`, push, tag.
2. Once approved: the F-001 doc records "Approved in web vX.Y.Z". Answer its 4 open questions from
   what was chosen.
3. Port: RecallCore first (the §4c functions map 1:1; `LogEntry` gains `lane`, `parentID`,
   `pauses`, track fields; the `MediaSource` enum → `MediaProvider` registry), with tests, then
   SwiftUI. App 0.2.0 with `RecallWebVersion` = the approved version.

## 8. Environment reminders

- `gh` exists only inside `nix develop`, and the repo's credential helper needs it, so push with
  `nix develop --command git push`.
- The headless Chromium and Deno used for testing are the system ones
  (`/etc/profiles/per-user/username/bin/`).
- The repo folder is `~/Development/active/ui-design/Recall`. Older handoffs name it
  `AI-UI-004-Recall`.
