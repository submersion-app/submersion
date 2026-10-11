# Dive Boat and Surface Condition Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the four orphaned free-text dive columns (`dive_operator`, `boat_name`, `boat_captain`, `surface_conditions`) everywhere a diver reads, edits, exports or bulk-edits dive data (issue #3229).

**Architecture:** Four flat `String?` fields on the `Dive` entity, threaded through every path `weatherDescription` already takes: repository mappers and companions, merge, mirror, planned fill, editor, detail page, bulk edit, `DiveField` list columns, UDDF/CSV/Excel export and re-import, and the detailed PDF. Editor fields suggest the active diver's earlier values through one new repository query.

**Tech Stack:** Flutter, Riverpod 3 (`FutureProvider.family`), Drift, `xml` builder, `flutter_test`.

**Spec:** `docs/design/specs/2026-10-10-dive-boat-surface-fields-design.md`

## Global Constraints

- No schema change: the four columns exist since migration 71.
- All four stay free text. Editor and bulk input are trimmed; blank text stores NULL.
- Entity names: `diveOperator`, `boatName`, `boatCaptain`, `surfaceConditions`. SQL columns: `dive_operator`, `boat_name`, `boat_captain`, `surface_conditions`.
- Editor placement: Operator, Boat, Captain in the Trip group below Dive center; Surface conditions in the Conditions group after Swell Height.
- Suggestions: active diver's distinct non-blank values, most recently used first, capped at 50.
- New `DiveField`s are not sortable and not enabled by default.
- New CSV columns are APPENDED after `Dive Type IDs` so positional consumers keep their offsets.
- Every new string exists in all 11 ARB files; translations reuse the `settings_conflict_field_*` and `query_dives_*` wording.
- No em-dashes anywhere. Run `dart format .` before each commit.

## Review Focus

1. Whitespace-only input in an editor field ("   ") must store NULL, not blank text. Pinned in Task 5.
2. Imported values that differ only by surrounding whitespace ("Calm" and "Calm ") must suggest once. Pinned in Task 4.
3. A boat name starting with a formula character (`=cmd`) must be neutralised in CSV. Pinned in Task 10.
4. XML special characters in a boat name (`Mike & Sons <II>`) must survive a UDDF round-trip. Pinned in Task 9.
5. An enabled bulk gate holding only whitespace must clear the field on every dive. Pinned in Task 7.

## File Map

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/domain/entities/dive.dart` | entity fields |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | mappers, companions, suggestions query |
| `lib/features/dive_log/domain/entities/dive_text_suggestion_field.dart` (new) | which column a suggestion list reads |
| `lib/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart` (new) | suggestions provider |
| `lib/features/dive_log/domain/services/dive_mirror_fields.dart` | mirror classification and copy |
| `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart` | planned fill classification |
| `lib/features/dive_log/domain/services/dive_merge_builder.dart` | merge |
| `lib/l10n/arb/app_*.arb` + generated | strings |
| `lib/features/dive_log/query/dive_query_entity.dart`, `lib/features/query/presentation/query_label_lookup.dart` | query field `boatCaptain` |
| `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart` | `logisticsRows` slot |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | editor and bulk form |
| `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` | bulk gates |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | detail rows |
| `lib/core/constants/dive_field*.dart` | list and table columns |
| `lib/core/services/export/uddf/uddf_dive_logistics.dart` (new) + both writers + importer | UDDF |
| `lib/core/services/export/csv/*`, `lib/features/universal_import/data/...` | CSV export and both CSV import paths |
| `lib/core/services/export/excel/excel_export_service.dart` | Excel |
| `lib/core/services/pdf_templates/pdf_template_detailed.dart` | PDF |

---

### Task 1: Entity and persistence

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive companion near `diveMaster: Value(dive.diveMaster)` ~line 1709, updateDive companion ~line 2035, `_mapRowToDiveWithPreloadedData` ~3985, `_mapRowToDive` ~4430)
- Modify: `lib/features/dive_log/domain/services/dive_mirror_fields.dart`
- Modify: `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_saveDive` literal, carry block)
- Test: `test/features/dive_log/data/repositories/dive_boat_fields_test.dart` (new)
- Test: `test/features/dive_log/domain/services/dive_mirror_fields_test.dart`
- Test: `test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart`

**Interfaces:**
- Produces: `Dive.diveOperator`, `Dive.boatName`, `Dive.boatCaptain`, `Dive.surfaceConditions` (all `String?`), constructor and `copyWith` params of the same names.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/dive_log/data/repositories/dive_boat_fields_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #3229: the operator, boat, captain and surface conditions columns
/// ride on the Dive entity, so they round-trip through both row mappers and
/// a save that does not touch them cannot erase them.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Dive makeDive({
    String id = '',
    String? diveOperator,
    String? boatName,
    String? boatCaptain,
    String? surfaceConditions,
  }) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10),
    diveOperator: diveOperator,
    boatName: boatName,
    boatCaptain: boatCaptain,
    surfaceConditions: surfaceConditions,
  );

  void expectAllFour(domain.Dive d) {
    expect(d.diveOperator, 'Buddy Dive');
    expect(d.boatName, 'Bonaire Breeze');
    expect(d.boatCaptain, 'Rik');
    expect(d.surfaceConditions, 'Choppy');
  }

  domain.Dive fullDive({String id = ''}) => makeDive(
    id: id,
    diveOperator: 'Buddy Dive',
    boatName: 'Bonaire Breeze',
    boatCaptain: 'Rik',
    surfaceConditions: 'Choppy',
  );

  test('createDive and getDiveById round-trip all four', () async {
    final created = await repository.createDive(fullDive());
    expectAllFour((await repository.getDiveById(created.id))!);
  });

  test('getAllDives carries all four', () async {
    await repository.createDive(fullDive());
    expectAllFour((await repository.getAllDives()).single);
  });

  test('updateDive with a fresh entity clears them', () async {
    final created = await repository.createDive(fullDive());
    // copyWith cannot null a field, so build the cleared dive the way the
    // edit form does: a fresh entity.
    await repository.updateDive(makeDive(id: created.id));
    final loaded = (await repository.getDiveById(created.id))!;
    expect(loaded.diveOperator, isNull);
    expect(loaded.boatName, isNull);
    expect(loaded.boatCaptain, isNull);
    expect(loaded.surfaceConditions, isNull);
  });

  test('an import-written row survives an unrelated update', () async {
    final created = await repository.createDive(makeDive());
    // The MacDive and UDDF importers write these columns straight to the
    // row, bypassing the entity.
    await (db.update(db.dives)..where((t) => t.id.equals(created.id))).write(
      const DivesCompanion(
        diveOperator: Value('Buddy Dive'),
        boatName: Value('Bonaire Breeze'),
        boatCaptain: Value('Rik'),
        surfaceConditions: Value('Choppy'),
      ),
    );
    final loaded = (await repository.getDiveById(created.id))!;
    expectAllFour(loaded);

    await repository.updateDive(loaded.copyWith(name: 'Renamed'));

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.name, 'Renamed');
    expectAllFour(reloaded);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_boat_fields_test.dart`
Expected: compile FAIL, `No named parameter with the name 'diveOperator'`.

- [ ] **Step 3: Add the entity fields**

In `dive.dart`, after `final String? diveMaster;` add:

```dart

  /// Who ran the dive, the boat it left from and that boat's captain, as
  /// the diver wrote them (#3229). MacDive and UDDF imports fill these too.
  final String? diveOperator;
  final String? boatName;
  final String? boatCaptain;
```

After `final double? swellHeight; // meters` add:

```dart

  /// The sea state at the surface in the diver's words, such as "Calm" or
  /// "Choppy" (#3229).
  final String? surfaceConditions;
```

In the constructor, after `this.diveMaster,` add `this.diveOperator,`, `this.boatName,`, `this.boatCaptain,`; after `this.swellHeight,` add `this.surfaceConditions,`.

In `copyWith` parameters, after `String? diveMaster,` add `String? diveOperator,`, `String? boatName,`, `String? boatCaptain,`; after `double? swellHeight,` add `String? surfaceConditions,`. In its body, after `diveMaster: diveMaster ?? this.diveMaster,` add:

```dart
      diveOperator: diveOperator ?? this.diveOperator,
      boatName: boatName ?? this.boatName,
      boatCaptain: boatCaptain ?? this.boatCaptain,
```

and after `swellHeight: swellHeight ?? this.swellHeight,` add `surfaceConditions: surfaceConditions ?? this.surfaceConditions,`.

In `props`, after the `diveMaster,` entry add `diveOperator,`, `boatName,`, `boatCaptain,`; after the `swellHeight,` entry add `surfaceConditions,`.

- [ ] **Step 4: Read and write them in the repository**

In both `createDive` and `updateDive` companions, after `diveMaster: Value(dive.diveMaster),` add (match the surrounding indent):

```dart
diveOperator: Value(dive.diveOperator),
boatName: Value(dive.boatName),
boatCaptain: Value(dive.boatCaptain),
surfaceConditions: Value(dive.surfaceConditions),
```

In both `_mapRowToDiveWithPreloadedData` and `_mapRowToDive`, after `diveMaster: row.diveMaster,` add:

```dart
diveOperator: row.diveOperator,
boatName: row.boatName,
boatCaptain: row.boatCaptain,
surfaceConditions: row.surfaceConditions,
```

- [ ] **Step 5: Run the repository test**

Run: `flutter test test/features/dive_log/data/repositories/dive_boat_fields_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Classify the fields for mirror and planned fill**

In `dive_mirror_fields.dart`, `kMirroredDiveFields`: after the `'entryMethod', 'exitMethod',` line add:

```dart
  // the boat and the sea it left on (#3229)
  'diveOperator', 'boatName', 'boatCaptain', 'surfaceConditions',
```

In `mirroredDiveFrom`, after `swellHeight: source.swellHeight,` add:

```dart
    surfaceConditions: source.surfaceConditions,
    diveOperator: source.diveOperator,
    boatName: source.boatName,
    boatCaptain: source.boatCaptain,
```

In `planned_dive_fill_fields.dart`, `kHumanDiveFields`: after `'weatherDescription',` add `'diveOperator',`, `'boatName',`, `'boatCaptain',`, `'surfaceConditions',`.

- [ ] **Step 7: Pin the mirror and planned-fill behaviour**

Append to `dive_mirror_fields_test.dart` inside `main`:

```dart
  test('mirroredDiveFrom copies the boat and surface conditions (#3229)', () {
    final source = Dive(
      id: 'src',
      diverId: 'eric',
      dateTime: DateTime(2026, 6, 1, 9),
      diveOperator: 'Buddy Dive',
      boatName: 'Bonaire Breeze',
      boatCaptain: 'Rik',
      surfaceConditions: 'Choppy',
    );
    final mirrored = mirroredDiveFrom(
      source,
      targetDiverId: 'chris',
      outingId: 'o',
      includeSite: true,
      tripId: null,
      includeDiveCenter: false,
      diveTypeIds: const ['wreck'],
      tags: const [],
      diverRoleIds: ['buddy'],
    );
    expect(mirrored.diveOperator, 'Buddy Dive');
    expect(mirrored.boatName, 'Bonaire Breeze');
    expect(mirrored.boatCaptain, 'Rik');
    expect(mirrored.surfaceConditions, 'Choppy');
  });
```

Append to `planned_dive_fill_fields_test.dart` inside `main`:

```dart
  test('a download never overwrites the boat or surface conditions', () {
    // The fill copies only measured fields onto the planned dive (#3229).
    expect(
      kHumanDiveFields,
      containsAll([
        'diveOperator',
        'boatName',
        'boatCaptain',
        'surfaceConditions',
      ]),
    );
  });
```

- [ ] **Step 8: Carry the fields through the editor save**

`updateDive` now writes the four columns, so `_saveDive` must name them or every editor save would erase them (the census in `dive_edit_save_field_census_test.dart` fails until it does). In `dive_edit_page.dart`, inside `final dive = Dive(` in `_saveDive`, after `weatherCode: _existingDive?.weatherCode,` add:

```dart
        diveOperator: _existingDive?.diveOperator,
        boatName: _existingDive?.boatName,
        boatCaptain: _existingDive?.boatCaptain,
        surfaceConditions: _existingDive?.surfaceConditions,
```

(Task 5 replaces these carries with the editor's own controllers.)

- [ ] **Step 9: Run the affected tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_boat_fields_test.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/presentation/pages/dive_edit_preserves_hidden_fields_test.dart`
Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/domain/services/dive_mirror_fields.dart lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/data/repositories/dive_boat_fields_test.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart
git commit -m "feat(dive-log): carry boat, operator, captain and surface conditions on the dive"
```

---

### Task 2: Merge

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart` (near `weatherDescription: _firstNonNull(...)` ~line 406)
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: Task 1 entity fields.

- [ ] **Step 1: Write the failing test**

In `dive_merge_builder_test.dart`, inside `group('build - metadata', ...)`, add:

```dart
    test('boat fields and surface conditions: first non-null wins (#3229)', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        boatName: 'Bonaire Breeze',
        surfaceConditions: 'Calm',
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        boatName: 'Other boat',
        boatCaptain: 'Rik',
        diveOperator: 'Buddy Dive',
        surfaceConditions: 'Choppy',
      );
      final merged = builder.build([b, a]).mergedDive; // unsorted input
      expect(merged.boatName, 'Bonaire Breeze');
      expect(merged.surfaceConditions, 'Calm');
      expect(merged.boatCaptain, 'Rik'); // a has none -> filled from b
      expect(merged.diveOperator, 'Buddy Dive');
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL, `Expected: 'Bonaire Breeze' Actual: <null>`.

- [ ] **Step 3: Implement**

In `dive_merge_builder.dart`, after `weatherDescription: _firstNonNull(sorted, (d) => d.weatherDescription),` add:

```dart
      diveOperator: _firstNonNull(sorted, (d) => d.diveOperator),
      boatName: _firstNonNull(sorted, (d) => d.boatName),
      boatCaptain: _firstNonNull(sorted, (d) => d.boatCaptain),
      surfaceConditions: _firstNonNull(sorted, (d) => d.surfaceConditions),
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_log/domain/services/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/domain/services/dive_merge_builder.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart
git commit -m "feat(dive-log): keep boat fields and surface conditions when merging dives"
```

---

### Task 3: Strings and the query field

**Files:**
- Create (scratchpad, not committed): `$SCRATCH/add_boat_keys.py`
- Modify: `lib/l10n/arb/app_*.arb` (11 files) and the generated `lib/l10n/arb/app_localizations*.dart`
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (~line 397)
- Modify: `lib/features/query/presentation/query_label_lookup.dart` (~line 114)
- Test: existing `test/features/query/presentation/query_labels_test.dart`, `test/l10n/arb_parity_test.dart`

**Interfaces:**
- Produces these `AppLocalizations` getters, used by Tasks 5 to 11:
  `diveLog_edit_row_diveOperator`, `diveLog_edit_row_boatName`, `diveLog_edit_row_boatCaptain`, `diveLog_edit_label_surfaceConditions`,
  `diveLog_detail_label_diveOperator`, `diveLog_detail_label_boatName`, `diveLog_detail_label_boatCaptain`, `diveLog_detail_label_surfaceConditions`,
  `enum_diveField_diveOperator`, `enum_diveField_boatName`, `enum_diveField_boatCaptain`, `enum_diveField_surfaceConditions` and each with `_short`,
  `query_dives_boatCaptain`,
  `pdf_diveOperator`, `pdf_boatName`, `pdf_boatCaptain`, `pdf_surfaceConditions`.

- [ ] **Step 1: Write the insertion script**

ARB files are feature-grouped and must be edited textually, anchored on a sibling key that exists in all 11 files (all anchors below were verified). Save as `$SCRATCH/add_boat_keys.py` (`$SCRATCH` = this session's scratchpad):

```python
"""Insert the #3229 keys into all 11 ARB files after sibling anchor keys."""
import json
import pathlib

ARB = pathlib.Path('lib/l10n/arb')
LOCALES = ['en', 'ar', 'de', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']

OPERATOR = dict(en='Operator', ar='المشغّل', de='Anbieter', es='Operador',
                fr='Opérateur', he='מפעיל', hu='Szolgáltató', it='Operatore',
                nl='Operator', pt='Operadora', zh='运营商')
BOAT = dict(en='Boat', ar='القارب', de='Boot', es='Barco', fr='Bateau',
            he='סירה', hu='Hajó', it='Barca', nl='Boot', pt='Barco', zh='船')
CAPTAIN = dict(en='Captain', ar='القبطان', de='Kapitän', es='Capitán',
               fr='Capitaine', he='רב החובל', hu='Kapitány', it='Capitano',
               nl='Kapitein', pt='Capitão', zh='船长')
SURFACE = dict(en='Surface Conditions', ar='أحوال السطح',
               de='Oberflächenbedingungen', es='Condiciones en superficie',
               fr='Conditions en surface', he='תנאי פני השטח',
               hu='Felszíni körülmények', it='Condizioni in superficie',
               nl='Oppervlakteomstandigheden', pt='Condições na superfície',
               zh='水面状况')
SURFACE_SHORT = dict(en='Surface', ar='السطح', de='Oberfläche',
                     es='Superficie', fr='Surface', he='פני המים',
                     hu='Felszín', it='Superficie', nl='Oppervlak',
                     pt='Superfície', zh='水面')
DIVE_OPERATOR = dict(en='Dive Operator', ar='مشغل الغوص', de='Tauchanbieter',
                     es='Operador de buceo', fr='Opérateur de plongée',
                     he='מפעיל צלילה', hu='Merülésszervező',
                     it='Operatore subacqueo', nl='Duikorganisatie',
                     pt='Operadora de mergulho', zh='潜水运营商')
BOAT_CAPTAIN = dict(en='Boat Captain', ar='قبطان القارب', de='Kapitän',
                    es='Capitán del barco', fr='Capitaine du bateau',
                    he='רב החובל', hu='Kapitány', it='Capitano della barca',
                    nl='Kapitein', pt='Capitão do barco', zh='船长')

# anchor key -> [(new key, values, English @description or None)]
PLAN = {
    'diveLog_edit_row_diveCenter': [
        ('diveLog_edit_row_diveOperator', OPERATOR, None),
        ('diveLog_edit_row_boatName', BOAT, None),
        ('diveLog_edit_row_boatCaptain', CAPTAIN, None),
    ],
    'diveLog_edit_label_swellHeight': [
        ('diveLog_edit_label_surfaceConditions', SURFACE, None),
    ],
    'diveLog_detail_label_diveMaster': [
        ('diveLog_detail_label_diveOperator', OPERATOR, None),
        ('diveLog_detail_label_boatName', BOAT, None),
        ('diveLog_detail_label_boatCaptain', CAPTAIN, None),
    ],
    'diveLog_detail_label_swellHeight': [
        ('diveLog_detail_label_surfaceConditions', SURFACE, None),
    ],
    'enum_diveField_weatherDescription': [
        ('enum_diveField_surfaceConditions', SURFACE, None),
    ],
    'enum_diveField_diveCenterName': [
        ('enum_diveField_diveOperator', DIVE_OPERATOR, None),
        ('enum_diveField_boatName', BOAT, None),
        ('enum_diveField_boatCaptain', BOAT_CAPTAIN, None),
    ],
    'enum_diveField_weatherDescription_short': [
        ('enum_diveField_surfaceConditions_short', SURFACE_SHORT, None),
    ],
    'enum_diveField_diveCenterName_short': [
        ('enum_diveField_diveOperator_short', OPERATOR, None),
        ('enum_diveField_boatName_short', BOAT, None),
        ('enum_diveField_boatCaptain_short', CAPTAIN, None),
    ],
    'query_dives_boatName': [
        ('query_dives_boatCaptain', CAPTAIN,
         'Field label in the query builder'),
    ],
    'pdf_diveCenter': [
        ('pdf_diveOperator', OPERATOR, None),
        ('pdf_boatName', BOAT, None),
        ('pdf_boatCaptain', CAPTAIN, None),
    ],
    'pdf_currentDirection': [
        ('pdf_surfaceConditions', SURFACE_SHORT, None),
    ],
}


def insert_after(lines, anchor, new_lines):
    idx = next(i for i, l in enumerate(lines)
               if l.startswith(f'  "{anchor}":'))
    j = idx + 1
    # Step past the anchor's own @-metadata (one line or a multi-line block).
    if j < len(lines) and lines[j].startswith(f'  "@{anchor}":'):
        j += 1
        while j < len(lines) and not lines[j].startswith('  "'):
            j += 1
    lines[j:j] = new_lines


for loc in LOCALES:
    path = ARB / f'app_{loc}.arb'
    lines = path.read_text(encoding='utf-8').split('\n')
    for anchor, entries in PLAN.items():
        new_lines = []
        for key, values, desc in entries:
            assert f'"{key}"' not in '\n'.join(lines), f'{key} exists'
            value = json.dumps(values[loc], ensure_ascii=False)
            new_lines.append(f'  "{key}": {value},')
            if loc == 'en' and desc:
                new_lines.append(
                    f'  "@{key}": {{"description": {json.dumps(desc)}}},')
        insert_after(lines, anchor, new_lines)
    path.write_text('\n'.join(lines), encoding='utf-8')
    json.loads(path.read_text(encoding='utf-8'))  # still valid JSON
    print('OK', loc)
```

- [ ] **Step 2: Run it and regenerate**

Run: `python3.14 $SCRATCH/add_boat_keys.py && flutter gen-l10n`
Expected: `OK` for all 11 locales. Then `git diff --numstat -- lib/l10n/arb/*.arb` shows 21 added / 0 removed per translated file and 22 / 0 for `app_en.arb`.

- [ ] **Step 3: Add the query field and its label**

In `dive_query_entity.dart`, after `_text('boatName', 'boat_name'),` add `_text('boatCaptain', 'boat_captain'),`.

In `query_label_lookup.dart`, after the `case 'query_dives_boatName':` return, add:

```dart
    case 'query_dives_boatCaptain':
      return l10n.query_dives_boatCaptain;
```

- [ ] **Step 4: Run the guards**

Run: `flutter test test/l10n/arb_parity_test.dart test/l10n/arb_no_duplicate_keys_test.dart test/l10n/arb_diacritics_test.dart test/features/query/`
Expected: PASS. (`query_labels_test` fails if the lookup case is missing.)

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/l10n/arb lib/features/dive_log/query/dive_query_entity.dart lib/features/query/presentation/query_label_lookup.dart
git commit -m "feat(dive-log): add strings for boat fields and surface conditions; query by captain"
```

---

### Task 4: Suggestions query and provider

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_text_suggestion_field.dart`
- Create: `lib/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (after `getDistinctLegacyBuddyNames`, ~line 2820)
- Test: `test/features/dive_log/data/repositories/dive_text_suggestions_test.dart` (new)

**Interfaces:**
- Produces: `enum DiveTextSuggestionField { diveOperator, boatName, boatCaptain, surfaceConditions }` with `final String column`; `DiveRepository.getRecentTextValues(DiveTextSuggestionField field, {String? diverId, int limit = 50}) -> Future<List<String>>`; `diveTextSuggestionsProvider` (`FutureProvider.family<List<String>, DiveTextSuggestionField>`).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/dive_text_suggestions_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';

import '../../../../helpers/test_database.dart';

/// The editor's suggestions for the free-text boat fields (#3229).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> logBoat(String? boat, int day, {String? diverId}) =>
      repository.createDive(
        domain.Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime.utc(2026, 7, day, 10),
          boatName: boat,
        ),
      );

  test('distinct values, most recently used first', () async {
    await logBoat('Alpha', 1);
    await logBoat('Bravo', 2);
    await logBoat('Alpha', 3);

    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
      ['Alpha', 'Bravo'],
    );
  });

  test('values differing only by surrounding whitespace suggest once', () async {
    await logBoat('Calm Seas ', 1);
    await logBoat('Calm Seas', 2);

    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
      ['Calm Seas'],
    );
  });

  test('null and blank values are not suggested', () async {
    await logBoat(null, 1);
    await logBoat('   ', 2);
    await logBoat('', 3);

    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
      isEmpty,
    );
  });

  test('scoped to the diver', () async {
    await insertDiver('eric');
    await insertDiver('chris');
    await logBoat('Mine', 1, diverId: 'eric');
    await logBoat('Theirs', 2, diverId: 'chris');

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.boatName,
        diverId: 'eric',
      ),
      ['Mine'],
    );
  });

  test('capped at the limit', () async {
    for (var day = 1; day <= 5; day++) {
      await logBoat('Boat $day', day);
    }

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.boatName,
        limit: 2,
      ),
      ['Boat 5', 'Boat 4'],
    );
  });

  test('each field reads its own column', () async {
    await repository.createDive(
      domain.Dive(
        id: '',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        diveOperator: 'Buddy Dive',
        boatCaptain: 'Rik',
        surfaceConditions: 'Choppy',
      ),
    );

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.diveOperator,
      ),
      ['Buddy Dive'],
    );
    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatCaptain),
      ['Rik'],
    );
    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.surfaceConditions,
      ),
      ['Choppy'],
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_text_suggestions_test.dart`
Expected: compile FAIL, `dive_text_suggestion_field.dart` not found.

- [ ] **Step 3: Create the enum**

`lib/features/dive_log/domain/entities/dive_text_suggestion_field.dart`:

```dart
/// A free-text dive column whose earlier values the dive editor offers as
/// suggestions (#3229).
///
/// The SQL column name lives here, never in the caller, so the suggestions
/// query interpolates only these four fixed names.
enum DiveTextSuggestionField {
  diveOperator('dive_operator'),
  boatName('boat_name'),
  boatCaptain('boat_captain'),
  surfaceConditions('surface_conditions');

  const DiveTextSuggestionField(this.column);

  /// The `dives` column the values are read from.
  final String column;
}
```

- [ ] **Step 4: Add the repository query**

In `dive_repository_impl.dart`, import `package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart`, and after `getDistinctLegacyBuddyNames` add:

```dart
  /// The diver's distinct non-blank values of one free-text column, most
  /// recently used first, for the dive editor's suggestions (#3229). Values
  /// that differ only by surrounding whitespace collapse into one.
  // stats-scope-exempt: a suggestion list, not an aggregate; an excluded
  // dive's boat is still one the diver may type again.
  Future<List<String>> getRecentTextValues(
    DiveTextSuggestionField field, {
    String? diverId,
    int limit = 50,
  }) async {
    final column = field.column;
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT TRIM($column) AS value FROM dives '
          "WHERE $column IS NOT NULL AND TRIM($column) <> '' $diverFilter "
          'GROUP BY TRIM($column) '
          'ORDER BY MAX(dive_date_time) DESC, value '
          'LIMIT ?',
          variables: [
            if (diverId != null) Variable(diverId),
            Variable(limit),
          ],
          readsFrom: {_db.dives},
        )
        .get();
    return rows.map((r) => r.read<String>('value')).toList();
  }
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/dive_log/data/repositories/dive_text_suggestions_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Add the provider**

`lib/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The active diver's earlier values for one free-text dive field, most
/// recent first (#3229). Refreshes whenever the dives table is written, so a
/// boat logged on another device appears after sync.
final diveTextSuggestionsProvider =
    FutureProvider.family<List<String>, DiveTextSuggestionField>((
      ref,
      field,
    ) async {
      final repository = ref.watch(diveRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      return repository.getRecentTextValues(field, diverId: diverId);
    });
```

- [ ] **Step 7: Run the architecture guards**

Run: `flutter test test/architecture/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS (the tick guard sees `invalidateSelfWhen`; the stats census sees the exempt marker).

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/features/dive_log/domain/entities/dive_text_suggestion_field.dart lib/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_text_suggestions_test.dart
git commit -m "feat(dive-log): suggest a diver's earlier boats, operators, captains and sea states"
```

---

### Task 5: Editor fields

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_boat_fields_test.dart` (new)

**Interfaces:**
- Consumes: Task 1 fields, Task 3 strings, Task 4 `diveTextSuggestionsProvider` and `DiveTextSuggestionField`.
- Produces: `TripSection.logisticsRows` (`List<Widget>`, default `const []`); `_DiveEditPageState` controllers `_diveOperatorController`, `_boatNameController`, `_boatCaptainController`, `_surfaceConditionsController` and helper `String? _trimmedOrNull(TextEditingController c)` (Task 7 uses both).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_log/presentation/pages/dive_edit_boat_fields_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3229: the editor shows and saves the dive's operator, boat,
/// captain and surface conditions, against a real database.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          // Pinned so the English finders below hold on any host locale.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens a collapsed group by tapping its header text.
  Future<void> expand(WidgetTester tester, String header) async {
    final finder = find.text(header).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder fieldOf(String label) => find.descendant(
    of: find.widgetWithText(SuggestionFormRow, label),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<domain.Dive> createDive({String? boatName}) =>
      repository.createDive(
        domain.Dive(
          id: '',
          dateTime: DateTime.utc(2026, 5, 1, 10),
          maxDepth: 20,
          boatName: boatName,
        ),
      );

  testWidgets('typing in the Trip group saves operator, boat and captain', (
    tester,
  ) async {
    final dive = await createDive();
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

    await expand(tester, 'Trip');
    await tester.enterText(fieldOf('Operator'), 'Buddy Dive');
    await tester.enterText(fieldOf('Boat'), ' Bonaire Breeze ');
    await tester.enterText(fieldOf('Captain'), 'Rik');
    await tester.pumpAndSettle();
    await save(tester);

    expect(savedId, isNotNull);
    final saved = (await repository.getDiveById(dive.id))!;
    expect(saved.diveOperator, 'Buddy Dive');
    expect(saved.boatName, 'Bonaire Breeze', reason: 'trimmed on save');
    expect(saved.boatCaptain, 'Rik');
  });

  testWidgets('whitespace-only text clears the field to null', (tester) async {
    final dive = await createDive(boatName: 'Old boat');
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Trip');
    expect(find.text('Old boat'), findsOneWidget, reason: 'loaded');
    await tester.enterText(fieldOf('Boat'), '   ');
    await tester.pumpAndSettle();
    await save(tester);

    expect((await repository.getDiveById(dive.id))!.boatName, isNull);
  });

  testWidgets('the Conditions group saves surface conditions', (tester) async {
    final dive = await createDive();
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Conditions');
    await tester.enterText(fieldOf('Surface Conditions'), 'Choppy');
    await tester.pumpAndSettle();
    await save(tester);

    expect((await repository.getDiveById(dive.id))!.surfaceConditions, 'Choppy');
  });

  testWidgets('an imported boat survives saving an unrelated edit', (
    tester,
  ) async {
    final dive = await createDive();
    await (db.update(db.dives)..where((t) => t.id.equals(dive.id))).write(
      const DivesCompanion(
        diveOperator: Value('Buddy Dive'),
        boatName: Value('Bonaire Breeze'),
        boatCaptain: Value('Rik'),
        surfaceConditions: Value('Choppy'),
      ),
    );
    await pumpEditor(tester, dive.id);

    final nameRow = find
        .ancestor(of: find.text('Name'), matching: find.byType(FormRow))
        .first;
    await tester.ensureVisible(nameRow);
    await tester.tap(nameRow);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: nameRow, matching: find.byType(TextField)),
      'Renamed',
    );
    await tester.pumpAndSettle();
    await save(tester);

    final saved = (await repository.getDiveById(dive.id))!;
    expect(saved.name, 'Renamed');
    expect(saved.diveOperator, 'Buddy Dive');
    expect(saved.boatName, 'Bonaire Breeze');
    expect(saved.boatCaptain, 'Rik');
    expect(saved.surfaceConditions, 'Choppy');
  });

  testWidgets('Boat offers a boat from an earlier dive', (tester) async {
    await createDive(boatName: 'Bonaire Breeze');
    final dive = await createDive();
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Trip');
    await tester.enterText(fieldOf('Boat'), 'Bon');
    await tester.pumpAndSettle();

    expect(find.text('Bonaire Breeze'), findsOneWidget);
  });

  testWidgets('the collapsed Trip summary names the boat', (tester) async {
    final dive = await createDive(boatName: 'Bonaire Breeze');
    await pumpEditor(tester, dive.id);

    expect(find.textContaining('Bonaire Breeze'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_boat_fields_test.dart`
Expected: FAIL, no `SuggestionFormRow` labeled `Operator`.

- [ ] **Step 3: Give TripSection a logistics slot**

In `trip_section.dart`, add the constructor parameter `this.logisticsRows = const [],` (after `this.centerChild,`), the field:

```dart

  /// Free-text rows under the dive center: operator, boat and captain
  /// (#3229). Page-built, like the Conditions group's row lists.
  final List<Widget> logisticsRows;
```

and in `build`, after the dive center `Column(...)` child of `FormSection.children`, add `...logisticsRows,`.

- [ ] **Step 4: Add controllers, load, dispose and the trim helper**

In `dive_edit_page.dart`:

1. Imports: `package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart`, `package:submersion/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart`, `package:submersion/shared/widgets/forms/suggestion_form_row.dart` (skip any already present).
2. After `final _weatherDescriptionController = TextEditingController();` add:

```dart
  final _diveOperatorController = TextEditingController();
  final _boatNameController = TextEditingController();
  final _boatCaptainController = TextEditingController();
  final _surfaceConditionsController = TextEditingController();
```

3. In the `_markDirty` listener list, after `_weatherDescriptionController,` add the four controllers.
4. In `dispose`, after `_weatherDescriptionController.dispose();` add a `dispose()` for each of the four.
5. In the load block, after `_weatherDescriptionController.text = dive.weatherDescription ?? '';` add:

```dart
          _diveOperatorController.text = dive.diveOperator ?? '';
          _boatNameController.text = dive.boatName ?? '';
          _boatCaptainController.text = dive.boatCaptain ?? '';
          _surfaceConditionsController.text = dive.surfaceConditions ?? '';
```

6. Above `String _tripSummary()` add:

```dart
  /// [c]'s text without surrounding whitespace, or null when nothing is
  /// left, so a cleared free-text field stores NULL (#3229).
  String? _trimmedOrNull(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }
```

- [ ] **Step 5: Save from the controllers**

In `_saveDive`'s `Dive(` literal, replace the four Task 1 carries (`diveOperator: _existingDive?.diveOperator,` and its three siblings) with:

```dart
        diveOperator: _trimmedOrNull(_diveOperatorController),
        boatName: _trimmedOrNull(_boatNameController),
        boatCaptain: _trimmedOrNull(_boatCaptainController),
        surfaceConditions: _trimmedOrNull(_surfaceConditionsController),
```

and move them from the "Fields this form has no widget for" block to just after `diveCenter: _selectedDiveCenter,`.

- [ ] **Step 6: Build the Trip group rows**

Replace `_tripSummary` with:

```dart
  String _tripSummary() => [
    if (_selectedTrip != null) _selectedTrip!.name,
    if (_selectedDiveCenter != null) _selectedDiveCenter!.name,
    ?_trimmedOrNull(_boatNameController),
  ].join(' · ');
```

In `_buildTripGroupSection`, change `isEmpty:` to:

```dart
      isEmpty:
          _selectedTrip == null &&
          _selectedDiveCenter == null &&
          _trimmedOrNull(_diveOperatorController) == null &&
          _trimmedOrNull(_boatNameController) == null &&
          _trimmedOrNull(_boatCaptainController) == null,
```

and pass `logisticsRows: _logisticsRows(),` to `TripSection`. Add the builder after `_tripSummary`:

```dart
  /// A free-text row that suggests the diver's earlier values of [field].
  Widget _suggestedTextRow(
    String label,
    TextEditingController controller,
    DiveTextSuggestionField field, {
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions:
          ref.watch(diveTextSuggestionsProvider(field)).value ?? const [],
      textCapitalization: capitalization,
    );
  }

  List<Widget> _logisticsRows() {
    final l10n = context.l10n;
    return [
      _suggestedTextRow(
        l10n.diveLog_edit_row_diveOperator,
        _diveOperatorController,
        DiveTextSuggestionField.diveOperator,
      ),
      _suggestedTextRow(
        l10n.diveLog_edit_row_boatName,
        _boatNameController,
        DiveTextSuggestionField.boatName,
      ),
      _suggestedTextRow(
        l10n.diveLog_edit_row_boatCaptain,
        _boatCaptainController,
        DiveTextSuggestionField.boatCaptain,
      ),
    ];
  }
```

(`?element` null-aware entries need Dart 3.8; the SDK floor is ^3.10 and `uddf_certification_currency.dart` already uses them.)

- [ ] **Step 7: Add the surface conditions row**

In `_environmentRows`, after the Swell Height `FormRow.text(...)`, add:

```dart
      _suggestedTextRow(
        l10n.diveLog_edit_label_surfaceConditions,
        _surfaceConditionsController,
        DiveTextSuggestionField.surfaceConditions,
        capitalization: TextCapitalization.sentences,
      ),
```

In `_conditionsIsEmpty`, append `&& _surfaceConditionsController.text.trim().isEmpty` before the `;`. In `_conditionsSummary`, add after the visibility entry:

```dart
      ?_trimmedOrNull(_surfaceConditionsController),
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_boat_fields_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/presentation/pages/dive_edit_preserves_hidden_fields_test.dart test/features/dive_log/presentation/widgets/edit_sections/`
Expected: PASS. Then run the whole editor folder, since the Trip and Conditions groups are shared: `flutter test test/features/dive_log/presentation/pages/ --name "dive_edit|DiveEdit"` (or the full folder if the filter misses files).

- [ ] **Step 9: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_boat_fields_test.dart
git commit -m "feat(dive-log): edit a dive's operator, boat, captain and surface conditions"
```

---

### Task 6: Detail page rows

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildDetailsSection` ~3246, `_hasEnvironmentData` ~3346, `_buildEnvironmentSection` ~3379 and ~3528)
- Test: `test/features/dive_log/presentation/pages/dive_detail_boat_fields_test.dart` (new)

**Interfaces:**
- Consumes: Task 1 fields, Task 3 strings.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/pages/dive_detail_boat_fields_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3229: the detail page shows the operator, boat and captain in
/// Details, and surface conditions under Environment > Dive conditions.
void main() {
  void ignoreOverflowErrors() {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  }

  Future<void> pumpWith(WidgetTester tester, Dive dive) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );

    ignoreOverflowErrors();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder row(String label, String value) => find.ancestor(
    of: find.text(value),
    matching: find.widgetWithText(DiveDetailRow, label),
  );

  testWidgets('shows operator, boat and captain rows', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(
        diveOperator: 'Buddy Dive',
        boatName: 'Bonaire Breeze',
        boatCaptain: 'Rik',
      ),
    );

    expect(row('Operator', 'Buddy Dive'), findsOneWidget);
    expect(row('Boat', 'Bonaire Breeze'), findsOneWidget);
    expect(row('Captain', 'Rik'), findsOneWidget);
  });

  testWidgets('no rows for empty or blank values', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(boatName: '   '),
    );

    expect(find.widgetWithText(DiveDetailRow, 'Operator'), findsNothing);
    expect(find.widgetWithText(DiveDetailRow, 'Boat'), findsNothing);
    expect(find.widgetWithText(DiveDetailRow, 'Captain'), findsNothing);
  });

  testWidgets('surface conditions alone opens Dive conditions', (
    tester,
  ) async {
    // The Environment card is hidden unless something in it has a value,
    // so the card gate and the subsection gate must both count it.
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(surfaceConditions: 'Choppy'),
    );

    expect(row('Surface Conditions', 'Choppy'), findsOneWidget);
    expect(find.text('Dive Conditions'), findsOneWidget);
  });
}
```

(`'Dive Conditions'` is the en value of `diveLog_detail_subsection_diveConditions`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_boat_fields_test.dart`
Expected: FAIL, `row('Operator', 'Buddy Dive')` finds nothing.

- [ ] **Step 3: Implement the rows and gates**

Next to `_hasEnvironmentData`, add:

```dart
  /// Whether free text [s] holds anything once trimmed (#3229).
  bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
```

In `_buildDetailsSection`, after `if (dive.diveCenter != null) _buildDiveCenterRow(context, dive),` add:

```dart
            // Free text from the editor or a MacDive/UDDF import (#3229).
            for (final (label, value) in [
              (context.l10n.diveLog_detail_label_diveOperator, dive.diveOperator),
              (context.l10n.diveLog_detail_label_boatName, dive.boatName),
              (context.l10n.diveLog_detail_label_boatCaptain, dive.boatCaptain),
            ])
              if (_hasText(value)) _buildDetailRow(context, label, value!.trim()),
```

In `_hasEnvironmentData`, add `|| _hasText(dive.surfaceConditions)` to the expression. In `_buildEnvironmentSection`, add `|| _hasText(dive.surfaceConditions)` to `hasDiveConditions`, and after the swell height row add:

```dart
              if (_hasText(dive.surfaceConditions))
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_surfaceConditions,
                  dive.surfaceConditions!.trim(),
                ),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_boat_fields_test.dart test/features/dive_log/presentation/pages/dive_detail_inherited_site_fields_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_boat_fields_test.dart
git commit -m "feat(dive-log): show a dive's operator, boat, captain and surface conditions"
```

---

### Task 7: Bulk edit

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_collectScalarInputs` ~1507, bulk Logistics `FormSection` ~1389, `_buildBulkConditionsSection` ~2006)
- Test: `test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`
- Test: `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`

**Interfaces:**
- Consumes: Task 5 controllers and `_trimmedOrNull`.
- Produces: `BulkField.diveOperator`, `.boatName`, `.boatCaptain`, `.surfaceConditions`; `BulkScalarInputs` named params of the same names (`String?`).

- [ ] **Step 1: Write the failing unit test**

Append to `bulk_edit_field_set_test.dart` inside `main`:

```dart
  test('the boat and surface gates write their columns (#3229)', () {
    final c = buildScalarCompanion(
      {
        BulkField.diveOperator,
        BulkField.boatName,
        BulkField.boatCaptain,
        BulkField.surfaceConditions,
      },
      BulkScalarInputs(
        diveOperator: 'Buddy Dive',
        boatName: 'Bonaire Breeze',
        boatCaptain: null,
        surfaceConditions: 'Calm',
      ),
    );
    expect(c.diveOperator.value, 'Buddy Dive');
    expect(c.boatName.value, 'Bonaire Breeze');
    // Enabled and empty clears the column.
    expect(c.boatCaptain.present, isTrue);
    expect(c.boatCaptain.value, isNull);
    expect(c.surfaceConditions.value, 'Calm');
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`
Expected: compile FAIL, `BulkField.diveOperator` not defined.

- [ ] **Step 3: Add the gates**

In `bulk_edit_field_set.dart`:
- `enum BulkField`: after `diveCenter,` add `diveOperator,`, `boatName,`, `boatCaptain,`; after `swellHeight,` add `surfaceConditions,`.
- `BulkScalarInputs` constructor: after `this.diveCenterId,` add `this.diveOperator,`, `this.boatName,`, `this.boatCaptain,`; after `this.swellHeight,` add `this.surfaceConditions,`. Fields: after `final String? diveCenterId;` add `final String? diveOperator;`, `final String? boatName;`, `final String? boatCaptain;`; after the `swellHeight` field add `final String? surfaceConditions;`.
- `buildScalarCompanion`: after the `BulkField.diveCenter` arm add:

```dart
      BulkField.diveOperator => c.copyWith(
        diveOperator: Value(i.diveOperator),
      ),
      BulkField.boatName => c.copyWith(boatName: Value(i.boatName)),
      BulkField.boatCaptain => c.copyWith(boatCaptain: Value(i.boatCaptain)),
```

and after the `BulkField.swellHeight` arm add:

```dart
      BulkField.surfaceConditions => c.copyWith(
        surfaceConditions: Value(i.surfaceConditions),
      ),
```

- [ ] **Step 4: Run the unit test**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing form tests**

In `bulk_dive_edit_form_test.dart`, update the gate count test: change `findsNWidgets(30)` to `findsNWidgets(34)` and its comment to `// 8 Logistics (course, #1741; operator, boat, captain, #3229) + 10 Conditions (surface conditions, #3229) + 6 Weather + 6 Rebreather` followed by the existing remaining lines with the total `= 34`. Then, inside `group('DiveEditPage bulk mode', ...)` after the course tests, add:

```dart
    Finder gateOf(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(BulkFieldGate),
    );

    Future<void> fillGate(
      WidgetTester tester,
      String label,
      String text,
    ) async {
      await tester.ensureVisible(gateOf(label));
      await tester.tap(
        find.descendant(of: gateOf(label), matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: gateOf(label), matching: find.byType(TextField)),
        text,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Captain gate sets every selected dive (#3229)', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'cap-1'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'cap-2', boatCaptain: 'Old'),
      );
      await pumpBulkDives(tester, [d1.id, d2.id]);

      await fillGate(tester, 'Captain', '  Rik ');
      await saveBulk(tester);

      expect((await repository.getDiveById(d1.id))!.boatCaptain, 'Rik');
      expect((await repository.getDiveById(d2.id))!.boatCaptain, 'Rik');
    });

    testWidgets('an enabled Captain gate holding only spaces clears it', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'cap-3', boatCaptain: 'Rik'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'cap-4', boatCaptain: 'Ana'),
      );
      await pumpBulkDives(tester, [d1.id, d2.id]);

      await fillGate(tester, 'Captain', '   ');
      await saveBulk(tester);

      expect((await repository.getDiveById(d1.id))!.boatCaptain, isNull);
      expect((await repository.getDiveById(d2.id))!.boatCaptain, isNull);
    });

    testWidgets('the Surface Conditions gate sets every dive (#3229)', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'sea-1'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'sea-2'),
      );
      await pumpBulkDives(tester, [d1.id, d2.id]);

      await fillGate(tester, 'Surface Conditions', 'Calm');
      await saveBulk(tester);

      expect((await repository.getDiveById(d1.id))!.surfaceConditions, 'Calm');
      expect((await repository.getDiveById(d2.id))!.surfaceConditions, 'Calm');
    });
```

- [ ] **Step 6: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`
Expected: FAIL, 30 gates found instead of 34, and no `Captain` gate.

- [ ] **Step 7: Wire the bulk form**

In `_collectScalarInputs`, after `diveCenterId: _selectedDiveCenter?.id,` add:

```dart
      diveOperator: _trimmedOrNull(_diveOperatorController),
      boatName: _trimmedOrNull(_boatNameController),
      boatCaptain: _trimmedOrNull(_boatCaptainController),
```

and after the `swellHeight:` entry add `surfaceConditions: _trimmedOrNull(_surfaceConditionsController),`.

In the bulk Logistics `FormSection`, after the `_gatedRow(BulkField.diveCenter, ...)` entry add:

```dart
              for (final (field, label, controller) in [
                (
                  BulkField.diveOperator,
                  l10n.diveLog_edit_row_diveOperator,
                  _diveOperatorController,
                ),
                (
                  BulkField.boatName,
                  l10n.diveLog_edit_row_boatName,
                  _boatNameController,
                ),
                (
                  BulkField.boatCaptain,
                  l10n.diveLog_edit_row_boatCaptain,
                  _boatCaptainController,
                ),
              ])
                _gatedRow(
                  field,
                  FormRow.text(
                    label: label,
                    controller: controller,
                    alwaysEditing: true,
                  ),
                ),
```

In `_buildBulkConditionsSection`, after the `_gatedRow(BulkField.swellHeight, ...)` entry add:

```dart
          _gatedRow(
            BulkField.surfaceConditions,
            FormRow.text(
              label: context.l10n.diveLog_edit_label_surfaceConditions,
              controller: _surfaceConditionsController,
              alwaysEditing: true,
            ),
          ),
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_page_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart
git commit -m "feat(dive-log): bulk-edit boat fields and surface conditions"
```

---

### Task 8: List and table columns

**Files:**
- Modify: `lib/core/constants/dive_field.dart`, `lib/core/constants/dive_field_extractor.dart`, `lib/core/constants/dive_field_column_sizing.dart`
- Test: `test/core/constants/dive_field_test.dart`, `test/core/constants/dive_field_extractor_test.dart`

**Interfaces:**
- Produces: `DiveField.diveOperator`, `.boatName`, `.boatCaptain` (category `location`), `DiveField.surfaceConditions` (category `environment`).

- [ ] **Step 1: Write the failing tests**

Append to `dive_field_test.dart` inside `main`:

```dart
  group('boat fields and surface conditions (#3229)', () {
    test('categories', () {
      expect(DiveField.diveOperator.category, DiveFieldCategory.location);
      expect(DiveField.boatName.category, DiveFieldCategory.location);
      expect(DiveField.boatCaptain.category, DiveFieldCategory.location);
      expect(
        DiveField.surfaceConditions.category,
        DiveFieldCategory.environment,
      );
    });

    test('free text is not sortable and has no icon', () {
      for (final f in [
        DiveField.diveOperator,
        DiveField.boatName,
        DiveField.boatCaptain,
        DiveField.surfaceConditions,
      ]) {
        expect(f.sortable, isFalse, reason: f.name);
        expect(f.icon, isNull, reason: f.name);
      }
    });

    test('names', () {
      expect(DiveField.diveOperator.displayName, 'Dive Operator');
      expect(DiveField.boatCaptain.shortLabel, 'Captain');
      expect(DiveField.surfaceConditions.shortLabel, 'Surface');
    });
  });
```

In `dive_field_extractor_test.dart`, add to the shared `testDive` constructor `diveOperator: 'Buddy Dive', boatName: 'Bonaire Breeze', boatCaptain: 'Rik', surfaceConditions: 'Calm',` and add:

```dart
    test('boat fields and surface conditions extract their text', () {
      expect(DiveField.diveOperator.extractFromDive(testDive), 'Buddy Dive');
      expect(DiveField.boatName.extractFromDive(testDive), 'Bonaire Breeze');
      expect(DiveField.boatCaptain.extractFromDive(testDive), 'Rik');
      expect(DiveField.surfaceConditions.extractFromDive(testDive), 'Calm');
    });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/constants/`
Expected: compile FAIL, `DiveField.diveOperator` not defined.

- [ ] **Step 3: Add the enum values and every switch arm**

In `dive_field.dart`:
- Enum: after `weatherDescription,` add `surfaceConditions,`; after `diveCenterName,` add `diveOperator,`, `boatName,`, `boatCaptain,`.
- `category`: add `case DiveField.surfaceConditions:` beside `case DiveField.weatherDescription:`; add the three boat cases beside `case DiveField.diveCenterName:`.
- `displayName`: `surfaceConditions` returns `'Surface Conditions'`; `diveOperator` `'Dive Operator'`; `boatName` `'Boat'`; `boatCaptain` `'Boat Captain'`.
- `shortLabel`: `'Surface'`, `'Operator'`, `'Boat'`, `'Captain'`.
- `localizedDisplayName`: `DiveField.surfaceConditions => l10n.enum_diveField_surfaceConditions,` and likewise `enum_diveField_diveOperator`, `enum_diveField_boatName`, `enum_diveField_boatCaptain`.
- `localizedShortLabel`: the same with `_short`.
- `icon`: add the four as `case ...: return null;` beside `case DiveField.weatherDescription:`.
- `sortable`: add the four cases beside `case DiveField.weatherDescription:` (returns `false`).

In `dive_field_extractor.dart`, after the `weatherDescription` arm:

```dart
      case DiveField.surfaceConditions:
        return dive.surfaceConditions;
```

and after the `diveCenterName` arm:

```dart
      case DiveField.diveOperator:
        return dive.diveOperator;
      case DiveField.boatName:
        return dive.boatName;
      case DiveField.boatCaptain:
        return dive.boatCaptain;
```

`extractFromSummary` ends in `default: return null;`, so it needs no change: these fields are not on `DiveSummary`, exactly like `weatherDescription`.

In `dive_field_column_sizing.dart`, in the first switch (default widths) add `case DiveField.surfaceConditions: return 140;` beside `weatherDescription`, and `case DiveField.diveOperator: return 140;`, `case DiveField.boatName: return 140;`, `case DiveField.boatCaptain: return 120;` beside `diveCenterName`. In the second switch (minimum widths) add `surfaceConditions: 80`, `diveOperator: 80`, `boatName: 80`, `boatCaptain: 60` the same way.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/constants/ test/features/settings/presentation/conflicts/ test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
Expected: PASS. (`flutter analyze lib/core/constants` must report no non-exhaustive switch.)

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/constants/dive_field.dart lib/core/constants/dive_field_extractor.dart lib/core/constants/dive_field_column_sizing.dart test/core/constants/dive_field_test.dart test/core/constants/dive_field_extractor_test.dart
git commit -m "feat(dive-log): offer boat fields and surface conditions as list and table columns"
```

---

### Task 9: UDDF export and re-import

**Files:**
- Create: `lib/core/services/export/uddf/uddf_dive_logistics.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (after the `exittype` element ~line 548)
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart` (after the `exittype` element ~line 571)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (element map ~line 1392)
- Test: `test/core/services/export/uddf/uddf_dive_logistics_round_trip_test.dart` (new)

**Interfaces:**
- Produces: `UddfDiveLogistics.write(XmlBuilder, Dive)`, `UddfDiveLogistics.elementToMapKey` (`Map<String, String>`).

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dive_logistics_round_trip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3229: the operator, boat, captain and surface conditions survive a
/// UDDF export and re-import from both writers, in the MacDive element names
/// the reader already understands.
void main() {
  Dive dive({
    String? diveOperator,
    String? boatName,
    String? boatCaptain,
    String? surfaceConditions,
  }) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
    diveOperator: diveOperator,
    boatName: boatName,
    boatCaptain: boatCaptain,
    surfaceConditions: surfaceConditions,
  );

  final writers = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  Future<Map<String, dynamic>> restore(String xml) async =>
      (await UddfFullImportService().importAllDataFromUddf(xml)).dives.single;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores all four, XML special characters included', () async {
        final restored = await restore(
          await write([
            dive(
              diveOperator: 'Buddy Dive',
              boatName: 'Mike & Sons <II>',
              boatCaptain: 'Rik',
              surfaceConditions: 'Choppy',
            ),
          ]),
        );

        expect(restored['diveOperator'], 'Buddy Dive');
        expect(restored['boatName'], 'Mike & Sons <II>');
        expect(restored['boatCaptain'], 'Rik');
        expect(restored['surfaceConditions'], 'Choppy');
      });

      test('writes nothing for empty or blank values', () async {
        final xml = await write([dive(boatName: '   ')]);

        expect(xml, isNot(contains('<boatname')));
        expect(xml, isNot(contains('<boatcaptain')));
        expect(xml, isNot(contains('<diveoperator')));
        expect(xml, isNot(contains('<surfaceconditions')));
      });
    });
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_dive_logistics_round_trip_test.dart`
Expected: FAIL, `restored['diveOperator']` is null.

- [ ] **Step 3: Create the helper**

`lib/core/services/export/uddf/uddf_dive_logistics.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's operator, boat, captain and surface conditions in UDDF (#3229).
///
/// UDDF has no elements for these. MacDive writes them as
/// `<diveoperator>`, `<boatname>`, `<boatcaptain>` and `<surfaceconditions>`
/// inside the dive's `<informationafterdive>`; both Submersion writers use
/// the same names, so a file round-trips through Submersion and MacDive.
abstract final class UddfDiveLogistics {
  /// Element name to dive map key, shared with the reader.
  static const elementToMapKey = {
    'surfaceconditions': 'surfaceConditions',
    'boatname': 'boatName',
    'boatcaptain': 'boatCaptain',
    'diveoperator': 'diveOperator',
  };

  /// Writes each of [dive]'s non-blank fields; writes nothing for the rest.
  static void write(XmlBuilder builder, Dive dive) {
    final values = {
      'surfaceconditions': dive.surfaceConditions,
      'boatname': dive.boatName,
      'boatcaptain': dive.boatCaptain,
      'diveoperator': dive.diveOperator,
    };
    for (final MapEntry(:key, :value) in values.entries) {
      final text = value?.trim();
      if (text == null || text.isEmpty) continue;
      builder.element(key, nest: text);
    }
  }
}
```

- [ ] **Step 4: Call it from both writers and share the map with the reader**

In `uddf_export_builders.dart` and `uddf_export_service.dart`, import the helper and, inside `informationafterdive`, after the `if (dive.exitMethod != null) { ... 'exittype' ... }` block, add `UddfDiveLogistics.write(builder, dive);`.

In `uddf_full_import_service.dart`, import the helper and change the element map to:

```dart
      for (final entry in const {
        'weather': 'weather',
        ...UddfDiveLogistics.elementToMapKey,
      }.entries) {
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/export/uddf/`
Expected: PASS, including `uddf_macdive_import_test.dart` (reader unchanged in behaviour).

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/core/services/export/uddf/uddf_dive_logistics.dart lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_export_service.dart lib/core/services/export/uddf/uddf_full_import_service.dart test/core/services/export/uddf/uddf_dive_logistics_round_trip_test.dart
git commit -m "feat(export): write boat fields and surface conditions to UDDF"
```

---

### Task 10: CSV and Excel

**Files:**
- Modify: `lib/core/services/export/csv/dive_csv_columns.dart`, `lib/core/services/export/csv/csv_dives_writer.dart`
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart` (~line 172)
- Modify: `lib/features/universal_import/data/csv/presets/built_in_presets.dart` (~line 721)
- Modify: `lib/features/universal_import/data/csv/extractors/dive_extractor.dart` (~line 43)
- Modify: `lib/core/services/export/excel/excel_export_service.dart` (~lines 253 and 298)
- Modify: `test/core/services/export/csv/goldens/dives_metric.csv` (regenerated), `test/core/services/export/csv/csv_metric_golden_test.dart` (doc comment)
- Test: `test/core/services/export/csv/csv_test_fixtures.dart`, `csv_dives_writer_test.dart`, `csv_dive_types_test.dart`, `test/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser_test.dart`, `test/features/universal_import/data/csv/integration/submersion_csv_roundtrip_test.dart`
- Test: `test/core/services/export/excel/excel_boat_fields_test.dart` (new)

**Interfaces:**
- Produces: `DiveCsvColumns.diveOperator` (`'Dive Operator'`), `.boatName` (`'Boat Name'`), `.boatCaptain` (`'Boat Captain'`), `.surfaceConditions` (`'Surface Conditions'`).

- [ ] **Step 1: Extend fixtures and expectations (failing)**

In `csv_test_fixtures.dart`, add to the first golden dive (after `weatherDescription: 'Sunny',`):

```dart
    diveOperator: 'Buddy Dive',
    boatName: 'Bonaire Breeze',
    boatCaptain: 'Rik',
    surfaceConditions: 'Calm',
```

In `submersion_dives_csv_parser_test.dart`, after `expect(d['weatherDescription'], 'Sunny');` add:

```dart
      expect(d['diveOperator'], 'Buddy Dive');
      expect(d['boatName'], 'Bonaire Breeze');
      expect(d['boatCaptain'], 'Rik');
      expect(d['surfaceConditions'], 'Calm');
```

In `submersion_csv_roundtrip_test.dart`, add the same four values to its dive fixture (after `weatherDescription: 'Sunny',`) and the same four expectations after its `expect(d['weatherDescription'], 'Sunny');`.

In `csv_dives_writer_test.dart`'s formula test, add `boatName: '=cmd',` to the `copyWith` and `expect(r['Boat Name'], "'=cmd");` to the expectations.

In `csv_dive_types_test.dart`, replace the `fixed.last` test body with:

```dart
      // Spreadsheets that address the export by position keep their offsets:
      // Dive Type IDs still directly follows Custom Fields.
      expect(
        DiveCsvColumns.fixed.indexOf(DiveCsvColumns.diveTypeIds),
        DiveCsvColumns.fixed.indexOf(DiveCsvColumns.customFields) + 1,
      );
```

and add beside it:

```dart
    test('appends the #3229 columns after Dive Type IDs', () {
      expect(DiveCsvColumns.fixed.sublist(DiveCsvColumns.fixed.length - 4), [
        DiveCsvColumns.diveOperator,
        DiveCsvColumns.boatName,
        DiveCsvColumns.boatCaptain,
        DiveCsvColumns.surfaceConditions,
      ]);
    });
```

Create `test/core/services/export/excel/excel_boat_fields_test.dart`:

```dart
import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3229: the Dives sheet carries the boat fields and surface
/// conditions.
void main() {
  test('the Dives sheet has a column for each', () async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1, 10),
          diveOperator: 'Buddy Dive',
          boatName: 'Bonaire Breeze',
          boatCaptain: 'Rik',
          surfaceConditions: 'Calm',
        ),
      ],
      sites: const [],
      equipment: const [],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
    );
    final sheet = xl.Excel.decodeBytes(bytes).tables['Dives']!;
    final headers = [
      for (final cell in sheet.rows.first) cell?.value?.toString() ?? '',
    ];
    String cell(String header) =>
        sheet.rows[1][headers.indexOf(header)]?.value?.toString() ?? '';

    expect(cell('Dive Operator'), 'Buddy Dive');
    expect(cell('Boat Name'), 'Bonaire Breeze');
    expect(cell('Boat Captain'), 'Rik');
    expect(cell('Surface Conditions'), 'Calm');
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/export/csv/ test/core/services/export/excel/excel_boat_fields_test.dart test/features/universal_import/data/parsers/submersion_csv/ test/features/universal_import/data/csv/integration/submersion_csv_roundtrip_test.dart`
Expected: FAIL (missing constants and columns).

- [ ] **Step 3: Add the CSV columns**

In `dive_csv_columns.dart`, below the `diveTypeIds` constant add:

```dart

  // Appended after Dive Type IDs so spreadsheets that address the export
  // by column position keep their offsets (#3229).
  static const diveOperator = 'Dive Operator';
  static const boatName = 'Boat Name';
  static const boatCaptain = 'Boat Captain';
  static const surfaceConditions = 'Surface Conditions';
```

and in `fixed`, after `diveTypeIds,` add `diveOperator,`, `boatName,`, `boatCaptain,`, `surfaceConditions,`.

In `csv_dives_writer.dart`, in the header list after `DiveCsvColumns.diveTypeIds,` add the four constants; in the row, after the Dive Type IDs cell (the `sanitizeCsvField(...)` that follows the "A name cannot be turned back into its id" comment), add:

```dart
        sanitizeCsvField(dive.diveOperator),
        sanitizeCsvField(dive.boatName),
        sanitizeCsvField(dive.boatCaptain),
        sanitizeCsvField(dive.surfaceConditions),
```

- [ ] **Step 4: Read them back on both import paths**

In `submersion_dives_csv_parser.dart`, after `'weatherDescription': table.text(row, 'Weather Description'),` add:

```dart
        'diveOperator': table.text(row, 'Dive Operator'),
        'boatName': table.text(row, 'Boat Name'),
        'boatCaptain': table.text(row, 'Boat Captain'),
        'surfaceConditions': table.text(row, 'Surface Conditions'),
```

In `built_in_presets.dart`, after the `weatherDescription` `ColumnMapping`, add:

```dart
        ColumnMapping(
          sourceColumn: DiveCsvColumns.diveOperator,
          targetField: 'diveOperator',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.boatName,
          targetField: 'boatName',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.boatCaptain,
          targetField: 'boatCaptain',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.surfaceConditions,
          targetField: 'surfaceConditions',
        ),
```

In `dive_extractor.dart`, after `'weatherDescription',` add `'diveOperator',`, `'boatName',`, `'boatCaptain',`, `'surfaceConditions',`.

(The importer's existing `applyImportedMetadata` block in `uddf_entity_importer.dart` already persists these four map keys; no change there.)

- [ ] **Step 5: Add the Excel columns**

In `excel_export_service.dart`'s Dives `headers`, after `'Weather Description',` add `'Dive Operator'`, `'Boat Name'`, `'Boat Captain'`, `'Surface Conditions'`; in `rowData`, after `dive.weatherDescription ?? '',` add:

```dart
        dive.diveOperator ?? '',
        dive.boatName ?? '',
        dive.boatCaptain ?? '',
        dive.surfaceConditions ?? '',
```

- [ ] **Step 6: Regenerate the dives golden deliberately**

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart --dart-define=WRITE_CSV_GOLDENS=true`
Then check with `git diff test/core/services/export/csv/goldens/` that ONLY `dives_metric.csv` changed, and only by appending `,Dive Operator,Boat Name,Boat Captain,Surface Conditions` to the header row (before the `custom:` columns) and the four values to each row. Add to the golden test's doc comment:

```dart
/// The dives golden moved once, for issue #3229: Dive Operator, Boat Name,
/// Boat Captain and Surface Conditions are APPENDED after Dive Type IDs, so
/// every earlier column keeps its position.
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/core/services/export/ test/features/universal_import/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/core/services/export/csv lib/core/services/export/excel/excel_export_service.dart lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart lib/features/universal_import/data/csv/presets/built_in_presets.dart lib/features/universal_import/data/csv/extractors/dive_extractor.dart test/core/services/export test/features/universal_import
git commit -m "feat(export): export and re-import boat fields and surface conditions in CSV and Excel"
```

---

### Task 11: Detailed PDF

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart` (`_teamFields` ~517, `_conditionFields` ~476)
- Test: `test/core/services/pdf_templates/pdf_detailed_content_test.dart`

**Interfaces:**
- Consumes: Task 3 `pdf_*` strings.

- [ ] **Step 1: Write the failing test**

Append inside `main` of `pdf_detailed_content_test.dart`:

```dart
  group('boat fields and surface conditions (#3229)', () {
    test('print when present', () async {
      final text = pdfVisibleText(
        await render(
          dive.copyWith(
            diveOperator: 'Buddy Dive',
            boatName: 'Bonaire Breeze',
            boatCaptain: 'Captain Rik',
            surfaceConditions: 'Choppy',
          ),
        ),
      );
      expect(text, contains('Buddy Dive'));
      expect(text, contains('Bonaire Breeze'));
      expect(text, contains('Captain Rik'));
      expect(text, contains('Choppy'));
    });

    test('no label when absent', () async {
      final text = pdfVisibleText(await render(dive));
      expect(text, isNot(contains('Operator')));
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_detailed_content_test.dart`
Expected: FAIL, text lacks `Buddy Dive`.

- [ ] **Step 3: Implement**

Add a file-private helper above the template class:

```dart
/// Whether free text [s] holds anything once trimmed (#3229).
bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
```

In `_teamFields`, after the dive center field add:

```dart
      if (_hasText(dive.diveOperator))
        _Field(l10n.pdf_diveOperator, dive.diveOperator!.trim()),
      if (_hasText(dive.boatName))
        _Field(l10n.pdf_boatName, dive.boatName!.trim()),
      if (_hasText(dive.boatCaptain))
        _Field(l10n.pdf_boatCaptain, dive.boatCaptain!.trim()),
```

In `_conditionFields`, after the current direction field add:

```dart
      if (_hasText(dive.surfaceConditions))
        _Field(l10n.pdf_surfaceConditions, dive.surfaceConditions!.trim()),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/pdf_templates/ test/core/services/pdf_equipment_arrangement_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/services/pdf_templates/pdf_template_detailed.dart test/core/services/pdf_templates/pdf_detailed_content_test.dart
git commit -m "feat(export): print boat fields and surface conditions in the detailed PDF"
```

---

### Task 12: Whole-branch verification

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes from format on committed files; `No issues found!`.

- [ ] **Step 2: Guards**

Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS.

- [ ] **Step 3: Generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: empty output.

- [ ] **Step 4: Affected suites**

Run: `flutter test test/features/dive_log/ test/features/dive_computer/ test/features/query/ test/features/universal_import/ test/features/settings/presentation/conflicts/ test/core/constants/ test/core/services/export/ test/core/services/pdf_templates/`
Expected: PASS. Any failure is fixed in the task that owns the file, then re-run.

- [ ] **Step 5: Em-dash scan of the diff**

Run: `git diff origin/main -- . ':!lib/l10n/arb/app_localizations*.dart' | python3.14 -c "import sys;t=sys.stdin.read();print(t.count(chr(0x2014)), t.count(chr(0x2013)))"`
Expected: `0 0` for added lines (pre-existing dashes in context lines are acceptable; inspect any hit).
