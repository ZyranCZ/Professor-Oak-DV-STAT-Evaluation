# Professor Oak's Pokemon Appraisal

**v1.0.1** for **Gen1Recomp v0.1.75** (`60cf07fb0a1ffce0ec6d5d0d2f78a921a6d0b7da`).

Adds a Pokemon appraisal service to **PROF.OAK's PC** in Pokemon Centers and to **Professor Oak himself in his lab**, while preserving the existing Pokedex rating.

## In game

Open a Pokemon Center PC and choose **PROF.OAK's PC**. Oak's entry now offers, with the Pokemon appraisal deliberately placed first:

- **SHOW POKéMON** — immediately opens the normal party screen and lets you choose one Pokemon for appraisal.
- **SHOW POKéDEX** — runs Gen1Recomp's existing vanilla Pokedex-rating callback.
- **CANCEL** — returns to the previous menu/dialogue.

The same **SHOW POKéMON / SHOW POKéDEX / CANCEL** menu is used when speaking directly to Professor Oak in his lab once his normal dialogue reaches the Pokédex-rating phase. A direct Pokémon appraisal returns to the lab instead of showing the PC link-closing message.

There is no terminology tutorial or first-use explanation. Choosing **SHOW POKéMON** always goes straight to the party picker. After selecting a party member, one short speaker-introduction box is shown:

`OAK: Let's see...`
`<selected Pokemon name>!`

This is the only appraisal-related box that uses `OAK:` or the Pokemon's variable name/nickname. The actual evaluation then uses fixed text.

The appraisal is split into short, separate dialogue boxes. The four semantic parts are still:

1. DV verdict.
2. Natural-potential verdict.
3. Training/stat verdict based on Stat Experience.
4. Remaining-training/potential verdict.

However, a semantic part may now occupy more than one physical dialogue box when that is needed for clean layout. Each physical box contains at most **two visible text lines** and requires its own fresh A/B press.

The actual appraisal verdicts do **not** repeat `OAK:`. Every DV verdict begins **`Your <PK><MN>'s DVs are ...`** and uses the fixed Gen I **`<PK><MN>'s`** glyph pair instead of repeating the selected species name or nickname. This keeps the evaluation layout deterministic after the one immersive intro box. `<PK>` and `<MN>` are the game's native one-tile charmap glyphs; `<PK><MN>'s` is treated as one atomic word and is never hyphenated or split across rows.

Appraisal text uses its own 18-column layout pass before the normal TextBox renderer. When a curated long word would otherwise waste the end of a row, the mod may hyphenate it. For example, `potential` can be rendered as `poten-` / `tial`. The resulting lines are then grouped two at a time into separate TextBoxes.

A press used to choose a menu option, select a Pokemon, or dismiss the previous box cannot spill into the next box.

## DV appraisal

The appraisal uses the four independently stored Gen I DVs: Attack, Defense, Speed and Special. Each is 0–15, so the maximum sum is **60**. HP DV is derived from those four and is not counted a second time.

| DV sum | Appraisal tier |
|---:|---|
| 50–60 | Outstanding |
| 40–49 | Above average |
| 31–39 | Fairly ordinary |
| 0–30 | Limited |

## Training appraisal

The mod evaluates all five Gen I Stat Experience buckets: HP, Attack, Defense, Speed and Special.

It measures **effective stat contribution**, not raw `statExp / 65535`. Gen1Recomp's Gen I formula converts each Stat Experience value to:

`floor(min(255, ceil(sqrt(statExp))) / 4)`

That produces **0–63 effective training points per stat**, or **0–315 total**. A 100% appraisal therefore means further Stat Experience can no longer increase any stat through the Gen I Stat Experience term.

| Effective training | Appraisal tier |
|---:|---|
| 0–20% | Just getting started |
| >20–40% | Developing |
| >40–70% | Well trained |
| >70–<100% | Nearly complete |
| 100% | Full training potential |


## Appraisal copy

After the one `OAK: Let's see... / <name>!` intro, the current fixed verdict copy is:

### DV verdicts

| DV sum | DV verdict | Potential verdict |
|---:|---|---|
| 50–60 | `Your <PK><MN>'s DVs are outstanding!` | `Its potential is remarkable!` |
| 40–49 | `Your <PK><MN>'s DVs are very good.` | `Its potential is above average.` |
| 31–39 | `Your <PK><MN>'s DVs are fairly ordinary.` | `Its natural potential is decent.` |
| 0–30 | `Your <PK><MN>'s DVs are rather low.` | `Its natural potential is limited.` |

### Training verdicts

| Effective training | Stat/training verdict | Potential verdict |
|---:|---|---|
| 100% | `Its stats are fully developed!` | `It reached its full potential!` |
| >70–<100% | `Its stats are remarkably high!` | `It's very near its full potential.` |
| >40–70% | `Its stats show lots of training.` | `It still has room to grow!` |
| >20–40% | `Its stats are growing nicely.` | `It still needs lots of training.` |
| 0–20% | `Its stats are still quite low.` | `You two are just getting started!` |

The visible wording says **stats/training** for readability, but these five tiers are still calculated exclusively from Gen I **Stat Experience**, not level EXP.

## Compatibility approach

- Uses the official `ui.pc.items` hook rather than patching PC tile logic or replacing `OverworldState` methods.
- Calls `next()` first and decorates only the `PROF.OAK's PC` descriptor.
- Preserves the original Oak callback for **SHOW POKéDEX**.
- Uses the public `mod.ui` facade for Menu, TextBox and PartyMenu.
- Does not change Pokemon data, DVs, Stat Experience, stats, save schema or battle mechanics.
- Compatible by design with Special Stat Split because Gen I still has one shared Special DV and one shared Special Stat Experience bucket.

## Current scope

The release evaluates Pokemon currently in the **party**. Direct selection of Pokemon stored inside boxes is outside the current scope.
