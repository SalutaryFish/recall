# Recall docs

Two kinds of documents live here, kept apart on purpose:

- **Foundation** — the rules and philosophy of the project. They change rarely, and only when the
  user decides so. Read these before building anything.
- **Handoff** — the state of the project at the end of a working session (what exists, what's
  broken, what's next). Written fresh every session; old ones are never edited.

```
docs/
├── README.md                 this map
├── CHANGELOG.md              every released web / app / spec version, and how they map
├── foundation/               ── the rules ──
│   ├── PRINCIPLES.md         what Recall is, design philosophy, visual language
│   ├── WORKFLOW.md           web-first: every feature is prototyped and approved on the web first
│   ├── VERSIONING.md         how everything is versioned, tagged and named
│   └── ENGINEERING.md        code structure, modularity, Swift/CI rules, tests
├── features/                 one design doc per feature (F-001, F-002, …) with its status
│   └── F-001-background-tracks.md
├── spec/
│   └── Recall-UX.md          the product/UX specification (spec v2.0)
├── handoff/                  ── session state ──
│   ├── README.md             index — points to the latest handoff
│   └── HANDOFF-v*.md
└── archive/
    └── v1-canvas/            the original v1 design canvas (superseded, kept for history)
```

## The three golden rules

1. **Web first.** No feature goes into the iOS app before it has been built in the web
   prototype (`web/`), tested on the phone, and approved by the user. → `foundation/WORKFLOW.md`
2. **Everything is versioned.** Every change to the web prototype or the app bumps its version;
   released versions are frozen and tagged; nothing is ever overwritten. → `foundation/VERSIONING.md`
3. **Every session ends with a handoff.** A new, versioned file in `handoff/`. → `handoff/README.md`

## Where things are

| Thing | Location | Latest |
|---|---|---|
| Web prototype (latest) | `web/index.html` → https://salutaryfish.github.io/recall/ | see `CHANGELOG.md` |
| Web prototype (frozen versions) | `web/versions/v<X.Y.Z>/` → https://salutaryfish.github.io/recall/versions/ | |
| iOS app | `ios/` (built by GitHub Actions, installed with iloader) | see `CHANGELOG.md` |
| Product spec | `docs/spec/Recall-UX.md` | spec v2.0 |
| Latest handoff | `docs/handoff/README.md` | |
