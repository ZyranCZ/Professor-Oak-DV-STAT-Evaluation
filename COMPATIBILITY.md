# Compatibility notes — v1.0.1

## Integration seam

The mod wraps `ui.pc.items`, calls `next()` first, copies the returned Oak descriptor, and changes only its `onSelect` callback. Every unrelated PC row and every descriptor field on Oak's row is preserved.

The UI uses only the public `mod.ui` facade:

- `mod.ui.Menu`
- `mod.ui.TextBox`
- `mod.ui.push(..., "PartyMenu", ...)`

No private engine module is required by the mod.

The short-dialogue sequence first pushes one fixed two-line Oak/name intro TextBox, then lays out deterministic appraisal sentences, groups at most two rows per message, and pushes separate public TextBox instances. Width measurement uses the public `mod.ui.Font`/`mod.ui.Theme` surface. The fresh-press gate wraps only those instances and does not alter global input handling.

## Special Stat Split

Compatible by design with the existing Special Stat Split approach: the appraisal reads the canonical Gen I `dvs.special` and `statExp.special` buckets. A later Sp. Atk / Sp. Def presentation split does not create separate Gen I DV or Stat Experience buckets, so no double-counting occurs.

## Other PC-menu mods

Because the wrapper calls `next()` before decorating the returned list, lower-priority PC menu edits survive. The mod only decorates the first row whose label is exactly `PROF.OAK's PC` and whose `onSelect` is callable.

If another mod renames or removes Oak's PC row, this release intentionally does not guess which replacement row should receive appraisal behavior.
