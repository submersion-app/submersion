# Show service status wherever a piece of equipment is shown

Issue: #2260

## Problem

The service-overdue signal lives only inside the equipment feature. The
equipment list card tints its avatar with `StatusColors.alert` and renders
`{kind} overdue` in the trailing slot; the detail header, the trip alert
banner, the pre-dive checklist row and the dashboard gear chips carry
comparable signals.

Every other surface that names a gear item is silent. The sharpest gap is the
dive surfaces: the gear tree on a dive, the equipment picker sheet, the
equipment set picker and the tank regulator dropdown all hold a full
`EquipmentItem` and show no service state, so a diver choosing gear gets no
warning at the moment it is most actionable.

Two secondary problems follow from the same cause, which is that each surface
re-implements the lookup:

- `equipment_list_worstClock` and `trips_serviceAlert_overdue` are the same
  English string under two keys, in two features, duplicated across 11 locale
  files.
- `ComponentsCard` and `ChildrenCard` read `equipmentWorstClockProvider` while
  the list tiles read `equipmentRollupClockProvider`, so a part whose own
  sub-part is overdue gets a dot in the list but not in the Components card.

## Decisions

| Question | Decision |
| --- | --- |
| Which severities travel | Both `overdue` and `dueSoon` |
| Rollup or own clocks | Inherit the rollup; the label names the owning part |
| Form factor | One widget, three densities (full, compact, dot) |
| Historical surfaces | Live state only on current-facing surfaces |
| Dive cutoff | Dive edit always; dive detail only when the dive is in the future |
| Due-soon wording | `{kind} due {relative}` |
| Delivery | A single PR |

## Architecture

### The shared widget

`lib/features/equipment/presentation/widgets/service_status_indicator.dart`

```dart
enum ServiceIndicatorDensity { full, compact, dot }

class ServiceStatusIndicator extends StatelessWidget {
  final RollupClock? clock;
  final String subjectId;
  final ServiceIndicatorDensity density;
}
```

It owns four decisions that are currently re-made at every call site:

1. **Nothing to say.** `clock == null` or `severity == ServiceClockSeverity.ok`
   renders `SizedBox.shrink()`.
2. **Rollup naming.** `clock.ownerId == subjectId` yields the bare
   `kind.name`; otherwise `equipment_components_rollupClock(ownerName,
   kind.name)`. This ternary appears in three files today.
3. **Colour.** `serviceSeveritySwatch` only, never a hardcoded red, so the
   theme's light and dark status work keeps applying.
4. **Accessibility.** Every density wraps in `Semantics`; the `compact` and
   `dot` densities also carry a `Tooltip`. The signal never rests on colour
   alone.

Densities:

| Density | Renders | Callers |
| --- | --- | --- |
| `full` | Kind label plus the long trigger line, matching `ServiceClocksCard` | Detail headers, roomy cards |
| `compact` | One line: `{kind} overdue` or `{kind} due {relative}` | List tiles, picker rows, dropdowns |
| `dot` | Coloured dot; the compact string in tooltip and semantics | Chips, dense rows, tree rows |

The widget renders service state only. Arbitration against condition findings
stays where it is today, in `pickBadgeSource`, and callers that have a badge
slot contested by both keep deciding which to pass.

### The short trigger formatter

`formatServiceTriggerText` returns a joined line covering every configured
trigger (`Due 12 Jan 2026 - 3 of 50 dives left`). That is correct for `full`
and far too long for `compact` or a tooltip.

A new sibling in `service_trigger_text.dart`:

```dart
String formatServiceTriggerShort(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  required ServiceClockStatus status,
});
```

It returns the single most urgent trigger in short form: `in 12d` for a date
clock, reusing `common_relativeTime_inDays`; `3 dives left` or `4h left` for
usage clocks. `full` keeps calling the existing long formatter unchanged.

Both take the active `UnitFormatter`, per the project rule that anything
displaying units respects the diver's unit settings.

### The current-facing rule

An explicit flag at the call sites rather than a provider, so the rule is
readable where it applies:

- `DiveGearTreeView` gains `showServiceStatus`, defaulting to `false`.
- Dive edit passes `true`.
- Dive detail passes `dive.diveDateTime.isAfter(now)`, so planned and future
  dives signal and logged past dives stay clean.
- Pickers, dropdowns and equipment screens pass `true` unconditionally:
  choosing gear is always a present-tense act.

## Surfaces

### Adopt (silent today)

Dive log: `DiveGearTreeView` (per the rule above), `EquipmentPickerSheet`,
`EquipmentSetPickerSheet`, the tank regulator dropdown in `tank_editor.dart`,
`cylinders_card.dart`.

Equipment: `ComponentPickerSheet`, `PartOfSection`, `InstalledInRow`,
`equipment_set_detail_page.dart`, `equipment_set_edit_page.dart`, the
parent-item dropdown in `equipment_edit_page.dart`, `EquipmentSummaryWidget`
rows.

Elsewhere: the pre-dive `start_session_sheet.dart` dropdown,
`trip_scrubber_margin_card.dart`, the `incident_edit_page.dart` gear picker
and `_EquipmentName`, `device_detail_page.dart`'s `_LinkedGearRow`, the
weight planner `rig_composer.dart` chips, the dive planner
`plan_gear_weights_section.dart` chips, `retype_other_gear_page.dart`.

### Migrate onto the widget (working today)

Planned: `EquipmentListTile`, `DenseEquipmentListTile`, the equipment detail
header, `ComponentsCard`, `ChildrenCard`, `TripServiceAlertBanner`,
`SessionItemTile`, `GaugeStrip`.

These go last, behind their existing tests, so a regression in a working
surface is caught rather than shipped.

**As shipped**, three of those were deliberately left alone, because reading
the code showed migrating them would lose meaning rather than add
consistency:

- `SessionItemTile` keeps its own provider. The rollup carries only the
  worst clock, while the tile deliberately shows every configured clock, and
  `activeEquipmentClocksProvider` covers active gear only, while the pre-dive
  start sheet offers gear from `allEquipmentProvider`. Migrating would have
  hidden clocks in a safety checklist. The N+1 is filed separately.
- `TripServiceAlertBanner` keeps its own rendering. Its due-soon line is
  trip-relative ("due before {trip date}"), which is more useful there than a
  relative day count. It does adopt the shared overdue key, and is
  allowlisted in the wording guard with that reason.
- `GaugeStrip` keeps its own wording: its chips name the gear item, not the
  service kind, and it holds a `GearGauge` projection rather than a clock.

`ComponentsCard` and `ChildrenCard` were fixed to read the rollup rather than
migrated to the widget: they draw a dot for every part including healthy ones,
which the indicator renders as nothing.

The equipment detail header keeps its page-level banner, which is a different
thing from a per-item badge.

### Excluded

Past-dive gear trees, every export path (CSV, Excel, UDDF, PDF), the dive,
trip and list filter chips, and `ServiceClocksCard`, whose rows are service
kinds rather than gear items.

## Fixes folded in

1. `ComponentsCard` and `ChildrenCard` switch to `equipmentRollupClockProvider`,
   ending the drift described above.
2. `EquipmentSummaryWidget`'s Service Due list switches to `dueClocksProvider`
   so each row carries its own severity.
3. `SessionItemTile` drops its per-row `serviceClockStatusesProvider` family
   for the batch rollup map, removing an N+1 inside a list builder.

## Deliberately out of scope

Filed separately rather than widened into this change:

- The equipment CSV export's `Next Service Due` column reads the legacy
  `item.nextServiceDue` getter, which derives from a dead column rather than
  the service ledger.
- `tripServiceAlertsProvider` re-evaluates every active item instead of
  deriving from `activeEquipmentClocksProvider`.

## Localisation

Nine new keys across all 11 locale files.

The two status sentences:

- `equipment_service_overdue`: `{kind} overdue`, retiring
  `equipment_list_worstClock` and `trips_serviceAlert_overdue`.
- `equipment_service_dueRelative`: `{kind} due {relative}`.

Plus seven per-unit short forms feeding `{relative}`:
`equipment_service_shortDives`, `..._shortHours`, `..._shortSaltHours`,
`..._shortColdDives`, `..._shortO2Hours`, `..._shortDeepCycles` and
`..._shortCycles`, each of the form "in {count} {unit noun}".

These are per-unit rather than one generic "in {count} {unit}" because a unit
noun cannot be composed into a sentence generically: the preposition, article
and case all vary by language. `ExposureUnitDisplay.usedAndLeftText` already
works this way for the same reason, and the generic form was tried first and
produced "in 3 Interval (dives)", since the only existing per-unit string is a
form-field label rather than a bare noun.

Only `app_en.arb` is alphabetical; inserts in the other ten anchor on a
neighbouring key.

## Testing

Tests are written before the code they cover.

**Unit.** `formatServiceTriggerShort` across date, dives, hours and
multi-trigger clocks. The strict `now == dueDate` boundary, which the engine
treats as due-soon rather than overdue. A plural check in `fr` and `pt`, where
the CLDR `one` category also covers zero, so a count of zero can wrongly
render the singular branch.

**Widget.** One test per density. Per-surface present and absent tests. Three
for the current-facing rule: a logged past dive stays silent, dive edit shows
the indicator, a future dive shows it.

**Architecture.** A guard asserting that no file outside
`service_status_indicator.dart` reads `equipmentRollupClockProvider` for
rendering. It lands in the same change as the last migration, so no window
exists in which the guard and a violating surface coexist.

## Risks

**Existing-test fallout is the dominant cost.** Adding a provider dependency
to a widget breaks every existing test that pumps that widget without an
override. Wiring the rollup into dive, trip, safety, planner and dive-computer
widgets reddens those features' test files until each is given
`equipmentRollupClockProvider.overrideWith(...)`. Mechanical, but it is what
makes a single PR wide: the diff touches test files in features unrelated to
equipment.

**Architecture tests are not run by affected-directory runs.** The suite in
`test/architecture/` scans all of `lib/`, so the new file means running it
explicitly.

**Screen budget.** Issue #2221 reports service warnings filling a mobile
screen. Dense surfaces take the `dot` density deliberately; no surface gains a
banner.
