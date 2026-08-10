# Locked specification — v1.0.0

Target: Gen1Recomp v0.1.75 / `60cf07fb0a1ffce0ec6d5d0d2f78a921a6d0b7da`.

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
