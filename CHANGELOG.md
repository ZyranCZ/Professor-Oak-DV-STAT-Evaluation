# Changelog

## 2.0.0

### Stable Gen 2 release
- Promoted the tested `1.1.0-rc.5` runtime unchanged to stable **2.0.0**.
- Added Pokémon Gold support while preserving Red / Blue / Yellow behavior.
- Gold appraisal is available through native **PROF.OAK's PC**, Goldenrod's Happiness Rater, and Professor Elm after Elm's complete native dialogue finishes.
- Preserves native Oak Pokédex rating and native Happiness Rater behavior.
- Keeps Egg appraisal opaque and read-only.
- Retains four stored DV / five Stat Experience scoring semantics in Gold, with shared Special counted once.
- Keeps `experimental: false` and intentionally has no `game_version` compatibility gate.

### Verification
- Gen I regression suite: PASS.
- Gold expanded headless suite: PASS.
- RC.5 live Gold behavior was reported to function correctly and is the exact runtime promoted here.
- Broader cross-mod smoke testing remains recommended after future upstream or dependency changes.

## 1.1.0-rc.5

### Validation / hardening
- Kept the RC.4 Professor Elm runtime mechanism unchanged; RC.5 adds no new Elm interception behavior before the next bundled live test.
- Expanded Gold headless scoring coverage to prove that held items, happiness, gender, shiny state, Pokérus, Unown/form-style metadata, records and separate Sp. Atk / Sp. Def convenience fields do not become appraisal score buckets.
- Expanded selected-Pokémon read-only coverage to include party identity/order, moves, OT, gender, shiny state, Pokérus and record metadata.
- Added fainted / statused / level-100 appraisal coverage.
- Added transparent **CHECK HAPPINESS** delegation tests for all six native happiness tiers and first-non-Egg behavior.
- Added stronger fresh-press coverage using intermittent held-A/autofire-style input; three consecutive neutral frames remain required before a new appraisal TextBox receives input.
- Added repeated `game.ready` installation checks and retained per-instance Center PC wrapper idempotence coverage.

### Compatibility status
- Gen I regression suite: PASS.
- Gold headless suite: PASS.
- The current upstream Gen 2 compatibility documentation explicitly lists `script.started`, `script.ended`, and `script.command` as the supported Gold scripting seams used by this candidate.
- Official `gen2check --strict --notes` remains pending because a runnable local upstream checkout is not available in this sandbox; this is not reported as a PASS.
- Physical Gold / Red / Blue / Yellow and real cross-mod testing remain intentionally batched for the later live matrix before stable v1.1.0.

## 1.1.0-rc.4

### Fixed
- Reworked Professor Elm again after live rc.3 testing still produced no supplemental appraisal menu.
- Removed runtime equality with the dynamically resolved Elm `scriptKey` as an activation requirement.
- Elm conversations are now armed by observing his native `faceplayer` command in `ELMS_LAB`; the command is delegated unchanged and cannot open appraisal UI itself.
- The supplemental **APPRAISE / CANCEL** menu is still created only after successful `script.ended` for the same observed VM run.
- Map matching accepts either `ELMS_LAB` or cartridge group 24 / map 5.

### Story / false-positive safety
- Vanilla Elm commands retain absolute priority: no Elm text, branch, item reward, flag write or return value is replaced or short-circuited.
- New-script, aborted-run and mismatched-run paths clear Elm bookkeeping before it can leak.
- A bare `script.ended` no longer qualifies. This guards against Gold's intentionally stale `hLastTalked` value on signs/callbacks.
- Pre-starter empty-party suppression and Egg opacity remain unchanged.

### Validation status
- Gen I regression suite: PASS.
- Gold headless suite: PASS, including deliberately mismatched Elm `scriptKey`, friendly-map-id-only and group/number-only contexts, same-VM binding, pass-through ordering, stale-context suppression and aborted-run suppression.
- Physical Gold live test remains required before stable v1.1.0.

## 1.1.0-rc.3

### Fixed
- Rebuilt Professor Elm integration after live testing showed the rc.2 idle-terminal command hook did not surface the appraisal menu.
- Elm appraisal is now an artificial **post-dialogue** menu driven by Gold's `script.ended` lifecycle event.
- Removed all Elm-specific `script.command` interception and imported idle-branch detection.
- Prevented Elm appraisal completion from falling into the Oak-PC `Closed link to PROF.OAK's PC.` copy.

### Priority / story safety
- Every native `ProfElmScript` conversation has absolute priority and must complete successfully before the mod can show **APPRAISE / CANCEL**.
- This applies to ordinary dialogue and to Mystery Egg, Togepi/Everstone, Master Ball, S.S. Ticket and other story/reward branches: the mod appears only after their native text and side effects have finished.
- Pre-starter Elm remains untouched because an empty party suppresses the post-dialogue menu.
- Exact provenance still requires Gold generation, `ELMS_LAB` group 24 / map 5 / object 1 and the dynamically resolved root Elm script. Aborted runs do not trigger appraisal.

### Validation status
- Gen I regression suite: PASS.
- Gold headless suite: PASS, including command pass-through, post-dialogue ordering, pre-starter suppression, exact provenance, cancellation, Egg handling and no Oak-PC close-text leak.
- Physical Gold live test of Elm remains required before stable v1.1.0.

## 1.1.0-rc.2

### Added
- Added Professor Elm appraisal in Pokémon Gold.
- The first safe Elm appraisal opportunity is the ordinary repeat conversation immediately after receiving the starter.
- Added **APPRAISE / CANCEL** after Elm's vanilla safe repeat/idle dialogue.
- Added headless coverage for Elm provenance, immediate post-starter appraisal, party cancellation, Egg refusal, later safe repeat branches, and negative story-branch isolation.

### Safety / compatibility
- Elm's one-shot story and reward branches remain untouched: Mystery Egg hand-off, stolen-Pokémon follow-up, aide/Egg reminder, Togepi/Everstone, Master Ball and S.S. Ticket flows are not decorated.
- Safe Elm branches are discovered from the imported `ProfElmScript` control-flow graph, not hardcoded ROM pointers or English dialogue text.
- Because Gold's VM memoizes the root `scriptKey` for the whole run, the mod keys the exact imported terminal command tables of approved idle branches while also requiring `ELMS_LAB` group 24 / map 5 / object 1 and the resolved root `ProfElmScript`.
- Red / Blue / Yellow behavior and the existing Gold Oak PC / Happiness Rater flows are unchanged.

### Validation status
- Gen I regression suite: PASS.
- Gold headless suite including Elm flows: PASS.
- Current upstream `dev` rechecked at `01aab1d763c2e2d6878a0a25d606c02b3f569818`.
- Physical Gold live / cross-mod matrix: NEEDS LIVE TEST before stable v1.1.0.

## 1.1.0-rc.1

### Added
- Added Pokémon Gold support as a live-test release candidate.
- Added Gold appraisal through the native **PROF.OAK's PC** context.
- Added in-person appraisal through Goldenrod's Happiness Rater with **CHECK HAPPINESS / APPRAISE / CANCEL**.
- Added Egg-safe appraisal refusal and reprompting without species/DV leakage.
- Added Gold headless tests for scoring, PC progression boundaries, native delegation, party selection, Egg handling, Happiness Rater provenance and VM resume behavior.
- Added read-only Gold diagnostics and Gold-specific effective Stat Experience exports.

### Compatibility
- Red / Blue / Yellow appraisal behavior, copy, tiers, layout and fresh-press semantics remain unchanged from v1.0.2.
- Gold uses four stored DVs and five Stat Experience buckets; HP DV is derived and Special DV/Stat Experience are counted once.
- Gold training appraisal follows the current Gold `Mon.lua` `floor(sqrt(statExp) / 4)` contribution. Gen I intentionally retains v1.0.2's ceil-sqrt behavior.
- Gold Oak PC integration decorates only an existing native `oaks` row and never manufactures it before the Pokédex.
- Bill's PC, Player's PC, Hall of Fame and Professor Elm are untouched.
- No engine-version allow-list was added; `experimental` remains false.

### Validation status
- Gen I regression suite: PASS.
- Gold headless suite: PASS.
- Official `tools/modkit.py gen2check`: BLOCKED in the build sandbox because the upstream tool checkout is unavailable locally; static MK400–MK410 review performed instead.
- Physical Gold live / cross-mod matrix: NEEDS LIVE TEST before stable v1.1.0.

## 1.0.2

- Removed the `game_version` manifest pin so Gen1Recomp updates no longer disable the mod solely because the engine version changed.
- Future engine releases are treated as best-effort compatible until an actual incompatibility is observed.
- Explicitly marks the mod as non-experimental.


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
