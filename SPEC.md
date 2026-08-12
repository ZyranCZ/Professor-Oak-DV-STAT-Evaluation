# Locked specification — v1.0.0

Target: Gen1Recomp Mod API 2. No engine-version pin is declared; newer engine releases are allowed to attempt loading the mod.

## Entry flow

1. Use a normal Pokemon Center PC.
2. Choose **PROF.OAK's PC**.
3. The mod presents **SHOW POKéMON / SHOW POKéDEX / CANCEL**, in that order.
4. **SHOW POKéDEX** executes the original Gen1Recomp Oak callback unchanged.
5. **SHOW POKéMON** immediately opens the built-in PartyMenu in immediate-pick mode. No tutorial is shown.
6. After a selection, show exactly one short immersive speaker/name TextBox: first line `OAK: Let's see...`, second line the selected Pokemon's actual display name/nickname followed by `!`.
7. Then Oak evaluates four semantic parts without repeated `OAK:` prefixes: DV verdict -> natural potential -> Stat Experience-based training/stat verdict -> remaining-training/potential verdict.
8. Each semantic part is laid out to the 18-column TextBox width. If it needs more than two rows, it is split into additional physical TextBoxes.
9. Every physical appraisal TextBox requires its own fresh A/B press.
10. Oak's normal link-closing text is shown and control returns to the PC menu.
11. Cancelling the PartyMenu returns to the Oak choice menu.

## Dialogue pacing

- Appraisal content MUST use separate TextBox instances rather than `\f` page breaks inside one long TextBox.
- `OAK:` MUST appear only in the one post-selection speaker/name intro box, not in the actual appraisal verdicts.
- Every DV verdict MUST begin with `Your <PK><MN>'s DVs are ...`.
- DV verdicts MUST use the fixed native `<PK><MN>'s` glyph pair instead of the selected Pokemon's species name or nickname.
- `<PK>` and `<MN>` MUST use the native Gen1Recomp charmap glyphs. `<PK><MN>'s` is an atomic word for appraisal layout: it MUST NOT be hyphenated or split across rows.
- Source appraisal sentences are passed through a width-aware layout step before TextBox construction.
- The layout budget is the active TextBox `maxCols` value, falling back to 18 vanilla cells.
- `potential` may be split at the approved break `poten-` / `tial` when that uses otherwise-wasted row space.
- Laid-out lines are grouped into physical TextBoxes of at most two explicit lines each.
- Therefore the number of physical boxes is dynamic; the four semantic appraisal parts are not required to equal exactly four boxes.
- Every physical appraisal TextBox requires a fresh A/B press.
- A new box waits until A and B have both been released for three consecutive update frames before it begins accepting normal TextBox input.
- The A press used to choose **SHOW POKéMON**, select a party member, or close the preceding box must never advance the newly opened box.
- This gate applies only to this mod's dialogue and does not patch global input behavior.

## No terminology tutorial

The mod MUST NOT show a first-use explanation of DVs, IVs, Stat Experience or EVs. The **SHOW POKéMON** option always goes directly to PartyMenu.

The short `OAK: Let's see... / <name>!` box after selecting a Pokemon is speaker identification only, not a terminology tutorial. The visible appraisal keeps the canonical Gen I term **DVs**. Training tiers are still calculated from canonical Gen I **Stat Experience**, but the shortened player-facing copy uses `stats` / `training` wording instead of spelling out `Stat Experience`.


## Locked appraisal copy

After the one speaker/name intro, the semantic verdict strings are locked as follows. The layout layer may only wrap/hyphenate them; it must not paraphrase them.

### DV

- 50–60: `Your <PK><MN>'s DVs are outstanding!` / `Its potential is remarkable!`
- 40–49: `Your <PK><MN>'s DVs are very good.` / `Its potential is above average.`
- 31–39: `Your <PK><MN>'s DVs are fairly ordinary.` / `Its natural potential is decent.`
- 0–30: `Your <PK><MN>'s DVs are rather low.` / `Its natural potential is limited.`

### Stat Experience / training

- 100%: `Its stats are fully developed!` / `It reached its full potential!`
- >70–<100%: `Its stats are remarkably high!` / `It's very near its full potential.`
- >40–70%: `Its stats show lots of training.` / `It still has room to grow!`
- >20–40%: `Its stats are growing nicely.` / `It still needs lots of training.`
- 0–20%: `Its stats are still quite low.` / `You two are just getting started!`

The shorter visible word `stats` is presentation copy only. Tier calculation remains based on effective Gen I Stat Experience.

## DV score

Count only the four independently stored Gen I DVs:

- Attack 0–15
- Defense 0–15
- Speed 0–15
- Special 0–15

HP DV is derived and MUST NOT be counted again. Score range: 0–60.

- 50–60: outstanding
- 40–49: above average
- 31–39: ordinary
- 0–30: limited

## Training score

For each of HP / Attack / Defense / Speed / Special:

`effective = floor(min(255, ceil(sqrt(statExp))) / 4)`

Each effective contribution is 0–63. Total score is 0–315.

- 0–20%: starting
- >20–40%: developing
- >40–70%: well trained
- >70–<100%: nearly complete
- 100%: complete

The 100% tier is based on effective stat contribution, not the raw 16-bit counter. A stat reaches the maximum effective contribution of 63 at raw Stat Experience 63002; further raw growth through 65535 does not increase that stat through the Stat Experience term.

## Non-goals

- No changes to DVs, Stat Experience, level, EXP, or calculated stats.
- No battle changes.
- No save-schema changes.
- No direct boxed-Pokemon picker in this release.
- No replacement of the vanilla Pokedex rating.

---

# Gold / Gen 2 port addendum — v2.0.0

## Invariants

1. Gold support is additive: Red / Blue / Yellow behavior must remain v1.0.2-compatible.
2. The four stored DVs remain the complete DV score. HP DV is derived and never a fifth bucket.
3. The five Stat Experience words remain the complete training score. Gold Special is shared by Sp. Atk / Sp. Def and counted once.
4. Appraisal verdict strings, DV/training tier thresholds, layout rules and fresh-press behavior are frozen.
5. Appraisal remains party-only and read-only.
6. Professor Elm never preempts a native branch: every completed `ProfElmScript` conversation runs fully vanilla first, and appraisal is appended only afterward via `script.ended`.
7. Eggs are not appraisable before hatch and must not leak hidden species or score information.

## Generation orchestration

Shared core:

- numeric clamping;
- DV sum / tiers;
- five-bucket training sum / tiers;
- verdict copy;
- width-aware appraisal layout;
- fresh-press TextBox behavior;
- selected-Pokémon display-name handling;
- exports.

Gen I backend:

- `ui.pc.items` → PROF.OAK's PC;
- `dex_rating` command → Oak's Lab only.

Gold backend:

- `screen.pushed` → per-instance `Gen2CenterPcMenu` decoration;
- `script.command` → exact Goldenrod Happiness Rater provenance;
- `script.command` → observation-only Elm conversation arming on native `faceplayer` (all commands delegate unchanged); exact Goldenrod Happiness Rater behavior remains its separate interception.
- `script.ended` → Professor Elm supplemental UI only after the same armed run completes successfully.

## Gold effective Stat Experience

Gen I must retain the v1.0.2 expression:

`floor(min(255, ceil(sqrt(statExp))) / 4)`

Current Gold `Mon.lua` uses:

`floor(sqrt(statExp) / 4)`

Therefore the backend selects the generation-appropriate effective contribution while sharing all five bucket keys and the 0–315 tier model. This specifically preserves the intentional Gen I result at raw `63002` while matching Gold's current calculation there.

## Gold Oak PC contract

The mod never inserts the top-level Oak row. It decorates only a native `Gen2CenterPcMenu` instance and only when `entries[index].id == "oaks"`.

Root menu order is fixed:

1. SHOW POKéMON
2. SHOW POKéDEX
3. CANCEL

SHOW POKéDEX invokes the captured native `choose` with the Oak row still selected. SHOW POKéMON opens `Gen2PartyMenu` in direct-selection mode. Party B returns to the custom Oak choice. Root Cancel returns to Center PC. A completed appraisal invokes native `oakClosed()`.

## Gold Professor Elm contract

- Identify Elm by Gold + `ELMS_LAB` + NPC object 1. The dynamically resolved root `ProfElmScript` key is diagnostic/fallback provenance, not a required equality check.
- Accept either friendly map id `ELMS_LAB` or cartridge group 24 / map 5 as map identity.
- Arm appraisal only after observing Elm's native opening `faceplayer` command. Immediately delegate that command unchanged.
- Never open Elm UI from `script.command`; do not replace, suppress, branch, resume or alter any native Elm command result.
- Bind the armed marker to the current VM run; a different VM/run cannot consume it.
- `script.started` clears stale markers; incomplete/aborted/mismatched `script.ended` also clears without UI.
- A bare `script.ended` is insufficient, preventing stale `hLastTalked` from causing sign/bookshelf false positives.
- Suppress the supplemental UI while the party is empty, which covers pre-starter Elm.
- After the armed run completes successfully, open **APPRAISE / CANCEL** only after vanilla completion.
- All native story/reward branches therefore retain absolute priority and side effects.
- APPRAISE uses direct `Gen2PartyMenu`; party B returns to the supplemental menu.
- Eggs are refused without species/DV/training leakage and the party picker reopens.
- A completed Elm appraisal returns to the overworld; it must never emit Oak-PC close copy.

## Gold Happiness Rater contract

Root menu order is fixed:

1. CHECK HAPPINESS
2. APPRAISE
3. CANCEL

The hook must match generation + map id + map group + map number + teacher object + dynamically resolved teacher scriptKey + `GetFirstPokemonHappiness`.

CHECK HAPPINESS delegates to the original command chain exactly once. APPRAISE may choose any non-Egg party member, uses the Rater-style intro, and terminates the vanilla happiness branch after appraisal. Party B returns to the root choice. Root B/CANCEL ends the conversation.

VM callbacks are one-shot. Every parked menu / picker / TextBox continuation may resume the VM at most once.

## Egg policy

An Egg may remain visible as `EGG` in the native party screen. Selecting it shows only:

`An EGG can't be`  
`appraised yet.`

The refusal must not reveal species, DVs, Stat Experience, potential or training tier. The picker then reopens.


## RC.5 validation delta

RC.5 changes validation scope, not the RC.4 Elm runtime mechanism. Additional invariants are now executable: unrelated Gold metadata cannot enter DV/training score; full selected-mon state stays read-only; fainted/statused/Lv100 mons remain appraisable; CHECK HAPPINESS transparently delegates all six threshold outcomes and native first-non-Egg selection; intermittent repeated A cannot bypass the fresh-press neutral gate; and repeated `game.ready` cannot duplicate Gold registrations inside one loaded entry closure. Physical runtime and actual multi-mod composition remain separate live gates.
