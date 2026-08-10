# Changelog

## 1.0.1

- Added native Gen1Recomp GitHub release update metadata.

## 1.0.0

- Final release based on the fully tested v0.1.0-test11 appraisal flow.
- Renamed Oak's three-way choice to **SHOW POKéMON / SHOW POKéDEX / CANCEL**.
- Moved **SHOW POKéMON** above **SHOW POKéDEX** so the new appraisal feature is the default highlighted choice.
- Widened the Oak choice menu to 15 tiles so both new labels fit cleanly.
- Applied the same ordering and labels to PROF.OAK's PC and Professor Oak in his lab.

## 0.1.0-test11

- Shortened the outstanding-DV follow-up from `Its natural potential is remarkable!` to `Its potential is remarkable!`.
- The outstanding-DV follow-up now fits in one two-line appraisal TextBox: `Its potential is` / `remarkable!`.

## 0.1.0-test10

- Shortened the developing-training follow-up so it fits cleanly in one two-line dialogue box: `It still needs lots of training.`

## 0.1.0-test9

- Finalized the shorter appraisal copy after in-game readability review.
- DV copy changes:
  - `Its natural potential is remarkable!` replaces the longer `...truly remarkable!`.
  - `Its potential is above average.` replaces `Its natural potential is above average.`.
- Training copy now uses compact `Its stats ...` wording instead of repeatedly spelling out `Stat Experience`.
- Complete tier: `Its stats are fully developed!` / `It reached its full potential!`.
- Nearly-complete tier: `Its stats are remarkably high!` / `It's very near its full potential.`.
- Well-trained tier: `Its stats show lots of training.` / `It still has room to grow!`.
- Developing tier: `Its stats are growing nicely.` / `There's lots of training left to do.`.
- Starting tier: `Its stats are still quite low.` / `You two are just getting started!`.
- Retained the single `OAK: Let's see... / <name>!` intro, native `<PK><MN>'s` glyph pair, width-aware wrapping, curated `poten- / tial` hyphenation and fresh-press pacing.

## 0.1.0-test7

- Removed the repeated `OAK: ` prefix from all actual appraisal verdicts.
- Added one short immersive intro TextBox after party selection: `OAK: Let's see...` followed by the selected Pokemon's real display name/nickname on line two.
- Standardized every DV verdict to begin `Your <PK><MN>'s DVs are ...`.
- Restored natural `Its Stat Experience ...` wording now that speaker attribution is handled separately.
- Kept `<PK><MN>'s` atomic, width-aware wrapping, curated potential hyphenation, and fresh-press pacing.

## 0.1.0-test6

- Corrected the compact Pokemon reference from literal `[Pk][Mn]` text-style markers to Gen1Recomp's actual native charmap glyph macros: `<PK><MN>`.
- DV verdicts now render the same two Gen I glyphs used by vanilla UI labels such as `WITHDRAW <PK><MN>` and append the possessive as `<PK><MN>'s`.
- `<PK><MN>'s` remains an atomic layout token and can never be line-split or hyphenated.
- Updated headless font tests so `<PK>`, `<MN>`, and the vanilla `'s` ligature are measured as glyph sequences rather than ASCII byte counts.

## 0.1.0-test5

- Prefixed every semantic appraisal message with `OAK: ` so the speaker is always explicit.
- Replaced variable species/nickname insertion in DV verdicts with the fixed Gen I `<PK><MN>'s` wordmark.
- Marked `<PK><MN>'s` as an atomic appraisal-layout token: it is never hyphenated or split across rows.
- Appraisal text layout is now identical regardless of the selected Pokemon's species name or nickname.
- Retained width-aware wrapping, curated `poten-` / `tial` hyphenation, and fresh-press pacing from test4.

## 0.1.0-test4

- Added width-aware appraisal text layout using the active Gen1Recomp TextBox width (18 vanilla cells).
- Added curated hyphenation for `potential` as `poten-` / `tial` when it makes better use of the current row.
- Semantic appraisal sentences can now expand into multiple physical TextBoxes when clean wrapping needs more than two rows.
- Every physical TextBox still contains at most two lines and requires its own fresh A/B press.
- Removed the assumption that the four semantic appraisal parts must always equal exactly four physical dialogue boxes.
- Kept the no-tutorial direct-to-party flow from test3.

## 0.1.0-test3

- Removed the first-use DV/IV and Stat Experience/EV terminology tutorial completely.
- **POKéMON** now goes directly from Oak's choice menu to the native party picker every time.
- Split appraisal output into four short, separate TextBox messages instead of longer multi-page dialogue.
- Each appraisal message requires its own fresh A/B press.
- Appraisal messages are limited to at most two explicit lines and contain no `\f` page breaks.

## 0.1.0-test2

- Added a per-dialog fresh-press gate: each appraisal TextBox waits for A/B release before accepting the next advance.
- Prevents the A press used for a menu/party selection or previous dialogue from spilling into the newly opened dialogue.
- Corrected the ordinary-DV wording so it no longer implies that immutable DVs can improve through training.

## 0.1.0-test1

- Added POKEDEX / POKEMON / CANCEL choice behind PROF.OAK's PC.
- Preserved the vanilla Pokedex rating callback.
- Added native PartyMenu selection for Pokemon appraisal.
- Added four DV appraisal tiers based on the Gen I 0–60 DV sum.
- Added five training tiers based on effective Stat Experience contribution.
- Added one-time DV/IV and Stat Experience/EV terminology explanation.
- Added read-only scoring exports for testing and compatibility.
