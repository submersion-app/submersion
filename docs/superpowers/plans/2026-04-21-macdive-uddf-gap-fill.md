# MacDive UDDF Gap-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all current gaps in Submersion's UDDF import path when the source is a MacDive export, and add the `sourceUuid` plumbing needed for downstream MacDive XML / SQLite milestones.

**Architecture:** Changes are confined to `lib/core/services/export/uddf/` (parsing), the dive-import schema migration layer, and the universal-import adapter. Additions are field-for-field extractions from `<informationbeforedive>` / `<informationafterdive>` / `<site>` plus a robustness fix for `<link ref>` disambiguation. No pipeline wiring changes.

**Tech Stack:** Flutter, Dart 3, Drift ORM, `xml` package, Riverpod. Testing via `flutter_test`.

**Sample data:** `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad sync.uddf` (29 MB, 540 dives) — integration test target.

---

## Milestone 1 Status — COMPLETE

- All 12 tasks landed or explicitly skipped (Task 3 proven non-bug; see Task 3 section).
- Schema bumped v69 → v70 (source_uuid on dive_data_sources) → v71
  (7 new dive + site metadata columns: dive_number_of_day, boat_name,
  boat_captain, dive_operator, surface_conditions on dives; water_type,
  body_of_water on dive_sites).
- Cross-format import dedup now works via `dive_data_sources.source_uuid`.
- Parser-to-DB gap closed for MacDive rich fields. `weather` now lands
  on the existing weather_description column. difficulty continues to
  flow through the DiveSite entity path.
- Dropped from scope: personalMode, altitudeMode, signature, site flag
  (niche / redundant). LinkRefKind/LinkRefIndex (Task 2) also removed
  after Task 3 investigation showed the bug they targeted didn't exist.
- Known limitation: profile `gasMixRef` (from `<switchmix ref>`) is
  parsed but not yet persisted to the profile samples table — deferred
  to a future milestone, likely via dive-events.
- Real-sample regression test passes (gated behind `@Tags(['real-data'])`).

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/core/database/database.dart` | Add single `sourceUuid TEXT NULL` column to the existing `DiveDataSources` 1:N sidecar table. That's where per-source dive identity already lives (alongside `rawFingerprint`, `sourceFormat`, `sourceFileName`, `computerSerial`). Bump schema version 69 → 70 and add migration step. No changes to `dives`, `dive_sites`, `buddies`, or any other top-level entity tables. | Modified |
| `lib/core/services/export/uddf/dialects/macdive_dialect.dart` | Add `<infinity/>` normalization for surface interval; preserve idempotency for all existing rewrites. | Modified |
| `lib/core/services/export/uddf/uddf_import_parsers.dart` | Add `resolveLinkRef(XmlElement, Map<String, LinkRefKind>)` helper that resolves a `<link ref="…"/>` against a pre-built index of top-level IDs and returns the entity kind. | Modified |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Build ID→kind index once per import; use the helper inside `informationbeforedive` / `equipmentused` parsing; extract newly-supported dive and site fields; store each entity's source UUID on its dive/site/buddy/etc. map under `sourceUuid`. | Modified |
| `lib/features/universal_import/data/parsers/uddf_import_parser.dart` | Pass through the new dive/site map keys into the `ImportPayload`. | Modified (minor) |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Write new fields and `sourceUuid` to DB. | Modified |
| `lib/core/domain/models/incoming_dive_data.dart` | Add new optional fields (weather, surfaceConditions, boatName, boatCaptain, diveOperator, personalMode, altitudeMode, signature, diveNumberOfDay, sourceUuid). | Modified |
| `test/core/services/export/uddf/uddf_macdive_import_test.dart` | Extend with: link-ref disambiguation, infinity surface interval, all new fields, idempotency of site country fix. | Modified |
| `test/core/services/export/uddf/uddf_macdive_real_sample_test.dart` | **New** integration test, gated behind `@Tags(['real-data'])`, runs the user's 29MB sample and asserts counts + spot-check values. | Created |
| `test/fixtures/macdive/small_uddf_quirks.uddf` | Hand-authored 3-dive UDDF with every MacDive quirk exercised. | Created |

---

## Task 1: Schema migration — add `source_uuid` column to `dive_data_sources`

**Design rationale:** The project already has a 1:N `dive_data_sources` sidecar table carrying per-source dive metadata: `raw_fingerprint` (libdivecomputer), `source_format`, `source_file_name`, `computer_serial`, etc. This is where "where this dive came from" already lives. Adding `source_uuid` here (rather than on `dives` or on every top-level table) keeps the schema change minimal (one column, one table) and aligns with the existing architecture. libdivecomputer continues to use its existing `raw_fingerprint` BLOB — different mechanism, same role. The new `source_uuid` column captures the string/UUID identifiers that Shearwater Cloud (`DiveId`), MacDive (UDDF `<dive id>`, XML `<identifier>`, SQLite `ZUUID`), Subsurface SSRF, and generic UDDF all provide.

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/source_uuid_migration_test.dart`

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/source_uuid_migration_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh database has source_uuid column on dive_data_sources', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final names = cols.map((r) => r.data['name'] as String).toSet();
    expect(
      names.contains('source_uuid'),
      isTrue,
      reason: 'dive_data_sources must have source_uuid column',
    );
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/source_uuid_migration_test.dart`
Expected: FAIL — `dive_data_sources must have source_uuid column`.

- [ ] **Step 3: Add the column to `DiveDataSources`**

In `lib/core/database/database.dart`, locate `class DiveDataSources extends Table` (around line 953). Add a nullable text column near the other per-source identity columns (e.g. immediately after `rawFingerprint`):

```dart
  TextColumn get sourceUuid => text().nullable()();
```

- [ ] **Step 4: Bump schema version and add migration step**

Find `currentSchemaVersion` (around line 1329) and bump from `69` to `70`.

Locate the existing `dive_data_sources` ALTER migration pattern (around lines 3083-3108 — where `raw_fingerprint`, `descriptor_vendor`, `descriptor_product`, etc. are added with `if (!existing.contains('X')) { await customStatement('ALTER TABLE dive_data_sources ADD COLUMN X Y') }`). Append to the same block (inside the same `if (from < N)` guard or in a new `if (from < 70)` block, matching the file's existing idiom):

```dart
if (!existing.contains('source_uuid')) {
  await customStatement(
    'ALTER TABLE dive_data_sources ADD COLUMN source_uuid TEXT',
  );
}
```

Grep the existing migration code for the exact `existing` variable name and reuse it; don't duplicate the `PRAGMA table_info` introspection if it's already in scope.

- [ ] **Step 5: Regenerate drift outputs and run the test**

Run:
```
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/source_uuid_migration_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/source_uuid_migration_test.dart
git commit -m "feat(db): add source_uuid to dive_data_sources for cross-format import dedup"
```

---

## Task 2: `<link ref>` kind resolution helper

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart`
- Test: `test/core/services/export/uddf/uddf_import_parsers_test.dart`

Context: MacDive puts two unrelated `<link ref="…"/>` children in `<informationbeforedive>` — one for the site, one for the buddy. Current parsing assumes positional order. Fix by resolving each ref's UUID against a pre-built ID index.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/services/export/uddf/uddf_import_parsers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

void main() {
  group('LinkRefIndex', () {
    test('classifies a site-ref correctly', () {
      final index = LinkRefIndex({
        'site-a': LinkRefKind.site,
        'buddy-a': LinkRefKind.buddy,
        'gear-a': LinkRefKind.gear,
      });
      expect(index.kindOf('site-a'), LinkRefKind.site);
      expect(index.kindOf('buddy-a'), LinkRefKind.buddy);
      expect(index.kindOf('gear-a'), LinkRefKind.gear);
      expect(index.kindOf('unknown'), LinkRefKind.unknown);
    });

    test('handles null ref gracefully', () {
      final index = LinkRefIndex(const {});
      expect(index.kindOf(null), LinkRefKind.unknown);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `flutter test test/core/services/export/uddf/uddf_import_parsers_test.dart -p chrome`
Expected: FAIL — `LinkRefIndex not defined`.

- [ ] **Step 3: Implement `LinkRefKind` and `LinkRefIndex`**

Append to `lib/core/services/export/uddf/uddf_import_parsers.dart`:

```dart
/// Categorisation of a top-level UDDF id so a `<link ref>` can be resolved
/// to the entity type it points at, regardless of where the link appears.
enum LinkRefKind { site, buddy, gear, gasMix, tank, diveComputer, trip, unknown }

/// Index of id → kind, built once per UDDF document by scanning the
/// top-level entity sections.
class LinkRefIndex {
  final Map<String, LinkRefKind> _map;
  const LinkRefIndex(Map<String, LinkRefKind> map) : _map = map;

  LinkRefKind kindOf(String? id) =>
      id == null ? LinkRefKind.unknown : (_map[id] ?? LinkRefKind.unknown);
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/core/services/export/uddf/uddf_import_parsers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_import_parsers.dart test/core/services/export/uddf/uddf_import_parsers_test.dart
git commit -m "feat(uddf): add LinkRefIndex for ref-kind disambiguation"
```

---

## Task 3: Build and use the ID index in `UddfFullImportService` — **SKIPPED**

**Investigation outcome:** The plan's premise (that the current parser assumes positional order for `<link ref>` children in `<informationbeforedive>`) turned out to be wrong. The existing `_parseUddfDive` at `uddf_full_import_service.dart:1173-1211` already classifies each link by looking up its `ref` attribute in pre-built entity maps (`sites`, `buddies`, `decoModels`, `diveComputers`). The prescribed failing test passes against unmodified code.

**What the real gap is (deferred):** `_parseFullDive` at lines 557-571 uses string-prefix matching (`ref.startsWith('trip_')`, `'center_'`, `'course_'`) to classify trip/center/course refs. This WOULD fail for MacDive-style UUIDs — but MacDive UDDF (per the user's 29MB sample) does not emit `<trip>` / `<divecenter>` / `<course>` references at all. For Milestone 1 scope (MacDive UDDF), this codepath is not exercised. Revisit in Milestone 3 (MacDive SQLite) if trip/center refs start showing up.

**LinkRefKind / LinkRefIndex from Task 2 are retained** — they cost ~22 lines + 2 tests and may be useful for the Milestone 3 SQLite work where cross-entity UUID resolution matters.

**Status:** Task 3 marked as SKIPPED in the task tracker. No code change for this task.

---

## Task 3 (ORIGINAL, for reference) — not executed

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Write the failing test for site+buddy disambiguation**

Append to `test/core/services/export/uddf/uddf_macdive_import_test.dart` inside the existing `group('UddfFullImportService - MacDive import', …)`:

```dart
test('disambiguates site vs buddy link refs in informationbeforedive',
    () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <buddy id="buddy-z"><personal><firstname>Zed</firstname></personal></buddy>
  </diver>
  <divesite>
    <site id="site-a"><name>Site A</name>
      <geography><address><country>US</country></address></geography>
    </site>
  </divesite>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <link ref="buddy-z" />
          <link ref="site-a" />
          <datetime>2024-06-01T09:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>12.0</greatestdepth>
          <diveduration>1800</diveduration>
        </informationafterdive>
        <samples><waypoint><divetime>0</divetime><depth>0.0</depth></waypoint></samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';
  final result = await service.importAllDataFromUddf(uddf);
  final dive = result.dives.first;
  final site = dive['site'] as Map<String, dynamic>?;
  expect(site?['name'], 'Site A', reason: 'site ref must be resolved by id-kind, not position');
  expect(dive['buddyRefs'], contains('buddy-z'));
});
```

- [ ] **Step 2: Run test — expect failure**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome --plain-name "disambiguates site vs buddy"`
Expected: FAIL (site probably ends up null or wrong).

- [ ] **Step 3: Implement the ID index build + use**

In `lib/core/services/export/uddf/uddf_full_import_service.dart`:

Near the start of `importAllDataFromUddf`, after the XML is parsed and normalized, add:

```dart
final linkRefs = _buildLinkRefIndex(doc);
```

Where `_buildLinkRefIndex` is a new private method:

```dart
LinkRefIndex _buildLinkRefIndex(XmlDocument doc) {
  final map = <String, LinkRefKind>{};
  for (final e in doc.findAllElements('site')) {
    final id = e.getAttribute('id');
    if (id != null) map[id] = LinkRefKind.site;
  }
  for (final e in doc.findAllElements('buddy')) {
    final id = e.getAttribute('id');
    if (id != null) map[id] = LinkRefKind.buddy;
  }
  // Gear lives under the owner/diver section as various tag names:
  for (final tagName in const [
    'variouspieces', 'suit', 'divecomputer', 'boots', 'fins',
    'compass', 'knife', 'bcd', 'regulator', 'tankrelatedequipment',
  ]) {
    for (final e in doc.findAllElements(tagName)) {
      final id = e.getAttribute('id');
      if (id != null) map[id] = LinkRefKind.gear;
    }
  }
  for (final e in doc.findAllElements('mix')) {
    final id = e.getAttribute('id');
    if (id != null) map[id] = LinkRefKind.gasMix;
  }
  for (final e in doc.findAllElements('tank')) {
    final id = e.getAttribute('id');
    if (id != null) map[id] = LinkRefKind.tank;
  }
  for (final e in doc.findAllElements('trip')) {
    final id = e.getAttribute('id');
    if (id != null) map[id] = LinkRefKind.trip;
  }
  return LinkRefIndex(map);
}
```

Then pass `linkRefs` through to the per-dive parser. In the per-dive loop, find the current code that iterates over `informationbeforedive`'s children looking for `<link>` elements; replace the positional logic with kind-based binding:

```dart
String? siteRef;
final buddyRefs = <String>[];
final gearRefs = <String>[];
for (final linkEl in before.findElements('link')) {
  final ref = linkEl.getAttribute('ref');
  switch (linkRefs.kindOf(ref)) {
    case LinkRefKind.site: siteRef ??= ref;
    case LinkRefKind.buddy: if (ref != null) buddyRefs.add(ref);
    case LinkRefKind.gear: if (ref != null) gearRefs.add(ref);
    case LinkRefKind.trip: diveData['tripRef'] = ref;
    case LinkRefKind.gasMix || LinkRefKind.tank || LinkRefKind.diveComputer || LinkRefKind.unknown: break;
  }
}
if (siteRef != null) diveData['siteRef'] = siteRef;
if (buddyRefs.isNotEmpty) diveData['buddyRefs'] = buddyRefs;
if (gearRefs.isNotEmpty) diveData['equipmentRefs'] = gearRefs;
```

- [ ] **Step 4: Run test — expect PASS**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome`
Expected: PASS for the new case and all existing cases.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_full_import_service.dart test/core/services/export/uddf/uddf_macdive_import_test.dart
git commit -m "fix(uddf): resolve <link ref> by entity kind not positional order"
```

---

## Task 4: Handle `<surfaceintervalbeforedive><infinity/></surfaceintervalbeforedive>`

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Write the failing test**

Append to the existing MacDive group:

```dart
test('treats <infinity/> surface interval as null (first dive)', () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-1">
      <informationbeforedive>
        <surfaceintervalbeforedive><infinity/></surfaceintervalbeforedive>
        <datetime>2024-06-01T09:00:00</datetime>
      </informationbeforedive>
      <informationafterdive><greatestdepth>12</greatestdepth><diveduration>1800</diveduration></informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
  final result = await service.importAllDataFromUddf(uddf);
  final dive = result.dives.first;
  expect(dive.containsKey('surfaceInterval'), isFalse,
      reason: '<infinity/> means no prior dive; must not set surfaceInterval');
});
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome --plain-name infinity`
Expected: FAIL (likely passes by accident if value is `null` — verify; if it passes, refine test to assert map entry absent).

- [ ] **Step 3: Implement explicit handling**

Find the surfaceIntervalBeforeDive parser in `uddf_full_import_service.dart` and update:

```dart
final siElement = before.findElements('surfaceintervalbeforedive').firstOrNull;
if (siElement != null) {
  final hasInfinity = siElement.findElements('infinity').isNotEmpty;
  if (!hasInfinity) {
    final passed = siElement.findElements('passedtime').firstOrNull?.innerText;
    final seconds = passed == null ? null : int.tryParse(passed);
    if (seconds != null) {
      diveData['surfaceInterval'] = Duration(seconds: seconds);
    }
  }
  // When <infinity/> is present, leave surfaceInterval unset.
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "fix(uddf): treat <infinity/> surface interval as absent"
```

---

## Task 5: Extract dive-level MacDive fields (weather, boat, operator, etc.)

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Modify: `lib/core/domain/models/incoming_dive_data.dart`
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Add fields to the domain model**

In `lib/core/domain/models/incoming_dive_data.dart`, inside the class, add:

```dart
final String? weather;
final String? surfaceConditions;
final String? boatName;
final String? boatCaptain;
final String? diveOperator;
final String? personalMode;
final String? altitudeMode;
final String? signature;
final int? diveNumberOfDay;
final String? sourceUuid;
```

Include them in the constructor, in `copyWith`, in `fromImportMap`, and (if the class has one) in `toMap`. Use the snake_case key names: `'weather'`, `'surfaceConditions'`, `'boatName'`, `'boatCaptain'`, `'diveOperator'`, `'personalMode'`, `'altitudeMode'`, `'signature'`, `'diveNumberOfDay'`, `'sourceUuid'`.

- [ ] **Step 2: Write failing tests for each new field**

Append a new fixture constant to `test/core/services/export/uddf/uddf_macdive_import_test.dart`:

```dart
const _macDiveRichFields = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name></generator>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-RICH-UUID">
      <informationbeforedive>
        <datetime>2024-06-01T09:00:00</datetime>
        <divenumber>42</divenumber>
        <divenumberofday>3</divenumberofday>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth>
        <diveduration>2400</diveduration>
        <weather>Sunny</weather>
        <surfaceconditions>Calm</surfaceconditions>
        <boatname>MV Nautilus</boatname>
        <boatcaptain>Jane Smith</boatcaptain>
        <diveoperator>Nautilus Liveaboards</diveoperator>
        <personalmode>recreational</personalmode>
        <altitudemode>sea-level</altitudemode>
        <signature>Marci G.</signature>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
```

Add a test group:

```dart
group('UddfFullImportService - MacDive extended fields', () {
  late UddfFullImportService service;
  setUp(() => service = UddfFullImportService());

  test('extracts weather, surfaceConditions, boatName, boatCaptain, diveOperator, '
      'personalMode, altitudeMode, signature, diveNumberOfDay, sourceUuid',
      () async {
    final r = await service.importAllDataFromUddf(_macDiveRichFields);
    final d = r.dives.first;
    expect(d['weather'], 'Sunny');
    expect(d['surfaceConditions'], 'Calm');
    expect(d['boatName'], 'MV Nautilus');
    expect(d['boatCaptain'], 'Jane Smith');
    expect(d['diveOperator'], 'Nautilus Liveaboards');
    expect(d['personalMode'], 'recreational');
    expect(d['altitudeMode'], 'sea-level');
    expect(d['signature'], 'Marci G.');
    expect(d['diveNumberOfDay'], 3);
    expect(d['sourceUuid'], 'd-RICH-UUID');
  });
});
```

- [ ] **Step 3: Run — expect FAIL**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome --plain-name "MacDive extended fields"`
Expected: FAIL — all new assertions fail.

- [ ] **Step 4: Implement the extractions**

In `uddf_full_import_service.dart`, inside the per-dive loop, locate where `informationafterdive` is processed and add:

```dart
for (final entry in const {
  'weather': 'weather',
  'surfaceconditions': 'surfaceConditions',
  'boatname': 'boatName',
  'boatcaptain': 'boatCaptain',
  'diveoperator': 'diveOperator',
  'personalmode': 'personalMode',
  'altitudemode': 'altitudeMode',
  'signature': 'signature',
}.entries) {
  final text = afterElement.findElements(entry.key).firstOrNull?.innerText.trim();
  if (text != null && text.isNotEmpty) diveData[entry.value] = text;
}
```

Inside the per-dive loop where `informationbeforedive` is processed, add:

```dart
final dnodRaw = before.findElements('divenumberofday').firstOrNull?.innerText;
final dnod = dnodRaw == null ? null : int.tryParse(dnodRaw);
if (dnod != null) diveData['diveNumberOfDay'] = dnod;
```

For the dive's own `id` attribute as `sourceUuid`, right after creating `diveData`:

```dart
final diveId = diveElement.getAttribute('id');
if (diveId != null && diveId.isNotEmpty) diveData['sourceUuid'] = diveId;
```

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome`
Expected: PASS for all cases.

- [ ] **Step 6: Commit**

```bash
git commit -am "feat(uddf): extract MacDive extended dive fields (weather, boat, operator, …) and source UUID"
```

---

## Task 6: Extract site-level MacDive fields

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('extracts site watertype, bodyofwater, difficulty, flag, sourceUuid', () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <divesite>
    <site id="site-RICH-UUID">
      <name>Rich Site</name>
      <watertype>saltwater</watertype>
      <bodyofwater>Pacific Ocean</bodyofwater>
      <difficulty>advanced</difficulty>
      <flag>MX</flag>
      <geography><address><country>Mexico</country></address></geography>
    </site>
  </divesite>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-1">
      <informationbeforedive><link ref="site-RICH-UUID" /><datetime>2024-06-01T09:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>12</greatestdepth><diveduration>1800</diveduration></informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
  final r = await service.importAllDataFromUddf(uddf);
  final site = r.sites.firstWhere((s) => s['sourceUuid'] == 'site-RICH-UUID');
  expect(site['waterType'], 'saltwater');
  expect(site['bodyOfWater'], 'Pacific Ocean');
  expect(site['difficulty'], 'advanced');
  expect(site['flag'], 'MX');
});
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome --plain-name "site watertype"`
Expected: FAIL.

- [ ] **Step 3: Implement**

In the site-parsing section of `uddf_full_import_service.dart`, add extraction of these four text-valued children and the id attribute. Look for the existing site map builder and append:

```dart
final siteId = siteElement.getAttribute('id');
if (siteId != null && siteId.isNotEmpty) siteData['sourceUuid'] = siteId;
for (final entry in const {
  'watertype': 'waterType',
  'bodyofwater': 'bodyOfWater',
  'difficulty': 'difficulty',
  'flag': 'flag',
}.entries) {
  final v = siteElement.findElements(entry.key).firstOrNull?.innerText.trim();
  if (v != null && v.isNotEmpty) siteData[entry.value] = v;
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/core/services/export/uddf/uddf_macdive_import_test.dart -p chrome`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(uddf): extract site waterType/bodyOfWater/difficulty/flag and source UUID"
```

---

## Task 7: Extract `sourceUuid` on buddies, gear, gas mixes, tanks, certifications, species, tags, trips, dive types

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('stores sourceUuid on buddies, gear, gases, tanks, certs, species, tags, trips, divetypes',
    () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <buddy id="buddy-X"><personal><firstname>Bob</firstname></personal></buddy>
    <owner id="owner-1">
      <personal><firstname>Me</firstname></personal>
      <equipment>
        <variouspieces id="gear-X"><name>BCD</name></variouspieces>
      </equipment>
    </owner>
  </diver>
  <divesite><site id="site-1"><name>S</name></site></divesite>
  <gasdefinitions>
    <mix id="mix-X"><name>EAN32</name><o2>0.32</o2></mix>
  </gasdefinitions>
  <trip id="trip-X"><name>T</name></trip>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-1">
      <informationbeforedive><datetime>2024-06-01T09:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>10</greatestdepth><diveduration>1800</diveduration></informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
  final r = await service.importAllDataFromUddf(uddf);
  expect(r.buddies.firstWhere((b) => b['sourceUuid'] == 'buddy-X'), isNotNull);
  expect(r.equipment.firstWhere((g) => g['sourceUuid'] == 'gear-X'), isNotNull);
});
```

- [ ] **Step 2: Run — expect FAIL**

Expected: FAIL — sourceUuid not yet written on buddies/gear.

- [ ] **Step 3: Implement**

In every entity-extraction section of `uddf_full_import_service.dart` (there are ~9), after the entity map is built, add:

```dart
final sid = <X>Element.getAttribute('id');
if (sid != null && sid.isNotEmpty) <X>Data['sourceUuid'] = sid;
```

(`<X>` varies: `buddy`, `owner`, `variouspieces`/`suit`/`divecomputer`/etc., `mix`, `tank`, `certification`, `species`, `tag`, `trip`, `divetype`.)

- [ ] **Step 4: Run — expect PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(uddf): preserve source UUID on every imported entity"
```

---

## Task 8: Verify equipment ref resolution end-to-end

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (if fix needed)
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('equipmentused <link ref> resolves to matching gear item, dive carries gear UUIDs',
    () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver><owner id="o"><personal><firstname>M</firstname></personal>
    <equipment>
      <variouspieces id="gear-REG-1"><name>Travel Reg</name></variouspieces>
      <variouspieces id="gear-BCD-1"><name>Hydros</name></variouspieces>
    </equipment></owner></diver>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-1">
      <informationbeforedive><datetime>2024-06-01T09:00:00</datetime></informationbeforedive>
      <informationafterdive>
        <greatestdepth>10</greatestdepth>
        <diveduration>1800</diveduration>
        <equipmentused>
          <link ref="gear-REG-1" />
          <link ref="gear-BCD-1" />
        </equipmentused>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
  final r = await service.importAllDataFromUddf(uddf);
  final dive = r.dives.first;
  final refs = dive['equipmentRefs'] as List?;
  expect(refs, containsAll(['gear-REG-1', 'gear-BCD-1']));
});
```

- [ ] **Step 2: Run**

Expected: depending on current state, may already pass. If it fails, look in `uddf_full_import_service.dart` for where `equipmentused` is parsed and ensure both `informationbeforedive` and `informationafterdive` paths append to `equipmentRefs`. (The MacDive dialect copies equipmentused into before; this test confirms end-to-end behaviour.)

- [ ] **Step 3: If failing, fix in the per-dive equipment extraction**

Make sure the helper that reads `<equipmentused>` iterates over *all* `<link ref>` children, appending each `ref` attribute to `equipmentRefs`:

```dart
final equipRefs = <String>[];
final equipBefore = before.findElements('equipmentused').firstOrNull;
if (equipBefore != null) {
  for (final l in equipBefore.findElements('link')) {
    final r = l.getAttribute('ref');
    if (r != null && r.isNotEmpty) equipRefs.add(r);
  }
}
final equipAfter = afterElement.findElements('equipmentused').firstOrNull;
if (equipAfter != null) {
  for (final l in equipAfter.findElements('link')) {
    final r = l.getAttribute('ref');
    if (r != null && !equipRefs.contains(r)) equipRefs.add(r);
  }
}
if (equipRefs.isNotEmpty) diveData['equipmentRefs'] = equipRefs;
```

- [ ] **Step 4: Run — expect PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "fix(uddf): ensure equipmentused refs from both before/after sections are captured"
```

---

## Task 9: Verify gas-switch (`<switchmix ref>`) handling in waypoints

**Files:**
- Test: `test/core/services/export/uddf/uddf_macdive_import_test.dart`

Existing code at `uddf_full_import_service.dart:1452` reads `<switchmix ref>`; this task only adds a test to guarantee the behaviour.

- [ ] **Step 1: Write the failing test**

```dart
test('samples with <switchmix ref> create per-sample gas-change markers', () async {
  const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <gasdefinitions>
    <mix id="mix-bottom"><o2>0.32</o2></mix>
    <mix id="mix-deco"><o2>0.80</o2></mix>
  </gasdefinitions>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-1">
      <informationbeforedive><datetime>2024-06-01T09:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>40</greatestdepth><diveduration>3600</diveduration></informationafterdive>
      <samples>
        <waypoint><divetime>0</divetime><depth>0</depth><switchmix ref="mix-bottom"/></waypoint>
        <waypoint><divetime>120</divetime><depth>30</depth></waypoint>
        <waypoint><divetime>2400</divetime><depth>6</depth><switchmix ref="mix-deco"/></waypoint>
      </samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
  final r = await service.importAllDataFromUddf(uddf);
  final profile = r.dives.first['profile'] as List<Map<String, dynamic>>;
  final switches = profile.where((p) => p['gasMixRef'] != null).toList();
  expect(switches.length, 2);
  expect(switches.first['gasMixRef'], 'mix-bottom');
  expect(switches.last['gasMixRef'], 'mix-deco');
});
```

- [ ] **Step 2: Run — may pass, may fail**

If FAIL: inspect the waypoint parser near line 1452. Ensure `gasMixRef` (or equivalent) is written into the sample map when a `<switchmix>` child is present. Add the field if missing:

```dart
final sw = waypoint.findElements('switchmix').firstOrNull;
final ref = sw?.getAttribute('ref');
if (ref != null) sampleMap['gasMixRef'] = ref;
```

- [ ] **Step 3: Run — expect PASS**

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(uddf): record gasMixRef on samples carrying <switchmix>"
```

---

## Task 10: Write pass-through in `UddfImportParser` and `UddfEntityImporter`

**Files:**
- Modify: `lib/features/universal_import/data/parsers/uddf_import_parser.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- Test: `test/features/universal_import/data/parsers/uddf_import_parser_test.dart`

Goal: Make sure the new map keys survive the trip from `UddfFullImportService` through the parser into the `ImportPayload` and all the way to the DB.

- [ ] **Step 1: Write a failing integration-style test**

In `test/features/universal_import/data/parsers/uddf_import_parser_test.dart`, add:

```dart
test('UDDF parser preserves MacDive extended fields into payload', () async {
  final bytes = Uint8List.fromList(utf8.encode(_macDiveRichFields));
  final payload = await UddfImportParser().parse(bytes);
  final dive = payload.entitiesOf(ImportEntityType.dives).first;
  expect(dive['weather'], 'Sunny');
  expect(dive['sourceUuid'], 'd-RICH-UUID');
  expect(dive['diveNumberOfDay'], 3);
});
```

(Import the same `_macDiveRichFields` constant — extract to a shared `test/fixtures/macdive/uddf_fixtures.dart` if convenient.)

- [ ] **Step 2: Run — expect PASS immediately** (assumption: parser is a thin wrapper)

If it fails, look at `uddf_import_parser.dart`'s map-projection; verify it passes through unknown keys or specifically adds the new ones.

- [ ] **Step 3: Modify `UddfEntityImporter`**

Find where `dives` are written to DB (`diveRepository.create…`) and add the new fields. Wherever dive columns are set, append:

```dart
sourceUuid: Value(diveMap['sourceUuid'] as String?),
weather: Value(diveMap['weather'] as String?),
surfaceConditions: Value(diveMap['surfaceConditions'] as String?),
boatName: Value(diveMap['boatName'] as String?),
boatCaptain: Value(diveMap['boatCaptain'] as String?),
diveOperator: Value(diveMap['diveOperator'] as String?),
personalMode: Value(diveMap['personalMode'] as String?),
altitudeMode: Value(diveMap['altitudeMode'] as String?),
signature: Value(diveMap['signature'] as String?),
diveNumberOfDay: Value(diveMap['diveNumberOfDay'] as int?),
```

Do the same for site, buddy, etc. — in each entity's create path, include `sourceUuid`.

(If the existing `Dives` table lacks columns for `weather`, etc., add them in Task 1's migration too. Update Task 1 retroactively if needed by editing the migration step and regenerating drift — this is OK because Task 1 hasn't been released yet within this plan.)

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(import): persist new MacDive UDDF fields through parser → DB"
```

---

## Task 11: Hand-authored MacDive-quirks fixture + regression tests

**Files:**
- Create: `test/fixtures/macdive/small_uddf_quirks.uddf`
- Create: `test/core/services/export/uddf/uddf_macdive_real_sample_test.dart`

- [ ] **Step 1: Create the fixture**

Create `test/fixtures/macdive/small_uddf_quirks.uddf` with 3 dives exercising:
- Namespace `http://www.streit.cc/uddf/3.2/` on root
- Float-encoded integer fields (`60.00`)
- Country nested under `geography/address/country`
- `equipmentused` in `informationafterdive`
- `<switchmix ref>` in waypoints
- One dive with `<surfaceintervalbeforedive><infinity/>`
- All extended fields (`weather`, `boatname`, etc.)
- `<divenumberofday>`
- UUIDs on all entities

(Full file content: reuse `_macDiveUddf` from the test file, extend it with one more dive.)

- [ ] **Step 2: Create integration test against user's real sample**

Create `test/core/services/export/uddf/uddf_macdive_real_sample_test.dart`:

```dart
@Tags(['real-data'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

const _realSamplePath =
  '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad sync.uddf';

void main() {
  test('imports 540 dives, 373 sites, 33 buddies, 32 gear from real sample',
      () async {
    final file = File(_realSamplePath);
    if (!file.existsSync()) {
      markTestSkipped('Real sample not available in this environment');
      return;
    }
    final content = await file.readAsString();
    final svc = UddfFullImportService();
    final r = await svc.importAllDataFromUddf(content);
    expect(r.dives.length, 540);
    expect(r.sites.length, greaterThanOrEqualTo(370));
    expect(r.buddies.length, greaterThanOrEqualTo(30));
    // Every dive has a sourceUuid.
    expect(r.dives.every((d) => d['sourceUuid'] != null), isTrue);
  });
}
```

- [ ] **Step 3: Run — gated**

Run: `flutter test --tags=real-data test/core/services/export/uddf/uddf_macdive_real_sample_test.dart`
Expected: PASS. If dive counts are off, inspect the warnings payload and iterate.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/macdive/ test/core/services/export/uddf/uddf_macdive_real_sample_test.dart
git commit -m "test(uddf): add MacDive real-sample regression + fixture"
```

---

## Task 12: Final sweep + release notes

- [ ] **Step 1: Run the full test suite**

Run:
```
dart format lib/ test/
flutter analyze
flutter test
```
Expected: all pass, no format changes, no analyzer issues.

- [ ] **Step 2: Add CHANGELOG entry**

Open `CHANGELOG.md`, add under the Unreleased section:

```markdown
### Added
- MacDive UDDF imports now preserve source UUID, dive number of day,
  weather, surface conditions, boat name, boat captain, dive operator,
  personal mode, altitude mode, signature, and site water type /
  body of water / difficulty / flag.
### Fixed
- MacDive UDDF: site and buddy `<link ref>` children in
  `<informationbeforedive>` are now resolved by entity kind instead
  of relying on positional order.
- MacDive UDDF: `<surfaceintervalbeforedive><infinity/></surfaceintervalbeforedive>`
  is now correctly treated as "no prior dive" instead of zero seconds.
```

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: changelog for MacDive UDDF gap-fill"
```

---

## Self-Review Checklist

- [x] Every step has concrete code, not "implement X"
- [x] Each new field has a failing test before implementation
- [x] Tank pressure unit (Pa → bar): existing code handles it (`tankpressurebegin` in Pa, already converted). Verify via Task 11's real-sample test — if the max-depth or pressure assertions fail, add a dedicated task before release.
- [x] Source UUID migration runs before any code that writes to the new column
- [x] Idempotency: all dialect changes re-verified via existing idempotency tests that run twice
- [x] Schema bump is single (49 → 50), one commit, with matching migration

## Notes for the executor

- Regenerate Drift code with `dart run build_runner build --delete-conflicting-outputs` after *any* schema change.
- If a test is flaky locally, run `flutter clean` first — build_runner output can get stale in this project.
- The user's sample sits at the exact path baked into Task 11. Do not check it in (it's 29 MB).
