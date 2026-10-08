# Changelog

Every released version, newest first. Web and app versions are independent numbers; the
**Implements web** column says which approved prototype an app build was ported from.

## App

| App version | Build | Date | Commit / tag | Implements web | Notes |
|---|---|---|---|---|---|
| 0.1.1 | CI run # | 2026-09-27 | tag `app-v0.1.1` once CI is green | 2.0.0 | Shows its version, build number and implemented web version in the You sheet; build number now comes from the CI run. *Run 36295377639 built the IPA, but one UI test (`testHoldCaptureAndSlideStartsAFrequent`, the toast lookup) failed, so it's not tagged yet.* |
| 0.1.0 | 1 | 2026-09-27 | `0c83113` · `app-v0.1.0` | 2.0.0 | First native build: full prototype port, all 13 gestures, CI + IPA. |

## Web prototype

| Web version | Date | Tag | Notes |
|---|---|---|---|
| 2.2.1 | 2026-10-08 | `web-v2.2.1` | **Capture fixes from the code review**, confirmed in headless Chromium (21 checks + 2,400 random steps, all green). **Captures are placed by when they happened**, not by what is live now — a burst put a track 15 min before its own task, and the native app (which reads the file on open) would have hit this on every read; tasks and tracks are walked forward between events. **Pending captures no longer count as tracked time** (principle 5): out of the totals, ribbon, archive and Insights until kept. **The gap, answered:** a pending capture sits in the gap it explains, with KEEP / DISCARD / + FILL (STRAIGHT IN fills it by itself). **Captures never overlap your entries:** a clashing app session stays pending even in STRAIGHT IN, and KEEP takes only the untracked part. **DISCARD no longer deletes your own track** alongside a capture. **Switching away from captured music** closes its break, records what played, and carries it on as a track. A hand-made track **adopts** capture instead of a second track opening. STRAIGHT IN entries show **CAPTURED**. **Settings survive the daily sample refresh** (mode, apps, Stop choice, max tracks, theme, density were reset every morning). Smaller: Stop ends a block to the second (a minimum length left it "live" for capture into the future); re-time moves a block's tracks with it; Split no longer shares breaks between the halves; a change is saved when the page is hidden; RESUME/PAUSE toasts only report real changes; SHORT SESSION 20s simulator button. |
| 2.2.0 | 2026-10-08 | `web-v2.2.0` | **F-002 automatic capture — first prototype.** Recall logs what you watch and listen to by itself: in the app a tweak inside LiveContainer appends JSON events, here that stream is **simulated** with the real contract's shape, and `capIngest` is the rule set that will port to RecallCore. Captured media opens and fills an F-001 track by itself (rail, chip, ribbon lane); nothing live → it becomes the main task. Pending captures are reviewed as **one capture card per stretch** (KEEP ALL / expand / drop one), so a burst of short video can't bury the day. A gap now offers what played through it. Layer-2 detail (a search) rides on the item. **Settings** (You): CAPTURE on/off, ENTRIES ENTER AS PENDING / STRAIGHT IN, SHORTEST SESSION, per-app toggles, and a simulator panel. **Fixes:** a capture card no longer truncates the span of the row above it (the live row lost its rail); capture settings were rebuilt on every read, losing writes; the ⏸/⏭ glyphs don't exist in these fonts (CSS-drawn now). |
| 2.1.0 | 2026-09-27 | `web-v2.1.0` | **F-001 background tracks — first prototype.** ♫ tracks play alongside the main task: a quiet mini bar above the live bar; a rail, chip and ribbon lane on the day; a track sheet; stop → Stop everything / Keep (promotion); manual or auto "next" with typed lengths and a queue; sleep timer. YouTube titles come from oEmbed. Sources are a provider registry. **Data:** store `recall.v2` (today's v1 data is migrated, v1 untouched); data is kept across days (only a samples-only store is refreshed); timers are midnight-safe. **Fixes:** the ribbon's now-marker and scrub cursor were 20 px (~80 min) off; tapping the live bar now opens the live screen; a sheet opened just as another closed could come up empty. |
| 2.0.0 | 2026-09-27 | `web-v2.0.0` | Baseline — the v2 interactive prototype (formerly `Recall.proto.html`), now version-stamped and frozen at `web/versions/v2.0.0/`. |

**Next planned:** phone testing of web 2.2.1 (F-001 **and** F-002 together) → PATCH versions
(2.2.1, …) until both are approved → port to the app as app 0.2.0, plus the `RecallTweak` dylib.

## Spec

| Spec version | Date | Notes |
|---|---|---|
| 2.0 | 2026-09-23 | `docs/spec/Recall-UX.md` — media-first redesign, gesture spec, native data model. |
