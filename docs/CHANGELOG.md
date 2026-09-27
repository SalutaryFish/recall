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
| 2.1.0 | 2026-09-27 | `web-v2.1.0` | **F-001 background tracks — first prototype.** ♫ tracks play alongside the main task: a quiet mini bar above the live bar; a rail, chip and ribbon lane on the day; a track sheet; stop → Stop everything / Keep (promotion); manual or auto "next" with typed lengths and a queue; sleep timer. YouTube titles come from oEmbed. Sources are a provider registry. **Data:** store `recall.v2` (today's v1 data is migrated, v1 untouched); data is kept across days (only a samples-only store is refreshed); timers are midnight-safe. **Fixes:** the ribbon's now-marker and scrub cursor were 20 px (~80 min) off; tapping the live bar now opens the live screen; a sheet opened just as another closed could come up empty. |
| 2.0.0 | 2026-09-27 | `web-v2.0.0` | Baseline — the v2 interactive prototype (formerly `Recall.proto.html`), now version-stamped and frozen at `web/versions/v2.0.0/`. |

**Next planned:** phone testing of web 2.1.0 → PATCH versions (2.1.1, …) until F-001 is approved →
port to the app as app 0.2.0.

## Spec

| Spec version | Date | Notes |
|---|---|---|
| 2.0 | 2026-09-23 | `docs/spec/Recall-UX.md` — media-first redesign, gesture spec, native data model. |
