# Shared Gear Overlap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Point out the same equipment on two different profiles' dives at the same time, as a data-quality finding and as a note while editing a dive (issue #2853).

**Architecture:** One SQL builder lists every (dive, item, link kind) pair. The quality context builder uses it to attach, for the scanned dive, the other profiles' dives in the neighbour window that share an item. A pure detector folds installed parts and assembly components into their topmost matched host and writes one pair finding per host, with a remove-from-dive repair when the link is a gear-list row. The dive edit page asks a provider, keyed by its unsaved times, which items are on another profile's overlapping dive, and hands the note text to the gear list and the picker.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter_test, ARB l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-10-03-equipment-transfer-and-overlap-design.md` (sections "PR 4"). Read it before starting any task.

## Global Constraints

- Two dives overlap when they belong to different, non-null profiles and their intervals share more than 5 minutes (`QualityThresholds.sharedGearOverlapTolerance`). Interval: `entry_time ?? dive_date_time` to `exit_time ?? entry + (runtime ?? bottom_time)`; no derivable duration means never compared.
- Dive times are wall-clock instants stored as UTC epoch millis. Every DateTime rebuilt from SQL or from finding params uses `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)`, as `QualityContextBuilder._neighbors` does; without it `UnitFormatter.formatTime` shows the time shifted by the device's UTC offset.
- A test that changes process-wide state restores it (repo CLAUDE.md, issue #2500): `QualityScanScheduler.enabled` goes back in `addTearDown`, and no production code keeps a static "already logged" set.
- Link kinds: `gearList` (`dive_equipment`), `tankCylinder`, `tankRegulator` (`dive_tanks`), `transmitter` (serial match through the registry, same rule as `getExposureSamplesForEquipment`). Installed parts are listed on their host's finding.
- Detector id `shared_gear_overlap`, version 1, category `QualityCategory.time`, severity `info`. Never a new `QualityCategory` value (findings sync; older builds throw on an unknown name).
- One finding per topmost matched item per pair of dives, through `makePair` with discriminator = that item's id.
- Remove repairs only for `gearList` links, with Undo; everything else is Dismiss and Go to dive.
- Nothing is blocked. With one profile nothing shows.
- Detectors stay pure; every threshold lives in `quality_thresholds.dart`.
- New strings in all 11 ARB files, feature-grouped; plural branches `one{...{count}...}`.
- No em dashes or en dashes as punctuation; no attribution in commits.
- `dart format .`, `flutter analyze`, affected tests and `flutter test test/architecture/` before each commit that adds a `lib/` file.

## Refinements to the spec found while planning

1. **The message names both sides.** The inbox is not scoped to a profile, so "also on Anna's dive" has no "this" to be relative to. The finding reads "{item} is on {diverA}'s dive at {timeA} and {diverB}'s dive at {timeB}." The inline note in the dive editor keeps "Also on {diver}'s dive, {time}".
2. **Params are keyed by dive id, in id order.** A pair finding is anchored on the smaller dive id whichever side was scanned, so "this" and "other" are stored per dive id: `dives: {<diveId>: {diverId, diverName, entryMs, linkKinds}}`, with the two entries inserted in ascending dive-id order. `applyScanResults` compares the params JSON as a string, so an order that followed the scanned side would rewrite and re-sync the finding on every other scan. Names are stored as facts (the message builder has no providers); a rename refreshes on the next scan of either dive.
3. **Installed parts need no install-date arithmetic.** A part only matters when its host is on both dives, and then it folds into the host's finding. The finding lists the host's currently installed parts (`parent_equipment_id = host`, active) and any matched item whose host or assembly parent is also matched.
4. **The note travels as text.** `DiveGearTreeView` and `EquipmentPickerSheet` take an optional `String? Function(String equipmentId) overlapNote`; only the dive edit page passes it.

## Review Focus

1. **An item on a dive twice** (gear list and a tank slot). One item, one finding, and both link kinds are recorded. The remove repair is offered only when the gear list is the item's only link on that dive: removing the dive_equipment row would leave the tank link, and the rescan would reopen the same finding. Pinned in Tasks 4 and 7.
2. **A dive whose profile is unknown (diver_id NULL).** Never paired, on either side. Pinned in Tasks 2 and 4.
3. **The same pair scanned from both sides.** Same finding id and same params. Pinned in Task 4.
4. **Editing a new dive** (no id yet) and moving its time. The note follows the unsaved times and the dive never matches itself. Pinned in Task 8.
5. **A finding synced from a newer build with a category this build does not know.** The inbox still loads. Pinned in Task 5.

---

## File Structure

| File | Responsibility |
| --- | --- |
| Modify `lib/features/data_quality/domain/quality_thresholds.dart` | `sharedGearOverlapTolerance` |
| Create `lib/features/data_quality/domain/services/shared_gear_overlap_rules.dart` | Pure: `gearUseOverlaps`, `foldToTopmost` |
| Create `lib/features/equipment/data/repositories/dive_gear_usage_sql.dart` | SQL fragment listing (dive, item, link kind) |
| Create `lib/features/data_quality/domain/entities/shared_gear_overlap.dart` | Context entities |
| Modify `lib/features/data_quality/domain/entities/dive_quality_context.dart` | `sharedGearOverlaps` field |
| Modify `lib/features/data_quality/data/services/quality_context_builder.dart` | Load the field |
| Create `lib/features/data_quality/domain/detectors/shared_gear_overlap_detector.dart` | The detector |
| Modify `.../quality_detector_registry.dart`, `.../quality_prefilters.dart` | Register, prefilter |
| Modify `lib/features/data_quality/data/repositories/quality_findings_repository.dart` | Tolerant row parsing |
| Modify `.../quality_repair_action.dart`, `.../quality_repair_executor.dart`, `.../data_quality_inbox_page.dart`, `.../quality_finding_card.dart`, `.../quality_finding_message.dart` | Repair and copy |
| Create `lib/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart` | Inline note provider |
| Modify `dive_gear_tree_view.dart`, `equipment_picker_sheet.dart`, `dive_edit_page.dart` | Show the note |
| Modify `lib/l10n/arb/app_*.arb` (11) | Strings |

---

### Task 1: Threshold and pure rules

**Files:**
- Modify: `lib/features/data_quality/domain/quality_thresholds.dart`
- Create: `lib/features/data_quality/domain/services/shared_gear_overlap_rules.dart`
- Test: `test/features/data_quality/domain/services/shared_gear_overlap_rules_test.dart`

**Interfaces:**
- Produces:
  - `static const Duration sharedGearOverlapTolerance = Duration(minutes: 5);` on `QualityThresholds`.
  - `bool gearUseOverlaps({required DateTime aStart, required DateTime aEnd, required DateTime bStart, required DateTime bEnd})`: true when the shared span is strictly longer than the tolerance.
  - `Map<String, Set<String>> foldToTopmost(Map<String, Set<String>> hostsOf)`: keys are matched item ids, values their host and assembly-parent ids; returns topmost matched id to the matched ids folded under it (topmost excluded from its own set). Hosts outside the key set are ignored; cycles terminate (the smallest id of the cycle itself is its top, and items leading into it fold under it).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/services/shared_gear_overlap_rules.dart';

void main() {
  final t0 = DateTime.utc(2026, 5, 1, 10);
  DateTime m(int minutes) => t0.add(Duration(minutes: minutes));

  group('gearUseOverlaps', () {
    test('6 minutes shared overlaps', () {
      expect(gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(34), bEnd: m(80)), isTrue);
    });
    test('exactly 5 minutes shared does not', () {
      expect(gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(35), bEnd: m(80)), isFalse);
    });
    test('4 minutes shared does not', () {
      expect(gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(36), bEnd: m(80)), isFalse);
    });
    test('one dive inside the other overlaps', () {
      expect(gearUseOverlaps(aStart: m(0), aEnd: m(60), bStart: m(10), bEnd: m(30)), isTrue);
    });
    test('disjoint dives do not', () {
      expect(gearUseOverlaps(aStart: m(0), aEnd: m(40), bStart: m(60), bEnd: m(90)), isFalse);
    });
  });

  group('foldToTopmost', () {
    test('a lone item is its own top', () {
      expect(foldToTopmost({'light': {}}), {'light': <String>{}});
    });
    test('parts fold into their matched host', () {
      expect(
        foldToTopmost({'reg': {}, 'hose': {'reg'}, 'octo': {'reg'}}),
        {'reg': {'hose', 'octo'}},
      );
    });
    test('a chain folds to its root', () {
      expect(foldToTopmost({'ccr': {}, 'head': {'ccr'}, 'cell': {'head'}}), {'ccr': {'head', 'cell'}});
    });
    test('a host not matched is ignored', () {
      expect(foldToTopmost({'hose': {'reg'}}), {'hose': <String>{}});
    });
    test('a cycle terminates on its smallest id', () {
      expect(foldToTopmost({'b': {'a'}, 'a': {'b'}}), {'a': {'b'}});
    });
    test('an item leading into a cycle folds under the cycle', () {
      expect(
        foldToTopmost({'a': {'c'}, 'c': {'d'}, 'd': {'c'}}),
        {'c': {'a', 'd'}},
      );
    });
  });
}
```

- [ ] **Step 2:** Run `flutter test test/features/data_quality/domain/services/shared_gear_overlap_rules_test.dart`; expected FAIL (file missing).
- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';

/// Whether two dives' gear use overlaps by more than the tolerance, which
/// absorbs unsynchronised dive computer clocks so a mask handed over
/// between back-to-back dives is not reported (issue #2853).
bool gearUseOverlaps({
  required DateTime aStart,
  required DateTime aEnd,
  required DateTime bStart,
  required DateTime bEnd,
}) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  return end.difference(start) > QualityThresholds.sharedGearOverlapTolerance;
}

/// Folds matched items into their topmost matched host or assembly parent,
/// so one physical setup gives one finding. [hostsOf] maps each matched
/// item to its host and assembly-parent ids; ids outside its keys are not
/// matched and are ignored.
Map<String, Set<String>> foldToTopmost(Map<String, Set<String>> hostsOf) {
  String topOf(String id) {
    final path = <String>[id];
    var current = id;
    while (true) {
      final next = [
        for (final h in hostsOf[current] ?? const <String>{})
          if (hostsOf.containsKey(h)) h,
      ]..sort();
      if (next.isEmpty) return current;
      final step = next.first;
      final loopStart = path.indexOf(step);
      if (loopStart >= 0) {
        // A loop in the links (corrupt data): its smallest member is the
        // top, never an item that only leads into it.
        return (path.sublist(loopStart)..sort()).first;
      }
      path.add(step);
      current = step;
    }
  }

  final out = <String, Set<String>>{};
  for (final id in hostsOf.keys) {
    final top = topOf(id);
    final folded = out.putIfAbsent(top, () => <String>{});
    if (id != top) folded.add(id);
  }
  return out;
}
```

- [ ] **Step 4:** Rerun; expected PASS. Add the threshold beside `neighborWindow` with a doc comment naming #2853.
- [ ] **Step 5: Commit** `feat(data-quality): overlap and folding rules for shared gear`.

---

### Task 2: Gear-on-dive SQL

**Files:**
- Create: `lib/features/equipment/data/repositories/dive_gear_usage_sql.dart`
- Test: `test/features/equipment/data/repositories/dive_gear_usage_sql_test.dart`

**Interfaces:**
- Produces:
  - `const String kDiveGearUsageSql`: a SELECT yielding columns `dive_id`, `equipment_id`, `link_kind` (`'gearList'`, `'tankCylinder'`, `'tankRegulator'`, `'transmitter'`) over the whole library, usable as `WITH g AS ($kDiveGearUsageSql)` or a subquery.
  - `Future<List<({String diveId, String equipmentId, String linkKind})>> gearUsageForDives(AppDatabase db, Iterable<String> diveIds)`, chunked with `seriesIdChunks`.

The SQL:

```sql
SELECT dive_id, equipment_id, 'gearList' AS link_kind FROM dive_equipment
UNION ALL
SELECT dive_id, equipment_id, 'tankCylinder' FROM dive_tanks
  WHERE equipment_id IS NOT NULL
UNION ALL
SELECT dive_id, regulator_equipment_id, 'tankRegulator' FROM dive_tanks
  WHERE regulator_equipment_id IS NOT NULL
UNION ALL
SELECT t.dive_id, r.transmitter_equipment_id, 'transmitter'
  FROM transmitters r
  JOIN dive_tanks t ON TRIM(t.transmitter_serial) = TRIM(r.transmitter_serial)
  JOIN dives rd ON rd.id = t.dive_id
  WHERE r.transmitter_equipment_id IS NOT NULL
    AND LTRIM(TRIM(r.transmitter_serial), '0') <> ''
    AND (r.diver_id IS NULL OR rd.diver_id IS NULL OR rd.diver_id = r.diver_id)
```

- [ ] **Step 1: Write the failing tests** (test database; seed two divers, items `mask`, `tank`, `reg`, `txItem`, two dives): one row per link kind; a blank or `000` serial gives no transmitter row; a registry row of profile A does not match B's dive; `gearUsageForDives` filters to the given dives.
- [ ] **Step 2:** Run; FAIL (file missing).
- [ ] **Step 3:** Implement the constant and the function (`customSelect('SELECT dive_id, equipment_id, link_kind FROM ($kDiveGearUsageSql) WHERE dive_id IN (...)')`).
- [ ] **Step 4:** Run; PASS.
- [ ] **Step 5: Commit** `feat(equipment): one query for every way gear is on a dive`.

---

### Task 3: Context entities and builder

**Files:**
- Create: `lib/features/data_quality/domain/entities/shared_gear_overlap.dart`
- Modify: `lib/features/data_quality/domain/entities/dive_quality_context.dart`
- Modify: `lib/features/data_quality/data/services/quality_context_builder.dart`
- Test: `test/features/data_quality/data/quality_context_builder_shared_gear_test.dart`

**Interfaces:**
- Produces:

```dart
class SharedGearItem {
  const SharedGearItem({
    required this.equipmentId,
    required this.name,
    required this.thisLinkKinds,
    required this.otherLinkKinds,
    this.hostIds = const {},
    this.installedPartIds = const [],
  });
  final String equipmentId;
  final String name;
  /// Every way the item is on each dive: gearList, tankCylinder,
  /// tankRegulator, transmitter.
  final Set<String> thisLinkKinds;
  final Set<String> otherLinkKinds;
  /// Host (parent_equipment_id), assembly parents and via_equipment_id on
  /// either dive.
  final Set<String> hostIds;
  /// Active items installed in it now.
  final List<String> installedPartIds;
}

class SharedGearOverlap {
  const SharedGearOverlap({
    required this.otherDiveId,
    required this.otherDiverId,
    required this.otherDiverName,
    required this.thisDiverName,
    required this.otherEntry,
    required this.otherExit,
    required this.items,
  });
  final String otherDiveId;
  final String otherDiverId;
  final String otherDiverName;
  final String thisDiverName;
  final DateTime otherEntry;
  final DateTime? otherExit;
  final List<SharedGearItem> items;
}
```

  - `DiveQualityContext.sharedGearOverlaps` (`List<SharedGearOverlap>`, default `const []`).

Builder: `_sharedGearOverlaps(domain.Dive dive)`. When `dive.diverId == null`, return `[]`. Otherwise: gear rows of this dive (`gearUsageForDives`); if none, `[]`. Other dives: `SELECT id, diver_id, entry_time, dive_date_time, exit_time, runtime, bottom_time FROM dives WHERE id != ?1 AND diver_id IS NOT NULL AND diver_id != ?2 AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4` (the `neighborWindow`, as `_neighbors`), exit derived as `_neighbors` derives it. Their gear rows, intersected with this dive's item ids. Names from `divers` and `equipment`; host ids from `equipment.parent_equipment_id`, `equipment_components` parents and both dives' `dive_equipment.via_equipment_id`; installed parts from `equipment WHERE parent_equipment_id IN (...) AND is_active = 1`. Link kinds per side: the set of every kind found on that side. A dive with no shared items is omitted.

Skip the whole load, returning `[]` without a query, when the library has fewer than two profiles: read the profile count once per builder instance and cache it beside `_knownSerialsByDiver`, so a single-profile library pays nothing on any scan.

- [ ] **Step 1: Write the failing tests:** an item on Bill's and Anna's overlapping dives appears with both link kinds and names; a same-profile dive does not appear; a null-profile dive does not appear on either side; a dive outside the window does not; a reg with an installed hose lists the hose under `installedPartIds`; an item on the gear list and a tank slot of one dive reports `gearList`.
- [ ] **Step 2:** Run; FAIL.
- [ ] **Step 3:** Implement; add the field and pass it in `_build`.
- [ ] **Step 4:** Run the new test and `flutter test test/features/data_quality/data/`; PASS.
- [ ] **Step 5: Commit** `feat(data-quality): give the scan other profiles' dives that share gear`.

---

### Task 4: Detector, registry and prefilter

**Files:**
- Create: `lib/features/data_quality/domain/detectors/shared_gear_overlap_detector.dart`
- Modify: `quality_detector_registry.dart`, `data/services/quality_prefilters.dart`
- Test: `test/features/data_quality/domain/detectors/shared_gear_overlap_detector_test.dart`; update the detector-count assertions in `test/features/data_quality/data/quality_prefilters_test.dart` and `test/features/data_quality/presentation/data_quality_settings_page_test.dart`.

**Interfaces:**
- Produces: `SharedGearOverlapDetector` (`id` `shared_gear_overlap`, `version` 1, category `time`). Finding params:

```dart
{
  'equipmentId': top,
  'itemName': name,
  'partIds': [...sorted folded and installed part ids],
  'dives': {
    // Ascending dive-id order, so both sides write the same JSON.
    smallerDiveId: {'diverId': ..., 'diverName': ..., 'entryMs': ..., 'linkKinds': [...sorted]},
    largerDiveId: {...},
  },
}
```

Detect: this interval from `effectiveEntryTime` and `effectiveRuntime` (none: `[]`). For each overlap with a non-null `otherExit` where `gearUseOverlaps` holds: fold the items with `foldToTopmost` (hosts restricted to the shared items), and for each top write `makePair(ctx, otherDiveId:, discriminator: top, severity: QualitySeverity.info, params:)`. `partIds` = folded ids plus the top's `installedPartIds`, deduplicated, sorted.

Prefilter: `'shared_gear_overlap'` = dives with an item shared with a dive of another non-null profile inside the neighbour window. Select the cross-profile dive pairs in the window first, then test shared gear per pair, so the gear lookups run through the `dive_id` indexes (`idx_dive_equipment_dive_id`, `idx_dive_tanks_dive_id`) instead of self-joining every gear row in the library:

```sql
SELECT DISTINCT da.id AS id
FROM dives da
JOIN dives db ON db.id != da.id
  AND da.diver_id IS NOT NULL AND db.diver_id IS NOT NULL
  AND da.diver_id != db.diver_id
  AND ABS(COALESCE(da.entry_time, da.dive_date_time) -
      COALESCE(db.entry_time, db.dive_date_time)) <= ?1
WHERE EXISTS (
  SELECT 1 FROM (<kDiveGearUsageSql>) ga
  JOIN (<kDiveGearUsageSql>) gb ON gb.equipment_id = ga.equipment_id
  WHERE ga.dive_id = da.id AND gb.dive_id = db.id)
```

Check the plan with `EXPLAIN QUERY PLAN` in the prefilter test against a seeded library (two profiles, a few hundred dives) and assert the gear subqueries search by `dive_id`; if SQLite does not push the dive filter into the union, inline the four link branches with `dive_id = da.id` / `= db.id` in each.

- [ ] **Step 1: Write the failing detector tests** with `makeTestDive` / `makeContext` from `test/features/data_quality/helpers/quality_test_helpers.dart`: overlap of 4, 5, 6 minutes (only 6 reports); no runtime: nothing; other exit null: nothing; a reg with two hoses on both dives: one finding with both hoses in `partIds`; two unrelated items: two findings; scanning A against B and B against A gives the same id and byte-identical `jsonEncode(params)` (build both contexts); an item on one dive by gear list and tank slot records both kinds.
- [ ] **Step 2:** Run; FAIL.
- [ ] **Step 3:** Implement the detector, append it to `kQualityDetectors`, add the prefilter key, bump the count assertions by one.
- [ ] **Step 4:** Run `flutter test test/features/data_quality/`; PASS.
- [ ] **Step 5: Commit** `feat(data-quality): find shared gear on two profiles' overlapping dives`.

---

### Task 5: Tolerant finding parsing

**Files:**
- Modify: `lib/features/data_quality/data/repositories/quality_findings_repository.dart`
- Test: `test/features/data_quality/data/quality_findings_repository_test.dart`

`_fromRow` returns `QualityFinding?` (null for a category, severity or status this build does not know, logged at warning for each skipped row; no static cache of logged values) and every caller drops nulls (`whereType<QualityFinding>()` or a null check). `lib/features/settings/presentation/widgets/conflict_data_preview.dart:352-354` parses synced finding rows with the same `byName` calls; it gets the same tolerance (an unreadable row renders as raw data instead of throwing), with its own test.

- [ ] **Step 1: Write the failing test:** insert a `quality_findings` row with category `'gear'`; the findings stream and the open-findings read return the other rows without throwing.
- [ ] **Step 2:** Run; FAIL (ArgumentError from `byName`).
- [ ] **Step 3:** Implement with `QualityCategory.values.asNameMap()[row.category]` and the same for severity and status.
- [ ] **Step 4:** Run the repository tests; PASS.
- [ ] **Step 5: Commit** `fix(data-quality): skip a synced finding this build cannot read`.

---

### Task 6: Strings

Keys (English; translate into ar, de, es, fr, he, hu, it, nl, pt, zh):

| Key | English |
| --- | --- |
| `dataQuality_detector_shared_gear_overlap` | `Shared gear on overlapping dives` |
| `dataQuality_msg_shared_gear_overlap` | `{item} is on {diverA}'s dive at {timeA} and {diverB}'s dive at {timeB}.` |
| `dataQuality_msg_shared_gear_overlap_parts` | `{count, plural, one{Includes {count} installed part.} other{Includes {count} installed parts.}}` |
| `dataQuality_repairLabel_removeGearFromDive` | `Remove from {diver}'s dive` |
| `diveLog_gear_alsoOnDive` | `Also on {diver}'s dive, {time}` |

Place `dataQuality_*` keys after their groups' last key and `diveLog_gear_alsoOnDive` after `diveLog_gear_removePart`. Commit `feat(data-quality): strings for shared gear overlap`.

---

### Task 7: Message, repair and inbox

**Files:**
- Modify: `quality_finding_message.dart` (title and detail cases), `quality_repair_action.dart` (new `RemoveGearFromDiveRepair({diveId, equipmentId, diverName})` and the `shared_gear_overlap` case), `quality_repair_executor.dart` (`removeGearFromDive`), `quality_finding_card.dart` (label), `data_quality_inbox_page.dart` (dispatch)
- Test: `test/features/data_quality/presentation/quality_finding_message_test.dart`, `test/features/data_quality/repairs/repair_mapping_test.dart`, `test/features/data_quality/repairs/quality_repair_executor_test.dart`

`repairOptionsFor` for `shared_gear_overlap`: one `RemoveGearFromDiveRepair` per dive in `dives` whose `linkKinds` is exactly `['gearList']` (anchor dive first), then `GoToDiveRepair` for both dives. A test pins that an item on a dive by gear list and tank slot gets no remove repair for that dive.

`removeGearFromDive({diveId, otherDiveId, equipmentId, findingId})`: snapshot the dive's `dive_equipment` rows as `GearProvenance` (as `BulkDiveEditService` does); if the item is not among them return `noChange`; else run `bulkRemoveEquipment([diveId], [equipmentId])` inside `_db.transaction` (it writes a gear diff and a dive bump and documents "No notify/txn"), then `SyncEventBus.notifyLocalChange()` and `_finish(findingId, [diveId, otherDiveId])`; undo writes the snapshot with `replaceGearRows` in a transaction and rescans both dives.

Message: times through `fmt.time` (add a `time` formatter to `QualityUnitFormatters` if it has none, built on `UnitFormatter.formatTime`); missing names read `sharedItems_ownerUnknown`; the parts sentence appended when `partIds` is non-empty.

- [ ] Steps: failing tests for the message text, the repair list (gear-list side only), the executor (removes, noChange when already gone, undo restores provenance), then implement, run `flutter test test/features/data_quality/`, commit `feat(data-quality): remove shared gear from one of two overlapping dives`.

---

### Task 8: Inline note provider

**Files:**
- Create: `lib/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart`
- Test: `test/features/dive_log/presentation/providers/shared_gear_overlap_providers_test.dart`

**Interfaces:**
- `typedef SharedGearOverlapQuery = ({String? diveId, String? diverId, DateTime entry, DateTime? exit});`
- `typedef SharedGearNote = ({String diverName, DateTime entry});`
- `final sharedGearOverlapProvider = FutureProvider.autoDispose.family<Map<String, SharedGearNote>, SharedGearOverlapQuery>`: empty with one profile, no `diverId` or no `exit`; else other-profile dives in the window whose interval overlaps (`gearUseOverlaps`), their gear rows (`gearUsageForDives`), keyed by equipment id (earliest entry wins). Excludes `diveId`. Refreshes on `watchDiveDetailChanges`.

- [ ] Steps: failing tests (new dive without id; moved time in and out of the overlap; same-profile and null-profile dives ignored; one profile gives empty), implement, PASS, commit `feat(dive-log): find other profiles' overlapping dives that share gear`.

---

### Task 9: Show the note

**Files:**
- Modify: `dive_gear_tree_view.dart` (optional `overlapNote`; a second subtitle line with `Icons.info_outline` size 14 in the muted style), `equipment_picker_sheet.dart` (same parameter; a line in `_subtitle`'s column), `dive_edit_page.dart` (build the query from `_existingDive?.diverId ?? activeDiverId`, `_currentEntryTime()`, `_currentDiveEndTime()`, `widget.diveId`; pass `overlapNote` to the gear tree at line ~3910 and to the single-dive picker at ~4082, not the bulk picker)
- Test: `dive_gear_tree_view_test.dart`, `equipment_picker_sheet_test.dart`, a dive edit page test that the note appears for an overlapping other-profile dive and follows a time change.

Note text: `l10n.diveLog_gear_alsoOnDive(note.diverName, UnitFormatter(settings).formatTime(note.entry))`.

- [ ] Steps: failing widget tests, implement, PASS, commit `feat(dive-log): note gear also on another profile's overlapping dive`.

---

### Task 10: Rescans where gear is attached silently

For each of `dive_computer_gear_linker.dart`, `dive_equipment_defaulter.dart`, `equipment_set_for_computer_linker.dart` and `DiveRepository.rewriteAssemblyOnPastDives`: find every caller (`grep -rn`), and check whether a `scheduleQualityScan` covering the same dives follows in that caller's flow (import paths call it after their gear steps). For each writer with a path that does not, add `scheduleQualityScan(diveIds)` after its write and a test that the rescan happens: seed two profiles' overlapping dives, run the writer, `await QualityScanScheduler.instance.idle`, and assert the `shared_gear_overlap` finding row exists (the scheduler exposes no hook to capture scheduled ids). A test that sets `QualityScanScheduler.enabled` restores it in `addTearDown`. Ledger the ones already covered. Commit `fix(data-quality): rescan dives whose gear changes without a save`.

---

### Task 11: Whole-branch checks

`dart format .`, `flutter analyze`, `flutter test test/architecture/`, `flutter test test/features/data_quality test/features/dive_log test/features/equipment test/l10n`.
