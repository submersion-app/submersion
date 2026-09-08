# Trimix Calculator: Settings Persistence Analysis (Teil 1)

Date: 2026-08-27
Original issue: [submersion-app/submersion#1335](https://github.com/submersion-app/submersion/issues/1335)
Fork issue: alpheios-one/submersion#18
Branch: `claude/issue-18-20260827-2101`

## Scope

This document was originally written as analysis only, for "Teil 1" of issue
#18, before any implementation existed. It documents the current architecture
the blender calculator sits on, so that "Teil 2" could build on accurate
ground rather than assumptions. The "Teil 2" implementation (persistence,
settings gear, cylinder-size templates) has since been added on top of this
same branch/PR; this document reflects the state of the codebase as it was
at the start of that work, not the final state.

## Summary of the request (issue #1335)

1. The blender should remember the last entered cylinder, target fill, fill
   gases and mixing conditions across app restarts.
2. The "Fill gases" and "Mixing conditions" views, plus the billing fields
   (currency, O2/He/air price, cylinder size), should move behind a settings
   gear icon, keeping today's grouping.
3. A manageable cylinder-size template (name, liters) should live under a
   "Default settings and billing" area and feed the cylinder dropdown.

## Current state

### The blender is a composed shell over six cards

`lib/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart`
assembles, in order: `BlenderCylinderCard`, `BlenderFillGasesCard`,
`BlenderConditionsCard`, `BlenderProcedureCard`, `BlenderAboutCard`,
`BlenderBillingCard`, `BlenderInvoiceCard`. Each card is its own file under
`presentation/widgets/blender/`. This maps directly onto the issue's request:

| Issue term | Existing widget |
| --- | --- |
| "Füllgase" | `blender_fill_gases_card.dart` (3 O2/He rows) |
| "Mischbedingungen" | `blender_conditions_card.dart` (fill temp, settled temp, gas model) |
| Cost fields currency/O2/He/air | `blender_billing_card.dart` (`_currencyField`, three `_priceField`s) |
| Flaschengrössen-Vorlage | `blender_billing_card.dart::_cylinderRow`, backed by `blenderTankChoices()` in `tank_spec.dart` |

There is no settings-gear affordance anywhere in the gas calculators today
(`Icons.settings` does not appear under `lib/features/gas_calculators/`). The
only existing AppBar action on the calculators page is a reset button
(`gas_calculators_page.dart:54-59`).

### What is already persisted, and what is not

A prior feature (issue #1100, see
`docs/superpowers/specs/2026-08-20-trimix-blender-optimisation-design.md`)
already built a persistence layer for *part* of the blender's state:

- `BlenderPreferences` (`domain/blending/blender_preferences.dart`) is a plain
  JSON-serializable class: mix templates, the three fill-gas prices, currency,
  fill/settled temperature, cylinder water liters (billing cylinder), the gas
  model, and billed fills/billed-to.
- It is stored as **one JSON blob** under the key-value `settings` table, key
  `gas_blender_prefs`, via `AppSettingsRepository.getBlenderPreferences()` /
  `.setBlenderPreferences()` (`app_settings_repository.dart:92-143`). This
  costs **no schema version bump** — it reuses the generic `settings(key,
  value, updatedAt)` KV table that already exists, the same pattern
  `getNavPrimaryIdsRaw`/`setNavPrimaryIds` use for nav config.
  Writes call `SyncRepository.markRecordPending(entityType: 'settings', ...)`
  and `SyncEventBus.notifyLocalChange()`, so the blob syncs across devices
  with no sync-serializer change.
- Loading happens once per calculator mount via
  `blenderPreferencesLoaderProvider` (a `FutureProvider` in
  `gas_blender_providers.dart:148-170`), which pushes the stored values into
  plain `StateProvider`s and bumps `blenderResetEpochProvider` so the
  `TextEditingController`s in `gas_blender_calculator.dart` re-seed from the
  loaded values (they only seed once, in `initState`).
- Saves are explicit and debounced to "on blur / on submit", not per
  keystroke: every field that persists calls `saveBlenderPreferences(ref)`
  from `onEditingComplete`/`onSubmitted`/`onChanged` (dropdowns), never from
  every `onChanged` on a text field.

**What is *not* persisted today**, confirmed by reading
`gas_blender_providers.dart:11-83`: `blenderStartPressureProvider`,
`blenderStartMixProvider`, `blenderTargetPressureProvider`,
`blenderTargetMixProvider`, `blenderFillGas1/2/3Provider` are plain
`StateProvider`s with hard-coded defaults (0 bar / air; 200 bar / EAN32; O2
100%, He 100%/O2 0%, air) and are never read by
`blenderPreferencesLoaderProvider` or written by `saveBlenderPreferences`.
This is exactly the gap issue #1335 point 1 is asking to close: the cylinder,
the target fill, and the three fill gases reset every time the calculator is
reopened, while the mixing *conditions* (temperatures, gas model) already
survive a restart.

### The cylinder-size dropdown

Two unrelated preset lists exist in `tank_spec.dart`:

- `metricTankChoices()` / `imperialTankChoices()` — the diver's own cylinders,
  used by dive planning/logging.
- `blenderTankChoices()` — a **separate, hard-coded** list of 4 entries (2 L,
  3 L, AL80, "Steel 12 L twinset") used only by
  `BlenderBillingCard._cylinderRow`'s preset menu. A code comment there notes
  this was a deliberate split during #1100's review: a blending bench sees
  small decant bottles and twinsets-as-one-vessel, which a diver's own
  cylinder list does not represent, and unifying them was rejected.

Separately, the app already has a full, user-manageable tank preset system —
`lib/features/tank_presets/` (`TankPresetEntity`, `TankPresetRepository`,
`tank_presets_page.dart`, reachable from Settings → Manage → Tank Presets).
That system is **not** what feeds the blender's cylinder dropdown, and it
carries more fields than the issue asks for (`workingPressureBar`,
`TankMaterial`, `sortOrder`, `ratedCapacityCuft`, per-diver ownership) plus a
real Drift table with its own schema-version history
(`docs/superpowers/specs/2026-03-18-default-tank-preset-design.md`). Issue
#1335 only asks for name + liters, scoped to the blender.

### Settings/DB modeling in general

- `currentSchemaVersion` is `170` today (`lib/core/database/database.dart:3196`).
  A migration is a numbered `ALTER TABLE`/new-table block plus a version bump,
  following the pattern already used for the tank-preset table and dozens of
  other features.
- Two persistence shapes coexist in the codebase for "user-managed lists of
  small records": (a) a dedicated Drift table with a repository and its own
  migration (tank presets, dive types, dive roles, service types), used when
  the data is referenced elsewhere or independently synced/queried; (b) a JSON
  blob under the generic `settings` KV table, used when the data is small,
  private to one feature, and does not need to be queried relationally
  (blender preferences, nav primary ids). `MixTemplate` inside
  `BlenderPreferences` is the closest existing precedent for "a small
  user-managed list of `{label fields, numbers}` records" and required zero
  schema changes.

## Gaps against the three asks

1. **Persist last-entered values.** `blenderStartPressureProvider`,
   `blenderStartMixProvider`, `blenderTargetPressureProvider`,
   `blenderTargetMixProvider`, `blenderFillGas1/2/3Provider` need to join
   `BlenderPreferences` (new fields), `blenderPreferencesLoaderProvider`, and
   `saveBlenderPreferences`. No migration needed, since this is the same JSON
   blob used for the conditions that already persist.
2. **Settings gear.** No such affordance exists on any gas calculator today.
   `BlenderFillGasesCard`, `BlenderConditionsCard`, and the currency/price
   portion of `BlenderBillingCard` would need to move out of the always-visible
   column in `gas_blender_calculator.dart` into a gear-triggered surface
   (dialog, bottom sheet, or a settings sub-page), while keeping their internal
   layout ("bestehende Gliederung erhalten"). `BlenderProcedureCard`,
   `BlenderAboutCard`, the cylinder/cost-lines/total part of
   `BlenderBillingCard`, and `BlenderInvoiceCard` are the calculator's actual
   output and would stay on the main screen.
3. **Manageable cylinder-size template.** Nothing today lets a user add,
   rename, or delete an entry in `blenderTankChoices()` — it is a static Dart
   list. The lightweight option (matching `MixTemplate`'s pattern: a `{name,
   liters}` record living inside `BlenderPreferences`, no migration) is a
   closer fit to the issue's ask than reusing/extending the heavier
   `TankPresetEntity` table, which was deliberately kept separate from the
   blender's bench-bottle list during #1100.

## Recommendation for Teil 2

- Extend `BlenderPreferences` with the six currently-ephemeral fields and a
  `List<CylinderTemplate>` (name + liters, capped like `maxTemplates`),
  following the exact shape `MixTemplate` already established — this avoids a
  database migration entirely, reusing the existing KV blob, sync path, and
  malformed-input-falls-back-per-field contract.
- Introduce a settings-gear entry point on the blender (mirroring where a gear
  icon would sit next to the reset action in `gas_calculators_page.dart`, or
  as a per-card action), opening a view that keeps the existing
  `BlenderFillGasesCard` / `BlenderConditionsCard` internals unchanged, plus a
  new billing-defaults section (currency, three gas prices, and the new
  cylinder-template manager) — this is the "Standardeinstellungen und
  Abrechnung" area the issue names.
- Keep `blenderTankChoices()` as the zero-config fallback/seed for first run,
  the same way `BlenderPreferences.seedTemplates` seeds mix templates only
  when the stored blob is entirely absent.
