# F-002 · Automatic capture

| | |
|---|---|
| **Feature** | F-002 — Recall logs what you watch, listen to and read **by itself**, from inside the apps |
| **Doc version** | v0.3 · 2026-10-08 (v0.1 = the design; v0.2 = built as web v2.2.0; v0.3 = web v2.2.1 fixes + the gap decision) |
| **Status** | **Web (v2.2.1)** — capture fixes on the first prototype, in phone testing |
| **Approved in web** | — |
| **Shipped in app** | — |
| **Depends on** | F-001 background tracks (captured media fills tracks and items) |

## Problem

Recall's first principle is that capture must cost under three seconds, and its second premise is
that it is *detailed* about media — source, creator, length, how much was taken in. Those two pull
against each other: typing a video's title is not a three-second job, and nobody does it 40 times a
day. Today the prototype fakes the answer (`AUTO_POOL` trickles in invented detections) and the app
has no real source at all. Everything in the archive is hand-typed.

iOS gives a third-party app no way to see what another app is playing. The system's own
"Now Playing" is not readable, Screen Time data cannot leave its extension, and there is no public
hook for YouTube. So the choice is between staying manual or running the media apps somewhere
Recall's own code can reach them.

## Decisions (user, 2026-10-07 / 2026-10-08)

1. **LiveContainer is the capture platform.** The media apps (Spotify, YouTube, …) run as *guest
   apps* inside [LiveContainer](https://github.com/LiveContainer/LiveContainer), which loads our own
   dynamic library into every one of them. That library is where all tracking happens.
2. **LiveContainer is used unmodified, not forked.** Its `TweakLoader` already `dlopen`s every
   `.dylib` in a global tweaks folder into each guest app, so our code gets in through a supported
   mechanism. We keep their releases and their bug fixes (the project ships fixes weekly and is
   already handling iOS 27). *Rejected: forking it — we would inherit ~30k lines of dyld/Mach-O
   internals, and a guest app in normal launch mode replaces LiveContainer's own UI in the same
   process, so there would be nothing to gain.*
3. **Recall stays a normal sideloaded app**, outside LiveContainer. Guest apps cannot have app
   extensions, and Recall needs them: Live Activity / Dynamic Island, widgets, Shortcuts/App
   Intents, the share sheet.
4. **Capture is file-based and merged on open.** The tweak appends timestamped JSON lines; Recall
   reads what is new whenever it is opened and reconstructs the stretch. Nothing of ours has to run
   in the background, which iOS would not allow anyway.
5. **Detail is added per app, incrementally** — one module inside the one dylib. Adding an app to
   track = adding a module + installing that app in LiveContainer. Never a change to LiveContainer.
6. **A captured entry may enter as pending or go straight in — the user's setting**, because
   content read from inside the app is machine-truth, not a guess (2026-10-08). Default: pending,
   which keeps principle 5 ("nothing unconfirmed enters the archive") as the out-of-the-box
   behaviour. See *Settings*.
7. **The AI pass is a separate, later feature**, and must be local-first: the archive is the most
   sensitive dataset the user owns (principle 7), so an on-device model or an explicit per-item
   opt-in — never a blanket upload.

## Architecture

```
┌─ LiveContainer (stock release, installed with iloader) ──────────────┐
│                                                                       │
│   Spotify      YouTube      Reddit      Kindle      …                 │
│      ▲            ▲            ▲           ▲      ← decrypted IPAs    │
│      └────────────┴────────────┴───────────┘                          │
│                  RecallTweak.dylib                                    │
│        one dylib, loaded into every guest app by TweakLoader          │
│        · universal hooks (layer 1)                                    │
│        · per-app modules, switched on bundle id (layer 2)             │
│        · readers for the guest apps' own data files (layer 3)         │
│                            │                                          │
│                            ▼  appends one JSON object per line        │
│   <LiveContainer>/Documents/Recall/events-YYYY-MM-DD.jsonl            │
└────────────────────────────┬──────────────────────────────────────────┘
                             │ LiveContainer's Documents folder is visible
                             │ in Files (UIFileSharingEnabled), so Recall
                             │ gets a one-time security-scoped folder bookmark
                             ▼
┌─ Recall (own app, own sandbox) ──────────────────────────────────────┐
│   Ingest: read new lines → events → entries, tracks, items, breaks    │
│   Review: pending captures, grouped, kept or dropped in one tap       │
│   The rest of Recall unchanged: timeline, Live Activity, widgets, …    │
└───────────────────────────────────────────────────────────────────────┘
```

### The three layers of detail

| Layer | What it hooks | Gives | Cost / stability |
|---|---|---|---|
| **1 · Universal** | `MPNowPlayingInfoCenter` (the setter every media app calls to fill the lock screen) + app foreground/background | Title, artist/creator, album, length, position, play/pause/stop — **in any media app**, including ones added later with no new code. Plus an app session for every app. | Written once. Public Apple API, so it survives app updates. |
| **2 · Per-app detail** | That app's own classes | What was *searched*, which playlist/channel/episode, which post was on screen, per-item scroll events | Needs a class dump of that app; breaks when the app is restructured. Optional, one app at a time. |
| **3 · The apps' own data** | The guest app's files (its local database, history store, caches) | Often richer than any hook, and retroactive | LiveContainer's README lists "guest app containers are not sandboxed [from each other]" as a limitation — for this project it is the enabling feature. Needs each app's schema. |

Layer 1 is the first prototype's whole scope on the native side. Layers 2 and 3 are additive and
must never be required for the core loop to work.

## Event format (the tweak → Recall contract)

One JSON object per line, append-only, one file per local day. Unknown fields are ignored and
unknown `type`s are skipped, so an older Recall can read a newer tweak's file.

```jsonc
{"v":1,"id":"a3f…","at":"2026-10-08T18:42:07.431+01:00","layer":1,
 "app":"com.spotify.client","appName":"Spotify","type":"play",
 "title":"Windowlicker","creator":"Aphex Twin","album":"Windowlicker",
 "durationMs":366000,"positionMs":0,"url":null}
```

| Field | Meaning |
|---|---|
| `v` | event schema version (1) |
| `id` | stable id, so a re-read never double-imports |
| `at` | ISO 8601 **with offset** — the clock the user lived in |
| `layer` | 1/2/3, so Recall can show (and trust) sources differently |
| `app`, `appName` | guest bundle id and display name |
| `type` | `play` · `pause` · `resume` · `stop` · `seek` · `heartbeat` · `appOpen` · `appClose` · `detail` |
| media fields | `title`, `creator`, `album`, `durationMs`, `positionMs`, `url` |
| `detail` | free-form object for layer 2 (`{"kind":"search","query":"…"}`, `{"kind":"post","id":"…"}`) |

`heartbeat` (every ~30 s while playing) means a crash or a kill loses at most half a minute, and
lets Recall tell "played to the end" from "app was killed mid-track".

## Ingest rules (events → the archive)

Deterministic, and pure functions in RecallCore so they can be unit-tested on Linux:

1. **A media `play` event** becomes an F-001 **item**:
   - a live track for that app exists → the item is appended to it (which ends the previous item,
     exactly as a manual "next" does);
   - else a **main task is live** → open a track named after the app ("Spotify") and add the item.
     This is the common case: music alongside whatever you are doing;
   - else nothing is live → the media becomes a **main-lane media entry** (attention `active`),
     because F-001 rule 1 says a track cannot exist without a main task.
2. **`pause` / `resume`** become F-001 breaks on the item and its track — never deleted, drawn as
   hatched gaps, and excluded from `consumedMs` (F-001 Q3).
3. **`stop`, or a silence longer than the grace period**, ends the item and the track.
4. **`appOpen`/`appClose` for a non-media app** become an app session (pending block, category
   `media` when it is a media app, else `life`). Sessions shorter than the floor (default 45 s) are
   dropped: opening Spotify to skip a track is not an activity.
5. **Rapid successive items from one source** collapse into a session card, the existing §2.5
   behaviour — one evening of short video must not bury the day.
6. **Capture never moves or edits what the user logged by hand.** A conflict (a captured session
   overlapping a hand-made block) is shown as a suggestion, not applied.
7. **Re-reading the same file changes nothing** (idempotent on `id`).
8. **Events are placed by when they happened, not by what is live now** (web 2.2.1). The app reads
   the file when it opens, so every event is in the past. Routing asks "which task was live at
   this event's moment?" (`mainAt`), and between events the day is walked forward (`capSettle`):
   a track whose task ended moves to the task that took over, or ends there — and music still
   playing then owns the main lane (1c); captured media owning the main lane yields to a task you
   logged later and keeps playing under it (1b). Events are processed in time order; the native
   decoder must do the same, and track progress by file offset rather than a capped list of ids.
9. **A pending capture is not tracked time** (principle 5). It is left out of the day's totals,
   the ribbon, the archive and Insights until kept. A pending capture in the main lane sits inside
   the gap it explains, which offers **KEEP / DISCARD / + FILL** (user decision, 2026-10-08);
   choose `STRAIGHT IN` to have such captures fill the gap by themselves.
10. **Keeping never overlaps what you logged** (rule 6): a kept main-lane capture keeps only the
    untracked part, split around your entries if it straddles one. **Discarding never takes down
    what you made or kept**: a capture with your own track alongside it refuses until that track
    is stopped or deleted.
11. **A manual track adopts capture**: the first captured play under a task with a live hand-made
    track flows into that track instead of opening a second one.

## Settings (decision 6)

| Setting | Options | Default |
|---|---|---|
| **CAPTURED ENTRIES ENTER AS** | `PENDING` (tap to keep) · `STRAIGHT IN` (confirmed, delete if wrong) | PENDING |
| **CAPTURE** | ON / OFF (master switch) | ON |
| **PER-APP** | each tracked app: capture on/off, and `PENDING`/`STRAIGHT IN` override | inherit |
| **SHORTEST SESSION** | 0 / 45 s / 2 min — below this, an app session is dropped | 45 s |

`origin: 'auto'` and the layer stay on the record forever either way, so "did I log this, or did the
machine?" is always answerable (principle 5, spec §8).

## Visual design (what the web prototype must answer)

The risk is not capture — it is **being buried in it**. A day with 60 captured items must stay as
readable as today's hand-made day, and reviewing must cost one tap, not sixty.

- **Capture card.** Consecutive captures collapse into one pending card on the timeline:
  `▶ 6 captures · YouTube · 1h12m` with **KEEP ALL** / expand to pick. Never 60 loose rows.
- **The auto-filled track.** Captured music appears as an F-001 track with its rail, chip and
  ribbon lane already drawn — the main thing to judge in the hand.
- **A captured row must be distinguishable at a glance** from a hand-made one (the existing dashed
  dot for pending, plus a quiet source mark when it went straight in).
- **The gap, answered.** An untracked gap that captured events can explain offers them inline:
  `2h13m untracked — Spotify played for 1h40m. Use it?`
- **Capture status** somewhere calm: when Recall last read the event file, and how many events
  are waiting. Nothing nagging, no badge counts.
- **A manual start can adopt capture**: start a track for "Music" and whatever the tweak reports
  flows into it.

## Where things are in web v2.2.0 (2.2.1 changes at the end)

- **You → F-002 · AUTOMATIC CAPTURE:** CAPTURE on/off · ENTRIES ENTER AS **PENDING / STRAIGHT IN**
  (decision 6) · SHORTEST SESSION ALL/45s/2m · a per-app ON/OFF row for each tracked app.
- **You → SIMULATE THE TWEAK:** ♫ PLAY · NEXT ITEM · ⏸ PAUSE · ▶ RESUME · ■ STOP · APP SESSION ·
  BURST ×8 · LAYER 2 · SEARCH, plus the time of the last event. Events also trickle in on their
  own every 22–42 s while CAPTURE is on, so a day fills in while you use it.
- **On the day:** a pending stretch is one **capture card** (dashed, clay) with KEEP ALL / DISCARD;
  tap it to see every item and drop one with ×. A single capture shows its creator, its time range
  and any layer-2 detail.
- **The track fills itself:** captured music opens an F-001 track named after the app, with its
  rail, chip (dashed while pending) and ribbon lane.
- **A gap** that captured play explains says so and prefills the backfill sheet.
- **Code:** `§12 AUTOMATIC CAPTURE` in `web/index.html` — `CAP_APPS`, `mkEvent`, `capIngest`
  (the rules), `capClusters`/`capNode` (review), `capSim*` (the simulator).
- **web 2.2.1:** `mainAt` + `capSettle` (rule 8) · the gap box (`gapNode` with clusters) · KEEP
  trims to untracked time (`capKeepMain`) · DISCARD guards your own tracks · STRAIGHT IN entries
  carry a quiet `CAPTURED` mark · a SHORT SESSION 20s simulator button tests the floor · settings
  survive the daily sample refresh.

## Prototype plan — web (what to test on the phone)

The web prototype **simulates the tweak**: a fake event stream, shaped exactly like the JSONL
contract, so every UI question can be answered before any Objective-C is written. A simulator panel
in You can inject events on demand (play, next, pause, resume, stop, open an app, a burst of short
videos) instead of waiting for the random trickle.

- [ ] A track plays and fills in by itself; the rail, chip and ribbon lane read correctly.
- [ ] 6 captures in a row collapse into one card; KEEP ALL is one tap; expanding and dropping one works.
- [ ] `PENDING` vs `STRAIGHT IN` both tried in the hand — which one you actually want.
- [ ] A burst of 30 short videos does not bury the day.
- [ ] Nothing is live, music starts → it becomes the main task (ingest rule 1c). Does that feel right?
- [ ] A gap offering its captured explanation.
- [ ] Captures never disturb a hand-made entry.
- [ ] The day still reads as a transcript at all three densities.

## Native plan (after the web version is approved)

1. **RecallCore**: the event model, a lenient JSONL decoder, and the ingest rules as pure
   functions, with unit tests (`just core-test`). No UI, no file system.
2. **Recall**: the folder bookmark (pick LiveContainer's `Documents` once in the Files picker),
   read-on-foreground, and the review UI ported from the approved web version.
3. **RecallTweak** (new `tweak/` folder, built with Theos **on Linux** — no Mac needed): layer 1
   only. Milestones from the user's own learning path: a test app of our own that sets
   now-playing info → a tweak that hooks it and writes the file → the same tweak on the real apps.
4. Layer 2 modules, one app at a time, only once the loop is trusted.

## Risks and open items

- **Decrypted IPAs** are needed for every guest app and every update. The user has a route
  (confirmed 2026-10-07, LiveContainer+SideStore installed with iloader and a decrypted app
  running). LiveContainer refuses encrypted ones outright (`LCAppInfo.m`).
- **Terms of service and accounts.** Modified clients can get accounts banned; a throwaway Google
  account for YouTube is the mitigation. Accepted: personal use only, never distributed.
- **Only apps inside LiveContainer are captured.** The normal copies have to go, and the
  home-screen shortcuts point into LiveContainer.
- **Multitask mode is not the model.** Floating windows exist only inside LiveContainer (and
  video playback there is broken for many apps — their issue #870), so the flow is
  "Recall launches the app, you come back", with the Live Activity as the always-visible part.
- **Background audio keeps playing** when you leave a guest app (their issue #942 confirms Spotify
  does), which is what makes merge-on-open sufficient.
- **The exact shared path must be verified on device** during the native spike: the tweak writes
  into LiveContainer's `Documents` folder, which is exposed in Files; whether a folder bookmark or
  an App Group is the better channel depends on where that build keeps guest data
  (`Documents/Data/Application/<uuid>` or the SideStore app group).

## Still open (answer during web testing)

1. When nothing is live and music starts, should it become the main task (rule 1c), or wait
   silently until something is started?
2. How long a silence ends a track — 2 min, 5 min, or only an explicit stop?
3. Should an app session for a *non-media* app (Reddit, Messages) be captured at all, or is that
   noise? If yes: as a block, or only as context on the gap it fills?
4. Does `STRAIGHT IN` want an undo window (a toast with UNDO) rather than deleting afterwards?
5. Should captured items be collapsed by app *per hour*, or per unbroken stretch?
