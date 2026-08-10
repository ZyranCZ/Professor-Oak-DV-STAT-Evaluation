# Test report — v1.0.1

Target: Gen1Recomp v0.1.75 / `60cf07fb0a1ffce0ec6d5d0d2f78a921a6d0b7da`.

## Integration audit

The in-person Oak path is implemented at the narrowest story-safe seam found in the frozen upstream source:

- Oak's Lab keeps its original `TEXT_OAKSLAB_OAK1` talk script.
- That vanilla script reaches the `dex_rating` command only on its existing Pokédex-rating branch.
- The mod captures the vanilla `dex_rating` command through the public `commands` registry and overrides that command.
- The replacement shows custom UI only when `ctx.overworld.map.id == "OAKS_LAB"`.
- Outside Oak's Lab, the captured vanilla command is called unchanged.
- Choosing **SHOW POKéDEX** in Oak's Lab also calls the captured vanilla command.
- Choosing **SHOW POKéMON** blocks the script coroutine while PartyMenu/appraisal UI runs, then resumes it when the final appraisal box closes.
- The in-person path deliberately omits the PC-only `Closed link to PROF.OAK's PC.` message.

This avoids copying or replacing Oak's starter/parcel/Pokédex/rival/Poké Ball story script.

## Automated Lua checks

Executed with the available Lua-compatible `texlua` runtime.

Covered:

- `main.lua` parses and loads;
- internal/exported version is `1.0.0`;
- `ui.pc.items` hook is registered;
- the existing `dex_rating` command is captured and an override is registered;
- a `dex_rating` invocation outside `OAKS_LAB` delegates to the captured vanilla handler;
- the in-person Oak command opens **SHOW POKéMON / SHOW POKéDEX / CANCEL**, in that order;
- both Oak choice menus use an explicit 15-tile width for the longer `SHOW ...` labels;
- direct **SHOW POKéDEX** delegates to the captured vanilla handler;
- direct **SHOW POKéMON** opens the native PartyMenu with `forceSwitch = true`;
- direct PartyMenu cancellation returns to Oak's three-way choice;
- direct **CANCEL** lets the blocked Oak script finish;
- direct appraisal uses the same `OAK: Let's see... / <name>!` intro and the same locked appraisal boxes as the PC path;
- direct appraisal does **not** append the PC-only close-link TextBox;
- every DV tier boundary: 50, 49, 40, 39, 31, 30;
- HP DV is not part of the summed score;
- effective Stat Experience conversion at 0, 1, 16, 4096, 16384, 40000, 63001, 63002 and 65535;
- all five training tiers and exact 315/315 effective maximum;
- PC **SHOW POKéDEX** still invokes the captured vanilla Oak PC callback;
- PC **SHOW POKéMON** still goes directly to PartyMenu with no terminology tutorial;
- PC and in-person menus both keep **SHOW POKéMON** at index 1 and **SHOW POKéDEX** at index 2;
- every DV verdict begins `Your <PK><MN>'s DVs are ...`;
- `<PK><MN>'s` remains atomic and is never newline-split or hyphenated;
- all locked appraisal strings are present in source;
- outstanding-DV follow-up is locked to `Its potential is remarkable!` and fits one two-line box as `Its potential is` / `remarkable!`;
- developing-tier follow-up is locked to `It still needs lots of training.` and fits the two-line 18-cell layout without a continuation box;
- every semantic appraisal sentence now fits in exactly one physical TextBox;
- all appraisal text respects the 18-cell headless layout budget and two-line physical TextBox limit;
- fresh-press protection still prevents a held A/B from spilling into the next appraisal box.

Result: **PASS**.

## JSON / packaging checks

- `manifest.json` parses successfully.
- The mod uses no private `require("src...")` calls.
- Version strings in the runtime and manifest are `1.0.0`.
- Final ZIP is unpacked to a fresh directory and the Lua test is rerun from the packaged copy before delivery.

## Remaining live smoke test

A real Gen1Recomp v0.1.75 session is still required to visually confirm the in-person sequence in Oak's Lab with the active renderer/input stack. The specific live checks are:

1. Before Oak reaches his normal Pokédex-rating phase, starter/parcel/Pokédex/Poké Ball dialogue remains vanilla.
2. Once Oak would normally rate the Pokédex, talking to him shows the three-way choice after his existing lead-in line.
3. **SHOW POKéDEX** still displays the normal in-person rating.
4. **SHOW POKéMON** opens the party picker and appraisal with the same pacing/layout as the PC path.
5. The final in-person appraisal box returns directly to the lab without `Closed link to PROF.OAK's PC.`.
