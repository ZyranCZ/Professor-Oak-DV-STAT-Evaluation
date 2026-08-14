# Migration test report — v2.0.1

Target: Gen1Recomp **v0.1.86**, Mod API 2, Red / Blue / Yellow + Pokémon Gold.

## Source freeze

- Authoritative input: `oak_pokemon_appraisal_v2.0.0 (1).zip`
- Input SHA-256: `fc32df12dff09e5faa6924eb3c8829afa5e84842a5e49045cf46a34278acad08`
- Input runtime version: `2.0.0`
- Engine tag: `v0.1.86`
- Engine commit: `3de45b671cada26835639c9bb3623201fefedfc3`
- Output version: `2.0.1`

The input ZIP was unpacked directly and audited in full. No GitHub release or older repository copy was used as the mod source.

## Migration finding fixed

Gen1Recomp v0.1.86 freezes content registries before `game.ready`. v2.0.0 attempted to install the Gen I `dex_rating` override from `game.ready`; the real v0.1.86 event bus reported `commands: content is frozen after load`. That could leave Professor Oak's in-person laboratory appraisal inactive even though the loader had already marked the mod as loaded.

v2.0.1 performs a read-only `dex_rating` capability probe and commits the Gen I override during the entry chunk. Gold's command registry has no Gen I built-in verbs, so the probe returns `nil` and no Gen I command override or PC hook is installed on Gold. Gold's runtime-only events and hooks remain installed after its live Game2 owner arrives through `game.ready`.

## Manifest and sandbox audit

- `api`: 2
- `id`: `oak_pokemon_appraisal` (unchanged)
- `version`: `2.0.1`
- `entry`: `main.lua`
- `profile`: `content`
- `games`: `gen1`, `gold`
- `category`: `TOOL`
- `priority`: 100
- dependencies / optional dependencies / conflicts: none
- permissions: none
- `experimental`: false
- `game_version`: intentionally absent
- options schema / persistent storage / update checker: not used by this mod

The packaged runtime contains no `io`, `package`, `debug`, `ffi`, `dofile`, `loadfile`, `getfenv`, `setfenv`, forbidden `os.*`, forbidden `love.*`, direct filesystem access, absolute path, traversal, bytecode, shared `_G`, or engine-internal `require`.

## Exact v0.1.86 API verification

The following contracts were checked against the target source and their actual callsites:

- `game.ready`: `src/core/Game.lua` and `src/core/Game2.lua`;
- `screen.pushed`: `src/core/StateStack.lua`;
- `ui.pc.items`: Gen I `src/world/OverworldController.lua` and Gold storage PC callsites;
- `script.started`, `script.ended`, `script.command`: `src/script/gen2/Vm.lua`;
- Gen I `dex_rating`: the target command registry;
- `Gen2CenterPcMenu`: native Pokédex-gated `oaks` row, `choose`, and `oakClosed`;
- `Gen2PartyMenu`: direct `onChoose(index, mon)` and `onCancel` contract;
- `mod.ui.Menu`, `mod.ui.TextBox`, `mod.ui.Font`, `mod.ui.Theme`, and `mod.ui.push`: `src/ui/ModUI.lua`;
- Gen I and Gold Stat Experience arithmetic: `src/pokemon/Stats.lua` and `src/battle/gen2/Mon.lua`;
- Gold map object `scriptKey` shape and VM context fields.

## Automated results

### Official modkit

- `validate --base fixture`: **PASS**
- `lint`: **PASS** — no ROM-derived content
- `gen2check --notes`: **PASS WITH 2 REVIEWED WARNINGS**

The two `MK409` warnings identify the literal Gen I `PartyMenu` at the two Gen I-only callsites. They are retained rather than hidden. The whole `installGen1` backend is activated only when the entry-time `dex_rating` capability exists; the Gold loader test proves that Gold installs neither `ui.pc.items` nor the Gen I command override and uses `Gen2PartyMenu` in its separate backend. These are therefore scoped false positives, not a Gold degradation.

### Real v0.1.86 SDK loader

`tests/v0186_loader_test.lua`: **32 / 32 PASS**.

The official SDK loader and the real v0.1.86 hook/event buses prove:

- `run.mod.state == "loaded"` on generation 1;
- `run.mod.state == "loaded"` on generation 2 / Gold;
- zero loader errors in both runs;
- versioned exports are published in both runs;
- the Gen I `dex_rating` override is owned by this mod before content freeze;
- Gen I installs `ui.pc.items` and does not install Gold `script.command`;
- the native Oak PC row is decorated without changing unrelated rows;
- SHOW POKéDEX delegates exactly once;
- Gold installs `script.command` and does not install Gen I `ui.pc.items`;
- a real `Gen2CenterPcMenu` instance receives the Oak appraisal choice;
- Elm's `faceplayer` result delegates unchanged and opens no immediate UI;
- only the successful matching `script.ended` appends APPRAISE / CANCEL;
- a bare later `script.ended` cannot reuse stale Elm identity;
- Gold Happiness Rater provenance resolves from the v0.1.86 map-object shape.

### Functional / regression suites

- `tests/appraisal_test.lua`: **PASS**
- `tests/gold_appraisal_test.lua`: **PASS**

Coverage includes all DV/training boundaries; Gen I versus Gold Stat Experience arithmetic; locked copy/layout; fresh-press gating; Oak PC and Oak Lab delegation; Gold Center PC availability; Eggs; selected-Pokémon read-only invariants; Happiness Rater exact provenance, native delegation and all six tiers; Professor Elm same-run ordering, mismatched root script key, stale-context suppression, abort suppression, and post-dialogue-only UI; and repeated `game.ready` idempotence.

## Packaging audit

The v0.1.86 `.modkitignore` parser accepts exact file paths rather than directory patterns. v2.0.1 lists each test file explicitly, so the user-facing package excludes test-only `loadfile` / `io` helpers and contains only installable runtime and documentation. Historical ZIPs, patches, caches, backups, logs, and build artifacts are excluded.

## Unverified

- `validate --base imported`: **UNVERIFIED** — no user-imported ROM-derived cache is available in this environment; the mod contains no ROM-content patches, and the official fixture loader passes.
- Physical Red / Blue / Yellow / Gold presentation and controller pacing: **UNVERIFIED in this build pass** — the SDK proves loader and functional contracts, but it is not the rendered game executable.
- Broad simultaneous cross-mod matrix: **UNVERIFIED in this build pass**.

## Verdict

**READY FOR USER TEST**
