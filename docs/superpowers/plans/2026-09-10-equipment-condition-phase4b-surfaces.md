# Equipment Condition Intelligence, Phase 4b: Badges, Trip Margin, Pre-Dive, Statistics

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the condition findings and exposure totals to the rest of the app: the equipment list badges, a scrubber margin card and banner line on trips (with the two trip edit override fields), the pre-dive runner's gear warning, and three ranking cards on the equipment statistics page. This closes the program.

**Architecture:** Every surface reads what earlier phases store or derive; nothing new is persisted except the two trip override columns that v202 already created. Badges come from one `getAllUndismissed` read filtered at display time by the master toggle and the disabled rules. The trip scrubber margin is a pure service over four inputs (rated minutes, consumed since the newest repack, expected dives, minutes per dive) fed by two small repository reads for the history medians; "as of the trip start" is one `before` parameter threaded through every read, so a past trip shows the estimate the diver had when they left. The pre-dive tile appends significant findings to the warning block it already draws for overdue clocks. The statistics page reuses `StatSectionCard` and `RankingList`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (Surfaces: Elsewhere, Trip scrubber margin; Testing). Stacked on phase 4a (#1724).

**Decisions (asked and answered 2026-09-10):** one PR for all of 4b; pre-dive shows significant findings in the same warning block as the overdue clocks, after them, as short rule labels; statistics uses ranking cards reusing the existing ranking widget; the scrubber margin card appears on every trip including past ones, computed as of the trip start; badges raise on caution and significant only (caution shares the due-soon colour, significant the overdue colour), read in one query.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings, this plan).
- No mention of Claude, Claude Code or Anthropic in any commit, comment, file or PR body.
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

Filled in at Task 7 from the ARB files, like the phase 4a plan.
