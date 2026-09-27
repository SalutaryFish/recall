# F-001 · Background tracks

| | |
|---|---|
| **Feature** | F-001 — media playing *alongside* the main task (music, YouTube, …) |
| **Doc version** | v0.3 · 2026-09-27 (v0.2 = decisions · v0.1 = brainstorm in handoff v1.0.0 §14) |
| **Status** | **Web (v2.1.0)** — first prototype, in phone testing |
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

### Added while planning web v2.1.0 (user, 2026-09-27)

6. **The mini bar sits *above* the main live bar**, not under it. The slot under the main bar,
   just above the tab bar, is where ⊕ pokes up and would cover the mini bar's middle. The main
   bar doesn't move when a track starts.
7. **Data is kept across days** in the prototype, so an overnight test (music + sleep timer in
   bed) can be looked at the next morning. Web v2.0.0 replaced everything with a fresh sample
   day on each new day. Now only a store holding nothing but sample data is refreshed. Live
   timers count correctly past midnight.

### Defaults in web v2.1.0 (not user decisions — confirm or change on the phone)

- **Switching** the main task (Switch, a frequent, the ⊕ arc, swipe-right *again*) **carries live
  tracks over** to the new task: the music keeps playing, and rule 1 still holds. Only **Stop**
  asks what to keep.
- **Promotion mechanics:** at the stop moment the kept track and its current item end in the
  background lane, and a **new main-lane entry starts at the same moment**. The main lane never
  overlaps, and background minutes stay background. A promoted item becomes an *active* media
  entry. Limitation: a promoted main task has no "next".
- The stop sheet's **Keep** button previews the result (“How X works” becomes the main task).
  **ALWAYS STOP EVERYTHING** remembers the choice; You → STOP WITH ♫ PLAYING switches it back.
- The track's name is stored in `title` (not a separate `name`), so search, autocomplete and
  export work unchanged.
- **YouTube titles and channels** come from YouTube's own oEmbed endpoint: only YouTube sees the
  pasted link, the same as the app's LinkPresentation lookup. If it fails, the title is editable.
  A browser can't read any other site's title, so other links show the hostname and ask for a
  title.
- Track, item and break times keep **seconds**, because a 20-second break is a real break.

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
- On tracks: `advance`: `manual` | `auto`; ~~`name`~~ → the track's name is its `title` (v0.3).

As built in web v2.1.0 (localStorage `recall.v2`; times are minutes on the entry's own day,
with seconds, and may run past 1440):
- **Track** = `kind:'track'`, `lane:'background'`, `parentID` → main task, `title`, `advance`,
  `queue: [{title, source, url?, creator?, durationMs?}]` (auto mode, not started yet),
  `sleepAt?` / `sleepFor?` (sleep timer), `asleep?` (the sleep timer stopped it), `pauses`.
- **Item** = `kind:'media'`, `lane:'background'`, `parentID` → track, `source` (provider id),
  `url?`, `creator?`, `durationMs?` (typed length), `consumedMs` (span − breaks, set when it
  ends), `pauses` (the track's breaks that fell inside it).
- A **promoted** main task carries `promotedFrom` (the item or track it continues).
- Seeded entries carry `sample: true`. The store refreshes only while it is samples-only.

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

In web v2.1.0 this is the `PROVIDERS` list in `web/index.html`, and the old `SOURCES` table is
derived from it. It holds YouTube (title and channel from oEmbed), TikTok, Spotify, Netflix,
Podcast, Kindle and a generic web link, all of which recognise their links. A typed item has no
link. Only YouTube can look up a title from a browser.

## Visual design (to prototype)

- **Mini live bar** docked **above** the main live bar (decision 6): ♫ glyph · item title · track
  timer · ⏸/▶ · **next/+** (paste link). Swipe left = stop track; tap = track sheet (queue,
  history, breaks, advance mode). Quieter than the main bar — *only live is loud*: soft/hollow
  clay pulse.
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

### Where things are in web v2.1.0

- **Start a track:** **♫** on the main live bar, or **+ ♫ track** on the expanded live screen.
  Recent track names are one tap; "what's playing" is optional, and so is MANUAL/AUTO next.
- **Mini bar:** tap → track sheet · ⏸/▶ · **+** (paste a link or type a title) · swipe left stops
  the track.
- **Track sheet** (tap the mini bar or a ♫ chip): strip of items and breaks, the list, UP NEXT
  (auto mode), NEXT MANUAL/AUTO, SLEEP OFF/15/30/60, Pause/Resume, Stop item (or Skip to next),
  Stop track. A finished track can be deleted from its sheet.
- **Stop with a track playing:** Stop everything / Keep ♫ … (the button says what becomes the
  main task) / ALWAYS STOP EVERYTHING.
- **You → F-001 · OPEN QUESTIONS:** KEPT TRACK BECOMES ITEM/TRACK and MAX TRACKS 1/2, so both
  variants can be tried in the hand. The sample days (after **Reset**) have tracks, so the rail,
  chip and ribbon lane can be judged at once.

### Not in v2.1.0 (next versions, once the core loop feels right)

On-demand promote/demote ("I'm actually watching this"), retro-editing (drag item edges, split,
insert a forgotten "next"), track frequents and a ♫ slot in the ⊕ arc, the Insights "soundtrack"
section, and "next" on a promoted main task. Insights already counts track time as background
without adding it to the logged total.

## Still open (answer during web testing)

1. When a kept track is promoted, is the new main task named after the **track** ("Media") or the
   **current item** ("How X works")? *v2.1.0 default: the item (the track if nothing plays);
   switch in You → KEPT TRACK BECOMES.*
2. If several tracks are kept, which becomes main — the most recent, or ask every time?
   *v2.1.0: the most recent is preselected in the stop sheet's MAIN row, so both.*
3. Do breaks subtract from the item's "consumed" time (yes by default)? *v2.1.0: yes.*
4. Maximum tracks in the first UI: one, or two? *v2.1.0 default: one; switch in You → MAX TRACKS.*
