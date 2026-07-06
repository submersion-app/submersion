# Unified "Cylinders" Card — Design

**Date:** 2026-07-05
**Status:** Approved

## Problem

The Dive Details page shows two cards describing the same physical cylinders:

- **Tanks** (`_buildTanksSection`, `dive_detail_page.dart:3825`) — a plain
  always-expanded `Card` rendered for every dive with tanks. Per tank: icon,
  `Tank N (EAN32)` title, `207 bar -> 55 bar (152 bar used)` pressure line,
  MOD/MND line, trailing volume/preset label and source-attribution badge.
- **SAC by Cylinder** (`_buildCylinderSacSection`, `dive_detail_page.dart:2044`)
  — a `CollapsibleCardSection` rendered only on multi-tank dives, as a
  sub-block of the SAC Rate by Segment area (and as a standalone fallback when
  no time segments exist). Per cylinder: icon, display label, gas + role line,
  SAC value, gas-used line.

Both are keyed by the same tank IDs (`CylinderSac.tankId` == `DiveTank.id`),
and `CylinderSac` even duplicates start/end pressure. The section metadata in
`dive_detail_sections.dart` already describes the `tanks` section as "Tank
list, gas mixes, pressures, per-tank SAC" — the implementation never caught up.

## Decision

Replace both with one new always-expanded **Cylinders** card that occupies the
existing `tanks` section slot.

### Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Merge model | New unified card built from scratch (not enriching either existing card) |
| Section placement | Reuse `DiveDetailSectionId.tanks` — zero saved-config migration |
| Card style | Always-expanded plain `Card` (like today's Tanks) |
| Single-tank dives | Show per-tank SAC whenever computable, regardless of tank count |
| Title | Rename to "Cylinders" (new l10n key, all locales) |

## New widget

`lib/features/dive_log/presentation/widgets/cylinders_card.dart` — a
`ConsumerWidget` extracted out of `dive_detail_page.dart` (which is 4,932
lines; project rule is many small files). The existing, entirely unused
`lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart`
(`CylinderSacCard`/`CylinderSacList`) is deleted.

### Row layout (per tank, "enriched list row")

- **Leading:** `MdiIcons.divingScubaTank` icon.
- **Title:** tank name (or localized `Tank N`) + `(gas mix name)`, with the
  volume/preset label (e.g. `AL80`, `11.1 L`) as a small outlined chip after
  the title. Chip omitted when no volume/preset.
- **Subtitle line 1:** `207 bar -> 55 bar (152 bar used)` — pressures resolved
  by the existing `_resolveTankPressures` priority (stored tank metadata
  first, per-tank time-series fallback). That helper moves into the new
  widget file.
- **Subtitle line 2:** `MOD 33 m . MND 30 m` in tertiary color, using
  `GasMix.mod()` / `GasMix.mnd()` with the diver's `endLimit`/`o2Narcotic`
  settings (unchanged from today).
- **Trailing:** SAC value, bold, primary color — formatted per
  `sacUnitProvider` (L/min when tank volume is known, otherwise the diver's
  pressure unit per minute), with gas-used-in-liters beneath when volume is
  known. When SAC is not computable for a tank, the trailing SAC block is
  omitted entirely (no `--` placeholder). The `FieldAttributionBadge` is kept
  for computer-attributed tanks on multi-source dives (>= 2 sources), same
  rule as today.
- All displayed values go through `UnitFormatter` and respect active unit
  settings.

### Data flow

- Tank list: `dive.tanks` (already available on the page's `Dive`).
- Per-tank SAC: `cylinderSacProvider(dive.id)` joined onto rows by `tankId`.
  The provider already computes for any tank count; the UI-side
  `isMultiTankDiveProvider` gate is dropped.
- Pressure time-series: `tankPressuresProvider(dive.id)` (unchanged).
- Attribution: `diveDataSourcesProvider(dive.id)` + computer display names
  (unchanged).

## Removals

In `dive_detail_page.dart`:

- `_buildTanksSection`, `_buildCylinderSacSection`, `_formatCylinderSac`,
  `_resolveTankPressures` (moves to the new widget).
- The cylinder-SAC sub-block at the end of `_buildSacSegmentsSection` and the
  standalone cylinder-SAC fallback in its no-segments path. The SAC Rate by
  Segment section becomes purely segment analysis; when no segments exist it
  simply renders nothing (the Cylinders card now always carries the per-tank
  SAC).
- The `tanks` section builder swaps to the new `CylindersCard`.

Elsewhere:

- `cylinderSacExpandedProvider` in `gas_analysis_providers.dart` (only
  consumer is the removed block).
- `lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart` (dead).
- l10n key `diveLog_detail_section_sacByCylinder` from all 11 locales.

## Naming and l10n

- New key `diveLog_detail_section_cylinders` = "Cylinders";
  `diveLog_detail_section_tanks` removed.
- Settings UI: `diveDetailSection_tanks_name` value becomes "Cylinders";
  `diveDetailSection_tanks_description` and
  `diveDetailSection_sacSegments_description` updated to reflect the move of
  the cylinder breakdown (English fallbacks in `dive_detail_sections.dart`
  `displayName`/`description` switches too).
- All 10 non-English locales get translations; `flutter gen-l10n` regenerated.
- `DiveDetailSectionId.tanks` enum value is NOT renamed — persisted section
  order/visibility JSON round-trips through `id.name`, so keeping `tanks`
  means zero migration.

## Testing

- New widget tests for `CylindersCard`:
  - single-tank dive with computable SAC (SAC trailing block shown),
  - single-tank dive without pressures (no SAC block, row still renders),
  - multi-tank dive (per-tank SAC values differ),
  - imperial units (psi, cuft) formatting,
  - source badges appear only with >= 2 data sources,
  - MOD/MND line rendering.
- Update existing dive-detail tests that reference the Tanks section or "SAC
  by Cylinder".
- `flutter analyze` and `dart format .` clean; run targeted test files rather
  than broad directories.

## Out of scope

- Any change to how SAC or cylinder SAC is calculated
  (`GasAnalysisService.calculateCylinderSac` untouched).
- The SAC Rate by Segment section's segment analysis UI.
- The dive edit form's tank editor.
