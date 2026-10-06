# Equipment Condition Intelligence, Phase 4b: Badges, Trip Margin, Pre-Dive, Statistics

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the condition findings and exposure totals to the rest of the app: the equipment list badges, a scrubber margin card and banner line on trips (with the two trip edit override fields), the pre-dive runner's gear warning, and three ranking cards on the equipment statistics page. This closes the program.

**Architecture:** Every surface reads what earlier phases store or derive; nothing new is persisted except the two trip override columns that v202 already created. Badges come from one `getAllUndismissed` read filtered at display time by the master toggle and the disabled rules. The trip scrubber margin is a pure service over four inputs (rated minutes, consumed since the newest repack, expected dives, minutes per dive) fed by two small repository reads for the history medians; "as of the trip start" is one `before` parameter threaded through every read, so a past trip shows the estimate the diver had when they left. The pre-dive tile appends significant findings to the warning block it already draws for overdue clocks. The statistics page reuses `StatSectionCard` and `RankingList`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (Surfaces: Elsewhere, Trip scrubber margin; Testing). Stacked on phase 4a (#1724).

**Decisions (asked and answered 2026-09-10):** one PR for all of 4b; pre-dive shows significant findings in the same warning block as the overdue clocks, after them, as short rule labels; statistics uses ranking cards reusing the existing ranking widget; the scrubber margin card appears on every trip including past ones, computed as of the trip start; badges raise on caution and significant only (caution shares the due-soon colour, significant the overdue colour), read in one query.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings, this plan).
- No tool or vendor attribution in any commit, comment, file or PR body.
- `dart format .` before every commit; push with `SKIP_TESTS=1` after a local full run.
- TDD: failing test first, watch it fail for the right reason, then implement.
- Every user-facing string goes through `context.l10n` in all 11 ARB files, anchored after `equipmentConditionSettings_title` (the condition block) with `@` metadata for every placeholder key; regenerate with `flutter gen-l10n` and stage the generated files. Record every shipped string in the appendix.
- Anything showing a unit goes through `UnitFormatter`; minutes and hours are dimensionless and use their own keys.
- No new schema rung: `trips.expected_dives` and `trips.expected_runtime_minutes` exist since v202.
- Every provider that calls a repository method subscribes to a tick itself (`test/architecture/provider_change_tick_test.dart`), even when it derives from a ticking provider.
- No template names a date prediction, a remaining life or a probability; "predict" appears nowhere. The margin card says "expected use" and "margin after", never "will last".
- Never `git add -A`; stage the listed paths. Commit after every task with the message given.

## File structure

Create:

- `lib/features/trips/domain/entities/scrubber_margin.dart`: `ScrubberMargin`, `ScrubberMarginInputs`.
- `lib/features/trips/domain/services/scrubber_margin_service.dart`: pure `computeScrubberMargin`.
- `lib/features/trips/data/repositories/trip_history_repository.dart`: `TripHistoryRepository` (dives per dive day over recent trips; recent CCR scrubber figures).
- `lib/features/trips/presentation/providers/scrubber_margin_providers.dart`: `tripScrubberMarginsProvider`.
- `lib/features/trips/presentation/widgets/trip_scrubber_margin_card.dart`: `TripScrubberMarginCard`, `tripScrubberMarginSummary`.
- `lib/features/equipment/presentation/providers/condition_badge_providers.dart`: `conditionBadgeProvider`, `ConditionBadge`, `worstBadgeSeverity`.
- `lib/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart`: `exposureRankingProvider`, `findingsByRuleProvider`, `issueTagRankingProvider`, `exposureRankingUnitProvider`.
- Tests beside each.

Modify:

- `lib/features/trips/domain/entities/trip.dart`, `lib/features/trips/data/repositories/trip_repository.dart`, `lib/features/trips/presentation/pages/trip_edit_page.dart`: the two override fields.
- `lib/features/trips/presentation/pages/trip_detail_page.dart` (four banner sites), `lib/features/trips/presentation/widgets/upcoming_trip_banner.dart`.
- `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart`, `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (the `_EquipmentListTile` badge and avatar).
- `lib/features/pre_dive/presentation/widgets/session_item_tile.dart`.
- `lib/features/statistics/data/repositories/statistics_repository.dart` (`getMostUsedGear` union), `lib/features/statistics/presentation/pages/statistics_equipment_page.dart`.
- ARB files and generated Dart.

---

### Task 0: Branch and plan

- [ ] Branch `ericgriffin/equipment-condition-phase4b-surfaces` from `ericgriffin/equipment-condition-phase4a-item-page` (done at plan time).
- [ ] Commit this plan: `docs(equipment): phase 4b plan, badges, trip margin, pre-dive and statistics`.

---

### Task 1: Trip override fields end to end

**Files:** `trip.dart`, `trip_repository.dart` (create and update companions, `_mapRow` at line 640 and `_mapDataToTrip` at line 660), `trip_edit_page.dart` (two controllers, load at `_loadTrip`, save at `_saveTrip`, two `TextFormField`s after the notes field), tests `test/features/trips/domain/entities/trip_expected_fields_test.dart`, `test/features/trips/data/repositories/trip_repository_expected_fields_test.dart`, `test/features/trips/presentation/pages/trip_edit_expected_fields_test.dart`.

**Interfaces:** `Trip.expectedDives` (`int?`), `Trip.expectedRuntimeMinutes` (`int?`), both in the constructor, `copyWith` (with the `_undefined` sentinel the class already uses for nullable fields) and `props`. The serializer exports trips with `row.toJson()`, so sync needs no change; `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` is untouched.

ARB: `trips_edit_label_expectedDives` "Expected dives", `trips_edit_hint_expectedDives` "Leave empty to estimate from your recent trips", `trips_edit_label_expectedRuntime` "Expected runtime per dive (minutes)", `trips_edit_hint_expectedRuntime` "Leave empty to estimate from your recent CCR dives", `trips_edit_sectionTitle_planning` "Planning". These sit in the trips block: anchor after `trips_edit_label_capacity` in all 11 files.

- [ ] **Step 1: Red.** Entity test: `copyWith(expectedDives: 12)` keeps the other field, `copyWith(expectedDives: null)` clears it, equality includes both. Repository test with `setUpTestDatabase`: create a trip with both set, read it back through `getTripById` and `getAllTripsWithStats` (both mappers), update to null and read null. Edit page test: pump `TripEditPage` for a new trip with `getBaseOverrides` plus `validatedCurrentDiverIdProvider` overridden to `'d1'` and a recording `tripListNotifierProvider` double (copy the pattern from the existing trip edit page test), enter `12` and `70`, save, expect the saved trip carries both; leave both empty, expect nulls.
- [ ] **Step 2: Implement** entity, repository (both write sites, both read mappers), the ARB keys, the edit page fields (`keyboardType: TextInputType.number`, `int.tryParse` on save, empty is null), `flutter gen-l10n`.
- [ ] **Step 3: Green**, run `test/features/trips/` fully.
- [ ] **Step 4: Commit** `feat(trips): expected dives and runtime overrides on the trip (condition phase 4b)`.

---

### Task 2: Scrubber margin service and history reads

**Files:** `scrubber_margin.dart`, `scrubber_margin_service.dart`, `trip_history_repository.dart`, tests `test/features/trips/domain/services/scrubber_margin_service_test.dart`, `test/features/trips/data/repositories/trip_history_repository_test.dart`.

**Interfaces:**

```dart
class ScrubberMarginInputs {
  final EquipmentItem item;
  final double? ratedMinutes;            // scrubber_duration_h * 60, else the scrubber-repack schedule's hours interval * 60, else null
  final double consumedMinutes;          // since the newest scrubber-repack record (or ever), CCR and SCR dives only, before the trip start
  final int? expectedDivesOverride;      // trip.expectedDives
  final int itineraryDiveDays;           // DayType.diveDay days, else calendar days of the trip
  final List<double> divesPerDiveDayHistory;   // one figure per recent trip (up to 3)
  final int? runtimeMinutesOverride;     // trip.expectedRuntimeMinutes
  final List<double> scrubberMinutesHistory;   // recent CCR dives with a summary figure (up to 30)
  final List<double> ccrRuntimeMinutesHistory; // recent CCR dives' runtime (up to 30)
}

class ScrubberMargin {
  final EquipmentItem item;
  final double? ratedMinutes;
  final double remainingBefore;          // rated minus consumed, floored at 0; null rated gives null margin
  final int expectedDives; final int expectedDivesN;      // n behind the estimate, 0 for an override
  final double minutesPerDive; final int minutesPerDiveN; // n behind the estimate, 0 for an override
  final double expectedUse;              // dives * minutes
  final double? marginAfter;             // remaining minus expected use, null when rated is null
  final bool caution;                    // marginAfter < 0.2 * rated, or negative
}

ScrubberMargin computeScrubberMargin(ScrubberMarginInputs inputs);
// expected dives = override, else itineraryDiveDays * median(divesPerDiveDayHistory) (default 2 when empty), rounded up
// minutes per dive = override, else median(scrubberMinutesHistory), else median(ccrRuntimeMinutesHistory), else 0

class TripHistoryRepository {
  TripHistoryRepository({AppDatabase? db});
  /// Dives per dive day for the diver's most recent [limit] trips that ended before [before] and had at least one dive, newest first.
  Future<List<double>> divesPerDiveDay({String? diverId, required DateTime before, int limit = 3});
  /// (scrubberMinutes, runtimeMinutes) for the diver's most recent [limit] CCR or SCR dives before [before], newest first; scrubberMinutes null when the dive has no summary figure.
  Future<List<({double? scrubberMinutes, double runtimeMinutes})>> recentCcrFigures({String? diverId, required DateTime before, int limit = 30});
}
```

Both reads are one `customSelect` each: dives grouped by `trip_id` with `COUNT(*)` and `COUNT(DISTINCT date(dive_date_time / 1000, 'unixepoch'))` over trips whose `end_date < ?`, ordered by `end_date DESC LIMIT ?`; and `dives LEFT JOIN dive_sensor_summaries` where `dive_mode IN ('ccr', 'scr') AND dive_date_time < ?` ordered by date desc.

- [ ] **Step 1: Service test (red)**, pure: an override for both fields gives n 0 and the exact product; empty history defaults to 2 dives per day and 0 minutes (expected use 0); medians over odd and even lists; consumed beyond rated floors remaining at 0; margin under 20 percent of rated sets caution; null rated gives null margin and no caution; the runtime fallback is used only when no scrubber figure exists.
- [ ] **Step 2: Repository test (red)** with an in-memory database: three trips with dives on distinct days (one trip after `before`, excluded), expect the per-trip figures newest first; CCR dives with and without summary rows, an OC dive excluded, a dive after `before` excluded.
- [ ] **Step 3: Implement, green.**
- [ ] **Step 4: Commit** `feat(trips): scrubber margin service and trip history reads (condition phase 4b)`.

---

### Task 3: Margin provider, trip card and banner line

**Files:** `scrubber_margin_providers.dart`, `trip_scrubber_margin_card.dart`, `trip_detail_page.dart` (all four `TripServiceAlertBanner(trip: trip)` sites gain `TripScrubberMarginCard(trip: trip)` right after), `upcoming_trip_banner.dart` (one line after the service alert line), tests `test/features/trips/presentation/providers/scrubber_margin_providers_test.dart`, `test/features/trips/presentation/widgets/trip_scrubber_margin_card_test.dart`, plus one case in `test/features/trips/presentation/widgets/trip_list_upcoming_test.dart` for the banner line.

**Interfaces:**

```dart
/// One margin per active rebreather of the trip's diver, as of the trip start. Empty when the diver owns no active rebreather.
final tripScrubberMarginsProvider = FutureProvider.family<List<ScrubberMargin>, String>(...);
// Reads: tripByIdProvider, validatedCurrentDiverIdProvider, EquipmentRepository.getActiveEquipment (type rebreather), the item's scrubber_duration_h attribute, ServiceScheduleRepository.getSchedulesForEquipment + ServiceKindRepository (kind id 'scrubber-repack', hours interval), ServiceRecordRepository.getRecordsForEquipment (newest record with serviceKindId 'scrubber-repack' before the trip start), equipmentExposureInputsProvider(item.id) for the samples (filter date >= repack date and < trip start, CCR or SCR mode, consumed = summary scrubberConsumedMinutes else runtime minutes; the summaries through DiveSensorSummaryRepository.getSummaries), ItineraryDayRepository.getByTripId for dive days, TripHistoryRepository for both histories.
// Ticks: equipment changes, dive detail changes, service records (watchServiceRecordChanges or the equipment tick if none exists), trips (watchTripsChanges).
String tripScrubberMarginSummary(AppLocalizations l10n, List<ScrubberMargin> margins); // one line: the worst margin, or the count when several
class TripScrubberMarginCard extends ConsumerWidget { final Trip trip; }
```

Card (a `Card` with icon `Icons.air`, title `trips_scrubber_title` "Scrubber margin", one block per rebreather): the item name, then four lines, each with its n where estimated: `trips_scrubber_remaining` "{minutes} min left before the trip (rated {rated} min, {consumed} min used since the last repack)", `trips_scrubber_expectedDives` "{dives} expected dives" plus `trips_scrubber_fromTrips` " (from your last {n} trips)" or `trips_scrubber_fromOverride` " (set on this trip)", `trips_scrubber_perDive` "{minutes} min per dive" plus `trips_scrubber_fromDives` " (from your last {n} CCR dives)" or the override suffix, `trips_scrubber_expectedUse` "{minutes} min expected use", `trips_scrubber_margin` "{minutes} min margin after the trip", `trips_scrubber_caution` "Under 20 percent of the rated duration. Plan a repack or carry spare absorbent." (error colour when caution), `trips_scrubber_noRating` "No rated duration on this rebreather; add scrubber duration to its attributes or a repack schedule." when rated is null. Past trips: title suffix `trips_scrubber_asOfStart` "as of {date}". Banner line: `trips_scrubber_bannerMargin` "{minutes} min scrubber margin" (error colour when caution) or `trips_scrubber_bannerCount` "{count} rebreathers, lowest {minutes} min scrubber margin". Renders nothing when the list is empty.

- [ ] **Step 1: Provider test (red)** on an in-memory database: a rebreather with `scrubber_duration_h` 5 (rated 300), one repack record on 1 Feb, two CCR dives after it with summary figures 40 and 50 (and one before it, excluded), a trip starting 1 June with no overrides and three earlier trips of two dives per day: expect consumed 90, remaining 210, expected dives = calendar days times 2, minutes per dive 45 (the median of 40 and 50), n values, and the caution flag; a past trip starting 15 Feb sees only the first dive.
- [ ] **Step 2: Card test (red)**: override `tripScrubberMarginsProvider('t1')` with a margin; expect the four lines and the caution text; empty list renders nothing; a null rating shows the no-rating line.
- [ ] **Step 3: Add keys, gen-l10n, implement, wire the four sites and the banner, green**; run `test/features/trips/` fully.
- [ ] **Step 4: Commit** `feat(trips): scrubber margin card and banner line (condition phase 4b)`.

---

### Task 4: List badges

**Files:** `condition_badge_providers.dart`, `dense_equipment_list_tile.dart`, `equipment_list_content.dart`, tests `test/features/equipment/presentation/providers/condition_badge_providers_test.dart`, `test/features/equipment/presentation/widgets/equipment_tile_condition_badge_test.dart`.

**Interfaces:**

```dart
typedef ConditionBadge = ({ConditionSeverity severity, ConditionRuleId rule});
/// Worst undismissed finding per item, caution or significant only, after the master toggle and the disabled rules; empty when the engine is off. One getAllUndismissed read; ticks on findings and equipment.
final conditionBadgeProvider = FutureProvider<Map<String, ConditionBadge>>(...);
/// The badge severity to draw: overdue beats significant beats dueSoon beats caution beats nothing.
({bool overdue, String label})? worstBadge({RollupClock? clock, ConditionBadge? finding, required AppLocalizations l10n, required String itemId});
```

Both tiles call `worstBadge` where they now read the rollup: the label is the clock's kind name (or the rollup phrasing) when the clock wins, else `conditionFindingShortLabel(rule, l10n)`; the colour is `error` for overdue or significant, `tertiary` otherwise; the avatar's error container follows `overdue` (overdue clock or significant finding). Info findings never badge.

- [ ] **Step 1: Provider test (red)** with a database: two findings on `reg` (info and caution), one significant on `bcd`, one dismissed significant on `mask`; expect `reg` caution, `bcd` significant, `mask` absent; with `conditionDisabledRules: {'cellOutputLow'}` the bcd entry goes; with the engine off the map is empty.
- [ ] **Step 2: Tile test (red)**, both tiles, mirroring `equipment_tile_service_badge_test.dart`: a significant finding and no clock gives the rule label in the error colour; a due-soon clock plus a significant finding shows the finding; an overdue clock plus a caution finding shows the clock; a caution finding alone uses the tertiary colour.
- [ ] **Step 3: Implement, green**; run `test/features/equipment/presentation/widgets/` fully.
- [ ] **Step 4: Commit** `feat(equipment): condition findings on the list badges (condition phase 4b)`.

---

### Task 5: Pre-dive runner warning

**Files:** `session_item_tile.dart`, test cases in `test/features/pre_dive/presentation/widgets/session_item_tile_test.dart`.

Behaviour: for a pending item with an `equipmentId`, read `equipmentConditionProvider(equipmentId).value`, filter through `hasVisibleConditionFindings`-style rules (master toggle, disabled rules), keep undismissed significant findings. The warning block: when overdue entries exist the header stays `preDive_runner_serviceOverdue` and the clock lines follow; when findings exist a header `preDive_runner_conditionFindings` "Condition findings" precedes one line per finding with `conditionFindingShortLabel`, in the error colour. Resolved items show the frozen clocks only (findings are not part of the snapshot, and the block says nothing about them).

ARB: `preDive_runner_conditionFindings` "Condition findings", anchored after `preDive_runner_serviceOverdue`.

- [ ] **Step 1: Red**: a pending item with a significant finding on `g1` shows "Condition findings" and the rule label; a caution finding shows nothing; a dismissed significant finding shows nothing; both overdue and finding show both headers in order; a resolved item with a finding shows no finding line; the engine off shows nothing.
- [ ] **Step 2: Implement, green**; run `test/features/pre_dive/` fully.
- [ ] **Step 3: Commit** `feat(pre-dive): significant condition findings in the runner warning (condition phase 4b)`.

---

### Task 6: Statistics equipment page

**Files:** `statistics_repository.dart` (`getMostUsedGear`), `equipment_condition_statistics_providers.dart`, `statistics_equipment_page.dart`, tests `test/features/statistics/data/repositories/statistics_repository_most_used_gear_test.dart`, `test/features/statistics/presentation/providers/equipment_condition_statistics_providers_test.dart`, cases in `test/features/statistics/presentation/pages/statistics_equipment_page_test.dart`.

**Interfaces:**

```dart
final exposureRankingUnitProvider = StateProvider<ExposureUnit>((ref) => ExposureUnit.hours);
/// Active items ranked by their total in the chosen unit, through the same samples and classifier the item page uses (equipmentExposureInputsProvider per item), value = total, count = dive count.
final exposureRankingProvider = FutureProvider<List<RankingItem>>(...);
/// Undismissed findings per rule after the display filter, name = short rule label, id = rule dbValue.
final findingsByRuleProvider = FutureProvider<List<RankingItem>>(...);
/// Issue tags by count over the diver's issue check-ins, name = tag label, id = tag dbValue.
final issueTagRankingProvider = FutureProvider<List<RankingItem>>(...);
```

`getMostUsedGear`: the join becomes a UNION of `dive_equipment` rows and `dive_tanks.equipment_id` rows (distinct per dive and item), so a cylinder linked through the transmitter registry counts. Page: three `StatSectionCard`s after the most used gear: `statistics_equipment_exposure_title` "Exposure", `statistics_equipment_exposure_subtitle` "Totals per item with your thresholds", the card's `trailing` a `DropdownButton<ExposureUnit>` over hours, salt-water hours, cold dives, high-O2 hours, deep dives, battery cycles (labels `equipmentCondition_exposure_unit_*`: "Hours", "Salt-water hours", "Cold dives", "High-O2 hours", "Deep dives", "Battery cycles"); `statistics_equipment_findings_title` "Condition findings", `statistics_equipment_findings_subtitle` "Open findings by rule"; `statistics_equipment_issues_title` "Reported issues", `statistics_equipment_issues_subtitle` "Most frequent check-in tags"; `countLabel` for each from `statistics_equipment_countLabel_items` "items", `_findings` "findings", `_reports` "reports"; empty states `statistics_equipment_exposure_empty` "No dives with gear yet", `statistics_equipment_findings_empty` "No open findings", `statistics_equipment_issues_empty` "No issues reported". Exposure rows navigate to `/equipment/<id>`.

- [ ] **Step 1: Repository test (red)**: a tank linked only through `dive_tanks.equipment_id` on two dives and a regulator through `dive_equipment` on one; expect the tank first with 2 and the regulator with 1; a dive carrying the same item through both paths counts once.
- [ ] **Step 2: Providers test (red)** on a database: two active items with different hour totals rank in order for `hours` and swap for `coldDives`; findings by rule counts and hides a disabled rule; issue tags count across observations.
- [ ] **Step 3: Page test (red)**: override the three providers and expect the three titles, a ranking row per item, the dropdown switching the unit state.
- [ ] **Step 4: Add keys, gen-l10n, implement, green**; run `test/features/statistics/` fully.
- [ ] **Step 5: Commit** `feat(statistics): exposure, findings and issue rankings on the equipment page (condition phase 4b)`.

---

### Task 7: Wrap-up

- [ ] `dart format .`, `flutter analyze`, `flutter gen-l10n && git status --short lib/l10n` (clean), em-dash scan over the touched features.
- [ ] Full suite once.
- [ ] Mutation checks: (a) in `computeScrubberMargin` use the mean instead of the median and confirm the even-list median test fails; (b) in `conditionBadgeProvider` drop the `dismissedAt == null` filter and confirm the mask case fails; (c) in `getMostUsedGear` drop the `dive_tanks` arm of the union and confirm the tank test fails. Restore from scratchpad backups.
- [ ] Fill the appendix; push `SKIP_TESTS=1`; PR against `ericgriffin/equipment-condition-phase4a-item-page` titled `feat(equipment): badges, trip scrubber margin, pre-dive and statistics (condition intelligence phase 4b)`; update the program memory and mark the program's build complete (merges pending).

## Translation Appendix

Generated at Task 7 from the ARB files: every key this phase added (trip planning fields, scrubber margin, pre-dive warning, statistics rankings), per locale.

### en

- `preDive_runner_conditionFindings`: Condition findings
- `statistics_equipment_exposure_title`: Exposure
- `statistics_equipment_exposure_subtitle`: Totals per item with your thresholds
- `statistics_equipment_exposure_empty`: No dives with gear yet
- `statistics_equipment_findings_title`: Condition findings
- `statistics_equipment_findings_subtitle`: Open findings by rule
- `statistics_equipment_findings_empty`: No open findings
- `statistics_equipment_issues_title`: Reported issues
- `statistics_equipment_issues_subtitle`: Most frequent check-in tags
- `statistics_equipment_issues_empty`: No issues reported
- `statistics_equipment_countLabel_items`: items
- `statistics_equipment_countLabel_findings`: findings
- `statistics_equipment_countLabel_reports`: reports
- `statistics_equipment_exposureUnit_hours`: Hours
- `statistics_equipment_exposureUnit_saltHours`: Salt-water hours
- `statistics_equipment_exposureUnit_coldDives`: Cold dives
- `statistics_equipment_exposureUnit_o2Hours`: High-O2 hours
- `statistics_equipment_exposureUnit_deepCycles`: Deep dives
- `statistics_equipment_exposureUnit_cycles`: Battery cycles
- `trips_edit_sectionTitle_planning`: Planning
- `trips_edit_label_expectedDives`: Expected dives
- `trips_edit_hint_expectedDives`: Leave empty to estimate from your recent trips
- `trips_edit_label_expectedRuntime`: Expected runtime per dive (minutes)
- `trips_edit_hint_expectedRuntime`: Leave empty to estimate from your recent CCR dives
- `trips_scrubber_title`: Scrubber margin
- `trips_scrubber_asOfStart`: as of {date}
- `trips_scrubber_remaining`: {minutes} min left before the trip (rated {rated} min, {consumed} min used since the last repack)
- `trips_scrubber_expectedDives`: {dives} expected dives
- `trips_scrubber_fromTrips`: (from your last {n} trips)
- `trips_scrubber_fromOverride`: (set on this trip)
- `trips_scrubber_perDive`: {minutes} min per dive
- `trips_scrubber_fromDives`: (from your last {n} CCR dives)
- `trips_scrubber_expectedUse`: {minutes} min expected use
- `trips_scrubber_margin`: {minutes} min margin after the trip
- `trips_scrubber_caution`: Under 20 percent of the rated duration. Plan a repack or carry spare absorbent.
- `trips_scrubber_noRating`: No rated duration on this rebreather; add scrubber duration to its attributes or a repack schedule.
- `trips_scrubber_bannerMargin`: {minutes} min scrubber margin
- `trips_scrubber_bannerCount`: {count} rebreathers, lowest {minutes} min scrubber margin

### es

- `preDive_runner_conditionFindings`: Hallazgos de estado
- `statistics_equipment_exposure_title`: Exposición
- `statistics_equipment_exposure_subtitle`: Totales por artículo con tus umbrales
- `statistics_equipment_exposure_empty`: Aún no hay inmersiones con equipo
- `statistics_equipment_findings_title`: Hallazgos de estado
- `statistics_equipment_findings_subtitle`: Hallazgos abiertos por regla
- `statistics_equipment_findings_empty`: No hay hallazgos abiertos
- `statistics_equipment_issues_title`: Problemas registrados
- `statistics_equipment_issues_subtitle`: Etiquetas de revisión más frecuentes
- `statistics_equipment_issues_empty`: No hay problemas registrados
- `statistics_equipment_countLabel_items`: artículos
- `statistics_equipment_countLabel_findings`: hallazgos
- `statistics_equipment_countLabel_reports`: registros
- `statistics_equipment_exposureUnit_hours`: Horas
- `statistics_equipment_exposureUnit_saltHours`: Horas en agua salada
- `statistics_equipment_exposureUnit_coldDives`: Inmersiones frías
- `statistics_equipment_exposureUnit_o2Hours`: Horas con O2 alto
- `statistics_equipment_exposureUnit_deepCycles`: Inmersiones profundas
- `statistics_equipment_exposureUnit_cycles`: Ciclos de batería
- `trips_edit_sectionTitle_planning`: Planificación
- `trips_edit_label_expectedDives`: Inmersiones previstas
- `trips_edit_hint_expectedDives`: Déjalo vacío para estimar a partir de tus viajes recientes
- `trips_edit_label_expectedRuntime`: Duración prevista por inmersión (minutos)
- `trips_edit_hint_expectedRuntime`: Déjalo vacío para estimar a partir de tus inmersiones CCR recientes
- `trips_scrubber_title`: Margen del absorbente
- `trips_scrubber_asOfStart`: a fecha de {date}
- `trips_scrubber_remaining`: {minutes} min restantes antes del viaje (nominal {rated} min, {consumed} min usados desde el último cambio)
- `trips_scrubber_expectedDives`: {dives} inmersiones previstas
- `trips_scrubber_fromTrips`: (según tus últimos {n} viajes)
- `trips_scrubber_fromOverride`: (fijado en este viaje)
- `trips_scrubber_perDive`: {minutes} min por inmersión
- `trips_scrubber_fromDives`: (según tus últimas {n} inmersiones CCR)
- `trips_scrubber_expectedUse`: {minutes} min de uso previsto
- `trips_scrubber_margin`: {minutes} min de margen tras el viaje
- `trips_scrubber_caution`: Menos del 20 por ciento de la duración nominal. Planifica un cambio o lleva absorbente de repuesto.
- `trips_scrubber_noRating`: Este rebreather no tiene duración nominal; añade la duración del absorbente a sus atributos o un programa de cambio.
- `trips_scrubber_bannerMargin`: {minutes} min de margen de absorbente
- `trips_scrubber_bannerCount`: {count} rebreathers, el menor con {minutes} min de margen de absorbente

### de

- `preDive_runner_conditionFindings`: Zustandsbefunde
- `statistics_equipment_exposure_title`: Belastung
- `statistics_equipment_exposure_subtitle`: Summen je Teil mit deinen Schwellen
- `statistics_equipment_exposure_empty`: Noch keine Tauchgänge mit Ausrüstung
- `statistics_equipment_findings_title`: Zustandsbefunde
- `statistics_equipment_findings_subtitle`: Offene Befunde je Regel
- `statistics_equipment_findings_empty`: Keine offenen Befunde
- `statistics_equipment_issues_title`: Gemeldete Probleme
- `statistics_equipment_issues_subtitle`: Häufigste Check-in-Tags
- `statistics_equipment_issues_empty`: Keine Probleme gemeldet
- `statistics_equipment_countLabel_items`: Teile
- `statistics_equipment_countLabel_findings`: Befunde
- `statistics_equipment_countLabel_reports`: Meldungen
- `statistics_equipment_exposureUnit_hours`: Stunden
- `statistics_equipment_exposureUnit_saltHours`: Salzwasserstunden
- `statistics_equipment_exposureUnit_coldDives`: Kalte Tauchgänge
- `statistics_equipment_exposureUnit_o2Hours`: Stunden mit hohem O2
- `statistics_equipment_exposureUnit_deepCycles`: Tiefe Tauchgänge
- `statistics_equipment_exposureUnit_cycles`: Akkuzyklen
- `trips_edit_sectionTitle_planning`: Planung
- `trips_edit_label_expectedDives`: Erwartete Tauchgänge
- `trips_edit_hint_expectedDives`: Leer lassen, um aus deinen letzten Reisen zu schätzen
- `trips_edit_label_expectedRuntime`: Erwartete Laufzeit je Tauchgang (Minuten)
- `trips_edit_hint_expectedRuntime`: Leer lassen, um aus deinen letzten CCR-Tauchgängen zu schätzen
- `trips_scrubber_title`: Atemkalkreserve
- `trips_scrubber_asOfStart`: Stand {date}
- `trips_scrubber_remaining`: {minutes} min übrig vor der Reise (nominell {rated} min, {consumed} min seit dem letzten Wechsel verbraucht)
- `trips_scrubber_expectedDives`: {dives} erwartete Tauchgänge
- `trips_scrubber_fromTrips`: (aus deinen letzten {n} Reisen)
- `trips_scrubber_fromOverride`: (auf dieser Reise festgelegt)
- `trips_scrubber_perDive`: {minutes} min je Tauchgang
- `trips_scrubber_fromDives`: (aus deinen letzten {n} CCR-Tauchgängen)
- `trips_scrubber_expectedUse`: {minutes} min erwarteter Verbrauch
- `trips_scrubber_margin`: {minutes} min Reserve nach der Reise
- `trips_scrubber_caution`: Unter 20 Prozent der nominellen Dauer. Plane einen Wechsel oder nimm Ersatzkalk mit.
- `trips_scrubber_noRating`: Für diesen Rebreather ist keine nominelle Dauer hinterlegt; trage die Atemkalkdauer in den Attributen ein oder lege einen Wechselplan an.
- `trips_scrubber_bannerMargin`: {minutes} min Atemkalkreserve
- `trips_scrubber_bannerCount`: {count} Rebreather, niedrigste Atemkalkreserve {minutes} min

### fr

- `preDive_runner_conditionFindings`: Constats d'état
- `statistics_equipment_exposure_title`: Exposition
- `statistics_equipment_exposure_subtitle`: Totaux par équipement avec vos seuils
- `statistics_equipment_exposure_empty`: Aucune plongée avec équipement pour l'instant
- `statistics_equipment_findings_title`: Constats d'état
- `statistics_equipment_findings_subtitle`: Constats ouverts par règle
- `statistics_equipment_findings_empty`: Aucun constat ouvert
- `statistics_equipment_issues_title`: Problèmes signalés
- `statistics_equipment_issues_subtitle`: Étiquettes de contrôle les plus fréquentes
- `statistics_equipment_issues_empty`: Aucun problème signalé
- `statistics_equipment_countLabel_items`: équipements
- `statistics_equipment_countLabel_findings`: constats
- `statistics_equipment_countLabel_reports`: signalements
- `statistics_equipment_exposureUnit_hours`: Heures
- `statistics_equipment_exposureUnit_saltHours`: Heures en eau salée
- `statistics_equipment_exposureUnit_coldDives`: Plongées froides
- `statistics_equipment_exposureUnit_o2Hours`: Heures à O2 élevé
- `statistics_equipment_exposureUnit_deepCycles`: Plongées profondes
- `statistics_equipment_exposureUnit_cycles`: Cycles de batterie
- `trips_edit_sectionTitle_planning`: Planification
- `trips_edit_label_expectedDives`: Plongées prévues
- `trips_edit_hint_expectedDives`: Laisser vide pour estimer d'après vos voyages récents
- `trips_edit_label_expectedRuntime`: Durée prévue par plongée (minutes)
- `trips_edit_hint_expectedRuntime`: Laisser vide pour estimer d'après vos plongées CCR récentes
- `trips_scrubber_title`: Marge de chaux
- `trips_scrubber_asOfStart`: au {date}
- `trips_scrubber_remaining`: {minutes} min restantes avant le voyage (nominal {rated} min, {consumed} min utilisées depuis le dernier remplissage)
- `trips_scrubber_expectedDives`: {dives} plongées prévues
- `trips_scrubber_fromTrips`: (d'après vos {n} derniers voyages)
- `trips_scrubber_fromOverride`: (défini sur ce voyage)
- `trips_scrubber_perDive`: {minutes} min par plongée
- `trips_scrubber_fromDives`: (d'après vos {n} dernières plongées CCR)
- `trips_scrubber_expectedUse`: {minutes} min d'usage prévu
- `trips_scrubber_margin`: {minutes} min de marge après le voyage
- `trips_scrubber_caution`: Moins de 20 pour cent de la durée nominale. Prévoyez un remplissage ou emportez de la chaux de rechange.
- `trips_scrubber_noRating`: Aucune durée nominale sur ce recycleur ; ajoutez la durée de la chaux à ses attributs ou un calendrier de remplissage.
- `trips_scrubber_bannerMargin`: {minutes} min de marge de chaux
- `trips_scrubber_bannerCount`: {count} recycleurs, la plus faible marge de chaux est de {minutes} min

### it

- `preDive_runner_conditionFindings`: Rilievi sullo stato
- `statistics_equipment_exposure_title`: Esposizione
- `statistics_equipment_exposure_subtitle`: Totali per articolo con le tue soglie
- `statistics_equipment_exposure_empty`: Ancora nessuna immersione con attrezzatura
- `statistics_equipment_findings_title`: Rilievi sullo stato
- `statistics_equipment_findings_subtitle`: Rilievi aperti per regola
- `statistics_equipment_findings_empty`: Nessun rilievo aperto
- `statistics_equipment_issues_title`: Problemi segnalati
- `statistics_equipment_issues_subtitle`: Tag di controllo più frequenti
- `statistics_equipment_issues_empty`: Nessun problema segnalato
- `statistics_equipment_countLabel_items`: articoli
- `statistics_equipment_countLabel_findings`: rilievi
- `statistics_equipment_countLabel_reports`: segnalazioni
- `statistics_equipment_exposureUnit_hours`: Ore
- `statistics_equipment_exposureUnit_saltHours`: Ore in acqua salata
- `statistics_equipment_exposureUnit_coldDives`: Immersioni fredde
- `statistics_equipment_exposureUnit_o2Hours`: Ore ad alto O2
- `statistics_equipment_exposureUnit_deepCycles`: Immersioni profonde
- `statistics_equipment_exposureUnit_cycles`: Cicli batteria
- `trips_edit_sectionTitle_planning`: Pianificazione
- `trips_edit_label_expectedDives`: Immersioni previste
- `trips_edit_hint_expectedDives`: Lascia vuoto per stimare dai tuoi viaggi recenti
- `trips_edit_label_expectedRuntime`: Durata prevista per immersione (minuti)
- `trips_edit_hint_expectedRuntime`: Lascia vuoto per stimare dalle tue immersioni CCR recenti
- `trips_scrubber_title`: Margine della calce
- `trips_scrubber_asOfStart`: al {date}
- `trips_scrubber_remaining`: {minutes} min rimasti prima del viaggio (nominale {rated} min, {consumed} min usati dall'ultimo ricambio)
- `trips_scrubber_expectedDives`: {dives} immersioni previste
- `trips_scrubber_fromTrips`: (dai tuoi ultimi {n} viaggi)
- `trips_scrubber_fromOverride`: (impostato su questo viaggio)
- `trips_scrubber_perDive`: {minutes} min per immersione
- `trips_scrubber_fromDives`: (dalle tue ultime {n} immersioni CCR)
- `trips_scrubber_expectedUse`: {minutes} min di uso previsto
- `trips_scrubber_margin`: {minutes} min di margine dopo il viaggio
- `trips_scrubber_caution`: Sotto il 20 per cento della durata nominale. Pianifica un ricambio o porta calce di scorta.
- `trips_scrubber_noRating`: Nessuna durata nominale su questo rebreather; aggiungi la durata della calce ai suoi attributi o una pianificazione di ricambio.
- `trips_scrubber_bannerMargin`: {minutes} min di margine della calce
- `trips_scrubber_bannerCount`: {count} rebreather, il margine più basso è {minutes} min

### pt

- `preDive_runner_conditionFindings`: Constatações de estado
- `statistics_equipment_exposure_title`: Exposição
- `statistics_equipment_exposure_subtitle`: Totais por item com os seus limites
- `statistics_equipment_exposure_empty`: Ainda não há mergulhos com equipamento
- `statistics_equipment_findings_title`: Constatações de estado
- `statistics_equipment_findings_subtitle`: Constatações abertas por regra
- `statistics_equipment_findings_empty`: Sem constatações abertas
- `statistics_equipment_issues_title`: Problemas registados
- `statistics_equipment_issues_subtitle`: Etiquetas de verificação mais frequentes
- `statistics_equipment_issues_empty`: Sem problemas registados
- `statistics_equipment_countLabel_items`: itens
- `statistics_equipment_countLabel_findings`: constatações
- `statistics_equipment_countLabel_reports`: registos
- `statistics_equipment_exposureUnit_hours`: Horas
- `statistics_equipment_exposureUnit_saltHours`: Horas em água salgada
- `statistics_equipment_exposureUnit_coldDives`: Mergulhos frios
- `statistics_equipment_exposureUnit_o2Hours`: Horas com O2 elevado
- `statistics_equipment_exposureUnit_deepCycles`: Mergulhos profundos
- `statistics_equipment_exposureUnit_cycles`: Ciclos de bateria
- `trips_edit_sectionTitle_planning`: Planeamento
- `trips_edit_label_expectedDives`: Mergulhos previstos
- `trips_edit_hint_expectedDives`: Deixe vazio para estimar a partir das suas viagens recentes
- `trips_edit_label_expectedRuntime`: Duração prevista por mergulho (minutos)
- `trips_edit_hint_expectedRuntime`: Deixe vazio para estimar a partir dos seus mergulhos CCR recentes
- `trips_scrubber_title`: Margem do absorvente
- `trips_scrubber_asOfStart`: à data de {date}
- `trips_scrubber_remaining`: {minutes} min restantes antes da viagem (nominal {rated} min, {consumed} min usados desde a última troca)
- `trips_scrubber_expectedDives`: {dives} mergulhos previstos
- `trips_scrubber_fromTrips`: (das suas últimas {n} viagens)
- `trips_scrubber_fromOverride`: (definido nesta viagem)
- `trips_scrubber_perDive`: {minutes} min por mergulho
- `trips_scrubber_fromDives`: (dos seus últimos {n} mergulhos CCR)
- `trips_scrubber_expectedUse`: {minutes} min de uso previsto
- `trips_scrubber_margin`: {minutes} min de margem após a viagem
- `trips_scrubber_caution`: Abaixo de 20 por cento da duração nominal. Planeie uma troca ou leve absorvente de reserva.
- `trips_scrubber_noRating`: Sem duração nominal neste rebreather; adicione a duração do absorvente aos atributos ou um plano de troca.
- `trips_scrubber_bannerMargin`: {minutes} min de margem de absorvente
- `trips_scrubber_bannerCount`: {count} rebreathers, a menor margem de absorvente é de {minutes} min

### nl

- `preDive_runner_conditionFindings`: Conditiebevindingen
- `statistics_equipment_exposure_title`: Blootstelling
- `statistics_equipment_exposure_subtitle`: Totalen per item met jouw drempels
- `statistics_equipment_exposure_empty`: Nog geen duiken met uitrusting
- `statistics_equipment_findings_title`: Conditiebevindingen
- `statistics_equipment_findings_subtitle`: Open bevindingen per regel
- `statistics_equipment_findings_empty`: Geen open bevindingen
- `statistics_equipment_issues_title`: Gemelde problemen
- `statistics_equipment_issues_subtitle`: Meest voorkomende check-in-tags
- `statistics_equipment_issues_empty`: Geen problemen gemeld
- `statistics_equipment_countLabel_items`: items
- `statistics_equipment_countLabel_findings`: bevindingen
- `statistics_equipment_countLabel_reports`: meldingen
- `statistics_equipment_exposureUnit_hours`: Uur
- `statistics_equipment_exposureUnit_saltHours`: Uur in zout water
- `statistics_equipment_exposureUnit_coldDives`: Koude duiken
- `statistics_equipment_exposureUnit_o2Hours`: Uur met hoog O2
- `statistics_equipment_exposureUnit_deepCycles`: Diepe duiken
- `statistics_equipment_exposureUnit_cycles`: Batterijcycli
- `trips_edit_sectionTitle_planning`: Planning
- `trips_edit_label_expectedDives`: Verwachte duiken
- `trips_edit_hint_expectedDives`: Laat leeg om te schatten op basis van je recente reizen
- `trips_edit_label_expectedRuntime`: Verwachte looptijd per duik (minuten)
- `trips_edit_hint_expectedRuntime`: Laat leeg om te schatten op basis van je recente CCR-duiken
- `trips_scrubber_title`: Scrubbermarge
- `trips_scrubber_asOfStart`: per {date}
- `trips_scrubber_remaining`: {minutes} min over voor de reis (nominaal {rated} min, {consumed} min gebruikt sinds de laatste vulling)
- `trips_scrubber_expectedDives`: {dives} verwachte duiken
- `trips_scrubber_fromTrips`: (uit je laatste {n} reizen)
- `trips_scrubber_fromOverride`: (ingesteld op deze reis)
- `trips_scrubber_perDive`: {minutes} min per duik
- `trips_scrubber_fromDives`: (uit je laatste {n} CCR-duiken)
- `trips_scrubber_expectedUse`: {minutes} min verwacht gebruik
- `trips_scrubber_margin`: {minutes} min marge na de reis
- `trips_scrubber_caution`: Onder 20 procent van de nominale duur. Plan een vulling of neem reservekalk mee.
- `trips_scrubber_noRating`: Geen nominale duur op deze rebreather; voeg de scrubberduur toe aan de attributen of maak een vulschema.
- `trips_scrubber_bannerMargin`: {minutes} min scrubbermarge
- `trips_scrubber_bannerCount`: {count} rebreathers, laagste scrubbermarge {minutes} min

### hu

- `preDive_runner_conditionFindings`: Állapotmegállapítások
- `statistics_equipment_exposure_title`: Igénybevétel
- `statistics_equipment_exposure_subtitle`: Összegek eszközönként a küszöbeiddel
- `statistics_equipment_exposure_empty`: Még nincs merülés felszereléssel
- `statistics_equipment_findings_title`: Állapotmegállapítások
- `statistics_equipment_findings_subtitle`: Nyitott megállapítások szabályonként
- `statistics_equipment_findings_empty`: Nincs nyitott megállapítás
- `statistics_equipment_issues_title`: Bejelentett problémák
- `statistics_equipment_issues_subtitle`: Leggyakoribb ellenőrzési címkék
- `statistics_equipment_issues_empty`: Nincs bejelentett probléma
- `statistics_equipment_countLabel_items`: eszköz
- `statistics_equipment_countLabel_findings`: megállapítás
- `statistics_equipment_countLabel_reports`: bejelentés
- `statistics_equipment_exposureUnit_hours`: Óra
- `statistics_equipment_exposureUnit_saltHours`: Sósvízi óra
- `statistics_equipment_exposureUnit_coldDives`: Hideg merülés
- `statistics_equipment_exposureUnit_o2Hours`: Óra magas O2-vel
- `statistics_equipment_exposureUnit_deepCycles`: Mély merülés
- `statistics_equipment_exposureUnit_cycles`: Akkumulátorciklus
- `trips_edit_sectionTitle_planning`: Tervezés
- `trips_edit_label_expectedDives`: Várható merülések
- `trips_edit_hint_expectedDives`: Hagyd üresen, hogy a legutóbbi utazásaidból becsüljük
- `trips_edit_label_expectedRuntime`: Várható futásidő merülésenként (perc)
- `trips_edit_hint_expectedRuntime`: Hagyd üresen, hogy a legutóbbi CCR-merüléseidből becsüljük
- `trips_scrubber_title`: Szűrőtartalék
- `trips_scrubber_asOfStart`: {date} állapot szerint
- `trips_scrubber_remaining`: {minutes} perc maradt az utazás előtt (névleges {rated} perc, {consumed} perc elhasználva a legutóbbi csere óta)
- `trips_scrubber_expectedDives`: {dives} várható merülés
- `trips_scrubber_fromTrips`: (a legutóbbi {n} utazásod alapján)
- `trips_scrubber_fromOverride`: (ezen az utazáson beállítva)
- `trips_scrubber_perDive`: {minutes} perc merülésenként
- `trips_scrubber_fromDives`: (a legutóbbi {n} CCR-merülésed alapján)
- `trips_scrubber_expectedUse`: {minutes} perc várható használat
- `trips_scrubber_margin`: {minutes} perc tartalék az utazás után
- `trips_scrubber_caution`: A névleges időtartam 20 százaléka alatt. Tervezz cserét, vagy vigyél tartalék szűrőanyagot.
- `trips_scrubber_noRating`: Ehhez a rebreatherhez nincs névleges időtartam; add meg a szűrő időtartamát az attribútumoknál, vagy hozz létre csereütemezést.
- `trips_scrubber_bannerMargin`: {minutes} perc szűrőtartalék
- `trips_scrubber_bannerCount`: {count} rebreather, a legkisebb szűrőtartalék {minutes} perc

### ar

- `preDive_runner_conditionFindings`: نتائج الحالة
- `statistics_equipment_exposure_title`: التعرّض
- `statistics_equipment_exposure_subtitle`: الإجماليات لكل قطعة وفق حدودك
- `statistics_equipment_exposure_empty`: لا توجد غطسات بمعدات بعد
- `statistics_equipment_findings_title`: نتائج الحالة
- `statistics_equipment_findings_subtitle`: النتائج المفتوحة حسب القاعدة
- `statistics_equipment_findings_empty`: لا توجد نتائج مفتوحة
- `statistics_equipment_issues_title`: المشكلات المبلّغ عنها
- `statistics_equipment_issues_subtitle`: أكثر وسوم الفحص تكرارًا
- `statistics_equipment_issues_empty`: لم يُبلَّغ عن مشكلات
- `statistics_equipment_countLabel_items`: قطع
- `statistics_equipment_countLabel_findings`: نتائج
- `statistics_equipment_countLabel_reports`: بلاغات
- `statistics_equipment_exposureUnit_hours`: ساعات
- `statistics_equipment_exposureUnit_saltHours`: ساعات في المياه المالحة
- `statistics_equipment_exposureUnit_coldDives`: غطسات باردة
- `statistics_equipment_exposureUnit_o2Hours`: ساعات بأكسجين مرتفع
- `statistics_equipment_exposureUnit_deepCycles`: غطسات عميقة
- `statistics_equipment_exposureUnit_cycles`: دورات بطارية
- `trips_edit_sectionTitle_planning`: التخطيط
- `trips_edit_label_expectedDives`: الغطسات المتوقعة
- `trips_edit_hint_expectedDives`: اتركه فارغًا للتقدير من رحلاتك الأخيرة
- `trips_edit_label_expectedRuntime`: مدة التشغيل المتوقعة لكل غطسة (بالدقائق)
- `trips_edit_hint_expectedRuntime`: اتركه فارغًا للتقدير من غطسات الدائرة المغلقة الأخيرة
- `trips_scrubber_title`: هامش المنظّف
- `trips_scrubber_asOfStart`: حتى {date}
- `trips_scrubber_remaining`: {minutes} دقيقة متبقية قبل الرحلة (المقدّر {rated} دقيقة، استُهلك {consumed} دقيقة منذ آخر إعادة تعبئة)
- `trips_scrubber_expectedDives`: {dives} غطسة متوقعة
- `trips_scrubber_fromTrips`: (من آخر {n} رحلات لك)
- `trips_scrubber_fromOverride`: (محدد في هذه الرحلة)
- `trips_scrubber_perDive`: {minutes} دقيقة لكل غطسة
- `trips_scrubber_fromDives`: (من آخر {n} غطسات دائرة مغلقة لك)
- `trips_scrubber_expectedUse`: {minutes} دقيقة استخدام متوقع
- `trips_scrubber_margin`: {minutes} دقيقة هامش بعد الرحلة
- `trips_scrubber_caution`: أقل من 20 بالمئة من المدة المقدّرة. خطّط لإعادة تعبئة أو احمل مادة ماصّة احتياطية.
- `trips_scrubber_noRating`: لا توجد مدة مقدّرة لهذا الجهاز؛ أضف مدة المنظّف إلى سماته أو جدول إعادة تعبئة.
- `trips_scrubber_bannerMargin`: {minutes} دقيقة هامش المنظّف
- `trips_scrubber_bannerCount`: {count} أجهزة، أدنى هامش منظّف {minutes} دقيقة

### he

- `preDive_runner_conditionFindings`: ממצאי מצב
- `statistics_equipment_exposure_title`: חשיפה
- `statistics_equipment_exposure_subtitle`: סיכומים לכל פריט לפי הספים שלך
- `statistics_equipment_exposure_empty`: אין עדיין צלילות עם ציוד
- `statistics_equipment_findings_title`: ממצאי מצב
- `statistics_equipment_findings_subtitle`: ממצאים פתוחים לפי כלל
- `statistics_equipment_findings_empty`: אין ממצאים פתוחים
- `statistics_equipment_issues_title`: תקלות שדווחו
- `statistics_equipment_issues_subtitle`: תגיות הבדיקה הנפוצות ביותר
- `statistics_equipment_issues_empty`: לא דווחו תקלות
- `statistics_equipment_countLabel_items`: פריטים
- `statistics_equipment_countLabel_findings`: ממצאים
- `statistics_equipment_countLabel_reports`: דיווחים
- `statistics_equipment_exposureUnit_hours`: שעות
- `statistics_equipment_exposureUnit_saltHours`: שעות במים מלוחים
- `statistics_equipment_exposureUnit_coldDives`: צלילות קרות
- `statistics_equipment_exposureUnit_o2Hours`: שעות ב-O2 גבוה
- `statistics_equipment_exposureUnit_deepCycles`: צלילות עמוקות
- `statistics_equipment_exposureUnit_cycles`: מחזורי סוללה
- `trips_edit_sectionTitle_planning`: תכנון
- `trips_edit_label_expectedDives`: צלילות צפויות
- `trips_edit_hint_expectedDives`: השאר ריק כדי להעריך מהטיולים האחרונים שלך
- `trips_edit_label_expectedRuntime`: זמן ריצה צפוי לכל צלילה (דקות)
- `trips_edit_hint_expectedRuntime`: השאר ריק כדי להעריך מצלילות ה-CCR האחרונות שלך
- `trips_scrubber_title`: מרווח הסופג
- `trips_scrubber_asOfStart`: נכון ל-{date}
- `trips_scrubber_remaining`: {minutes} דק' נותרו לפני הטיול (נקוב {rated} דק', {consumed} דק' נוצלו מאז המילוי האחרון)
- `trips_scrubber_expectedDives`: {dives} צלילות צפויות
- `trips_scrubber_fromTrips`: (לפי {n} הטיולים האחרונים שלך)
- `trips_scrubber_fromOverride`: (הוגדר בטיול זה)
- `trips_scrubber_perDive`: {minutes} דק' לכל צלילה
- `trips_scrubber_fromDives`: (לפי {n} צלילות ה-CCR האחרונות שלך)
- `trips_scrubber_expectedUse`: {minutes} דק' שימוש צפוי
- `trips_scrubber_margin`: {minutes} דק' מרווח אחרי הטיול
- `trips_scrubber_caution`: מתחת ל-20 אחוז מהמשך הנקוב. תכננו מילוי או קחו סופג רזרבי.
- `trips_scrubber_noRating`: אין משך נקוב לריברידר זה; הוסיפו את משך הסופג למאפיינים או לוח זמנים למילוי.
- `trips_scrubber_bannerMargin`: {minutes} דק' מרווח סופג
- `trips_scrubber_bannerCount`: {count} ריברידרים, מרווח הסופג הנמוך ביותר {minutes} דק'

### zh

- `preDive_runner_conditionFindings`: 状态发现
- `statistics_equipment_exposure_title`: 使用暴露
- `statistics_equipment_exposure_subtitle`: 按您的阈值统计每件装备的总量
- `statistics_equipment_exposure_empty`: 尚无使用装备的潜水
- `statistics_equipment_findings_title`: 状态发现
- `statistics_equipment_findings_subtitle`: 按规则统计的未处理发现
- `statistics_equipment_findings_empty`: 没有未处理的发现
- `statistics_equipment_issues_title`: 已报告的问题
- `statistics_equipment_issues_subtitle`: 最常见的检查标签
- `statistics_equipment_issues_empty`: 未报告问题
- `statistics_equipment_countLabel_items`: 件
- `statistics_equipment_countLabel_findings`: 项
- `statistics_equipment_countLabel_reports`: 条
- `statistics_equipment_exposureUnit_hours`: 小时
- `statistics_equipment_exposureUnit_saltHours`: 盐水小时
- `statistics_equipment_exposureUnit_coldDives`: 冷水潜水
- `statistics_equipment_exposureUnit_o2Hours`: 高氧小时
- `statistics_equipment_exposureUnit_deepCycles`: 深潜
- `statistics_equipment_exposureUnit_cycles`: 电池循环
- `trips_edit_sectionTitle_planning`: 计划
- `trips_edit_label_expectedDives`: 预计潜水次数
- `trips_edit_hint_expectedDives`: 留空则根据近期行程估算
- `trips_edit_label_expectedRuntime`: 每次潜水预计运行时间（分钟）
- `trips_edit_hint_expectedRuntime`: 留空则根据近期 CCR 潜水估算
- `trips_scrubber_title`: 吸收剂余量
- `trips_scrubber_asOfStart`: 截至 {date}
- `trips_scrubber_remaining`: 行程前剩余 {minutes} 分钟（额定 {rated} 分钟，自上次更换以来已使用 {consumed} 分钟）
- `trips_scrubber_expectedDives`: 预计 {dives} 次潜水
- `trips_scrubber_fromTrips`: （根据您最近 {n} 次行程）
- `trips_scrubber_fromOverride`: （在本行程中设置）
- `trips_scrubber_perDive`: 每次潜水 {minutes} 分钟
- `trips_scrubber_fromDives`: （根据您最近 {n} 次 CCR 潜水）
- `trips_scrubber_expectedUse`: 预计使用 {minutes} 分钟
- `trips_scrubber_margin`: 行程后余量 {minutes} 分钟
- `trips_scrubber_caution`: 低于额定时长的 20%。请安排更换或携带备用吸收剂。
- `trips_scrubber_noRating`: 此呼吸器没有额定时长；请在属性中添加吸收剂时长或添加更换计划。
- `trips_scrubber_bannerMargin`: 吸收剂余量 {minutes} 分钟
- `trips_scrubber_bannerCount`: {count} 台呼吸器，最低吸收剂余量 {minutes} 分钟

