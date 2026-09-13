# MacDive Multi-Diver Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One MacDive import (SQLite or XML) writes each MacDive diver's dives and certifications to the Submersion profile the user picks in a new "Divers" wizard step, with shared sites, buddies, gear and tags following the dives that use them.

**Architecture:** Parsers describe the source's divers (`SourceDiver`) and stamp `sourceDiverKey` on dives and certifications. A new wizard step records a mapping per diver (`DiverTarget`). A pure `PayloadDiverExpander` rewrites the payload so every item carries `_targetKey`, copying shared items per target. `PayloadSlicer` splits that payload per target, and `UniversalAdapter` runs its existing duplicate check and the unchanged `UddfEntityImporter` once per slice, mapping indices back to the full payload.

**Tech Stack:** Flutter 3.47, Dart 3 (sealed classes, patterns, records), Riverpod (`StateNotifier`, legacy providers), Drift, mockito, `flutter_test`, `sqlite3` (test fixtures), `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-13-macdive-multi-diver-import-design.md`

## Global Constraints

- Issue: #1893. The PR description must contain `Closes #1893`.
- Single-diver imports behave exactly as today: no Divers step, no expansion, same duplicate check, same importer call with the active diver's id.
- `UddfEntityImporter` (`lib/features/dive_import/data/services/uddf_entity_importer.dart`) is not modified.
- Never write the em-dash character (U+2014), and never use an en-dash, `--` or ` - ` as sentence punctuation, in code, comments, docs, commit messages or PR text.
- No AI tool attribution, co-author trailers, "generated with" lines or session links in any commit, PR, comment or file.
- No emojis in code, comments or docs.
- Files 200 to 400 lines typical, 800 max. `universal_adapter.dart` is already 1,438 lines: put new logic in new files and keep the additions there thin.
- Imports grouped: dart, flutter, packages, local; package imports use `package:submersion/...`.
- Run `dart format .` before every commit.
- Stage explicit paths only (never `git add -A` / `git add .`).
- Test commands: `flutter test <path>`; never pipe `flutter test` into `grep` (it hides the exit code). Run single files, not directories.
- New user-facing strings go in `lib/l10n/arb/app_en.arb` and all 10 other locale files (`ar de es fr he hu it nl pt zh`), then `flutter gen-l10n`; commit the ARB files and the regenerated `lib/l10n/arb/app_localizations*.dart` together.
- Payload bookkeeping keys: `sourceDiverKey` (`SourceDiver.mapKey`) on dive and certification maps; `_targetKey` (`DiverTarget.itemKey`) on every item of an expanded payload.

## File Structure

**Create:**
- `lib/features/universal_import/data/models/source_diver.dart`: `SourceDiver`, `orderedDiverRows`.
- `lib/features/universal_import/data/models/diver_target.dart`: sealed `DiverTarget` (`ExistingDiverTarget`, `NewDiverTarget`, `SkipDiverTarget`) and target-key helpers.
- `lib/features/universal_import/data/services/payload_ref_keys.dart`: the dive-to-entity reference keys shared by the merger and the expander.
- `lib/features/universal_import/data/services/default_diver_mapping.dart`: the Divers step's preselected targets.
- `lib/features/universal_import/data/services/payload_diver_expander.dart`: splits a payload across targets.
- `lib/features/universal_import/data/services/payload_slicer.dart`: `DiverSlice`, `PayloadSlicer`.
- `lib/features/universal_import/data/services/diver_slice_duplicates.dart`: remaps duplicate results between slice and full indices.
- `lib/features/import_wizard/data/adapters/existing_import_records.dart`: per-target existing records for the duplicate check.
- `lib/features/import_wizard/data/adapters/diver_slice_review.dart`: one slice's bundle, selections and actions; result merging.
- `lib/features/import_wizard/domain/models/diver_import_outcome.dart`: what one import wrote to one profile.
- `lib/features/import_wizard/presentation/widgets/diver_mapping_step.dart`: the Divers step.
- `lib/features/import_wizard/presentation/widgets/import_target_chip.dart`: the per-row target label.
- `lib/features/import_wizard/presentation/widgets/import_summary_diver_outcomes.dart`: the Summary's "By profile" section.

**Modify:**
- `lib/features/universal_import/data/models/import_payload.dart` (`sourceDivers`, `needsDiverMapping`)
- `lib/features/universal_import/data/services/payload_merger.dart` (shared ref keys, merge `sourceDivers`)
- `lib/features/universal_import/data/services/macdive_raw_types.dart`, `macdive_db_reader.dart`, `macdive_dive_mapper.dart`
- `lib/features/universal_import/data/parsers/macdive_xml_parser.dart`, `lib/features/universal_import/data/services/macdive_xml_models.dart` (comment)
- `lib/features/universal_import/presentation/providers/universal_import_state.dart`, `universal_import_providers.dart`
- `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- `lib/features/import_wizard/domain/models/import_bundle.dart` (`ImportTarget`, `EntityItem.target`, `ImportBundle.nextDiveNumberByTarget`)
- `lib/features/import_wizard/domain/models/unified_import_result.dart` (`diverOutcomes`)
- `lib/features/import_wizard/presentation/widgets/review_step.dart`, `entity_review_list.dart`, `duplicate_action_card.dart`, `import_summary_step.dart`
- `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (`_applyImportTags`)
- `lib/l10n/arb/app_*.arb` (11 files) and generated `app_localizations*.dart`
- `test/fixtures/macdive_sqlite/build_synthetic_db.dart`

**Worktree:** already initialized (submodules, `flutter pub get`, codegen via `scripts/setup.sh`). If a DB-touching test fails with `database.g.dart: No such file or directory`, run `bash scripts/setup.sh`.

---

### Task 1: SourceDiver and ImportPayload.sourceDivers

**Files:**
- Create: `lib/features/universal_import/data/models/source_diver.dart`
- Modify: `lib/features/universal_import/data/models/import_payload.dart`
- Test: `test/features/universal_import/data/models/source_diver_test.dart`

**Interfaces:**
- Produces: `class SourceDiver` (`key`, `name`, `diveCount`, `certificationCount`, `email`, `phone`, `emergencyContact`, `bloodType`, `danNumber`, `isUnowned`, `hasRecords`, `copyWith({int? diveCount, int? certificationCount})`, `static const unownedKey = '_unowned'`, `static const mapKey = 'sourceDiverKey'`); `List<SourceDiver> orderedDiverRows(List<SourceDiver>)`; `ImportPayload.sourceDivers` (`List<SourceDiver>`, default `const []`); `ImportPayload.needsDiverMapping` (`bool`).

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/models/source_diver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';

void main() {
  group('ImportPayload.needsDiverMapping', () {
    ImportPayload withDivers(List<SourceDiver> divers) =>
        ImportPayload(entities: const {}, sourceDivers: divers);

    test('is false with no source divers', () {
      expect(withDivers(const []).needsDiverMapping, isFalse);
    });

    test('is false for one diver plus dives with no diver', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 503),
        SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 37),
      ]);
      expect(payload.needsDiverMapping, isFalse);
    });

    test('is true for two divers with records', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 3),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray', certificationCount: 1),
      ]);
      expect(payload.needsDiverMapping, isTrue);
    });

    test('ignores a diver with no records', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 3),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray'),
      ]);
      expect(payload.needsDiverMapping, isFalse);
    });
  });

  group('orderedDiverRows', () {
    test('orders by dive count then name, unowned last, empty dropped', () {
      final rows = orderedDiverRows(const [
        SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 9),
        SourceDiver(key: 'macdive:c', name: 'Cy Park', diveCount: 2),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray', diveCount: 5),
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 2),
        SourceDiver(key: 'macdive:z', name: 'Zed'),
      ]);
      expect(rows.map((r) => r.key), [
        'macdive:b',
        'macdive:a',
        'macdive:c',
        SourceDiver.unownedKey,
      ]);
    });
  });

  test('copyWith changes only the counts', () {
    const ann = SourceDiver(
      key: 'macdive:a',
      name: 'Ann Lee',
      diveCount: 1,
      email: 'ann@example.com',
    );
    expect(
      ann.copyWith(diveCount: 4, certificationCount: 2),
      const SourceDiver(
        key: 'macdive:a',
        name: 'Ann Lee',
        diveCount: 4,
        certificationCount: 2,
        email: 'ann@example.com',
      ),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/models/source_diver_test.dart`
Expected: FAIL to compile: `source_diver.dart` not found, `sourceDivers` not a parameter.

- [ ] **Step 3: Create `source_diver.dart`**

```dart
import 'package:equatable/equatable.dart';

/// A person a multi-diver logbook attributes records to (issue #1893).
///
/// A MacDive library can hold several divers. Parsers describe each one here
/// and stamp its [key] on every dive and certification map under [mapKey], so
/// the import wizard can send each diver's records to the Submersion profile
/// the user picks.
class SourceDiver extends Equatable {
  /// [key] of the records the source attributes to no diver.
  static const unownedKey = '_unowned';

  /// Payload map key that carries a record's [key].
  static const mapKey = 'sourceDiverKey';

  /// Stable id within one import: `macdive:<ZUUID>` for MacDive.sqlite,
  /// `name:<name>` for MacDive XML, or [unownedKey].
  final String key;

  /// Display name; empty for the unowned row.
  final String name;

  final int diveCount;
  final int certificationCount;

  // What a new Submersion profile is seeded from. MacDive.sqlite only; the
  // XML export carries a diver's name and nothing else.
  final String? email;
  final String? phone;
  final String? emergencyContact;
  final String? bloodType;
  final String? danNumber;

  const SourceDiver({
    required this.key,
    required this.name,
    this.diveCount = 0,
    this.certificationCount = 0,
    this.email,
    this.phone,
    this.emergencyContact,
    this.bloodType,
    this.danNumber,
  });

  bool get isUnowned => key == unownedKey;

  bool get hasRecords => diveCount > 0 || certificationCount > 0;

  SourceDiver copyWith({int? diveCount, int? certificationCount}) {
    return SourceDiver(
      key: key,
      name: name,
      diveCount: diveCount ?? this.diveCount,
      certificationCount: certificationCount ?? this.certificationCount,
      email: email,
      phone: phone,
      emergencyContact: emergencyContact,
      bloodType: bloodType,
      danNumber: danNumber,
    );
  }

  @override
  List<Object?> get props => [
    key,
    name,
    diveCount,
    certificationCount,
    email,
    phone,
    emergencyContact,
    bloodType,
    danNumber,
  ];
}

/// The rows the Divers step shows, in display order: divers with records by
/// dive count (most first, then name), then the unowned row when it has
/// records.
List<SourceDiver> orderedDiverRows(List<SourceDiver> divers) {
  final named = [
    for (final d in divers)
      if (!d.isUnowned && d.hasRecords) d,
  ]..sort((a, b) {
      final byCount = b.diveCount.compareTo(a.diveCount);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
  return [
    ...named,
    for (final d in divers)
      if (d.isUnowned && d.hasRecords) d,
  ];
}
```

- [ ] **Step 4: Add the field to `ImportPayload`**

In `lib/features/universal_import/data/models/import_payload.dart`, add the import
`import 'package:submersion/features/universal_import/data/models/source_diver.dart';`
after the existing `import_warning.dart` import. Add the field after `metadata`:

```dart
  /// The people the source attributes records to (issue #1893). Empty for
  /// every format that has no notion of several divers.
  final List<SourceDiver> sourceDivers;
```

Change the constructor to:

```dart
  const ImportPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
    this.sourceDivers = const [],
  });
```

Add after `isNotEmpty`:

```dart
  /// Whether two or more divers have records, so the wizard must ask where
  /// each diver's records go (issue #1893). Records with no diver do not
  /// count: in a one-diver library they are that diver's.
  bool get needsDiverMapping =>
      sourceDivers.where((d) => !d.isUnowned && d.hasRecords).length > 1;
```

Change `props` to `[entities, warnings, metadata, sourceDivers]`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/models/source_diver_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/universal_import/data/models/source_diver.dart lib/features/universal_import/data/models/import_payload.dart test/features/universal_import/data/models/source_diver_test.dart
git commit -m "feat(import): describe a logbook's divers on the import payload (#1893)"
```

---

### Task 2: Shared reference keys and merging source divers

**Files:**
- Create: `lib/features/universal_import/data/services/payload_ref_keys.dart`
- Modify: `lib/features/universal_import/data/services/payload_merger.dart:49-75,109-190`
- Test: `test/features/universal_import/data/services/payload_merger_test.dart`

**Interfaces:**
- Consumes: `SourceDiver`, `ImportPayload.sourceDivers` (Task 1).
- Produces: top-level consts `diveScalarRefTypes`, `diveListRefTypes`, `gearLinkRefTypes`, `componentRefTypes`, `buddyRoleRefTypes` (all `Map<String, ImportEntityType>`); `PayloadMerger.merge` returns merged `sourceDivers` (summed counts per key, first file's profile fields).

- [ ] **Step 1: Write the failing test**

Append a group inside `main()` of `test/features/universal_import/data/services/payload_merger_test.dart` (add `import 'package:submersion/features/universal_import/data/models/source_diver.dart';` if it is not already imported):

```dart
  group('source divers (#1893)', () {
    test('sums one diver across files and leaves the dive key alone', () {
      final merged = const PayloadMerger().merge([
        const FilePayload(
          fileId: 'f0',
          fileName: 'one.sqlite',
          payload: ImportPayload(
            entities: {
              ImportEntityType.dives: [
                {'sourceUuid': 'd1', SourceDiver.mapKey: 'macdive:a'},
              ],
            },
            sourceDivers: [
              SourceDiver(
                key: 'macdive:a',
                name: 'Ann Lee',
                diveCount: 2,
                email: 'ann@example.com',
              ),
            ],
          ),
        ),
        const FilePayload(
          fileId: 'f1',
          fileName: 'two.sqlite',
          payload: ImportPayload(
            entities: {},
            sourceDivers: [
              SourceDiver(
                key: 'macdive:a',
                name: 'Ann Lee',
                diveCount: 3,
                certificationCount: 1,
              ),
            ],
          ),
        ),
      ]);

      final ann = merged.sourceDivers.single;
      expect(ann.diveCount, 5);
      expect(ann.certificationCount, 1);
      expect(ann.email, 'ann@example.com');
      // The same person in two files is one diver, so the key is never
      // namespaced the way uddfIds are.
      expect(
        merged.entitiesOf(ImportEntityType.dives).single[SourceDiver.mapKey],
        'macdive:a',
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: FAIL: `merged.sourceDivers` is empty (`Bad state: No element`).

- [ ] **Step 3: Create `payload_ref_keys.dart`**

```dart
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

// Keys through which payload maps reference other payload entities, and the
// entity type each resolves to. Shared by PayloadMerger (namespacing, alias
// rewrite) and PayloadDiverExpander (which items a dive uses), so a new
// reference key is added in one place. A dive's `site` is a nested map with
// its own `uddfId` and is handled by each caller directly.

/// Dive map fields holding one entity reference.
const Map<String, ImportEntityType> diveScalarRefTypes = {
  'siteId': ImportEntityType.sites,
  'tripRef': ImportEntityType.trips,
  'diveCenterRef': ImportEntityType.diveCenters,
  'courseRef': ImportEntityType.courses,
};

/// Dive map fields holding a list of entity references.
const Map<String, ImportEntityType> diveListRefTypes = {
  'equipmentRefs': ImportEntityType.equipment,
  'buddyRefs': ImportEntityType.buddies,
  'diveGuideRefs': ImportEntityType.buddies,
  'tagRefs': ImportEntityType.tags,
};

/// Fields inside a dive's `gearLinks` entries (issue #1487).
const Map<String, ImportEntityType> gearLinkRefTypes = {
  'itemRef': ImportEntityType.equipment,
  'viaRef': ImportEntityType.equipment,
  'setRef': ImportEntityType.equipmentSets,
};

/// Field inside an equipment item's `components` entries (issue #1487).
const Map<String, ImportEntityType> componentRefTypes = {
  'componentRef': ImportEntityType.equipment,
};

/// Field inside a dive's `buddyRoleRefs` entries (issue #1737).
const Map<String, ImportEntityType> buddyRoleRefTypes = {
  'buddyRef': ImportEntityType.buddies,
};
```

- [ ] **Step 4: Use the shared keys in `PayloadMerger`**

In `payload_merger.dart`, add imports for `payload_ref_keys.dart` and `source_diver.dart`. Replace the five `static const` field lists (`_scalarRefFields`, `_listRefFields`, `_gearLinkRefFields`, `_componentRefFields`, `_buddyRoleRefFields`, currently lines 49-75) with, keeping their doc comments:

```dart
  /// Dive map fields holding a single entity reference.
  static final _scalarRefFields = diveScalarRefTypes.keys.toList();

  /// Dive map fields holding a list of entity references.
  static final _listRefFields = diveListRefTypes.keys.toList();

  /// Reference fields inside a dive's `gearLinks` entries and an item's
  /// `components` entries (issue #1487): nested lists of maps, so they
  /// need their own pass.
  static final _gearLinkRefFields = gearLinkRefTypes.keys.toList();
  static final _componentRefFields = componentRefTypes.keys.toList();

  /// Reference field inside a dive's `buddyRoleRefs` entries (issue #1737):
  /// the person holding each exact role.
  static final _buddyRoleRefFields = buddyRoleRefTypes.keys.toList();
```

- [ ] **Step 5: Merge `sourceDivers`**

In `merge`, after `final customDiveRoles = <String, Map<String, dynamic>>{};` add:

```dart
    // The people each file attributes records to (issue #1893). Keyed by the
    // diver's own id, so the same person in two files stays one diver.
    final sourceDivers = <String, SourceDiver>{};
```

Inside `for (final input in inputs) {`, right after `warnings.addAll(input.payload.warnings);`, add:

```dart
      for (final diver in input.payload.sourceDivers) {
        final seen = sourceDivers[diver.key];
        sourceDivers[diver.key] = seen == null
            ? diver
            : seen.copyWith(
                diveCount: seen.diveCount + diver.diveCount,
                certificationCount:
                    seen.certificationCount + diver.certificationCount,
              );
      }
```

In the returned `ImportPayload(...)`, add `sourceDivers: sourceDivers.values.toList(),` after `warnings: warnings,`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/payload_merger_test.dart`
Expected: PASS, including every pre-existing test (the key lists are unchanged).
Run: `flutter test test/features/universal_import/data/services/payload_merger_assemblies_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/universal_import/data/services/payload_ref_keys.dart lib/features/universal_import/data/services/payload_merger.dart test/features/universal_import/data/services/payload_merger_test.dart
git commit -m "refactor(import): share payload reference keys and merge source divers (#1893)"
```

---

### Task 3: Read MacDive diver links and profile fields

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_raw_types.dart:286-316,387-410`
- Modify: `lib/features/universal_import/data/services/macdive_db_reader.dart:306-325,371-384`
- Modify: `test/fixtures/macdive_sqlite/build_synthetic_db.dart`
- Test: `test/features/universal_import/data/services/macdive_db_reader_test.dart`

**Interfaces:**
- Produces: `MacDiveRawCertification.diverFk` (`int?`); `MacDiveRawDiver.phone`, `.mobile`, `.emergencyContact`, `.bloodType`, `.danNumber` (`String?`); `buildSyntheticMacDiveDb(String path, {bool includeDiveImages = true, bool includeDivers = false})`.

- [ ] **Step 1: Extend the synthetic fixture**

In `test/fixtures/macdive_sqlite/build_synthetic_db.dart`:

1. Change the signature and body of `buildSyntheticMacDiveDb`:

```dart
File buildSyntheticMacDiveDb(
  String path, {
  bool includeDiveImages = true,
  bool includeDivers = false,
}) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final db = sqlite3.open(path);
  try {
    _createSchema(db, includeDiveImages: includeDiveImages);
    _insertFixtureRows(
      db,
      includeDiveImages: includeDiveImages,
      includeDivers: includeDivers,
    );
  } finally {
    db.close();
  }
  return f;
}
```

2. Add to the doc comment above it:

```dart
/// [includeDivers] adds two MacDive divers (issue #1893): Ann Lee owns dives
/// 1 and 2, Bo Ray owns the certification, and dive 3 names no diver.
```

3. In the `CREATE TABLE ZDIVE` statement, change the line
`ZRELATIONSHIPDIVESITE INTEGER, ZRELATIONSHIPCERTIFICATION INTEGER,` to
`ZRELATIONSHIPDIVESITE INTEGER, ZRELATIONSHIPCERTIFICATION INTEGER, ZRELATIONSHIPDIVER INTEGER,`.

4. Replace the `CREATE TABLE ZDIVER` statement with:

```dart
  db.execute('''
    CREATE TABLE ZDIVER (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZFIRSTNAME VARCHAR, ZLASTNAME VARCHAR, ZEMAILADDRESS VARCHAR,
      ZPHONE VARCHAR, ZMOBILE VARCHAR, ZEMERGENCYCONTACT VARCHAR,
      ZBLOODTYPE VARCHAR, ZINSURANCEDAN VARCHAR,
      ZUUID VARCHAR
    )
  ''');
```

5. Change `void _insertFixtureRows(Database db, {required bool includeDiveImages}) {` to
`void _insertFixtureRows(Database db, {required bool includeDiveImages, required bool includeDivers}) {`, and insert this block immediately before the `// ---- dive images ----` comment (it must run before that section's early `return`):

```dart
  // ---- divers (#1893) ---- Ann owns dives 1 and 2, Bo owns the
  // certification, dive 3 names no diver.
  if (includeDivers) {
    db.execute('''
      INSERT INTO ZDIVER (Z_PK, ZFIRSTNAME, ZLASTNAME, ZEMAILADDRESS, ZPHONE,
                          ZMOBILE, ZEMERGENCYCONTACT, ZBLOODTYPE,
                          ZINSURANCEDAN, ZUUID)
      VALUES
        (1, 'Ann', 'Lee', 'ann@example.com', NULL, '555-0101',
         'Sam Lee', 'O+', 'DAN-123', 'diver-uuid-1'),
        (2, 'Bo', 'Ray', NULL, NULL, NULL, NULL, NULL, NULL, 'diver-uuid-2')
    ''');
    db.execute('UPDATE ZDIVE SET ZRELATIONSHIPDIVER = 1 WHERE Z_PK IN (1, 2)');
    db.execute('UPDATE ZCERTIFICATION SET ZRELATIONSHIPDIVER = 2');
  }
```

- [ ] **Step 2: Write the failing test**

Append inside `main()` of `test/features/universal_import/data/services/macdive_db_reader_test.dart` (the file already imports `dart:io`, `dart:typed_data`, the reader and the fixture builder; add any that are missing):

```dart
  group('divers (#1893)', () {
    late Uint8List diverBytes;

    setUpAll(() async {
      final path =
          '${Directory.systemTemp.path}/mdr_divers_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      final file = buildSyntheticMacDiveDb(path, includeDivers: true);
      diverBytes = Uint8List.fromList(await file.readAsBytes());
      file.deleteSync();
    });

    test('reads the diver profile columns', () async {
      final logbook = await MacDiveDbReader.readAll(diverBytes);
      final ann = logbook.diversByPk[1]!;
      expect(ann.fullName, 'Ann Lee');
      expect(ann.email, 'ann@example.com');
      expect(ann.phone, isNull);
      expect(ann.mobile, '555-0101');
      expect(ann.emergencyContact, 'Sam Lee');
      expect(ann.bloodType, 'O+');
      expect(ann.danNumber, 'DAN-123');
    });

    test('links dives and certifications to their diver', () async {
      final logbook = await MacDiveDbReader.readAll(diverBytes);
      final byPk = {for (final d in logbook.dives) d.pk: d};
      expect(byPk[1]!.diverFk, 1);
      expect(byPk[2]!.diverFk, 1);
      expect(byPk[3]!.diverFk, isNull);
      expect(logbook.certifications.single.diverFk, 2);
    });
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/macdive_db_reader_test.dart`
Expected: FAIL to compile: `mobile`, `emergencyContact`, `bloodType`, `danNumber` and `MacDiveRawCertification.diverFk` are not defined.

- [ ] **Step 4: Add the raw fields**

In `macdive_raw_types.dart`, in `MacDiveRawCertification` add after `cardBackPath`:

```dart
  /// `ZRELATIONSHIPDIVER` - the MacDive diver the card belongs to (#1893).
  final int? diverFk;
```

and `this.diverFk,` at the end of its constructor parameter list.

In `MacDiveRawDiver` add after `email`:

```dart
  /// `ZPHONE` and `ZMOBILE`.
  final String? phone;
  final String? mobile;

  /// `ZEMERGENCYCONTACT`, free text.
  final String? emergencyContact;

  /// `ZBLOODTYPE`.
  final String? bloodType;

  /// `ZINSURANCEDAN`, the diver's DAN membership number.
  final String? danNumber;
```

and `this.phone, this.mobile, this.emergencyContact, this.bloodType, this.danNumber,` after `this.email,` in its constructor.

- [ ] **Step 5: Read the columns**

In `macdive_db_reader.dart`, `_readCertifications`: add `diverFk: r['ZRELATIONSHIPDIVER'] as int?,` after `cardBackPath: _str(r['ZCARDBACK']),`.
In `_readDivers`: add after `email: _str(r['ZEMAILADDRESS']),`:

```dart
        phone: _str(r['ZPHONE']),
        mobile: _str(r['ZMOBILE']),
        emergencyContact: _str(r['ZEMERGENCYCONTACT']),
        bloodType: _str(r['ZBLOODTYPE']),
        danNumber: _str(r['ZINSURANCEDAN']),
```

(Both queries are `SELECT *`; a column missing from an older library reads as null, which is how `ZRELATIONSHIPDIVER` already behaves on `ZDIVE`.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/macdive_db_reader_test.dart`
Expected: PASS, including `absent tables ... diversByPk isEmpty` (the default fixture still has no divers).
Run: `flutter test test/features/universal_import/data/services/macdive_db_reader_photo_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/universal_import/data/services/macdive_raw_types.dart lib/features/universal_import/data/services/macdive_db_reader.dart test/fixtures/macdive_sqlite/build_synthetic_db.dart test/features/universal_import/data/services/macdive_db_reader_test.dart
git commit -m "feat(macdive): read each certification's diver and diver profile fields (#1893)"
```

---

### Task 4: MacDive.sqlite mapper describes divers instead of tagging them

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_dive_mapper.dart:135-143,181-187,254-266,302-304,319-327,599-624,657-664,788-796,934-941`
- Test: `test/features/universal_import/data/services/macdive_dive_mapper_test.dart:185-231,1452-1492`

**Interfaces:**
- Consumes: `SourceDiver` (Task 1), `MacDiveRawCertification.diverFk`, `MacDiveRawDiver` profile fields (Task 3).
- Produces: payloads from `MacDiveDiveMapper.toPayload` carry `sourceDivers` and a `sourceDiverKey` on every dive and certification map (`macdive:<ZUUID>`, or `macdive:pk<Z_PK>` when the uuid is empty, or `SourceDiver.unownedKey`). No diver-name tags and no "divers" warning.

- [ ] **Step 1: Update the test helper**

In `macdive_dive_mapper_test.dart`, replace `_multiDiverLogbook` (starts at the doc comment "Three dives across two MacDive divers") with:

```dart
/// Three dives across two MacDive divers, plus one dive with no diver link,
/// and one certification belonging to the second diver. With [singleDiver]
/// the second diver is removed, so their dive and card no longer resolve to
/// anyone and the library looks like the common one-diver case.
MacDiveRawLogbook _multiDiverLogbook({bool singleDiver = false}) {
  return MacDiveRawLogbook(
    dives: const [
      MacDiveRawDive(pk: 1, uuid: 'dive-1', diverFk: 1),
      MacDiveRawDive(pk: 2, uuid: 'dive-2', diverFk: 2),
      MacDiveRawDive(pk: 3, uuid: 'dive-3'),
    ],
    diversByPk: {
      1: const MacDiveRawDiver(
        pk: 1,
        uuid: 'diver-1',
        firstName: 'Ann',
        lastName: 'Lee',
        email: 'ann@example.com',
        mobile: '555-0101',
        emergencyContact: 'Sam Lee',
        bloodType: 'O+',
        danNumber: 'DAN-123',
      ),
      if (!singleDiver)
        2: const MacDiveRawDiver(
          pk: 2,
          uuid: 'diver-2',
          firstName: 'Bo',
          lastName: 'Ray',
        ),
    },
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [
      MacDiveRawCertification(
        pk: 1,
        uuid: 'cert-1',
        name: 'Rescue Diver',
        diverFk: 2,
      ),
    ],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}
```

- [ ] **Step 2: Rewrite the two #912 tests**

Replace the tests `'a multi-diver library is flagged and tagged by diver'` and `'a single-diver library is not tagged or flagged'` with (add `import 'package:submersion/features/universal_import/data/models/source_diver.dart';`):

```dart
    test('a multi-diver library describes each diver (#1893)', () async {
      final payload = await MacDiveDiveMapper.toPayload(_multiDiverLogbook());

      expect(payload.needsDiverMapping, isTrue);
      expect(payload.sourceDivers.map((d) => d.key), [
        'macdive:diver-1',
        'macdive:diver-2',
        SourceDiver.unownedKey,
      ]);
      final ann = payload.sourceDivers[0];
      expect(ann.name, 'Ann Lee');
      expect(ann.diveCount, 1);
      expect(ann.email, 'ann@example.com');
      // ZPHONE is empty, so the mobile number stands in.
      expect(ann.phone, '555-0101');
      expect(ann.emergencyContact, 'Sam Lee');
      expect(ann.bloodType, 'O+');
      expect(ann.danNumber, 'DAN-123');
      expect(payload.sourceDivers[1].certificationCount, 1);
      expect(payload.sourceDivers[2].diveCount, 1);

      final dives = payload.entitiesOf(ImportEntityType.dives);
      Object? keyOf(String uuid) =>
          dives.firstWhere((d) => d['sourceUuid'] == uuid)[SourceDiver.mapKey];
      expect(keyOf('dive-1'), 'macdive:diver-1');
      expect(keyOf('dive-2'), 'macdive:diver-2');
      expect(keyOf('dive-3'), SourceDiver.unownedKey);
      expect(
        payload
            .entitiesOf(ImportEntityType.certifications)
            .single[SourceDiver.mapKey],
        'macdive:diver-2',
      );

      // The Divers step replaces #912's name tags and warning.
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
      for (final dive in dives) {
        expect(dive.containsKey('tagRefs'), isFalse);
      }
      expect(
        payload.warnings.where((w) => w.message.contains('divers')),
        isEmpty,
      );
    });

    test('a single-diver library needs no diver mapping', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        _multiDiverLogbook(singleDiver: true),
      );
      expect(payload.needsDiverMapping, isFalse);
      // Diver 2 is gone, so their dive and card are unowned.
      expect(payload.sourceDivers.map((d) => d.key), [
        'macdive:diver-1',
        SourceDiver.unownedKey,
      ]);
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
    });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart --plain-name "diver"`
Expected: FAIL: `sourceDivers` is empty and the old tag is still emitted.

- [ ] **Step 4: Change the mapper**

In `macdive_dive_mapper.dart`, add `import 'package:submersion/features/universal_import/data/models/source_diver.dart';`.

1. Replace lines 135-143 (the `// A MacDive library can hold several divers...` comment, `diverNames` and `tagMapsWithDivers`) with:

```dart
    // A MacDive library can hold several divers. The payload names each one
    // and keys every dive and card to its diver, so the wizard's Divers step
    // can send them to separate profiles (#1893).
    final sourceDivers = _buildSourceDivers(logbook);
```

2. In the dive loop, change the `_buildDiveMap(d, logbook, converter, multiDiver: diverNames.length > 1)` call to `_buildDiveMap(d, logbook, converter)`.
3. Delete the `if (diverNames.length > 1) { warnings.add(...) }` block (lines 254-266).
4. Replace `if (tagMapsWithDivers.isNotEmpty) { entities[ImportEntityType.tags] = tagMapsWithDivers; }` with `if (tagMaps.isNotEmpty) entities[ImportEntityType.tags] = tagMaps;`.
5. In the returned `ImportPayload(...)`, add `sourceDivers: sourceDivers,` after `warnings: warnings,`.
6. In `_buildCertificationMaps`, add to the emitted map, after `'level': name,`:

```dart
        SourceDiver.mapKey: _sourceDiverKey(logbook, c.diverFk),
```

7. Replace `_diverNamesInUse` (lines 657-664) with:

```dart
  /// The `sourceDiverKey` of a record whose `ZRELATIONSHIPDIVER` is
  /// [diverFk]. A missing or dangling link is the unowned row (#1893).
  static String _sourceDiverKey(MacDiveRawLogbook logbook, int? diverFk) {
    final diver = logbook.diversByPk[diverFk];
    if (diver == null) return SourceDiver.unownedKey;
    return 'macdive:${diver.uuid.isNotEmpty ? diver.uuid : 'pk${diver.pk}'}';
  }

  /// One [SourceDiver] per MacDive diver with dives or certifications, then
  /// the unowned row when some records name no diver (#1893).
  static List<SourceDiver> _buildSourceDivers(MacDiveRawLogbook logbook) {
    final dives = <String, int>{};
    for (final d in logbook.dives) {
      final key = _sourceDiverKey(logbook, d.diverFk);
      dives[key] = (dives[key] ?? 0) + 1;
    }
    final certs = <String, int>{};
    for (final c in logbook.certifications) {
      // Mirrors _buildCertificationMaps, which drops nameless cards.
      if ((c.name?.trim() ?? '').isEmpty) continue;
      final key = _sourceDiverKey(logbook, c.diverFk);
      certs[key] = (certs[key] ?? 0) + 1;
    }

    final out = <SourceDiver>[];
    final seen = <String>{};
    final pks = logbook.diversByPk.keys.toList()..sort();
    for (final pk in pks) {
      final diver = logbook.diversByPk[pk]!;
      final key = _sourceDiverKey(logbook, pk);
      if (!seen.add(key)) continue;
      final diveCount = dives[key] ?? 0;
      final certificationCount = certs[key] ?? 0;
      if (diveCount == 0 && certificationCount == 0) continue;
      final email = diver.email?.trim();
      out.add(
        SourceDiver(
          key: key,
          name:
              diver.fullName ??
              ((email?.isNotEmpty ?? false) ? email! : 'MacDive diver $pk'),
          diveCount: diveCount,
          certificationCount: certificationCount,
          email: diver.email,
          phone: diver.phone ?? diver.mobile,
          emergencyContact: diver.emergencyContact,
          bloodType: diver.bloodType,
          danNumber: diver.danNumber,
        ),
      );
    }

    final unownedDives = dives[SourceDiver.unownedKey] ?? 0;
    final unownedCerts = certs[SourceDiver.unownedKey] ?? 0;
    if (unownedDives > 0 || unownedCerts > 0) {
      out.add(
        SourceDiver(
          key: SourceDiver.unownedKey,
          name: '',
          diveCount: unownedDives,
          certificationCount: unownedCerts,
        ),
      );
    }
    return out;
  }
```

8. In `_buildDiveMap`, remove the `bool multiDiver = false,` parameter (line 792) and the `if (multiDiver) { ... }` block with its two-line comment (lines 933-940). After `if (d.identifier != null) map['sourceIdentifier'] = d.identifier;` add:

```dart
    map[SourceDiver.mapKey] = _sourceDiverKey(logbook, d.diverFk);
```

- [ ] **Step 5: Run the MacDive tests**

Run each (one at a time):
`flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart`
`flutter test test/features/universal_import/data/services/macdive_dive_mapper_photo_test.dart`
`flutter test test/features/universal_import/data/parsers/macdive_sqlite_parser_test.dart`
`flutter test test/features/universal_import/data/parsers/macdive_sqlite_photo_test.dart`
Expected: PASS. If a pre-existing test fails only because a dive or certification map compared with full-map equality now has the extra `sourceDiverKey` entry, add `SourceDiver.mapKey: SourceDiver.unownedKey` (the synthetic default fixture has no divers) to that expected map; do not weaken any other assertion.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/universal_import/data/services/macdive_dive_mapper.dart test/features/universal_import/data/services/macdive_dive_mapper_test.dart
git commit -m "feat(macdive): key sqlite dives and certifications to their diver (#1893)"
```

(Add any other test file Step 5 touched to the `git add` list.)

---

### Task 5: MacDive XML parser groups dives by `<diver>`

**Files:**
- Modify: `lib/features/universal_import/data/parsers/macdive_xml_parser.dart:112-124,234-272`
- Modify: `lib/features/universal_import/data/services/macdive_xml_models.dart:116`
- Test: `test/features/universal_import/data/parsers/macdive_xml_parser_test.dart`

**Interfaces:**
- Consumes: `SourceDiver` (Task 1).
- Produces: MacDive XML payloads carry `sourceDivers` (`name:<trimmed name>` keys, first-seen order, `SourceDiver.unownedKey` for an empty `<diver>`) and a `sourceDiverKey` on each dive map.

- [ ] **Step 1: Write the failing test**

Append inside `group('MacDiveXmlParser', ...)` (add imports for `source_diver.dart`; `dart:convert` and `dart:typed_data` are already imported):

```dart
    // #1893: MacDive writes the diver on each dive. The reference library
    // fills it on 503 of 540 dives and leaves it empty on exactly the dives
    // whose MacDive.sqlite row names no diver.
    test('groups dives by <diver>', () async {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<dives>
    <units>Metric</units>
    <schema>2.2.0</schema>
    <dive><date>2024-06-01 09:00:00</date><identifier>a</identifier><diver>Ann Lee</diver></dive>
    <dive><date>2024-06-02 09:00:00</date><identifier>b</identifier><diver> Bo Ray </diver></dive>
    <dive><date>2024-06-03 09:00:00</date><identifier>c</identifier><diver></diver></dive>
    <dive><date>2024-06-04 09:00:00</date><identifier>d</identifier><diver>Ann Lee</diver></dive>
</dives>''';
      final payload = await const MacDiveXmlParser().parse(
        Uint8List.fromList(utf8.encode(xml)),
      );

      expect(payload.sourceDivers, const [
        SourceDiver(key: 'name:Ann Lee', name: 'Ann Lee', diveCount: 2),
        SourceDiver(key: 'name:Bo Ray', name: 'Bo Ray', diveCount: 1),
        SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 1),
      ]);
      expect(payload.needsDiverMapping, isTrue);
      expect(
        payload
            .entitiesOf(ImportEntityType.dives)
            .map((d) => d[SourceDiver.mapKey]),
        ['name:Ann Lee', 'name:Bo Ray', SourceDiver.unownedKey, 'name:Ann Lee'],
      );
    });

    test('a file with one diver needs no diver mapping', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(payload.needsDiverMapping, isFalse);
    });
```

If `MacDiveXmlReader` rejects a `<dive>` this minimal, copy the smallest set of extra elements it requires from `test/fixtures/macdive_xml/metric_small.xml` into each `<dive>`; keep the `<diver>` values as written.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/macdive_xml_parser_test.dart --plain-name "diver"`
Expected: FAIL: `sourceDivers` is empty.

- [ ] **Step 3: Implement**

In `macdive_xml_parser.dart`, add `import 'package:submersion/features/universal_import/data/models/source_diver.dart';`. After the `diveCentersByName` declaration add:

```dart
    // Dives per `<diver>`, in first-seen order (#1893). MacDive fills it on
    // every dive a diver logged and leaves it empty on dives it attributes
    // to no one.
    final diverNames = <String, String>{};
    final diveCountByDiver = <String, int>{};
```

Right after `final diveMap = _mapDive(dive);` add:

```dart
      final diverName = dive.diver?.trim() ?? '';
      final diverKey = diverName.isEmpty
          ? SourceDiver.unownedKey
          : 'name:$diverName';
      diveMap[SourceDiver.mapKey] = diverKey;
      diverNames.putIfAbsent(diverKey, () => diverName);
      diveCountByDiver[diverKey] = (diveCountByDiver[diverKey] ?? 0) + 1;
```

In the final `return ImportPayload(...)`, add after `warnings: warnings,`:

```dart
      sourceDivers: [
        for (final MapEntry(:key, value: name) in diverNames.entries)
          SourceDiver(key: key, name: name, diveCount: diveCountByDiver[key]!),
      ],
```

In `macdive_xml_models.dart`, replace the comment `/// Owner/diver name (rarely populated in MacDive XML).` with:

```dart
  /// The diver who logged the dive. MacDive fills it on every dive it
  /// attributes to a diver and leaves it empty otherwise, exactly matching
  /// `ZDIVE.ZRELATIONSHIPDIVER` in MacDive.sqlite (#1893).
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/macdive_xml_parser_test.dart`
Expected: PASS (all tests).
Run: `flutter test test/features/universal_import/data/parsers/macdive_xml_photo_test.dart`
Expected: PASS. Apply the same full-map-equality rule as Task 4 Step 5 if a dive map comparison fails only on `sourceDiverKey`.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/universal_import/data/parsers/macdive_xml_parser.dart lib/features/universal_import/data/services/macdive_xml_models.dart test/features/universal_import/data/parsers/macdive_xml_parser_test.dart
git commit -m "feat(macdive): group xml dives by their diver (#1893)"
```

---

### Task 6: DiverTarget and the default mapping

**Files:**
- Create: `lib/features/universal_import/data/models/diver_target.dart`
- Create: `lib/features/universal_import/data/services/default_diver_mapping.dart`
- Test: `test/features/universal_import/data/services/default_diver_mapping_test.dart`

**Interfaces:**
- Consumes: `SourceDiver`, `orderedDiverRows` (Task 1); `Diver` (`lib/features/divers/domain/entities/diver.dart`, fields `id`, `name`).
- Produces: `sealed class DiverTarget` with `String? get targetKey`, `static const itemKey = '_targetKey'`, `static String? diverIdOf(String targetKey)`, `static String? newSourceKeyOf(String targetKey)`; `ExistingDiverTarget(String diverId)` (key `diver:<id>`), `NewDiverTarget(String sourceKey)` (key `new:<sourceKey>`), `SkipDiverTarget()` (key null). All are `Equatable`. `Map<String, DiverTarget> defaultDiverMapping({required List<SourceDiver> sourceDivers, required List<Diver> profiles, required String activeDiverId})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/default_diver_mapping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/default_diver_mapping.dart';

Diver _profile(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _ann = SourceDiver(key: 'macdive:ann', name: 'Ann Lee', diveCount: 10);
const _bo = SourceDiver(key: 'macdive:bo', name: 'Bo Ray', diveCount: 4);
const _cy = SourceDiver(key: 'macdive:cy', name: 'Cy Park', diveCount: 2);
const _unowned = SourceDiver(
  key: SourceDiver.unownedKey,
  name: '',
  diveCount: 1,
);

void main() {
  group('DiverTarget', () {
    test('target keys round trip', () {
      const existing = ExistingDiverTarget('p1');
      const created = NewDiverTarget('macdive:ann');
      expect(DiverTarget.diverIdOf(existing.targetKey), 'p1');
      expect(DiverTarget.newSourceKeyOf(existing.targetKey), isNull);
      expect(DiverTarget.newSourceKeyOf(created.targetKey), 'macdive:ann');
      expect(DiverTarget.diverIdOf(created.targetKey), isNull);
      expect(const SkipDiverTarget().targetKey, isNull);
    });

    test('targets compare by value', () {
      expect(const ExistingDiverTarget('p1'), const ExistingDiverTarget('p1'));
      expect(
        const NewDiverTarget('a') == const ExistingDiverTarget('a'),
        isFalse,
      );
    });
  });

  group('defaultDiverMapping', () {
    test('a name match wins, ignoring case and outer spaces', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo],
        profiles: [_profile('me', 'Me'), _profile('p-bo', '  bo RAY ')],
        activeDiverId: 'me',
      );
      expect(mapping[_bo.key], const ExistingDiverTarget('p-bo'));
      expect(mapping[_ann.key], const ExistingDiverTarget('me'));
    });

    test('the busiest unmatched diver gets the active profile', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_cy, _bo, _ann],
        profiles: [_profile('me', 'Me')],
        activeDiverId: 'me',
      );
      expect(mapping, {
        _ann.key: const ExistingDiverTarget('me'),
        _bo.key: NewDiverTarget(_bo.key),
        _cy.key: NewDiverTarget(_cy.key),
      });
    });

    test('an active profile claimed by a name match is not given twice', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo],
        profiles: [_profile('me', 'Bo Ray')],
        activeDiverId: 'me',
      );
      expect(mapping, {
        _bo.key: const ExistingDiverTarget('me'),
        _ann.key: NewDiverTarget(_ann.key),
      });
    });

    test('dives with no diver go to the active profile', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo, _unowned],
        profiles: [_profile('me', 'Ann Lee')],
        activeDiverId: 'me',
      );
      expect(mapping[SourceDiver.unownedKey], const ExistingDiverTarget('me'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/default_diver_mapping_test.dart`
Expected: FAIL to compile: missing files.

- [ ] **Step 3: Create `diver_target.dart`**

```dart
import 'package:equatable/equatable.dart';

/// Where the import wizard's Divers step sends one source diver's records
/// (issue #1893).
sealed class DiverTarget extends Equatable {
  const DiverTarget();

  /// Payload map key stamped on every item of an expanded payload with the
  /// [targetKey] of the profile it will be imported into.
  static const itemKey = '_targetKey';

  static const _existingPrefix = 'diver:';
  static const _newPrefix = 'new:';

  /// The [itemKey] value for items going to this target; null when the
  /// records are left out of the import.
  String? get targetKey;

  /// The existing profile id [targetKey] names, or null for a new profile.
  static String? diverIdOf(String targetKey) =>
      targetKey.startsWith(_existingPrefix)
      ? targetKey.substring(_existingPrefix.length)
      : null;

  /// The source diver key a new-profile [targetKey] names, or null.
  static String? newSourceKeyOf(String targetKey) =>
      targetKey.startsWith(_newPrefix)
      ? targetKey.substring(_newPrefix.length)
      : null;
}

/// Import into an existing Submersion profile.
final class ExistingDiverTarget extends DiverTarget {
  const ExistingDiverTarget(this.diverId);

  final String diverId;

  @override
  String get targetKey => '${DiverTarget._existingPrefix}$diverId';

  @override
  List<Object?> get props => [diverId];
}

/// Import into a profile the import creates, seeded from the source diver.
final class NewDiverTarget extends DiverTarget {
  const NewDiverTarget(this.sourceKey);

  final String sourceKey;

  @override
  String get targetKey => '${DiverTarget._newPrefix}$sourceKey';

  @override
  List<Object?> get props => [sourceKey];
}

/// Leave this source diver's records out of the import.
final class SkipDiverTarget extends DiverTarget {
  const SkipDiverTarget();

  @override
  String? get targetKey => null;

  @override
  List<Object?> get props => const [];
}
```

- [ ] **Step 4: Create `default_diver_mapping.dart`**

```dart
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';

/// The Divers step's preselected targets (issue #1893).
///
/// 1. A diver whose name matches a profile's, ignoring case and outer
///    spaces, goes to that profile.
/// 2. Otherwise the diver with the most dives goes to the active profile,
///    unless a name match already claimed it.
/// 3. Every other diver gets a new profile.
/// 4. Records with no diver go to the active profile.
Map<String, DiverTarget> defaultDiverMapping({
  required List<SourceDiver> sourceDivers,
  required List<Diver> profiles,
  required String activeDiverId,
}) {
  String norm(String s) => s.trim().toLowerCase();
  final rows = orderedDiverRows(sourceDivers);
  final mapping = <String, DiverTarget>{};
  final claimed = <String>{};

  for (final row in rows) {
    if (row.isUnowned || norm(row.name).isEmpty) continue;
    for (final profile in profiles) {
      if (norm(profile.name) == norm(row.name)) {
        mapping[row.key] = ExistingDiverTarget(profile.id);
        claimed.add(profile.id);
        break;
      }
    }
  }

  var activeTaken = claimed.contains(activeDiverId);
  for (final row in rows) {
    if (row.isUnowned || mapping.containsKey(row.key)) continue;
    if (!activeTaken) {
      mapping[row.key] = ExistingDiverTarget(activeDiverId);
      activeTaken = true;
    } else {
      mapping[row.key] = NewDiverTarget(row.key);
    }
  }

  for (final row in rows) {
    if (row.isUnowned) mapping[row.key] = ExistingDiverTarget(activeDiverId);
  }
  return mapping;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/services/default_diver_mapping_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/universal_import/data/models/diver_target.dart lib/features/universal_import/data/services/default_diver_mapping.dart test/features/universal_import/data/services/default_diver_mapping_test.dart
git commit -m "feat(import): model diver targets and preselect them (#1893)"
```

---

### Task 7: PayloadDiverExpander

**Files:**
- Create: `lib/features/universal_import/data/services/payload_diver_expander.dart`
- Test: `test/features/universal_import/data/services/payload_diver_expander_test.dart`

**Interfaces:**
- Consumes: `SourceDiver` (Task 1), ref-key maps (Task 2), `DiverTarget` (Task 6).
- Produces: `PayloadDiverExpander.expand(ImportPayload source, Map<String, DiverTarget> mapping, {required String activeDiverId}) -> ImportPayload`. Every item of the result carries `DiverTarget.itemKey`. A source key missing from `mapping` is treated as `ExistingDiverTarget(activeDiverId)`. `warnings`, `metadata` and `sourceDivers` pass through.

- [ ] **Step 1: Write the failing tests**

Create `test/features/universal_import/data/services/payload_diver_expander_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/payload_diver_expander.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';
const _cy = 'macdive:cy';
const _active = 'diver:active';
const _newBo = 'new:macdive:bo';
const _key = DiverTarget.itemKey;

/// Ann (active profile) and Bo (new profile) share Blue Hole and the BCD;
/// Cy is skipped and alone used Cy Only; the unowned dive used the Wreck.
ImportPayload _source({int annDives = 1}) => ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {
        'sourceUuid': 'd1',
        SourceDiver.mapKey: _ann,
        'site': {'uddfId': 'Blue Hole'},
        'tagRefs': ['Reef'],
        'equipmentRefs': ['bcd'],
      },
      {
        'sourceUuid': 'd2',
        SourceDiver.mapKey: _bo,
        'site': {'uddfId': 'Blue Hole'},
        'equipmentRefs': ['bcd'],
      },
      {
        'sourceUuid': 'd3',
        SourceDiver.mapKey: _cy,
        'site': {'uddfId': 'Cy Only'},
      },
      {
        'sourceUuid': 'd4',
        SourceDiver.mapKey: SourceDiver.unownedKey,
        'site': {'uddfId': 'Wreck'},
      },
    ],
    ImportEntityType.sites: [
      {'name': 'Blue Hole', 'uddfId': 'Blue Hole'},
      {'name': 'Cy Only', 'uddfId': 'Cy Only'},
      {'name': 'Wreck', 'uddfId': 'Wreck'},
      {'name': 'Never Dived', 'uddfId': 'Never Dived'},
    ],
    ImportEntityType.tags: [
      {'name': 'Reef', 'uddfId': 'Reef'},
    ],
    ImportEntityType.equipment: [
      {
        'name': 'BCD',
        'uddfId': 'bcd',
        'components': [
          {'componentRef': 'inflator'},
        ],
        'observations': [
          {'diveRef': 'd1', 'observedAt': DateTime(2024, 1, 1)},
          {'diveRef': 'd2', 'observedAt': DateTime(2024, 1, 2)},
        ],
      },
      {'name': 'Inflator', 'uddfId': 'inflator'},
      {'name': 'Spare', 'uddfId': 'spare'},
    ],
    ImportEntityType.serviceRecords: [
      {'equipmentRef': 'bcd', 'serviceDate': DateTime(2024)},
    ],
    ImportEntityType.certifications: [
      {'name': 'Rescue', 'uddfId': 'c1', SourceDiver.mapKey: _bo},
    ],
    ImportEntityType.media: [
      {'filename': 'a.jpg', '_diveIndex': 0},
      {'filename': 'c.jpg', '_diveIndex': 2},
      {'filename': 'd.jpg', '_diveIndex': 3},
    ],
  },
  sourceDivers: [
    SourceDiver(key: _ann, name: 'Ann Lee', diveCount: annDives),
    const SourceDiver(
      key: _bo,
      name: 'Bo Ray',
      diveCount: 1,
      certificationCount: 1,
    ),
    const SourceDiver(key: _cy, name: 'Cy Park', diveCount: 1),
    const SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 1),
  ],
);

const Map<String, DiverTarget> _mapping = {
  _ann: ExistingDiverTarget('active'),
  _bo: NewDiverTarget(_bo),
  _cy: SkipDiverTarget(),
  SourceDiver.unownedKey: ExistingDiverTarget('active'),
};

ImportPayload _expand(
  ImportPayload source, [
  Map<String, DiverTarget> mapping = _mapping,
]) => PayloadDiverExpander.expand(source, mapping, activeDiverId: 'active');

List<Object?> _targets(ImportPayload p, ImportEntityType type, String id) => [
  for (final item in p.entitiesOf(type))
    if (item['uddfId'] == id) item[_key],
];

void main() {
  test('dives and certifications take their source diver target', () {
    final out = _expand(_source());
    final dives = out.entitiesOf(ImportEntityType.dives);
    expect(dives.map((d) => d['sourceUuid']), ['d1', 'd2', 'd4']);
    expect(dives.map((d) => d[_key]), [_active, _newBo, _active]);
    expect(_targets(out, ImportEntityType.certifications, 'c1'), [_newBo]);
  });

  test('a site both targets use is copied per target, uddfId unchanged', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Blue Hole'), [
      _active,
      _newBo,
    ]);
    expect(_targets(out, ImportEntityType.sites, 'Wreck'), [_active]);
  });

  test('an item only skipped dives use is dropped', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Cy Only'), isEmpty);
  });

  test('an item no dive uses goes to the active profile when mapped', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Never Dived'), [_active]);
    expect(_targets(out, ImportEntityType.equipment, 'spare'), [_active]);
  });

  test('without the active profile, unused items go to the busiest target',
      () {
    final out = _expand(_source(annDives: 5), const {
      _ann: NewDiverTarget(_ann),
      _bo: NewDiverTarget(_bo),
      _cy: SkipDiverTarget(),
      SourceDiver.unownedKey: SkipDiverTarget(),
    });
    expect(_targets(out, ImportEntityType.sites, 'Never Dived'), [
      'new:$_ann',
    ]);
  });

  test('components and service records follow their equipment', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.equipment, 'inflator'), [
      _active,
      _newBo,
    ]);
    expect(
      out.entitiesOf(ImportEntityType.serviceRecords).map((r) => r[_key]),
      [_active, _newBo],
    );
  });

  test('a gear copy keeps only observations of its own dives', () {
    final out = _expand(_source());
    List<Object?> refsOf(String target) => [
      for (final item in out.entitiesOf(ImportEntityType.equipment))
        if (item['uddfId'] == 'bcd' && item[_key] == target)
          for (final o in item['observations'] as List) (o as Map)['diveRef'],
    ];
    expect(refsOf(_active), ['d1']);
    expect(refsOf(_newBo), ['d2']);
  });

  test('sets and a course instructor follow the dive that uses them', () {
    final out = _expand(
      const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {
              SourceDiver.mapKey: _bo,
              'gearLinks': [
                {'setRef': 'set1'},
              ],
              'courseRef': 'owd',
            },
            {SourceDiver.mapKey: _ann},
          ],
          ImportEntityType.equipmentSets: [
            {
              'uddfId': 'set1',
              'equipmentRefs': ['fins'],
            },
          ],
          ImportEntityType.equipment: [
            {'uddfId': 'fins'},
          ],
          ImportEntityType.courses: [
            {'uddfId': 'owd', 'instructorRef': 'kim'},
          ],
          ImportEntityType.buddies: [
            {'uddfId': 'kim'},
          ],
        },
        sourceDivers: [
          SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
        ],
      ),
    );
    expect(_targets(out, ImportEntityType.equipmentSets, 'set1'), [_newBo]);
    expect(_targets(out, ImportEntityType.equipment, 'fins'), [_newBo]);
    expect(_targets(out, ImportEntityType.courses, 'owd'), [_newBo]);
    expect(_targets(out, ImportEntityType.buddies, 'kim'), [_newBo]);
  });

  test('media follow their dive and are renumbered', () {
    final out = _expand(_source());
    final media = out.entitiesOf(ImportEntityType.media);
    expect(media.map((m) => m['filename']), ['a.jpg', 'd.jpg']);
    expect(media.map((m) => m['_diveIndex']), [0, 2]);
    expect(media.map((m) => m[_key]), [_active, _active]);
  });

  test('a target fed by two divers tags each dive with its diver', () {
    final out = _expand(_source());
    final dives = out.entitiesOf(ImportEntityType.dives);
    expect(dives[0]['tagRefs'], ['Reef', 'Ann Lee']);
    // The unowned dive gets no tag, and Bo's profile holds only Bo.
    expect(dives[2].containsKey('tagRefs'), isFalse);
    expect(dives[1].containsKey('tagRefs'), isFalse);
    expect(_targets(out, ImportEntityType.tags, 'Ann Lee'), [_active]);
    expect(_targets(out, ImportEntityType.tags, 'Bo Ray'), isEmpty);
  });

  test('expansion is pure and repeatable', () {
    final source = _source();
    final first = _expand(source);
    expect(_expand(source), first);
    expect(source, _source());
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/payload_diver_expander_test.dart`
Expected: FAIL to compile: `payload_diver_expander.dart` not found.

- [ ] **Step 3: Implement**

Create `lib/features/universal_import/data/services/payload_diver_expander.dart`:

```dart
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/payload_ref_keys.dart';

/// Splits a multi-diver payload across the profiles the Divers step chose
/// (issue #1893).
///
/// Every item of the result carries [DiverTarget.itemKey]. Dives and
/// certifications take their source diver's target. Reference items (sites,
/// buddies, gear, tags and the rest) follow the dives that use them: one copy
/// per target whose dives reference the item, `uddfId` unchanged, which is
/// safe because PayloadSlicer later gives each target a payload of its own.
/// An item that only skipped dives use is dropped; an item no dive uses goes
/// to the primary target.
///
/// Pure: the same source and mapping always give an equal payload, so the
/// wizard re-expands from the parsed payload instead of from an earlier
/// expansion.
class PayloadDiverExpander {
  const PayloadDiverExpander._();

  /// Stand-in target for dives that are not imported.
  static const _droppedKey = '_dropped';

  /// Reference types, in the order they are emitted.
  static const _referenceTypes = [
    ImportEntityType.sites,
    ImportEntityType.trips,
    ImportEntityType.equipment,
    ImportEntityType.equipmentSets,
    ImportEntityType.buddies,
    ImportEntityType.diveCenters,
    ImportEntityType.courses,
    ImportEntityType.tags,
    ImportEntityType.diveTypes,
  ];

  static ImportPayload expand(
    ImportPayload source,
    Map<String, DiverTarget> mapping, {
    required String activeDiverId,
  }) {
    DiverTarget resolve(String? sourceKey) =>
        mapping[sourceKey ?? SourceDiver.unownedKey] ??
        ExistingDiverTarget(activeDiverId);

    final dives = <Map<String, dynamic>>[];
    final dropped = <Map<String, dynamic>>[];
    final newDiveIndex = <int, int>{};
    final diveTargetByUuid = <String, String>{};
    final sourceDives = source.entitiesOf(ImportEntityType.dives);
    for (var i = 0; i < sourceDives.length; i++) {
      final dive = sourceDives[i];
      final target =
          resolve(dive[SourceDiver.mapKey] as String?).targetKey ?? _droppedKey;
      if (dive['sourceUuid'] case final String uuid) {
        diveTargetByUuid[uuid] = target;
      }
      final copy = {...dive, DiverTarget.itemKey: target};
      if (target == _droppedKey) {
        dropped.add(copy);
        continue;
      }
      newDiveIndex[i] = dives.length;
      dives.add(copy);
    }

    final used = _RefUsage.of(source, dives);
    final usedByDropped = _RefUsage.of(source, dropped);
    final primary = _primaryTarget(
      source.sourceDivers,
      resolve,
      activeDiverId,
    );

    final out = <ImportEntityType, List<Map<String, dynamic>>>{
      ImportEntityType.dives: dives,
    };
    final equipmentTargets = <String, List<String>>{};
    for (final type in _referenceTypes) {
      final items = <Map<String, dynamic>>[];
      for (final item in source.entitiesOf(type)) {
        final ref = refOf(type, item);
        final List<String> targets;
        if (used.targetsOf(type, ref).isNotEmpty) {
          targets = used.targetsOf(type, ref).toList();
        } else if (usedByDropped.targetsOf(type, ref).isNotEmpty) {
          targets = const [];
        } else {
          targets = [?primary];
        }
        for (final target in targets) {
          items.add(_copyFor(type, item, target, diveTargetByUuid));
        }
        if (type == ImportEntityType.equipment && ref != null) {
          equipmentTargets[ref] = targets;
        }
      }
      out[type] = items;
    }

    out[ImportEntityType.certifications] = [
      for (final cert in source.entitiesOf(ImportEntityType.certifications))
        if (resolve(cert[SourceDiver.mapKey] as String?).targetKey
            case final target?)
          {...cert, DiverTarget.itemKey: target},
    ];

    // A service record rides with every copy of its equipment.
    out[ImportEntityType.serviceRecords] = [
      for (final record in source.entitiesOf(ImportEntityType.serviceRecords))
        for (final target in switch (record['equipmentRef']) {
          final String ref when equipmentTargets.containsKey(ref) =>
            equipmentTargets[ref]!,
          _ => [?primary],
        })
          {...record, DiverTarget.itemKey: target},
    ];

    final media = <Map<String, dynamic>>[];
    for (final item in source.entitiesOf(ImportEntityType.media)) {
      final oldIndex = item['_diveIndex'];
      if (oldIndex is int) {
        final newIndex = newDiveIndex[oldIndex];
        if (newIndex == null) continue;
        media.add({
          ...item,
          '_diveIndex': newIndex,
          DiverTarget.itemKey: dives[newIndex][DiverTarget.itemKey],
        });
      } else if (primary != null) {
        media.add({...item, DiverTarget.itemKey: primary});
      }
    }
    out[ImportEntityType.media] = media;

    _addNameTags(out, source.sourceDivers);

    return ImportPayload(
      entities: {
        for (final entry in out.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      },
      warnings: source.warnings,
      metadata: source.metadata,
      sourceDivers: source.sourceDivers,
    );
  }

  /// The id dives use to reference [item]: the slug for a dive type,
  /// otherwise its `uddfId`, otherwise its name (the importer's fallback).
  static String? refOf(ImportEntityType type, Map<String, dynamic> item) {
    final id = type == ImportEntityType.diveTypes
        ? (item['id'] ?? item['uddfId'])
        : (item['uddfId'] ?? item['name']);
    return id is String && id.isNotEmpty ? id : null;
  }

  /// The target unused items go to: the active profile when any diver maps
  /// to it, otherwise the target of the mapped diver with the most dives.
  static String? _primaryTarget(
    List<SourceDiver> divers,
    DiverTarget Function(String?) resolve,
    String activeDiverId,
  ) {
    final activeKey = ExistingDiverTarget(activeDiverId).targetKey;
    String? best;
    var bestDives = -1;
    for (final diver in divers) {
      final key = resolve(diver.key).targetKey;
      if (key == null) continue;
      if (key == activeKey) return activeKey;
      if (diver.diveCount > bestDives) {
        best = key;
        bestDives = diver.diveCount;
      }
    }
    return best;
  }

  /// [item] stamped for [target]. A gear copy keeps only the check-ins of
  /// its own target's dives, plus any not tied to a dive in this file.
  static Map<String, dynamic> _copyFor(
    ImportEntityType type,
    Map<String, dynamic> item,
    String target,
    Map<String, String> diveTargetByUuid,
  ) {
    final copy = <String, dynamic>{...item, DiverTarget.itemKey: target};
    final observations = item['observations'];
    if (type == ImportEntityType.equipment && observations is List) {
      copy['observations'] = [
        for (final o in observations)
          if (o is! Map ||
              switch (o['diveRef']) {
                final String ref when diveTargetByUuid.containsKey(ref) =>
                  diveTargetByUuid[ref] == target,
                _ => true,
              })
            o,
      ];
    }
    return copy;
  }

  /// When one target takes dives from two or more source divers, tags each
  /// dive with the name it was logged under so the merged profile can still
  /// tell them apart (#912). The unowned row gets no tag.
  static void _addNameTags(
    Map<ImportEntityType, List<Map<String, dynamic>>> out,
    List<SourceDiver> sourceDivers,
  ) {
    String sourceOf(Map<String, dynamic> dive) =>
        dive[SourceDiver.mapKey] as String? ?? SourceDiver.unownedKey;

    final dives = out[ImportEntityType.dives]!;
    final sourcesByTarget = <String, Set<String>>{};
    for (final dive in dives) {
      (sourcesByTarget[dive[DiverTarget.itemKey] as String] ??= {}).add(
        sourceOf(dive),
      );
    }
    final nameByKey = {for (final d in sourceDivers) d.key: d.name.trim()};
    final tags = out[ImportEntityType.tags] ??= [];

    for (final MapEntry(key: target, value: sources)
        in sourcesByTarget.entries) {
      if (sources.length < 2) continue;
      for (final sourceKey in sources) {
        final name = nameByKey[sourceKey] ?? '';
        if (sourceKey == SourceDiver.unownedKey || name.isEmpty) continue;
        final exists = tags.any(
          (t) => t[DiverTarget.itemKey] == target && t['uddfId'] == name,
        );
        if (!exists) {
          tags.add({'name': name, 'uddfId': name, DiverTarget.itemKey: target});
        }
        for (var i = 0; i < dives.length; i++) {
          final dive = dives[i];
          if (dive[DiverTarget.itemKey] != target) continue;
          if (sourceOf(dive) != sourceKey) continue;
          final refs = [...?(dive['tagRefs'] as List?)];
          if (!refs.contains(name)) dives[i] = {...dive, 'tagRefs': [...refs, name]};
        }
      }
    }
  }
}

/// Which targets reference each item, by entity type and reference id.
class _RefUsage {
  _RefUsage._();

  final Map<ImportEntityType, Map<String, Set<String>>> _targets = {};

  /// Usage by [dives] (each stamped with its target), including items only
  /// reached through another item.
  factory _RefUsage.of(ImportPayload source, List<Map<String, dynamic>> dives) {
    final usage = _RefUsage._();
    for (final dive in dives) {
      usage._addDive(dive, dive[DiverTarget.itemKey] as String);
    }
    usage._followLinks(source);
    return usage;
  }

  Set<String> targetsOf(ImportEntityType type, String? ref) =>
      ref == null ? const {} : (_targets[type]?[ref] ?? const {});

  /// Records [target] as a user of [ref]; true when that is new.
  bool _add(ImportEntityType type, Object? ref, String target) {
    if (ref is! String || ref.isEmpty) return false;
    return ((_targets[type] ??= {})[ref] ??= <String>{}).add(target);
  }

  void _addDive(Map<String, dynamic> dive, String target) {
    final site = dive['site'];
    if (site is Map) _add(ImportEntityType.sites, site['uddfId'], target);
    for (final MapEntry(:key, value: type) in diveScalarRefTypes.entries) {
      _add(type, dive[key], target);
    }
    for (final MapEntry(:key, value: type) in diveListRefTypes.entries) {
      final refs = dive[key];
      if (refs is List) {
        for (final ref in refs) {
          _add(type, ref, target);
        }
      }
    }
    _addNested(dive['gearLinks'], gearLinkRefTypes, target);
    _addNested(dive['buddyRoleRefs'], buddyRoleRefTypes, target);
    final typeIds = dive['diveTypeIds'];
    if (typeIds is List) {
      for (final id in typeIds) {
        _add(ImportEntityType.diveTypes, id, target);
      }
    }
    _add(ImportEntityType.diveTypes, dive['diveType'], target);
  }

  void _addNested(
    Object? entries,
    Map<String, ImportEntityType> fields,
    String target,
  ) {
    if (entries is! List) return;
    for (final entry in entries) {
      if (entry is! Map) continue;
      for (final MapEntry(:key, value: type) in fields.entries) {
        _add(type, entry[key], target);
      }
    }
  }

  /// Items reached through another item follow it: an item's components and
  /// parent, a set's items, a course's instructor. Repeats until nothing new
  /// is reached, so chains of any depth are followed.
  void _followLinks(ImportPayload source) {
    var changed = true;
    while (changed) {
      changed = false;
      void follow(
        ImportEntityType fromType,
        ImportEntityType toType,
        Map<String, dynamic> item,
        List<Object?> linked,
      ) {
        final ref = PayloadDiverExpander.refOf(fromType, item);
        for (final target in targetsOf(fromType, ref).toList()) {
          for (final link in linked) {
            if (_add(toType, link, target)) changed = true;
          }
        }
      }

      for (final item in source.entitiesOf(ImportEntityType.equipment)) {
        final components = item['components'];
        follow(ImportEntityType.equipment, ImportEntityType.equipment, item, [
          item['parentRef'],
          if (components is List)
            for (final c in components)
              if (c is Map) c[componentRefTypes.keys.single],
        ]);
      }
      for (final set in source.entitiesOf(ImportEntityType.equipmentSets)) {
        final refs = set['equipmentRefs'];
        follow(
          ImportEntityType.equipmentSets,
          ImportEntityType.equipment,
          set,
          [if (refs is List) ...refs],
        );
      }
      for (final course in source.entitiesOf(ImportEntityType.courses)) {
        follow(ImportEntityType.courses, ImportEntityType.buddies, course, [
          course['instructorRef'],
        ]);
      }
    }
  }
}
```

Notes for the implementer:
- `[?primary]` is a null-aware list element (Dart 3.8+), already used in this repo (`review_step.dart`, `universal_adapter.dart`).
- `_RefUsage` keeps `LinkedHashSet` insertion order (the default `<String>{}`), which is what makes a shared item's copies come out in first-dive order (`[_active, _newBo]` in the tests).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/payload_diver_expander_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/universal_import/data/services/payload_diver_expander.dart test/features/universal_import/data/services/payload_diver_expander_test.dart
git commit -m "feat(import): split a multi-diver payload across target profiles (#1893)"
```

---

### Task 8: PayloadSlicer and duplicate-result remapping

**Files:**
- Create: `lib/features/universal_import/data/services/payload_slicer.dart`
- Create: `lib/features/universal_import/data/services/diver_slice_duplicates.dart`
- Test: `test/features/universal_import/data/services/payload_slicer_test.dart`

**Interfaces:**
- Consumes: `DiverTarget.itemKey` (Task 6); `ImportDuplicateResult` (`lib/features/universal_import/data/services/import_duplicate_checker.dart`, fields `duplicates`, `diveMatches`, `entityMatches`); `DiveMatchResult` (`lib/features/dive_import/domain/services/dive_matcher.dart`, has `inBatchIndex`).
- Produces:
  - `class DiverSlice { String? targetKey; ImportPayload payload; Map<ImportEntityType, List<int>> globalIndices; int toGlobal(type, local); Set<int> toLocalSet(type, Iterable<int> globals); Map<int, V> toLocalMap<V>(type, Map<int, V> globals); Set<int> toGlobalSet(type, Iterable<int> locals); Map<int, V> toGlobalMap<V>(type, Map<int, V> locals); int? localIndexOf(type, int global); }` (types are the universal-import `ImportEntityType`).
  - `PayloadSlicer.slice(ImportPayload payload, {String? firstTargetKey}) -> List<DiverSlice>`: an unexpanded payload gives one slice with `targetKey == null` and identity indices.
  - `ImportDuplicateResult duplicatesToGlobal(DiverSlice slice, ImportDuplicateResult local)`, `ImportDuplicateResult mergeDuplicateResults(Iterable<ImportDuplicateResult> results)`, `DiveMatchResult withInBatchIndex(DiveMatchResult match, int? inBatchIndex)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/universal_import/data/services/payload_slicer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/diver_slice_duplicates.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

const _key = DiverTarget.itemKey;

const _expanded = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'n': 0, _key: 'diver:a'},
      {'n': 1, _key: 'new:b'},
      {'n': 2, _key: 'diver:a'},
    ],
    ImportEntityType.sites: [
      {'uddfId': 'S', _key: 'diver:a'},
      {'uddfId': 'S', _key: 'new:b'},
    ],
    ImportEntityType.media: [
      {'filename': 'x.jpg', '_diveIndex': 2, _key: 'diver:a'},
      {'filename': 'y.jpg', '_diveIndex': 1, _key: 'new:b'},
    ],
  },
);

void main() {
  group('PayloadSlicer', () {
    test('an unexpanded payload is one untargeted identity slice', () {
      const payload = ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'n': 0},
            {'n': 1},
          ],
        },
      );
      final slices = PayloadSlicer.slice(payload, firstTargetKey: 'diver:a');
      expect(slices, hasLength(1));
      expect(slices.single.targetKey, isNull);
      expect(slices.single.payload, same(payload));
      expect(slices.single.globalIndices[ImportEntityType.dives], [0, 1]);
    });

    test('splits by target, the first target first', () {
      final slices = PayloadSlicer.slice(_expanded, firstTargetKey: 'new:b');
      expect(slices.map((s) => s.targetKey), ['new:b', 'diver:a']);
      final a = slices[1];
      expect(
        a.payload.entitiesOf(ImportEntityType.dives).map((d) => d['n']),
        [0, 2],
      );
      expect(a.globalIndices[ImportEntityType.dives], [0, 2]);
      expect(a.globalIndices[ImportEntityType.sites], [0]);
    });

    test('a first target with no items gets no slice', () {
      final slices = PayloadSlicer.slice(_expanded, firstTargetKey: 'diver:z');
      expect(slices.map((s) => s.targetKey), ['diver:a', 'new:b']);
    });

    test('renumbers media against the slice dives', () {
      final slices = PayloadSlicer.slice(_expanded);
      final aMedia = slices[0].payload.entitiesOf(ImportEntityType.media);
      final bMedia = slices[1].payload.entitiesOf(ImportEntityType.media);
      expect(aMedia.single['_diveIndex'], 1);
      expect(bMedia.single['_diveIndex'], 0);
    });

    test('index helpers translate both ways', () {
      final a = PayloadSlicer.slice(_expanded).first;
      const dives = ImportEntityType.dives;
      expect(a.toGlobal(dives, 1), 2);
      expect(a.toLocalSet(dives, {0, 1, 2}), {0, 1});
      expect(a.toLocalMap(dives, {1: 'b', 2: 'c'}), {1: 'c'});
      expect(a.toGlobalSet(dives, {1}), {2});
      expect(a.toGlobalMap(dives, {1: 'x'}), {2: 'x'});
      expect(a.localIndexOf(dives, 1), isNull);
    });
  });

  group('duplicate remapping', () {
    const match = EntityMatchResult(
      existingId: 'e',
      existingName: 'S',
      existingFields: {},
      incomingFields: {},
    );

    test('maps indices and in-batch pointers to the full payload', () {
      final a = PayloadSlicer.slice(_expanded).first;
      final global = duplicatesToGlobal(
        a,
        const ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {0},
          },
          diveMatches: {
            1: DiveMatchResult(
              diveId: '',
              score: 1,
              timeDifferenceMs: 0,
              inBatchIndex: 0,
            ),
          },
          entityMatches: {
            ImportEntityType.sites: {0: match},
          },
        ),
      );
      expect(global.duplicates[ImportEntityType.sites], {0});
      expect(global.diveMatches.keys, [2]);
      expect(global.diveMatches[2]!.inBatchIndex, 0);
      expect(global.entityMatches[ImportEntityType.sites], {0: match});
    });

    test('merges per-slice results', () {
      final merged = mergeDuplicateResults(const [
        ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {0},
          },
        ),
        ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {1},
          },
          entityMatches: {
            ImportEntityType.sites: {1: match},
          },
        ),
      ]);
      expect(merged.duplicates[ImportEntityType.sites], {0, 1});
      expect(merged.entityMatches[ImportEntityType.sites], {1: match});
    });

    test('withInBatchIndex keeps every other field', () {
      const original = DiveMatchResult(
        diveId: 'd',
        score: 0.8,
        timeDifferenceMs: 5,
        depthDifferenceMeters: 1.5,
        durationDifferenceSeconds: 30,
        siteName: 'S',
        matchedComputerId: 'c',
        matchedExistingSource: true,
        inBatchIndex: 3,
      );
      final moved = withInBatchIndex(original, 7);
      expect(moved.inBatchIndex, 7);
      expect(moved.diveId, 'd');
      expect(moved.score, 0.8);
      expect(moved.timeDifferenceMs, 5);
      expect(moved.depthDifferenceMeters, 1.5);
      expect(moved.durationDifferenceSeconds, 30);
      expect(moved.siteName, 'S');
      expect(moved.matchedComputerId, 'c');
      expect(moved.matchedExistingSource, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/payload_slicer_test.dart`
Expected: FAIL to compile: missing files.

- [ ] **Step 3: Create `payload_slicer.dart`**

```dart
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// One target's share of an expanded payload, with the index maps that
/// translate between its own lists and the full payload's (issue #1893).
///
/// Review selections, duplicate results and the importer's `diveIdByIndex`
/// are all keyed by list index. Every translation between a slice and the
/// full payload goes through these helpers, so there is one place to get it
/// right.
class DiverSlice {
  const DiverSlice({
    required this.targetKey,
    required this.payload,
    required this.globalIndices,
  });

  /// The [DiverTarget.itemKey] of every item in [payload]; null for a
  /// payload that was never expanded (a single-diver import).
  final String? targetKey;

  final ImportPayload payload;

  /// Per entity type, the full-payload index of each slice item, in order.
  final Map<ImportEntityType, List<int>> globalIndices;

  int toGlobal(ImportEntityType type, int local) =>
      globalIndices[type]![local];

  /// The slice index of full-payload [global], or null outside this slice.
  int? localIndexOf(ImportEntityType type, int global) =>
      _positions(type)[global];

  /// The members of [globals] that belong to this slice, as slice indices.
  Set<int> toLocalSet(ImportEntityType type, Iterable<int> globals) {
    final positions = _positions(type);
    return {
      for (final g in globals)
        if (positions[g] case final local?) local,
    };
  }

  Map<int, V> toLocalMap<V>(ImportEntityType type, Map<int, V> globals) {
    final positions = _positions(type);
    return {
      for (final entry in globals.entries)
        if (positions[entry.key] case final local?) local: entry.value,
    };
  }

  Set<int> toGlobalSet(ImportEntityType type, Iterable<int> locals) => {
    for (final l in locals) toGlobal(type, l),
  };

  Map<int, V> toGlobalMap<V>(ImportEntityType type, Map<int, V> locals) => {
    for (final entry in locals.entries)
      toGlobal(type, entry.key): entry.value,
  };

  Map<int, int> _positions(ImportEntityType type) {
    final indices = globalIndices[type] ?? const <int>[];
    return {for (var i = 0; i < indices.length; i++) indices[i]: i};
  }
}

/// Splits an expanded payload by [DiverTarget.itemKey] (issue #1893).
class PayloadSlicer {
  const PayloadSlicer._();

  /// One slice per target. [firstTargetKey] (the active profile) comes first
  /// when it has items, then targets in the order their first dive appears,
  /// then targets only reference items carry. A payload without target keys
  /// is returned whole as a single untargeted slice.
  static List<DiverSlice> slice(
    ImportPayload payload, {
    String? firstTargetKey,
  }) {
    final targeted = payload.entities.values.any(
      (items) => items.any((item) => item[DiverTarget.itemKey] is String),
    );
    if (!targeted) {
      return [
        DiverSlice(
          targetKey: null,
          payload: payload,
          globalIndices: {
            for (final entry in payload.entities.entries)
              entry.key: [for (var i = 0; i < entry.value.length; i++) i],
          },
        ),
      ];
    }

    final order = <String>[?firstTargetKey];
    void see(Object? key) {
      if (key is String && !order.contains(key)) order.add(key);
    }

    for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
      see(dive[DiverTarget.itemKey]);
    }
    for (final items in payload.entities.values) {
      for (final item in items) {
        see(item[DiverTarget.itemKey]);
      }
    }

    final slices = <DiverSlice>[];
    for (final target in order) {
      final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
      final globalIndices = <ImportEntityType, List<int>>{};
      for (final MapEntry(key: type, value: items)
          in payload.entities.entries) {
        for (var i = 0; i < items.length; i++) {
          if (items[i][DiverTarget.itemKey] != target) continue;
          (entities[type] ??= []).add(items[i]);
          (globalIndices[type] ??= []).add(i);
        }
      }
      if (entities.isEmpty) continue;

      // Media point at dives by index, so they are renumbered against this
      // slice's own dive list.
      final media = entities[ImportEntityType.media];
      if (media != null) {
        final diveIndices = globalIndices[ImportEntityType.dives] ?? const [];
        final localDive = {
          for (var i = 0; i < diveIndices.length; i++) diveIndices[i]: i,
        };
        entities[ImportEntityType.media] = [
          for (final m in media)
            if (m['_diveIndex'] case final int g)
              {...m, '_diveIndex': localDive[g]}
            else
              m,
        ];
      }

      slices.add(
        DiverSlice(
          targetKey: target,
          payload: ImportPayload(
            entities: entities,
            warnings: payload.warnings,
            metadata: payload.metadata,
            sourceDivers: payload.sourceDivers,
          ),
          globalIndices: globalIndices,
        ),
      );
    }
    return slices;
  }
}
```

- [ ] **Step 4: Create `diver_slice_duplicates.dart`**

```dart
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

/// One slice's duplicate check, moved onto the full payload's indices
/// (issue #1893). An in-batch pointer names another dive of the same slice,
/// so it moves too.
ImportDuplicateResult duplicatesToGlobal(
  DiverSlice slice,
  ImportDuplicateResult local,
) {
  const dives = ImportEntityType.dives;
  return ImportDuplicateResult(
    duplicates: {
      for (final entry in local.duplicates.entries)
        entry.key: slice.toGlobalSet(entry.key, entry.value),
    },
    diveMatches: {
      for (final entry in local.diveMatches.entries)
        slice.toGlobal(dives, entry.key): withInBatchIndex(
          entry.value,
          switch (entry.value.inBatchIndex) {
            final int i => slice.toGlobal(dives, i),
            null => null,
          },
        ),
    },
    entityMatches: {
      for (final entry in local.entityMatches.entries)
        entry.key: slice.toGlobalMap(entry.key, entry.value),
    },
  );
}

/// Results that [duplicatesToGlobal] already moved, combined into one.
ImportDuplicateResult mergeDuplicateResults(
  Iterable<ImportDuplicateResult> results,
) {
  final duplicates = <ImportEntityType, Set<int>>{};
  final diveMatches = <int, DiveMatchResult>{};
  final entityMatches = <ImportEntityType, Map<int, EntityMatchResult>>{};
  for (final result in results) {
    result.duplicates.forEach(
      (type, indices) => (duplicates[type] ??= {}).addAll(indices),
    );
    diveMatches.addAll(result.diveMatches);
    result.entityMatches.forEach(
      (type, matches) => (entityMatches[type] ??= {}).addAll(matches),
    );
  }
  return ImportDuplicateResult(
    duplicates: duplicates,
    diveMatches: diveMatches,
    entityMatches: entityMatches,
  );
}

/// [match] with its in-batch pointer replaced; every other field is kept.
DiveMatchResult withInBatchIndex(DiveMatchResult match, int? inBatchIndex) {
  return DiveMatchResult(
    diveId: match.diveId,
    score: match.score,
    timeDifferenceMs: match.timeDifferenceMs,
    depthDifferenceMeters: match.depthDifferenceMeters,
    durationDifferenceSeconds: match.durationDifferenceSeconds,
    siteName: match.siteName,
    matchedComputerId: match.matchedComputerId,
    matchedExistingSource: match.matchedExistingSource,
    inBatchIndex: inBatchIndex,
  );
}
```

Before writing `withInBatchIndex`, open `lib/features/dive_import/domain/services/dive_matcher.dart:78-110` and confirm the field list is exactly the nine above. If `DiveMatchResult` has gained a field, pass it through too and add it to the test.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/payload_slicer_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/universal_import/data/services/payload_slicer.dart lib/features/universal_import/data/services/diver_slice_duplicates.dart test/features/universal_import/data/services/payload_slicer_test.dart
git commit -m "feat(import): slice an expanded payload per target profile (#1893)"
```

---

### Task 9: Import state keeps the parsed payload and the diver mapping

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart:35-67,165-172,187-290`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart:851-859,918-925` and add three methods
- Test: `test/features/universal_import/presentation/providers/universal_import_diver_mapping_test.dart`

**Interfaces:**
- Consumes: `defaultDiverMapping` (Task 6), `PayloadDiverExpander` (Task 7), `DiverTarget` (Task 6), `Diver`.
- Produces:
  - `UniversalImportState.sourcePayload` (`ImportPayload?`), `.diverMapping` (`Map<String, DiverTarget>`, default `const {}`), getter `parsedPayload` (`sourcePayload ?? payload`); `copyWith(..., ImportPayload? sourcePayload, Map<String, DiverTarget>? diverMapping, bool clearDiverMapping = false)`. `clearPayload: true` also clears both.
  - `UniversalImportNotifier.initDiverMapping({required List<Diver> profiles, required String activeDiverId})`, `.setDiverTarget(String sourceKey, DiverTarget target)`, `.applyDiverMapping({required String activeDiverId})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/universal_import/presentation/providers/universal_import_diver_mapping_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

const _parsed = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'd1', SourceDiver.mapKey: _ann},
      {'sourceUuid': 'd2', SourceDiver.mapKey: _bo},
    ],
    ImportEntityType.media: [
      {'filename': 'b.jpg', '_diveIndex': 1},
    ],
  },
  sourceDivers: [
    SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
    SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
  ],
);

final _me = Diver(
  id: 'me',
  name: 'Me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(payload: _parsed);
  });

  tearDown(() => container.dispose());

  test('initDiverMapping seeds the defaults once', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping, {
      _ann: const ExistingDiverTarget('me'),
      _bo: const NewDiverTarget(_bo),
    });

    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping[_bo], const SkipDiverTarget());
  });

  test('initDiverMapping ignores a single-diver payload', () {
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(
        entities: {},
        sourceDivers: [SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 3)],
      ),
    );
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping, isEmpty);
  });

  test('applyDiverMapping always expands from the parsed payload', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.sourcePayload, _parsed);
    expect(
      notifier.state.payload!
          .entitiesOf(ImportEntityType.dives)
          .map((d) => d[DiverTarget.itemKey]),
      ['diver:me', 'new:$_bo'],
    );

    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.payload!.entitiesOf(ImportEntityType.dives), [
      {'sourceUuid': 'd1', SourceDiver.mapKey: _ann, DiverTarget.itemKey: 'diver:me'},
    ]);
    expect(notifier.state.parsedPayload, _parsed);
  });

  test('a changed media list drops the photo resolution', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    notifier.state = notifier.state.copyWith(
      photoResolution: ImportMediaResolution(
        resolvedPathByIndex: const {0: '/p/b.jpg'},
        reRootedCount: 0,
        filenameOnlyCount: 0,
        notFoundCount: 0,
      ),
    );

    // Same mapping, same media: the resolution stays.
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.photoResolution, isNotNull);

    // Skipping Bo removes his photo, so the resolution no longer lines up.
    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.photoResolution, isNull);
  });

  test('clearing the payload clears the diver state', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    notifier.state = notifier.state.copyWith(clearPayload: true);
    expect(notifier.state.sourcePayload, isNull);
    expect(notifier.state.diverMapping, isEmpty);
    expect(notifier.state.parsedPayload, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_diver_mapping_test.dart`
Expected: FAIL to compile: `initDiverMapping`, `diverMapping`, `sourcePayload` undefined.

- [ ] **Step 3: Extend `UniversalImportState`**

In `universal_import_state.dart`, add `import 'package:submersion/features/universal_import/data/models/diver_target.dart';`. Add constructor parameters after `this.payload,`:

```dart
    this.sourcePayload,
    this.diverMapping = const {},
```

Add fields after `final ImportPayload? payload;`:

```dart
  /// The payload as parsed, kept once the Divers step has split [payload]
  /// across profiles (issue #1893). Every re-expansion starts from here, so
  /// walking Back through the step never expands an expansion.
  final ImportPayload? sourcePayload;

  /// The Divers step's choice per source diver key (issue #1893).
  final Map<String, DiverTarget> diverMapping;

  /// The parsed payload, whether or not it has been split across profiles.
  ImportPayload? get parsedPayload => sourcePayload ?? payload;
```

In `copyWith`, add parameters after `bool clearPayload = false,`:

```dart
    ImportPayload? sourcePayload,
    Map<String, DiverTarget>? diverMapping,
    bool clearDiverMapping = false,
```

and in the returned `UniversalImportState(...)`, after the `payload:` line:

```dart
      // A payload cleared or replaced by a new parse takes the diver state
      // that was derived from it along.
      sourcePayload: clearPayload || clearDiverMapping
          ? null
          : (sourcePayload ?? this.sourcePayload),
      diverMapping: clearPayload || clearDiverMapping
          ? const {}
          : (diverMapping ?? this.diverMapping),
```

- [ ] **Step 4: Reset diver state on every fresh parse**

In `universal_import_providers.dart`, add `clearDiverMapping: true,` to the two `state.copyWith(...)` calls that store a newly parsed payload: the one in `_parseBatch` (`payload: payload,` near line 858) and the one at the end of `_parseAndCheckDuplicates` (`payload: payload,` near line 923).

- [ ] **Step 5: Add the notifier methods**

In `universal_import_providers.dart`, add imports:

```dart
import 'package:collection/collection.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/services/default_diver_mapping.dart';
import 'package:submersion/features/universal_import/data/services/payload_diver_expander.dart';
```

(If `package:collection` is already imported, skip it. It is a direct dependency in `pubspec.yaml`.) Add these methods just above `void clearExternalLoadFlag()`:

```dart
  // -- Divers step (issue #1893) --

  /// Seeds the Divers step's choices for a multi-diver payload. A mapping
  /// already present is kept, so walking Back and Next never resets choices
  /// the user made; a fresh parse clears it first.
  void initDiverMapping({
    required List<Diver> profiles,
    required String activeDiverId,
  }) {
    final parsed = state.parsedPayload;
    if (parsed == null || !parsed.needsDiverMapping) return;
    if (state.diverMapping.isNotEmpty) return;
    state = state.copyWith(
      diverMapping: defaultDiverMapping(
        sourceDivers: parsed.sourceDivers,
        profiles: profiles,
        activeDiverId: activeDiverId,
      ),
    );
  }

  void setDiverTarget(String sourceKey, DiverTarget target) {
    state = state.copyWith(
      diverMapping: {...state.diverMapping, sourceKey: target},
    );
  }

  /// Splits the parsed payload across profiles per [diverMapping], always
  /// starting from the parsed payload. A photo resolution is keyed by media
  /// index, so it is dropped when the media list changes under it.
  void applyDiverMapping({required String activeDiverId}) {
    final parsed = state.parsedPayload;
    if (parsed == null || !parsed.needsDiverMapping) return;
    final expanded = PayloadDiverExpander.expand(
      parsed,
      state.diverMapping,
      activeDiverId: activeDiverId,
    );
    final mediaChanged = !const DeepCollectionEquality().equals(
      expanded.entitiesOf(ImportEntityType.media),
      state.payload?.entitiesOf(ImportEntityType.media),
    );
    state = state.copyWith(
      sourcePayload: parsed,
      payload: expanded,
      clearPhotoResolution: mediaChanged,
    );
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_diver_mapping_test.dart`
Expected: PASS (5 tests).
Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`
Expected: PASS (no behaviour change for single-diver payloads).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/universal_import/presentation/providers/universal_import_state.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart test/features/universal_import/presentation/providers/universal_import_diver_mapping_test.dart
git commit -m "feat(import): keep the parsed payload and diver choices in import state (#1893)"
```

---

### Task 10: Localized strings

**Files:**
- Modify: `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Scratch (not committed): `<scratchpad>/add_1893_strings.py`

**Interfaces:**
- Produces (generated on `AppLocalizations`): `universalImport_divers_intro(num count)`, `universalImport_divers_diveCount(num count)`, `universalImport_divers_certificationCount(num count)`, `universalImport_divers_unownedRow`, `universalImport_divers_targetLabel`, `universalImport_divers_targetNew(String name)`, `universalImport_divers_targetSkip`, `universalImport_divers_newLabel(String name)`, `universalImport_summary_byProfileTitle`, `universalImport_summary_newProfile`, `universalImport_summary_switchToSee(String name)`. The existing `universalImport_summary_fileImported(num count)` is reused for per-profile dive counts.

- [ ] **Step 1: Write the insertion script**

The anchor `"universalImport_summary_filesTitle"` exists in all 11 files. Non-English ARB files are grouped by feature, not sorted, so every file gets the new keys directly after that anchor line; English also gets the `@` metadata there (ARB metadata may sit anywhere). Create the script in the session scratchpad directory:

```python
import json
import pathlib

ANCHOR = '"universalImport_summary_filesTitle":'
KEYS = [
    'universalImport_divers_intro',
    'universalImport_divers_diveCount',
    'universalImport_divers_certificationCount',
    'universalImport_divers_unownedRow',
    'universalImport_divers_targetLabel',
    'universalImport_divers_targetNew',
    'universalImport_divers_targetSkip',
    'universalImport_divers_newLabel',
    'universalImport_summary_byProfileTitle',
    'universalImport_summary_newProfile',
    'universalImport_summary_switchToSee',
]
COUNT = {'placeholders': {'count': {'type': 'num'}}}
NAME = {'placeholders': {'name': {'type': 'String'}}}
META = {
    'universalImport_divers_intro': {'description': 'Explains the import wizard Divers step for a logbook holding several divers', **COUNT},
    'universalImport_divers_diveCount': {'description': 'Dive count of one diver row in the Divers step', **COUNT},
    'universalImport_divers_certificationCount': {'description': 'Certification count of one diver row in the Divers step', **COUNT},
    'universalImport_divers_unownedRow': {'description': 'Divers step row for dives the logbook attributes to no diver'},
    'universalImport_divers_targetLabel': {'description': 'Label of the profile picker on a Divers step row'},
    'universalImport_divers_targetNew': {'description': 'Divers step choice that creates a profile named after the diver', **NAME},
    'universalImport_divers_targetSkip': {'description': 'Divers step choice that leaves the diver out of the import'},
    'universalImport_divers_newLabel': {'description': 'Review row label for an item going to a profile the import will create', **NAME},
    'universalImport_summary_byProfileTitle': {'description': 'Import summary section listing what each diver profile received'},
    'universalImport_summary_newProfile': {'description': 'Import summary label on a profile the import created'},
    'universalImport_summary_switchToSee': {'description': 'Import summary hint on a profile that is not the active one', **NAME},
}
T = {
    'en': ["{count, plural, other{This logbook has dives for {count} divers. Choose where each diver's dives and certifications go.}}", '{count, plural, =1{1 dive} other{{count} dives}}', '{count, plural, =1{1 certification} other{{count} certifications}}', 'Dives with no diver', 'Import into', 'Create new profile "{name}"', "Don't import", 'New: {name}', 'By profile', 'New profile', 'Switch to {name} to see these dives'],
    'de': ['{count, plural, other{Dieses Logbuch enthält Tauchgänge von {count} Tauchern. Wählen Sie, wohin die Tauchgänge und Brevets jedes Tauchers importiert werden.}}', '{count, plural, =1{1 Tauchgang} other{{count} Tauchgänge}}', '{count, plural, =1{1 Brevet} other{{count} Brevets}}', 'Tauchgänge ohne Taucher', 'Importieren in', 'Neues Profil „{name}“ anlegen', 'Nicht importieren', 'Neu: {name}', 'Nach Profil', 'Neues Profil', 'Wechseln Sie zu {name}, um diese Tauchgänge zu sehen'],
    'es': ['{count, plural, other{Este registro tiene inmersiones de {count} buceadores. Elige adónde van las inmersiones y certificaciones de cada buceador.}}', '{count, plural, =1{1 inmersión} other{{count} inmersiones}}', '{count, plural, =1{1 certificación} other{{count} certificaciones}}', 'Inmersiones sin buceador', 'Importar en', 'Crear perfil nuevo "{name}"', 'No importar', 'Nuevo: {name}', 'Por perfil', 'Perfil nuevo', 'Cambia a {name} para ver estas inmersiones'],
    'fr': ['{count, plural, other{Ce carnet contient des plongées de {count} plongeurs. Choisissez où importer les plongées et les brevets de chaque plongeur.}}', '{count, plural, =1{1 plongée} other{{count} plongées}}', '{count, plural, =1{1 brevet} other{{count} brevets}}', 'Plongées sans plongeur', 'Importer dans', 'Créer le profil « {name} »', 'Ne pas importer', 'Nouveau : {name}', 'Par profil', 'Nouveau profil', 'Passez à {name} pour voir ces plongées'],
    'it': ['{count, plural, other{Questo registro contiene immersioni di {count} subacquei. Scegli dove importare le immersioni e i brevetti di ciascun subacqueo.}}', '{count, plural, =1{1 immersione} other{{count} immersioni}}', '{count, plural, =1{1 brevetto} other{{count} brevetti}}', 'Immersioni senza subacqueo', 'Importa in', 'Crea nuovo profilo "{name}"', 'Non importare', 'Nuovo: {name}', 'Per profilo', 'Nuovo profilo', 'Passa a {name} per vedere queste immersioni'],
    'nl': ['{count, plural, other{Dit logboek bevat duiken van {count} duikers. Kies waar de duiken en brevetten van elke duiker naartoe gaan.}}', '{count, plural, =1{1 duik} other{{count} duiken}}', '{count, plural, =1{1 brevet} other{{count} brevetten}}', 'Duiken zonder duiker', 'Importeren in', 'Nieuw profiel "{name}" maken', 'Niet importeren', 'Nieuw: {name}', 'Per profiel', 'Nieuw profiel', 'Schakel over naar {name} om deze duiken te zien'],
    'pt': ['{count, plural, other{Este registro tem mergulhos de {count} mergulhadores. Escolha para onde vão os mergulhos e as certificações de cada mergulhador.}}', '{count, plural, =1{1 mergulho} other{{count} mergulhos}}', '{count, plural, =1{1 certificação} other{{count} certificações}}', 'Mergulhos sem mergulhador', 'Importar para', 'Criar novo perfil "{name}"', 'Não importar', 'Novo: {name}', 'Por perfil', 'Novo perfil', 'Mude para {name} para ver estes mergulhos'],
    'hu': ['{count, plural, other{Ez a napló {count} búvár merüléseit tartalmazza. Válaszd ki, hová kerüljenek az egyes búvárok merülései és minősítései.}}', '{count, plural, =1{1 merülés} other{{count} merülés}}', '{count, plural, =1{1 minősítés} other{{count} minősítés}}', 'Búvár nélküli merülések', 'Importálás ide', 'Új profil létrehozása: „{name}”', 'Ne importáld', 'Új: {name}', 'Profilonként', 'Új profil', 'Válts {name} profiljára a merülések megtekintéséhez'],
    'ar': ['{count, plural, other{يحتوي هذا السجل على غطسات لـ {count} غواصين. اختر وجهة غطسات وشهادات كل غواص.}}', '{count, plural, =1{غطسة واحدة} other{{count} غطسات}}', '{count, plural, =1{شهادة واحدة} other{{count} شهادات}}', 'غطسات بلا غواص', 'استيراد إلى', 'إنشاء ملف غواص جديد "{name}"', 'عدم الاستيراد', 'جديد: {name}', 'حسب ملف الغواص', 'ملف غواص جديد', 'انتقل إلى {name} لرؤية هذه الغطسات'],
    'he': ['{count, plural, other{יומן זה מכיל צלילות של {count} צוללים. בחר לאן ייובאו הצלילות וההסמכות של כל צולל.}}', '{count, plural, =1{צלילה אחת} other{{count} צלילות}}', '{count, plural, =1{הסמכה אחת} other{{count} הסמכות}}', 'צלילות ללא צולל', 'ייבוא אל', 'יצירת פרופיל חדש "{name}"', 'לא לייבא', 'חדש: {name}', 'לפי פרופיל', 'פרופיל חדש', 'עבור אל {name} כדי לראות צלילות אלה'],
    'zh': ['{count, plural, other{此日志包含 {count} 名潜水员的潜水记录。请选择每位潜水员的潜水和证书导入到哪里。}}', '{count, plural, other{{count} 次潜水}}', '{count, plural, other{{count} 个证书}}', '无潜水员的潜水', '导入到', '新建潜水员档案“{name}”', '不导入', '新建：{name}', '按潜水员档案', '新潜水员档案', '切换到 {name} 以查看这些潜水'],
}

for loc, values in T.items():
    assert len(values) == len(KEYS), loc
    path = pathlib.Path(f'lib/l10n/arb/app_{loc}.arb')
    text = path.read_text(encoding='utf-8')
    assert '"universalImport_divers_intro"' not in text, f'{loc} already has the keys'
    lines = text.splitlines(keepends=True)
    idx = next(i for i, line in enumerate(lines) if line.lstrip().startswith(ANCHOR))
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    new = [f'{indent}{json.dumps(k)}: {json.dumps(v, ensure_ascii=False)},\n' for k, v in zip(KEYS, values)]
    if loc == 'en':
        new += [f'{indent}{json.dumps("@" + k)}: {json.dumps(META[k], ensure_ascii=False)},\n' for k in KEYS]
    lines[idx + 1 : idx + 1] = new
    path.write_text(''.join(lines), encoding='utf-8')
    json.loads(path.read_text(encoding='utf-8'))
    print(loc, 'ok')
```

- [ ] **Step 2: Run it and regenerate**

Run (from the worktree root; system `python3` is 3.9 and too old for some repo scripts, so use 3.14):
```bash
LC_ALL=en_US.UTF-8 python3.14 <scratchpad>/add_1893_strings.py
flutter gen-l10n
git diff --numstat -- lib/l10n/arb/*.arb
```
Expected: 11 `ok` lines; numstat shows `22 0` for `app_en.arb` and `11 0` for each other ARB file; `flutter gen-l10n` exits 0 with no warnings about the new keys.

- [ ] **Step 3: Verify the generated API compiles**

Run: `flutter analyze lib/l10n`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_*.dart
git commit -m "feat(l10n): strings for the import Divers step and per-profile summary (#1893)"
```

---

### Task 11: The Divers step

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/diver_mapping_step.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart:141-153,232-274` (providers, step list, seeding)
- Modify: `test/features/import_wizard/data/adapters/universal_adapter_test.dart:477-486` (step count)
- Test: `test/features/import_wizard/presentation/widgets/diver_mapping_step_test.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`

**Interfaces:**
- Consumes: Task 9 notifier API, `orderedDiverRows`, `DiverTarget`, Task 10 strings, `allDiversProvider` and `validatedCurrentDiverIdProvider` (`lib/features/divers/presentation/providers/diver_providers.dart`).
- Produces: `DiverMappingStep` widget; `universalAdapterSingleDiverProvider` and `universalAdapterDiverMappingReadyProvider` (`Provider<bool>`); `UniversalAdapter.acquisitionSteps` is now Select File, Confirm Source, Map Fields, **Divers**, Photos.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/import_wizard/presentation/widgets/diver_mapping_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/diver_mapping_step.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

final _me = Diver(
  id: 'me',
  name: 'Me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allDiversProvider.overrideWith((ref) async => [_me]),
      ],
    );
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(
        entities: {},
        sourceDivers: [
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 3),
          SourceDiver(
            key: _ann,
            name: 'Ann Lee',
            diveCount: 5,
            certificationCount: 2,
          ),
          SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 1),
        ],
      ),
      diverMapping: const {
        _ann: ExistingDiverTarget('me'),
        _bo: NewDiverTarget(_bo),
        SourceDiver.unownedKey: ExistingDiverTarget('me'),
      },
    );
  });

  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiverMappingStep()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists each diver with counts and the current choice', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.textContaining('This logbook has dives for 2 divers'),
      findsOneWidget,
    );
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('5 dives · 2 certifications'), findsOneWidget);
    expect(find.text('Bo Ray'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('Dives with no diver'), findsOneWidget);
    expect(find.text('Create new profile "Bo Ray"'), findsOneWidget);
    // Ann (busiest) is listed before Bo.
    expect(
      tester.getTopLeft(find.text('Ann Lee')).dy,
      lessThan(tester.getTopLeft(find.text('Bo Ray')).dy),
    );
  });

  testWidgets('choosing a target updates the mapping', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('diver_target_$_ann')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't import").last);
    await tester.pumpAndSettle();

    expect(
      container.read(universalImportNotifierProvider).diverMapping[_ann],
      const SkipDiverTarget(),
    );
  });

  testWidgets('the no-diver row cannot create a profile', (tester) async {
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('diver_target_${SourceDiver.unownedKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Create new profile ""'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/widgets/diver_mapping_step_test.dart`
Expected: FAIL to compile: `diver_mapping_step.dart` not found.

- [ ] **Step 3: Create the widget**

Create `lib/features/import_wizard/presentation/widgets/diver_mapping_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The import wizard's Divers step (issue #1893): one row per diver in a
/// multi-diver logbook, each choosing the profile that diver's dives and
/// certifications go to.
class DiverMappingStep extends ConsumerWidget {
  const DiverMappingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final parsed = state.parsedPayload;
    if (parsed == null) return const SizedBox.shrink();

    final profiles =
        ref.watch(allDiversProvider).valueOrNull ?? const <Diver>[];
    final rows = orderedDiverRows(parsed.sourceDivers);
    final diverCount = rows.where((r) => !r.isUnowned).length;
    final notifier = ref.read(universalImportNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.l10n.universalImport_divers_intro(diverCount),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        for (final row in rows)
          _DiverRow(
            row: row,
            profiles: profiles,
            target: state.diverMapping[row.key],
            onChanged: (target) => notifier.setDiverTarget(row.key, target),
          ),
      ],
    );
  }
}

class _DiverRow extends StatelessWidget {
  const _DiverRow({
    required this.row,
    required this.profiles,
    required this.target,
    required this.onChanged,
  });

  final SourceDiver row;
  final List<Diver> profiles;
  final DiverTarget? target;
  final ValueChanged<DiverTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = <DiverTarget, String>{
      for (final profile in profiles)
        ExistingDiverTarget(profile.id): profile.name,
      // Dives with no diver have no name to give a new profile.
      if (!row.isUnowned)
        NewDiverTarget(row.key): l10n.universalImport_divers_targetNew(
          row.name,
        ),
      const SkipDiverTarget(): l10n.universalImport_divers_targetSkip,
    };
    final counts = [
      l10n.universalImport_divers_diveCount(row.diveCount),
      if (row.certificationCount > 0)
        l10n.universalImport_divers_certificationCount(
          row.certificationCount,
        ),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.isUnowned ? l10n.universalImport_divers_unownedRow : row.name,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              counts,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.universalImport_divers_targetLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DiverTarget>(
                  key: ValueKey('diver_target_${row.key}'),
                  // A choice naming a profile that no longer exists shows as
                  // unset rather than tripping the dropdown's value check.
                  value: options.containsKey(target) ? target : null,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final option in options.entries)
                      DropdownMenuItem(
                        value: option.key,
                        child: Text(
                          option.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (choice) {
                    if (choice != null) onChanged(choice);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/import_wizard/presentation/widgets/diver_mapping_step_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing adapter test**

Create `test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

const _multi = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'd1', SourceDiver.mapKey: _ann},
      {'sourceUuid': 'd2', SourceDiver.mapKey: _bo},
    ],
  },
  sourceDivers: [
    SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
    SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
  ],
);

final _me = Diver(
  id: 'me',
  name: 'Me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith(ImportPayload payload) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allDiversProvider.overrideWith((ref) async => [_me]),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(payload: payload);
    return container;
  }

  group('Divers step providers', () {
    test('a single-diver payload skips the step', () {
      final container = containerWith(const ImportPayload(entities: {}));
      expect(container.read(universalAdapterSingleDiverProvider), isTrue);
      expect(container.read(universalAdapterDiverMappingReadyProvider), isTrue);
    });

    test('a multi-diver payload waits for a mapping', () {
      final container = containerWith(_multi);
      expect(container.read(universalAdapterSingleDiverProvider), isFalse);
      expect(
        container.read(universalAdapterDiverMappingReadyProvider),
        isFalse,
      );
    });

    test('the step is ready once one diver imports somewhere', () {
      final container = containerWith(_multi);
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.setDiverTarget(_ann, const SkipDiverTarget());
      notifier.setDiverTarget(_bo, const SkipDiverTarget());
      expect(
        container.read(universalAdapterDiverMappingReadyProvider),
        isFalse,
      );
      notifier.setDiverTarget(_bo, const NewDiverTarget(_bo));
      expect(container.read(universalAdapterDiverMappingReadyProvider), isTrue);
    });
  });

  group('UniversalAdapter Divers step', () {
    Future<(UniversalAdapter, ProviderContainer)> adapterFor(
      WidgetTester tester,
      ImportPayload payload,
    ) async {
      final container = containerWith(payload);
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                adapter = UniversalAdapter(ref: ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return (adapter, container);
    }

    testWidgets('sits between Map Fields and Photos', (tester) async {
      final (adapter, _) = await adapterFor(tester, _multi);
      expect(adapter.acquisitionSteps.map((s) => s.label), [
        'Select File',
        'Confirm Source',
        'Map Fields',
        'Divers',
        'Photos',
      ]);
    });

    testWidgets('leaving Map Fields seeds the defaults', (tester) async {
      final (adapter, container) = await adapterFor(tester, _multi);
      await tester.runAsync(() => adapter.acquisitionSteps[2].onBeforeAdvance!());
      expect(container.read(universalImportNotifierProvider).diverMapping, {
        _ann: const ExistingDiverTarget('me'),
        _bo: const NewDiverTarget(_bo),
      });
    });

    testWidgets('leaving the Divers step expands the payload', (tester) async {
      final (adapter, container) = await adapterFor(tester, _multi);
      await tester.runAsync(() async {
        await adapter.acquisitionSteps[2].onBeforeAdvance!();
        await adapter.acquisitionSteps[3].onBeforeAdvance!();
      });
      final dives = container
          .read(universalImportNotifierProvider)
          .payload!
          .entitiesOf(ImportEntityType.dives);
      expect(dives.map((d) => d[DiverTarget.itemKey]), [
        'diver:me',
        'new:$_bo',
      ]);
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`
Expected: FAIL to compile: the two providers are not defined.

- [ ] **Step 7: Add providers, the step and the seeding to `UniversalAdapter`**

In `universal_adapter.dart` add imports:

```dart
import 'package:submersion/features/import_wizard/presentation/widgets/diver_mapping_step.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
```

After `universalAdapterPhotosReadyProvider` add:

```dart
/// True when the parsed payload has at most one diver, so the Divers step
/// has nothing to ask and skips itself (issue #1893).
final universalAdapterSingleDiverProvider = Provider<bool>((ref) {
  final parsed = ref.watch(
    universalImportNotifierProvider.select((s) => s.parsedPayload),
  );
  return !(parsed?.needsDiverMapping ?? false);
});

/// True once every row of the Divers step has a choice and at least one of
/// them imports somewhere.
final universalAdapterDiverMappingReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  final parsed = state.parsedPayload;
  if (parsed == null || !parsed.needsDiverMapping) return true;
  final rows = orderedDiverRows(parsed.sourceDivers);
  final mapping = state.diverMapping;
  return rows.every((row) => mapping.containsKey(row.key)) &&
      rows.any((row) => mapping[row.key] is! SkipDiverTarget);
});
```

In `acquisitionSteps`, change the Map Fields step's `onBeforeAdvance` to:

```dart
      onBeforeAdvance: () async {
        final notifier = _ref.read(universalImportNotifierProvider.notifier);
        await notifier.confirmFieldMapping();
        await _seedDiverMapping();
      },
```

and insert between the Map Fields and Photos steps:

```dart
    WizardStepDef(
      label: 'Divers',
      icon: Icons.people_outline,
      builder: (context) => const DiverMappingStep(),
      canAdvance: universalAdapterDiverMappingReadyProvider,
      // Only a logbook with two or more divers has anything to ask.
      canAutoAdvance: universalAdapterSingleDiverProvider,
      autoAdvance: true,
      onBeforeAdvance: () async {
        final activeDiverId = await _ref.read(
          validatedCurrentDiverIdProvider.future,
        );
        if (activeDiverId == null) return;
        _ref
            .read(universalImportNotifierProvider.notifier)
            .applyDiverMapping(activeDiverId: activeDiverId);
      },
    ),
```

Add this method to `UniversalAdapter` (below `acquisitionSteps`):

```dart
  /// Seeds the Divers step's defaults (issue #1893). Runs as Map Fields is
  /// left, which the wizard does even when it auto-skips that step, after
  /// choosing the next page and before rendering it.
  Future<void> _seedDiverMapping() async {
    final parsed = _ref.read(universalImportNotifierProvider).parsedPayload;
    if (parsed == null || !parsed.needsDiverMapping) return;
    final activeDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    if (activeDiverId == null) return;
    final profiles = await _ref.read(allDiversProvider.future);
    _ref
        .read(universalImportNotifierProvider.notifier)
        .initDiverMapping(profiles: profiles, activeDiverId: activeDiverId);
  }
```

- [ ] **Step 8: Update the step-count test**

In `universal_adapter_test.dart`, test `'acquisitionSteps has four steps'`: rename it to `'acquisitionSteps has five steps'` and change `hasLength(4)` to `hasLength(5)`. Keep `expect(adapter.acquisitionSteps.last.label, 'Photos');`.

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`
Expected: PASS (6 tests).
Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: PASS.
Run: `flutter test test/features/import_wizard/presentation/pages/unified_import_wizard_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/widgets/diver_mapping_step.dart lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/presentation/widgets/diver_mapping_step_test.dart test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart test/features/import_wizard/data/adapters/universal_adapter_test.dart
git commit -m "feat(import-wizard): add a Divers step for multi-diver logbooks (#1893)"
```

---

### Task 11b: Hide steps that do not apply from the step indicator (added during execution)

Found while running Task 11: `WizardStepIndicator` is a fixed `Row`, and the eighth label overflowed by 3.8 px at 800 px (`unified_import_wizard_test.dart`, "consumes preloaded state from UniversalAdapter"). The wizard listed every acquisition step, including ones that auto-skip. Decision (user): hide steps that do not apply to the current import.

**Files:**
- Modify: `lib/shared/widgets/wizard/wizard_step_def.dart` (optional `ProviderListenable<bool>? hiddenWhen`)
- Create: `lib/features/import_wizard/presentation/pages/step_indicator_view.dart` (`stepIndicatorView({acquisitionLabels, hidden, trailingLabels, currentPage}) -> ({List<String> labels, int current})`; the current page always shows)
- Modify: `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart` (`_buildStepIndicator` watches each step's `hiddenWhen`)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`hiddenWhen` on Map Fields via new `universalAdapterNoFieldMappingProvider` (payload exists and not CSV), Divers via `universalAdapterSingleDiverProvider`, Photos via `universalAdapterNoPhotosProvider`)
- Test: `test/features/import_wizard/presentation/pages/step_indicator_view_test.dart`, `unified_import_wizard_test.dart` (a hidden fake step never reaches the indicator), `universal_adapter_diver_step_test.dart` (Map Fields provider)

Only the indicator changes; the page list, navigation and auto-advance are untouched. Other adapters set no `hiddenWhen` and render as before. Committed together with Task 11.

---

### Task 12: Review shows each row's profile and numbers dives per profile

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart:96-118,160-168`
- Create: `lib/features/import_wizard/presentation/widgets/import_target_chip.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` (`_NonDuplicateRow` ~645-657, `_EntityDuplicateCard` ~820-830)
- Modify: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` (~232-248)
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart:42-54,81-127`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`buildBundle` return at ~365; `checkDuplicates` return at ~482)
- Test: `test/features/import_wizard/presentation/widgets/review_step_test.dart`, `test/features/import_wizard/presentation/widgets/import_target_chip_test.dart`, `test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`

**Interfaces:**
- Consumes: `DiverTarget` helpers (Task 6), `universalImport_divers_newLabel` (Task 10), `allDiversProvider`, `diveRepositoryProvider.getNextDiveNumber({String? diverId})`.
- Produces:
  - `class ImportTarget { String key; String name; bool isNew; }` in `import_bundle.dart`.
  - `EntityItem.target` (`ImportTarget?`) and `EntityItem.copyWith({ImportTarget? target})`.
  - `ImportBundle.nextDiveNumberByTarget` (`Map<String, int>`, default `const {}`).
  - `ReviewStep.computeProjectedDiveNumbers(...)` (`@visibleForTesting static`, new named parameter `Map<String, int> nextDiveNumberByTarget = const {}`).
  - `ImportTargetChip({required ImportTarget target})`.

- [ ] **Step 1: Write the failing tests**

Append to `review_step_test.dart` inside `main()` (it already has a helper building `EntityItem` with `IncomingDiveData(startTime:, diveNumber:)`; write the items inline here):

```dart
  group('computeProjectedDiveNumbers per profile (#1893)', () {
    EntityItem dive(DateTime start, {ImportTarget? target}) => EntityItem(
      title: '',
      subtitle: '',
      diveData: IncomingDiveData(startTime: start),
      target: target,
    );
    const me = ImportTarget(key: 'diver:me', name: 'Me', isNew: false);
    const bo = ImportTarget(key: 'new:bo', name: 'Bo Ray', isNew: true);

    Map<int, int>? project(ImportBundle bundle, {int? next}) =>
        ReviewStep.computeProjectedDiveNumbers(
          bundle: bundle,
          nextDiveNumber: next,
          retainSource: false,
          selections: {0, 1, 2},
          duplicateActions: const {},
          duplicateIndices: const {},
          nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,
        );

    test('numbers each profile from its own next number', () {
      final bundle = ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'MacDive',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [
              dive(DateTime(2024, 1, 2), target: me),
              dive(DateTime(2024, 1, 1), target: bo),
              dive(DateTime(2024, 1, 1), target: me),
            ],
          ),
        },
        nextDiveNumberByTarget: const {'diver:me': 40, 'new:bo': 1},
      );
      expect(project(bundle, next: 40), {0: 41, 1: 1, 2: 40});
    });

    test('a single target without labels uses its own base', () {
      final bundle = ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'MacDive',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [dive(DateTime(2024, 1, 1))],
          ),
        },
        nextDiveNumberByTarget: const {'new:bo': 1},
      );
      expect(project(bundle, next: 40), {0: 1});
    });
  });
```

Create `test/features/import_wizard/presentation/widgets/import_target_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_target_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('names an existing profile', (tester) async {
    await tester.pumpWidget(
      _host(
        const ImportTargetChip(
          target: ImportTarget(key: 'diver:me', name: 'Me', isNew: false),
        ),
      ),
    );
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('marks a profile the import will create', (tester) async {
    await tester.pumpWidget(
      _host(
        const ImportTargetChip(
          target: ImportTarget(key: 'new:bo', name: 'Bo Ray', isNew: true),
        ),
      ),
    );
    expect(find.text('New: Bo Ray'), findsOneWidget);
  });
}
```

Append to `universal_adapter_diver_step_test.dart` inside `group('UniversalAdapter Divers step', ...)`:

```dart
    testWidgets('buildBundle labels rows only across two profiles', (
      tester,
    ) async {
      final (adapter, _) = await adapterFor(
        tester,
        const ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'sourceUuid': 'd1', DiverTarget.itemKey: 'diver:me'},
              {'sourceUuid': 'd2', DiverTarget.itemKey: 'new:$_bo'},
            ],
          },
          sourceDivers: [
            SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
            SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
          ],
        ),
      );
      final bundle = (await tester.runAsync(adapter.buildBundle))!;
      final items = bundle.groups[wizard.ImportEntityType.dives]!.items;
      expect(items.map((i) => i.target?.name), ['Me', 'Bo Ray']);
      expect(items.map((i) => i.target?.isNew), [false, true]);
      expect(bundle.nextDiveNumberByTarget['new:$_bo'], 1);
      expect(bundle.nextDiveNumberByTarget.containsKey('diver:me'), isTrue);
    });
```

For that test, add to the file's imports `import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart' as wizard show ImportEntityType;` and add to `containerWith`'s overrides a dive repository stub, since `buildBundle` now asks it for the next dive number:

```dart
        diveRepositoryProvider.overrideWithValue(_FakeDiveNumbers()),
```

with, at the bottom of the file:

```dart
class _FakeDiveNumbers extends Fake implements DiveRepository {
  @override
  Future<int> getNextDiveNumber({String? diverId}) async => 7;
}
```

plus imports `package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart` and `package:submersion/features/dive_log/presentation/providers/dive_providers.dart` (`Fake` comes from `flutter_test`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_target_chip_test.dart`
Expected: FAIL to compile: `ImportTarget`, `import_target_chip.dart` missing.

- [ ] **Step 3: Extend the bundle model**

In `import_bundle.dart`, add above `class EntityItem`:

```dart
/// The diver profile an item will be imported into (issue #1893). Shown on
/// review rows when one import writes to more than one profile.
class ImportTarget {
  /// The item's `_targetKey` (`diver:<id>` or `new:<source key>`).
  final String key;

  /// The profile's name, or the source diver's name for a new profile.
  final String name;

  /// Whether the import will create this profile.
  final bool isNew;

  const ImportTarget({
    required this.key,
    required this.name,
    required this.isNew,
  });
}
```

In `EntityItem`, add the field and constructor parameter, and a `copyWith`:

```dart
  /// The profile this item goes to, when the import writes to several.
  final ImportTarget? target;

  const EntityItem({
    required this.title,
    required this.subtitle,
    this.icon,
    this.diveData,
    this.target,
  });

  EntityItem copyWith({ImportTarget? target}) => EntityItem(
    title: title,
    subtitle: subtitle,
    icon: icon,
    diveData: diveData,
    target: target ?? this.target,
  );
```

In `ImportBundle`, add:

```dart
  /// The next dive number of each target profile, keyed by target key
  /// (issue #1893). Empty for an import into the active profile alone.
  final Map<String, int> nextDiveNumberByTarget;

  const ImportBundle({
    required this.source,
    required this.groups,
    this.nextDiveNumberByTarget = const {},
  });
```

- [ ] **Step 4: Create the chip and render it**

Create `lib/features/import_wizard/presentation/widgets/import_target_chip.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The profile a review row goes to (issue #1893), shown under the row's
/// subtitle when one import writes to several profiles.
class ImportTargetChip extends StatelessWidget {
  const ImportTargetChip({super.key, required this.target});

  final ImportTarget target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            target.isNew ? Icons.person_add_alt : Icons.person_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              target.isNew
                  ? context.l10n.universalImport_divers_newLabel(target.name)
                  : target.name,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
```

Render it in the three title/subtitle columns, directly after the subtitle `Text` (import `import_target_chip.dart` in both files):
- `entity_review_list.dart`, `_NonDuplicateRow`: after the `if (item.subtitle.isNotEmpty) Text(...)` element add `if (item.target case final target?) ImportTargetChip(target: target),`.
- `entity_review_list.dart`, `_EntityDuplicateCard`: after its `if (widget.item.subtitle.isNotEmpty) Text(...)` add `if (widget.item.target case final target?) ImportTargetChip(target: target),`.
- `duplicate_action_card.dart`: after `if (effectiveSubtitle.isNotEmpty) Text(...)` add `if (item.target case final target?) ImportTargetChip(target: target),`.

- [ ] **Step 5: Number dives per profile in Review**

In `review_step.dart`, rename `_computeProjectedDiveNumbers` to `computeProjectedDiveNumbers`, annotate it `@visibleForTesting` (import `package:flutter/foundation.dart` if `visibleForTesting` is not already available through `material.dart`; it is), add the parameter `Map<String, int> nextDiveNumberByTarget = const {},`, and replace everything from `if (nextDiveNumber == null) return null;` to the end of the method with:

```dart
    if (nextDiveNumber == null && nextDiveNumberByTarget.isEmpty) return null;

    // Each profile numbers its own dives (issue #1893). A dive without a
    // target label belongs to the import's only profile when there is one,
    // otherwise to the active profile.
    int? baseFor(String? targetKey) {
      if (targetKey != null) {
        return nextDiveNumberByTarget[targetKey] ?? nextDiveNumber;
      }
      return nextDiveNumberByTarget.length == 1
          ? nextDiveNumberByTarget.values.single
          : nextDiveNumber;
    }

    final byTarget = <String?, List<(int, DateTime)>>{};
    for (final i in importIndices) {
      (byTarget[items[i].target?.key] ??= []).add((
        i,
        items[i].diveData?.startTime ?? DateTime(0),
      ));
    }

    // Assign numbers oldest-first within each profile.
    final result = <int, int>{};
    for (final MapEntry(key: target, value: indexed) in byTarget.entries) {
      final base = baseFor(target);
      if (base == null) continue;
      indexed.sort((a, b) => a.$2.compareTo(b.$2));
      for (var n = 0; n < indexed.length; n++) {
        result[indexed[n].$1] = base + n;
      }
    }
    return result;
```

Update the call in `build` to `computeProjectedDiveNumbers(...)` and pass `nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,`.

- [ ] **Step 6: Label rows and fetch per-profile numbers in `buildBundle`**

In `universal_adapter.dart`, replace the final `return ImportBundle(source: ..., groups: groups);` of `buildBundle` with:

```dart
    final targets = await _importTargets(payload);
    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.universal,
        displayName: _displayName,
      ),
      // One profile needs no labels; the counts already say where it goes.
      groups: targets.length > 1
          ? _labelTargets(groups, payload, targets)
          : groups,
      nextDiveNumberByTarget: await _nextDiveNumbers(targets.keys),
    );
```

Change the last line of `checkDuplicates` to:

```dart
    return ImportBundle(
      source: bundle.source,
      groups: updatedGroups,
      nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,
    );
```

`_applyDuplicateIndices` rebuilds `EntityGroup`s from `group.items`, so labels survive it. Add these helpers to `UniversalAdapter`:

```dart
  /// The profile behind each target key of an expanded payload (#1893).
  /// Empty for a payload that was never split across profiles.
  Future<Map<String, ImportTarget>> _importTargets(ImportPayload payload) async {
    final keys = <String>{
      for (final items in payload.entities.values)
        for (final item in items)
          if (item[DiverTarget.itemKey] case final String key) key,
    };
    if (keys.isEmpty) return const {};
    final profiles = await _ref.read(allDiversProvider.future);
    final nameById = {for (final p in profiles) p.id: p.name};
    final nameBySource = {for (final d in payload.sourceDivers) d.key: d.name};
    return {
      for (final key in keys)
        key: switch (DiverTarget.diverIdOf(key)) {
          final String id => ImportTarget(
            key: key,
            name: nameById[id] ?? id,
            isNew: false,
          ),
          null => ImportTarget(
            key: key,
            name: nameBySource[DiverTarget.newSourceKeyOf(key)] ?? '',
            isNew: true,
          ),
        },
    };
  }

  /// [groups] with each item labelled with its target. Groups are built one
  /// to one from the payload's lists, so index i is payload item i.
  Map<wizard.ImportEntityType, EntityGroup> _labelTargets(
    Map<wizard.ImportEntityType, EntityGroup> groups,
    ImportPayload payload,
    Map<String, ImportTarget> targets,
  ) {
    return {
      for (final MapEntry(key: type, value: group) in groups.entries)
        type: EntityGroup(
          items: [
            for (final (i, item) in group.items.indexed)
              switch (payload
                  .entitiesOf(ui.ImportEntityType.values.byName(type.name))[i][
                    DiverTarget.itemKey
                  ]) {
                final String key when targets.containsKey(key) =>
                  item.copyWith(target: targets[key]),
                _ => item,
              },
          ],
          duplicateIndices: group.duplicateIndices,
          matchResults: group.matchResults,
          entityMatches: group.entityMatches,
          autoSkipIndices: group.autoSkipIndices,
        ),
    };
  }

  /// Each target's next dive number: a new profile starts at 1.
  Future<Map<String, int>> _nextDiveNumbers(Iterable<String> targetKeys) async {
    final dives = _ref.read(diveRepositoryProvider);
    return {
      for (final key in targetKeys)
        key: switch (DiverTarget.diverIdOf(key)) {
          final String id => await dives.getNextDiveNumber(diverId: id),
          null => 1,
        },
    };
  }
```

(`ImportTarget` comes from `import_bundle.dart`, already imported with `hide ImportEntityType`.)

- [ ] **Step 7: Run tests to verify they pass**

Run each:
`flutter test test/features/import_wizard/presentation/widgets/import_target_chip_test.dart`
`flutter test test/features/import_wizard/presentation/widgets/review_step_test.dart`
`flutter test test/features/import_wizard/presentation/widgets/review_step_pending_test.dart`
`flutter test test/features/import_wizard/presentation/widgets/entity_review_list_test.dart`
`flutter test test/features/import_wizard/presentation/widgets/duplicate_action_card_test.dart`
`flutter test test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart`
`flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/import_wizard/domain/models/import_bundle.dart lib/features/import_wizard/presentation/widgets/import_target_chip.dart lib/features/import_wizard/presentation/widgets/entity_review_list.dart lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart lib/features/import_wizard/presentation/widgets/review_step.dart lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/presentation/widgets/review_step_test.dart test/features/import_wizard/presentation/widgets/import_target_chip_test.dart test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart
git commit -m "feat(import-wizard): label review rows with their profile (#1893)"
```

---

### Task 13: Duplicate check per profile

**Files:**
- Create: `lib/features/import_wizard/data/adapters/existing_import_records.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart:374-419` (`checkDuplicates` up to the first `_applyDuplicateIndices` call)
- Test: `test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`

**Interfaces:**
- Consumes: `PayloadSlicer`, `duplicatesToGlobal`, `mergeDuplicateResults` (Task 8); `DiverTarget` (Task 6).
- Produces: `class ExistingImportRecords` with `check(ImportPayload, {required bool checkIntraBatch, required UnitFormatter units}) -> ImportDuplicateResult`; loaders `loadActiveDiverRecords(WidgetRef, String?)`, `loadProfileRecords(WidgetRef, String)`, `loadNewProfileRecords(WidgetRef)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`. It reuses the generated mocks of `universal_adapter_test.dart` (regenerated by `scripts/setup.sh`; no new `@GenerateNiceMocks` needed):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import 'universal_adapter_test.mocks.dart';

final _now = DateTime(2026);

Diver _diver(String id, String name) =>
    Diver(id: id, name: name, createdAt: _now, updatedAt: _now);

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Blue Hole goes to the active profile (diver-1) and to diver-2.
const _twoProfiles = ImportPayload(
  entities: {
    ui.ImportEntityType.sites: [
      {'name': 'Blue Hole', 'uddfId': 'Blue Hole', DiverTarget.itemKey: 'diver:diver-1'},
      {'name': 'Blue Hole', 'uddfId': 'Blue Hole', DiverTarget.itemKey: 'diver:diver-2'},
    ],
  },
);

Future<UniversalAdapter> _adapter(
  WidgetTester tester, {
  required ImportPayload payload,
  List<DiveSite> activeSites = const [],
  required MockSiteRepository siteRepo,
}) async {
  final diveRepo = MockDiveRepository();
  when(
    diveRepo.getAllDives(diverId: anyNamed('diverId')),
  ).thenAnswer((_) async => []);
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universalImportNotifierProvider.overrideWith((ref) {
          final notifier = UniversalImportNotifier(ref);
          notifier.state = notifier.state.copyWith(payload: payload);
          return notifier;
        }),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        currentDiverProvider.overrideWith(
          (ref) async => _diver('diver-1', 'Test Diver'),
        ),
        allDiversProvider.overrideWith(
          (ref) async => [
            _diver('diver-1', 'Test Diver'),
            _diver('diver-2', 'Other'),
          ],
        ),
        diveRepositoryProvider.overrideWithValue(diveRepo),
        siteRepositoryProvider.overrideWithValue(siteRepo),
        tripRepositoryProvider.overrideWithValue(MockTripRepository()),
        equipmentRepositoryProvider.overrideWithValue(
          MockEquipmentRepository(),
        ),
        buddyRepositoryProvider.overrideWithValue(MockBuddyRepository()),
        diveCenterRepositoryProvider.overrideWithValue(
          MockDiveCenterRepository(),
        ),
        certificationRepositoryProvider.overrideWithValue(
          MockCertificationRepository(),
        ),
        tagRepositoryProvider.overrideWithValue(MockTagRepository()),
        diveTypeRepositoryProvider.overrideWithValue(MockDiveTypeRepository()),
        // The active profile still reads through these providers.
        allTripsProvider.overrideWith((ref) async => []),
        sitesProvider.overrideWith((ref) async => activeSites),
        allEquipmentProvider.overrideWith((ref) async => []),
        allBuddiesProvider.overrideWith((ref) async => []),
        allDiveCentersProvider.overrideWith((ref) async => []),
        allCertificationsProvider.overrideWith((ref) async => []),
        tagsProvider.overrideWith((ref) async => []),
        diveTypesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  group('checkDuplicates per profile (#1893)', () {
    testWidgets('a site the active profile has is a duplicate only there', (
      tester,
    ) async {
      final siteRepo = MockSiteRepository();
      when(
        siteRepo.getAllSites(diverId: 'diver-2'),
      ).thenAnswer((_) async => []);
      final adapter = await _adapter(
        tester,
        payload: _twoProfiles,
        siteRepo: siteRepo,
        activeSites: const [DiveSite(id: 's1', name: 'Blue Hole')],
      );

      final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
      expect(bundle.groups[ImportEntityType.sites]!.duplicateIndices, {0});
    });

    testWidgets('another profile is checked against its own records', (
      tester,
    ) async {
      final siteRepo = MockSiteRepository();
      when(siteRepo.getAllSites(diverId: 'diver-2')).thenAnswer(
        (_) async => const [DiveSite(id: 's2', name: 'Blue Hole')],
      );
      final adapter = await _adapter(
        tester,
        payload: _twoProfiles,
        siteRepo: siteRepo,
      );

      final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
      expect(bundle.groups[ImportEntityType.sites]!.duplicateIndices, {1});
      verify(siteRepo.getAllSites(diverId: 'diver-2')).called(1);
      verifyNever(siteRepo.getAllSites(diverId: null));
    });
  });
}
```

If `universal_adapter_test.mocks.dart` does not export one of the mocks named above, check its `@GenerateNiceMocks` list at the top of `universal_adapter_test.dart` and use the mock it does generate.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`
Expected: FAIL: the second test finds `{}` (today every item is checked against the active profile only).

- [ ] **Step 3: Create `existing_import_records.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

/// The records one import target's items are checked against for
/// duplicates (issue #1893).
class ExistingImportRecords {
  const ExistingImportRecords({
    this.dives = const [],
    this.sites = const [],
    this.trips = const [],
    this.equipment = const [],
    this.buddies = const [],
    this.diveCenters = const [],
    this.certifications = const [],
    this.tags = const [],
    this.diveTypes = const [],
    this.sourceUuidByDiveId = const {},
  });

  final List<Dive> dives;
  final List<DiveSite> sites;
  final List<Trip> trips;
  final List<EquipmentItem> equipment;
  final List<Buddy> buddies;
  final List<DiveCenter> diveCenters;
  final List<Certification> certifications;
  final List<Tag> tags;
  final List<DiveTypeEntity> diveTypes;
  final Map<String, String> sourceUuidByDiveId;

  ImportDuplicateResult check(
    ImportPayload payload, {
    required bool checkIntraBatch,
    required UnitFormatter units,
  }) {
    return const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: dives,
      existingSites: sites,
      existingTrips: trips,
      existingEquipment: equipment,
      existingBuddies: buddies,
      existingDiveCenters: diveCenters,
      existingCertifications: certifications,
      existingTags: tags,
      existingDiveTypes: diveTypes,
      existingSourceUuidByDiveId: sourceUuidByDiveId,
      checkIntraBatch: checkIntraBatch,
      units: units,
    );
  }
}

/// The active profile's records, read the way the review always has:
/// through the diver-scoped list providers, refreshed. `refresh()` rather
/// than `read()`, which may return a value invalidated but not re-fetched.
Future<ExistingImportRecords> loadActiveDiverRecords(
  WidgetRef ref,
  String? diverId,
) async {
  final trips = await ref.refresh(allTripsProvider.future);
  final sites = await ref.refresh(sitesProvider.future);
  final equipment = await ref.refresh(allEquipmentProvider.future);
  final buddies = await ref.refresh(allBuddiesProvider.future);
  final diveCenters = await ref.refresh(allDiveCentersProvider.future);
  final certifications = await ref.refresh(allCertificationsProvider.future);
  final tags = await ref.refresh(tagsProvider.future);
  final diveTypes = await ref.refresh(diveTypesProvider.future);
  final diveRepo = ref.read(diveRepositoryProvider);
  return ExistingImportRecords(
    trips: trips,
    sites: sites,
    equipment: equipment,
    buddies: buddies,
    diveCenters: diveCenters,
    certifications: certifications,
    tags: tags,
    diveTypes: diveTypes,
    dives: await diveRepo.getAllDives(diverId: diverId),
    sourceUuidByDiveId: await diveRepo.getSourceUuidByDiveId(diverId: diverId),
  );
}

/// Another existing profile's records, straight from the repositories,
/// which take the diver id as an argument. [diverId] is never null here: a
/// null id would make every filter return all divers' rows.
Future<ExistingImportRecords> loadProfileRecords(
  WidgetRef ref,
  String diverId,
) async {
  final diveRepo = ref.read(diveRepositoryProvider);
  return ExistingImportRecords(
    trips: await ref.read(tripRepositoryProvider).getAllTrips(diverId: diverId),
    sites: await ref.read(siteRepositoryProvider).getAllSites(diverId: diverId),
    equipment: await ref
        .read(equipmentRepositoryProvider)
        .getAllEquipment(diverId: diverId),
    buddies: await ref
        .read(buddyRepositoryProvider)
        .getAllBuddies(diverId: diverId),
    diveCenters: await ref
        .read(diveCenterRepositoryProvider)
        .getAllDiveCenters(diverId: diverId),
    certifications: await ref
        .read(certificationRepositoryProvider)
        .getAllCertifications(diverId: diverId),
    tags: await ref.read(tagRepositoryProvider).getAllTags(diverId: diverId),
    diveTypes: await ref
        .read(diveTypeRepositoryProvider)
        .getAllDiveTypes(diverId: diverId),
    dives: await diveRepo.getAllDives(diverId: diverId),
    sourceUuidByDiveId: await diveRepo.getSourceUuidByDiveId(diverId: diverId),
  );
}

/// A profile the import will create has no records yet. Built-in dive types
/// exist for every diver, so they still count (a null id asks for those
/// alone).
Future<ExistingImportRecords> loadNewProfileRecords(WidgetRef ref) async {
  return ExistingImportRecords(
    diveTypes: await ref.read(diveTypeRepositoryProvider).getAllDiveTypes(),
  );
}
```

Confirm `getAllDiveTypes()` with no id returns built-ins only by reading `lib/features/dive_types/data/repositories/dive_type_repository.dart:31`; if it returns every diver's custom types, pass an empty list instead.

- [ ] **Step 4: Check each slice against its own profile**

In `universal_adapter.dart`, add imports for `existing_import_records.dart`, `payload_slicer.dart` and `diver_slice_duplicates.dart`. In `checkDuplicates`, replace everything from `const checker = ImportDuplicateChecker();` down to the end of the `final dupResult = checker.check(...);` statement with:

```dart
    // Scope duplicate detection to each target profile's own data (#1893).
    // An unexpanded payload is one slice checked against the active diver,
    // exactly as before.
    final currentDiver = await _ref.read(currentDiverProvider.future);
    final activeDiverId = currentDiver?.id;
    final checkIntraBatch =
        (payload.metadata['batchFileCount'] as int? ?? 1) > 1;
    final units = UnitFormatter(_ref.read(settingsProvider));
    final slices = PayloadSlicer.slice(
      payload,
      firstTargetKey: activeDiverId == null
          ? null
          : ExistingDiverTarget(activeDiverId).targetKey,
    );
    final dupResult = mergeDuplicateResults([
      for (final slice in slices)
        duplicatesToGlobal(
          slice,
          (await _existingRecordsFor(slice.targetKey, activeDiverId)).check(
            slice.payload,
            checkIntraBatch: checkIntraBatch,
            units: units,
          ),
        ),
    ]);
```

Leave everything after it (the `updatedGroups` and `_applyDuplicateIndices` calls) unchanged. Add the helper:

```dart
  Future<ExistingImportRecords> _existingRecordsFor(
    String? targetKey,
    String? activeDiverId,
  ) {
    if (targetKey == null) return loadActiveDiverRecords(_ref, activeDiverId);
    final diverId = DiverTarget.diverIdOf(targetKey);
    if (diverId == null) return loadNewProfileRecords(_ref);
    if (diverId == activeDiverId) {
      return loadActiveDiverRecords(_ref, activeDiverId);
    }
    return loadProfileRecords(_ref, diverId);
  }
```

Remove imports that are now unused in `universal_adapter.dart` (for example `import_duplicate_checker.dart` if nothing else uses `ImportDuplicateChecker`; it is still needed for `ImportDuplicateResult` in `performImport`). Let `flutter analyze` decide.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`
Expected: PASS (2 tests).
Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: PASS: every existing `checkDuplicates()` test still overrides the same providers, and the untargeted path reads them in the same order.
Run: `flutter analyze lib/features/import_wizard`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/import_wizard/data/adapters/existing_import_records.dart lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart
git commit -m "feat(import-wizard): check each profile's items against its own records (#1893)"
```

---

### Task 14: Import each profile's slice

**Files:**
- Create: `lib/features/import_wizard/domain/models/diver_import_outcome.dart`
- Create: `lib/features/import_wizard/data/adapters/diver_slice_review.dart`
- Modify: `lib/features/import_wizard/domain/models/unified_import_result.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`performImport` ~486-827)
- Test: `test/features/import_wizard/data/adapters/diver_slice_review_test.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`

**Interfaces:**
- Consumes: `DiverSlice`, `PayloadSlicer`, `withInBatchIndex` (Task 8); `ImportTarget`, `ImportBundle.nextDiveNumberByTarget` (Task 12); `SourceDiver` (Task 1); `DiverRepository.createDiver(Diver)` via `diverRepositoryProvider`.
- Produces:
  - `class DiverImportOutcome { String diverId; String name; bool isNew; bool isActive; List<String> diveIds; DiverImportOutcome withoutDives(Set<String> removed); }`.
  - `UnifiedImportResult.diverOutcomes` (`List<DiverImportOutcome>`, default `const []`). In a multi-profile import `importedDiveIds` holds only the active profile's dives; `errorMessage` is set together with non-empty `diverOutcomes` when a later slice failed.
  - `class DiverSliceReview { ImportBundle bundle; Map<ImportEntityType, Set<int>> selections; Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions; factory DiverSliceReview.of(DiverSlice, ImportBundle, selections, duplicateActions); }` and `UddfEntityImportResult addSliceResult(UddfEntityImportResult total, DiverSlice slice, UddfEntityImportResult result)`.

- [ ] **Step 1: Write the failing pure tests**

Create `test/features/import_wizard/data/adapters/diver_slice_review_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/data/adapters/diver_slice_review.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

const _key = DiverTarget.itemKey;

void main() {
  const payload = ImportPayload(
    entities: {
      ui.ImportEntityType.dives: [
        {'n': 0, _key: 'diver:a'},
        {'n': 1, _key: 'new:b'},
        {'n': 2, _key: 'new:b'},
      ],
    },
  );
  final b = PayloadSlicer.slice(payload, firstTargetKey: 'diver:a')[1];

  EntityItem item(String title) => EntityItem(title: title, subtitle: '');

  test('moves the bundle, selections and actions onto slice indices', () {
    final review = DiverSliceReview.of(
      b,
      ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'x',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [item('a0'), item('b1'), item('b2')],
            duplicateIndices: const {2},
            matchResults: const {
              2: DiveMatchResult(
                diveId: '',
                score: 1,
                timeDifferenceMs: 0,
                inBatchIndex: 1,
              ),
            },
          ),
        },
      ),
      const {
        ImportEntityType.dives: {0, 1, 2},
      },
      const {
        ImportEntityType.dives: {2: DuplicateAction.skip},
      },
    );

    final group = review.bundle.groups[ImportEntityType.dives]!;
    expect(group.items.map((i) => i.title), ['b1', 'b2']);
    expect(group.duplicateIndices, {1});
    expect(group.matchResults![1]!.inBatchIndex, 0);
    expect(review.selections[ImportEntityType.dives], {0, 1});
    expect(review.duplicateActions[ImportEntityType.dives], {
      1: DuplicateAction.skip,
    });
  });

  test('addSliceResult sums counts and maps dive indices back', () {
    final total = addSliceResult(
      const UddfEntityImportResult(
        dives: 1,
        sites: 1,
        diveIds: ['x'],
        diveIdByIndex: {0: 'x'},
      ),
      b,
      const UddfEntityImportResult(
        dives: 2,
        sites: 1,
        diveIds: ['y', 'z'],
        diveIdByIndex: {0: 'y', 1: 'z'},
      ),
    );
    expect(total.dives, 3);
    expect(total.sites, 2);
    expect(total.diveIds, ['x', 'y', 'z']);
    expect(total.diveIdByIndex, {0: 'x', 1: 'y', 2: 'z'});
  });

  test('withoutDives drops consolidated dives', () {
    const outcome = DiverImportOutcome(
      diverId: 'd',
      name: 'Me',
      isNew: false,
      isActive: true,
      diveIds: ['x', 'y'],
    );
    expect(outcome.withoutDives({'x'}).diveIds, ['y']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/diver_slice_review_test.dart`
Expected: FAIL to compile: missing files.

- [ ] **Step 3: Create the outcome model and the result field**

`lib/features/import_wizard/domain/models/diver_import_outcome.dart`:

```dart
/// What one import wrote to one diver profile (issue #1893).
class DiverImportOutcome {
  const DiverImportOutcome({
    required this.diverId,
    required this.name,
    required this.isNew,
    required this.isActive,
    this.diveIds = const [],
  });

  final String diverId;
  final String name;

  /// Whether the import created this profile.
  final bool isNew;

  /// Whether this is the profile the app is showing, the only one whose
  /// dives "View Dives" can open.
  final bool isActive;

  /// Dives the import created in this profile.
  final List<String> diveIds;

  /// This outcome without the dives consolidation folded into others.
  DiverImportOutcome withoutDives(Set<String> removed) => DiverImportOutcome(
    diverId: diverId,
    name: name,
    isNew: isNew,
    isActive: isActive,
    diveIds: [
      for (final id in diveIds)
        if (!removed.contains(id)) id,
    ],
  );
}
```

In `unified_import_result.dart`, import it and add after `notices`:

```dart
  /// What each profile received when one import wrote to several
  /// (issue #1893). Empty for an import into the active profile alone.
  final List<DiverImportOutcome> diverOutcomes;
```

with `this.diverOutcomes = const [],` at the end of the constructor.

- [ ] **Step 4: Create `diver_slice_review.dart`**

```dart
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/services/diver_slice_duplicates.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

/// One [DiverSlice]'s share of the review, in the slice's own indices
/// (issue #1893): what the importer needs to run the slice as if it were a
/// whole import.
class DiverSliceReview {
  const DiverSliceReview({
    required this.bundle,
    required this.selections,
    required this.duplicateActions,
  });

  final ImportBundle bundle;
  final Map<ImportEntityType, Set<int>> selections;
  final Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions;

  factory DiverSliceReview.of(
    DiverSlice slice,
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    return DiverSliceReview(
      bundle: ImportBundle(
        source: bundle.source,
        groups: {
          for (final MapEntry(key: type, value: group) in bundle.groups.entries)
            type: _sliceGroup(slice, _uiType(type), group),
        },
        nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,
      ),
      selections: {
        for (final MapEntry(key: type, value: indices) in selections.entries)
          type: slice.toLocalSet(_uiType(type), indices),
      },
      duplicateActions: {
        for (final MapEntry(key: type, value: actions)
            in duplicateActions.entries)
          type: slice.toLocalMap(_uiType(type), actions),
      },
    );
  }

  /// The payload's type of the same name; the wizard's enum is a subset.
  static ui.ImportEntityType _uiType(ImportEntityType type) =>
      ui.ImportEntityType.values.byName(type.name);

  static EntityGroup _sliceGroup(
    DiverSlice slice,
    ui.ImportEntityType type,
    EntityGroup group,
  ) {
    final globals = slice.globalIndices[type] ?? const <int>[];
    final matches = group.matchResults;
    final entityMatches = group.entityMatches;
    final autoSkip = group.autoSkipIndices;
    return EntityGroup(
      items: [for (final g in globals) group.items[g]],
      duplicateIndices: slice.toLocalSet(type, group.duplicateIndices),
      matchResults: matches == null
          ? null
          : {
              for (final entry in slice.toLocalMap(type, matches).entries)
                entry.key: withInBatchIndex(
                  entry.value,
                  switch (entry.value.inBatchIndex) {
                    final int i => slice.localIndexOf(type, i),
                    null => null,
                  },
                ),
            },
      entityMatches: entityMatches == null
          ? null
          : slice.toLocalMap(type, entityMatches),
      autoSkipIndices: autoSkip == null
          ? null
          : slice.toLocalSet(type, autoSkip),
    );
  }
}

/// [total] plus one slice's [result], with the slice's dive indices moved
/// back onto the full payload so the steps after the import (consolidation,
/// photos, per-file outcomes) run unchanged.
UddfEntityImportResult addSliceResult(
  UddfEntityImportResult total,
  DiverSlice slice,
  UddfEntityImportResult result,
) {
  return UddfEntityImportResult(
    trips: total.trips + result.trips,
    equipment: total.equipment + result.equipment,
    equipmentSets: total.equipmentSets + result.equipmentSets,
    buddies: total.buddies + result.buddies,
    diveCenters: total.diveCenters + result.diveCenters,
    certifications: total.certifications + result.certifications,
    tags: total.tags + result.tags,
    diveTypes: total.diveTypes + result.diveTypes,
    sites: total.sites + result.sites,
    dives: total.dives + result.dives,
    courses: total.courses + result.courses,
    diveIds: [...total.diveIds, ...result.diveIds],
    diveIdByIndex: {
      ...total.diveIdByIndex,
      ...slice.toGlobalMap(ui.ImportEntityType.dives, result.diveIdByIndex),
    },
    restoredDataSources: total.restoredDataSources + result.restoredDataSources,
  );
}
```

Before writing `addSliceResult`, reopen `uddf_entity_importer.dart:184-225` and confirm `UddfEntityImportResult`'s fields are exactly these fourteen; sum any new count field too.

- [ ] **Step 5: Run the pure tests**

Run: `flutter test test/features/import_wizard/data/adapters/diver_slice_review_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Write the failing integration tests**

Append to `universal_adapter_multi_diver_test.dart` (add imports: `package:submersion/core/constants/enums.dart` if needed, `package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart`, `package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart`, `package:submersion/features/divers/data/repositories/diver_repository.dart`, `package:submersion/features/universal_import/data/models/source_diver.dart`, `package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart`, and `'../../../../helpers/test_database.dart'`):

```dart
  group('performImport per profile (#1893)', () {
    /// One dive and one Blue Hole for the active profile (diver-1), the same
    /// for a profile the import creates for Bo, plus optional extra targets.
    ImportPayload payload({List<Map<String, dynamic>> extraDives = const []}) =>
        ImportPayload(
          entities: {
            ui.ImportEntityType.dives: [
              {
                'dateTime': DateTime(2026, 3, 15, 10),
                'maxDepth': 20.0,
                'runtime': const Duration(minutes: 30),
                'site': {'uddfId': 'Blue Hole'},
                DiverTarget.itemKey: 'diver:diver-1',
              },
              {
                'dateTime': DateTime(2026, 3, 16, 10),
                'maxDepth': 18.0,
                'runtime': const Duration(minutes: 40),
                'site': {'uddfId': 'Blue Hole'},
                DiverTarget.itemKey: 'new:macdive:bo',
              },
              ...extraDives,
            ],
            ui.ImportEntityType.sites: [
              {
                'name': 'Blue Hole',
                'uddfId': 'Blue Hole',
                DiverTarget.itemKey: 'diver:diver-1',
              },
              {
                'name': 'Blue Hole',
                'uddfId': 'Blue Hole',
                DiverTarget.itemKey: 'new:macdive:bo',
              },
            ],
          },
          sourceDivers: const [
            SourceDiver(
              key: 'macdive:bo',
              name: 'Bo Ray',
              diveCount: 1,
              email: 'bo@example.com',
              danNumber: 'DAN-9',
            ),
          ],
        );

    Future<UniversalAdapter> realAdapter(
      WidgetTester tester,
      ImportPayload payload,
    ) async {
      final tankPresets = MockTankPresetRepository();
      when(tankPresets.getPresetById(any)).thenAnswer((_) async => null);
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final notifier = UniversalImportNotifier(ref);
              notifier.state = notifier.state.copyWith(payload: payload);
              return notifier;
            }),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            currentDiverProvider.overrideWith(
              (ref) async => _diver('diver-1', 'Test Diver'),
            ),
            tankPresetRepositoryProvider.overrideWithValue(tankPresets),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                adapter = UniversalAdapter(ref: ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return adapter;
    }

    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(tearDownTestDatabase);

    testWidgets('writes each slice to its own profile, creating Bo', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      final adapter = await realAdapter(tester, payload());

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0, 1},
          ImportEntityType.sites: {0, 1},
        }, {});
      }))!;

      expect(result.errorMessage, isNull);
      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver', 'Bo Ray']);
      expect(result.diverOutcomes.map((o) => o.isNew), [false, true]);

      final check = (await tester.runAsync(() async {
        final divers = await DiverRepository().getAllDivers();
        final bo = divers.singleWhere((d) => d.name == 'Bo Ray');
        return (
          bo: bo,
          mine: await DiveRepository().getAllDives(diverId: 'diver-1'),
          bos: await DiveRepository().getAllDives(diverId: bo.id),
          mySites: await SiteRepository().getAllSites(diverId: 'diver-1'),
          boSites: await SiteRepository().getAllSites(diverId: bo.id),
        );
      }))!;
      expect(check.bo.email, 'bo@example.com');
      expect(check.bo.insurance.provider, 'DAN');
      expect(check.bo.insurance.policyNumber, 'DAN-9');
      expect(check.mine, hasLength(1));
      expect(check.bos, hasLength(1));
      expect(check.mySites.map((s) => s.name), contains('Blue Hole'));
      expect(check.boSites.map((s) => s.name), ['Blue Hole']);
      // Only the active profile's dives, which "View Dives" can open.
      expect(result.importedDiveIds, [check.mine.single.id]);
    });

    testWidgets('a profile whose items are all deselected is not created', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      final adapter = await realAdapter(tester, payload());

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0},
          ImportEntityType.sites: {0},
        }, {});
      }))!;

      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver']);
      final divers = (await tester.runAsync(DiverRepository().getAllDivers))!;
      expect(divers.map((d) => d.name), isNot(contains('Bo Ray')));
    });

    testWidgets('a failing later slice keeps what the earlier one imported', (
      tester,
    ) async {
      await tester.runAsync(
        () => DiverRepository().createDiver(_diver('diver-1', 'Test Diver')),
      );
      // A new-profile target with no source diver behind it cannot be created.
      final adapter = await realAdapter(
        tester,
        payload(
          extraDives: [
            {
              'dateTime': DateTime(2026, 3, 17, 10),
              'maxDepth': 10.0,
              'runtime': const Duration(minutes: 20),
              DiverTarget.itemKey: 'new:macdive:ghost',
            },
          ],
        ),
      );

      final result = (await tester.runAsync(() async {
        final bundle = await adapter.buildBundle();
        return adapter.performImport(bundle, {
          ImportEntityType.dives: {0, 2},
          ImportEntityType.sites: {0},
        }, {});
      }))!;

      expect(result.errorMessage, contains('macdive:ghost'));
      expect(result.diverOutcomes.map((o) => o.name), ['Test Diver']);
      final mine = (await tester.runAsync(
        () => DiveRepository().getAllDives(diverId: 'diver-1'),
      ))!;
      expect(mine, hasLength(1));
    });
  });
```

Here `ImportEntityType` is the wizard enum from `import_bundle.dart` (already imported unaliased in this file) and `ui.ImportEntityType` the payload enum. If `SiteRepository` or `DiveRepository` are exported under different class names, use the names `universal_adapter_test.dart` mocks (`MockSiteRepository` mocks `SiteRepository`, `MockDiveRepository` mocks `DiveRepository`).

- [ ] **Step 7: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`
Expected: FAIL: every dive lands in diver-1 and `diverOutcomes` is empty.

- [ ] **Step 8: Split `performImport` into per-slice runs**

In `universal_adapter.dart`, add imports for `diver_slice_review.dart`, `diver_import_outcome.dart` and `package:submersion/features/divers/domain/entities/diver.dart`.

1. Extract the importer construction (the `settings`, `resolver`, `defaultTankPreset` and `UddfEntityImporter(...)` statements) into:

```dart
  Future<UddfEntityImporter> _buildImporter() async {
    final settings = _ref.read(settingsProvider);
    final resolver = DefaultTankPresetResolver(
      repository: _ref.read(tankPresetRepositoryProvider),
    );
    final defaultTankPreset = await resolver.resolve(
      settings.defaultTankPreset,
    );
    return UddfEntityImporter(
      defaultTankPreset: defaultTankPreset,
      defaultStartPressure: settings.defaultStartPressure,
      applyDefaultTankToImports: settings.applyDefaultTankToImports,
      placeNameLanguage: settings.placeNameLanguage,
    );
  }
```

2. Move the code from `Set<int> resolve(...)` through the `final result = await importer.import(...);` statement into a method that returns the importer's result, replacing `payload`, `bundle`, `selections`, `duplicateActions` and `currentDiver.id` with its parameters (the body is otherwise unchanged, `preResolvedIdsFor` and all comments included):

```dart
  /// One importer run: [payload] with the review state that indexes it,
  /// written to [diverId]. A single-diver import runs this once for the
  /// whole payload; a multi-diver import once per profile (issue #1893).
  Future<UddfEntityImportResult> _runImporter({
    required UddfEntityImporter importer,
    required ImportRepositories repos,
    required ImportPayload payload,
    required ImportBundle bundle,
    required Map<wizard.ImportEntityType, Set<int>> selections,
    required Map<wizard.ImportEntityType, Map<int, DuplicateAction>>
    duplicateActions,
    required String diverId,
    required bool retainSourceDiveNumbers,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) {
    final notifierState = _ref.read(universalImportNotifierProvider);
    // ... the moved body: resolve, uddfData, preResolvedIdsFor, uddfSelections ...
    return importer.import(
      data: uddfData,
      selections: uddfSelections,
      repositories: repos,
      diverId: diverId,
      // ... every other argument exactly as before ...
    );
  }
```

The `// ...` lines mark code that moves verbatim; nothing in it changes except the five renamed inputs.

3. In `performImport`, after `final skipped = _countSkipped(selections, duplicateActions);`, replace the removed block with:

```dart
    final repos = universalImportRepositories(_ref);
    final importer = await _buildImporter();

    // Every profile this import writes to, the active one first (#1893). A
    // payload the Divers step never split is one untargeted slice, imported
    // into the active diver exactly as before.
    final slices = PayloadSlicer.slice(
      payload,
      firstTargetKey: ExistingDiverTarget(currentDiver.id).targetKey,
    );
    final UddfEntityImportResult result;
    var outcomes = const <DiverImportOutcome>[];
    String? stoppedEarly;
    if (slices.length == 1 && slices.single.targetKey == null) {
      result = await _runImporter(
        importer: importer,
        repos: repos,
        payload: payload,
        bundle: bundle,
        selections: selections,
        duplicateActions: duplicateActions,
        diverId: currentDiver.id,
        retainSourceDiveNumbers: retainSourceDiveNumbers,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      final run = await _importSlices(
        slices: slices,
        importer: importer,
        repos: repos,
        payload: payload,
        bundle: bundle,
        selections: selections,
        duplicateActions: duplicateActions,
        activeDiverId: currentDiver.id,
        retainSourceDiveNumbers: retainSourceDiveNumbers,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      result = run.result;
      outcomes = run.outcomes;
      stoppedEarly = run.error;
    }
```

Everything after it (consolidation, photos, counts, file outcomes, refreshes, notices) stays as it is: it reads `result`, which is in full-payload indices either way.

4. Change the returned `UnifiedImportResult(...)`:

```dart
    final diverOutcomes = [
      for (final outcome in outcomes) outcome.withoutDives(removedDiveIds),
    ];
    return UnifiedImportResult(
      notices: notices,
      importedCounts: counts,
      consolidatedCount: consolidated,
      skippedCount: skipped + cleanedUpFailures,
      // "View Dives", the quality count and site matching all work in the
      // active profile, so they get only its dives; every profile's dives
      // are in diverOutcomes.
      importedDiveIds: diverOutcomes.isEmpty
          ? netImportedDiveIds
          : [
              for (final outcome in diverOutcomes)
                if (outcome.isActive) ...outcome.diveIds,
            ],
      fileOutcomes: fileOutcomes,
      attachedPhotoCount: attachedPhotos + resolvedPhotos,
      unmatchedPhotoCount:
          notifierState.unmatchedPhotoCount + (resolution?.notFoundCount ?? 0),
      diverOutcomes: diverOutcomes,
      errorMessage: stoppedEarly,
    );
```

5. Add the loop and profile creation:

```dart
  /// Imports each slice into its profile, creating new profiles just before
  /// their own slice, so a failure never leaves an empty profile behind. A
  /// slice with nothing selected is skipped and creates nothing. A failure
  /// in the first imported slice fails the import as before; a later one
  /// stops the loop and is reported next to what already landed.
  Future<
    ({
      UddfEntityImportResult result,
      List<DiverImportOutcome> outcomes,
      String? error,
    })
  >
  _importSlices({
    required List<DiverSlice> slices,
    required UddfEntityImporter importer,
    required ImportRepositories repos,
    required ImportPayload payload,
    required ImportBundle bundle,
    required Map<wizard.ImportEntityType, Set<int>> selections,
    required Map<wizard.ImportEntityType, Map<int, DuplicateAction>>
    duplicateActions,
    required String activeDiverId,
    required bool retainSourceDiveNumbers,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    final profiles = await _ref.read(allDiversProvider.future);
    final nameById = {for (final p in profiles) p.id: p.name};
    var total = const UddfEntityImportResult();
    final outcomes = <DiverImportOutcome>[];

    for (final slice in slices) {
      if (cancelToken?.isCancelled ?? false) break;
      final review = DiverSliceReview.of(
        slice,
        bundle,
        selections,
        duplicateActions,
      );
      if (!_importsAnything(review)) continue;

      final targetKey = slice.targetKey!;
      final newSourceKey = DiverTarget.newSourceKeyOf(targetKey);
      var name = newSourceKey ?? '';
      try {
        final String diverId;
        if (newSourceKey != null) {
          final source = payload.sourceDivers
              .where((d) => d.key == newSourceKey)
              .firstOrNull;
          if (source == null) {
            throw StateError('No source diver $newSourceKey');
          }
          name = source.name;
          diverId = await _createProfile(source);
        } else {
          diverId = DiverTarget.diverIdOf(targetKey)!;
          name = nameById[diverId] ?? diverId;
        }

        final sliceResult = await _runImporter(
          importer: importer,
          repos: repos,
          payload: slice.payload,
          bundle: review.bundle,
          selections: review.selections,
          duplicateActions: review.duplicateActions,
          diverId: diverId,
          retainSourceDiveNumbers: retainSourceDiveNumbers,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        total = addSliceResult(total, slice, sliceResult);
        outcomes.add(
          DiverImportOutcome(
            diverId: diverId,
            name: name,
            isNew: newSourceKey != null,
            isActive: diverId == activeDiverId,
            diveIds: sliceResult.diveIds,
          ),
        );
      } catch (e, stackTrace) {
        if (outcomes.isEmpty) rethrow;
        _log.error(
          'Import stopped before profile $name',
          error: e,
          stackTrace: stackTrace,
        );
        return (
          result: total,
          outcomes: outcomes,
          error:
              'Imported ${outcomes.map((o) => o.name).join(', ')}, '
              'then stopped before $name: $e',
        );
      }
    }
    return (result: total, outcomes: outcomes, error: null);
  }

  /// Whether a slice's review imports anything at all.
  bool _importsAnything(DiverSliceReview review) =>
      wizard.ImportEntityType.values.any(
        (type) => _resolveSelections(
          type,
          review.selections,
          review.duplicateActions,
        ).isNotEmpty,
      ) ||
      _resolveSiteOverrides(review.duplicateActions, review.bundle).isNotEmpty;

  /// Creates the profile a new-profile target asked for, seeded from what
  /// the source logbook knows about the diver.
  Future<String> _createProfile(SourceDiver source) async {
    final now = DateTime.now();
    final created = await _ref
        .read(diverRepositoryProvider)
        .createDiver(
          Diver(
            id: '',
            name: source.name,
            email: source.email,
            phone: source.phone,
            emergencyContact: EmergencyContact(name: source.emergencyContact),
            bloodType: source.bloodType,
            insurance: source.danNumber == null
                ? const DiverInsurance()
                : DiverInsurance(
                    provider: 'DAN',
                    policyNumber: source.danNumber,
                  ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return created.id;
  }
```

`ImportProgressCallback` and `ImportCancellationToken` are the types `performImport` already takes; `firstOrNull` comes from `package:collection` (add the import if `universal_adapter.dart` lacks it).

- [ ] **Step 9: Run tests to verify they pass**

Run each:
`flutter test test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`
`flutter test test/features/import_wizard/data/adapters/diver_slice_review_test.dart`
`flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
`flutter test test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart`
`flutter test test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`
Expected: all PASS. The single-diver path calls `_runImporter` with the same arguments `importer.import` received before.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/import_wizard/domain/models/diver_import_outcome.dart lib/features/import_wizard/domain/models/unified_import_result.dart lib/features/import_wizard/data/adapters/diver_slice_review.dart lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/data/adapters/diver_slice_review_test.dart test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart
git commit -m "feat(import-wizard): import each diver's slice into its own profile (#1893)"
```

---

### Task 15: Import tags per profile

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart:862-874,905-934`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

**Interfaces:**
- Consumes: `UnifiedImportResult.diverOutcomes` (Task 14), `TagRepository.getOrCreateTag(String name, {String? colorHex, String? diverId})`, `TagRepository.addTagToDive(String diveId, String tagId)`.
- Produces: `_applyImportTags(UnifiedImportResult result)`: a tag chosen in Review lands on every imported dive, resolved per profile.

- [ ] **Step 1: Write the failing test**

In `import_wizard_notifier_test.dart`, next to `'uses existing tag ID directly without calling getOrCreateTag'` (inside the same group, so `notifier`, `mockAdapter`, `mockTagRepo`, `buildBundle` and `makeItem` are in scope; the notifier's diver is `diver-1`), add (import `package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart`):

```dart
      test('resolves each tag per profile in a multi-profile import', () async {
        notifier.setBundle(buildBundle(diveItems: [makeItem('Dive 1')]));
        notifier.addImportTag(
          const TagSelection(existingTagId: 'tag-existing', name: 'Existing'),
        );
        notifier.addImportTag(const TagSelection(name: 'Vacation'));

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 2},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['d1'],
          diverOutcomes: [
            DiverImportOutcome(
              diverId: 'diver-1',
              name: 'Me',
              isNew: false,
              isActive: true,
              diveIds: ['d1'],
            ),
            DiverImportOutcome(
              diverId: 'diver-2',
              name: 'Bo Ray',
              isNew: true,
              isActive: false,
              diveIds: ['d2'],
            ),
          ],
        );
        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => importResult);

        Tag tag(String id, String name) => Tag(
          id: id,
          name: name,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          mockTagRepo.getOrCreateTag('Vacation', diverId: 'diver-1'),
        ).thenAnswer((_) async => tag('v1', 'Vacation'));
        when(
          mockTagRepo.getOrCreateTag('Existing', diverId: 'diver-2'),
        ).thenAnswer((_) async => tag('e2', 'Existing'));
        when(
          mockTagRepo.getOrCreateTag('Vacation', diverId: 'diver-2'),
        ).thenAnswer((_) async => tag('v2', 'Vacation'));
        when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});

        await notifier.performImport();

        verify(mockTagRepo.addTagToDive('d1', 'tag-existing')).called(1);
        verify(mockTagRepo.addTagToDive('d1', 'v1')).called(1);
        verify(mockTagRepo.addTagToDive('d2', 'e2')).called(1);
        verify(mockTagRepo.addTagToDive('d2', 'v2')).called(1);
        verifyNever(mockTagRepo.addTagToDive('d2', 'tag-existing'));
      });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --plain-name "per profile"`
Expected: FAIL: `d2` is never tagged (today only `importedDiveIds` are).

- [ ] **Step 3: Implement**

In `performImport`, change the tag condition `result.importedDiveIds.isNotEmpty &&` to:

```dart
          (result.importedDiveIds.isNotEmpty ||
              result.diverOutcomes.any((o) => o.diveIds.isNotEmpty)) &&
```

and the call `await _applyImportTags(result.importedDiveIds);` to `await _applyImportTags(result);`.

Replace `_applyImportTags` with:

```dart
  /// Resolve tag selections and apply them to every imported dive.
  ///
  /// A tag belongs to one diver, so when an import wrote to several
  /// profiles (issue #1893) each profile gets its own tag of the chosen
  /// name. The existing tags offered in Review are the active diver's, so
  /// they are used as they are only for that diver's dives.
  Future<void> _applyImportTags(UnifiedImportResult result) async {
    final divesByDiver = <String?, List<String>>{
      if (result.diverOutcomes.isEmpty)
        _diverId: result.importedDiveIds
      else
        for (final outcome in result.diverOutcomes)
          if (outcome.diveIds.isNotEmpty) outcome.diverId: outcome.diveIds,
    };
    final total = divesByDiver.values.fold<int>(0, (n, ids) => n + ids.length);
    state = state.copyWith(
      importPhase: ImportPhase.applyingTags,
      importCurrent: 0,
      importTotal: total,
    );

    var done = 0;
    for (final MapEntry(key: diverId, value: diveIds) in divesByDiver.entries) {
      final tagIds = <String>[];
      for (final tagSelection in state.importTags) {
        if (!tagSelection.isNew && diverId == _diverId) {
          tagIds.add(tagSelection.existingTagId!);
        } else {
          final tag = await _tagRepository!.getOrCreateTag(
            tagSelection.name,
            diverId: diverId,
          );
          tagIds.add(tag.id);
        }
      }
      for (final diveId in diveIds) {
        for (final tagId in tagIds) {
          await _tagRepository!.addTagToDive(diveId, tagId);
        }
        done++;
        state = state.copyWith(importCurrent: done);
      }
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: PASS, including the existing single-profile tag tests (same calls as before: new tags via `getOrCreateTag(name, diverId: 'diver-1')`, existing ids used directly).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git commit -m "feat(import-wizard): apply import tags per profile (#1893)"
```

---

### Task 16: Summary "By profile" section

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/import_summary_diver_outcomes.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart:48-64,70-97` and the children list (~246)
- Test: `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`

**Interfaces:**
- Consumes: `DiverImportOutcome`, `UnifiedImportResult.diverOutcomes` (Task 14); strings `universalImport_summary_byProfileTitle`, `universalImport_summary_newProfile`, `universalImport_summary_switchToSee`, `universalImport_summary_fileImported` (Task 10).
- Produces: `ImportSummaryDiverOutcomes({required List<DiverImportOutcome> outcomes, String? errorMessage})` with `static bool isWorthShowing(List<DiverImportOutcome>)`.

- [ ] **Step 1: Write the failing tests**

Append to `import_summary_step_test.dart` inside `main()` (import `diver_import_outcome.dart`):

```dart
  group('ImportSummaryStep - by profile (#1893)', () {
    const outcomes = [
      DiverImportOutcome(
        diverId: 'me',
        name: 'Marci Glazer',
        isNew: false,
        isActive: true,
        diveIds: ['d1', 'd2'],
      ),
      DiverImportOutcome(
        diverId: 'bo',
        name: 'Alex Glazer',
        isNew: true,
        isActive: false,
        diveIds: ['d3'],
      ),
    ];

    testWidgets('lists what each profile received', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 3},
          consolidatedCount: 0,
          skippedCount: 0,
          diverOutcomes: outcomes,
        ),
      );
      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('By profile'), findsOneWidget);
      expect(find.text('Marci Glazer'), findsOneWidget);
      expect(find.text('2 dives imported'), findsOneWidget);
      expect(find.text('Alex Glazer'), findsOneWidget);
      expect(find.text('New profile'), findsOneWidget);
      expect(
        find.text('Switch to Alex Glazer to see these dives'),
        findsOneWidget,
      );
    });

    testWidgets('a later failure keeps the success view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 2},
          consolidatedCount: 0,
          skippedCount: 0,
          diverOutcomes: [
            DiverImportOutcome(
              diverId: 'me',
              name: 'Marci Glazer',
              isNew: false,
              isActive: true,
              diveIds: ['d1', 'd2'],
            ),
          ],
          errorMessage: 'Imported Marci Glazer, then stopped before Alex',
        ),
      );
      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_success_title')),
        findsOneWidget,
      );
      expect(
        find.text('Imported Marci Glazer, then stopped before Alex'),
        findsOneWidget,
      );
    });

    testWidgets('one active profile adds no section', (tester) async {
      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          diverOutcomes: [
            DiverImportOutcome(
              diverId: 'me',
              name: 'Marci Glazer',
              isNew: false,
              isActive: true,
              diveIds: ['d1'],
            ),
          ],
        ),
      );
      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();
      expect(find.text('By profile'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_summary_step_test.dart --plain-name "by profile"`
Expected: FAIL: no "By profile" text; the failure case shows the error view.

- [ ] **Step 3: Create the section widget**

`lib/features/import_wizard/presentation/widgets/import_summary_diver_outcomes.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Summary step's "By profile" section (issue #1893): what one import
/// wrote to each diver profile, and how to see the ones that are not
/// active. Carries the error when a later profile's import failed, so what
/// did land stays visible.
class ImportSummaryDiverOutcomes extends StatelessWidget {
  const ImportSummaryDiverOutcomes({
    super.key,
    required this.outcomes,
    this.errorMessage,
  });

  final List<DiverImportOutcome> outcomes;
  final String? errorMessage;

  /// Whether [outcomes] tell the user more than the counts above: dives
  /// went to two or more profiles, or to one the app is not showing.
  static bool isWorthShowing(List<DiverImportOutcome> outcomes) =>
      outcomes.length > 1 || outcomes.any((o) => !o.isActive);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: const Key('import_summary_by_profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorMessage case final message?) ...[
          Container(
            key: const Key('import_summary_partial_error'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isWorthShowing(outcomes)) ...[
          Text(
            l10n.universalImport_summary_byProfileTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final outcome in outcomes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                outcome.isNew ? Icons.person_add_alt : Icons.person_outline,
              ),
              title: Text(outcome.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outcome.isNew)
                    Text(l10n.universalImport_summary_newProfile, style: muted),
                  Text(
                    l10n.universalImport_summary_fileImported(
                      outcome.diveIds.length,
                    ),
                    style: muted,
                  ),
                  if (!outcome.isActive)
                    Text(
                      l10n.universalImport_summary_switchToSee(outcome.name),
                      style: muted,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Wire it into the Summary**

In `import_summary_step.dart` (import the new widget and `diver_import_outcome.dart`):

1. Change `if (result.errorMessage != null) {` to `if (result.errorMessage != null && result.diverOutcomes.isEmpty) {`.
2. Pass two more arguments to `_SuccessView(...)`: `diverOutcomes: result.diverOutcomes,` and `partialError: result.errorMessage,`.
3. In `_SuccessView`, add fields `final List<DiverImportOutcome> diverOutcomes;` and `final String? partialError;` with constructor parameters `this.diverOutcomes = const [],` and `this.partialError,`.
4. In the children list, directly before `if (fileNotices.isNotEmpty) ...[`, add:

```dart
            if (partialError != null ||
                ImportSummaryDiverOutcomes.isWorthShowing(diverOutcomes)) ...[
              const SizedBox(height: 16),
              ImportSummaryDiverOutcomes(
                outcomes: diverOutcomes,
                errorMessage: partialError,
              ),
            ],
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`
Expected: PASS (existing error-view tests still pass: their results have no outcomes).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/widgets/import_summary_diver_outcomes.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart test/features/import_wizard/presentation/widgets/import_summary_step_test.dart
git commit -m "feat(import-wizard): show what each profile received in the import summary (#1893)"
```

---

### Task 17: Verify the whole change and prepare follow-ups

**Files:**
- No code changes expected. Scratch: `<scratchpad>/followups_1893.md`

- [ ] **Step 1: Format and analyze**

Run:
```bash
dart format .
flutter analyze
```
Expected: `dart format` changes nothing (every task formatted before committing); `flutter analyze` reports "No issues found!" (infos are fatal in CI, so fix any).

- [ ] **Step 2: Scan for forbidden characters and attribution**

Run:
```bash
git diff origin/main --name-only
git diff origin/main | grep -n $'\xe2\x80\x94' || echo "no em-dashes"
git log origin/main..HEAD --format=%B | grep -inE 'claude|anthropic|co-authored' || echo "clean commit messages"
```
Expected: `no em-dashes` and `clean commit messages`.

- [ ] **Step 3: Run the full test suite once, in the background**

Run (with the Bash tool's `run_in_background: true` and a long timeout; do not overlap it with other `flutter test` runs):
```bash
flutter test > "$TMPDIR/flutter_test_1893.log" 2>&1; echo "exit=$?" >> "$TMPDIR/flutter_test_1893.log"
```
Expected: the last line reads `exit=0`. On failure, read the log, fix the cause in the task that introduced it, and rerun only the failing files.

- [ ] **Step 4: Check the real MacDive libraries still import as one diver**

The reference library on this Mac has one diver plus 37 unowned dives, so it must not trigger the Divers step. Run the skipped real-data suites against it:
```bash
flutter test --dart-define=MACDIVE_XML_SAMPLE="$HOME/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad Mini sync.xml" --run-skipped --tags=real-data test/features/universal_import/data/parsers/macdive_xml_real_sample_test.dart
MACDIVE_SQLITE_REAL_SAMPLE_PATH="$HOME/Documents/submersion development/submersion data/Macdive/MacDive.sqlite" flutter test --run-skipped --tags=real-data test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart
```
Expected: PASS. The XML suite reads a `--dart-define`; the sqlite suite reads the `MACDIVE_SQLITE_REAL_SAMPLE_PATH` environment variable.

- [ ] **Step 5: Draft the follow-up issues**

Write `<scratchpad>/followups_1893.md` with two issue drafts, and show them to the user. File them with `gh issue create` only after the user says yes:

1. **Title:** `Resync can replay another diver's samples for a shared MacDive XML dive`
   **Body:** `DiveResyncOrchestrator.resync` re-parses the stored file and picks the best candidate across every dive in it with DiveMatcher, regardless of which diver logged it. Since #1893, one MacDive XML file can feed several profiles; two divers logging the same buddy dive score almost identically, so resyncing one diver's dive can replay the other diver's samples. Restrict candidates to dives with the same sourceDiverKey as the dive's own import, which needs that key stored with the dive data source. Refs #1893`
2. **Title:** `Map UDDF owners and Subsurface divers to profiles on import`
   **Body:** `#1893 added a Divers step for MacDive libraries holding several divers. UDDF files can carry several <owner> elements (only the first is parsed, into UddfImportResult.owner, and never used) and Subsurface logs can name several divers. Emitting SourceDiver entries and sourceDiverKey from those parsers would reuse the same step, expansion and per-profile import. Refs #1893`

- [ ] **Step 6: Open the PR (only when the user asks)**

Push the branch and open a PR against `main` whose description summarizes the change and contains the line `Closes #1893`. No attribution lines, no session links.

