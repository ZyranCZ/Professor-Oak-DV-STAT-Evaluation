# Compatibility — v2.0.0

## Supported game targets

- Red / Blue / Yellow (`gen1`)
- Pokémon Gold (`gold`)

Silver and Crystal are **not** declared. Gold support does not imply generic `gen2` support.

## Engine / Mod API

- Mod API: 2
- `game_version`: intentionally absent
- `experimental`: false
- `engine_internals`: not requested
- Dependencies: none
- Optional dependencies: none
- Declared conflicts: none

## Gen I preservation contract

The Gold port is additive. Red / Blue / Yellow keep the v1.0.2 routes, scorer semantics, tier thresholds, verdict copy, text layout, fresh-press behavior, exports and menu ordering.

Gen I installs only:

- `ui.pc.items` for **PROF.OAK's PC**
- the existing `dex_rating` command interception for Oak's Lab, restricted to `OAKS_LAB`

Gold boot does not access the Gen I `dex_rating` registry.

## Gold Oak PC

Gold does **not** use `ui.pc.items` for Oak's top-level PC. That hook belongs to Bill/storage rows in the Gold implementation.

Instead the mod listens for the native `Gen2CenterPcMenu` screen and decorates each concrete instance once. Only an already-existing row with `id == "oaks"` is intercepted.

Consequences:

- before `ENGINE_POKEDEX`: no Oak row is created and appraisal is absent;
- after Pokédex: Oak's existing row gains **SHOW POKéMON / SHOW POKéDEX / CANCEL**;
- **SHOW POKéDEX** delegates to the captured original `CenterPcMenu:choose()`;
- **SHOW POKéMON** uses direct non-mutating `Gen2PartyMenu` selection;
- completion calls native `oakClosed()`;
- Bill's PC, Player's PC and Hall of Fame remain native.

## Gold Professor Elm

Professor Elm uses an observation-only, post-dialogue integration. **No Elm command is replaced or short-circuited.**

RC.2 and RC.3 proved that making Elm appraisal depend on an assumed imported/root `scriptKey` was too brittle in live Gold. The stable v2.0.0 design therefore does not use `scriptKey` equality as an activation requirement.

The live sequence is:

1. A new Gold script run begins; stale Elm bookkeeping is cleared.
2. While the run is in `ELMS_LAB`, the mod observes the native `faceplayer` command only when the context identifies Elm's NPC (object 1; dynamically resolved Elm root key is only a fallback if object context is unavailable).
3. That command is delegated to the native VM unchanged. The mod does not open UI at this point.
4. Every subsequent Elm command and whichever vanilla story/reward branch is active run normally.
5. Only a successful `script.ended` for the **same VM run** can consume the marker and append **APPRAISE / CANCEL**.
6. The marker is cleared before any supplemental UI is pushed, and is also cleared on aborted/mismatched runs.

Map identity accepts either the friendly `ELMS_LAB` id or the cartridge group 24 / map 5 pair. This avoids depending on which representation a particular Gold runtime path populated.

The observed native `faceplayer` beat is important for safety: Gold intentionally permits `hLastTalked`/`ctx.object` to be stale for signs and callbacks. Therefore a bare `script.ended` with object 1 is **not** enough to trigger appraisal. A bookshelf or sign cannot consume an old Elm identity unless the current run actually executed Elm's `faceplayer` command.

Before the starter, the party is empty and the supplemental menu is suppressed. Immediately after receiving the starter, the next manual conversation with Elm can be followed by appraisal. Story/reward branches such as Mystery Egg, Togepi/Everstone, Master Ball and S.S. Ticket retain absolute priority because appraisal does not exist until their native run is complete.

The supplemental appraisal is outside the VM coroutine. Party B returns only to the supplemental menu; selecting an Egg remains opaque and reprompts the party picker; a completed appraisal returns directly to the overworld without Oak-PC close text.

## Gold Happiness Rater

The personal route is restricted to the exact Goldenrod teacher interaction. The hook requires all available provenance to match:

- generation `2`;
- map id `GOLDENROD_HAPPINESS_RATER`;
- map group `11`;
- map number `5`;
- object `1`;
- the exact teacher `scriptKey`, resolved from the current loaded map definition;
- special name `GetFirstPokemonHappiness`.

The special is not overridden globally.

**CHECK HAPPINESS** calls the native special exactly once and lets the untouched vanilla threshold/text branch continue. **APPRAISE** runs the party appraisal and then returns `"end"` so the happiness branch is not executed afterward.

## Gold data model

Natural-potential score:

- Attack DV
- Defense DV
- Speed DV
- Special DV

HP DV is derived and not counted as a fifth value. Gold's Sp. Atk and Sp. Def share `dvs.special` for this purpose.

Training score:

- HP Stat Exp
- Attack Stat Exp
- Defense Stat Exp
- Speed Stat Exp
- Special Stat Exp

`statExp.special` contributes once even though it feeds both Sp. Atk and Sp. Def. Held items, happiness, Pokérus, gender and shininess do not alter the appraisal score.

## Cross-mod expectations

The mod is read-only and is designed to coexist with Special Stat Split, Autofire, Tap to Move/dialog touch, Held Items and Gen2 gender-related systems. The broader cross-mod matrix remains recommended after major upstream or mod updates.
