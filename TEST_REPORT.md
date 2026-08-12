# Test report — v2.0.0

Target: Gen1Recomp Mod API 2; stable Red / Blue / Yellow + Pokémon Gold support.

## Source freeze

Stable v2.0.0 is promoted directly from the previously delivered and live-tested `v1.1.0-rc.5` candidate. Runtime behavior is unchanged from RC.5; only release metadata/documentation and version assertions were changed.

`df745f0c01f9220230c474d994b7bd6c600a8228a40474cf01264aa065bdbe0e`

The RC.5 package above was unpacked directly and used as the sole source for v2.0.0. Its lineage remains the verified v1.0.2 migration baseline (`2a75be61fb18e0345a60960123985228bbf38f15cf67d14731d6f78d1e94b1e3`). Stable v2.0.0 changes release metadata/version assertions only; the RC.5 runtime is preserved byte-for-byte apart from the version constant/comment.

Current upstream audit snapshot used for the port:

`bryanthaboi/gen1recomp` `dev` @ `01aab1d763c2e2d6878a0a25d606c02b3f569818` (current `dev` HEAD used for the RC.5/v2.0.0 Elm contract verification).

## Gen I regression — PASS

Executed with `texlua tests/appraisal_test.lua`.

The existing assertions were retained and adapted only so generation-specific integration installs after `game.ready`. Covered behavior includes:

- exact PC menu ordering **SHOW POKéMON / SHOW POKéDEX / CANCEL**;
- Oak Lab interception only in `OAKS_LAB` at the vanilla `dex_rating` phase;
- native Pokédex delegation;
- party picker / cancellation flow;
- all DV boundaries;
- HP DV excluded from the score;
- v1.0.2 effective Stat Experience boundary behavior;
- all training tiers;
- locked appraisal strings and layout;
- `<PK><MN>'s` atomic handling;
- fresh A/B press gating;
- existing public export signatures.

Result: **PASS**.

## Gold headless suite — PASS

Executed with `texlua tests/gold_appraisal_test.lua`.

Covered:

- Gold boot never touches the Gen I `dex_rating` registry;
- no Gen I `ui.pc.items` hook is installed on Gold;
- four stored DVs only, maximum 60;
- derived HP DV ignored as a fifth score;
- five Stat Experience buckets only, maximum 315;
- shared Special Stat Experience counted once;
- current Gold `Mon.lua` effective Stat Exp arithmetic at `0, 1, 16, 4096, 16384, 40000, 63001, 63002, 65535`;
- explicit regression that raw `63002` remains `63` in Gen I v1.0.2 semantics but is `62` in current Gold arithmetic;
- Center PC before Pokédex: no Oak row manufactured;
- native Oak row decoration after Pokédex;
- idempotent per-instance Center PC wrapper;
- SHOW POKéDEX native delegation exactly once;
- Bill / Player / Hall of Fame / Turn Off rows delegate unchanged;
- SHOW POKéMON direct `Gen2PartyMenu` selection;
- selected Pokémon data remains unchanged, including moves, OT, held item, status, happiness, gender, shiny state, Pokérus and record metadata;
- the selected party object identity/order is retained;
- held item, happiness, gender, shiny/Pokérus/form/records and separate Sp. Atk / Sp. Def convenience fields are explicitly proven not to affect DV/training score;
- fainted, statused and level-100 Pokémon remain valid read-only appraisal targets;
- native `oakClosed()` after remote appraisal;
- Party B returns to Oak root choice;
- Egg refusal leaks no hidden species and reopens the picker;
- exact Happiness Rater provenance matching and negative-context chaining;
- CHECK HAPPINESS calls the native special exactly once;
- all six native happiness tier outcomes (`250+`, `200+`, `150+`, `100+`, `50+`, `<50`) are returned through the wrapper unchanged in the headless delegation model;
- native first-non-Egg happiness selection is returned through the wrapper unchanged;
- APPRAISE selects any non-Egg party member and returns `"end"` rather than falling into happiness text;
- Rater intro with normal and maximum legal nickname lengths;
- root B / CANCEL ends cleanly;
- repeated conversations do not retain stale choice state;
- coroutine callback resume counts;
- the asynchronous hook path is exercised across a protected `pcall` boundary, matching the engine hook-chain shape;
- intermittent held-A/autofire-style edges cannot bypass the three-neutral-frame fresh-press gate;
- a repeated `game.ready` emission does not stack this entry closure's Gold event/hook registrations;
- Professor Elm root `ProfElmScript` is still resolved from `ELMS_LAB` object 1 for diagnostics/fallback only;
- Elm appraisal activation no longer requires runtime `scriptKey` equality;
- `script.started` clears stale per-run Elm bookkeeping;
- Elm's native opening `faceplayer` is observed through `script.command`, but every Elm command is proven pass-through with unchanged return value and no UI before completion;
- a deliberately different runtime `scriptKey` still arms appraisal when map + Elm object + `faceplayer` match;
- both friendly `ELMS_LAB`-only and cartridge group 24 / map 5-only identities are accepted;
- successful `script.ended` for the same armed VM run appends APPRAISE / CANCEL;
- bare `script.ended` without an observed Elm `faceplayer` does not trigger, guarding stale `hLastTalked` sign/bookshelf contexts;
- different-VM completion cannot consume a marker from another run;
- pre-starter empty-party suppression and aborted-run suppression;
- the first manual Elm conversation after the starter is appraisal-capable in the modeled flow;
- later story/reward dialogue remains command-identical and appraisal exists only after completion;
- Elm appraisal uses the `ELM:` intro and the shared Gold scorer;
- party B returns to the supplemental Elm menu;
- Egg refusal stays opaque and reprompts;
- completed appraisal returns to overworld without Oak-PC close text.

Result: **PASS**.

## Upstream facts re-verified

- Gold top-level PC is `Gen2CenterPcMenu` and Oak's row is native / Pokédex-gated.
- `ui.pc.items` is not the correct top-level Oak seam in Gold.
- `Screens` stamps `state.screenId` and `StateStack` emits `screen.pushed` after enter.
- Gold `Gen2PartyMenu` supports direct `onChoose(index, mon)` selection and exposes Eggs without requiring a field submenu.
- Gold generated map definitions store object `scriptKey` values in `def.objects`.
- Goldenrod Happiness Rater is map group 11 / map 5 and the teacher is the first object.
- Gold `Mon.lua` stores one Special DV / one Special Stat Experience contribution for both special stats.
- Elm is `ELMS_LAB`, map group 24 / map 5, object 1 (`ProfElmScript`), and the vanilla starter flow sets `EVENT_GOT_A_POKEMON_FROM_ELM` before the first repeat Elm conversation.
- Gold `Vm:scriptCtx()` exposes generation, root script key, map id/group/number, object and VM, and `Vm:emitScriptEnded(completed)` emits that context before clearing it.
- Gold documents `ctx.object` as `hLastTalked` and notes that it can be stale for signs/callbacks; v2.0.0 therefore requires an observed Elm `faceplayer` command before completion can open supplemental UI.

## Static MK400–MK410 review

Stable manifest declares only `gen1` and `gold`, has no dependencies, no `game_version`, no private engine `require`, no debug/upvalue surgery and no entry-time live game reads. Gen I-only `PartyMenu` / `dex_rating` access is isolated behind the Gen I backend; Gold uses `Gen2CenterPcMenu`, `Gen2PartyMenu`, `screen.pushed`, `script.started`, `script.ended`, `script.command` (Happiness Rater behavior + observation-only Elm arming) and public `mod.ui`.

The current upstream compatibility documentation independently identifies `script.started`, `script.ended`, and `script.command` as the supported scripting seams on Gold, matching the RC.4/RC.5 Elm and Happiness Rater design.

Static result: **PASS WITH OFFICIAL TOOL PENDING**.

The required command `python3 tools/modkit.py gen2check <mod> --strict --notes` could not be executed in this sandbox because the upstream `tools/modkit.py` checkout is not locally available and direct repository download is unavailable here. This item is therefore **BLOCKED**, not reported as PASS.

## Packaging checks

Before delivery the stable ZIP is unpacked to a fresh directory and both Lua suites are rerun from the packaged copy. JSON parsing, version synchronization, forbidden `game_version`, `experimental: false`, release-tree hygiene and SHA-256 hashes are checked after packaging.

## Stable release status

The following broader live matrix was not exhaustively re-run as part of this packaging pass and remains recommended for future compatibility sweeps:

- Gold boot with v2.0.0 enabled;
- Center PC before Pokédex;
- Center PC after Pokédex;
- postgame Center PC with Hall of Fame;
- SHOW POKéDEX presentation / sound / link close;
- SHOW POKéMON presentation / fresh-press pacing;
- Professor Elm immediately after receiving the starter;
- Professor Elm after ordinary and later story/reward conversations, verifying vanilla always completes before supplemental appraisal;
- Professor Elm aborted/wrong-provenance negative controls;
- Goldenrod Happiness Rater all six vanilla happiness tiers in a physical runtime (headless delegation PASS);
- happiness Egg-skip behavior in a physical runtime (headless delegation PASS);
- APPRAISE Egg refusal and reprompt;
- repeated Rater conversations / map exit;
- Autofire A;
- Tap to Move / touch dialogue A;
- Special Stat Split;
- Held Items;
- Gen2 gender-related mods;
- final Red / Blue / Yellow live regression.

RC.5 was reported to behave correctly in live Gold and is therefore promoted unchanged to stable **v2.0.0**. The full scripted cross-mod matrix remains recommended for future compatibility sweeps rather than a release blocker.
