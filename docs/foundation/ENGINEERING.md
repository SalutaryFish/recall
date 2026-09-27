# Engineering rules

| | |
|---|---|
| **Document** | foundation/ENGINEERING · **v1.0** · 2026-09-27 |

## Structure

- **`web/`** — the prototype: one self-contained HTML file (vanilla JS, no build step, no
  dependencies besides Google Fonts). Latest at `web/index.html`, frozen releases in `web/versions/`.
- **`ios/RecallCore/`** — *all* domain logic for the app: model, day math, every mutation, seed,
  insights, formatting, persistence codec. Pure Swift + Foundation; must build and test on Linux
  (`just core-test`). If it can be a pure function, it belongs here.
- **`ios/Recall/`** — SwiftUI views, gestures, design system and the `AppStore` that calls
  RecallCore. Views hold no business rules.
- The web prototype and the app share the *design*, not code. When porting, the web version is the
  reference for behaviour and the spec/feature doc is the reference for intent.

## Modularity (set by the user)

- Grow by **adding pieces, not editing everything**. A new media source ("backend") should be one
  new provider type registered in one place, not new cases scattered through switch statements.
  Target shape (see F-001): a `MediaProvider` protocol — `id`, display name, glyph, `matches(url)`,
  `resolve(url) async → metadata (title, creator, duration?)`, capability flags — with a registry.
  The current `MediaSource` enum is the v0 of this and should migrate when F-001 lands.
- Model structure must be general enough to extend without rewrites: e.g. entries carry
  `lane` / `parentID` so multiple background tracks and nesting (F-001) are data, not special cases.
- Keep features behind small, named types with clear seams; prefer composition over flags.

## Swift 6 / Xcode 27 rules (each one avoided a failed CI build)

- App target: Swift 6 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency.
  Test targets: `nonisolated` default + `@MainActor` on tests.
- Mark value types `nonisolated` when they conform to protocols with nonisolated requirements or
  cross isolation (`SheetRoute`, `ToastMessage`, `Persistence`). Codable models live in RecallCore.
- Pass **closure literals**, not method references, into gesture callbacks and stored closures.
- Don't capture non-Sendable values (e.g. key paths) inside `Binding(get:set:)`.
- Write mixed `CGFloat`/`Double` arithmetic explicitly.
- `Text(verbatim:)` for any string containing `%`.
- `@State`: type it unless it's a trivial literal; never assign at declaration and in `init`.
- Closure-form `.overlay { }` / `.background { }`; `foregroundStyle`; `#Preview` only.
- Avoid custom `Shape`/`Layout`/`EnvironmentKey`/`PreferenceKey` conformances, or mark them
  `nonisolated`.
- Public RecallCore types use collision-proof names (`LogEntry`, `EntryCategory`, `RecallData`,
  `RecallCodec`) — SwiftUI/ObjC already export `Entry`, `Category`, ….
- Performance: only thin wrapper views read per-frame state (`SpringValue`); timers use
  `TimelineView`; write to `@Observable` properties only when the value changes.

## Tests and CI

- Every RecallCore mutation gets unit tests. On Linux the tests run through a generated entry point:
  after adding a test, run `just core-test` and commit the regenerated `main.swift`.
- New gestures or flows get a UI test in `ios/RecallUITests` when feasible (accessibility identifiers
  are the contract).
- CI (`.github/workflows/ios.yml`) must be green before an IPA is handed over. `just logs` shows
  failures. The web prototype deploys via `.github/workflows/pages.yml`.
- `just core-test`, `just lint` (swiftformat + actionlint) before pushing.

## Data and privacy

- Schema changes are additive and optional-with-defaults; decoders stay lenient; an unreadable
  archive is moved aside, never overwritten.
- Nothing leaves the device except what the user explicitly shares/exports.

## Git and tooling

- Commit messages: `web vX.Y.Z: …`, `app vX.Y.Z: …`, `docs: …`, `ci: …`, `core: …`; end with the
  Co-Authored-By trailer. Tag releases (`VERSIONING.md`).
- Generated files are never committed: `ios/Recall.xcodeproj`, `ios/Recall/Info.plist`, `build/`.
- Never launch GUI apps (iloader) from an automated tool call; never change the user's global git config.
