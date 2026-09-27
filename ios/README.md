# Recall for iPhone

The native build of the web prototype in `../web/index.html`, specified by `../docs/spec/Recall-UX.md`.
New features go into the web prototype first — see `../docs/foundation/WORKFLOW.md`.
SwiftUI, iOS 26+ (built with the iOS 27 SDK), no dependencies.

## Getting the app onto your phone

There is no Mac in this setup: GitHub Actions compiles the app and publishes an
**unsigned IPA**, and iloader signs and installs it with your Apple ID.

```sh
nix develop            # or: direnv allow
just ipa               # newest green build → dist/Recall-<run>-<sha>.ipa
iloader                # pick the IPA from dist/, install over USB
```

A free Apple ID signature lasts 7 days — re-run iloader to refresh.
If the app crashes on launch: `just crashes` pulls the reports into `crashes/`.

## Building

| What | Where |
|---|---|
| Logic (`RecallCore`: model, day math, seed, insights) | `just core-test` — runs here on Linux |
| The app | `.github/workflows/ios.yml` on the `xcode-27` runner — `just ci`, `just watch`, `just logs` |
| Xcode project | generated from `project.yml` by XcodeGen on CI (never committed) |

## Layout

```
RecallCore/        pure Swift, Foundation only — every mutation the app can make, unit-tested
Recall/App         entry point, root view, chrome layer (tab bar, ⊕, live bar, live screen, toast)
Recall/Store       AppStore (@Observable), persistence (JSON, atomic, file-protected)
Recall/Design      tokens, fonts, springs (CADisplayLink integrator), haptics, hatch, components
Recall/Gestures    UIKit recognizers: horizontal swipe with intent lock, lift-to-retime
Recall/Today       header + ribbon, rows, cards, gaps, empty state
Recall/…           Archive, Insights, Live, Capture sheets, Detail, You
RecallTests/       hosted unit tests (fonts registered, persistence, store)
RecallUITests/     launch + gesture smoke tests
```

## Gestures

| # | Gesture | Where | Result |
|---|---|---|---|
| G1 | Scroll | timeline | momentum scroll |
| G2 | Pinch | timeline | cycle density: transcript → proportional → ribbon (the pill mirrors it) |
| G3 | Swipe left | a row | EDIT / SPLIT / DELETE |
| G4 | Swipe right past 45% | a row | AGAIN — start it now |
| G5 | Hold 0.35 s, drag | a row | re-time in 5-minute steps; hold without moving opens the detail |
| G6 | Hold ⊕ 0.28 s, slide, release | ⊕ | start a frequent from the arc (tap ⊕ for quick add) |
| G7 | Drag up / down | live bar / live screen | open / close the tracking screen |
| G8 | Drag | any sheet | native detents |
| G9 | Swipe sideways | the header | previous / next day (not into the future) |
| G10 | Pull down past 80 pt | top of the timeline | how yesterday ended |
| G11 | Drag | the 24h ribbon | scrub — the timeline follows |
| G12 | Hold | a heatmap day | preview; tap opens the day |
| G13 | Tap | a session card | expand its items |

Every gesture also has a VoiceOver action and a visible fallback.

## On-device checklist

- [ ] Launches into Today with the sample day; the live bar is ticking
- [ ] G1–G13 above, each once; thresholds tick (haptics) exactly once per crossing
- [ ] Quick add: type → autocomplete; frequent tile starts a block; **Past** opens Fill the gap
- [ ] Fill the gap: FROM/TO wheels, attention, "Add to the day"
- [ ] Detail: rename, change times, place, thought; Split; Delete; Do this again
- [ ] ⤓ Save a link: copy a YouTube link in Safari → paste → title resolves → Add to today
- [ ] Live screen: + note, + photo, + media, Switch, Stop block
- [ ] Archive: heatmap hold/tap, Re-live that day, search → detail
- [ ] Insights reads sensibly; ◐ flips theme; You → theme AUTO/LIGHT/DARK
- [ ] You → SAMPLE DATA → CLEAR leaves only what you logged; relaunch keeps it
- [ ] Settings → Accessibility → Reduce Motion: springs become instant, nothing breaks
