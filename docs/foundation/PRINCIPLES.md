# Principles

| | |
|---|---|
| **Document** | foundation/PRINCIPLES · **v1.0** · 2026-09-27 |
| **Changes only when** | the user decides a principle changes (record why in the change note below) |

The full product specification is `docs/spec/Recall-UX.md`. This file is the part of it that must
never drift, plus the direction the user has set since.

## What Recall is

- A **transcript of a day.** Timestamps run down the left in mono; a day reads like a log.
- **Media-first.** Videos, tracks, episodes, posts and books are the primary object. Everything else
  (blocks of activity, places, people, thoughts, photos) gives that media context.
- **Detailed about media**: source, creator, length of the work vs. how much was taken in, and
  whether it had your *attention* (active) or merely played (background).
- **Cheap to feed.** Anything that can be captured automatically is; manual entry is the fallback.
- **Honest about gaps.** Untracked time is shown as untracked, never silently omitted.

## What Recall is not

- Not a productivity scorer: no streaks, goals, guilt or "screen time is up 12%". It reports; it
  doesn't judge.
- Not an inventory of things owned. Not a social product: nothing is shared, ranked or compared.

## Design principles

1. **Capture must cost under three seconds**, or the habit dies. One-tap frequents, the ⊕ arc,
   autocomplete from your own history.
2. **Read the shape, then the detail.** A day must be legible as a silhouette (the 24 h ribbon,
   proportional densities) before a single word is read.
3. **The interface is calm; only *live* is loud.** One accent colour (clay), reserved for things
   happening right now.
4. **Gestures over chrome — but every gesture has a visible fallback** (a button, a pill, a sheet
   action) and a VoiceOver action. A gesture nobody discovers is a feature nobody has.
5. **Nothing unconfirmed enters the archive.** Auto-captured entries arrive pending; `origin` and
   `status` stay on the record forever ("did I log this, or did the machine?").
6. **Attention is recorded, not inferred.** A cheap toggle beats a clever guess that ruins the totals.
7. **Local-first and private.** This is one of the most sensitive datasets a person can assemble.
   No accounts; data stays on the device; any future sync must be end-to-end encrypted by design.
8. **Every animation can be interrupted** and carries velocity; Reduce Motion removes interpolation,
   never capability.

## Product direction set by the user

- **Modular and intentional.** Build features as small, composable pieces with clear seams — e.g.
  media *sources* are pluggable providers ("backends"), and task structure is general enough to grow
  (multiple background tracks, nesting) without rewrites. Start with what the user uses daily; add
  providers over time.
- **Foundations before extras.** Stabilise the core loop before conveniences (e.g. fetching a
  video's length comes later; manual "next" comes first).
- **The user decides by feel, on the phone.** Designs are judged in the hand, which is why the web
  prototype comes first (`WORKFLOW.md`).

## Visual language (summary — tokens in `docs/spec/Recall-UX.md` §4)

- Bone background, white cards, ink text; greys tuned for WCAG AA (timestamps ≥ 5:1); clay accent
  split into `clay` (fills/dots) and `clay-ink` (text). Full dark palette.
- **Newsreader** (serif) for titles and prose; **IBM Plex Mono** for the transcript, labels and
  numbers (tabular); system sans for entry titles/body.
- 4 pt grid; radii 8 chips · 14 cards · 28 sheet tops · pills; three elevations only.
- Springs, not easing curves: snappy 400/32 · standard 260/26 · gentle 180/24.
- Touch targets ≥ 44 × 44 pt everywhere.

## Change log of this document

- v1.0 (2026-09-27) — first version, distilled from spec v2.0 and the user's direction.
