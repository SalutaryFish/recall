# Recall — UI/UX Design Document

**Version** 2.0 · media-first
**Date** 23 September 2026
**Status** Prototype specification. Precedes the native iOS build.
**Artefacts** `Recall.dc.html` (v1 static canvas) → `Recall.proto.html` (v2 interactive prototype)

---

## 1. Premise

Recall is a personal archive of attention. It answers one question with precision —
*where did my time and attention actually go today* — and a second question as a
by-product: *what was that day like*.

The primary object is **media**: the videos, posts, tracks, episodes, articles and books
that consume most modern waking hours and leave the least trace. Everything else the app
records — blocks of activity, places, people, thoughts, photographs — exists to give that
media a context, so that a day can be re-read rather than merely counted.

### What Recall is

- A **transcript of a day**. Timestamps run down the left in monospace; a day reads like a log.
- **Detailed about media.** Source, creator, duration, how much was actually consumed, and
  whether it held your attention or merely played in the background.
- **Cheap to feed.** Anything that can be captured automatically is. Manual entry is the
  fallback, never the default.
- **Honest about gaps.** Untracked time is shown as untracked, not silently omitted.

### What Recall is not

- Not a productivity scorer. No streaks, no goals, no guilt mechanics, no "screen time is up
  12%" nagging. The app reports; it does not judge.
- Not a household inventory. v1 devoted an entire screen to things owned and their prices.
  Cut — it is a different application wearing the same typeface.
- Not a social product. Nothing is shared, ranked or compared.

### Design principles

1. **Capture must cost under three seconds**, or the habit dies inside a week. This principle
   was stated in v1 and then contradicted by v1's own interaction design. It is now enforced.
2. **Read the shape, then the detail.** A day should be legible as a silhouette before you
   read a single word of it.
3. **The interface is calm; only *live* is loud.** One accent colour, reserved exclusively
   for things happening right now.
4. **Gestures over chrome.** Every destructive or corrective action lives under a gesture,
   not behind a button that has to earn its pixels.

---

## 2. Critique of v1

Ten findings from the static canvas, each with the fix carried into v2. Line references
point at `Recall.dc.html`.

### 2.1 The floating action button contradicts the design's own principle

The annotation at `Recall.dc.html:379` states: *"Logging must cost <3 seconds or you'll stop."*
The interaction it sits beside costs three taps — open the sheet, choose a frequent, confirm —
plus a sheet animation and a mode switch.

**Fix.** The `+` keeps its single-tap behaviour for the considered case. But a **long-press
raises an arc of the four most-used frequents** around the button; slide a thumb to one and
release to commit. No sheet, no screen change, one continuous gesture, well under a second.
The arc is positioned for a thumb arriving from the bottom-right, and the frequents reorder
themselves by actual use.

### 2.2 There is no affordance for the way tracking actually happens

Nobody logs their day as it occurs. They forget for six hours and reconstruct it at
half past nine at night. v1 treats this as an afterthought: a small secondary button labelled
"Past" (`Recall.dc.html:173`).

**Fix.** Untracked time becomes a **first-class object in the timeline** — a hatched segment
labelled `2h13m untracked` sitting exactly where the hole is. Tapping it opens a block
pre-filled with the gap's start and end, so backfilling is a matter of naming the thing rather
than entering four fields. This is the single largest retention lever in the design: it turns
an accusing blank space into a one-tap task.

### 2.3 Time is rendered as a list, not as a duration

Every entry in v1 occupies the same vertical space. A five-minute coffee and a three-hour
work block are visually identical, so the *proportions* of a day — the entire point of
tracking it — cannot be read.

**Fix.** Three densities, cycled by **pinching the timeline**:

| Density | Row height | Use |
|---|---|---|
| **Transcript** | Uniform | Reading and editing. The v1 behaviour, kept as the default. |
| **Proportional** | Log-compressed by duration, floor 44px | Seeing the day's rhythm without losing short entries. |
| **Ribbon** | True linear scale | Auditing. A day-column, like a calendar. |

Log compression matters: on a true scale a two-minute entry is two pixels and untappable. The
44px floor guarantees every entry remains a legal touch target at every density.

### 2.4 There is no glanceable sense of the day so far

The header reports `14h tracked · 6 blocks · 3 media` (`Recall.dc.html:41`) — numbers, which
must be read and interpreted, where a shape could be absorbed instantly.

**Fix.** A **24-hour ribbon** sits under the header: a 6px bar spanning midnight to midnight,
segmented by category tone, with untracked time hatched. It is both a summary and a control —
drag along it and the timeline scrubs in sync, so jumping to "that thing around four" is a
thumb-slide rather than a scroll hunt.

### 2.5 Media — the stated purpose — is the shallowest part of the design

v1 has exactly one media card (`Recall.dc.html:75-88`): a thumbnail, a title, a source, a
progress line. For an app whose job is detailed media tracking, this is thin. Three specific
omissions:

- **No attention model.** An album playing while you cook is not forty-five minutes of
  attention. Without an `active`/`background` distinction every total is inflated and the data
  is worthless.
- **No session concept.** Forty minutes of short-form scrolling is not one entry — it is
  roughly two hundred. Rendered naïvely, a single evening would bury the entire day's timeline
  in noise.
- **No completion fidelity.** "Watched 8:02 / 12:41" exists on one card but is not modelled;
  abandonment is itself a signal worth keeping.

**Fix.** Media entries carry `source`, `creator`, `durationMs`, `consumedMs` and `attention`.
Rapid successive consumption from one source **auto-collapses into a session card** —
`TikTok · 23 items · 41m` — which expands on tap into its constituent items. Background media
renders at reduced weight with a hollow spine dot, so the eye skips it when scanning for
what actually mattered.

### 2.6 Every correction requires a full screen

In v1 the only way to change anything is to open the detail view. Given that most entries will
be created by imperfect automation, correction is not an edge case — it is a core loop.

**Fix.** Corrections move onto the rows themselves:

- **Swipe left** reveals Edit / Split / Delete.
- **Swipe right** is *again* — start this same thing now. The fastest possible path for
  repeated activity, which is most activity.
- **Long-press** lifts the row with a haptic tick; drag to re-time it, snapping to five-minute
  increments, with the affected neighbours reflowing live.

*Split* deserves its own note: it is the repair tool for the commonest automation error, where
a single four-hour "browsing" block should have been three distinct things.

### 2.7 The live screen is a takeover when it should be a spine

The tracking screen (`Recall.dc.html:220`) is the most striking thing in the canvas — a dark
field, a 66px monospace timer. It is also a dead end. While it is up you cannot see your day,
and there is nowhere to go but out.

**Fix.** The dark screen is retained exactly, but demoted to the *expanded state* of a
persistent **live bar** docked above the tab bar. Drag it up to expand, down to collapse, with
velocity deciding the outcome — the now-playing interaction every phone user already knows.
The bar is always visible while something is being tracked, which gives the whole app a spine
and makes "am I still tracking?" answerable without navigation.

### 2.8 Nothing closes the loop

v1 has "On this day" (`Recall.dc.html:358`), which is nostalgia — pleasant, but it does not
reward the labour of tracking. A tracker that never hands the data back is abandoned.

**Fix.** An **Insights** tab whose centrepiece is a weekly recap written as prose, in the
app's own editorial voice — *"Tuesday was your longest unbroken stretch of attention this
month: two hours and forty minutes on one thing, no media at all."* Charts are present but
subordinate. Sentences are read; dashboards are glanced at and forgotten.

### 2.9 Contrast fails on the most-read element in the app

`#A9A69F` on `#FAFAF9` measures **2.33:1**. WCAG AA requires 4.5:1 for text at this size. That
colour is used for the timestamps — the element the eye returns to more than any other — and
for most metadata. Several touch targets (the ACQUIRED row at `Recall.dc.html:104`, the tag
chips) are roughly 24px tall against a 44px minimum.

**Fix.** The grey ramp is retuned (§4.1) with measured ratios. The character of the palette is
preserved; the greys simply stop being decorative at the expense of legibility. All targets
are padded to 44px.

### 2.10 No empty state, no dark mode

Every day starts empty, and a log of one's own day is disproportionately consulted at night.
v1 designs neither.

**Fix.** Both specified — §6.8 and §4.2.

---

## 3. Information architecture

```
┌─ Today ──────────── Archive ──────────── Insights ─┐
│                        ⊕                            │   ⊕ = capture
└─────────────────────────────────────────────────────┘
        ▲ live bar (present only while tracking)
```

Three tabs, down from five. **Things** is cut entirely; **You** moves to an avatar in the
Today header, because settings are visited monthly and do not deserve a fifth of the
navigation.

| Surface | Contains |
|---|---|
| **Today** | The day's transcript. Header, 24h ribbon, entries, gaps, pending auto-captures. Pages horizontally to any other day. |
| **Archive** | The heatmap calendar, on-this-day, lifetime counts. Search lives here. |
| **Insights** | Weekly recap, attention split, source breakdown, the long view. |
| **Capture (⊕)** | Tap → quick-add sheet. Long-press → frequents arc. |
| **Live bar** | Persistent while tracking. Drags up into the full dark tracking screen. |

**Modality rule.** Sheets are the only modal layer, and they are always dismissible by drag.
Nothing in the app can trap you in a state that requires finding a specific button to leave.

---

## 4. Design tokens

### 4.1 Colour — light

Ratios measured against the surface each token actually sits on.

| Token | Hex | On | Ratio | Use |
|---|---|---|---|---|
| `--bone` | `#FAFAF9` | — | — | App background |
| `--card` | `#FFFFFF` | — | — | Raised surfaces |
| `--wash` | `#F0EEE9` | — | — | Chips, inset fills |
| `--ink` | `#1C1B19` | bone | **16.48** | Primary text, spine, tab bar fill |
| `--ink-2` | `#56544E` | bone | **7.25** | Secondary text, chip labels |
| `--ink-3` | `#6E6B63` | bone | **5.10** | Timestamps, mono metadata — *was `#A9A69F` at 2.33* |
| `--hair` | `rgba(0,0,0,0.08)` | — | — | Borders, the timeline spine. Never text. |
| `--clay` | `#B5734F` | bone | 3.64 | Live accent — **fills and dots only**, ≥3:1 for UI components |
| `--clay-ink` | `#9A5B34` | bone | **5.13** | Clay-coloured *text*. Same family, AA-compliant |

The `--clay` / `--clay-ink` split is the honest resolution of the accent problem. v1 set clay
text at `#B5734F` (3.64:1 — a fail). Darkening the whole accent would dull the live indicator,
which needs to be vivid. So the dot, the fill and the border keep the original clay, and only
*text* shifts to the darker `--clay-ink`. Side by side the difference reads as emphasis, not
as two colours.

### 4.2 Colour — dark

| Token | Hex | On | Ratio |
|---|---|---|---|
| `--bone` | `#141311` | — | — |
| `--card` | `#1E1D1A` | — | — |
| `--wash` | `#262420` | — | — |
| `--ink` | `#F5F3EF` | bg | **16.75** |
| `--ink-2` | `#B8B4AB` | bg | **8.98** |
| `--ink-3` | `#A09C93` | bg | **6.78** |
| `--hair` | `rgba(255,255,255,0.10)` | — | — |
| `--clay` | `#B5734F` | bg | 4.89 |
| `--clay-ink` | `#D19770` | bg | **7.40** |

Dark mode follows the system by default with a manual override in the header. The existing
v1 tracking screen is effectively the dark palette already, which is why it transplants
cleanly.

### 4.3 Type

Unchanged in character from v1 — the Newsreader / IBM Plex Mono pairing is what gives the app
an editorial rather than administrative voice, and it is the best decision in the canvas.

| Role | Face | Size / weight |
|---|---|---|
| Screen title | Newsreader | 32 / 400 |
| Section title | Newsreader | 24 / 400 |
| Quotation, recap prose | Newsreader italic | 17 / 400, 1.5 |
| Entry title | system-ui | 15 / 500 |
| Body | system-ui | 14 / 400, 1.5 |
| Timestamp | IBM Plex Mono | 12 / 400, `tnum` |
| Metadata, labels | IBM Plex Mono | 11 / 400, tracking +0.5 |
| Timer | IBM Plex Mono | 64 / 500, `tnum` |

`font-variant-numeric: tabular-nums` on every timestamp and timer. Without it a running
clock visibly shimmers as digits change width — the single cheapest fix for making a
prototype feel engineered rather than assembled.

### 4.4 Space, radius, elevation

4px base unit. Radii: 8 chips · 14 cards · 20 sheets and modals · 28 sheet top corners ·
999 pills. Three elevation levels only — flat, card (`0 1px 2px rgba(0,0,0,0.04)`), and
sheet (`0 -8px 40px rgba(0,0,0,0.14)`). Anything needing a fourth level is over-designed.

### 4.5 Touch targets

44 × 44px minimum, universally. Where a row is visually shorter than 44px its tappable area
is extended with transparent padding rather than by inflating the design.

---

## 5. Gesture specification

The heart of the prototype. Each gesture lists its trigger, its feedback, its commit
threshold and — most importantly — how it *fails*, because an unfamiliar gesture is only
safe if abandoning it mid-way is obvious and free.

| # | Gesture | Target | Result | Commit threshold | Cancel |
|---|---|---|---|---|---|
| G1 | Vertical drag | Timeline | Momentum scroll | — | — |
| G2 | Pinch | Timeline | Cycle density (§2.3) | scale < 0.8 or > 1.25 | Release inside band → springs back |
| G3 | Swipe left | Entry row | Reveal Edit / Split / Delete | 33% of width, or velocity > 0.5 px/ms | Below threshold → springs closed |
| G4 | Swipe right | Entry row | *Again* — start this now | 45% of width | Springs closed |
| G5 | Long-press → drag | Entry row | Lift, re-time, snap to 5 min | 350ms, then any drag | Release < 8px moved → opens detail instead |
| G6 | Long-press → slide | ⊕ button | Frequents arc, release to commit | 280ms | Release on centre or outside arc → nothing |
| G7 | Drag up / down | Live bar | Expand / collapse tracking screen | 40% of travel, or velocity > 0.4 | Springs to nearer detent |
| G8 | Drag | Sheet handle | Detents: peek / half / full | Nearest detent by projected position | Drag past full → rubber-bands |
| G9 | Horizontal swipe | Day header | Page to previous / next day | 30% of width | Springs back |
| G10 | Pull down | Timeline top | Reveal yesterday's tail | 80px | Springs back |
| G11 | Drag | 24h ribbon | Scrub; timeline follows | Continuous | — |
| G12 | Long-press | Heatmap cell | Preview popover of that day | 300ms | Release → dismisses |
| G13 | Tap | Session card | Expand to constituent items | — | Tap again to collapse |

### 5.1 Rules that apply to all of them

**Directional intent lock.** On the first 10px of movement the gesture layer decides whether
this is a vertical or horizontal drag and commits to that axis for the rest of the gesture.
Without this lock, a slightly diagonal scroll half-opens every row it passes — the single most
common failure in hand-rolled swipe implementations.

**Velocity projection.** Commit decisions use *projected* resting position
(`position + velocity × 0.12`), not raw displacement. A short fast flick should commit; a long
slow drag that stops short should not. This is what makes a gesture feel like it understood
the intent rather than measured the distance.

**Interruptibility.** Every animation can be caught mid-flight. Touching a settling sheet
retargets the spring from its current position *and current velocity* — it never snaps to a
new start. This is the largest single contributor to an interface feeling native.

**Haptics.** A tick on: threshold crossed, row lifted, frequent selected in the arc, density
changed, entry committed. Fired once per crossing, never repeated while held.

**Reduced motion.** With `prefers-reduced-motion`, springs collapse to 1ms state changes.
Gestures remain fully functional — only interpolation is removed. Reduced motion must never
mean reduced capability.

**Every gesture has a visible fallback.** A gesture nobody discovers is a feature nobody has.
G2 is mirrored by a density pill in the header that cycles on tap; G3–G5 are all reachable
from the entry detail sheet; G6 is mirrored by tapping ⊕. The gestures are the fast path for
people who know them, never the only path.

---

## 6. Screens

### 6.1 Today

```
┌───────────────────────────────┐
│ TUE · 24 JUN 2026        ◐ ⌂  │  ← date pages horizontally (G9)
│ Today                          │
│ 6h12m attention · 14 media     │
│ ▓▓▒▒░░████▒▒░░░▓▓▓▓░░░░  24h  │  ← ribbon, draggable (G11)
├───────────────────────────────┤
│ 07:10 ●  Woke up               │
│ 07:40 ●  ┌ Morning routine 55m │
│          │ coffee · shower     │
│ 08:35 ●  ┌ ▤ How to build…     │  ← media, active
│          │ YOUTUBE · 8:02/12:41│
│ 09:15 ◉  ┌ Deep work — Design  │  ← live: clay dot + spine
│          │ ● 1h24m             │
│ ┄┄┄┄┄┄┄  2h13m untracked  +   │  ← gap, tappable (§2.2)
│ 12:50 ○  ┌ ♪ Ambient · 23 trk  │  ← background: hollow dot
├───────────────────────────────┤
│  ▬▬ Deep work — Design 1:24:06 │  ← live bar, drag up (G7)
│  TODAY      ⊕      ARCHIVE  ···│
└───────────────────────────────┘
```

Entry anatomy: a mono timestamp in a 46px gutter, a 1.5px spine, a dot, and a card. The dot
encodes state — filled grey for a normal entry, hollow for background media, clay with a glow
ring for live, dashed outline for a pending auto-capture.

### 6.2 Live

The v1 dark screen (`Recall.dc.html:220`) preserved: clay `TRACKING NOW` label, a 64px
tabular-numeral timer, the activity in Newsreader, quick `+ note / + media / + photo` chips,
and Switch / Stop. It now arrives by dragging the live bar up, tracks the drag one-to-one,
and can be dismissed by dragging back down at any point.

### 6.3 Quick-add sheet

Detents at peek (frequents grid only), half (adds quick-type and autocomplete), and full
(adds time, place, tags). Autocomplete draws from the user's own history ranked by frequency
and time-of-day, so at 08:00 "Gym — push day" outranks "Dinner" without being asked.

### 6.4 Frequents arc (G6)

Long-pressing ⊕ fans four frequents into a 120° arc above the button, sized and positioned for
a right thumb. The nearest item to the thumb scales up and ticks haptically; release commits.
Releasing on the centre or beyond the arc commits nothing. The four are chosen by usage
weighted toward the current hour.

### 6.5 Entry detail

Evolves the moment screen at `Recall.dc.html:248`. For media it adds a completion arc, the
attention flag as a toggle, source and creator, and a "where this came from" provenance line —
*shared from Safari*, *auto-detected*, *logged by you* — because trust in an auto-populated
archive depends on being able to ask where any given line came from.

### 6.6 Capture and auto-ingest

Three tiers, in order of how much they deserve to exist:

1. **Automatic** — share sheet, GPS for places, Health for sleep and steps, and eventually a
   network-level or browser-level media source.
2. **Frequents** — one gesture, no typing, the everyday path.
3. **Manual** — full sheet. The fallback, and it should feel like one.

Auto-captured entries arrive as `status: 'pending'` with a dashed spine dot, and collect in a
confirm queue. **Nothing enters the permanent archive unconfirmed.** This is a deliberate
constraint: an archive you do not trust is worse than no archive, and a single wrong
auto-entry seen at the top of the day poisons confidence in everything beneath it. The
prototype simulates this trickle precisely so the question *does auto-capture feel helpful or
does it feel like spam* gets an answer before any ingestion plumbing is built.

### 6.7 Archive and Insights

Archive keeps the v1 heatmap — darker means fuller — with long-press preview (G12) and
on-this-day. Insights leads with the written weekly recap, followed by attention split
(active vs background, the number most likely to be genuinely surprising), sources ranked by
time, and completion rate.

### 6.8 Empty state

A first day shows the ribbon fully hatched, a single Newsreader line — *"Nothing yet. Start
the day."* — and the frequents grid raised inline rather than hidden behind the sheet, so the
first log of a session is one tap from a cold open.

---

## 7. Motion

| Class | Stiffness | Damping | Used for |
|---|---|---|---|
| Snappy | 400 | 32 | Row swipes, chips, taps |
| Standard | 260 | 26 | Sheets, live bar, detents |
| Gentle | 180 | 24 | Screen transitions, density changes |

Implemented as a real spring integrator on `requestAnimationFrame`, not CSS easing curves,
because only a spring carries velocity across an interruption.

**Only `transform` and `opacity` animate.** Nothing that triggers layout or paint is ever
put on an animation frame. Entries that move during a re-time use FLIP so reordering is a
transform, not a reflow.

---

## 8. Data model

The schema the native app inherits — decided here rather than improvised in Swift.

```js
Entry {
  id,
  kind: 'block' | 'media' | 'moment' | 'session',
  start,                       // ISO 8601
  end,                         // ISO 8601 | null while live
  title,
  tags: [],
  place?, people?: [],

  // media
  source?: 'youtube'|'tiktok'|'spotify'|'netflix'|'kindle'|'podcast'|'web',
  creator?,
  durationMs?,                 // length of the work
  consumedMs?,                 // how much was actually taken in
  attention?: 'active' | 'background',
  items?: [Entry],             // children of a session

  // provenance
  origin: 'manual' | 'share' | 'auto',
  confidence?,                 // 0–1, auto only
  status: 'confirmed' | 'pending',

  note?, photo?, spend?
}
```

Three notes on why this shape:

- **`consumedMs` is separate from `durationMs`.** Abandonment is signal. A twelve-minute video
  closed at ninety seconds says something a completion flag cannot.
- **`attention` is on the entry, not inferred.** Any attempt to infer active versus background
  from duration or source will be wrong often enough to discredit the totals. It is a cheap
  toggle and an honest field.
- **`origin` and `status` are permanent, not ingestion-time scaffolding.** Six months on, the
  question "did I record this or did the machine?" is exactly the question you will want to
  ask of a surprising line.

---

## 9. Open questions for the native build

1. **Encryption.** This is among the most sensitive datasets a person could assemble — every
   video, every location, every purchase. Local-only with an encrypted export is the
   defensible default; anything involving a server needs end-to-end encryption designed in
   from the first commit, not added later.
2. **Which automatic source ships first.** The share sheet is trivial and high-value; a
   network-level DNS logger is broad but blind inside HTTPS, so it can tell you *YouTube* but
   never *which video*; a browser extension gives titles but only covers the browser. The v1
   note at `Recall.dc.html:374` frames this trade-off correctly and it remains unresolved.
3. **Whether re-live ever becomes a timed playback.** A day replayed at pace, as a story, is
   an appealing idea and an enormous amount of work. It should not be attempted until the
   capture loop is proven to survive a month of real use.
4. **Retention of pending entries.** If auto-capture is left unconfirmed for a week, does the
   queue expire, auto-confirm, or accumulate? Accumulation risks a demoralising backlog;
   auto-confirmation violates §6.6. Likely answer: expire silently after seven days, on the
   grounds that an unreviewed record is not worth the trust it costs.

---

## 10. Prototype scope

`Recall.proto.html` implements §5 and §6 in full, with simulated auto-ingest and
`localStorage` persistence, so that several days of real use can be had before any native
code is written. It deliberately excludes real ingestion, accounts and sync.

**Seed behaviour.** Today is seeded at absolute clock times (wake 07:10, and so on) and only
the entries the clock has actually reached are present — a day in progress is genuinely
partial. Two full past days are always seeded so Archive, Insights and day-paging have
substance. If the app is opened before the day has four entries in it, it opens on yesterday
and says so, because a 00:40 "today" is correct but tells you nothing about the design.

The prototype's purpose is to answer three questions that cannot be answered from a canvas:

1. Does capture actually cost under three seconds in the hand?
2. Does auto-capture feel like help, or like spam?
3. Is the gap-backfill flow inviting enough to survive contact with a 10pm reconstruction?
