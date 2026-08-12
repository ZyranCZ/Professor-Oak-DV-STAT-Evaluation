# Professor Oak's Pokemon Appraisal

**v2.0.0** for **Gen1Recomp Mod API 2**.

This stable release adds **Pokémon Gold** support while preserving the existing Red / Blue / Yellow appraisal behavior. The mod intentionally has no `game_version` pin and remains `experimental: false`; engine versions are not allow-listed.

## Where appraisal is available

### Red / Blue / Yellow

**PROF.OAK's PC** and Professor Oak in **Oak's Lab** keep the existing v1.0.2 flow:

- **SHOW POKéMON** — choose a party Pokémon to appraise.
- **SHOW POKéDEX** — use the game's original Pokédex rating.
- **CANCEL** — return without appraisal.

Oak's Lab is intercepted only when the vanilla story has already reached Oak's normal Pokédex-rating phase. Earlier Oak story dialogue is untouched.

### Pokémon Gold

Gold uses three natural locations:

**PROF.OAK's PC** in a Pokémon Center:

- **SHOW POKéMON**
- **SHOW POKéDEX**
- **CANCEL**

The mod does not create Oak's PC entry itself. It becomes available naturally when Gold unlocks **PROF.OAK's PC** after receiving the Pokédex. Bill's PC, the player's item PC and Hall of Fame remain separate native entries.

**Goldenrod Happiness Rater**:

- **CHECK HAPPINESS** — continues into Gold's original Happiness Rater behavior.
- **APPRAISE** — choose any non-Egg party Pokémon for DV / training appraisal.
- **CANCEL** — ends the conversation cleanly.

**Professor Elm** in Elm's Lab:

- The mod never replaces, branches, suppresses or resumes an Elm command. Every command is passed to Gold unchanged.
- During the real Elm conversation the mod only observes Elm's native opening `faceplayer` command. That arms a one-run marker; it does **not** open any UI or change the script result.
- Gold's complete native `ProfElmScript` conversation then finishes normally, including the active story/reward branch and all of its side effects.
- Only the subsequent successful `script.ended` for that same observed run may open the separate **APPRAISE / CANCEL** menu.
- This is available on the first manual conversation with Elm after receiving the starter because the player then has a party Pokémon.
- Mystery Egg, stolen-Pokémon, Togepi/Everstone, Master Ball, S.S. Ticket and later Elm dialogue therefore keep absolute priority; appraisal is merely appended after whichever vanilla conversation just completed.

v2.0.0 deliberately does **not** require Elm's imported `scriptKey` to equal the runtime root key. Elm is identified by Gold + `ELMS_LAB` + Elm's NPC object (with the resolved root key only as a fallback when object context is missing) and, critically, by observing his native `faceplayer` command. `script.ended` by itself is insufficient, preventing stale `hLastTalked` from making a sign or bookshelf look like Elm. Before the starter, an empty party suppresses the supplemental menu.

**Eggs cannot be appraised before they hatch.** Selecting an Egg gives a short refusal without revealing the hidden species, DVs or training data and returns to the party picker.

## What is appraised

The mod keeps **natural potential** and **training** separate.

### Natural potential — DVs

It scores the four independently stored DVs:

| DV | Range |
|---|---:|
| Attack | 0–15 |
| Defense | 0–15 |
| Speed | 0–15 |
| Special | 0–15 |

Maximum: **60**. HP DV is derived from those four and is not counted again. In Gold, Sp. Atk and Sp. Def still share the same stored Special DV for this appraisal.

| DV sum | Tier |
|---:|---|
| 50–60 | Outstanding |
| 40–49 | Above average |
| 31–39 | Fairly ordinary |
| 0–30 | Limited |

### Training — Stat Experience

Five buckets are scored in both generations:

`HP / Attack / Defense / Speed / Special`

Gold still has one shared Special Stat Experience word for both Sp. Atk and Sp. Def, so Special is counted **once**, not twice. Held items, happiness, Pokérus, gender and shininess do not alter the appraisal score.

Red / Blue / Yellow intentionally retain the exact v1.0.2 effective-training formula:

`floor(min(255, ceil(sqrt(statExp))) / 4)`

Current Gold stat calculation uses:

`floor(sqrt(statExp) / 4)`

The difference matters only at a few raw boundaries, but the Gold backend follows Gold's current `Mon.lua` arithmetic while Gen I remains unchanged. Both produce 0–63 effective points per bucket and 0–315 total.

| Effective training | Tier |
|---:|---|
| 0–20% | Just getting started |
| >20–40% | Developing |
| >40–70% | Well trained |
| >70–<100% | Nearly complete |
| 100% | Full training potential |

## Appraisal presentation

After party selection, Oak's routes use the existing introduction:

`OAK: Let's see...`  
`<selected Pokémon name>!`

Goldenrod's Happiness Rater uses her own style:

`Oh? Let me see`  
`your <selected Pokémon name>...`

Professor Elm uses:

`ELM: Let's see...`  
`<selected Pokémon name>!`

The actual verdict copy remains the v1.0.2 copy. Appraisal layout keeps the 18-cell budget, native `<PK><MN>'s` token handling, at most two visible rows per physical TextBox, width-aware wrapping, approved `poten- / tial` hyphenation, and a fresh A/B press for every box.

## Compatibility design

- Red / Blue / Yellow keep the existing `ui.pc.items` and Oak Lab `dex_rating` integration, installed only on Gen I.
- Gold's top-level Center PC is handled only through the native `Gen2CenterPcMenu` instance; the mod never inserts appraisal into Bill's storage PC or the player's item PC.
- Gold's **SHOW POKéDEX** delegates to the captured native Oak PC behavior.
- Goldenrod appraisal is restricted by generation, map id, map group/number, teacher object id, dynamically resolved exact `scriptKey`, and `GetFirstPokemonHappiness` special identity.
- Elm's `script.command` seam is observation-only: the mod records the native `faceplayer` beat for Elm and immediately delegates the command unchanged. Supplemental UI can be created only later by successful `script.ended` for the same run, so every vanilla Elm branch finishes first.
- **CHECK HAPPINESS** executes the native happiness special exactly once. **APPRAISE** ends the vanilla happiness branch after the custom appraisal so both evaluations are never accidentally shown together.
- Appraisal is read-only: party order, DVs, Stat Experience, HP, status, moves, held item, happiness, OT, gender, shiny state and Pokérus are not changed.
- Existing public exports remain available. Gold-specific effective-training helpers are additive exports.

## Current scope

Appraisal is for **party Pokémon only**. Direct boxed-Pokémon selection remains outside this release.

## Release validation

Automated Gen I regression and expanded Gold headless suites pass. The Elm runtime mechanism proven through RC.4/RC.5 is promoted unchanged: Elm's complete native conversation always runs before the supplemental appraisal menu. Coverage includes mismatched runtime `scriptKey`, map-id/group-number fallback, vanilla-command pass-through, post-dialogue priority, pre-starter suppression, stale-context suppression and aborted-run suppression.

RC.5 was also exercised in live Gold and reported to behave correctly, so it is promoted to stable **v2.0.0**. The broader scripted cross-mod matrix remains useful as future compatibility smoke testing, but is no longer a release blocker.
