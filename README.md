# DBMS Quest

A calm, laptop-first recall game for Database Management Systems terms -
word search, spelling/unscramble, true/false, and card grouping modes,
with a shared class scoreboard. Sibling app to BA Quest (Business
Analytics) - same engine, same previously-fixed bugs avoided, different
subject content.

## Running locally

No build step. Serve the folder with any static file server and open it:

```
python3 -m http.server 8000
# then open http://localhost:8000/
```

## Setting up Supabase

This app shares a Supabase project with other apps (BA Quest, and the
original VOM game). All of its tables are prefixed `dbms_`
(`dbms_scores`, `dbms_flagged_terms`) so nothing collides with the other
apps' tables in the same project.

1. Open your Supabase project's SQL Editor.
2. Run `supabase/schema.sql` to create the tables, enable RLS, and add the
   (intentionally open, no-login) policies. The whole file is safe to
   re-run any time content or the schema changes - `create table if not
   exists` and `alter table ... add column if not exists` are both
   idempotent, so re-running it against an already-live project only adds
   what's missing (e.g. the four per-mode marks columns added for the
   scoreboard breakdown below) without touching existing data.
3. `js/config.js` already has this project's `SUPABASE_URL` and anon
   (publishable) key filled in.

If `js/config.js` is ever left blank, the game runs fully offline: puzzles,
spelling sets, and local progress all work, but scores stay on that device
and never reach the shared scoreboard. The Supabase client loads lazily
(dynamic `import()` only when a URL/key are present), so a missing or
unreachable Supabase project can never break the rest of the app.

### Important: localStorage is shared across apps on the same GitHub Pages account

BA Quest and DBMS Quest are both served under `rlkprasad-design.github.io`,
which means they share the same browser **origin** - and `localStorage` is
scoped per-origin, not per-path. To keep the two apps' player data from
colliding, every local storage key in this app is prefixed `dbmsquest.`
(BA Quest uses `baquest.`). If you ever copy this engine again for a third
subject under the same GitHub account, give it its own prefix too - see
`js/identity.js` and `js/puzzle-engine.js` for where the prefix lives.

## Content

- `data/questions.json` - the term bank: `{ word, meaning, scenario, difficulty, source }`.
  - `difficulty` is one of `easy | medium | difficult`, mixed together in
    every puzzle.
  - `scenario` is an optional short situational description (e.g. "why did
    the transfer disappear when the server crashed?" style) - included from
    day one, unused by v1's UI, so a later "apply this concept" exercise
    type is just new content, not a schema migration.
  - `source` is a free-text category tag for the curator's own
    organization (e.g. "Transactions (ACID)") - never shown to players.
- `data/levels.json` - grid size range and filler mode: 9-13 (smaller than
  BA Quest's 9-15 - lowered after real play found 15x15 grids uncomfortably
  large; see the decision below).
- `scripts/validate-content.js` - run with `node scripts/validate-content.js`
  before shipping any content change. No dependencies.

### Decisions made explicit

Same as BA Quest, for consistency across the two apps:

- **Tracing/handwriting mode**: not included.
- **Max grid size**: 13x13 - lowered from an initial 15x15 after real play
  found the largest grids uncomfortably big on a laptop screen. Only two
  words needed 15 (`SERIALIZABILITY`, `SELFREFERENCING`); both were renamed
  to shorter, equally standard terms (`SERIALIZABLE`, `SELFJOIN`) rather
  than dropped, so no content was lost. The longest word now (13 chars:
  NORMALIZATION/DECOMPOSITION/INCONSISTENCY) exactly matches the new cap.
- **Reward tiers**: Bronze / Silver / Gold for easy / medium / difficult,
  worth 1 / 3 / 6 base marks - mapped to grouped Bloom's Taxonomy levels
  (easy = Remember+Understand, medium = Apply+Analyze, difficult =
  Evaluate+Create).
- **Mode multiplier**: Word Search ("crossword") and Card Grouping award
  double a tier's base marks per find; Spelling and True/False award the
  base value as-is. Finding a word hidden among filler letters, or
  correctly recalling which category a term belongs to, is a harder recall
  task than assembling a word from an already-isolated letter tray or
  making a binary true/false call - see `MODE_MULTIPLIERS` in `js/gems.js`.
- **`scenario` field**: present in the schema from day one.

## Puzzle engine notes

Identical engine to BA Quest - see that repo's README for the full writeup
of the anti-repetition draw-queue design and the exhaustion-detection fix
(a single unlucky small-grid roll is never mistaken for "seen everything";
a guaranteed max-grid-size fallback roll is required before concluding the
pool is exhausted). The engine code here (`js/puzzle-engine.js`,
`js/wordsearch-ui.js`, `js/spelling-ui.js`, `js/truefalse-ui.js`,
`js/grouping-ui.js`, `js/gems.js`, `js/identity.js`, `js/storage.js`) is
unchanged from BA Quest except for the `dbmsquest.` localStorage prefix
noted above (and BA Quest's `scenarios[]`-pool feature for measurement
scales, which has no equivalent here since no DBMS term needs it).

- **Per-mode scoreboard breakdown**: `dbms_scores` carries a `..._marks`
  column per game mode (`wordsearch_marks`, `spelling_marks`,
  `truefalse_marks`, `grouping_marks`) alongside the existing
  `total_marks`. `recordFind(playerName, difficulty, marksDelta, mode)`
  takes the mode as its 4th argument and increments both the tier count
  (bronze/silver/gold) and the matching mode column in the same upsert -
  see `MODE_COLUMN` in `js/supabase-client.js`. The scoreboard table shows
  one column per mode so a teacher can see, per student, how much of their
  total came from each exercise type, not just the grand total.
- **Time spent**: `dbms_scores.total_seconds` accumulates the wall-clock
  time between a puzzle/set/round starting and its completion, added once
  per completion via `recordTimeSpent(playerName, secondsDelta)` (called
  from each `*-ui.js`'s `checkCompletion`, alongside - not instead of -
  `recordFind`). This is approximate by nature: it's measuring elapsed
  wall-clock time, not focused attention, so a backgrounded or idle tab
  between starting and finishing counts too. `MAX_SECONDS_PER_COMPLETION`
  (1 hour) caps what a single completion can add, so a tab left open
  overnight doesn't inflate the total unboundedly. The scoreboard formats
  it as `Xh Ym` / `Xm Ys` / `Xs` via `formatDuration` in `js/scoreboard.js`.
  Like the per-mode breakdown, this only accumulates from the moment the
  feature shipped forward - there's no way to reconstruct time spent on
  puzzles completed before this column existed.

### True/False mode

- `drawTrueFalseSet` (`js/puzzle-engine.js`) draws from the same mixed
  difficulty pool as word search/spelling. For each drawn word, it flips a
  coin: heads, the claim shown is that word's own meaning/scenario (true);
  tails, the claim is borrowed from a different entry - preferring one of
  the same difficulty tier so an impostor claim doesn't stand out just by
  looking harder or easier. The borrowed entry isn't itself counted as
  exposed, since it isn't really being asked about.
- Marks are only awarded for a genuine correct guess. "Show answer" reveals
  the truth and locks the card, but earns nothing, matching the same
  convention as word search/spelling.

### Card Grouping mode

- `drawGroupingRound` needs no new content: it buckets by each entry's
  existing `source` tag (already present purely for curator organization
  elsewhere) rather than any new taxonomy. It only offers categories with 2
  or more not-yet-exposure-capped members, and returns `null` (triggering
  the "seen everything" screen) once fewer than 2 such categories remain.
- Placing a card correctly awards marks immediately and removes it from the
  tray; placing it in the wrong bucket shakes that bucket and leaves the
  card selected for another attempt. A round completes once every drawn
  card has been correctly placed.

## Known gap from this environment

Built and tested in a sandboxed dev environment whose network policy
blocks arbitrary external hosts, including `esm.sh` (used to load
`@supabase/supabase-js`) and the Supabase project's own domain. Everything
that doesn't require reaching those hosts was verified in a real Chromium
browser: the name gate and history notice, word-search drag-to-find
(including the gem-burst animation's actual rendered bounding box), the
"Show answer" visual distinction, spelling mode's letter-click-to-build
flow, true/false's answer/lock/reveal flow, card grouping's
select-then-place flow (including the wrong-bucket shake), and the
scoreboard's graceful no-crash fallback when Supabase can't be reached.
The actual round-trip to Supabase (writing a score, reading
the scoreboard back, submitting a flag) could not be exercised from this
environment and should be checked once deployed.

## Deployment

Deployed via GitHub Pages from `main`. Enable it once under the repo's
Settings > Pages > Deploy from a branch > `main` / root, if not already on.
Development happens on feature branches with one focused PR per change,
squash-merged to `main`.
