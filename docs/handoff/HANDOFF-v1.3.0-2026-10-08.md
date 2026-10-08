# Recall — project handoff

| | |
|---|---|
| **Handoff version** | **v1.3.0** |
| **Date** | 2026-10-08 |
| **Previous version** | [v1.2.0](HANDOFF-v1.2.0-2026-09-27.md) (F-001 as web 2.1.0) · [v1.1.0](HANDOFF-v1.1.0-2026-09-27.md) (rules, docs layout) · [v1.0.0](HANDOFF-v1.0.0-2026-09-27.md) (architecture; paths outdated) |
| **Repo** | https://github.com/SalutaryFish/recall · local `~/Development/active/ui-design/Recall` |
| **Commit** | `1085e44` (main, clean) · tags `web-v2.2.0`, `web-v2.1.0`, `web-v2.0.0`, `app-v0.1.0` |
| **Web prototype** | **web v2.2.0** — https://salutaryfish.github.io/recall/ (Pages run 37736659876, green, verified live) |
| **App** | app v0.1.1 · implements web 2.0.0 · **not tagged**, unchanged this session (see §7) |
| **Written by** | Claude (Opus 5) |

## 1. TL;DR

- The project **gained its missing half**: F-002 automatic capture. Recall will log what you watch
  and listen to **by itself**, by running the media apps inside **LiveContainer** with our own tweak
  loaded into them. Designed, documented, and built as **web v2.2.0** with the event stream
  simulated.
- The iOS app was **not touched**, per the web-first rule.
- **Both F-001 and F-002 now wait on the same phone testing.** Each round of feedback is a PATCH
  (2.2.1, …). Once approved, the native work is app 0.2.0 **plus** a new `RecallTweak` dylib.

## 2. What the user decided this session

The source was a claude.ai conversation the user pasted in (they could not share the link — see
§9). Decisions, all recorded in `docs/features/F-002-automatic-capture.md`:

1. **LiveContainer is the capture platform.** Media apps run as guests inside it; our dylib is
   loaded into every one of them and does all the tracking.
2. **LiveContainer is used unmodified — not forked.** This was the user's main question, and the
   answer they accepted: its `TweakLoader` already loads a global tweaks folder into each guest, so
   detail comes from *our* tweak, never from changing LiveContainer. Forking would mean inheriting
   ~30k lines of dyld/Mach-O internals for nothing — in normal launch mode a guest app replaces
   LiveContainer's own UI in the same process anyway.
3. **Recall stays a normal sideloaded app**, outside LiveContainer, because guest apps cannot have
   app extensions and Recall needs them (Live Activity, widgets, Shortcuts, share sheet).
4. **File-based capture, merged on open.** The tweak appends JSONL; Recall reads what is new when
   it opens and reconstructs the stretch. Nothing of ours runs in the background.
5. **Detail is per app, incremental** — one module inside the one dylib. Adding an app to track =
   a module + installing that app in LiveContainer.
6. **Pending vs straight-in is a setting, not a verdict.** The user's words: *"just add a setting
   for that."* Default PENDING, which keeps principle 5 out of the box.
7. The user **confirmed the prerequisites on 2026-10-07**: LiveContainer+SideStore installed with
   iloader, a decrypted app running, and a route to decrypted IPAs. That was the gating risk in the
   previous plan and it is now cleared.

## 3. What was verified in LiveContainer's source (so nobody re-derives it)

Cloned at `github.com/LiveContainer/LiveContainer` (AGPL-3.0, active — commits weekly, iOS 27
issues already being fixed):

| Claim | Where |
|---|---|
| One tweak is loaded into **every** guest app | `TweakLoader/TweakLoader.m` — `dlopen`s every `.dylib` in `LC_GLOBAL_TWEAKS_FOLDER` |
| Encrypted App Store IPAs are **refused** | `LiveContainerSwiftUI/Models/LCAppInfo.m` — *"The app you tried to install is encrypted."* |
| Recall can launch a guest app directly | `livecontainer://livecontainer-launch?bundle-name=<id>` — parsed in `LiveContainer/LCSharedUtils.m` |
| Background audio keeps playing | `LiveContainer/Info.plist` declares `UIBackgroundModes: audio`; their issue #942 confirms Spotify keeps going |
| The event file can be reached from outside | `LiveContainer/Info.plist` has `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`, so its `Documents` shows in Files |
| Guest data lives where the tweak can read it | `LCBootstrap.m` sets each guest's `HOME` to `…/Data/Application/<uuid>`; the README lists "guest app containers are not sandboxed" as a limitation — here it is the enabling feature (layer 3) |
| Multitask mode is **not** the model | Floating windows exist only inside LiveContainer, and their issue #870 reports video playback broken there for many apps |
| Spotify/YouTube do run in it | Issues #1216 (EeveeSpotify), #1491 (YouTube on iOS 26.5) |

## 4. What's in web v2.2.0 (`web/index.html`)

The prototype **simulates the tweak**: the fake events have exactly the shape of the real contract,
and `capIngest` is the rule set that ports to RecallCore unchanged.

| Section | What it holds |
|---|---|
| CSS "5c · AUTOMATIC CAPTURE" | the capture card, the layer-2 detail line, dashed pending rail/chip, the gap's captured explanation |
| `capDefaults()` (next to `PREFS`) | capture settings. **A function, not a constant** — see §6 |
| §12 `CAP_APPS` · `mkEvent` | the simulated apps and the JSONL event shape (`v, id, at, layer, app, appName, type, …`) |
| §12 `capIngest` | **the ingest rules.** play → item (into the app's live track · open one under the live main task · or become the main task); pause/resume → breaks; stop; `appSession` with a floor; `detail` → layer-2 info on the item; idempotent on `id` |
| §12 `capClusters` / `capNode` / `capKeep` / `capDrop` | review: one card per unbroken stretch from one app, KEEP ALL / expand / drop one |
| §12 `capSim*` + `capTick` | the simulator panel and the 22–42 s trickle |
| `gapCapture` + `gapNode` | a gap that captured play explains says so and prefills the backfill sheet |
| `openYou` | CAPTURE on/off · ENTRIES ENTER AS PENDING/STRAIGHT IN · SHORTEST SESSION · per-app toggles · the simulator · last-event time |

**Behaviour change worth knowing:** `renderToday` now appends capture cards by time *without* them
taking part in span computation — they are review surfaces, not tracked minutes (see §6, bug 1).

## 5. How it was verified

- A **Deno script driving headless Chromium over the DevTools protocol** (402×874, a local
  `python3 -m http.server`), running **74 checks, all green, with no page errors**: every ingest
  rule including the three play routings, breaks, the session floor, per-app and master switches,
  idempotency, layer-2 detail, cluster grouping/keep/expand/drop, the gap suggestion, persistence
  across a reload, all three densities, and the invariants from F-001 (one live main task, every
  live track has a live main parent, one playing item per track, breaks inside their entry).
- A smoke pass over the existing flows (quick add, F-001's start-a-track sheet, Archive, Insights,
  tabs) still green.
- Screenshots reviewed in light and dark; that review caught the ⏸/⏭ glyph bug (§6).
- The deployed site was re-checked **from https://salutaryfish.github.io** afterwards.
- The script lives in the session scratchpad and is **not in the repo**, same as last session. If
  the phone-testing rounds want regression runs, it could become `just web-test` — new tooling, so
  ask the user first.

## 6. Bugs found and fixed while testing

1. **A capture card truncated the span of the row above it.** Rows own the minutes until the next
   row starts, and that span is what the ♫ rail maps onto — so inserting a card into the row list
   silently cost the live row its rail and chip. Capture cards are now laid out by time but excluded
   from span computation, and `refreshLiveRow` finds the live row by a `data-live-row` marker
   instead of "last child in the DOM".
2. **The capture settings object was rebuilt on every read.** `capPrefs()` returned a fresh object
   each call, so `capEnabled()` detached the object `capIngest` was holding, and writes to it (the
   last-event time) were lost. It now fills in missing keys **in place** and returns the same object.
   A shared mutable default had the mirror-image problem: switching one app off wrote through to the
   defaults for every future reset — hence `capDefaults()` being a function.
3. **⏸ and ⏭ don't exist in these fonts** (the same class of bug F-001 hit): they rendered as
   nothing. Drawn in CSS now.

## 7. Open items outside F-002

- **App v0.1.1 CI** (run 36295377639) is still where handoff v1.2.0 left it: the IPA built, but the
  UI test `testHoldCaptureAndSlideStartsAFrequent` failed to find the `toast` element. It passed in
  run 36291417879, so it is probably timing-flaky (the toast hides after ~1.9 s). Not tagged. This
  is CI work, so it may go straight to the app. Untouched this session.

## 8. Next steps (in order)

1. **The user tests web v2.2.0 on the phone — F-001 and F-002 together.** The checklists are in
   both feature docs. Each round of changes is a new PATCH: bump `WEB_VERSION` and `<title>`, freeze
   `web/versions/v2.2.x/`, add a line to the versions list, the CHANGELOG and the feature doc,
   commit `web v2.2.x: …`, push, tag.
2. **Answer the open questions** from what was chosen in the hand — F-001 has 4, F-002 has 5
   (notably: should music with nothing running become the main task; how long a silence ends a
   track; are non-media app sessions noise; does STRAIGHT IN want an undo window).
3. **Native port**, once approved:
   - **RecallCore first**: the event model, a lenient JSONL decoder, and the ingest rules as pure
     functions with unit tests (`just core-test`). `LogEntry` also gains F-001's `lane`, `parentID`,
     `pauses` and track fields, and `MediaSource` becomes a `MediaProvider` registry.
   - **Recall**: the one-time security-scoped folder bookmark onto LiveContainer's `Documents`,
     read-on-foreground, and the review UI ported from the approved web version.
   - **`RecallTweak`** (new `tweak/` folder, built with **Theos on Linux — no Mac needed**): layer 1
     only at first. Milestones: a test app of our own that sets now-playing info → a tweak that hooks
     it and writes the file → the same tweak on the real apps in LiveContainer.
   - App 0.2.0 with `RecallWebVersion` = the approved web version.
4. The **exact shared path must be confirmed on device** during that spike — folder bookmark versus
   App Group, depending on where the installed LiveContainer build keeps guest data.

## 9. Environment reminders

- `gh` exists only inside `nix develop`, and the repo's credential helper needs it, so push with
  `nix develop --command git push`.
- Headless testing: Deno and Chromium are the system ones (`/etc/profiles/per-user/username/bin/`).
  **Use a private `--remote-debugging-port`.** On 9333 another local process was found attached to
  the same browser and navigated the page mid-run (to a different local app on `127.0.0.1:8797`),
  which corrupted a screenshot pass. Also: never `pkill -f 'remote-debugging-port=…'` — the pattern
  matches the shell running it and kills the session.
- `claude.ai/share/…` links **cannot be read from here**: the page is JS-rendered and the snapshot
  API is behind a Cloudflare bot check. Ask the user to paste the text or export a PDF.
- The repo folder is `~/Development/active/ui-design/Recall`. Older handoffs name it
  `AI-UI-004-Recall`.
