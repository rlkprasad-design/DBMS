# DBMS Quest

A calm, laptop-first recall game for Database Management Systems terms -
word search and spelling/unscramble modes, with a shared class scoreboard.
Sibling app to BA Quest (Business Analytics) - same engine, same
previously-fixed bugs avoided, different subject content.

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
2. Run `supabase/schema.sql` once to create the tables, enable RLS, and add
   the (intentionally open, no-login) policies.
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
- `data/levels.json` - grid size range and filler mode, matching BA Quest's
  9-15 range.
- `scripts/validate-content.js` - run with `node scripts/validate-content.js`
  before shipping any content change. No dependencies.

### Decisions made explicit

Same as BA Quest, for consistency across the two apps:

- **Tracing/handwriting mode**: not included.
- **Max grid size**: 15x15 (fits longer single-word DBMS terms like
  NORMALIZATION/DECOMPOSITION/INCONSISTENCY).
- **Reward tiers**: Bronze / Silver / Gold for easy / medium / difficult,
  worth 1 / 3 / 6 base marks - mapped to grouped Bloom's Taxonomy levels
  (easy = Remember+Understand, medium = Apply+Analyze, difficult =
  Evaluate+Create).
- **Mode multiplier**: Word Search ("crossword") awards double a tier's base
  marks per find; Spelling awards the base value as-is. Finding a word
  hidden among filler letters is a harder recall task than typing it from
  its jumbled-letters hint, so it's worth more - see `MODE_MULTIPLIERS`
  in `js/gems.js`.
- **`scenario` field**: present in the schema from day one.

## Puzzle engine notes

Identical engine to BA Quest - see that repo's README for the full writeup
of the anti-repetition draw-queue design and the exhaustion-detection fix
(a single unlucky small-grid roll is never mistaken for "seen everything";
a guaranteed max-grid-size fallback roll is required before concluding the
pool is exhausted). The engine code here (`js/puzzle-engine.js`,
`js/wordsearch-ui.js`, `js/spelling-ui.js`, `js/gems.js`, `js/identity.js`,
`js/storage.js`) is unchanged from BA Quest except for the `dbmsquest.`
localStorage prefix noted above.

## Known gap from this environment

Built and tested in a sandboxed dev environment whose network policy
blocks arbitrary external hosts, including `esm.sh` (used to load
`@supabase/supabase-js`) and the Supabase project's own domain. Everything
that doesn't require reaching those hosts was verified in a real Chromium
browser: the name gate and history notice, word-search drag-to-find
(including the gem-burst animation's actual rendered bounding box), the
"Show answer" visual distinction, spelling mode's type-to-answer flow,
and the scoreboard's graceful no-crash fallback when Supabase can't be
reached. The actual round-trip to Supabase (writing a score, reading
the scoreboard back, submitting a flag) could not be exercised from this
environment and should be checked once deployed.

## Deployment

Deployed via GitHub Pages from `main`. Enable it once under the repo's
Settings > Pages > Deploy from a branch > `main` / root, if not already on.
Development happens on feature branches with one focused PR per change,
squash-merged to `main`.
