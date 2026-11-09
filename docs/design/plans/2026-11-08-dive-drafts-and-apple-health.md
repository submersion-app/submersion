# Dive Drafts and Apple Health Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drafts made at the dive site (GPS log buttons and lock screen
actions) that a dive computer download or an Apple Health workout fills
later, automatic Apple Health import, and heart rate, recovery and sleep from
Apple Health on any dive.

**Architecture:** A new `is_draft` flag on `dives` marks a dive with times
and positions but no readings. The flag stays separate from `is_planned`,
because the app reads `is_planned = 0` as "this dive happened" and a draft
did; but plans and drafts share the code around them. Both are "unfilled
dives": one SQL helper (`diveUnfilledSql`) keeps them out of numbering and
matching, one matcher (`FillTargetMatcher`) pairs a download with either,
one review-step pass and one match field (`DiveMatchResult.fillTarget`)
carry the pairing, one chip (`UnfilledDiveChip`) marks them in the list, and
one fill path (`PlannedDiveFillService`, `DuplicateAction.fillPlanned`)
fills them. A new Health classifier routes each Apple Health workout to fill
a draft, consolidate into a logged dive, import as new, or wait for review.
Heart rate, recovery and sleep live in a new synced per-dive table
`dive_health_records`, modelled on `tide_records`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, `health` 13.3.2,
`flutter_local_notifications` 22.3.0, geolocator 14.

**Spec:** `docs/design/specs/2026-11-08-dive-drafts-and-apple-health-design.md`

## Global Constraints

- Schema rung v347 in `lib/core/database/migrations/ladder/rungs_v340_onward.dart`; append 347 to `AppDatabase.migrationVersions` and set `currentSchemaVersion = 347`; do not raise `minimumCompatibleSchemaVersion` (336). Renumber if main moves first.
- New tables go in a new library `lib/core/database/tables/dive_health_tables.dart`, never in `database.dart`; each table library stays under 800 lines.
- Dive times are wall clock stored as UTC: build tap times with `asWallClockUtc(DateTime.now())` (`lib/core/util/wall_clock_utc.dart:65`); GPS points are wall-clock-as-UTC seconds.
- A draft stores `entryTime`, `exitTime`, `entryLocation`, `exitLocation` and leaves `runtime`, `bottomTime`, `maxDepth` null, so its estimated length reaches no total, SAC, gear hours or CNS/OTU.
- Drafts: not in totals or statistics, no dive number until filled, counted for no-fly (as a deco dive) and surface interval.
- A dive is never both planned and a draft. Saving one with both flags keeps the draft and clears `is_planned` (it happened), and `diveUndivedSql` counts a row that still reaches both (two devices' edits merged by sync) as dived, so the failure is always the safe one.
- Shared vocabulary: an "unfilled dive" is a plan or a draft; the dive a download fills is its "fill target". New code uses these names; `DuplicateAction.fillPlanned` and `PlannedDiveFillService` keep theirs (the enum name is pinned by `duplicate_action_test.dart`) and their docs say they cover both kinds.
- Every Health feature is iOS only; drafts and lock screen actions are Android and iOS.
- Health switches are device-local SharedPreferences, bound to the diver who turned them on; nothing from Health is written to another diver's dives.
- The first readings to reach a dive stay its main profile; merges never change the primary.
- Every user-visible string goes in `lib/l10n/arb/app_en.arb` and is translated into all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh) in Task 27.
- Units follow the active diver's settings (`UnitFormatter`).
- Paths in code and tests use `p.join`; tests restore any process-wide state they replace.
- No em dashes in code, comments, strings or docs. No emojis.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests; after adding any `lib/` file also run `flutter test test/architecture/ test/shared/`.

## Review Focus

1. **A dive across midnight.** "Entered water" at 23:50, "Surfaced" at 00:40: plan adoption, pairing and the reminder use the entry's wall-clock day. Test in Task 7 (`adoptsPlanFromEntryDay`) and Task 11 (`pairsAcrossMidnight`).
2. **Back-to-back dives with a short surface interval.** Two drafts both within the clock-drift tolerance of one download: nothing is defaulted. Test in Task 11 (`twoCandidatesIsAmbiguous`).
3. **Diver switched mid-dive.** "Surfaced" closes the open draft of the diver who entered, not the newly active diver. Test in Task 7 (`surfacedClosesDraftOfItsOwnDiver`).
4. **No GPS fix at the tap** (recording just started). The draft is created without a position and the existing GPS sweep fills it from the track later. Test in Task 7 (`entryWithoutFixLeavesPositionEmpty`) and Task 8 (sweep picks it up).
5. **The bound diver is deleted.** Health auto-import and metrics turn themselves off and import nothing. Test in Task 15 (`deletedBoundDiverDisablesHealth`).

---

## Phase A: The draft state

### Task 1: `is_draft` column, entity and guard registrations

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart:178-180` (add after `isPlanned`)
- Modify: `lib/core/database/migrations/helpers/dive_migrations.dart` (helper next to `_assertDiveGasSwitchesEditedColumn`, :653)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v347)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart:49` (backstop)
- Modify: `lib/core/database/database.dart:316, :475` (version 347)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field, ctor, copyWith, props)
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart` (field, ctor, fromDive, copyWith, props)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive :2348, updateDive :2678, summary SELECTs :3286 and :4201, `_mapSummaryRows` :4317, `_mapRowToDiveWithPreloadedData` :5159, `_mapRowToDive` :5620)
- Modify guard registries: `lib/features/dive_log/data/services/dive_consolidation_field_fill.dart` (unfilled, `_Holds.flag`, cleared when filled like `is_planned` :221), `lib/features/dive_log/domain/services/dive_mirror_fields.dart` (`kUnmirroredDiveFields`), `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart` (`kMeasuredDiveFields`, lifecycle), `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart` (ConflictField + `settings_conflict_field_isDraft`), `lib/features/dive_log/presentation/pages/dive_edit_page.dart` save literal (`isDraft: _isDraft`, loaded from the dive)
- Regenerate: `dart run tool/generate_sql_column_notes.dart`, `dart run build_runner build --delete-conflicting-outputs` (run in the background, unfiltered)
- Test: `test/core/database/migration_v347_dive_is_draft_test.dart` (pattern: `migration_v333_dive_gas_switches_edited_test.dart`)

**Interfaces:**
- Produces: `dives.is_draft INTEGER NOT NULL DEFAULT 0`; `Dive.isDraft` (bool, default false); `DiveSummary.isDraft`; Drift `BoolColumn get isDraft => boolean().withDefault(const Constant(false))()`.

- [ ] **Step 1: Write the failing migration test** `migration_v347_dive_is_draft_test.dart`: a v346 database upgraded to 347 has column `is_draft` with default 0 on an existing row; a fresh database has it too.
- [ ] **Step 2: Run it.** `flutter test test/core/database/migration_v347_dive_is_draft_test.dart`. Expected: FAIL (no column).
- [ ] **Step 3: Add the column, rung, backstop, version and helper** `Future<void> _assertDiveIsDraftColumn() => _addColumnIfMissing('dives', 'is_draft', 'INTEGER NOT NULL DEFAULT 0');` Rung comment: "v347: dives.is_draft, a dive marked at the site that waits for its readings (issue #637). Defaulted, no backfill."
- [ ] **Step 4: Add `isDraft` to `Dive`, `DiveSummary`, every mapper and the guard registries listed above**, then regenerate.
- [ ] **Step 5: Run** the migration test plus the guard tests: `flutter test test/core/database/ test/features/dive_log/data/services/dive_consolidation_field_fill_test.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/settings/presentation/conflicts/ test/features/agent_access/data/resources/schema_resource_test.dart`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(dive-log): add the draft flag to dives`.

### Task 2: Drafts in totals, numbering, matching and no-fly

**Files:**
- Modify: `lib/core/database/dive_stats_scope.dart:76-81` (add `'$alias.is_draft = 0'`)
- Modify: `lib/features/dive_log/data/repositories/dive_times_sql.dart` (new `diveUnfilledSql` beside `diveUndivedSql` :155; `diveUndivedSql` gains `AND $alias.is_draft = 0`; `diveMatchCandidatesSql` :215 uses `NOT diveUnfilledSql`; `latestEndedDiveSql` :306 keeps drafts: they happened)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`createDive` :2348 and `updateDive` :2678 write `is_planned = isPlanned && !isDraft`; `getNoFlyDiveInputs` :6407; `_renumberAllDivesInner` :7232 and `getDiveNumberingInfo` :7137 use `diveUnfilledSql`; `getNextDive` :6628 keeps drafts)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart:653, :1306` (skip `assignMissingDiveNumbers` for any unfilled dive: `dive.isPlanned || dive.isDraft`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:3070` (`countLogbookDives` uses `NOT diveUnfilledSql`)
- Test: `test/core/database/dive_stats_scope_test.dart` (update pinned strings), `test/features/dive_log/data/repositories/dive_drafts_queries_test.dart`

**Interfaces:**
- Consumes: `dives.is_draft` (Task 1).
- Produces: `String diveUnfilledSql(String alias)` returning `'($alias.is_planned = 1 OR $alias.is_draft = 1)'`, the one place "plan or draft" is spelled in SQL; `DiveStatsScope.predicate()` now `'d.excluded_from_stats = 0 AND d.is_planned = 0 AND d.is_draft = 0'` (kept as separate parts so its census test still reads each rule).

- [ ] **Step 1: Write failing tests** in `dive_drafts_queries_test.dart`:
  - `draftIsLeftOutOfStatistics`: one logged dive (maxDepth 20) and one draft; `getStatistics()` reports `totalDives == 1`.
  - `draftIsNotRenumbered`: `renumberAllDives()` leaves the draft's `diveNumber` null and numbers the logged dives 1..n.
  - `draftCountsForNoFlyAsDeco`: a closed draft ended 2 h ago gives one `NoFlyDiveInput` with `hadDecoObligation == true` and `endTime` equal to its exit time.
  - `openDraftEndsNow`: a draft with no exit time gives `endTime` within 5 s of now.
  - `draftIsNotAFuzzyMatchCandidate`: `diveMatchCandidatesSql` returns no draft row.
  - `draftCountsForSurfaceInterval`: `getSurfaceIntervals` treats the draft as dived (`is_undived = 0`).
  - `bothFlagsSavesAsDraft`: `createDive` and `updateDive` with `isPlanned: true, isDraft: true` read back `isPlanned == false, isDraft == true`.
  - `bothFlagsRowCountsAsDived`: a row written with both flags by raw SQL (as a sync merge could) still gives a `NoFlyDiveInput` and counts for surface interval.
  - `unfilledSqlMatchesPlansAndDrafts`: `diveUnfilledSql('d')` selects a plan and a draft, not a logged dive.
  - Update `dive_stats_scope_test.dart` expected strings.
- [ ] **Step 2: Run.** `flutter test test/features/dive_log/data/repositories/dive_drafts_queries_test.dart test/core/database/dive_stats_scope_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `getNoFlyDiveInputs`, `had_deco` gains `OR d.is_draft = 1`, and `endMs` uses `CASE WHEN d.is_draft = 1 AND d.exit_time IS NULL THEN ? ELSE <existing> END` bound to now (wall clock UTC millis).
- [ ] **Step 4: Run** the tests above plus `flutter test test/core/database/dive_stats_scope_census_test.dart test/features/safety/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): keep drafts out of totals and in no-fly`.

### Task 3: Draft repository API

**Files:**
- Create: `lib/features/dive_log/data/repositories/dive_draft_repository.dart` (extension or small class over `AppDatabase` + `DiveRepository`, to keep `dive_repository_impl.dart` from growing)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:5784` (`convertPlanToActualDive` delegates to `promoteToLoggedDive`), `:5742` (add `getUnfilledDives` beside `getPlannedDives`)
- Create: `lib/features/dive_log/presentation/providers/dive_draft_providers.dart`
- Test: `test/features/dive_log/data/repositories/dive_draft_repository_test.dart`

**Interfaces:**
- Produces (class `DiveDraftRepository`, provider `diveDraftRepositoryProvider`):
  - `Future<Dive> createDraft({required String diverId, required DateTime entryTime, GeoPoint? entryLocation})`: adopts a plan when `findPlanToAdopt` returns one (sets `isPlanned false, isDraft true`, keeps site, tanks, buddies), else creates a new row.
  - `Future<String?> findPlanToAdopt({required String diverId, required DateTime entryTime})`: unfilled planned dive of that diver whose start (`entryTime ?? dateTime`) is on the same wall-clock day and within 2 h; nearest wins.
  - `Future<void> closeDraft(String diveId, {required DateTime exitTime, GeoPoint? exitLocation})`
  - `Future<Dive?> openDraftFor(String diverId)`: the draft with no exit time, newest entry first.
  - `Future<List<Dive>> getDrafts({String? diverId})`, `Stream<List<DiveSummary>> watchDrafts({String? diverId})`
  - `Future<String> promoteToLoggedDive(String diveId, {DateTime? actualDateTime})`: works for planned or draft; clears both flags; assigns `getNextDiveNumber(diverId)`; marks pending; notifies sync.
  - `Future<void> markDraftComplete(String diveId)`: `promoteToLoggedDive` with no readings.
- Produces on `DiveRepository`: `Future<List<Dive>> getUnfilledDives({String? diverId})`, the plans and drafts a download may fill (`WHERE diveUnfilledSql`), same ordering and diver scoping as `getPlannedDives`. Tasks 12 and 16 read fill targets only through this.
- Produces providers: `draftDivesProvider` (`StreamProvider<List<DiveSummary>>` for the current diver), `openDraftProvider` (`FutureProvider.family<Dive?, String>` by diver id).

- [ ] **Step 1: Write failing tests:** `createsDraftWithEntryAndNoReadings` (isDraft true, diveNumber null, runtime null, maxDepth null); `adoptsPlanWithinTwoHoursSameDay` (plan at 10:00, tap at 11:30 adopts, keeps siteId); `doesNotAdoptPlanOnAnotherDay`; `adoptsNearestOfTwoPlans`; `closeDraftSetsExitAndPosition`; `promoteAssignsNextNumberAndClearsFlag` (existing max 41 gives 42); `promotePlannedStillWorks` (the old `convertPlanToActualDive` tests stay green); `markCompleteKeepsTimes`; `unfilledDivesListsPlansAndDrafts` (a plan and a draft of the diver, not a logged dive, not another diver's draft).
- [ ] **Step 2: Run.** `flutter test test/features/dive_log/data/repositories/dive_draft_repository_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the class and providers above.
- [ ] **Step 4: Run** the new tests and `flutter test test/features/dive_log/data/repositories/ test/features/dive_computer/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add the draft dive repository`.

### Task 4: UDDF round trip

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:299` (`<isdraft>true</isdraft>` beside `isplanned`)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1338`, `lib/features/dive_import/data/services/uddf_entity_importer.dart:2989, :3111`
- Test: `test/core/services/export/uddf/uddf_draft_roundtrip_test.dart` (pattern: `uddf_exclusion_roundtrip_test.dart`)

- [ ] **Step 1: Failing test** `draftFlagSurvivesUddfRoundTrip`: export a draft, import it, `isDraft == true`; a logged dive imports with `isDraft == false`.
- [ ] **Step 2: Run** `flutter test test/core/services/export/uddf/uddf_draft_roundtrip_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the element on export and parse on import.
- [ ] **Step 4: Run** the test and `flutter test test/core/services/export/uddf/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): keep the draft flag in UDDF backups`.

## Phase B: Draft UI

### Task 5: List chip

**Files:**
- Rename: `lib/features/dive_log/presentation/widgets/planned_dive_chip.dart` to `unfilled_dive_chip.dart` (`git mv`), `PlannedDiveChip` becomes `UnfilledDiveChip`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart:676, :795, :851, :1115`, `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart:231, :332, :381` (the `isPlannedDive` locals become `unfilledState`, from `unfilledDiveStateOf`; they drive the chip, the avatar icon and the semantics label)
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart` (expose `exitTime` presence as `bool isOpenDraft` if the summary lacks exit time)
- Test: `test/features/dive_log/presentation/widgets/unfilled_dive_chip_test.dart`; `test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart` stays green with the renamed widget

**Interfaces:**
- Produces: `enum UnfilledDiveState { planned, inWater, awaitingDownload }`; `UnfilledDiveState? unfilledDiveStateOf({required bool isPlanned, required bool isDraft, required bool isOpenDraft})` (null for a logged dive; draft wins if both flags are set); `UnfilledDiveChip({required UnfilledDiveState state})`. Looks: `planned` unchanged (tertiaryContainer, `diveLog_planned_chip`, avatar `Icons.event_available_outlined`); `awaitingDownload` and `inWater` use secondaryContainer and avatar `Icons.hourglass_top_outlined`. Strings `diveLog_draft_chip` ("Waiting for download"), `diveLog_draft_inWaterChip` ("In the water"), semantics `diveLog_listPage_semanticsDraftDiveAtSite` ("Draft dive at {site}", beside the planned one).

- [ ] **Step 1: Failing widget tests:** `plannedLookUnchanged` (text "Planned", tertiaryContainer); `showsWaitingChipForClosedDraft`; `showsInTheWaterForOpenDraft`; `avatarShowsDraftIconNotNumber` (no `#` text, icon `Icons.hourglass_top_outlined`) in both the detailed and compact tiles; `loggedDiveHasNoChip`; `bothFlagsShowsDraft`.
- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/unfilled_dive_chip_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the rename, the state function and the two draft looks, and wire them into both tiles.
- [ ] **Step 4: Run** the test, `dive_list_planned_chip_test.dart` and `flutter test test/features/dive_log/presentation/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show drafts in the dive list`.

### Task 6: Detail banner and menu

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/draft_dive_banner.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:451-457`, `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart:137`, `lib/features/dive_log/presentation/widgets/dive_detail_overflow_menu.dart:124`, `lib/features/dive_log/presentation/pages/dive_detail_page_actions.dart:162` (add `_markDraftComplete`, invalidating the same providers as `_markAsLogged`), `lib/features/dive_log/presentation/pages/dive_edit_page.dart:1336` (hide the "Planned" switch while editing a draft, so the editor cannot set both flags)
- Test: `test/features/dive_log/presentation/widgets/draft_dive_banner_test.dart`, `test/features/dive_log/presentation/pages/dive_edit_page_draft_test.dart`

**Interfaces:**
- Consumes: `DiveDraftRepository.markDraftComplete`, `closeDraft` (Task 3); `downloadTargetComputerProvider` (Task 24) for "Download now" (until Task 24 lands, route to `/dive-computers`).
- Produces: `DraftDiveBanner({required Dive dive, required VoidCallback onMarkComplete, required VoidCallback onDownload, VoidCallback? onSurfaced})`. Body text shows the estimated length: `diveLog_draft_bannerBody` with `{minutes}` from `exitTime - entryTime` ("About {minutes} min from your taps. Download your dive computer to fill in depth and time.").

- [ ] **Step 1: Failing tests:** `bannerShowsEstimatedMinutes` (entry 10:00, exit 10:52 shows "About 52 min"); `openDraftOffersSurfaced`; `markCompleteCallsRepository`; `menuShowsMarkCompleteOnlyForDrafts`; `editPageHidesPlannedSwitchForDraft` (and a draft saved from the editor keeps `isDraft == true`).
- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/draft_dive_banner_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the banner, menu item and action.
- [ ] **Step 4: Run** the test and `flutter test test/features/dive_log/presentation/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show a draft's banner on its detail page`.

## Phase C: Making drafts on the phone

### Task 7: Dive mark service

**Files:**
- Create: `lib/features/gps_log/data/services/dive_mark_service.dart`
- Modify: `lib/features/gps_log/data/services/gps_track_recorder.dart` (public getter `GpsTrackPoint? get lastPoint`, from the last accepted fix)
- Modify: `lib/features/gps_log/presentation/providers/gps_log_providers.dart` (`diveMarkServiceProvider`)
- Test: `test/features/gps_log/data/services/dive_mark_service_test.dart`

**Interfaces:**
- Consumes: `GpsTrackRecorder.state.trackId`, `GpsTrackRepository.getBufferPoints(trackId)`, `GpsTrackMatcher.positionAt(points, wallClockSeconds)`, `DiveDraftRepository` (Task 3), `currentDiverIdProvider`.
- Produces: `class DiveMarkService { Future<Dive> enteredWater({required String diverId, DateTime? at}); Future<Dive?> surfaced({DateTime? at}); }`. `surfaced` closes the newest open draft across divers whose `diverId` matches the draft that `enteredWater` created this session (stored in the service), falling back to the open draft of the current diver. Times default to `asWallClockUtc(DateTime.now())`.

- [ ] **Step 1: Failing tests:** `enteredWaterCreatesDraftAtTrackPosition` (buffer point at the tap second gives `entryLocation`); `entryWithoutFixLeavesPositionEmpty`; `surfacedClosesOpenDraft`; `surfacedClosesDraftOfItsOwnDiver` (enter as diver A, switch to B, surfaced closes A's draft); `secondEnteredWaterWhileOpenIsIgnored` (returns the open draft, no second row); `adoptsPlanFromEntryDay` (entry at 23:50 adopts a plan at 22:30 that day, not one at 00:30 next day).
- [ ] **Step 2: Run** `flutter test test/features/gps_log/data/services/dive_mark_service_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test and `flutter test test/features/gps_log/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(gps-log): mark water entry and surfacing as draft dives`.

### Task 8: Buttons on the recording card and strip

**Files:**
- Modify: `lib/features/gps_log/presentation/widgets/gps_record_card.dart` (recording branch between :90 and :92; idle state gains "Entered water", which runs `_start` then `enteredWater`)
- Modify: `lib/features/gps_log/presentation/widgets/gps_recording_strip.dart:50` (one compact button: "Entered water" or "Surfaced"; the button must not trigger the strip's `InkWell`)
- Create: `lib/features/gps_log/presentation/widgets/dive_mark_buttons.dart`, `lib/features/gps_log/presentation/widgets/surface_on_stop_dialog.dart`
- Test: `test/features/gps_log/presentation/widgets/dive_mark_buttons_test.dart`, `test/features/gps_log/presentation/widgets/gps_record_card_draft_test.dart`

**Interfaces:**
- Consumes: `diveMarkServiceProvider` (Task 7), `openDraftProvider` (Task 3).
- Produces: `DiveMarkButtons({bool compact = false})`; `Future<bool?> showSurfaceOnStopDialog(BuildContext, {required DateTime entryTime})` (true = mark surfaced now, false = leave open, null = cancel stop). Strings `gpsLogger_enteredWater`, `gpsLogger_surfaced`, `gpsLogger_surfaceOnStop_title/body/surfaceNow/leaveOpen`.

- [ ] **Step 1: Failing widget tests:** `showsEnteredWaterWhenNoOpenDraft`; `showsSurfacedWhenDraftOpen`; `stripButtonDoesNotNavigate`; `stopWithOpenDraftAsks` (dialog shown; "Surface now" closes the draft then stops); `stopWithoutOpenDraftDoesNotAsk`; `sweepFillsDraftWithoutFix` (a draft with no entry GPS gets one from the finalized track through the existing `GpsTrackMatchService.sweep`).
- [ ] **Step 2: Run** both test files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/gps_log/ test/features/tracks/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(gps-log): add water entry and surfacing buttons while recording`.

### Task 9: Lock screen action buttons

**Files:**
- Modify: `lib/core/services/notification_service.dart` (Darwin category `diveMark` with actions `enteredWater`, `surfaced`; Android channel `dive_marks`; `onDidReceiveBackgroundNotificationResponse` top-level handler; response routing by `actionId`)
- Create: `lib/core/services/dive_mark_actions.dart` (pure mapping + a broadcast stream the app listens to)
- Modify: `lib/features/gps_log/presentation/providers/gps_log_providers.dart` (show the action notification while recording, update its body when a draft opens or closes, cancel on stop)
- Modify: `lib/app.dart` (subscribe to the action stream and call `DiveMarkService`; on launch, read `getNotificationAppLaunchDetails` for an action that started the app)
- Modify: `android/app/src/main/AndroidManifest.xml` (`ActionBroadcastReceiver` for flutter_local_notifications actions)
- Test: `test/core/services/dive_mark_actions_test.dart`

**Interfaces:**
- Produces: `enum DiveMarkAction { enteredWater, surfaced }`; `DiveMarkAction? diveMarkActionFor(String? actionId)`; `Stream<({DiveMarkAction action, DateTime at})> diveMarkActions`; `NotificationService.showDiveMarkActions({required bool draftOpen, required String title, required String body})`; `NotificationService.cancelDiveMarkActions()`. The tap time is captured in the handler (`asWallClockUtc(DateTime.now())`), not when the app later processes it.

- [ ] **Step 1: Spike on a device first** (spec goal 2): on iOS, confirm a non-foreground action reaches the running app while the GPS recording keeps it alive in the background; on Android, confirm the action broadcast reaches the app. If iOS cannot deliver it, use `DarwinNotificationActionOption.foreground` (opens the app, then records). Note the outcome in the PR description.
- [ ] **Step 2: Failing tests:** `mapsActionIds` (`'enteredWater'` and `'surfaced'` map, anything else is null); `tapTimeIsCapturedAtResponse` (a response handled at T emits `at == T` even if the listener subscribes later); `notificationShowsOnlyTheNextAction` (open draft shows "Surfaced" only).
- [ ] **Step 3: Run** `flutter test test/core/services/dive_mark_actions_test.dart`. Expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the test and `flutter test test/core/services/ test/features/notifications/`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(gps-log): mark water entry and surfacing from the lock screen`.

### Task 10: Ask about a draft left open

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/stale_open_draft_prompt.dart`
- Modify: `lib/app.dart` (post-frame launch and resume: if the current diver's open draft is older than 6 h, show the prompt once per draft per app session)
- Test: `test/features/dive_log/presentation/widgets/stale_open_draft_prompt_test.dart`

**Interfaces:**
- Consumes: `openDraftFor`, `closeDraft` (Task 3).
- Produces: `bool isStaleOpenDraft(Dive draft, DateTime now)` (open and `now - entryTime >= 6 h`); `Future<void> showStaleOpenDraftPrompt(BuildContext, Dive draft)` with a time picker defaulting to entry + 1 h.

- [ ] **Step 1: Failing tests:** `staleAfterSixHours` (5 h 59 min false, 6 h true, closed draft false); `promptClosesWithPickedTime`; `promptNotShownTwiceInOneSession`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): ask when a draft has been open for six hours`.

## Phase D: The cable download fills drafts

### Task 11: One matcher for plans and drafts

**Files:**
- Rename: `lib/features/dive_computer/domain/services/planned_dive_matcher.dart` to `fill_target_matcher.dart` (`git mv`), `PlannedDiveMatcher` becomes `FillTargetMatcher`
- Rename: `test/features/dive_computer/domain/services/planned_dive_matcher_test.dart` to `fill_target_matcher_test.dart` (`git mv`); its existing cases keep their expectations, with the new call shape

**Interfaces:**
- Produces: `class FillTargetMatcher { const FillTargetMatcher({Duration draftTolerance = const Duration(minutes: 10)}); FillPairing match({required List<({DateTime start, DateTime end})> incoming, required List<Dive> targets}); Map<int, String> pair({...same}) => match(...).pairs; }` and `class FillPairing { final Map<int, String> pairs; final Map<int, List<String>> ambiguous; }` (`ambiguous` maps a download index to the draft ids it fitted, so a caller can say "two candidates" instead of "no match"; the review step reads only `pairs`, Task 16 reads both). `targets` holds plans and drafts together (from `getUnfilledDives`); each keeps its own rule:
  - **Drafts first.** A download fits a draft when `[start, end]` overlaps `[entryTime - draftTolerance, (exitTime ?? entryTime + 3 h) + draftTolerance]`. A download with two or more fitting drafts, or a draft with two or more fitting downloads, is left out (ambiguous), and an ambiguous download is not offered to plans either: it belongs to one of those drafts.
  - **Then plans,** for the downloads no draft fitted: today's rule unchanged (same wall-clock day or the day before, smallest start gap first, each download and each plan once, ties to the earlier download then the earlier plan).
  - A target with both flags is treated as a draft. Times are wall clock.

- [ ] **Step 1: Failing tests:** `pairsOverlappingDownload`; `pairsWithinClockDrift` (download starts 8 min before the tap); `rejectsOutsideTolerance` (12 min gap); `twoCandidatesIsAmbiguous` (two drafts 15 min apart, one download overlapping both windows); `pairsAcrossMidnight` (draft 23:50 to 00:40, download 23:52 to 00:38); `openDraftUsesThreeHourWindow`; `draftBeatsPlan` (a download fitting today's draft and yesterday's plan fills the draft; the plan stays unfilled); `ambiguousDownloadIsNotOfferedToPlans` (and `match().ambiguous` lists both draft ids); `plansAndDraftsInOneBatch` (two downloads, one draft, one plan on another dive's time: each gets its own target). The moved planned cases stay green.
- [ ] **Step 2: Run** `flutter test test/features/dive_computer/domain/services/fill_target_matcher_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the rename and the draft rule ahead of the existing plan rule.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): pair downloads with plans and drafts in one matcher`.

### Task 12: Fill drafts from a download

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:746-775` (the planned pass becomes the fill pass: same place, after the fingerprint, fuzzy and contained passes; reads `getUnfilledDives`, pairs with `FillTargetMatcher`, passes each download's start and end), `:908-943` (the apply step reads `fillTarget`)
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart:136-185` (`plannedDiveId` becomes `FillTarget? fillTarget`; `isPlannedFill` becomes `isFill`; `withPlannedDive` becomes `withFillTarget`)
- Modify: `lib/features/dive_computer/data/services/planned_dive_fill_service.dart:63` (accept any unfilled dive, `isPlanned || isDraft`; parameter `plannedDiveId` becomes `targetDiveId`; promote through `promoteToLoggedDive`; never overwrite the dives-row entry/exit GPS when the draft has them), `lib/features/dive_computer/data/services/dive_import_service.dart:1036-1106` (same parameter rename)
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart:262-270` (`plannedFillCandidatesProvider` becomes `fillCandidatesProvider`, reading `getUnfilledDives`), `:511`, `:898-926` (`setPlannedFillTarget` becomes `setFillTarget`)
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart:505-545` (the picker lists plans and drafts; `plannedDiveLabel` labels a draft by its tap times), `duplicate_action_card.dart:172, :280` and `lib/core/presentation/widgets/dive_comparison_card.dart:587` (wording "Fill draft" when `fillTarget.kind == FillTargetKind.draft`, today's wording otherwise)
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_draft_fill_test.dart`, `test/features/dive_computer/data/services/planned_dive_fill_service_draft_test.dart`; every existing planned-fill test (adapter, wizard providers, review step, duplicate card, fill service) stays green after the renames

**Interfaces:**
- Consumes: `FillTargetMatcher` (Task 11), `DiveRepository.getUnfilledDives`, `DiveDraftRepository.promoteToLoggedDive` (Task 3).
- Produces: `enum FillTargetKind { plan, draft }`; `class FillTarget { const FillTarget({required String diveId, required FillTargetKind kind}); factory FillTarget.of(Dive dive); }` (in `dive_matcher.dart`, `==` and `hashCode` by both fields; `of` reads the dive's flags, draft winning); `DiveMatchResult({..., FillTarget? fillTarget})`, `bool get isFill`, `DiveMatchResult withFillTarget(FillTarget target)`; `ImportWizardNotifier.setFillTarget(int index, FillTarget? target)`; `fillCandidatesProvider`. There is one fill pass and one field: no separate draft flag on the match. Strings `universalImport_fillDraft` ("Fill draft"), `universalImport_fillDraft_label` ("Draft, {start} to {end}"; open draft "Draft, from {start}").

- [ ] **Step 1: Failing tests:** `downloadDefaultsToFillDraft` (`duplicateActions[index] == DuplicateAction.fillPlanned`, `fillTarget.kind == FillTargetKind.draft`); `downloadStillDefaultsToFillPlan` (`fillTarget.kind == FillTargetKind.plan`, as before); `pickerListsPlansAndDrafts`; `fillKeepsTypedFieldsAndTapPositions` (notes, buddy, siteId, entryLocation unchanged; maxDepth, runtime from the download); `fillMakesDownloadPrimaryAndAssignsNumber`; `fillClearsDraftFlag`; `ambiguousDraftsStayPending`; `realDuplicateNeverBecomesDraftFill` (a re-download of an already logged dive is still skipped); `undoRestoresDraft`.
- [ ] **Step 2: Run** both test files. Expected: FAIL.
- [ ] **Step 3: Implement** the renames first (analyzer clean, existing tests green), then the draft kind.
- [ ] **Step 4: Run** the tests and `flutter test test/features/import_wizard/ test/features/dive_computer/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): fill drafts from a dive computer download`.

### Task 13: A download joining a watch dive keeps the watch as main

**Files:**
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_watch_consolidate_test.dart`
- Modify only if a test fails: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart:519`

**Interfaces:**
- Consumes: watch dives carrying the Apple Watch `computerId` (Task 14).

- [ ] **Step 1: Failing tests:** `downloadOntoWatchDiveDefaultsToConsolidate` (existing dive attributed to the Apple Watch computer, overlap score at least 0.85); `watchProfileStaysPrimary` (after consolidation the primary series is the watch's, the download is non-primary); `oldWatchDiveWithoutComputerStaysPending`.
- [ ] **Step 2: Run.** Expected: FAIL until Task 14 lands (write this task's tests now, run them again after Task 14).
- [ ] **Step 3: Implement** any gap the tests show.
- [ ] **Step 4: Run** `flutter test test/features/import_wizard/`. Expected: PASS.
- [ ] **Step 5: Commit** `test(import-wizard): pin the first readings as a merged dive's main profile`.

## Phase E: Apple Health import

### Task 14: The Apple Watch computer and stable dive ids

**Files:**
- Create: `lib/features/dive_import/data/services/apple_watch_computer.dart`
- Modify: `lib/features/dive_import/domain/services/imported_dive_converter.dart:42` (id = `Uuid().v5(Namespace.url.value, 'submersion:applehealth:<diverId>:<workoutUuid>')` when the source is Apple Watch and a diver id is given)
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (`performImport` attributes the computer: `attributeDiveToComputer`)
- Test: `test/features/dive_import/data/services/apple_watch_computer_test.dart`, `test/features/dive_import/domain/services/imported_dive_converter_id_test.dart`

**Interfaces:**
- Consumes: `DiveComputerRepository.findOrRegisterImportedComputer(model: 'Apple Watch', manufacturer: 'Apple', diverId:)`.
- Produces: `Future<DiveComputer> appleWatchComputerFor(DiveComputerRepository repo, String diverId)`; `String healthDiveId({required String diverId, required String workoutUuid})`.

- [ ] **Step 1: Failing tests:** `sameDiverGetsOneWatchComputer` (two calls return the same id); `idIsStablePerWorkoutAndDiver` (same inputs same id, other diver other id); `wizardImportAttributesWatch` (imported dive `computerId` equals the watch computer's id).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `flutter test test/features/dive_import/ test/features/import_wizard/`, and Task 13's tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): record Apple Watch dives under their own computer`.

### Task 15: Apple Health settings, bound to a diver

**Files:**
- Create: `lib/features/dive_import/presentation/providers/health_settings_providers.dart`
- Create: `lib/features/settings/presentation/widgets/apple_health_settings_section.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:1878-2000` (mount the section in the Apple Health card, iOS only)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:74` (`SettingsKeys.healthAutoImportDiver = 'health_auto_import_diver'`, `healthMetricsDiver = 'health_metrics_diver'`, `healthImportWatermark = 'health_import_watermark_ms'`)
- Modify: `lib/core/providers/root_overrides.dart:84` (override with prefs)
- Modify: `lib/features/dive_import/data/services/healthkit_service.dart:141` (`requestMetricsPermissions()`: HEART_RATE, HEART_RATE_VARIABILITY_SDNN, SLEEP_ASLEEP)
- Test: `test/features/dive_import/presentation/providers/health_settings_providers_test.dart`, `test/features/settings/presentation/widgets/apple_health_settings_section_test.dart`

**Interfaces:**
- Produces: `class HealthSettings { final String? autoImportDiverId; final String? metricsDiverId; }`; `HealthSettingsNotifier` with `Future<void> enableAutoImport(String diverId)`, `disableAutoImport()`, `enableMetrics(String diverId)`, `disableMetrics()`; `healthSettingsProvider`. A bound diver id that no longer exists reads as off and is cleared.
- Strings: `settings_appleHealth_autoImport_title/subtitle`, `settings_appleHealth_metrics_title/subtitle`, `settings_appleHealth_boundDiver` ("For: {name}").

- [ ] **Step 1: Failing tests:** `enableBindsCurrentDiver`; `switchingDiverKeepsBinding`; `deletedBoundDiverDisablesHealth`; `sectionHiddenOffIOS`; `turningOnRequestsPermission` (fake `HealthImportService.requestPermissions` called; denied leaves the switch off).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/settings/ test/features/dive_import/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): add Apple Health switches bound to one diver`.

### Task 16: Health workout classifier

**Files:**
- Create: `lib/features/dive_import/domain/services/health_dive_classifier.dart`
- Test: `test/features/dive_import/domain/services/health_dive_classifier_test.dart`

**Interfaces:**
- Produces: `sealed class HealthDiveRoute` with `FillDraft(String diveId)`, `FillPlan(String diveId)`, `Consolidate(String diveId)`, `ImportNew()`, `NeedsReview(List<String> candidateIds)`; `List<HealthDiveRoute> classifyHealthDives(List<ImportedDive> workouts, {required List<Dive> unfilled, required List<Dive> loggedNear, DiveMatcher matcher = const DiveMatcher()})`, one route per workout in order. It works on the whole batch so several workouts on one day pair with plans the way a download batch does. Three passes, each taking only the workouts the one before left:
  1. **Drafts:** `FillTargetMatcher.match` with the drafts of `unfilled` as targets. A pair is `FillDraft`; an entry in `ambiguous` is `NeedsReview` with those draft ids.
  2. **Logged dives:** `matcher.calculateMatchScore`, at least 0.85 is `Consolidate`, 0.5 up to 0.85 is `NeedsReview`.
  3. **Plans:** `FillTargetMatcher.match` with the plans of `unfilled` as targets (today's same-day-or-day-before rule). A pair is `FillPlan`.
  4. Anything left is `ImportNew`.
  The classifier only names the route; whether a `FillPlan` is written or held is the caller's call (Tasks 17 and 19).

- [ ] **Step 1: Failing tests:** `oneDraftFills`; `twoDraftsNeedReview`; `strongMatchConsolidates`; `weakMatchNeedsReview`; `nothingNearImportsNew`; `draftBeatsLoggedDive` (a draft and a logged dive both fit: fills the draft); `planOnTheDayIsFillPlan`; `loggedDiveBeatsPlan` (a strong logged match and a same-day plan: consolidates, the plan is left); `draftBeatsPlan`; `twoWorkoutsTwoPlansPairNearest` (dives at 09:00 and 14:00, plans at 09:30 and 13:30).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): route each Apple Health dive to fill, merge or import`.

### Task 17: Automatic Apple Health import service

**Files:**
- Create: `lib/features/dive_import/data/services/health_dive_writer.dart` (the per-dive create extracted from `HealthKitAdapter.performImport` :305-422, shared by both paths)
- Create: `lib/features/dive_import/data/services/health_fill_service.dart`
- Create: `lib/features/dive_import/data/services/health_auto_import_service.dart`
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (use `HealthDiveWriter`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.healthReviewAnnounced = 'health_review_announced'`)
- Test: `test/features/dive_import/data/services/health_auto_import_service_test.dart`, `test/features/dive_import/data/services/health_fill_service_test.dart`

**Interfaces:**
- Consumes: Tasks 14 to 16; `DiveRepository.getUnfilledDives` (Task 3); `DiveConsolidationService.apply(targetDiveId:, secondaryDiveIds:)`; `DiveDraftRepository.promoteToLoggedDive`.
- Produces:
  - `HealthDiveWriter.importAsNew(ImportedDive, {required String diverId}) -> Future<String>` (attributes the watch computer).
  - `HealthFillService.fill({required String targetDiveId, required ImportedDive workout, required String computerId}) -> Future<void>` for any unfilled dive, plan or draft: writes the watch series as primary, sets the measured fields in `kMeasuredDiveFields` from the converted dive, keeps typed fields and a draft's tap positions, promotes. On a plan it first removes the planned profile and gas switches, as `PlannedDiveFillService` does (`planned_dive_fill_service.dart:85-86`).
  - `HealthAutoImportService.run({DateTime? now}) -> Future<HealthAutoImportResult>` where `HealthAutoImportResult { List<String> newDiveIds; List<String> filledDraftIds; List<String> consolidatedIds; List<String> reviewWorkoutIds; List<String> planReviewWorkoutIds; }`. Reads workouts from `watermark - 24 h` (or the last 7 days on first run) to now, skips workout UUIDs already imported for the bound diver, routes the batch with `classifyHealthDives`, then sets the watermark to now. Does nothing when `autoImportDiverId` is null or permission is not granted. Consolidation: import as new, then `apply(targetDiveId: existing, secondaryDiveIds: [new])`. **`FillPlan` is never written in the background:** the workout goes to `planReviewWorkoutIds`, nothing is imported, and the plan is untouched, because a plan's day is much weaker evidence than a draft's taps. Each workout held for review (`NeedsReview` or `FillPlan`) is reported once: its UUID goes in the device-local list `health_review_announced`, entries older than 7 days are pruned, and a later run skips reporting it again.
- [ ] **Step 1: Failing tests:** `offDoesNothing`; `importsNewWorkout`; `skipsWorkoutAlreadyImported`; `fillsDraft` (draft keeps notes; profile from the watch is primary; isDraft false; dive number assigned); `consolidatesIntoDownloadedDive` (downloaded profile stays primary); `ambiguousIsReportedNotWritten`; `planFitIsHeldNotWritten` (the plan keeps `isPlanned == true` and its planned profile; no new dive; the workout is in `planReviewWorkoutIds`); `heldWorkoutIsReportedOnce` (a second run inside 24 h reports nothing new); `advancesWatermark`; `wizardStillImportsThroughWriter` (existing `healthkit_adapter` tests stay green); in `health_fill_service_test.dart`: `fillsPlanReplacingPlannedProfile`, `fillsDraftKeepingTapPositions`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/dive_import/ test/features/import_wizard/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): import Apple Watch dives automatically`.

### Task 18: Run it on launch and resume, and tell the diver

**Files:**
- Modify: `lib/app.dart:201-217` (post-frame launch) and `:274-280` (resume): `_runHealthAutoImport()`, throttled to once per 10 minutes
- Modify: `lib/core/services/notification_service.dart:32` (`notificationPayloadRoute`: `dive:<id>` maps to `/dives/<id>`, `healthReview` maps to `/settings/wearable-import`), add `showNewWatchDive({required String diveId, required String title, required String body})` and `showWatchDiveNeedsReview(...)` on channel `watch_dives`
- Create: `lib/features/dive_import/presentation/health_auto_import_feedback.dart` (foreground: SnackBar through the root scaffold messenger with an "Add details" action; background: notification)
- Test: `test/core/services/notification_payload_route_test.dart`, `test/features/dive_import/presentation/health_auto_import_feedback_test.dart`

**Interfaces:**
- Consumes: `HealthAutoImportService.run` (Task 17).
- Strings: `healthAutoImport_newDive_title` ("New dive from your Apple Watch"), `healthAutoImport_newDive_body` ("Add details?"), `healthAutoImport_review_title/body`, `healthAutoImport_planReview_body` ("This dive may be one you planned. Review it to fill the plan."), `healthAutoImport_snackbar`, `healthAutoImport_addDetails`.

- [ ] **Step 1: Failing tests:** `diveAndReviewPayloadsRoute` (and the existing `document:` and equipment payloads still route); `foregroundShowsSnackBar`; `backgroundShowsNotification`; `oneMessageForSeveralDives` ("3 new dives" body, routes to the dive list); `planReviewUsesPlanWording` (a `planReviewWorkoutIds` result shows `healthAutoImport_planReview_body` and routes to the Health import review).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/core/services/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): announce Apple Watch dives imported in the background`.

### Task 19: Fill and merge choices in the Health import wizard

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart:131, :191-302, :305-422` (supported actions add `consolidate` and `fillPlanned`; duplicate check routes the batch through `classifyHealthDives`; `FillDraft` and `FillPlan` rows default to `fillPlanned` with a `FillTarget` of their kind, so the review step's picker from Task 12 works unchanged; apply branch uses `HealthFillService` and the consolidation path from Task 17; planned dives are no longer fuzzy candidates)
- Test: `test/features/import_wizard/data/adapters/healthkit_adapter_fill_test.dart`

- [ ] **Step 1: Failing tests:** `wizardDefaultsDraftToFill`; `wizardDefaultsPlanToFill` (a workout on a plan's day: `fillPlanned`, `fillTarget.kind == FillTargetKind.plan`; switching the row to import as new leaves the plan alone); `wizardOffersConsolidateForDownloadedDive` (defaulted when the score is at least 0.85); `planIsNotAFuzzyDuplicate`; `heldPlanWorkoutDefaultsToFillInWizard` (a workout the background run held opens in the wizard with the plan preselected).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/import_wizard/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(import-wizard): fill drafts and merge dives from Apple Health`.

## Phase F: Heart rate, recovery and sleep

### Task 20: `dive_health_records` table and sync

**Files:**
- Create: `lib/core/database/tables/dive_health_tables.dart` (export from `database.dart`, add to `@DriftDatabase`)
- Modify: v347 rung (create the table; same rung as Task 1), backstop in `before_open_child_columns.dart`
- Create: `lib/features/dive_log/data/repositories/dive_health_record_repository.dart`
- Modify (sync, following `tide_records` everywhere it appears): `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/features/dive_log/data/services/dive_merge_snapshot.dart`, `dive_consolidation_service.dart`, `dive_merge_service.dart`, `dive_repository_impl.dart` (delete cascade, merge moves), conflict catalogue
- Test: `test/features/dive_log/data/repositories/dive_health_record_repository_test.dart`, plus the existing sync coverage tests (`sync_serializer_upsert_test.dart`, `sync_data_serializer_batch_coverage_test.dart`, `sync_parent_refs_completeness_test.dart`, `sync_serializer_fetch_record_test.dart`, `dive_undo_restamps_children_test.dart`)

**Interfaces:**
- Produces table `DiveHealthRecords`: `id` text PK, `diveId` text FK to dives cascade (unique), `heartRateSamples` text nullable (JSON `[[offsetSeconds, bpm], ...]` from entry), `avgHeartRate` int?, `maxHeartRate` int?, `heartRateAtExit` int?, `heartRateExitPlus5` int?, `heartRateExitPlus15` int?, `overnightHrvMs` real?, `sleepBeforeMinutes` int?, `settled` bool default false, `fetchedAt` int, `createdAt` int, `updatedAt` int, `hlc` text nullable.
- Produces: `DiveHealthRecord` entity with `copyWith`; `DiveHealthRecordRepository { Future<DiveHealthRecord?> forDive(String diveId); Stream<DiveHealthRecord?> watchForDive(String diveId); Future<void> upsert(DiveHealthRecord record); Future<List<String>> unsettledDiveIds({required String diverId, required DateTime since}); }`; `diveHealthRecordProvider` (`StreamProvider.family<DiveHealthRecord?, String>`).

- [ ] **Step 1: Failing tests:** `upsertAndReadBack`; `deletingDiveDeletesRecord`; `consolidationMovesRecordToTarget`; `unsettledListsOnlyBoundDiverRecent`; and the sync coverage suites fail until the table is registered.
- [ ] **Step 2: Run** `flutter test test/features/dive_log/data/repositories/dive_health_record_repository_test.dart test/core/services/sync/ test/core/database/`. Expected: FAIL.
- [ ] **Step 3: Implement** the table, rung, repository and sync wiring; regenerate code.
- [ ] **Step 4: Run** the same command plus `flutter test test/features/dive_log/data/services/ test/features/settings/presentation/conflicts/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): store Apple Health readings per dive`.

### Task 21: Read heart rate, HRV and sleep from Health

**Files:**
- Modify: `lib/features/dive_import/domain/services/health_import_service.dart` and `lib/features/dive_import/data/services/healthkit_service.dart` (`fetchHeartRate`, `fetchHrv`, `fetchSleep`)
- Create: `lib/features/dive_import/domain/services/health_metrics_calculator.dart`
- Test: `test/features/dive_import/domain/services/health_metrics_calculator_test.dart`, `test/features/dive_import/data/services/healthkit_service_metrics_test.dart`

**Interfaces:**
- Produces on `HealthImportService`: `Future<List<HealthSample>> fetchHeartRate({required DateTime start, required DateTime end})`, `fetchHrv(...)`, `Future<List<SleepInterval>> fetchSleep(...)`; `class HealthSample { final DateTime at; final double value; }`; `class SleepInterval { final DateTime start; final DateTime end; }`. Instants are true UTC; callers convert dive wall-clock times with `fromWallClockUtc`.
- Produces calculator functions:
  - `HeartRateSummary? summarizeHeartRate(List<HealthSample> s)` (avg rounded, max).
  - `RecoveryReadings recoveryAfter(List<HealthSample> s, DateTime exit)`: value nearest to exit, exit + 5 min, exit + 15 min, each within 2 min or null.
  - `double? overnightHrv(List<HealthSample> hrv, List<SleepInterval> sleep, DateTime afterExit)`: mean SDNN of samples inside the first sleep that starts after `afterExit` and within 18 h.
  - `int? sleepBeforeMinutes(List<SleepInterval> sleep, DateTime firstEntryOfDay)`: total asleep minutes between 18:00 the previous evening and the entry.
  - `List<List<int>> heartRateOffsets(List<HealthSample> s, DateTime entry)`.

- [ ] **Step 1: Failing tests:** `summaryRoundsAverage` (60, 61, 62 gives avg 61, max 62); `recoveryPicksNearestWithinTwoMinutes`; `recoveryNullWhenNoSample`; `overnightHrvUsesNextSleep`; `sleepCountsOnlyPreviousEvening` (an afternoon nap the day before at 15:00 is ignored); `heartRateOffsetsAreSecondsFromEntry`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/dive_import/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): read heart rate, HRV and sleep from Apple Health`.

### Task 22: Attach Health readings to dives

**Files:**
- Create: `lib/features/dive_import/data/services/dive_health_metrics_service.dart`
- Modify: `lib/app.dart` (after the auto-import on launch and resume: `refreshPending()`), Task 12 and Task 17 fill and import paths (refresh the touched dives when metrics are on)
- Test: `test/features/dive_import/data/services/dive_health_metrics_service_test.dart`

**Interfaces:**
- Consumes: Tasks 15, 20, 21.
- Produces: `DiveHealthMetricsService { Future<void> refresh(String diveId); Future<void> refreshPending({DateTime? now}); }`. Only for dives of `metricsDiverId`; skips drafts that are still open; heart rate is not written when the dive's primary profile already has heart rate from a non-Apple-Watch source (`heartRateSource != 'appleWatch'`); a record is `settled` when every value is present or the dive ended more than 3 days ago.

- [ ] **Step 1: Failing tests:** `writesRecordForBoundDiver`; `ignoresOtherDiver`; `keepsComputerHeartRate` (a dive whose profile has strap heart rate gets recovery and sleep but no samples); `rereadsUntilSettled` (HRV missing on the first pass, present on the second, then settled); `stopsAfterThreeDays`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-import): attach Apple Health heart rate and recovery to dives`.

### Task 23: Show heart rate, recovery and sleep

**Files:**
- Create: `lib/features/dive_log/domain/services/merge_heart_rate.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart:257-271`, `dive_profile_panel.dart:257-260` (merge the record's heart rate when the drawn profile has none)
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_health_section.dart` (average and maximum heart rate, recovery numbers, the sleep note)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (mount the section), `dive_detail_overflow_menu.dart` ("Add heart rate from Apple Health", iOS, metrics on)
- Test: `test/features/dive_log/domain/services/merge_heart_rate_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/dive_health_section_test.dart`

**Interfaces:**
- Produces: `List<DiveProfilePoint> mergeHeartRate(List<DiveProfilePoint> points, List<List<int>> offsets, {int maxGapSeconds = 30})`: returns points unchanged if any has heart rate; otherwise sets `heartRate` and `heartRateSource: 'appleWatch'` from the nearest sample within the gap.
- Strings: `diveLog_health_title` ("Heart rate and recovery"), `diveLog_health_avgMax`, `diveLog_health_recovery`, `diveLog_health_recoveryExplain` ("Heart rate at surfacing and 5 and 15 minutes later, from Apple Health."), `diveLog_health_overnightHrv`, `diveLog_health_sleepBefore` ("Slept {hours} h {minutes} min the night before"), `diveLog_detail_menu_addHeartRate`.

- [ ] **Step 1: Failing tests:** `mergeFillsNearestWithinGap`; `mergeLeavesProfileWithHeartRate`; `mergeSkipsBeyondGap`; `sectionShowsNumbersWithoutVerdicts` (no "good", "poor" or "normal" text); `sectionHiddenWithoutRecord`; `sleepNoteFormatsHoursAndMinutes`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/dive_log/presentation/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show Apple Health heart rate, recovery and sleep on a dive`.

## Phase G: Card, reminder and conditions

### Task 24: "Waiting for download" dashboard card

**Files:**
- Modify: `lib/features/dashboard/presentation/home_cards.dart:6-20` (`waitingForDownload` after `preDive`)
- Modify: `lib/features/dashboard/presentation/home_layout.dart:46-61`, `lib/features/dashboard/presentation/pages/dashboard_page.dart:84-97, :131-147`, `lib/features/settings/presentation/pages/home_appearance_page.dart:173-197`
- Create: `lib/features/dashboard/presentation/widgets/waiting_for_download_card.dart`, `lib/features/dive_log/presentation/providers/download_target_providers.dart`
- Test: `test/features/dashboard/presentation/widgets/waiting_for_download_card_test.dart`, `test/features/dive_log/presentation/providers/download_target_providers_test.dart`

**Interfaces:**
- Consumes: `draftDivesProvider` (Task 3), `allDiveComputersProvider`.
- Produces: `downloadTargetComputerProvider` (`FutureProvider<DiveComputer?>`: the computer with the newest `lastDownload`, never the Apple Watch computer, null when none); `WaitingForDownloadCard` lists the count and up to 3 newest drafts; "Download now" pushes `/dive-computers/<id>/download` or `/dive-computers` when null. Strings `dashboard_waitingForDownload_title` ("{count} dives waiting for your dive computer"), `dashboard_waitingForDownload_download`, `settings_homeCards_card_waitingForDownload`.

- [ ] **Step 1: Failing tests:** `hiddenWithNoDrafts`; `listsThreeNewest`; `downloadNowOpensMostRecentComputer`; `neverPicksAppleWatch`; `noComputerOpensPicker`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**, and point Task 6's "Download now" at `downloadTargetComputerProvider`.
- [ ] **Step 4: Run** the tests and `flutter test test/features/dashboard/ test/features/settings/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): show drafts waiting for a download`.

### Task 25: Reminder for drafts left waiting

**Files:**
- Create: `lib/features/notifications/presentation/providers/draft_reminder_settings_provider.dart` (device-local, key `draft_download_reminder`, default off)
- Modify: `lib/core/services/notification_service.dart` (`scheduleDraftReminder({required String diveId, required DateTime at, required String title, required String body})`, `cancelDraftReminder(String diveId)`, channel `draft_reminders`, payload `dive:<id>`)
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart:58` (`_scheduleDraftReminders`, so `rescheduleAll` restores them)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:1476` (switch)
- Modify: Task 3 `closeDraft`, `promoteToLoggedDive`, delete (schedule on close, cancel on fill, complete or delete)
- Test: `test/features/notifications/data/services/notification_scheduler_draft_test.dart`

**Interfaces:**
- Produces: `DateTime draftReminderAt(Dive draft)` = exit time (or entry) + 3 days at the diver's `reminderTime`. Strings `notifications_draftReminder_title`, `notifications_draftReminder_body`, `settings_notifications_draftReminder`.

- [ ] **Step 1: Failing tests:** `offSchedulesNothing`; `schedulesThreeDaysAfterExit`; `fillCancels`; `rescheduleAllRestoresDraftReminders`; `pastReminderNotScheduled`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/notifications/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notifications): remind about drafts waiting for a download`.

### Task 26: Weather and tide for drafts

**Files:**
- Create: `lib/features/dive_log/data/services/draft_conditions_service.dart`
- Modify: `DiveMarkService.surfaced` (Task 7) and `lib/app.dart` launch (retry pending)
- Test: `test/features/dive_log/data/services/draft_conditions_service_test.dart`

**Interfaces:**
- Consumes: `WeatherRepository.fetchAndSaveWeather(diveId:, latitude:, longitude:, dateTime:)`, `recordDiveTide(repository:, calculator:, diveId:, entryWallClock:, location: GeoPoint, waterType:)`, `DiveRepository.fillDiveConditions` semantics (fill only).
- Produces: `DraftConditionsService { Future<void> fillFor(String diveId); Future<void> retryPending(); }`. Uses the entry position; skips drafts without one; never overwrites values already set; a failure leaves the draft for `retryPending`, which covers drafts from the last 7 days with no weather source.

- [ ] **Step 1: Failing tests:** `fillsWeatherAndTideFromEntryPosition`; `keepsTypedAirTemperature`; `skipsWithoutPosition`; `offlineFailureRetriesLater`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/weather/ test/features/tides/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): fill weather and tide for drafts`.

## Phase H: Finish

### Task 27: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (every key added in Tasks 1 to 26)
- Regenerate: `flutter gen-l10n`

- [ ] **Step 1: Run** the l10n completeness tests: `flutter test test/l10n/ test/features/settings/presentation/conflicts/conflict_labels_complete_test.dart`. Expected: FAIL for missing keys.
- [ ] **Step 2: Translate** each new key into the ten locales, keeping placeholders.
- [ ] **Step 3: Run** `flutter gen-l10n` and the same tests. Expected: PASS.
- [ ] **Step 4: Commit** `feat(l10n): translate dive drafts and Apple Health strings`.

### Task 28: Full verification

- [ ] **Step 1:** `dart format .` (no changes), `flutter analyze` (no issues).
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/core/ test/features/dive_log/ test/features/dive_import/ test/features/dive_computer/ test/features/import_wizard/ test/features/gps_log/ test/features/dashboard/ test/features/notifications/ test/features/settings/` in the background, logged to the scratchpad. Expected: all pass.
- [ ] **Step 3:** Run the app (iOS simulator for the GPS card and Apple Health settings, macOS for the list, detail and dashboard) and capture the after screenshots listed in the PR.
