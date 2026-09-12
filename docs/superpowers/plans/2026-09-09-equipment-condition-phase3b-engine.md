# Equipment Condition Intelligence, Phase 3b: Condition Engine and Findings

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the per-dive sensor summaries (phase 2), the check-ins and incident links (phase 3a) and the exposure samples (phase 1) into condition findings per item: a pure rule engine with ten rules, a synced `equipment_findings` store with deterministic ids and a dismissal rule, a device-local review marker with an input fingerprint so an unchanged item costs one row read, a sweep pass over active gear, and the engine's master and per-rule toggles in Settings.

**Architecture:** `EquipmentConditionEngine` is pure and versioned; it takes the item, its children, its exposure samples (now carrying dive ids), the sensor summaries for those dives, the observations, the incidents, the thresholds and `now`, and returns findings. `equipmentConditionProvider(equipmentId)` computes through the cache: it builds the inputs, hashes them into a fingerprint, compares with `equipment_condition_reviews`, and only then runs the engine and saves. Findings sync like `dive_safety_findings` (no HLC of their own, the parent equipment row's HLC is bumped); the review marker is device-local. Rule toggles never reach the engine: like the safety review, every rule always runs and the disabled set filters at display time, so a toggle flip is instant and reversible. The toggles live in `diver_settings` behind a v206 rung.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Data model: `equipment_findings`, `equipment_condition_reviews`, Enums, Settings; Condition findings: Engine, Rules, Evidence, Dismissal; Sync). This plan is the second half of phase 3; phase 4 (surfaces) stacks on it.

**Decisions (asked and answered 2026-09-09):** the engine master and rule toggles are `diver_settings` columns behind a v206 rung (204 and 205 are claimed by other branches; re-check the ladder in Task 0); rules always compute and hide at display time; phase 3 ships as 3a then 3b, stacked.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings). Rewrite the sentence instead.
- No tool or vendor attribution in any commit, comment, file or PR body.
- Run `dart format .` before every commit. The pre-push hook runs format, analyze, l10n staleness and tests; push with `SKIP_TESTS=1` after a local full run because the hook cannot see a worktree's new test files.
- TDD: write the failing test first, run it, watch it fail, then implement.
- Every user-facing string goes through `context.l10n` and is added to all 11 ARB files; only `app_en.arb` is alphabetical, the other ten anchor on the same neighbour. Regenerate with `flutter gen-l10n`; the generated `lib/l10n/arb/app_localizations*.dart` files are tracked and are staged with the ARB edits.
- **One schema rung: v206.** `equipment_findings` and `equipment_condition_reviews` exist since v202; the rung adds only the two `diver_settings` columns. Bump `currentSchemaVersion` from 203 to 206 (204 and 205 are claimed elsewhere; if either lands on main first, the ladder still reads in order because every rung is `if (from < n)`). If 206 is claimed by execution time, take the next free number and renumber every `206` in this plan and the migration test.
- The migration touches `lib/core/database/database.dart`, so Drift codegen must run afterwards: `dart run build_runner build --delete-conflicting-outputs` through a scratchpad script (a bare `build` token in a Bash command can be refused).
- Every new setter on `SettingsNotifier` must also be added to `MockSettingsNotifier` (`test/helpers/mock_providers.dart`) and to every test-local class that `implements SettingsNotifier` without `noSuchMethod` (find them with `grep -rln "implements SettingsNotifier" test`, then check each for `noSuchMethod`).
- Tests importing both `drift` and `flutter_test` must `hide isNull, isNotNull` on the drift import.
- The engine never produces a date, a remaining life or a probability; the word "predict" appears nowhere.
- Commit after every task with the message given in the task. Never `git add -A`; stage the listed paths.

## File structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/equipment_finding.dart` | `ConditionRuleId`, `ConditionSeverity`, `FindingEvidence`, `EquipmentFinding`, `conditionFindingId`, evidence JSON codec |
| `lib/features/equipment/domain/services/equipment_condition_engine.dart` | `ConditionEngineInput`, `EquipmentConditionEngine` (pure, `engineVersion = 1`) |
| `lib/features/equipment/domain/services/condition_input_fingerprint.dart` | `conditionInputFingerprint(...)` |
| `lib/features/equipment/data/repositories/equipment_findings_repository.dart` | Findings and review marker persistence, dismissal carry-over, sync bookkeeping |
| `lib/features/equipment/presentation/providers/equipment_condition_providers.dart` | `equipmentConditionProvider`, `conditionEngineEnabledProvider`, `conditionDisabledRulesProvider`, dismissal helper |
| `test/features/equipment/domain/entities/equipment_finding_test.dart` | Entity, id shape, codec |
| `test/features/equipment/domain/services/equipment_condition_engine_test.dart` | Every rule at n minus one and n, slot attachment, severities |
| `test/features/equipment/domain/services/condition_input_fingerprint_test.dart` | Fingerprint sensitivity |
| `test/features/equipment/data/repositories/equipment_findings_repository_test.dart` | Save, re-emit, dismissal, deletion, marker |
| `test/features/equipment/data/repositories/dive_sensor_summary_batch_test.dart` | `getSummaries` |
| `test/features/transmitters/data/repositories/transmitter_serials_for_equipment_test.dart` | `getSerialsForEquipment` |
| `test/core/services/sync/equipment_findings_sync_test.dart` | Round trip, export by parent HLC, census |
| `test/core/database/migration_v206_condition_engine_settings_test.dart` | Rung and backstop |
| `test/features/equipment/presentation/providers/equipment_condition_providers_test.dart` | Compute-through-cache, invalidation, statement count on an unchanged item |

Modified files: `lib/features/equipment/domain/entities/service_clock_status.dart` (`EquipmentExposureSample.diveId`, `updatedAt`), `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (exposure query), `lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart` (`getSummaries`), `lib/features/transmitters/data/repositories/transmitter_repository.dart` (`getSerialsForEquipment`), `lib/core/database/database.dart` (columns, rung, backstop), `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`, `test/helpers/mock_providers.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, the two sync census tests, `lib/features/equipment/presentation/providers/equipment_condition_sweep.dart`, `lib/features/equipment/data/services/sensor_summary_scheduler.dart`, `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart` and its test, `test/features/equipment/data/exposure_samples_query_test.dart`, the 11 ARB files.

---

### Task 0: Branch, preflight, ladder

- [ ] **Step 1:** `git checkout -b ericgriffin/equipment-condition-phase3b-engine ericgriffin/equipment-condition-phase3a-observations`
- [ ] **Step 2:** `git submodule update --init --recursive && flutter pub get && flutter analyze` (expect `No issues found!`)
- [ ] **Step 3: Ladder.** Run the scratchpad `ladder.sh` from phase 2 (or its equivalent: `grep -o 'currentSchemaVersion = [0-9]*'` across every sibling worktree and `gh pr diff <n> | grep currentSchemaVersion` for every open PR, fork PRs included). Expected on 2026-09-09: 204 (worktree github-issue-1606-76cd56) and 205 (fork PR #1639) claimed, 206 free. Renumber the plan if not.

---

### Task 1: Finding entities, deterministic ids, evidence codec

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_finding.dart`
- Test: `test/features/equipment/domain/entities/equipment_finding_test.dart`

**Interfaces (produces):**

```dart
enum ConditionRuleId {
  cellOutputDeclining, cellOutputLow, cellDivergent, cellCurrentLimited,
  transmitterDropoutRising, transmitterDropoutHigh,
  issueRecurring, issueColdCorrelated, issueDeepCorrelated, incidentLinked;
  String get dbValue => name;
  static ConditionRuleId? fromDbValue(String value);   // null for unknown
  ConditionSeverity get severity;   // the spec table: info for the two
      // correlation rules and incidentLinked; caution for cellOutputDeclining,
      // cellDivergent, transmitterDropoutRising, issueRecurring; significant
      // for cellOutputLow, cellCurrentLimited, transmitterDropoutHigh
}
enum ConditionSeverity { info, caution, significant; dbValue; fromDbValue (falls back to info) }

/// n, the window, the dive ids and the numbers the sentence is built from.
class FindingEvidence extends Equatable {
  final int n;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<String> diveIds;
  final Map<String, double> values;   // rule-specific, e.g. {'recentMedian': 41.2, 'baselineMedian': 52.8}
  final String? tag;                  // ObservationTag.dbValue for issueRecurring, else null
  final int? slot;                    // cell slot for the slot rules
  String encode();  static FindingEvidence? decode(String json);
}

String conditionFindingId(String equipmentId, ConditionRuleId rule, {int? slot}) =>
    slot == null ? 'cf_${equipmentId}_${rule.dbValue}' : 'cf_${equipmentId}_${rule.dbValue}_$slot';

/// SHA-1 hex of the sorted dive ids joined with "|" plus the values map in
/// key order, so two devices computing the same evidence agree.
String evidenceFingerprint(FindingEvidence evidence);

class EquipmentFinding extends Equatable {
  id, equipmentId, ruleId, severity, value (double?), evidence (FindingEvidence),
  evidenceFingerprint, engineVersion, dismissedAt (DateTime?), createdAt;
  bool get isDismissed; copyWith({..., bool clearDismissedAt = false});
}
```

- [ ] **Step 1: Test** the enums round-trip and fall back as specified, `conditionFindingId` with and without slot, the evidence codec round-trips every field and drops nothing, `evidenceFingerprint` is stable across dive id order and changes when a value changes, and `severity` matches the spec table for all ten rules.
- [ ] **Step 2:** Run red. **Step 3:** Implement (use `package:crypto` `sha1` if it is a dependency, check `pubspec.yaml`; otherwise a stable FNV-1a hex over the canonical string is acceptable, documented as such). **Step 4:** Run green. **Step 5:** Commit `feat(equipment): condition finding entities and evidence codec (condition phase 3b)`.

---

### Task 2: Exposure samples carry the dive id and stamp

**Files:**
- Modify: `lib/features/equipment/domain/entities/service_clock_status.dart` (`EquipmentExposureSample`: add `final String diveId;` and `final int updatedAt;` with defaults `''` and `0` so every existing constructor call compiles; add to `props`)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`SELECT d.id AS dive_id, d.updated_at AS updated_at, ...`; map both)
- Test: extend `test/features/equipment/data/exposure_samples_query_test.dart` with one case asserting each sample's `diveId` and `updatedAt` match the fixture rows, and that the statement count is still one.

Commit: `feat(equipment): exposure samples name their dive and its stamp (condition phase 3b)`.

---

### Task 3: Batch summary read and transmitter serial lookup

**Files:**
- Modify: `lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart`: `Future<Map<String, DiveSensorSummary>> getSummaries(List<String> diveIds)` reading in chunks of 500 (`isIn`), no compute, missing dives absent from the map.
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart`: `Future<Set<String>> getSerialsForEquipment(String equipmentId)` returning the normalised serials of every registry row whose `equipment_id` is the item.
- Tests: the two files listed in the structure table.

Commit: `feat(equipment): batch sensor summary read and transmitter serials per item (condition phase 3b)`.

---

### Task 4: The condition engine

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_condition_engine.dart`
- Test: `test/features/equipment/domain/services/equipment_condition_engine_test.dart`

**Interfaces (produces):**

```dart
class ConditionEngineInput {
  final EquipmentItem item;
  final List<EquipmentItem> children;
  final List<EquipmentExposureSample> samples;             // ascending by date, with diveId
  final Map<String, DiveSensorSummary> summariesByDive;    // for the sample dive ids
  final List<EquipmentObservation> observations;           // this item's
  final List<Incident> incidents;                          // naming this item
  final Set<String> transmitterSerials;                    // registry rows for this item (transmitter items)
  final ExposureThresholds thresholds;
  final DateTime now;
}

class EquipmentConditionEngine {
  static const int engineVersion = 1;
  const EquipmentConditionEngine();
  List<EquipmentFinding> evaluate(ConditionEngineInput input);
}
```

Rules, each a private method returning zero or more findings, ids from `conditionFindingId`, `createdAt = now`, `engineVersion = engineVersion`, severity from the rule:

| Rule | Applies to | Window and emit condition | `value` | evidence values |
| --- | --- | --- | --- | --- |
| `cellOutputDeclining` | `o2Cell` item (its slot from `attrNum(EquipmentAttrKeys.cellSlot)`, dives since its install date), or a `rebreather` for each slot with data that has no child item in that slot | over the dives with a gain for the slot, ordered by date: n at least 10; `recentMedian` = median gain of the last 5; `baselineMedian` = median of the first 5; emit when `recentMedian <= 0.85 * baselineMedian` | percent drop `100 * (1 - recent / baseline)` | `recentMedian`, `baselineMedian` |
| `cellOutputLow` | same | last 3 dives with a gain: median below 40 mV per bar; n at least 3 | the median | `recentMedian` |
| `cellDivergent` | same | last 5 dives with a p95: at least 3 have p95 above 0.1 bar; n at least 5 | worst p95 among them | `worstP95`, `count` |
| `cellCurrentLimited` | same | last 5 dives that reached 1.2 bar (`highPpO2Samples > 0`): at least 2 have `lowAtHighFraction > 0.5`; n at least 2 | worst fraction | `worstFraction`, `count` |
| `transmitterDropoutRising` | `transmitter` item: gap entries whose serial is in `transmitterSerials` | dives with a gap entry, by date: n at least 15; `recentMean` = mean gap fraction of the last 5; `priorMean` = mean of the 10 before; emit when `recentMean >= 2 * priorMean` and `recentMean >= 0.05` | `recentMean` | `recentMean`, `priorMean` |
| `transmitterDropoutHigh` | same | last 5 dives with a gap entry: at least 3 have fraction at least 0.10; n at least 5 | mean fraction over the 5 | `recentMean`, `count` |
| `issueRecurring` | any | the item's last 20 dives (by sample date); observations with a dive id in that set and status issue; for each tag with at least 3 such observations, one finding per tag with the tag in the evidence and the id suffixed `_<tag>` through the `slot`-free id plus the tag (use `conditionFindingId` then append `'_${tag.dbValue}'`) | count | `count` |
| `issueColdCorrelated` | `regulator, bcd, drysuit, light` | split the samples by `minTemperature < thresholds.coldWaterC`; a dive "has an issue" when an issue observation names it; need at least 5 dives on each side and at least 3 cold issue dives; emit when `coldShare >= 3 * warmShare` (a zero warm share counts as satisfied) | `coldShare / max(warmShare, 1/warmCount)` capped at 99 | `coldIssueDives`, `coldDives`, `warmIssueDives`, `warmDives` |
| `issueDeepCorrelated` | same | same shape over `maxDepth >= thresholds.deepDiveM` | same | `deepIssueDives`, `deepDives`, `shallowIssueDives`, `shallowDives` |
| `incidentLinked` | any | incidents naming the item with severity moderate or serious; n at least 1 | count | `count` |

Evidence window: `windowStart`/`windowEnd` are the first and last dive dates of the dives the rule read; `diveIds` those dives; `n` their count. A rule whose data is absent emits nothing. Cell slot rules on a rebreather attach to the child when a child `o2Cell` with that `cell_slot` exists among `children` and was installed on or before the evidence dives (the child's `installedDate`), otherwise to the rebreather with the slot in the id.

- [ ] **Step 1: Tests.** For every rule: a fixture at n minus one emits nothing and at n emits with the expected `value`, `severity`, id, `evidence.n` and `evidence.diveIds`; the cell rules once on an `o2Cell` child (id without slot) and once on a bare rebreather (id with slot); `issueRecurring` emits one finding per tag; the correlation rules honour both minimums and the ratio boundary; `incidentLinked` ignores `minor`. Build samples with a helper that also fills `summariesByDive`.
- [ ] **Step 2:** Run red. **Step 3:** Implement, one private method per rule, shared helpers `_median`, `_mean`, `_lastN`. **Step 4:** Run green. **Step 5:** Commit `feat(equipment): condition engine with the ten spec rules (condition phase 3b)`.

---

### Task 5: Input fingerprint

**Files:**
- Create: `lib/features/equipment/domain/services/condition_input_fingerprint.dart`
- Test: `test/features/equipment/domain/services/condition_input_fingerprint_test.dart`

```dart
/// The newest exposure sample stamp and count, the observation count and
/// newest stamp, the incident count and newest stamp, the thresholds, the
/// children (ids and install dates) and the engine version, hashed. An
/// unchanged item hashes the same on every device.
String conditionInputFingerprint({
  required List<EquipmentExposureSample> samples,
  required List<EquipmentObservation> observations,
  required List<Incident> incidents,
  required List<EquipmentItem> children,
  required ExposureThresholds thresholds,
  required int engineVersion,
});
```

Test: stable for equal input; changes when a sample stamp, an observation, an incident, a threshold, a child or the engine version changes. Commit `feat(equipment): condition input fingerprint (condition phase 3b)`.

---

### Task 6: Findings repository with the dismissal rule

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_findings_repository.dart`
- Test: `test/features/equipment/data/repositories/equipment_findings_repository_test.dart`

**Interfaces (produces):**

```dart
class EquipmentConditionReview { equipmentId, engineVersion, inputFingerprint, DateTime reviewedAt }

class EquipmentFindingsRepository {
  EquipmentFindingsRepository({AppDatabase? db, SyncRepository? syncRepository});
  Future<EquipmentConditionReview?> getReview(String equipmentId);
  Future<List<EquipmentFinding>> getFindings(String equipmentId);   // undismissed first, then by rule
  Future<List<EquipmentFinding>> getAllUndismissed();                // phase 4 badges
  Future<void> saveReview({required String equipmentId, required String inputFingerprint,
      required List<EquipmentFinding> findings, required DateTime now});
  Future<void> setDismissed({required String findingId, required bool dismissed, required DateTime now});
  Stream<void> watchChanges();   // findings and reviews tables
}
```

`saveReview` in one transaction: load the existing rows for the item; for each new finding with an existing row, keep the row's `dismissed_at` unless the new evidence has at least three dive ids that are not in the old evidence and whose dates (from the new evidence window, use the sample dates passed in through the finding's evidence) are after `dismissed_at`, in which case clear it; write `evidence`, `evidence_fingerprint`, `value`, `severity`, `engine_version` and keep the old `created_at`; insert new findings; delete rows whose id is not among the new findings with `logDeletion(entityType: 'equipmentFindings', recordId)`; `markRecordPending('equipmentFindings', id)` for every written row; upsert the review marker (no sync mark: device-local); `markRecordPending('equipment', equipmentId, ...)` once so the parent's HLC advances and the incremental exporter picks the findings up (the safety review does the same with `dives`); `SyncEventBus.notifyLocalChange()`.

Tests: first save inserts and marks; a second save with the same finding keeps `created_at`; a dismissed finding stays dismissed when fewer than three new dives contributed and clears after three; a rule that stops firing is deleted with a tombstone; `setDismissed` toggles and bumps the parent equipment; the marker round-trips; deleting the item cascades both tables.

Commit `feat(equipment): findings repository with dismissal carry-over and review marker (condition phase 3b)`.

---

### Task 7: Findings travel through sync

Mirror the `diveSafetyFindings` arms with the parent being `equipment`: `SyncData.equipmentFindings` (field, default, `toJson`, `fromJson`, `_baseTables` entry with `table: _db.equipmentFindings`), `exportChangeset` through `_exportEquipmentFindings(hlcSince)` (incremental: equipment rows whose `hlc` is newer, then findings `WHERE equipment_id IN (...)` in chunks), `fetchRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, table lookup, `deleteRecord`. `sync_service.dart`: merge order entry after `equipmentObservations` with `hasUpdatedAt: false`, `entityHasUpdatedAt['equipmentFindings'] = false`, `parentRefs['equipmentFindings'] = [(field: 'equipmentId', parent: 'equipment', nullable: false)]`. Census tests: `syncedTables['equipment_findings'] = 'equipmentFindings'`; batch coverage target. `equipment_condition_reviews` is device-local and is deliberately absent from every sync list; add a one-line comment beside the `hlcTargets` note in `sync_repository.dart` saying so.

Test `test/core/services/sync/equipment_findings_sync_test.dart`: the same four shapes as the observations test, plus "a finding is exported when its parent equipment HLC is newer than the watermark and not otherwise".

Commit `feat(sync): equipment findings travel like safety findings (condition phase 3b)`.

---

### Task 8: Engine toggles in diver settings, v206 rung

**Files:**
- Modify: `lib/core/database/database.dart`: `DiverSettings` gains `BoolColumn get conditionEngineEnabled => boolean().withDefault(const Constant(true))();` and `TextColumn get conditionDisabledRules => text().nullable()();` (JSON list of `ConditionRuleId.dbValue`), `currentSchemaVersion = 206`, `_assertConditionEngineSettingsColumns()` using `_addColumnIfMissing('diver_settings', 'condition_engine_enabled', 'INTEGER NOT NULL DEFAULT 1')` and `('diver_settings', 'condition_disabled_rules', 'TEXT')`, an `if (from < 206)` block after v203 with `await reportProgress()`, and the backstop call beside the v202 one.
- Codegen through the scratchpad script.
- Modify: `settings_providers.dart` (`AppSettings.conditionEngineEnabled` default true, `conditionDisabledRules` default `const {}`, `copyWith`, `setConditionEngineEnabled(bool)`, `setConditionRuleEnabled(ConditionRuleId rule, bool enabled)` mirroring `setSafetyRuleEnabled`, selectors `conditionEngineEnabledProvider` and `conditionDisabledRulesProvider` with `select`), `diver_settings_repository.dart` (both write arms and the read arm through `_encodeDisabledRules` / `_decodeDisabledRules`), `test/helpers/mock_providers.dart` and every `implements SettingsNotifier` class without `noSuchMethod`.
- Tests: `test/core/database/migration_v206_condition_engine_settings_test.dart` (copy the v202 test's fixture style: a v203 fixture with a `diver_settings` table, upgrade, assert both columns, defaults on a new row, and that a fresh database has them; also `currentSchemaVersion == 206`); the settings notifier tests that cover `setSafetyRuleEnabled` gain the condition twins; the diver settings repository round-trip test gains both columns.

Commit `feat(settings): condition engine toggles in diver settings, schema v206 (condition phase 3b)`.

---

### Task 9: Compute-through-cache provider

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_condition_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_condition_providers_test.dart`

```dart
final equipmentFindingsRepositoryProvider = Provider<EquipmentFindingsRepository>(...);

/// The item's findings, computed when the inputs changed. Null when the item
/// does not exist. Returns the stored findings without computing when the
/// master toggle is off. Hidden rules are NOT filtered here; the display
/// layer filters through conditionDisabledRulesProvider.
final equipmentConditionProvider = FutureProvider.family<List<EquipmentFinding>?, String>(...);

Future<void> setConditionFindingDismissed(WidgetRef ref, {required EquipmentFinding finding, required bool dismissed});
Set<String> enabledConditionRuleIds(AppSettings settings);
```

Provider body: self-invalidate on `equipmentRepository.watchEquipmentChanges()`, `observationRepository.watchChanges()`, `incidentRepository.watchChanges()`, `findingsRepository.watchChanges()` and `diveRepository.watchDiveDetailChanges()`; load item (null → null), children (`getChildEquipment`), samples (`getExposureSamplesForEquipment` with the same parent/install/rebreather arguments `_evaluateClocksFor` uses in `equipment_providers.dart`), observations, incidents (`getIncidentsForEquipment`), transmitter serials (transmitter items only), thresholds; fingerprint; if the marker matches (`engineVersion >= EquipmentConditionEngine.engineVersion && inputFingerprint == fingerprint`) return `getFindings`; if the master toggle is off return `getFindings`; else `getSummaries(sampleDiveIds)`, run the engine, `saveReview`, return `getFindings`.

Tests (in-memory Drift, runner-free): a first read computes and stores; a second read with unchanged inputs issues exactly one statement against the findings tables beyond the input reads (count `Drift: Sent` lines for `equipment_condition_reviews` and `equipment_findings`, see the counting memory); an observation write invalidates and recomputes; a threshold change through `settingsProvider` recomputes; the master toggle off returns the stored findings and never calls the engine (inject a counting engine through a provider override if needed: expose `equipmentConditionEngineProvider`).

Commit `feat(equipment): equipmentConditionProvider computes through the review marker (condition phase 3b)`.

---

### Task 10: The sweep runs the engine over active gear

- Modify `equipment_condition_sweep.dart`: `run` gains `bool findings = true`; after the summary loop, when `findings` is set and the master toggle is on, iterate `activeEquipmentProvider` items (through the repository, not the provider, inside the sweep) and for each call a new `EquipmentConditionRefresher.ensureCurrent(item)` that does what the provider body does without Riverpod (extract the provider's compute into `lib/features/equipment/data/services/equipment_condition_refresher.dart` taking the repositories in its constructor, and have the provider call it). Progress counts items after dives.
- Modify `sensor_summary_scheduler.dart`: after its dive loop, run the refresher over active gear (skipped when the master toggle is off, read through `DiverSettingsRepository` for the active diver, or simply always run: the refresher itself checks the marker so an unchanged item is one read).
- Tests: sweep test gains "the findings pass writes a marker for every active item"; scheduler test gains the same after a scheduled refresh.

Commit `feat(equipment): condition sweep and scheduler refresh findings for active gear (condition phase 3b)`.

---

### Task 11: Settings page toggles

- ARB (13 keys, anchored after `equipmentConditionSettings_rebuild_failed`): `equipmentConditionSettings_masterToggle` "Condition findings", `equipmentConditionSettings_masterToggle_subtitle` "Report trends in cell output, transmitter dropouts and reported issues, with the numbers behind them", `equipmentConditionSettings_rulesHeader` "Rules", and `equipmentConditionSettings_rule_<ruleId>` for the ten rules: "Cell output declining", "Cell output low", "Cell disagrees with its peers", "Cell current-limited at high ppO2", "Transmitter dropouts rising", "Transmitter dropouts high", "Recurring issue", "Issues on cold dives", "Issues on deep dives", "Linked incidents". Translations into the ten locales, recorded in this plan's appendix before committing.
- Page: after the sensor section, a master `SwitchListTile` bound to `setConditionEngineEnabled` and, under a "Rules" header, one `SwitchListTile` per `ConditionRuleId` bound to `setConditionRuleEnabled`, disabled when the master is off; mirror `safety_settings_page.dart` lines 40 to 90.
- Test: the page shows 11 switches; toggling the master calls the setter; toggling a rule updates `conditionDisabledRules`; rules are disabled when the master is off.

Commit `feat(settings): condition engine master and rule toggles (condition phase 3b)`.

---

### Task 12: Wrap-up

`dart format .`, `flutter analyze`, `flutter gen-l10n && git status --short lib/l10n` (clean), full suite once, mutation checks (a) flip the `0.85` in `cellOutputDeclining` to `0.95` and confirm the n-boundary test fails, (b) drop the `parentRefs['equipmentFindings']` entry and confirm the completeness test fails, (c) make `saveReview` never clear `dismissed_at` and confirm the three-dive test fails; restore each. Push with `SKIP_TESTS=1`, open the PR against `ericgriffin/equipment-condition-phase3a-observations` titled `feat(equipment): condition engine, findings and toggles (condition intelligence phase 3b)` with the repository template (Summary, Changes, Test Plan). Update the program memory.

## Translation Appendix

Shipped at Task 11, 13 keys under `equipmentConditionSettings_`, anchored after `equipmentConditionSettings_rebuild_failed` in all 11 files.

### en

- `masterToggle`: Condition findings
- `masterToggle_subtitle`: Report trends in cell output, transmitter dropouts and reported issues, with the numbers behind them
- `rulesHeader`: Rules
- `rule_cellOutputDeclining`: Cell output declining
- `rule_cellOutputLow`: Cell output low
- `rule_cellDivergent`: Cell disagrees with its peers
- `rule_cellCurrentLimited`: Cell current-limited at high ppO2
- `rule_transmitterDropoutRising`: Transmitter dropouts rising
- `rule_transmitterDropoutHigh`: Transmitter dropouts high
- `rule_issueRecurring`: Recurring issue
- `rule_issueColdCorrelated`: Issues on cold dives
- `rule_issueDeepCorrelated`: Issues on deep dives
- `rule_incidentLinked`: Linked incidents

### es

- `masterToggle`: Hallazgos de estado
- `masterToggle_subtitle`: Informa de tendencias en la salida de las celdas, pérdidas de señal del transmisor y problemas registrados, con las cifras que las respaldan
- `rulesHeader`: Reglas
- `rule_cellOutputDeclining`: Salida de la celda en descenso
- `rule_cellOutputLow`: Salida de la celda baja
- `rule_cellDivergent`: La celda discrepa de sus pares
- `rule_cellCurrentLimited`: Celda limitada por corriente a ppO2 alta
- `rule_transmitterDropoutRising`: Pérdidas de señal del transmisor en aumento
- `rule_transmitterDropoutHigh`: Pérdidas de señal del transmisor elevadas
- `rule_issueRecurring`: Problema recurrente
- `rule_issueColdCorrelated`: Problemas en inmersiones frías
- `rule_issueDeepCorrelated`: Problemas en inmersiones profundas
- `rule_incidentLinked`: Incidentes vinculados

### de

- `masterToggle`: Zustandsbefunde
- `masterToggle_subtitle`: Meldet Trends bei Zellenausgang, Senderaussetzern und gemeldeten Problemen, mit den Zahlen dahinter
- `rulesHeader`: Regeln
- `rule_cellOutputDeclining`: Zellenausgang sinkt
- `rule_cellOutputLow`: Zellenausgang niedrig
- `rule_cellDivergent`: Zelle weicht von den anderen ab
- `rule_cellCurrentLimited`: Zelle strombegrenzt bei hohem ppO2
- `rule_transmitterDropoutRising`: Senderaussetzer nehmen zu
- `rule_transmitterDropoutHigh`: Senderaussetzer hoch
- `rule_issueRecurring`: Wiederkehrendes Problem
- `rule_issueColdCorrelated`: Probleme bei kalten Tauchgängen
- `rule_issueDeepCorrelated`: Probleme bei tiefen Tauchgängen
- `rule_incidentLinked`: Verknüpfte Vorfälle

### fr

- `masterToggle`: Constats d'état
- `masterToggle_subtitle`: Signale les tendances de la sortie des cellules, des pertes de signal de l'émetteur et des problèmes signalés, avec les chiffres à l'appui
- `rulesHeader`: Règles
- `rule_cellOutputDeclining`: Sortie de cellule en baisse
- `rule_cellOutputLow`: Sortie de cellule faible
- `rule_cellDivergent`: Cellule en désaccord avec les autres
- `rule_cellCurrentLimited`: Cellule limitée en courant à ppO2 élevée
- `rule_transmitterDropoutRising`: Pertes de signal de l'émetteur en hausse
- `rule_transmitterDropoutHigh`: Pertes de signal de l'émetteur élevées
- `rule_issueRecurring`: Problème récurrent
- `rule_issueColdCorrelated`: Problèmes lors des plongées froides
- `rule_issueDeepCorrelated`: Problèmes lors des plongées profondes
- `rule_incidentLinked`: Incidents liés

### it

- `masterToggle`: Rilievi sullo stato
- `masterToggle_subtitle`: Segnala le tendenze dell'uscita delle celle, delle perdite di segnale del trasmettitore e dei problemi registrati, con i numeri a supporto
- `rulesHeader`: Regole
- `rule_cellOutputDeclining`: Uscita della cella in calo
- `rule_cellOutputLow`: Uscita della cella bassa
- `rule_cellDivergent`: La cella discorda dalle altre
- `rule_cellCurrentLimited`: Cella limitata in corrente ad alta ppO2
- `rule_transmitterDropoutRising`: Perdite di segnale del trasmettitore in aumento
- `rule_transmitterDropoutHigh`: Perdite di segnale del trasmettitore elevate
- `rule_issueRecurring`: Problema ricorrente
- `rule_issueColdCorrelated`: Problemi nelle immersioni fredde
- `rule_issueDeepCorrelated`: Problemi nelle immersioni profonde
- `rule_incidentLinked`: Incidenti collegati

### pt

- `masterToggle`: Constatações de estado
- `masterToggle_subtitle`: Relata tendências na saída das células, falhas de sinal do transmissor e problemas registados, com os números por trás
- `rulesHeader`: Regras
- `rule_cellOutputDeclining`: Saída da célula em queda
- `rule_cellOutputLow`: Saída da célula baixa
- `rule_cellDivergent`: Célula discorda das outras
- `rule_cellCurrentLimited`: Célula limitada por corrente a ppO2 alta
- `rule_transmitterDropoutRising`: Falhas de sinal do transmissor a aumentar
- `rule_transmitterDropoutHigh`: Falhas de sinal do transmissor elevadas
- `rule_issueRecurring`: Problema recorrente
- `rule_issueColdCorrelated`: Problemas em mergulhos frios
- `rule_issueDeepCorrelated`: Problemas em mergulhos profundos
- `rule_incidentLinked`: Incidentes associados

### nl

- `masterToggle`: Conditiebevindingen
- `masterToggle_subtitle`: Meldt trends in celuitvoer, zenderuitval en gemelde problemen, met de cijfers erachter
- `rulesHeader`: Regels
- `rule_cellOutputDeclining`: Celuitvoer daalt
- `rule_cellOutputLow`: Celuitvoer laag
- `rule_cellDivergent`: Cel wijkt af van de andere
- `rule_cellCurrentLimited`: Cel stroombegrensd bij hoge ppO2
- `rule_transmitterDropoutRising`: Zenderuitval neemt toe
- `rule_transmitterDropoutHigh`: Zenderuitval hoog
- `rule_issueRecurring`: Terugkerend probleem
- `rule_issueColdCorrelated`: Problemen bij koude duiken
- `rule_issueDeepCorrelated`: Problemen bij diepe duiken
- `rule_incidentLinked`: Gekoppelde incidenten

### hu

- `masterToggle`: Állapotmegállapítások
- `masterToggle_subtitle`: Jelzi a cellakimenet, az adókimaradások és a bejelentett problémák trendjeit, a mögöttük álló számokkal
- `rulesHeader`: Szabályok
- `rule_cellOutputDeclining`: Csökkenő cellakimenet
- `rule_cellOutputLow`: Alacsony cellakimenet
- `rule_cellDivergent`: A cella eltér a többitől
- `rule_cellCurrentLimited`: Áramkorlátozott cella magas ppO2-nél
- `rule_transmitterDropoutRising`: Növekvő adókimaradások
- `rule_transmitterDropoutHigh`: Sok adókimaradás
- `rule_issueRecurring`: Visszatérő probléma
- `rule_issueColdCorrelated`: Problémák hideg merüléseken
- `rule_issueDeepCorrelated`: Problémák mély merüléseken
- `rule_incidentLinked`: Kapcsolódó események

### ar

- `masterToggle`: نتائج الحالة
- `masterToggle_subtitle`: يُبلغ عن اتجاهات خرج الخلايا وانقطاعات جهاز الإرسال والمشكلات المسجّلة، مع الأرقام التي تدعمها
- `rulesHeader`: القواعد
- `rule_cellOutputDeclining`: خرج الخلية في انخفاض
- `rule_cellOutputLow`: خرج الخلية منخفض
- `rule_cellDivergent`: الخلية تختلف عن نظيراتها
- `rule_cellCurrentLimited`: الخلية محدودة التيار عند ppO2 مرتفع
- `rule_transmitterDropoutRising`: انقطاعات جهاز الإرسال في ازدياد
- `rule_transmitterDropoutHigh`: انقطاعات جهاز الإرسال مرتفعة
- `rule_issueRecurring`: مشكلة متكررة
- `rule_issueColdCorrelated`: مشكلات في الغطسات الباردة
- `rule_issueDeepCorrelated`: مشكلات في الغطسات العميقة
- `rule_incidentLinked`: حوادث مرتبطة

### he

- `masterToggle`: ממצאי מצב
- `masterToggle_subtitle`: מדווח על מגמות בפלט התאים, בנפילות המשדר ובתקלות שדווחו, עם המספרים שמאחוריהן
- `rulesHeader`: כללים
- `rule_cellOutputDeclining`: פלט התא יורד
- `rule_cellOutputLow`: פלט התא נמוך
- `rule_cellDivergent`: התא חורג מהאחרים
- `rule_cellCurrentLimited`: התא מוגבל זרם ב-ppO2 גבוה
- `rule_transmitterDropoutRising`: נפילות המשדר במגמת עלייה
- `rule_transmitterDropoutHigh`: נפילות המשדר רבות
- `rule_issueRecurring`: תקלה חוזרת
- `rule_issueColdCorrelated`: תקלות בצלילות קרות
- `rule_issueDeepCorrelated`: תקלות בצלילות עמוקות
- `rule_incidentLinked`: אירועים מקושרים

### zh

- `masterToggle`: 状态发现
- `masterToggle_subtitle`: 报告电池输出、发射器断连和已记录问题的趋势，并附上背后的数据
- `rulesHeader`: 规则
- `rule_cellOutputDeclining`: 电池输出下降
- `rule_cellOutputLow`: 电池输出偏低
- `rule_cellDivergent`: 电池与其他电池不一致
- `rule_cellCurrentLimited`: 高 ppO2 下电池电流受限
- `rule_transmitterDropoutRising`: 发射器断连增多
- `rule_transmitterDropoutHigh`: 发射器断连频繁
- `rule_issueRecurring`: 反复出现的问题
- `rule_issueColdCorrelated`: 冷水潜水中的问题
- `rule_issueDeepCorrelated`: 深潜中的问题
- `rule_incidentLinked`: 关联事件

