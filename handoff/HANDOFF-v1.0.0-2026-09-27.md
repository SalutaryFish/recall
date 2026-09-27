# Recall — project handoff

| | |
|---|---|
| **Handoff version** | **v1.0.0** (first) |
| **Date** | 2026-09-27 |
| **Previous version** | — |
| **Repo** | https://github.com/SalutaryFish/recall (public) · local: `~/Development/active/ui-design/AI-UI-004-Recall` |
| **Commit at time of writing** | `0c83113` (main) |
| **Last CI run** | [36291417879](https://github.com/SalutaryFish/recall/actions/runs/36291417879) — **both jobs green** |
| **App version** | 0.1.0 (build 1) · bundle id `dev.recall.Recall` |
| **Written by** | Claude (Opus 5.5) at the end of the session that built the app |

> Read this whole file before touching code. It is the fastest way to understand the project,
> the build pipeline (there is **no Mac**), and the traps already stepped in. Older handoffs are
> never edited; the newest version in `handoff/` is authoritative (see `handoff/README.md`).

---

## 1. TL;DR — where things stand

- **Recall** is a personal "transcript of a day" app (media-first). The **design spec** is
  `Recall-UX.md` (v2.0) and the **interactive web prototype** is `Recall.proto.html`. Both predate
  the native app and remain the source of truth for UI/behaviour.
- A **native SwiftUI iPhone app** now lives in `ios/`. It matches the prototype closely, implements
  all 13 specified gestures (G1–G13), and **compiled on its first CI build**.
- **CI is green** on GitHub Actions (`xcode-27` runner, Xcode 27.0, iOS 27 SDK): RecallCore tests,
  an unsigned device build packaged as an **IPA**, plus simulator unit + UI tests.
- The user installs the IPA with **iloader** (free Apple ID; re-sign every 7 days).
- **Not yet done:** feedback from a real device. Simulator UI tests prove gestures *fire*, not that
  they *feel* right. Expect a round of on-device polish.
- **Next feature (designed, not built):** a *background media track* — music/YouTube running
  alongside the main live task. Full brainstorm in §14. Four open questions for the user are listed
  there; ask them before implementing.

---

## 2. The product in one paragraph

Recall answers "where did my time and attention actually go today?". A day reads like a log:
mono timestamps down a spine, cards for blocks / media / sessions / moments, hatched rows for
untracked gaps (tap to backfill), a 24-hour ribbon summarising the day, one clay accent reserved
for whatever is **live**. Media carries source, creator, duration vs. consumed, and an honest
`active` / `background` attention flag. Auto-captured entries arrive *pending* and must be
confirmed. Tabs: **Today · Archive · ⊕ · Insights · You** (You opens a sheet).

**Design sources, in priority order**
1. `Recall-UX.md` — spec v2.0: principles, critique of v1, tokens (§4), gestures (§5), screens (§6),
   motion (§7), data model (§8), open questions (§9).
2. `Recall.proto.html` — the working prototype (vanilla JS, ~2,000 lines). Open it in a browser.
   The native app ported its logic line-for-line in places (seed, `rowHeight`, gaps, ribbon, arc
   geometry, thresholds).
3. `Recall.dc.html`, `v2_Recall.dc.html` (bundled copy), `ios-frame.jsx`, `support.js` — the older
   v1 design canvas. Superseded; kept for history.

**Decisions already made with the user** (don't re-litigate)
- Faithful **custom chrome** (mono tab bar, ⊕ FAB, live bar, swipe rails) + **native iOS sheets**
  styled with the bone background and 28 pt corners. Partial-height sheets use the iOS 26/27
  floating-inset shape — accepted.
- **Public** repo (free macOS CI minutes).
- **Sample data is seeded on first launch.** You → SAMPLE DATA → **CLEAR** removes only
  sample-flagged data; **LOAD** brings samples back.
- Deployment target **iOS 26.0**, built with the **iOS 27 SDK** (lets a `macos-26` fallback runner
  still build; no iOS-27-only APIs are used).
- Portrait iPhone only. Local-only data (no accounts, no sync).

---

## 3. Environment and tooling

- The user is on **NixOS x86_64** with **no Mac**. The iOS app is only ever compiled by
  **GitHub Actions**. Locally we can build and test the pure-Swift core only.
- **Dev shell:** `nix develop` (or `direnv allow`, `.envrc` = `use flake`).
  `flake.nix` pins **nixpkgs-unstable** and provides:
  - all platforms: `gh`, `actionlint`, `just`, `jq`, `yq-go`, `swiftformat`, `imagemagick`
  - Linux: `swift` 5.10.1, `swiftpm`, `swiftPackages.{Dispatch,Foundation,XCTest}`,
    `sourcekit-lsp`, **`iloader`** (unstable-only package), `libimobiledevice`
  - Darwin (if a Mac ever appears): `xcodegen`, `xcbeautify`
  - `shellHook` exports `LD_LIBRARY_PATH` for the Swift runtime libs (see §5).
- **justfile** (run `just` to list):

  | Recipe | What it does |
  |---|---|
  | `core-test` | RecallCore tests (Linux: regenerates the test entry point, `swift run … RecallCoreTests`; macOS: `swift test`) |
  | `fmt` / `lint` | swiftformat (conservative config `ios/.swiftformat`) / swiftformat `--lint` + `actionlint` |
  | `ci [branch]` | `gh workflow run ios.yml` |
  | `watch` | follow the latest CI run until it ends |
  | `logs` | failed-step logs of the latest run (tail 400) |
  | `ipa` | download the newest **successful** run's `Recall-ipa` artifact into `dist/` |
  | `publish` | one-time: `gh auth refresh -s workflow`, push, watch (already done) |
  | `crashes` | `idevicecrashreport -e crashes/` from a USB-connected iPhone |

- **GitHub:** account **SalutaryFish**. The `gh` token now has scopes `gist, read:org, repo,
  workflow` (the `workflow` scope is required to push `.github/workflows/*`). The SSH key in
  `~/.ssh` is **not** registered on GitHub → use HTTPS. This repo has **repo-local** git config:
  `user.name=SalutaryFish`, `user.email=235790561+SalutaryFish@users.noreply.github.com`,
  `credential.helper=!gh auth git-credential` (works inside the dev shell, where `gh` exists).
  The user's *global* git identity is a placeholder — don't change it.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (per the harness).

---

## 4. Build → test → install loop

```
edit code ──► git push ──► GitHub Actions (xcode-27) ──► just watch / just logs
                                    │
                                    ▼
                 artifact Recall-ipa (unsigned .ipa) ──► just ipa ──► dist/Recall-<run>-<sha>.ipa
                                                                         │
                                                        iloader (USB, free Apple ID) ──► iPhone
```

**Workflow** `.github/workflows/ios.yml` (triggers: push/PR touching `ios/**` or the workflow;
`workflow_dispatch` with input `runner` = `xcode-27` (default) | `macos-26` fallback; concurrency
cancels older runs; `defaults.run.working-directory: ios`):

- **Job `build` — "Build unsigned IPA"**
  1. `actions/checkout@v7` → print `xcodebuild -version`, `swift --version`
  2. `scripts/ci.sh install-xcodegen` (pinned release zip `2.46.0`, Homebrew fallback)
  3. `swift test --package-path RecallCore`
  4. `xcodegen generate` (from `ios/project.yml`; the `.xcodeproj` is never committed)
  5. `xcodebuild build -scheme Recall -configuration Release -destination 'generic/platform=iOS'
     CODE_SIGNING_ALLOWED=NO …` piped through `xcbeautify`
  6. zip `Payload/Recall.app` → `Recall-<run>-<sha7>.ipa` → `actions/upload-artifact@v7`
     (name `Recall-ipa`, 14-day retention)
- **Job `sim-tests` — "Simulator tests"** (parallel): XcodeGen → `scripts/ci.sh simulator` picks
  the newest iOS runtime and prefers iPhone 17 Pro / 18 Pro → `xcodebuild test` (RecallTests +
  RecallUITests; default ad-hoc simulator signing). On failure the `.xcresult` bundle is uploaded.

**Timing:** ~3 min for `build`; ~8–10 min for `sim-tests` (UI tests boot a simulator).
**Docs-only commits** (e.g. `handoff/`) don't trigger CI because of the path filter.

**Installing:** iloader is a GUI app the user runs themselves. **Never launch iloader** from a tool
call (it opens a window). Free-Apple-ID installs expire after 7 days.

---

## 5. Gotchas learned the hard way

| Problem | Fix in place |
|---|---|
| nixpkgs Swift 5.10: compiled manifests/tests can't find `libdispatch.so` etc. | `flake.nix` `shellHook` exports `LD_LIBRARY_PATH` for Dispatch/Foundation/XCTest. Plain `mkShell` (the `swiftPackages.stdenv` override made it worse). |
| nixpkgs Swift has **no `libIndexStore`** → SwiftPM can't discover XCTest cases on Linux | `RecallCore/Package.swift` uses `#if os(Linux)` to build the tests as an **executable target** driven by `Tests/RecallCoreTests/main.swift` (an `XCTMain([...])` list generated by `ios/scripts/linux-test-main.sh`; `just core-test` regenerates it). On macOS it's a normal `testTarget` that excludes `main.swift`. **When you add a test, run `just core-test` (or the script) so Linux sees it — and commit the regenerated `main.swift`.** |
| corelibs Foundation on NixOS has **no tzdata** (`TimeZone(identifier:)` → nil; `TZDIR` ignored) | Tests fall back to UTC; the one DST assertion only runs when Europe/London loads (it does on macOS CI). |
| `JSONEncoder.dateEncodingStrategy = .iso8601` **crashes** on Linux (needs tzdata) | RecallCore has its own exact `ISO8601` enum (Hinnant civil-date algorithms); `RecallCodec` uses it on every platform. |
| Command sandbox blocks **SSH**; also the local key isn't on GitHub | Use HTTPS + the repo-local gh credential helper. Tool calls that need GitHub/network sometimes need the sandbox disabled. |
| `gh auth refresh` is interactive | Run with `GH_PROMPT_DISABLED=1 BROWSER=true` in the background; it prints a device code for github.com/login/device. |
| `pkill -f <pattern>` killed its own shell | Use the bracket trick: `pgrep -f '[g]h auth refresh'`. |
| SDK name collisions (`ObjectiveC.Category`, SwiftUI `@Entry` macro, …) | Core types are named **`LogEntry`, `EntryCategory`, `RecallData`, `RecallCodec`** — keep that style for new public types. |
| swiftformat 0.63 defaults would rewrite deliberate code (e.g. `redundantType` strips explicit `@State` types) | `ios/.swiftformat` disables those rules; only whitespace/ordering rules run. |
| The first CI failure was a CI script bug (`\"` inside a bash single-quoted Python string) | `scripts/ci.sh simulator` now uses a quoted heredoc, and the step fails if the UDID is empty. |

---

## 6. Repository map

```
AI-UI-004-Recall/                      (= github.com/SalutaryFish/recall)
├── Recall-UX.md                       design spec v2.0 — READ FIRST for behaviour questions
├── Recall.proto.html                  interactive prototype (source of truth for UI)
├── Recall.dc.html, v2_Recall.dc.html, ios-frame.jsx, support.js, .thumbnail   v1 canvas (history)
├── README.md                          short pointer
├── flake.nix / flake.lock / .envrc    dev shell (§3)
├── justfile                           tasks (§3)
├── .github/workflows/ios.yml          CI (§4)
├── handoff/                           THESE DOCS (README.md = index)
└── ios/
    ├── README.md                      install steps, gesture table, on-device checklist
    ├── project.yml                    XcodeGen spec (targets Recall, RecallTests, RecallUITests)
    ├── .swiftformat                   conservative formatter config
    ├── scripts/
    │   ├── ci.sh                      install-xcodegen | simulator (used by the workflow)
    │   ├── linux-test-main.sh         regenerates RecallCoreTests/main.swift for Linux
    │   ├── fetch-fonts.sh             downloads the OFL fonts (already committed)
    │   ├── make-icon.sh + icon/*.svg  renders AppIcon PNGs with ImageMagick
    ├── RecallCore/                    pure-Swift logic package (Foundation only) — §7
    │   ├── Package.swift              tools 5.10; Linux/macOS split for tests
    │   ├── Sources/RecallCore/        Model, Day, Timeline, Mutations, Seed, Ingest, Suggestions,
    │   │                              Insights, Formatting, Codec, ISO8601
    │   └── Tests/RecallCoreTests/     RecallCoreTests.swift (30 tests) + generated main.swift
    ├── Recall/                        the SwiftUI app — §8
    │   ├── App/        RecallApp (entry), RootView (+ ChromeLayer, ChromeLayout)
    │   ├── Store/      AppStore (@Observable, all intents), Persistence (JSON on disk)
    │   ├── Design/     Palette, Typography, Motion (SpringValue), Haptics, Hatch, Components
    │   ├── Gestures/   Recognizers (HorizontalSwipeGesture, LiftGesture)
    │   ├── Today/      TodayScreen, DayHeader (+DayRibbon, Pill, PagerOffset, ScrollChrome),
    │   │               TimelineRows (+GapRow, EmptyDayView, YesterdayPeek), EntryRow (+SwipeRig,
    │   │               SpineDot), EntryCard (+PendingCard, MetaLine, ProgressLine, AttentionLabel)
    │   ├── Archive/    ArchiveScreen (+HeatCell, DayPreviewCard, OnThisDayCard, StatCard, SearchResults)
    │   ├── Insights/   InsightsScreen (+RecapCard, SplitBar, SourceList)
    │   ├── Live/       LiveBar (+StatusBarVisibility), LiveScreen (+PulsingDot)
    │   ├── Capture/    CaptureButton (+ArcModel, ArcOverlay), FrequentsGrid, QuickAddSheet
    │   │               (+SuggestionList), BackfillSheet, ShareCaptureSheet (+LinkTitle)
    │   ├── Detail/     EntryDetailSheet (+CompletionRing, LogEntry.placeText/noteText)
    │   ├── You/        YouSheet
    │   ├── Chrome/     SheetHost (+FittedSheet), TabBar, Toast (ToastLayer)
    │   └── Resources/  Assets.xcassets (AppIcon light+dark, LaunchBackground, AccentColor),
    │                   Fonts/ (Newsreader variable + italic, IBM Plex Mono 400/500, OFL licences)
    ├── RecallTests/RecallTests.swift       4 hosted unit tests
    └── RecallUITests/RecallUITests.swift   4 UI smoke/gesture tests
```

Generated, never committed: `ios/Recall.xcodeproj`, `ios/Recall/Info.plist` (XcodeGen writes it
from `project.yml` → `info.properties`), `ios/build/`, `.build/`, `dist/`, `crashes/`.

---

## 7. RecallCore (the logic package)

Pure Swift + Foundation; compiles with Swift 5.10 (Linux) and Swift 6.4 (Xcode 27); every public
type is `Codable, Hashable, Sendable` where relevant. **All state changes the app can make are
functions here**, unit-tested on Linux.

**Model (`Model.swift`)** — spec §8 with absolute `Date`s:
- `LogEntry { id, kind (block|media|moment|session), start, end? (nil = live), title,
  category: EntryCategory, tags, place?, people?, source: MediaSource?, creator?, durationMs?,
  consumedMs?, attention (active|background)?, items: [SessionItem]?, origin (manual|share|auto),
  confidence?, status (confirmed|pending), note?, meta?, photos?, url?, sample? }`.
  Lenient custom decoder: unknown enum values/missing fields never make the archive unreadable.
  Helpers: `isLive, isPending, isSample, isBackground, completionPercent, mediaItemCount`.
- `EntryCategory` = sleep · life · focus · social · media · `mediaBackground` (JSON `"mediabg"`) —
  drives ribbon tones.
- `MediaSource` (youtube, tiktok, spotify, netflix, podcast, kindle, web) with `label` and a
  placeholder `glyph` (U+FE0E text presentation).
- `Frequent { glyph, name, category, uses, hours, sampleUses? }`, `Density` (transcript,
  proportional, ribbon), `ThemePreference` (auto, light, dark), `Counters` (mediaSaved + sample
  baselines), `RecallData` (everything persisted: entries, history, frequents, density, theme,
  counters, simulateAutoCapture, hasSamples, hintsShown; `defaultFrequents` = the prototype's 8).

**Day math**: `Day` (`Day.swift`, local calendar day with key `yyyy-MM-dd`, DST-aware length,
Monday index, year-earlier). `DayTimeline` (`Timeline.swift`): `entries(on:)` (overlap; a
midnight-crossing entry shows on both days, clipped), `rows(for:)` → `[TimelineRow]` (entries +
gaps ≥ 20 min + trailing gap to now when nothing is live), `stats`, `ribbon` segments,
`rowHeight(minutes:density:)` (proportional `clamp(44+34·log2(1+m/10),44,300)`, ribbon
`clamp(1.5m,44,900)`), `retimeDelta` (0.75 min/pt, 5-min snap), fraction ↔ date, `entry(atOrBefore:)`.

**Mutations** (`Mutations.swift`, `extension RecallData`): `startBlock` (ends the live one),
`stopLive` (≥ 1 min), `again`, `split` (midpoint; items and consumed time shared out), `delete`,
`retime` (keeps length, clamps to the day and to now), `backfill`, `confirmPending`,
`setAttention` (moves media ↔ mediabg), `bumpFrequent`, `prunePending` (7-day expiry, §9.4),
`addShared`, `update`, **`clearSamples`** / **`loadSamples`**.

**Invariants** — at most one *foreground* live entry (`liveEntry`); pending entries always have an
end; sample data is exactly the `sample == true` entries + `history` + counter baselines +
`sampleUses`.

**Other modules** — `Seed.sampleSnapshot` (today up to "now" at the prototype's clock times, a live
"Deep work — Design", two past days, 67 days of heatmap history, a Lisbon year-ago day; LCG
`SeededRandom(seed: 20260923)` = the prototype's), `AutoIngest.makePending` (simulated
detections), `SharePool` + `SourceDetector` (URL host → source), `Suggestions` (topFrequents
weighted by hour, autocomplete, search), `InsightsBuilder.week`, `ArchiveMath` (month grid, fill,
level, on-this-day sentence), `Fmt` (fixed English tables: `SAT · 26 SEP 2026`, `1h05m`,
`1:24:06`), `RecallCodec` (+ `ISO8601`).

---

## 8. App architecture

**State** — `AppStore` (`Store/AppStore.swift`, `@Observable`, main actor) owns `data: RecallData`
plus UI state (`tab`, `day`, `sheet: SheetRoute?`, `toast`, `openSwipeRow`, `scrollToTopRequest`,
`pastedURL`). Every intent wraps a RecallCore mutation, animates with the gentle spring, fires a
haptic and a toast, then `scheduleSave()` (300 ms debounce → `Task.detached` atomic write).
`bootstrap()` loads or seeds; `-uiTesting` launch argument = temp storage, no simulation, no hints.
`applyTheme()` sets `overrideUserInterfaceStyle` on the windows (more reliable than
`preferredColorScheme(nil)`). `runAutoCaptureLoop()` = simulated ingest every 22–42 s.

**Persistence** (`Store/Persistence.swift`) — `Application Support/Recall/recall.json`, atomic,
`.completeFileProtectionUntilFirstUserAuthentication`; an unreadable file is **moved aside**
(`recall-unreadable-<ts>.json`), never overwritten; photos in `…/Photos/`; export JSON to temp dir
for `ShareLink`.

**Composition** — `RecallApp` → `RootView` (ZStack: bone background, the active screen, `ChromeLayer`)
with `.sheet(item: $store.sheet) { SheetHost }`. `ChromeLayer` is a full-screen, safe-area-ignoring
overlay positioned with `ChromeLayout` (prototype geometry: tab bar 58 pt + home inset; ⊕ centred
54 pt above the inset, i.e. 4 pt below the bar's top; live bar 6 pt above the bar; toast 150 pt from
the bottom). Only the active tab's screen is mounted. Screens scroll under the chrome via a
146 pt `safeAreaInset`.

**Design system** — `Palette` (every token from the prototype `:root`/`.dark`, dynamic light/dark;
`tone(_:)`, `heat` ramp, rail colours, live-screen colours). `Typeface` PostScript names:
`Newsreader16pt-Regular`, `Newsreader16pt-Italic`, `IBMPlexMono-Regular`, `IBMPlexMono-Medium`
(fonts registered via `UIAppFonts`; system serif/mono fallback). `Font.serif/.serifItalic/.mono`,
`View.sans(size, weight)` (Dynamic Type via `@ScaledMetric`; app capped at `.xxLarge`).
`Hatch` = CSS repeating-linear-gradient stripes in a `Canvas`. `Components` = cardSurface, Chip,
SegmentedPill, FieldList/FieldRow, TimeValueButton, WheelTimePicker (24 h), Primary/Secondary
button styles, PressScaleStyle, IconButton, SheetTitle/SheetSub/SectionLabel/PageHeader,
InputField, Thumb.

**Motion** — `SpringValue` (`Design/Motion.swift`): a CADisplayLink spring integrator (presets
snappy 400/32, standard 260/26, gentle 180/24; 240 Hz sub-steps; 120 Hz via
`CADisableMinimumFrameDurationOnPhone`). It exposes the *presented* value, so a finger can catch
an element mid-flight (spec §5.1). `Motion.project(pos, velocity)` = pos + v·0.12 s drives every
commit decision. Reduce Motion → instant. **Performance pattern:** only thin wrapper views read a
`SpringValue` (`PagerOffset`, `LiveBar`, `LiveScreenLayer`, `SwipeRig`, `StatusBarVisibility`), so
per-frame updates re-render tiny views, not screens. Clock text uses `TimelineView` (1 s timers,
per-minute durations). `ScrollChrome` holds per-scroll state; only `DayTitle` observes it.

**Gesture recognizers** (`Gestures/Recognizers.swift`, via `UIGestureRecognizerRepresentable`):
`HorizontalPanRecognizer` fails itself if the first ≥ 6 pt of movement is mostly vertical — the
spec's **directional intent lock**, so scrolling never half-opens rows. `LiftGesture` wraps a
0.35 s `UILongPressGestureRecognizer` (8 pt allowable movement) and reports window translation.

**Accessibility** — rows are combined elements with custom actions (Edit, Split, Delete, Do this
again, Move ±5 min; pending: Keep/Discard); ⊕ has "Start <frequent>" actions; the live bar has
Expand/Stop; heat cells, ribbon, split bar have labels. Identifiers used by UI tests: `capture`,
`tab.today|archive|insights|you`, `livebar`, `livebar.stop`, `freq.<name>`, `entry.<title>`,
`toast`, `sheet.quickAdd`, `pending.keep`, `samples.toggle`.

---

## 9. Swift 6 / Xcode 27 rules in force (follow them — each one avoids a CI round-trip)

- App target: Swift 6 language mode, **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**,
  approachable concurrency. Test targets override isolation to `nonisolated`; test methods are
  `@MainActor`.
- Value types that cross isolation or conform to protocols with nonisolated requirements are
  declared **`nonisolated`** (`SheetRoute`, `ToastMessage`, `AppTab`, `Persistence`). Codable
  models live in RecallCore (non-isolated) so background file writes stay Sendable-clean.
- Pass **closure literals**, not method references, into gesture callbacks and stored closures.
- Don't capture non-Sendable values (e.g. `WritableKeyPath`) in `Binding(get:set:)`.
- Mixed `CGFloat`/`Double` arithmetic is written explicitly (`CGFloat(x) * width`).
- `Text(verbatim:)` whenever a string contains `%` (interpolated `Text("…")` is a format string).
- Type every `@State` that isn't a trivial literal (Xcode 27 makes `@State` a macro: never assign
  at declaration *and* in `init`, never compose with other wrappers).
- Closure forms `.overlay { }` / `.background { }`; `foregroundStyle`; no `PreviewProvider`.
- `@preconcurrency import LinkPresentation`. Use `ContentBuilder`-safe code (no ambiguous
  `.overlay(Color…)`).
- Avoid custom `Shape`, `Layout`, `EnvironmentKey` and `PreferenceKey` conformances under default
  MainActor isolation, or mark them `nonisolated`; the app currently uses none.

---

## 10. Gesture map (spec §5 → code)

| # | Gesture | Implemented in |
|---|---|---|
| G1 | Scroll | `TodayScreen.timeline` (native `ScrollView`) |
| G2 | Pinch → density | `TodayScreen.pinch` (`MagnifyGesture`, >1.25 / <0.8; pill previews target) |
| G3 | Swipe left → EDIT/SPLIT/DELETE | `SwipeRig` + `HorizontalSwipeGesture` (rail 222 pt, opens at 33% projected) |
| G4 | Swipe right → AGAIN | `SwipeRig` (commits past 45% of the card, projected) |
| G5 | Hold → drag to re-time | `EntryRow` + `LiftGesture` (5-min ticks; < 8 pt moved → detail) |
| G6 | Hold ⊕ → arc | `CaptureButton` + `ArcModel`/`ArcOverlay` (280 ms, R 100, 152°→28°, 76 pt pick, 44 pt dead zone) |
| G7 | Live bar ↑ / screen ↓ | `LiveBar`, `LiveScreenLayer` (shared `SpringValue`; 0.6 / 0.4 projected) |
| G8 | Sheet detents | native sheets (`SheetHost`, `FittedSheet`) |
| G9 | Header swipe → day | `TodayScreen.headerDrag` + `PagerOffset` (30% projected; no paging into the future) |
| G10 | Pull down → yesterday's tail | `TodayScreen.scrolled/phaseChanged` (> 80 pt) + `YesterdayPeek` |
| G11 | Ribbon scrub | `DayRibbon` → `TodayScreen.scrub` (`ScrollViewReader.scrollTo`) |
| G12 | Heatmap hold → preview | `HeatCell` + `DayPreviewCard` (0.3 s) |
| G13 | Session tap → expand | `EntryRow.tap` → `EntryCard(expanded:)` |

---

## 11. Tests

- **RecallCore — 30 XCTest cases** (`just core-test` locally on Linux; `swift test` on CI):
  formatters, day arithmetic incl. DST, gaps/trailing gap/overlap, midnight clipping, stats,
  row heights, ribbon, retime snapping, start/stop/split/retime/backfill/pending expiry/attention,
  seed invariants (one live entry, nothing in the future, no overlaps, counts), clear/load samples
  keeps user data, on-this-day sentence, frequents ranking, autocomplete/search, week insights,
  month grid, heat fill, source detection, simulated ingest, shared media, ISO 8601, JSON
  round-trip + lenient decoding.
- **RecallTests — 4 hosted unit tests:** fonts registered, persistence round trip, corrupt file
  moved aside, store start/clear/stop.
- **RecallUITests — 4 UI tests** (iPhone 18 Pro, iOS 27.0 sim): launch + tabs, tap ⊕ → frequent →
  live bar, hold ⊕ + slide → toast "Started…", swipe row left → EDIT.
- Adding core tests: write `func testSomething()` in `RecallCoreTests.swift`, run `just
  core-test` (regenerates `main.swift`), commit both files.

---

## 12. Known limitations and deviations

- Not yet verified on a physical device (the user just received the IPA).
- Partial-height native sheets float inset (iOS 26/27 style) instead of the prototype's
  edge-to-edge sheets.
- "Save to Recall" uses the clipboard (`PasteButton` + LinkPresentation title); there's no Share
  Extension yet. Media durations are unknown for pasted links (entry spans 1 min unless sampled).
- Auto-capture is **simulated** (You → AUTO-CAPTURE). No real ingestion source exists.
- Thumbnails are hatched placeholders with a source glyph; photos attached on the live screen do
  show as the detail hero.
- Tag chips render on one line (max 4). The Today scroll position resets when switching tabs.
- On-this-day text is generated from data (place, a moment, media counts, a "steps" meta).
- Deliberate additions beyond the prototype: a TODAY → pill when viewing another day, editable
  title/times/place/thought in detail, real time pickers in Fill the gap, real photo/note on the
  live screen, paging into the future blocked, clear/load sample data.

---

## 13. Roadmap (priority order, as discussed)

1. **On-device polish pass** from the user's feedback (gesture thresholds, spacing, fonts).
2. **Background media track** — the user's next feature; design in §14, needs answers first.
3. **App Intents / Shortcuts** ("start <frequent>", "add background media", "pause") — no extension
   target needed; enables automations when Spotify/YouTube open.
4. **Live Activity / Dynamic Island** for the live timer (and later the background track). Needs a
   widget extension = extra App ID; check iloader/free-account limits first.
5. **Share Extension** for true share-sheet capture (extension + App Group).
6. **Real thumbnails** via LinkPresentation images, stored like photos.
7. **Real auto-ingest** sources (spec §6.6, §9.2), encryption/export design (§9.1), sync later.

---

## 14. Next feature design: the background media track (brainstorm — not implemented)

### The user's idea (their words, condensed)
Music or YouTube often plays *while doing something else*. Start a main task (coding, lying in
bed), then start a **background** session named whatever ("media", "background slop", "music").
Adding a YouTube link starts that item at that moment and runs until you stop it **or add another
link** — the new link ends the previous item and starts itself. You can **pause** (the break shows
visually) and **resume** later, **stop one** item, and add more later. Background should be
strictly music / YouTube-type media.

### Proposed shape
- **Two lanes.** The *foreground* lane stays exclusive: one live block, exactly as today. A
  *background* lane runs in parallel and never ends the foreground (and vice versa).
- **Background session** = a container entry: user-named, category `mediaBackground`,
  `attention: background`, lane `background`. Its **items** are media entries with absolute
  `start`/`end`, source/creator/url, and a `pauses: [interval]` list. Exactly one item is "now
  playing" while the session is live.
- **Add link = queue-replace:** end the current item now, start the new one now. A link is
  optional: typed items ("Spotify — Discover Weekly") are first-class.
- **Pause** freezes the session and the current item; **resume** closes the pause interval (the
  break is stored, not deleted). **Stop item** ends just that item (session keeps running, idle).
  **Stop session** ends everything.
- Stopping the foreground asks "Stop background too?" once, then remembers the choice (setting).
- Model sketch (RecallCore): add `lane: Lane (foreground|background)` and `pauses: [DateInterval]?`
  to `LogEntry` (optional fields → old archives still decode); `parentID: UUID?` links items to
  their session; `RecallData.backgroundLive` alongside `liveEntry`. Mutations:
  `startBackground(name:)`, `addBackgroundItem(title:url:source:)`, `pauseBackground`,
  `resumeBackground`, `stopBackgroundItem`, `stopBackground`. All unit-tested like the rest.

### Improvements beyond the idea
- **Background frequents** ("lofi mix", "Hyperpop for Cooking") and "resume last session" in one
  tap; the ⊕ arc could include a ♫ slot.
- **Sleep timer** for the in-bed case (15/30/60 min) — ends the session and flags "may have
  fallen asleep".
- **Promote / demote:** "I'm actually watching this now" moves an item to the foreground (and
  back) — keeps the ACTIVE/BACKGROUND attention split honest.
- **Source filter:** music · video (YouTube) · podcast/audiobook (defaulting to music/YouTube); link
  paste reuses `LinkTitle` + `SourceDetector` from `ShareCaptureSheet.swift`.
- **Retro-editing:** drag item boundaries, split, "I forgot to press next" fix-ups.
- **App Intents / Shortcuts:** automation "when YouTube opens → add background media".
- **Insights:** "soundtrack of the week", % of focus time with background media, top background
  sources/creators, longest listening session.
- Later: Live Activity showing both the main timer and the background item.

### How it should look (recommended combination)
- **Mini live bar** docked directly under the main live bar: ♫ glyph, current item title,
  session timer, ⏸/▶ button, "next" (+ paste link). Swipe left = stop, tap = open the
  background sheet (queue + history + pauses). Softer than the main bar — "only live is loud".
- **Timeline sidecar rail:** a thin `toneMediaBackground` vertical rail at the right edge of the
  card column, drawn per row for the minutes background media overlapped that row (works in all
  three densities); item changes = small ticks; pauses = hatched gaps (reuse `Hatch`).
- **Attached chip** under the overlapped foreground card: `♫ with Lo-fi mix · 1h10m · ⏸ 12m`;
  tap → background session detail.
- **Ribbon lane:** a 2 pt second lane under the 24 h ribbon showing when anything played,
  with pause gaps.
- The playing background item uses a **hollow/soft clay pulse**, not the full clay live dot.

### Open questions — ask the user before building
1. Can a background session exist with **no** foreground task running?
2. When the foreground stops, should background **auto-stop**, ask, or keep going?
3. Allow **podcasts/audiobooks**, or strictly music + YouTube?
4. **Manual "next" only**, or auto-advance when a known duration elapses?

---

## 15. How to start the next session

1. Read this file, then `ios/README.md`, then skim `Recall-UX.md` §5–§8.
2. `cd ~/Development/active/ui-design/AI-UI-004-Recall && nix develop`
3. `git status && git log --oneline -5 && gh run list --workflow ios.yml --limit 3`
4. `just core-test` (expect 30 passing).
5. Ask the user for on-device feedback and the §14 open questions before changing behaviour.
6. Change → `git push` → `just watch` (→ `just logs` on failure) → `just ipa` → user installs with
   iloader.
7. When a session ends, write the **next handoff version** (see `handoff/README.md`), don't edit
   this one.
