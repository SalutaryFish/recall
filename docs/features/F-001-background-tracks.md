# F-001 · Background tracks

| | |
|---|---|
| **Feature** | F-001 — media playing *alongside* the main task (music, YouTube, …) |
| **Doc version** | v0.2 · 2026-09-27 (v0.1 = brainstorm in handoff v1.0.0 §14) |
| **Status** | **Design** — decisions recorded; next: first prototype as **web v2.1.0** |
| **Approved in web** | — |
| **Shipped in app** | — |

## Problem

Music or a YouTube video often plays *while* doing something else — coding with a video on,
lying in bed with music. Today Recall can only have one live thing, so background media is either
lost or has to replace the real task. The ACTIVE / BACKGROUND attention split in Insights can't be
honest without it.

## Decisions (user, 2026-09-27)

1. **A background track can't exist without a main task.** If you want to track only media, make it
   the main task. *(Agreed. The one moment this could break is covered by rule 2's "keep".)*
2. **Stopping the main task offers a choice:** stop everything, or keep some or all background
   tracks going. **Reconciliation with rule 1:** a kept track is **promoted to be the new main
   task** (e.g. stop "Coding", keep "YouTube: How X works" → the video becomes the main task). If
   several tracks are kept, one becomes main and the rest stay background under it.
3. **Sources are modular "backends".** Start with what the user uses daily (YouTube, music, typed
   entries); podcasts, audiobooks, movies etc. are allowed and added later as new providers.
4. **Advancing is the user's choice per track:** **manual "next"** (default — adding a link ends the
   current item) or **auto-advance** when an item's length is known. Pauses mustn't break
   auto-advance (it counts *playing* time, not wall-clock time). Fetching lengths automatically is
   a later capability, after the foundations are stable.
5. **Built to grow:** the model must allow **multiple background tracks** and **nesting** later
   without a rewrite (see *Model*). Example from the user: main task *School* → sequential
   sub-tasks *Math*, then *English* → during Math a *Restroom* break runs alongside while still in
   class.

## Concepts

| Term | Meaning |
|---|---|
| **Main task** | The foreground live block. Exactly one at a time (as today). |
| **Track** | A named background container ("Media", "Background slop", "Music") attached to a main task. Plays one **item** at a time. |
| **Item** | One piece of media in a track (a YouTube link, a playlist, a typed title). Has start/end and pauses. |
| **Break** | A paused interval inside a track/item. Stored, never deleted; drawn as a hatched gap. |
| **Segment** | (future) A sequential child of a main task — *School → Math → English*. Same "next" mechanic as items. |

## Behaviour

- **Start a track** (only while a main task is live): name it (or pick a recent/frequent track).
- **Add item:** paste a link (title/source resolved by the provider) or type a title. With manual
  advance, adding ends the current item *now* and starts the new one *now*.
- **Pause / resume** the track: the current item and the track freeze; resume records a break.
- **Stop item:** ends just the current item; the track stays live but idle (shows "nothing playing").
- **Stop track:** ends the track and its current item.
- **Stop main task:** sheet with **Stop everything** / **Keep …** (checkbox per live track). Kept
  tracks follow rule 2. The choice can be remembered ("always stop everything").
- **Promote / demote:** "I'm actually watching this" makes an item the main task (the old main ends
  or becomes background); a main media task can be pushed into a track.
- **Sleep timer** (for the in-bed case): stop the track after 15/30/60 min, flagged "may have fallen
  asleep".
- **Retro-editing:** drag item boundaries, split an item, insert a forgotten "next".
- **Frequents for tracks:** "lofi mix", "Hyperpop for Cooking", "resume last track" in one tap; the
  ⊕ arc may gain a ♫ slot.

## Model (designed for growth — first implemented in the web prototype, then RecallCore)

Every entry keeps its existing fields and gains optional ones (old data still loads):
- `lane`: `main` | `background` (default `main`).
- `parentID`: the entry this belongs to (a track → its main task; an item → its track; a segment →
  its main task).
- `pauses`: list of `{start, end}` intervals.
- On tracks: `advance`: `manual` | `auto`; `name`.

Invariants: one live main task; every live track has a live main parent (except during the
promotion step of rule 2); one playing item per track; pauses lie inside their entry. Multiple
tracks per main task and deeper nesting are allowed by the data from day one; **the first UI may
limit itself to one track** until the user asks for more.

## Source providers (the modular "backends")

One small unit per source, registered in one list:
`id · name · glyph · matches(url) · resolve(url) → {title, creator, duration?} · capabilities`
(`canResolveTitle`, `canResolveDuration`, `isAudio`, `isVideo`).
First set: **YouTube**, **generic link** (page title), **typed / music** (no link). Later: Spotify,
Apple Music, podcasts, audiobooks, movies/TV, duration fetching. Adding one must not touch the rest.

## Visual design (to prototype)

- **Mini live bar** docked under the main live bar: ♫ glyph · item title · track timer · ⏸/▶ ·
  **next/+** (paste link). Swipe left = stop track; tap = track sheet (queue, history, breaks,
  advance mode). Quieter than the main bar — *only live is loud*: soft/hollow clay pulse.
- **Timeline sidecar rail:** a thin `tone-media-bg` vertical rail at the right edge of the card
  column, drawn per row for the minutes a track overlapped that row (works in all three
  densities); item changes = small ticks; breaks = hatched gaps.
- **Attached chip** under the overlapped main-task card: `♫ with Lo-fi mix · 1h10m · ⏸ 12m`;
  tap → track detail.
- **Ribbon lane:** a 2 pt lane under the 24 h ribbon showing when any track played, gaps for breaks.
- **Track detail:** mini timeline of items with breaks, per-item provider/source, edit/split.
- **Insights:** soundtrack of the week, % of focus time with background media, top background
  sources/creators, longest listening stretch; ACTIVE/BACKGROUND split becomes exact.

## Prototype plan — web v2.1.0 (what to test on the phone)

- [ ] Start a main task, start a track, add two YouTube links (second ends the first).
- [ ] Pause and resume; the break shows in the mini bar, the rail and the chip.
- [ ] Stop an item; stop the track; start another track later.
- [ ] Stop the main task → Stop everything / Keep (promotion).
- [ ] Rail, chip and ribbon lane read clearly at transcript / proportional / ribbon densities.
- [ ] Manual vs auto advance toggle (auto uses a typed length for now).
- [ ] Typed item without a link; the sleep timer.

## Still open (answer during web testing)

1. When a kept track is promoted, is the new main task named after the **track** ("Media") or the
   **current item** ("How X works")?
2. If several tracks are kept, which becomes main — the most recent, or ask every time?
3. Do breaks subtract from the item's "consumed" time (yes by default)?
4. Maximum tracks in the first UI: one, or two?
