# Cylinder Passports 5: Fills CSV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth self-describing Submersion CSV, one row per cylinder fill, that exports from the CSV export sheet in either unit mode and re-imports through the import wizard (alone or batched with the equipment CSV) keeping each fill's id, so a file imports once.

**Architecture:** The export side follows the equipment sheet exactly: a `CsvColumn` pair for the two unit-bearing columns, a `CsvFillsWriter` that takes `CsvExportUnits`, a `SubmersionCsvKind.fills` header signature, and the `CsvExportService` / `ExportService` / `ExportNotifier` / `CsvExportDialog` / transfer page chain that the observations export added most recently. The import side follows the equipment CSV parser and the media entity type: `ImportFormat.submersionFillsCsv` detected by signature and routed to `SubmersionFillsCsvParser`, a `fills` entity type in both entity enums, a Fills group in the wizard, and a `CsvFillImporter` (the CSV twin of `TagFillImporter`) that keeps the fill id, skips a fill already here or deleted here, stamps the importing diver, and links the fill to the diver's cylinder that holds its passport id. No schema change: `cylinder_fills` already has every column.

**Tech Stack:** Flutter, Dart 3, Drift, Riverpod, `csv`, `intl`, `uuid`, flutter_test with the in-memory test database (`test/helpers/test_database.dart`).

**Spec:** `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md` (section 4 scope note, section 10.2 `cylinder_fills`, section 10.8 visibility, section 17 row 5). Issue #2339, umbrella #2333.

## Global Constraints

- Never use an em dash (U+2014) or an en dash (U+2013) as punctuation anywhere: code, comments, strings, ARB files, docs, commit messages, PR body. Double hyphens and spaced hyphens as prose punctuation are equally forbidden. Rewrite with a comma, colon, semicolon or parentheses.
- No mention of the coding tool or its vendor anywhere (see the Attribution section of the project instructions file at the repository root): no co-author trailers, no "Generated with" line, no session links, nothing in commit messages, PR body or comments.
- Imports grouped: dart, flutter, packages, then local (`package:submersion/...`) after a blank line, as every file touched here already does.
- Run `dart format .` before every commit; the pre-push hook rejects unformatted code and CI treats analyzer infos as fatal.
- Anything showing units respects the active diver's unit settings: here, the CSV's My units mode writes pressure and temperature in the diver's units, named in the header, through `CsvExportUnits`. Metric mode output for the existing three sheets must stay byte-identical to `test/core/services/export/csv/goldens/*.csv`.
- A test that replaces process-wide state puts it back (`FilePickerPlatform.instance`, surface size); CI bundles test files in one isolate.
- Files under 800 lines where practical; new files are small and single-purpose. `uddf_entity_importer.dart` (3550 lines) and `export_providers.dart` (1520 lines) are pre-existing and get only the minimum lines.
- No schema change in this phase: no new table, column, rung or migration.
- Every new user-facing string goes in all 11 ARB files under `lib/l10n/arb` (ar de en es fr he hu it nl pt zh), then `flutter gen-l10n`; `flutter test test/l10n` must pass (parity across locales, no duplicate keys, the Spanish and Portuguese diacritics twin scan).
- CSV header text stays English (the other three sheets never localise headers); only dialog and status strings are localised.
- Every PR body must carry `Closes #2339` and `Refs #2333` (the "PR Issue Link" check).

## Review Focus

1. Importing the same fills file twice: the second import must create nothing and report 0 fills; a person expects a re-import to be harmless. Pinned in Task 6 ("the same file imported twice adds nothing").
2. A fill whose passport id matches none of the diver's cylinders: it must still import, unlinked, under its passport id, and appear on a cylinder that later gets that id. Pinned in Task 5 (`CsvFillImporter` "a fill with no matching cylinder stays unlinked") and Task 6 ("a fill links to the cylinder holding its passport id").
3. A psi and Fahrenheit file from an imperial diver: the stored bar and Celsius must come back within the file's rounding (0.5 psi is 0.034 bar; 0.5 °F is 0.28 °C), not shifted by a conversion applied twice or not at all. Pinned in Task 6 (the "My units, imperial diver" round trip with `near(..., 0.06)` and `near(..., 0.6)`).
4. A fill deleted here and then re-imported from an older export: it must stay deleted (deletion log), the rule `TagFillImporter` already applies to tags. Pinned in Task 5 ("a fill deleted here is not brought back") and Task 6 ("a fill deleted here stays deleted after a re-import").
5. A batch of the equipment CSV plus the fills CSV in one wizard run: both must land, and the merger's per-file namespace (`uddfId` becomes `f1:<id>`) must not leak into the stored fill id. Pinned in Task 6 ("an equipment CSV and a fills CSV import together").

---

## File structure

**Create**

- `lib/core/services/export/csv/csv_fills_writer.dart`: the fills sheet writer (one responsibility: rows from `CylinderFill` plus an equipment lookup for the display columns).
- `lib/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart`: the fills sheet parser.
- `lib/features/cylinder_passports/data/services/csv_fill_importer.dart`: id-preserving dedupe, diver stamp and passport linking for parsed fill rows.
- `test/core/services/export/csv/csv_fills_writer_test.dart`, `test/core/services/export/csv/goldens/fills_metric.csv`.
- `test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart`.
- `test/features/cylinder_passports/data/services/csv_fill_importer_test.dart`.
- `test/features/import_wizard/data/adapters/universal_adapter_fills_csv_test.dart`.

**Modify**

- Spec: `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md`.
- Codec: `lib/core/services/export/csv/codec/csv_column.dart`, `codec/submersion_csv_signatures.dart`.
- Repository: `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` (one new query).
- Export chain: `lib/core/services/export/csv/csv_export_service.dart`, `lib/core/services/export/export_service.dart`, `lib/features/settings/presentation/providers/export_providers.dart`, `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`, `lib/features/transfer/presentation/pages/transfer_page.dart`.
- Import chain: `lib/features/universal_import/data/models/import_enums.dart`, `lib/features/universal_import/data/services/format_detector.dart`, `lib/features/universal_import/data/parsers/parser_registry.dart`, `lib/features/universal_import/data/services/payload_merger.dart`, `lib/features/universal_import/data/services/payload_diver_expander.dart`, `lib/core/services/export/models/uddf_import_result.dart`, `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/features/import_wizard/domain/models/import_bundle.dart`, `lib/features/import_wizard/data/adapters/universal_adapter.dart`, `lib/features/import_wizard/data/services/import_provider_invalidator.dart`, `lib/features/import_wizard/presentation/widgets/review_step.dart`, `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`.
- l10n: all 11 `lib/l10n/arb/app_*.arb`.
- Docs: `docs/guide/import-export.md`.
- Tests: `test/core/services/export/csv/csv_test_fixtures.dart`, `csv_metric_golden_test.dart`, `codec/submersion_csv_signatures_test.dart`, `csv_units_plumbing_test.dart`, `csv_export_service_test.dart`, `csv_round_trip_test.dart`, `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart` (`buildRepositories`), `test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`, `test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`, `test/features/universal_import/data/models/import_enums_test.dart`, `test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`, `test/features/universal_import/data/parsers/submersion_csv/submersion_csv_parser_warnings_test.dart`, `test/features/import_wizard/domain/models/import_bundle_test.dart`, `test/features/import_wizard/data/services/import_provider_invalidator_test.dart`, `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`.

**Survey corrections (verified 2026-09-29).** `unified_import_wizard.dart` no longer has its own switch over the wizard enum; it calls `invalidateImportRelatedProviders` (line 395), so only the invalidator changes. `lib/features/universal_import/presentation/widgets/import_summary_step.dart` no longer exists; the only switches over the universal `ImportEntityType` are `PayloadMerger._foldKey` (a switch statement, so a new value is a compile error until it gets a case) and nothing else. The wizard-enum switches are: `import_provider_invalidator.dart`, `review_step.dart` `_typeDisplayName`, and `import_summary_step.dart` `_iconForType` and `_labelForType` (two switches in one file). `ImportDuplicateChecker` is a fixed list of `_checkEntityIfPresent` calls, not a switch, so an unlisted type is simply not checked; fills need no entry there (see Task 5).

---

### Task 1: Amend the spec with the 2026-09-29 decisions

**Files:**
- Modify: `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md` (section 4 lines 75-76, end of section 10.2 before line 364 `### 10.3`, section 17 row 5 line 657)

**Interfaces:**
- Consumes: nothing.
- Produces: the decisions every later task argues from.

- [ ] **Step 1: Amend section 4**

Replace the two lines

```markdown
- UDDF export of fills. CSV joins in PR 5; the `.db` backup is a byte copy
  and already carries every table.
```

with

```markdown
- UDDF export of fills. CSV joins in PR 5; the `.db` backup is a byte copy
  and already carries every table.

  Decided 2026-09-29 (PR 5): there is no multi-file CSV "bundle" in the
  code. The app has three self-describing Submersion CSVs (dives, sites,
  equipment), each with a header signature and a parser, plus an
  export-only gear check-ins CSV. Fills get their own fourth Submersion
  CSV, one row per fill: an entry in the CSV export sheet
  (`CsvExportType.fills`), a header signature (`SubmersionCsvKind.fills`),
  a format (`ImportFormat.submersionFillsCsv`), a parser and a Fills group
  in the import wizard. A fills file imports on its own and also batches
  with the equipment CSV.
```

- [ ] **Step 2: Amend section 10.2**

Insert before the `### 10.3 \`fill_stations\`` heading (after the last invariant bullet, "`equipment_id` is resolved from `passport_id` on write ..."):

```markdown
Decided 2026-09-29 (PR 5, the fills CSV):

- Columns: everything except the reserved `station_key` and
  `signed_record`. That is the fill id, the passport id, the linked
  cylinder's name and serial (display only, ignored on import), date and
  time, O2 %, He %, pressure and temperature in the export's units (the unit
  in the header, like the other sheets), filled by (`station_name`),
  analyzer, source and notes.
- Identity: import KEEPS the fill id, unlike the other CSVs, which mint
  ids. A row whose id already exists here, or was deleted here (deletion
  log), is skipped, the same rule `TagFillImporter` applies to a fill read
  from a tag. A row without an id is a hand-added one and is given a fresh
  id.
- Linking: a fill is linked to the importing diver's cylinder that holds
  its passport id (`CylinderPassportRepository.findEquipmentIdByPassportId`
  scoped to the diver); otherwise `equipment_id` stays null and the fill
  is relinked when a cylinder gets that id. `diver_id` is the importing
  diver. `source` is kept as written (`FillSource.fromName`, unknown text
  reads as `manual`).
- Export scope: every fill the diver can see under section 10.8 (linked to
  a cylinder the diver owns or has been shared, or unlinked and logged by
  the diver), newest first.
```

- [ ] **Step 3: Amend section 17 row 5**

Replace

```markdown
| 5 CSV round trip | #2339 | fills in the Submersion CSV bundle: writer, signature, parser, round-trip test | no | 1a |
```

with

```markdown
| 5 CSV round trip | #2339 | a fourth Submersion CSV for fills (decided 2026-09-29, section 4): writer, export sheet entry, signature, format, parser, wizard Fills group, id-keeping importer, round-trip test in three unit modes | no | 1a |
```

- [ ] **Step 4: Check the file for dashes**

Run: `grep -nP '\x{2014}|\x{2013}' docs/design/specs/2026-09-25-smart-cylinder-passports-design.md | grep -n "2026-09-29" ; echo "exit $?"`
Expected: no line printed for the new paragraphs (pre-existing dashes elsewhere in the file, if any, are left alone).

- [ ] **Step 5: Commit**

```bash
git add docs/design/specs/2026-09-25-smart-cylinder-passports-design.md
git commit -m "docs(spec): cylinder passports, decide the fills CSV shape for PR 5

Refs #2339, refs #2333"
```

---

### Task 2: Codec columns, fills writer, header signature, export query

**Files:**
- Modify: `lib/core/services/export/csv/codec/csv_column.dart:18-98` (class doc and two new constants)
- Modify: `lib/core/services/export/csv/codec/submersion_csv_signatures.dart:4,61-91`
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` (imports; new method after `getForCylinder`, line 104)
- Create: `lib/core/services/export/csv/csv_fills_writer.dart`
- Modify: `test/core/services/export/csv/csv_test_fixtures.dart` (append `goldenFills`, `goldenFillEquipment`)
- Create: `test/core/services/export/csv/csv_fills_writer_test.dart`
- Create: `test/core/services/export/csv/goldens/fills_metric.csv` (generated)
- Modify: `test/core/services/export/csv/csv_metric_golden_test.dart:31-52`
- Modify: `test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`
- Modify: `test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`

**Interfaces:**
- Consumes: `CsvExportUnits` (`header`, `value`, `date`, `time`, `dateHeader`, `timeHeader`), `sanitizeCsvField`, `trimFixed` from `codec/csv_text.dart`, `CylinderFill`, `EquipmentItem`, `VisibilityFilter.equipmentVisibleTo(db, equipment, diverId)`.
- Produces:
  - `CsvColumns.fillPressure` (`'Pressure'`, pressure, 1 metric decimal) and `CsvColumns.fillTemperature` (`'Temperature'`, temperature, 1 metric decimal).
  - `SubmersionCsvKind.fills`.
  - `class CsvFillsWriter { CsvFillsWriter(CsvExportUnits units); String write(List<CylinderFill> fills, {Map<String, EquipmentItem> equipmentById = const {}}); }` writing the header `Fill ID, Passport ID, Cylinder, Serial Number, Date, Time, O2 %, He %, Pressure (unit), Temperature (unit), Filled By, Analyzer, Source, Notes` (Date and Time carry the format suffix in My units mode).
  - `Future<List<CylinderFill>> CylinderFillRepository.getAllVisibleTo(String diverId)`.
  - Fixtures `List<CylinderFill> goldenFills()` and `Map<String, EquipmentItem> goldenFillEquipment()`.

- [ ] **Step 1: Write the failing writer test**

Create `test/core/services/export/csv/csv_fills_writer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;
import 'csv_test_fixtures.dart';

/// The cylinder fills sheet (cylinder passports phase 5, issue #2339).
void main() {
  test('metric mode writes canonical values and ISO date and time', () {
    final csv = CsvFillsWriter(
      CsvExportUnits.metric,
    ).write(goldenFills(), equipmentById: goldenFillEquipment());
    expect(
      csv.split('\r\n').first,
      'Fill ID,Passport ID,Cylinder,Serial Number,Date,Time,O2 %,He %,'
      'Pressure (bar),Temperature (°C),Filled By,Analyzer,Source,Notes',
    );
    final r = rowOf(csv, 1);
    expect(r['Fill ID'], '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11');
    expect(r['Passport ID'], 'pp-al80');
    expect(r['Cylinder'], 'AL80');
    expect(r['Serial Number'], '00123');
    expect(r['Date'], '2025-03-15');
    expect(r['Time'], '09:05');
    expect(r['O2 %'], '32');
    expect(r['He %'], '0');
    expect(r['Pressure (bar)'], '206.8');
    expect(r['Temperature (°C)'], '22.0');
    expect(r['Filled By'], 'Blue Hole Dive Center');
    expect(r['Analyzer'], 'Analox O2EII');
    expect(r['Source'], 'manual');
    expect(r['Notes'], 'Topped off after analysis');

    // No linked cylinder and no temperature: empty cells, not "null".
    final unlinked = rowOf(csv, 2);
    expect(unlinked['Cylinder'], '');
    expect(unlinked['Serial Number'], '');
    expect(unlinked['He %'], '45');
    expect(unlinked['Pressure (bar)'], '180.0');
    expect(unlinked['Temperature (°C)'], '');
    expect(unlinked['Source'], 'nfc');
  });

  test('imperial My units converts pressure and temperature and names them', () {
    final csv = CsvFillsWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(goldenFills());
    final r = rowOf(csv, 1);
    expect(r['Date (MM/DD/YYYY)'], '03/15/2025');
    expect(r['Time (12-hour)'], '9:05 AM');
    expect(r['Pressure (psi)'], '3000');
    expect(r['Temperature (°F)'], '72');
    // The passport id and the analysis never change with the units.
    expect(r['Passport ID'], 'pp-al80');
    expect(r['O2 %'], '32');
  });

  test('free text is neutralised against formulas', () {
    final fill = goldenFills().first.copyWith(
      stationName: '=cmd',
      notes: '-deep',
      analyzer: '@box',
    );
    final r = rowOf(CsvFillsWriter(CsvExportUnits.metric).write([fill]), 1);
    expect(r['Filled By'], "'=cmd");
    expect(r['Notes'], "'-deep");
    expect(r['Analyzer'], "'@box");
  });
}
```

Append to `test/core/services/export/csv/csv_test_fixtures.dart` (add the import `import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';` in the package group):

```dart
/// Two fills for the fills sheet (cylinder passports phase 5): one linked to
/// the AL80 of [goldenEquipment] with every column set, one unlinked trimix
/// fill read from a tag with the optional columns empty. Wall-clock instants
/// are local, the way LogFillSheet stores them.
List<CylinderFill> goldenFills() => [
  CylinderFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    diverId: 'diver-1',
    passportId: 'pp-al80',
    equipmentId: 'e-tank',
    filledAt: DateTime(2025, 3, 15, 9, 5),
    o2Percent: 32,
    pressureBar: 206.843,
    temperatureC: 22,
    analyzer: 'Analox O2EII',
    stationName: 'Blue Hole Dive Center',
    notes: 'Topped off\nafter analysis',
    createdAt: DateTime(2025, 3, 15, 9, 6),
    updatedAt: DateTime(2025, 3, 15, 9, 6),
  ),
  CylinderFill(
    id: '8a1d4c47-9e2a-4b7d-8c9e-0f113f0c2b8e',
    diverId: 'diver-1',
    passportId: 'pp-foreign',
    filledAt: DateTime(2025, 3, 16, 14, 30),
    o2Percent: 18,
    hePercent: 45,
    pressureBar: 180,
    source: FillSource.nfc,
    createdAt: DateTime(2025, 3, 16, 14, 31),
    updatedAt: DateTime(2025, 3, 16, 14, 31),
  ),
];

/// The cylinder [goldenFills] links to, by id, for the display columns.
Map<String, EquipmentItem> goldenFillEquipment() => {
  'e-tank': goldenEquipment()[2],
};
```

- [ ] **Step 2: Run the writer test to verify it fails**

Run: `flutter test test/core/services/export/csv/csv_fills_writer_test.dart`
Expected: FAIL, compile error `Target of URI doesn't exist: 'package:submersion/core/services/export/csv/csv_fills_writer.dart'`.

- [ ] **Step 3: Add the two columns and the signature**

In `lib/core/services/export/csv/codec/csv_column.dart` change the class doc on line 18 to

```dart
/// Every unit-bearing column the dives, sites, equipment and fills exports
/// write.
```

and append inside `CsvColumns`, after `dryWeight`:

```dart

  /// Fills sheet (cylinder passports phase 5): gas pressure at the fill.
  static const fillPressure = CsvColumn(
    'Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );

  /// Fills sheet: gas temperature at the reading.
  static const fillTemperature = CsvColumn(
    'Temperature',
    CsvQuantity.temperature,
    metricDecimals: 1,
  );
```

In `lib/core/services/export/csv/codec/submersion_csv_signatures.dart`:

```dart
/// Which of Submersion's own CSV exports a file is.
enum SubmersionCsvKind { dives, sites, equipment, fills }
```

add after the `_equipment` set:

```dart

  /// Cylinder fills (cylinder passports phase 5). Shares `date`, `time`,
  /// `o2 %`, `serial number` and `notes` with the dives sheet, but the dives
  /// sheet has no `fill id` or `passport id`, and this sheet has no `dive
  /// number`, so neither can match the other.
  static const _fills = {
    'fill id',
    'passport id',
    'cylinder',
    'serial number',
    'date',
    'time',
    'o2 %',
    'he %',
    'pressure',
    'temperature',
    'filled by',
    'analyzer',
    'source',
    'notes',
  };
```

and in `match`, after the dives check:

```dart
    if (bases.containsAll(_dives)) return SubmersionCsvKind.dives;
    if (bases.containsAll(_fills)) return SubmersionCsvKind.fills;
    if (bases.containsAll(_equipment)) return SubmersionCsvKind.equipment;
    if (bases.containsAll(_sites)) return SubmersionCsvKind.sites;
```

- [ ] **Step 4: Write the writer**

Create `lib/core/services/export/csv/csv_fills_writer.dart`:

```dart
import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Writes the cylinder fills CSV (spec section 10.2, PR 5): one row per
/// fill. The fill id and passport id are the row's identity and survive a
/// re-import; the cylinder name and serial are for the reader and are
/// ignored on import. The reserved `station_key` and `signed_record`
/// columns are never written. Free-text cells go through
/// [sanitizeCsvField] so a spreadsheet never evaluates them as formulas;
/// the importer reverses it.
class CsvFillsWriter {
  CsvFillsWriter(this.units);

  final CsvExportUnits units;

  /// [equipmentById] supplies the name and serial of each fill's linked
  /// cylinder; a fill whose cylinder is unknown gets empty cells.
  String write(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
  }) {
    final rows = <List<dynamic>>[
      [
        'Fill ID',
        'Passport ID',
        'Cylinder',
        'Serial Number',
        units.dateHeader('Date'),
        units.timeHeader('Time'),
        'O2 %',
        'He %',
        units.header(CsvColumns.fillPressure),
        units.header(CsvColumns.fillTemperature),
        'Filled By',
        'Analyzer',
        'Source',
        'Notes',
      ],
    ];

    for (final fill in fills) {
      final cylinder = fill.equipmentId == null
          ? null
          : equipmentById[fill.equipmentId];
      rows.add([
        fill.id,
        sanitizeCsvField(fill.passportId),
        sanitizeCsvField(cylinder?.name),
        sanitizeCsvField(cylinder?.serialNumber),
        units.date(fill.filledAt),
        units.time(fill.filledAt),
        trimFixed(fill.o2Percent, 1),
        trimFixed(fill.hePercent, 1),
        units.value(CsvColumns.fillPressure, fill.pressureBar),
        units.value(CsvColumns.fillTemperature, fill.temperatureC),
        sanitizeCsvField(fill.stationName),
        sanitizeCsvField(fill.analyzer),
        fill.source.name,
        sanitizeCsvField(fill.notes.replaceAll('\n', ' ')),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
```

- [ ] **Step 5: Run the writer test to verify it passes**

Run: `flutter test test/core/services/export/csv/csv_fills_writer_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Extend the signature test and generate the golden**

In `test/core/services/export/csv/codec/submersion_csv_signatures_test.dart` add the import `import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';` and, inside the `for (final units in [...])` loop after the equipment test:

```dart
    test('fills export matches in $label mode', () {
      final csv = CsvFillsWriter(units).write(goldenFills());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.fills,
      );
    });
```

and after the "other apps' CSVs do not match" test:

```dart
  test('a fills export is never read as a dives export, or the reverse', () {
    // The two sheets share Date, Time, O2 %, Serial Number and Notes.
    final fills = _headers(
      CsvFillsWriter(CsvExportUnits.metric).write(goldenFills()),
    );
    expect(fills, isNot(contains('Dive Number')));
    expect(SubmersionCsvSignatures.match(fills), SubmersionCsvKind.fills);
    final dives = _headers(
      CsvDivesWriter(CsvExportUnits.metric).write(goldenDives()),
    );
    expect(dives, isNot(contains('Fill ID')));
    expect(SubmersionCsvSignatures.match(dives), SubmersionCsvKind.dives);
  });
```

In `test/core/services/export/csv/csv_metric_golden_test.dart` add the imports `import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';` and `import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';`, extend the header comment with

```dart
/// The fills golden (cylinder passports phase 5) was written by the new
/// writer on 2026-09-29; it exists so a later change to the sheet is a
/// deliberate one.
```

and add a test:

```dart
  test('fills metric export matches the golden', () {
    _check(
      'fills_metric.csv',
      CsvFillsWriter(
        CsvExportUnits.metric,
      ).write(goldenFills(), equipmentById: goldenFillEquipment()),
    );
  });
```

Generate the golden once:

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart --dart-define=WRITE_CSV_GOLDENS=true`
Expected: PASS, 4 tests; `test/core/services/export/csv/goldens/fills_metric.csv` now exists.

Run: `cat test/core/services/export/csv/goldens/fills_metric.csv`
Expected (CRLF line endings):

```
Fill ID,Passport ID,Cylinder,Serial Number,Date,Time,O2 %,He %,Pressure (bar),Temperature (°C),Filled By,Analyzer,Source,Notes
3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11,pp-al80,AL80,00123,2025-03-15,09:05,32,0,206.8,22.0,Blue Hole Dive Center,Analox O2EII,manual,Topped off after analysis
8a1d4c47-9e2a-4b7d-8c9e-0f113f0c2b8e,pp-foreign,,,2025-03-16,14:30,18,45,180.0,,,,nfc,
```

Run: `git status --short test/core/services/export/csv/goldens/`
Expected: only `?? test/core/services/export/csv/goldens/fills_metric.csv`; the three existing goldens are unchanged (Metric mode of the other sheets is untouched).

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`
Expected: PASS.

- [ ] **Step 7: Write the failing repository test**

In `test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart` append inside `main()`:

```dart
  test('getAllVisibleTo reads the diver\'s own, shared and unlinked fills, '
      'newest first', () async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd2',
            name: 'd2',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-2',
            name: 'eq-2',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d2'),
          ),
        );
    // d2 shares eq-2 with d1, so eq-2's fills are d1's to see.
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'share-1',
            equipmentId: 'eq-2',
            diverId: 'd1',
            createdAt: t,
          ),
        );
    await repo.create(fill('own', t0)); // eq-1, d1
    await repo.create(
      fill('unlinked', t0.add(const Duration(hours: 1)), equipmentId: null),
    );
    await repo.create(
      fill(
        'shared',
        t0.add(const Duration(hours: 2)),
        equipmentId: 'eq-2',
      ).copyWith(diverId: 'd2'),
    );
    await repo.create(
      fill(
        'other-unlinked',
        t0.add(const Duration(hours: 3)),
        equipmentId: null,
      ).copyWith(diverId: 'd2'),
    );

    final visible = await repo.getAllVisibleTo('d1');
    expect(visible.map((f) => f.id), ['shared', 'unlinked', 'own']);
    expect(
      (await repo.getAllVisibleTo('d2')).map((f) => f.id),
      ['other-unlinked', 'shared'],
    );
  });
```

Run: `flutter test test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`
Expected: FAIL, `The method 'getAllVisibleTo' isn't defined for the type 'CylinderFillRepository'`.

- [ ] **Step 8: Add the query**

In `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` add the import (package group, alphabetical): `import 'package:submersion/core/data/visibility/visibility_filter.dart';` and, after `getForCylinder` (before `_ownedElsewhere`):

```dart
  /// Every fill [diverId] can see, newest first, for the fills CSV (spec
  /// section 10.8): those linked to a cylinder the diver owns or has been
  /// shared, and unlinked ones the diver logged or imported.
  Future<List<CylinderFill>> getAllVisibleTo(String diverId) async {
    final eq = _db.equipment;
    final visibleEquipment = _db.selectOnly(eq)
      ..addColumns([eq.id])
      ..where(VisibilityFilter.equipmentVisibleTo(_db, eq, diverId)!);
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where(
                (t) =>
                    t.equipmentId.isInQuery(visibleEquipment) |
                    (t.equipmentId.isNull() & t.diverId.equals(diverId)),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.filledAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(_fromRow).toList();
  }
```

- [ ] **Step 9: Run the repository test to verify it passes**

Run: `flutter test test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`
Expected: PASS, every test.

- [ ] **Step 10: Format, analyze, commit**

Run: `dart format . && flutter analyze lib/core/services/export/csv lib/features/cylinder_passports test/core/services/export/csv test/features/cylinder_passports`
Expected: `No issues found!`

```bash
git add lib/core/services/export/csv/codec/csv_column.dart lib/core/services/export/csv/codec/submersion_csv_signatures.dart lib/core/services/export/csv/csv_fills_writer.dart lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart test/core/services/export/csv/csv_test_fixtures.dart test/core/services/export/csv/csv_fills_writer_test.dart test/core/services/export/csv/goldens/fills_metric.csv test/core/services/export/csv/csv_metric_golden_test.dart test/core/services/export/csv/codec/submersion_csv_signatures_test.dart test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart
git commit -m "feat(export): cylinder fills CSV writer, header signature and visible-fills query

Refs #2339"
```

---

### Task 3: Export plumbing, the CSV export sheet entry, l10n and the guide

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (imports; three methods after `saveEquipmentCsvToFile`, line 308)
- Modify: `lib/core/services/export/export_service.dart` (imports; forwarders after `saveObservationsCsvToFile`, line 208)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (imports; methods after `saveEquipmentCsvToFile`, about line 1295)
- Modify: `lib/features/transfer/presentation/widgets/csv_export_dialog.dart:8-55`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:486-519`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Modify: `docs/guide/import-export.md:83-99`
- Modify: `test/core/services/export/csv/csv_units_plumbing_test.dart`, `test/core/services/export/csv/csv_export_service_test.dart`, `test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`

**Interfaces:**
- Consumes: `CsvFillsWriter`, `CsvColumns.fillPressure`, `CylinderFillRepository.getAllVisibleTo`, `cylinderFillRepositoryProvider` (from `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`), `allEquipmentProvider`, `validatedCurrentDiverIdProvider`, `CsvExportUnits.forMode` via the existing `_csvUnits(CsvUnitMode)`.
- Produces:
  - `CsvExportService.exportFillsToCsv(List<CylinderFill>, {Map<String, EquipmentItem> equipmentById, CsvExportUnits units})`, `generateFillsCsvContent(...)`, `saveFillsCsvToFile(..., {required String dialogTitle, ...})`, and the same three on `ExportService`.
  - `ExportNotifier.exportFillsToCsv({CsvUnitMode unitMode})` and `saveFillsCsvToFile({CsvUnitMode unitMode})`.
  - `CsvExportType.fills` (between `equipment` and `observations`, `hasUnits` true).
  - l10n keys: `transfer_csvExport_typeFills`, `transfer_csvExport_descriptionFills`, `transfer_csvExport_optionFillsTitle`, `settings_export_progress_fillsCsv`, `settings_export_progress_preparingFillsCsv`, `settings_export_empty_fills`, `settings_export_success_fills`, `settings_export_saved_fillsCsv`, `settings_export_saveFillsCsvDialogTitle`.

- [ ] **Step 1: Write the failing service tests**

In `test/core/services/export/csv/csv_units_plumbing_test.dart` add, inside `generating content honours the units` after the equipment expectation:

```dart
    expect(
      header(service.generateFillsCsvContent(goldenFills(), units: units)),
      contains('Pressure (psi)'),
    );
```

and a new test after `saving equipment writes the chosen units and parts`:

```dart
  test('saving fills writes the chosen units and the cylinder name', () async {
    await service.saveFillsCsvToFile(
      goldenFills(),
      equipmentById: goldenFillEquipment(),
      dialogTitle: 'Save',
      units: units,
    );
    expect(header(saved()), contains('Temperature (°F)'));
    expect(saved(), contains('AL80'));
  });
```

In `test/core/services/export/csv/csv_export_service_test.dart`, inside the `save to file` group after the equipment cancel test (add `import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';` to the imports):

```dart
    test('saveFillsCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveFillsCsvToFile(
        <CylinderFill>[],
        dialogTitle: 'Save',
      );
      expect(result, isNull);
    });
```

Run: `flutter test test/core/services/export/csv/csv_units_plumbing_test.dart test/core/services/export/csv/csv_export_service_test.dart`
Expected: FAIL, `The method 'generateFillsCsvContent' isn't defined for the type 'ExportService'` (and the same for `saveFillsCsvToFile` on both classes).

- [ ] **Step 2: Add the service and facade methods**

In `lib/core/services/export/csv/csv_export_service.dart` add the imports (package group, keep alphabetical order within it):

```dart
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
```

Append inside the class, after `saveEquipmentCsvToFile`:

```dart

  // ==================== Cylinder fills (passports phase 5) ====================

  /// Export cylinder fills to CSV format and share via system sheet.
  /// [equipmentById] supplies the linked cylinder's name and serial.
  Future<String> exportFillsToCsv(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvData = generateFillsCsvContent(
      fills,
      equipmentById: equipmentById,
      units: units,
    );
    return saveAndShareFile(csvData, 'fills_export.csv', 'text/csv');
  }

  /// Generate CSV content for cylinder fills (without sharing).
  String generateFillsCsvContent(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvFillsWriter(units).write(fills, equipmentById: equipmentById);

  /// Save cylinder fills CSV to a user-selected location.
  Future<String?> saveFillsCsvToFile(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvContent = generateFillsCsvContent(
      fills,
      equipmentById: equipmentById,
      units: units,
    );
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'fills_export_$dateStr.csv';

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }
```

In `lib/core/services/export/export_service.dart` add the import `import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';` and, after `saveObservationsCsvToFile` (line 208):

```dart

  Future<String> exportFillsToCsv(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.exportFillsToCsv(fills, equipmentById: equipmentById, units: units);

  String generateFillsCsvContent(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.generateFillsCsvContent(
    fills,
    equipmentById: equipmentById,
    units: units,
  );

  Future<String?> saveFillsCsvToFile(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.saveFillsCsvToFile(
    fills,
    equipmentById: equipmentById,
    dialogTitle: dialogTitle,
    units: units,
  );
```

Run: `flutter test test/core/services/export/csv/csv_units_plumbing_test.dart test/core/services/export/csv/csv_export_service_test.dart`
Expected: PASS.

- [ ] **Step 3: Add the l10n strings to all 11 ARB files**

Every key below goes into every file. Place the three `transfer_csvExport_*` keys beside their `*Observations` siblings (alphabetical inside that block: `descriptionFills` after `descriptionEquipment`, `optionFillsTitle` after `optionEquipmentTitle`, `typeFills` after `typeEquipment`). Place each `settings_export_*` key on the line after its `*observations*` sibling. In `app_en.arb` only, add the `@key` description object after each key, as `diveImport_uddf_media` does.

`app_en.arb`:

```json
  "transfer_csvExport_descriptionFills": "Every fill logged on a cylinder passport, with its analysis, pressure and filler",
  "@transfer_csvExport_descriptionFills": {
    "description": "Subtitle of the cylinder fills option in the CSV export sheet"
  },
  "transfer_csvExport_optionFillsTitle": "Cylinder fills CSV",
  "@transfer_csvExport_optionFillsTitle": {
    "description": "Title of the share-or-save sheet for the cylinder fills CSV"
  },
  "transfer_csvExport_typeFills": "Cylinder fills",
  "@transfer_csvExport_typeFills": {
    "description": "Name of the cylinder fills option in the CSV export sheet"
  },
  "settings_export_progress_fillsCsv": "Exporting cylinder fills to CSV...",
  "@settings_export_progress_fillsCsv": {
    "description": "Progress message while the cylinder fills CSV is generated for sharing"
  },
  "settings_export_progress_preparingFillsCsv": "Preparing cylinder fills CSV...",
  "@settings_export_progress_preparingFillsCsv": {
    "description": "Progress message while the cylinder fills CSV is generated for saving"
  },
  "settings_export_empty_fills": "No cylinder fills to export",
  "@settings_export_empty_fills": {
    "description": "Shown when the diver has no fills to put in the CSV"
  },
  "settings_export_success_fills": "Cylinder fills exported",
  "@settings_export_success_fills": {
    "description": "Shown after the cylinder fills CSV was shared"
  },
  "settings_export_saved_fillsCsv": "Cylinder fills CSV saved",
  "@settings_export_saved_fillsCsv": {
    "description": "Shown after the cylinder fills CSV was saved to a chosen location"
  },
  "settings_export_saveFillsCsvDialogTitle": "Save Cylinder Fills CSV",
  "@settings_export_saveFillsCsvDialogTitle": {
    "description": "Title of the system save dialog for the cylinder fills CSV"
  },
```

`app_de.arb`:

```json
  "transfer_csvExport_descriptionFills": "Jede auf einem Flaschenpass protokollierte Füllung mit Analyse, Druck und Füllstation",
  "transfer_csvExport_optionFillsTitle": "CSV der Flaschenfüllungen",
  "transfer_csvExport_typeFills": "Flaschenfüllungen",
  "settings_export_progress_fillsCsv": "Flaschenfüllungen werden als CSV exportiert...",
  "settings_export_progress_preparingFillsCsv": "CSV der Flaschenfüllungen wird vorbereitet...",
  "settings_export_empty_fills": "Keine Flaschenfüllungen zum Exportieren",
  "settings_export_success_fills": "Flaschenfüllungen exportiert",
  "settings_export_saved_fillsCsv": "CSV der Flaschenfüllungen gespeichert",
  "settings_export_saveFillsCsvDialogTitle": "CSV der Flaschenfüllungen speichern",
```

`app_es.arb`:

```json
  "transfer_csvExport_descriptionFills": "Cada llenado registrado en un pasaporte de botella, con su análisis, presión y estación",
  "transfer_csvExport_optionFillsTitle": "CSV de llenados de botella",
  "transfer_csvExport_typeFills": "Llenados de botella",
  "settings_export_progress_fillsCsv": "Exportando llenados de botella a CSV...",
  "settings_export_progress_preparingFillsCsv": "Preparando CSV de llenados de botella...",
  "settings_export_empty_fills": "No hay llenados de botella para exportar",
  "settings_export_success_fills": "Llenados de botella exportados",
  "settings_export_saved_fillsCsv": "CSV de llenados de botella guardado",
  "settings_export_saveFillsCsvDialogTitle": "Guardar CSV de llenados de botella",
```

`app_fr.arb`:

```json
  "transfer_csvExport_descriptionFills": "Chaque gonflage consigné sur un passeport de bloc, avec son analyse, sa pression et sa station",
  "transfer_csvExport_optionFillsTitle": "CSV des gonflages de bloc",
  "transfer_csvExport_typeFills": "Gonflages de bloc",
  "settings_export_progress_fillsCsv": "Export des gonflages de bloc en CSV...",
  "settings_export_progress_preparingFillsCsv": "Préparation du CSV des gonflages de bloc...",
  "settings_export_empty_fills": "Aucun gonflage de bloc à exporter",
  "settings_export_success_fills": "Gonflages de bloc exportés",
  "settings_export_saved_fillsCsv": "CSV des gonflages de bloc enregistré",
  "settings_export_saveFillsCsvDialogTitle": "Enregistrer le CSV des gonflages de bloc",
```

`app_it.arb`:

```json
  "transfer_csvExport_descriptionFills": "Ogni ricarica registrata su un passaporto bombola, con analisi, pressione e stazione",
  "transfer_csvExport_optionFillsTitle": "CSV delle ricariche bombola",
  "transfer_csvExport_typeFills": "Ricariche bombola",
  "settings_export_progress_fillsCsv": "Esportazione delle ricariche bombola in CSV...",
  "settings_export_progress_preparingFillsCsv": "Preparazione del CSV delle ricariche bombola...",
  "settings_export_empty_fills": "Nessuna ricarica bombola da esportare",
  "settings_export_success_fills": "Ricariche bombola esportate",
  "settings_export_saved_fillsCsv": "CSV delle ricariche bombola salvato",
  "settings_export_saveFillsCsvDialogTitle": "Salva CSV delle ricariche bombola",
```

`app_nl.arb`:

```json
  "transfer_csvExport_descriptionFills": "Elke vulling die op een flespaspoort is gelogd, met analyse, druk en vulstation",
  "transfer_csvExport_optionFillsTitle": "CSV met flesvullingen",
  "transfer_csvExport_typeFills": "Flesvullingen",
  "settings_export_progress_fillsCsv": "Flesvullingen exporteren naar CSV...",
  "settings_export_progress_preparingFillsCsv": "CSV met flesvullingen voorbereiden...",
  "settings_export_empty_fills": "Geen flesvullingen om te exporteren",
  "settings_export_success_fills": "Flesvullingen geëxporteerd",
  "settings_export_saved_fillsCsv": "CSV met flesvullingen opgeslagen",
  "settings_export_saveFillsCsvDialogTitle": "CSV met flesvullingen opslaan",
```

`app_pt.arb`:

```json
  "transfer_csvExport_descriptionFills": "Cada enchimento registado num passaporte de garrafa, com análise, pressão e estação",
  "transfer_csvExport_optionFillsTitle": "CSV de enchimentos de garrafa",
  "transfer_csvExport_typeFills": "Enchimentos de garrafa",
  "settings_export_progress_fillsCsv": "A exportar enchimentos de garrafa para CSV...",
  "settings_export_progress_preparingFillsCsv": "A preparar CSV de enchimentos de garrafa...",
  "settings_export_empty_fills": "Sem enchimentos de garrafa para exportar",
  "settings_export_success_fills": "Enchimentos de garrafa exportados",
  "settings_export_saved_fillsCsv": "CSV de enchimentos de garrafa guardado",
  "settings_export_saveFillsCsvDialogTitle": "Guardar CSV de enchimentos de garrafa",
```

`app_hu.arb`:

```json
  "transfer_csvExport_descriptionFills": "Minden palackútlevélen naplózott töltés az elemzéssel, nyomással és a töltőállomással",
  "transfer_csvExport_optionFillsTitle": "Palacktöltések CSV",
  "transfer_csvExport_typeFills": "Palacktöltések",
  "settings_export_progress_fillsCsv": "Palacktöltések exportálása CSV-be...",
  "settings_export_progress_preparingFillsCsv": "Palacktöltések CSV előkészítése...",
  "settings_export_empty_fills": "Nincs exportálható palacktöltés",
  "settings_export_success_fills": "Palacktöltések exportálva",
  "settings_export_saved_fillsCsv": "Palacktöltések CSV mentve",
  "settings_export_saveFillsCsvDialogTitle": "Palacktöltések CSV mentése",
```

`app_ar.arb`:

```json
  "transfer_csvExport_descriptionFills": "كل تعبئة مسجلة على جواز أسطوانة، مع التحليل والضغط ومحطة التعبئة",
  "transfer_csvExport_optionFillsTitle": "CSV تعبئات الأسطوانات",
  "transfer_csvExport_typeFills": "تعبئات الأسطوانات",
  "settings_export_progress_fillsCsv": "جارٍ تصدير تعبئات الأسطوانات إلى CSV...",
  "settings_export_progress_preparingFillsCsv": "جارٍ تجهيز CSV تعبئات الأسطوانات...",
  "settings_export_empty_fills": "لا تعبئات أسطوانات للتصدير",
  "settings_export_success_fills": "تم تصدير تعبئات الأسطوانات",
  "settings_export_saved_fillsCsv": "تم حفظ CSV تعبئات الأسطوانات",
  "settings_export_saveFillsCsvDialogTitle": "حفظ CSV تعبئات الأسطوانات",
```

`app_he.arb`:

```json
  "transfer_csvExport_descriptionFills": "כל מילוי שנרשם בדרכון מכל, עם הניתוח, הלחץ ותחנת המילוי",
  "transfer_csvExport_optionFillsTitle": "CSV מילויי מכלים",
  "transfer_csvExport_typeFills": "מילויי מכלים",
  "settings_export_progress_fillsCsv": "מייצא מילויי מכלים ל-CSV...",
  "settings_export_progress_preparingFillsCsv": "מכין CSV מילויי מכלים...",
  "settings_export_empty_fills": "אין מילויי מכלים לייצוא",
  "settings_export_success_fills": "מילויי המכלים יוצאו",
  "settings_export_saved_fillsCsv": "CSV מילויי המכלים נשמר",
  "settings_export_saveFillsCsvDialogTitle": "שמירת CSV מילויי מכלים",
```

`app_zh.arb`:

```json
  "transfer_csvExport_descriptionFills": "气瓶护照上记录的每次充气，含气体分析、压力和充气站",
  "transfer_csvExport_optionFillsTitle": "气瓶充气记录 CSV",
  "transfer_csvExport_typeFills": "气瓶充气记录",
  "settings_export_progress_fillsCsv": "正在将气瓶充气记录导出为 CSV...",
  "settings_export_progress_preparingFillsCsv": "正在准备气瓶充气记录 CSV...",
  "settings_export_empty_fills": "没有可导出的气瓶充气记录",
  "settings_export_success_fills": "气瓶充气记录已导出",
  "settings_export_saved_fillsCsv": "气瓶充气记录 CSV 已保存",
  "settings_export_saveFillsCsvDialogTitle": "保存气瓶充气记录 CSV",
```

Run: `flutter gen-l10n && flutter test test/l10n`
Expected: PASS (parity, no duplicate keys, diacritics twin scan).

- [ ] **Step 4: Write the failing dialog test**

In `test/features/transfer/presentation/widgets/csv_export_dialog_test.dart` change the comment on lines 11-12 to `// The sheet lists five data types plus the unit choice; the default test` and the surface to `const Size(800, 1500)`. Append a test:

```dart
  testWidgets('cylinder fills keep the unit choice and are returned', (
    tester,
  ) async {
    final result = await _open(tester);
    await tester.tap(find.text('Cylinder fills'));
    await tester.pumpAndSettle();
    expect(find.text('My units'), findsOneWidget);
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
    expect(result(), (
      type: CsvExportType.fills,
      unitMode: CsvUnitMode.myUnits,
    ));
  });
```

Run: `flutter test test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`
Expected: FAIL, `Member not found: 'fills'`.

- [ ] **Step 5: Add the sheet entry and the notifier methods**

In `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`:

```dart
/// The type of CSV data to export.
enum CsvExportType {
  dives,
  sites,
  equipment,
  fills,
  observations;

  String localizedDisplayName(BuildContext context) {
    switch (this) {
      case CsvExportType.dives:
        return context.l10n.transfer_csvExport_typeDives;
      case CsvExportType.sites:
        return context.l10n.transfer_csvExport_typeSites;
      case CsvExportType.equipment:
        return context.l10n.transfer_csvExport_typeEquipment;
      case CsvExportType.fills:
        return context.l10n.transfer_csvExport_typeFills;
      case CsvExportType.observations:
        return context.l10n.transfer_csvExport_typeObservations;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case CsvExportType.dives:
        return context.l10n.transfer_csvExport_descriptionDives;
      case CsvExportType.sites:
        return context.l10n.transfer_csvExport_descriptionSites;
      case CsvExportType.equipment:
        return context.l10n.transfer_csvExport_descriptionEquipment;
      case CsvExportType.fills:
        return context.l10n.transfer_csvExport_descriptionFills;
      case CsvExportType.observations:
        return context.l10n.transfer_csvExport_descriptionObservations;
    }
  }

  IconData get icon {
    switch (this) {
      case CsvExportType.dives:
        return Icons.table_chart;
      case CsvExportType.sites:
        return Icons.location_on;
      case CsvExportType.equipment:
        return Icons.build;
      case CsvExportType.fills:
        return Icons.propane_tank_outlined;
      case CsvExportType.observations:
        return Icons.fact_check;
    }
  }
```

(`hasUnits` is unchanged: fills have unit-bearing columns.)

In `lib/features/transfer/presentation/pages/transfer_page.dart`, in `_handleCsvExport` after the `equipment` case:

```dart
      case CsvExportType.fills:
        await _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionFillsTitle,
          shareAction: (_) => notifier.exportFillsToCsv(unitMode: mode),
          saveAction: (_) => notifier.saveFillsCsvToFile(unitMode: mode),
        );
```

In `lib/features/settings/presentation/providers/export_providers.dart` add the imports

```dart
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
```

and, after `saveEquipmentCsvToFile` (before the `// ==================== UDDF SAVE TO FILE` banner):

```dart

  // ==================== CYLINDER FILLS CSV ====================

  /// The active diver's fills and the cylinders they link to, for the
  /// fills CSV (cylinder passports phase 5). Scoped through the validated
  /// diver id like the check-ins: a shared cylinder's fills come along and
  /// another diver's unlinked fills do not (spec section 10.8).
  Future<({List<CylinderFill> fills, Map<String, EquipmentItem> equipmentById})>
  _fillRows() async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) {
      return (fills: const <CylinderFill>[], equipmentById: const {});
    }
    final fills = await _ref
        .read(cylinderFillRepositoryProvider)
        .getAllVisibleTo(diverId);
    final equipment = await _ref.read(allEquipmentProvider.future);
    return (fills: fills, equipmentById: {for (final e in equipment) e.id: e});
  }

  Future<void> exportFillsToCsv({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_fillsCsv,
    );
    try {
      final rows = await _fillRows();
      if (rows.fills.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_fills,
        );
        return;
      }
      final path = await _exportService.exportFillsToCsv(
        rows.fills,
        equipmentById: rows.equipmentById,
        units: _csvUnits(unitMode),
      );
      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_success_fills,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_data_export_failed('$e'),
      );
    }
  }

  /// Save cylinder fills CSV to a user-selected location.
  Future<void> saveFillsCsvToFile({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      message: _l10n.settings_export_progress_preparingFillsCsv,
    );
    try {
      final rows = await _fillRows();
      if (rows.fills.isEmpty) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: _l10n.settings_export_empty_fills,
        );
        return;
      }

      state = state.copyWith(
        message: _l10n.settings_export_progress_chooseLocation,
      );
      final path = await _exportService.saveFillsCsvToFile(
        rows.fills,
        equipmentById: rows.equipmentById,
        dialogTitle: _l10n.settings_export_saveFillsCsvDialogTitle,
        units: _csvUnits(unitMode),
      );

      if (path == null) {
        state = state.copyWith(
          status: ExportStatus.idle,
          message: _l10n.settings_export_cancelled_save,
        );
        return;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        message: _l10n.settings_export_saved_fillsCsv,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: _l10n.settings_export_saveFailed('$e'),
      );
    }
  }
```

Run: `flutter test test/features/transfer/presentation/widgets/csv_export_dialog_test.dart test/features/transfer`
Expected: PASS.

- [ ] **Step 6: Update the guide**

In `docs/guide/import-export.md`, replace the block

```markdown
Exported CSV includes:

- All standard dive fields
- Tank information
- Site details
- Equipment links
```

with

```markdown
The Export CSV sheet offers five files: dives, sites, equipment, cylinder
fills and gear check-ins. Each unit-bearing file can be written in your
units (named in every column header) or in metric with ISO dates.

The dives CSV includes:

- All standard dive fields
- Tank information
- Site details
- Equipment links

The dives, sites, equipment and cylinder fills files are self-describing:
the import wizard recognises each by its headers and re-imports it without
column mapping, alone or together with the others. A cylinder fills file
carries each fill's id, so importing it twice adds nothing, and a fill you
deleted stays deleted. A fill whose passport id matches one of your
cylinders lands on that cylinder; any other fill waits under its passport
id until a cylinder gets that id.
```

- [ ] **Step 7: Format, analyze, run the export tests, commit**

Run: `dart format . && flutter analyze && flutter test test/core/services/export/csv test/features/transfer test/features/settings/presentation/providers test/l10n`
Expected: `No issues found!` and every test PASS.

```bash
git add lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/export_service.dart lib/features/settings/presentation/providers/export_providers.dart lib/features/transfer/presentation/widgets/csv_export_dialog.dart lib/features/transfer/presentation/pages/transfer_page.dart lib/l10n docs/guide/import-export.md test/core/services/export/csv/csv_units_plumbing_test.dart test/core/services/export/csv/csv_export_service_test.dart test/features/transfer/presentation/widgets/csv_export_dialog_test.dart
git commit -m "feat(export): cylinder fills entry in the CSV export sheet

Refs #2339"
```

---

### Task 4: Import format, entity type, detector and parser

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart:6-8,33-37,62-77,158-274,314-360`
- Modify: `lib/features/universal_import/data/services/format_detector.dart:317-327`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Modify: `lib/features/universal_import/data/services/payload_merger.dart:520-552` (`_foldKey` switch)
- Create: `lib/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart`
- Modify: `test/features/universal_import/data/models/import_enums_test.dart`
- Modify: `test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`
- Create: `test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart`
- Modify: `test/features/universal_import/data/parsers/submersion_csv/submersion_csv_parser_warnings_test.dart`

**Interfaces:**
- Consumes: `SubmersionCsvKind.fills`, `CsvColumns.fillPressure`, `CsvColumns.fillTemperature`, `SubmersionCsvTable` (`text`, `number`, `quantity`, `date`, `time`, `cellWarnings`, `unreadableUnitColumns`, `sourceRowOf`), `CsvFillsWriter` and fixtures in tests.
- Produces:
  - `ImportFormat.submersionFillsCsv` (displayName `'Submersion Fills CSV'`, `isSupported` true), `SourceOverrideOption` `'Submersion (Fills CSV)'`.
  - Universal `ImportEntityType.fills` (displayName `'Fills'`, shortName `'Fills'`).
  - `SubmersionFillsCsvParser` emitting `ImportEntityType.fills` items with keys `uddfId` (the fill id; the batch merger prefixes this one), `id` (the fill id, never prefixed), `passportId`, `filledAt` (local `DateTime`), `o2Percent`, `hePercent` (0 when blank), `pressureBar`, `temperatureC`, `stationName`, `analyzer`, `source` (lower-cased text), `notes`; null values removed.

- [ ] **Step 1: Write the failing enum and detector tests**

In `test/features/universal_import/data/models/import_enums_test.dart`:

- `ImportFormat` `has all expected values`: `hasLength(21)`.
- In `displayName for each format`, after the equipment line: `expect(ImportFormat.submersionFillsCsv.displayName, 'Submersion Fills CSV');`
- In the `isSupported returns true ...` test: `expect(ImportFormat.submersionFillsCsv.isSupported, isTrue);`
- `ImportEntityType` `has all expected values`: `hasLength(14)`; in `displayName for each entity type`: `expect(ImportEntityType.fills.displayName, 'Fills');`; in `shortName ...`: `expect(ImportEntityType.fills.shortName, 'Fills');`
- `SourceOverrideOption` `contains expected number of entries`: `expect(SourceOverrideOption.supported.length, 24);` and a new test:

```dart
      test('contains Submersion Fills CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.submersion &&
              o.format == ImportFormat.submersionFillsCsv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Submersion (Fills CSV)');
      });
```

In `test/features/universal_import/data/services/format_detector_submersion_csv_test.dart` add `import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';` and, inside the loop test after the equipment expectation:

```dart
      expect(
        detector
            .detect(_bytes(CsvFillsWriter(units).write(goldenFills())))
            .format,
        ImportFormat.submersionFillsCsv,
      );
```

Run: `flutter test test/features/universal_import/data/models/import_enums_test.dart test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`
Expected: FAIL, `Member not found: 'submersionFillsCsv'`.

- [ ] **Step 2: Add the format, the entity type, the override option, the detector arm and the merger case**

In `lib/features/universal_import/data/models/import_enums.dart`:

- `ImportFormat`: after `submersionEquipmentCsv,` add `submersionFillsCsv,`; in `displayName` after the equipment arm add `submersionFillsCsv => 'Submersion Fills CSV',`; in `isSupported` add `submersionFillsCsv ||` after `submersionEquipmentCsv ||`.
- `SourceOverrideOption.supported`: after the `Submersion (Equipment CSV)` entry add

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.submersion,
      format: ImportFormat.submersionFillsCsv,
      displayName: 'Submersion (Fills CSV)',
    ),
```

- `ImportEntityType`: after `media` add

```dart
  media,

  /// Cylinder fills from the fills CSV (cylinder passports phase 5). Keyed
  /// by passport id, never by an imported item.
  fills;
```

with `fills => 'Fills',` in both `displayName` and `shortName`.

In `lib/features/universal_import/data/services/format_detector.dart`, in the `switch (kind)` add `SubmersionCsvKind.fills => ImportFormat.submersionFillsCsv,`.

In `lib/features/universal_import/data/services/payload_merger.dart`, `_foldKey`: fills are events like service records and never fold across files. Add the case to the `return null` group:

```dart
      case ImportEntityType.dives:
      // Service records are events, not named entities: two services on the
      // same item are both real and must never fold together.
      case ImportEntityType.serviceRecords:
      // Media is handled before this point and has no name to fold on.
      case ImportEntityType.media:
      // A fill carries its own id and the importer skips one already here,
      // so two files holding the same fill import it once without folding.
      case ImportEntityType.fills:
        return null;
```

Run: `flutter analyze lib/features/universal_import`
Expected: `No issues found!` (every switch over the universal enum compiles).

- [ ] **Step 3: Write the failing parser test**

Create `test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// The fills CSV parser (cylinder passports phase 5, issue #2339).
void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionFillsCsv),
      isA<SubmersionFillsCsvParser>(),
    );
  });

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    test(
      'reads every column back (${units.isMetric ? 'metric' : 'my units'})',
      () async {
        final csv = CsvFillsWriter(
          units,
        ).write(goldenFills(), equipmentById: goldenFillEquipment());
        final payload = await const SubmersionFillsCsvParser().parse(
          _bytes(csv),
        );
        expect(payload.warnings, isEmpty);
        final items = payload.entitiesOf(ImportEntityType.fills);
        expect(items, hasLength(2));

        final first = items.first;
        final want = goldenFills().first;
        expect(first['id'], want.id);
        expect(first['uddfId'], want.id);
        expect(first['passportId'], 'pp-al80');
        // A wall clock, stored local like the equipment dates.
        expect(first['filledAt'], DateTime(2025, 3, 15, 9, 5));
        expect(first['o2Percent'], 32.0);
        expect(first['hePercent'], 0.0);
        expect(first['pressureBar'] as double, closeTo(206.843, 0.06));
        expect(first['temperatureC'] as double, closeTo(22.0, 0.6));
        expect(first['stationName'], 'Blue Hole Dive Center');
        expect(first['analyzer'], 'Analox O2EII');
        expect(first['source'], 'manual');
        expect(first['notes'], 'Topped off after analysis');
        // Display columns are not read back.
        expect(first.containsKey('cylinderName'), isFalse);
        expect(first.containsKey('serialNumber'), isFalse);

        final second = items[1];
        expect(second['passportId'], 'pp-foreign');
        expect(second['hePercent'], 45.0);
        expect(second['pressureBar'] as double, closeTo(180, 0.06));
        expect(second.containsKey('temperatureC'), isFalse);
        expect(second.containsKey('stationName'), isFalse);
        expect(second['source'], 'nfc');
      },
    );
  }

  test('a row without a passport id, date or O2 is skipped with an error', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    // Row 2: blank passport id. Row 3: unreadable O2.
    lines[1] = lines[1].replaceFirst(',pp-al80,', ',,');
    lines[2] = lines[2].replaceFirst(',18,45,', ',eighteen,45,');
    final payload = await const SubmersionFillsCsvParser().parse(
      _bytes(lines.join('\r\n')),
    );
    expect(payload.entitiesOf(ImportEntityType.fills), isEmpty);
    final errors = payload.warnings
        .where((w) => w.severity == ImportWarningSeverity.error)
        .toList();
    expect(errors, hasLength(2));
    expect(errors[0].message, 'Row 2 has no passport id and was skipped');
    expect(errors[0].field, 'Passport ID');
    expect(errors[1].message, 'Row 3 has no readable O2 % and was skipped');
    expect(errors[1].field, 'O2 %');
  });

  test('a blank fill id is minted, so a hand-added row imports', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    lines[1] = lines[1].replaceFirst(
      '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11,',
      ',',
    );
    final payload = await const SubmersionFillsCsvParser().parse(
      _bytes(lines.join('\r\n')),
    );
    final items = payload.entitiesOf(ImportEntityType.fills);
    expect(items, hasLength(2));
    final minted = items.first['id'] as String;
    expect(minted, isNotEmpty);
    expect(minted, isNot(goldenFills().first.id));
    expect(items.first['uddfId'], minted);
    expect(payload.warnings, isEmpty);
  });

  test('an unknown source reads as manual downstream and a blank He is 0', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    lines[2] = lines[2].replaceFirst(',18,45,', ',18,,').replaceFirst(',nfc,', ',Teleport,');
    final payload = await const SubmersionFillsCsvParser().parse(
      _bytes(lines.join('\r\n')),
    );
    final second = payload.entitiesOf(ImportEntityType.fills)[1];
    expect(second['hePercent'], 0.0);
    // The parser keeps the text; FillSource.fromName maps it to manual.
    expect(second['source'], 'teleport');
  });
}
```

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart`
Expected: FAIL, compile error on the missing parser file.

- [ ] **Step 4: Write the parser and register it**

Create `lib/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart`:

```dart
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's cylinder fills CSV (either unit mode) back into fill
/// maps (cylinder passports phase 5). Each row keeps its fill id, which the
/// importer uses to skip a fill already here or deleted here; a hand-added
/// row without one is given a fresh id. The cylinder name and serial are
/// display columns and are not read.
///
/// The id is emitted twice: under `uddfId`, which the batch merger prefixes
/// with the file id like every other entity, and under `id`, which stays
/// as written so the stored row keeps the exported id.
class SubmersionFillsCsvParser implements ImportParser {
  const SubmersionFillsCsvParser();

  static const _uuid = Uuid();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionFillsCsv,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.fillPressure,
        CsvColumns.fillTemperature,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.diagnostic,
          message:
              'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.fills,
        ),
    ];
    final items = <Map<String, dynamic>>[];

    for (final (i, row) in table.rows.indexed) {
      final passportId = table.text(row, 'Passport ID');
      final date = table.date(row, 'Date');
      final o2 = table.number(row, 'O2 %');
      final (missing, field) = passportId == null
          ? ('passport id', 'Passport ID')
          : date == null
          ? ('readable date', 'Date')
          : o2 == null
          ? ('readable O2 %', 'O2 %')
          : (null, null);
      if (missing != null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Row ${table.sourceRowOf(i)} has no $missing and was skipped',
            entityType: ImportEntityType.fills,
            itemIndex: i,
            field: field,
          ),
        );
        continue;
      }

      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.fills,
          numbers: const ['He %', 'Pressure', 'Temperature'],
          times: const ['Time'],
        ),
      );
      final time = table.time(row, 'Time');
      final id = table.text(row, 'Fill ID') ?? _uuid.v4();

      items.add(
        <String, dynamic>{
          'uddfId': id,
          'id': id,
          'passportId': passportId,
          // A fill time is a wall clock stored as a local instant, the way
          // LogFillSheet stores it and the equipment dates come back; not
          // UTC-flagged like a dive.
          'filledAt': DateTime(
            date!.year,
            date.month,
            date.day,
            time?.hour ?? 0,
            time?.minute ?? 0,
          ),
          'o2Percent': o2,
          'hePercent': table.number(row, 'He %') ?? 0.0,
          'pressureBar': table.quantity(row, CsvColumns.fillPressure),
          'temperatureC': table.quantity(row, CsvColumns.fillTemperature),
          'stationName': table.text(row, 'Filled By'),
          'analyzer': table.text(row, 'Analyzer'),
          'source': table.text(row, 'Source')?.toLowerCase(),
          'notes': table.text(row, 'Notes'),
        }..removeWhere((_, value) => value == null),
      );
    }

    return ImportPayload(
      entities: {if (items.isNotEmpty) ImportEntityType.fills: items},
      warnings: warnings,
    );
  }
}
```

In `lib/features/universal_import/data/parsers/parser_registry.dart` add the import `import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart';` (keep the import block alphabetical: after `submersion_equipment_csv_parser.dart`) and the arm

```dart
    ImportFormat.submersionFillsCsv => const SubmersionFillsCsvParser(),
```

after the equipment arm.

- [ ] **Step 5: Run the parser, enum and detector tests**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart test/features/universal_import/data/models/import_enums_test.dart test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`
Expected: PASS.

- [ ] **Step 6: Extend the warnings test**

In `test/features/universal_import/data/parsers/submersion_csv/submersion_csv_parser_warnings_test.dart` add the imports `import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';` and `import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart';`, extend `each parser declares its own format` with

```dart
    expect(const SubmersionFillsCsvParser().supportedFormats, [
      ImportFormat.submersionFillsCsv,
    ]);
```

and add a test:

```dart
  test('a unit a column cannot hold is reported once, for fills', () async {
    final csv = CsvFillsWriter(
      CsvExportUnits.metric,
    ).write(goldenFills()).replaceFirst('Pressure (bar)', 'Pressure (m)');
    final payload = await const SubmersionFillsCsvParser().parse(_bytes(csv));
    final unitWarnings = payload.warnings.where(
      (w) => w.message.contains('Pressure (m)') && w.itemIndex == null,
    );
    expect(unitWarnings, hasLength(1));
    expect(
      payload
          .entitiesOf(ImportEntityType.fills)
          .first
          .containsKey('pressureBar'),
      isFalse,
    );
  });
```

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_csv_parser_warnings_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

Run: `dart format . && flutter analyze && flutter test test/features/universal_import`
Expected: `No issues found!`, every test PASS.

```bash
git add lib/features/universal_import/data/models/import_enums.dart lib/features/universal_import/data/services/format_detector.dart lib/features/universal_import/data/parsers/parser_registry.dart lib/features/universal_import/data/services/payload_merger.dart lib/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart test/features/universal_import/data/models/import_enums_test.dart test/features/universal_import/data/services/format_detector_submersion_csv_test.dart test/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser_test.dart test/features/universal_import/data/parsers/submersion_csv/submersion_csv_parser_warnings_test.dart
git commit -m "feat(import): detect and parse the Submersion fills CSV

Refs #2339"
```

---

### Task 5: Fills through the wizard: entity group, id-keeping importer, passport linking

**Files:**
- Create: `lib/features/cylinder_passports/data/services/csv_fill_importer.dart`
- Create: `test/features/cylinder_passports/data/services/csv_fill_importer_test.dart`
- Modify: `lib/core/services/export/models/uddf_import_result.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:80-160` (`ImportRepositories`), `164-215` (`UddfImportSelections`), `219-275` (`UddfEntityImportResult`), `import()` after the `_importServiceRecords` call (about line 463), and the result construction (about line 633)
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart:33-70`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`buildBundle` after the media group, `_runImporter` selections, `_convertImportCounts`, `payloadToUddfResult`, `universalImportRepositories`, a new `_fillToEntityItem`)
- Modify: `lib/features/import_wizard/data/services/import_provider_invalidator.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart:310-337`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart:369-425`
- Modify: `lib/features/universal_import/data/services/payload_diver_expander.dart:120-135`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`diveImport_uddf_fills`)
- Modify: `test/features/import_wizard/domain/models/import_bundle_test.dart:23-24`, `test/features/import_wizard/data/services/import_provider_invalidator_test.dart`, `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`, `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart:39-57`
- Create: `test/features/import_wizard/data/adapters/universal_adapter_fills_csv_test.dart`

**Interfaces:**
- Consumes: parser items from Task 4 (`id`, `passportId`, `filledAt`, `o2Percent`, `hePercent`, `pressureBar`, `temperatureC`, `stationName`, `analyzer`, `source`, `notes`), `CylinderFillRepository.getById/wasDeleted/create`, `CylinderPassportRepository.findEquipmentIdByPassportId(passportId, diverId:)`, `cylinderFillRepositoryProvider`, `cylinderPassportRepositoryProvider`, `fillsForEquipmentProvider`, `newestFillProvider`.
- Produces:
  - `class CsvFillImporter { CsvFillImporter({CylinderFillRepository? fills, CylinderPassportRepository? passports}); Future<int> importRows(List<Map<String, dynamic>> items, {required Set<int> selected, required String diverId}); Future<CylinderFill?> importIfNew(CylinderFill fill, {required String diverId}); static CylinderFill? fromPayload(Map<String, dynamic> data); }`
  - `UddfImportResult.fills`, `UddfImportSelections.fills`, `UddfEntityImportResult.fills`.
  - `ImportRepositories.cylinderFillRepository` and `.cylinderPassportRepository` (both optional; both supplied by `universalImportRepositories`).
  - Wizard `ImportEntityType.fills`; l10n `diveImport_uddf_fills` (`"Fills"`).

- [ ] **Step 1: Write the failing `CsvFillImporter` test**

Create `test/features/cylinder_passports/data/services/csv_fill_importer_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/csv_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

import '../../../../helpers/test_database.dart';

/// The CSV twin of TagFillImporter (cylinder passports phase 5): a fill
/// row keeps its id, imports once, and links to the cylinder holding its
/// passport id.
void main() {
  late AppDatabase db;
  late CylinderFillRepository fills;
  late CsvFillImporter importer;
  const fillId = '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11';

  Map<String, dynamic> row({String id = fillId, String passportId = 'pp-1'}) =>
      <String, dynamic>{
        'uddfId': 'f0:$id',
        'id': id,
        'passportId': passportId,
        'filledAt': DateTime(2026, 9, 28, 9, 30),
        'o2Percent': 32.0,
        'hePercent': 0.0,
        'pressureBar': 232.0,
        'stationName': 'Blue Hole',
        'source': 'qr',
        'notes': 'from the sheet',
      };

  setUp(() async {
    db = await setUpTestDatabase();
    fills = CylinderFillRepository();
    importer = CsvFillImporter();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tank-1',
            name: 'Faber 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-1',
      diverId: 'd1',
    );
  });
  tearDown(tearDownTestDatabase);

  test('a new fill keeps its id, is stamped with the diver and links to '
      'the cylinder holding its passport id', () async {
    final count = await importer.importRows(
      [row()],
      selected: {0},
      diverId: 'd1',
    );
    expect(count, 1);
    final stored = (await fills.getById(fillId))!;
    expect(stored.id, fillId);
    expect(stored.diverId, 'd1');
    expect(stored.passportId, 'pp-1');
    expect(stored.equipmentId, 'tank-1');
    expect(stored.filledAt, DateTime(2026, 9, 28, 9, 30));
    expect(stored.o2Percent, 32);
    expect(stored.pressureBar, 232);
    expect(stored.stationName, 'Blue Hole');
    // The source is kept as written, not rewritten to "file".
    expect(stored.source, FillSource.qr);
    expect(stored.notes, 'from the sheet');
  });

  test('a fill with no matching cylinder stays unlinked under its passport '
      'id', () async {
    await importer.importRows(
      [row(passportId: 'pp-unknown')],
      selected: {0},
      diverId: 'd1',
    );
    final stored = (await fills.getById(fillId))!;
    expect(stored.equipmentId, isNull);
    expect(stored.passportId, 'pp-unknown');
    expect(stored.diverId, 'd1');
  });

  test('a fill already here is skipped, so the same rows import once', () async {
    expect(await importer.importRows([row()], selected: {0}, diverId: 'd1'), 1);
    expect(await importer.importRows([row()], selected: {0}, diverId: 'd1'), 0);
    expect(
      (await fills.getForCylinder(passportId: 'pp-1', equipmentId: 'tank-1'))
          .map((f) => f.id),
      [fillId],
    );
  });

  test('a fill deleted here is not brought back', () async {
    await importer.importRows([row()], selected: {0}, diverId: 'd1');
    await fills.delete(fillId);
    expect(await importer.importRows([row()], selected: {0}, diverId: 'd1'), 0);
    expect(await fills.getById(fillId), isNull);
  });

  test('unselected and unreadable rows are skipped and never fatal', () async {
    final count = await importer.importRows(
      [
        row(),
        row(id: 'second')..remove('o2Percent'),
        row(id: 'third'),
      ],
      selected: {0, 1},
      diverId: 'd1',
    );
    expect(count, 1);
    expect(await fills.getById('second'), isNull);
    expect(await fills.getById('third'), isNull, reason: 'not selected');
  });

  test('fromPayload reads an unknown source as manual and a missing He as 0',
      () {
    final fill = CsvFillImporter.fromPayload(
      row()
        ..['source'] = 'teleport'
        ..remove('hePercent'),
    )!;
    expect(fill.source, FillSource.manual);
    expect(fill.hePercent, 0);
    expect(fill.equipmentId, isNull);
  });
}
```

Run: `flutter test test/features/cylinder_passports/data/services/csv_fill_importer_test.dart`
Expected: FAIL, compile error on the missing importer file.

- [ ] **Step 2: Write `CsvFillImporter`**

Create `lib/features/cylinder_passports/data/services/csv_fill_importer.dart`:

```dart
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Stores the rows of a Submersion fills CSV (spec section 10.2, PR 5).
///
/// Each row keeps its fill id, so a file imports once: a fill already here,
/// or one the diver deleted (the deletion log), adds nothing, the rule
/// TagFillImporter applies to a fill read from a tag. A fill is linked to
/// the importing diver's cylinder that holds its passport id when there is
/// one; otherwise it stays under the passport id alone and is relinked when
/// a cylinder gets that id (Link an existing tag, Add to my gear).
class CsvFillImporter {
  CsvFillImporter({
    CylinderFillRepository? fills,
    CylinderPassportRepository? passports,
  }) : _fills = fills ?? CylinderFillRepository(),
       _passports = passports ?? CylinderPassportRepository();

  final CylinderFillRepository _fills;
  final CylinderPassportRepository _passports;

  /// Stores the rows of [items] at the indices in [selected] for [diverId]
  /// and returns how many were created. A row that cannot be read or
  /// stored is skipped; one bad row never aborts the import.
  Future<int> importRows(
    List<Map<String, dynamic>> items, {
    required Set<int> selected,
    required String diverId,
  }) async {
    var count = 0;
    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final fill = fromPayload(items[i]);
      if (fill == null) continue;
      try {
        if (await importIfNew(fill, diverId: diverId) != null) count++;
      } catch (_) {
        // One bad row must not abort the import.
      }
    }
    return count;
  }

  /// The stored fill, or null when [fill] is already here or was deleted.
  Future<CylinderFill?> importIfNew(
    CylinderFill fill, {
    required String diverId,
  }) async {
    if (await _fills.getById(fill.id) != null) return null;
    if (await _fills.wasDeleted(fill.id)) return null;
    final equipmentId = await _passports.findEquipmentIdByPassportId(
      fill.passportId,
      diverId: diverId,
    );
    final now = DateTime.now();
    return _fills.create(
      fill.copyWith(
        diverId: diverId,
        equipmentId: equipmentId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// A fill from a SubmersionFillsCsvParser row, unlinked and without a
  /// diver, or null when the row lacks an id, a passport id, a time or an
  /// O2 reading.
  static CylinderFill? fromPayload(Map<String, dynamic> data) {
    final id = data['id'];
    final passportId = data['passportId'];
    final filledAt = data['filledAt'];
    final o2 = data['o2Percent'];
    if (id is! String ||
        id.isEmpty ||
        passportId is! String ||
        passportId.isEmpty ||
        filledAt is! DateTime ||
        o2 is! num) {
      return null;
    }
    final now = DateTime.now();
    return CylinderFill(
      id: id,
      passportId: passportId,
      filledAt: filledAt,
      o2Percent: o2.toDouble(),
      hePercent: (data['hePercent'] as num?)?.toDouble() ?? 0,
      pressureBar: (data['pressureBar'] as num?)?.toDouble(),
      temperatureC: (data['temperatureC'] as num?)?.toDouble(),
      analyzer: data['analyzer'] as String?,
      stationName: data['stationName'] as String?,
      source: FillSource.fromName(data['source'] as String?),
      notes: data['notes'] as String? ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }
}
```

Run: `flutter test test/features/cylinder_passports/data/services/csv_fill_importer_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 3: Write the failing wizard-enum, invalidator and repositories tests**

In `test/features/import_wizard/domain/models/import_bundle_test.dart` change `has all 12 expected values` to `has all 13 expected values`, `hasLength(13)`, and add `expect(ImportEntityType.values, contains(ImportEntityType.fills));`.

In `test/features/import_wizard/data/services/import_provider_invalidator_test.dart` (it records the real `invalidateImportRelatedProviders` through `List<Object> _record(Set<ImportEntityType> types)`; there is no mirror to edit) add the import `import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';` and, inside the `invalidateImportRelatedProviders` group after the `media invalidates the per-dive media providers` test:

```dart

    test('fills invalidate the passport fill providers', () {
      // A passport page may be showing the cylinder the fills landed on.
      final recorded = _record({ImportEntityType.fills});
      expect(recorded, contains(fillsForEquipmentProvider));
      expect(recorded, contains(newestFillProvider));
    });
```

The existing `every ImportEntityType maps to at least one provider` test also fails until the case exists.

In `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart` add after the site feature expectation:

```dart
    // Without these every fill in a fills CSV is skipped (cylinder
    // passports phase 5).
    expect(repos!.cylinderFillRepository, isNotNull);
    expect(repos!.cylinderPassportRepository, isNotNull);
```

Run: `flutter test test/features/import_wizard/domain/models/import_bundle_test.dart test/features/import_wizard/data/services/import_provider_invalidator_test.dart test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`
Expected: FAIL, `Member not found: 'fills'` and `The getter 'cylinderFillRepository' isn't defined`.

- [ ] **Step 4: Add the wizard entity type and its four switch cases**

In `lib/features/import_wizard/domain/models/import_bundle.dart` after `media,`:

```dart
  /// Photos referenced by an imported logbook.
  media,

  /// Cylinder fills from the Submersion fills CSV (passports phase 5).
  fills,
```

In `lib/features/import_wizard/data/services/import_provider_invalidator.dart` add the import `import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';` and after the `media` case:

```dart

      case ImportEntityType.fills:
        // A passport page may be showing the cylinder the fills landed on.
        invalidate(fillsForEquipmentProvider);
        invalidate(newestFillProvider);
```

In `lib/features/import_wizard/presentation/widgets/review_step.dart`, `_typeDisplayName`, after the `media` case:

```dart
      case ImportEntityType.fills:
        return l10n.diveImport_uddf_fills;
```

In `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`, `_iconForType` after the `media` case:

```dart
      case ImportEntityType.fills:
        return Icons.propane_tank_outlined;
```

and `_labelForType` after the `media` case:

```dart
      case ImportEntityType.fills:
        return l10n.diveImport_uddf_fills;
```

Add `diveImport_uddf_fills` to every ARB, on the line after `diveImport_uddf_media` (en gets a `@` description):

| file | value |
| --- | --- |
| en | `"Fills"` with `"@diveImport_uddf_fills": {"description": "Entity type label for cylinder fills in the import wizard"}` |
| de | `"Füllungen"` |
| es | `"Llenados"` |
| fr | `"Gonflages"` |
| it | `"Ricariche"` |
| nl | `"Vullingen"` |
| pt | `"Enchimentos"` |
| hu | `"Töltések"` |
| ar | `"التعبئات"` |
| he | `"מילויים"` |
| zh | `"充气记录"` |

Run: `flutter gen-l10n && flutter test test/l10n test/features/import_wizard/domain/models/import_bundle_test.dart test/features/import_wizard/data/services/import_provider_invalidator_test.dart`
Expected: PASS.

- [ ] **Step 5: Thread fills through `UddfImportResult`, the importer and `ImportRepositories`**

In `lib/core/services/export/models/uddf_import_result.dart`:

- Field after `courses`: 

```dart
  final List<Map<String, dynamic>> courses;

  /// Cylinder fills from a Submersion fills CSV (passports phase 5): rows
  /// keyed by fill id and passport id, stored by CsvFillImporter.
  final List<Map<String, dynamic>> fills;
```

- Constructor: `this.fills = const [],` after `this.courses = const [],`.
- `isEmpty`: `courses.isEmpty && fills.isEmpty;`
- `totalItems`: `courses.length + fills.length;`
- `summary`: after the courses line, `if (fills.isNotEmpty) parts.add('${fills.length} fills');`
- `copyWithSourceFileName`: `fills: fills,` after `courses: courses,`.

In `lib/features/dive_import/data/services/uddf_entity_importer.dart`:

- Imports (package group): 

```dart
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/csv_fill_importer.dart';
```

- `ImportRepositories`: after `siteFeatureRepository`:

```dart
  /// Optional for the same reason; when null, the fills in a Submersion
  /// fills CSV are skipped rather than failing the import (cylinder
  /// passports phase 5). Both are needed: the fills repository stores the
  /// row, the passport repository finds the cylinder it links to.
  final CylinderFillRepository? cylinderFillRepository;
  final CylinderPassportRepository? cylinderPassportRepository;
```

with `this.cylinderFillRepository, this.cylinderPassportRepository,` at the end of the constructor parameter list.

- `UddfImportSelections`: field `final Set<int> fills;`, constructor `this.fills = const {},`, `selectAll`: `fills: _allIndices(data.fills.length),`.
- `UddfEntityImportResult`: field `final int fills;`, constructor `this.fills = 0,`, `total` adds `+ fills`, `summary` adds `if (fills > 0) parts.add('$fills fills');` after the tags line.
- In `import()`, after the `_importServiceRecords(...)` call and before `_importBuddies`:

```dart

    // Cylinder fills (passports phase 5) are keyed by passport id, not by
    // an imported item, so they need only the diver and the two passport
    // repositories. CsvFillImporter keeps each row's id, skips one already
    // here or deleted here, and links the fill to the diver's cylinder that
    // holds its passport id.
    final fillsCount =
        repositories.cylinderFillRepository == null ||
            repositories.cylinderPassportRepository == null
        ? 0
        : await CsvFillImporter(
            fills: repositories.cylinderFillRepository,
            passports: repositories.cylinderPassportRepository,
          ).importRows(
            data.fills,
            selected: selections.fills,
            diverId: diverId,
          );
```

- In the `return UddfEntityImportResult(...)` add `fills: fillsCount,` after `courses: coursesCount,`.

- [ ] **Step 6: Thread fills through the adapter, the expander and the repository bundle**

In `lib/features/import_wizard/data/adapters/universal_adapter.dart`:

- Imports (the file does not import `dive.dart` today): `import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';` and `import 'package:submersion/features/dive_log/domain/entities/dive.dart' show GasMix;`.
- `buildBundle`, after the media group:

```dart
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.fills,
      payload.entitiesOf(ui.ImportEntityType.fills),
      _fillToEntityItem,
    );
```

- After `_mediaToEntityItem`:

```dart

  EntityItem _fillToEntityItem(Map<String, dynamic> data) {
    final passportId = (data['passportId'] as String?) ?? '';
    final filledAt = data['filledAt'] as DateTime?;
    final o2 = asDoubleOrNull(data['o2Percent']);
    final he = asDoubleOrNull(data['hePercent']) ?? 0;
    final mix = o2 == null ? '' : GasMix(o2: o2, he: he).name;
    final when = filledAt == null ? '' : _units.formatDate(filledAt);
    return EntityItem(
      title: passportId.isEmpty ? mix : passportId,
      subtitle: [when, mix].where((s) => s.isNotEmpty).join(', '),
    );
  }
```

- `_runImporter`, in `UddfImportSelections(...)`: `fills: resolve(wizard.ImportEntityType.fills),` after `courses:`.
- `_convertImportCounts`: `if (result.fills > 0) counts[wizard.ImportEntityType.fills] = result.fills;` after the courses block.
- `payloadToUddfResult`: `fills: payload.entitiesOf(ui.ImportEntityType.fills),` after `serviceRecords:`.
- `universalImportRepositories`: after `siteFeatureRepository`:

```dart
    // Cylinder fills (passports phase 5); without both, every fill in a
    // fills CSV is skipped.
    cylinderFillRepository: ref.read(cylinderFillRepositoryProvider),
    cylinderPassportRepository: ref.read(cylinderPassportRepositoryProvider),
```

`checkDuplicates` gets no fills entry: a fill's identity is its id, and `CsvFillImporter` skips one already here, so there is nothing for the review to flag or link. A re-imported file shows its rows as plain items and the summary counts only the rows actually created. Add this sentence as a comment above the `return ImportBundle(` at the end of `checkDuplicates`:

```dart
    // Fills are not checked: their identity is the fill id and the importer
    // skips one already here (passports phase 5), so a re-import shows the
    // rows and creates none.
```

In `lib/features/universal_import/data/services/payload_diver_expander.dart`, after `out[ImportEntityType.media] = media;`:

```dart

    // A fill is keyed by passport id, not by a dive, so every fill goes to
    // the primary profile (cylinder passports phase 5).
    out[ImportEntityType.fills] = [
      if (primary != null)
        for (final fill in source.entitiesOf(ImportEntityType.fills))
          {...fill, DiverTarget.itemKey: primary},
    ];
```

In `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart` add the imports

```dart
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
```

and in `buildRepositories()` after `siteFeatureRepository: SiteFeatureRepository(),`:

```dart
  cylinderFillRepository: CylinderFillRepository(),
  cylinderPassportRepository: CylinderPassportRepository(),
```

Run: `flutter analyze && flutter test test/features/import_wizard test/features/universal_import test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart`
Expected: `No issues found!`, every test PASS (including the repositories test from Step 3).

- [ ] **Step 7: Write the wizard end-to-end test**

Create `test/features/import_wizard/data/adapters/universal_adapter_fills_csv_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    show ImportFormat;
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../core/services/export/csv/csv_test_fixtures.dart';
import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// A Submersion fills CSV through UniversalAdapter the way the wizard runs
/// it: a Fills group in the bundle, the id-keeping importer, the passport
/// link, and the summary count (cylinder passports phase 5).
void main() {
  testWidgets('a fills CSV imports as a Fills group and links by passport id', (
    tester,
  ) async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.runAsync(() async {
      await DiverRepository().createDiver(_diver());
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tank-1',
              name: 'AL80',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(_diverId),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'tank-1',
        passportId: 'pp-al80',
        diverId: _diverId,
      );
    });

    final bytes = Uint8List.fromList(
      utf8.encode(CsvFillsWriter(CsvExportUnits.metric).write(goldenFills())),
    );
    final detected = const FormatDetector().detect(bytes).format;
    expect(detected, ImportFormat.submersionFillsCsv);
    final payload = await parserForFormat(detected).parse(bytes);

    final result = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(result.errorMessage, isNull);
    expect(result.importedCounts[ImportEntityType.fills], 2);

    await tester.runAsync(() async {
      final fills = CylinderFillRepository();
      final linked = (await fills.getById(goldenFills().first.id))!;
      expect(linked.equipmentId, 'tank-1');
      expect(linked.diverId, _diverId);
      final unlinked = (await fills.getById(goldenFills()[1].id))!;
      expect(unlinked.equipmentId, isNull);
      expect(unlinked.passportId, 'pp-foreign');
    });

    // The same file again: the review shows the rows, the import adds none.
    final again = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(again.errorMessage, isNull);
    expect(again.importedCounts[ImportEntityType.fills], isNull);
    await tester.runAsync(() async {
      expect(
        await CylinderFillRepository().getAllVisibleTo(_diverId),
        hasLength(2),
      );
    });
  });
}
```

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_fills_csv_test.dart`
Expected: PASS.

- [ ] **Step 8: Format, analyze, run the guards, commit**

Run: `dart format . && flutter analyze && flutter test test/architecture test/features/import_wizard test/features/cylinder_passports test/features/dive_import`
Expected: `No issues found!`, every test PASS.

```bash
git add lib/features/cylinder_passports/data/services/csv_fill_importer.dart lib/core/services/export/models/uddf_import_result.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/features/import_wizard/domain/models/import_bundle.dart lib/features/import_wizard/data/adapters/universal_adapter.dart lib/features/import_wizard/data/services/import_provider_invalidator.dart lib/features/import_wizard/presentation/widgets/review_step.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart lib/features/universal_import/data/services/payload_diver_expander.dart lib/l10n test/features/cylinder_passports/data/services/csv_fill_importer_test.dart test/features/import_wizard/domain/models/import_bundle_test.dart test/features/import_wizard/data/services/import_provider_invalidator_test.dart test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart test/features/import_wizard/data/adapters/universal_adapter_fills_csv_test.dart test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart
git commit -m "feat(import): fills group in the wizard with an id-keeping, passport-linking importer

Refs #2339"
```

---

### Task 6: Round trip in three unit modes and the Review Focus cases

**Files:**
- Modify: `test/core/services/export/csv/csv_round_trip_test.dart`

**Interfaces:**
- Consumes: `CsvFillsWriter`, `CylinderFillRepository.getAllVisibleTo/getById/delete/getForCylinder`, `CylinderPassportRepository.assignPassportId`, `PayloadMerger().merge([FilePayload(fileId:, fileName:, payload:)])`, `UniversalAdapter.payloadToUddfResult`, `UddfEntityImporter.import` with `buildRepositories()` (which now carries both passport repositories) and `createTestDiver()`.
- Produces: nothing new; this task pins behaviour.

- [ ] **Step 1: Add the fills round trip to the three-mode loop**

In `test/core/services/export/csv/csv_round_trip_test.dart` add the imports

```dart
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';
```

(if `drift`'s `Value` clashes with anything already imported, alias it: `import 'package:drift/drift.dart' as drift show Value;` and write `drift.Value`.)

Inside the `for (final MergeEntry(key: label, value: units) in cases.entries)` group, after `dives come back`:

```dart
      test('fills come back', () async {
        final diverId = await importCsv(
          CsvFillsWriter(
            units,
          ).write(goldenFills(), equipmentById: goldenFillEquipment()),
          ImportFormat.submersionFillsCsv,
        );
        final stored = {
          for (final f in await CylinderFillRepository().getAllVisibleTo(
            diverId,
          ))
            f.id: f,
        };
        expect(
          stored.keys,
          unorderedEquals(goldenFills().map((f) => f.id)),
          reason: 'the fill id survives the round trip',
        );
        for (final original in goldenFills()) {
          final back = stored[original.id]!;
          final what = original.id;
          expect(back.passportId, original.passportId, reason: what);
          expect(back.diverId, diverId, reason: what);
          expect(
            back.equipmentId,
            isNull,
            reason: 'no cylinder of this diver carries the id',
          );
          expect(back.filledAt, original.filledAt, reason: what);
          expect(back.o2Percent, original.o2Percent, reason: what);
          expect(back.hePercent, original.hePercent, reason: what);
          // psi is written whole (0.5 psi is 0.034 bar); °F whole (0.28 °C).
          near(back.pressureBar, original.pressureBar, 0.06, 'pressure');
          near(back.temperatureC, original.temperatureC, 0.6, 'temperature');
          expect(back.analyzer, original.analyzer, reason: what);
          expect(back.stationName, original.stationName, reason: what);
          expect(back.source, original.source, reason: what);
          expect(back.notes, original.notes.replaceAll('\n', ' '));
        }
      });
```

Run: `flutter test test/core/services/export/csv/csv_round_trip_test.dart --name "fills come back"`
Expected: PASS, 3 tests (one per unit mode).

- [ ] **Step 2: Pin the Review Focus cases**

Append inside `main()`, after the last existing test:

```dart
  group('fills CSV (cylinder passports phase 5)', () {
    Future<UddfEntityImportResult> importFills(
      String csv,
      String diverId,
    ) async {
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final payload = await parserForFormat(
        ImportFormat.submersionFillsCsv,
      ).parse(bytes);
      final data = UniversalAdapter.payloadToUddfResult(payload);
      return UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: diverId,
      );
    }

    test('the same file imported twice adds nothing', () async {
      final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
      final diverId = await createTestDiver();
      expect((await importFills(csv, diverId)).fills, 2);
      expect((await importFills(csv, diverId)).fills, 0);
      expect(
        await CylinderFillRepository().getAllVisibleTo(diverId),
        hasLength(2),
      );
    });

    test('a fill deleted here stays deleted after a re-import', () async {
      final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
      final diverId = await createTestDiver();
      await importFills(csv, diverId);
      final gone = goldenFills().first.id;
      await CylinderFillRepository().delete(gone);
      expect((await importFills(csv, diverId)).fills, 0);
      expect(await CylinderFillRepository().getById(gone), isNull);
      expect(
        await CylinderFillRepository().getAllVisibleTo(diverId),
        hasLength(1),
      );
    });

    test('a fill links to the cylinder holding its passport id', () async {
      final diverId = await createTestDiver();
      final db = DatabaseService.instance.database;
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tank-1',
              name: 'AL80',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: Value(diverId),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'tank-1',
        passportId: 'pp-al80',
        diverId: diverId,
      );

      await importFills(
        CsvFillsWriter(CsvExportUnits.metric).write(goldenFills()),
        diverId,
      );

      final fills = CylinderFillRepository();
      expect((await fills.getById(goldenFills().first.id))!.equipmentId, 'tank-1');
      expect((await fills.getById(goldenFills()[1].id))!.equipmentId, isNull);
      // The passport page reads it through the gear link.
      expect(
        (await fills.getForCylinder(
          passportId: 'pp-al80',
          equipmentId: 'tank-1',
        )).map((f) => f.id),
        [goldenFills().first.id],
      );
    });

    test('an unlinked fill is picked up when a cylinder gets its passport id',
        () async {
      final diverId = await createTestDiver();
      await importFills(
        CsvFillsWriter(CsvExportUnits.metric).write(goldenFills()),
        diverId,
      );
      final db = DatabaseService.instance.database;
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tank-2',
              name: 'Stage',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: Value(diverId),
            ),
          );
      // Link an existing tag: assignPassportId relinks the fills under it.
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'tank-2',
        passportId: 'pp-foreign',
        diverId: diverId,
      );
      expect(
        (await CylinderFillRepository().getById(goldenFills()[1].id))!
            .equipmentId,
        'tank-2',
      );
    });

    test('an equipment CSV and a fills CSV import together', () async {
      // The batch merger prefixes every uddfId with the file id; the fill
      // must still land under the id the file wrote.
      final equipmentCsv = CsvEquipmentWriter(
        CsvExportUnits.metric,
      ).write(goldenEquipment());
      final fillsCsv = CsvFillsWriter(
        CsvExportUnits.metric,
      ).write(goldenFills(), equipmentById: goldenFillEquipment());
      Future<ImportPayload> parse(String csv, ImportFormat format) =>
          parserForFormat(format).parse(Uint8List.fromList(utf8.encode(csv)));
      final merged = const PayloadMerger().merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'equipment.csv',
          payload: await parse(
            equipmentCsv,
            ImportFormat.submersionEquipmentCsv,
          ),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'fills.csv',
          payload: await parse(fillsCsv, ImportFormat.submersionFillsCsv),
        ),
      ]);
      expect(
        merged.entitiesOf(ImportEntityType.fills).first['uddfId'],
        'f1:${goldenFills().first.id}',
        reason: 'the merger namespaces uddfId like every entity',
      );

      final data = UniversalAdapter.payloadToUddfResult(merged);
      final diverId = await createTestDiver();
      final result = await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: diverId,
      );
      expect(result.equipment, goldenEquipment().length);
      expect(result.fills, 2);
      final stored = await CylinderFillRepository().getAllVisibleTo(diverId);
      expect(
        stored.map((f) => f.id),
        unorderedEquals(goldenFills().map((f) => f.id)),
        reason: 'the stored id is the file\'s, not the namespaced one',
      );
      // The imported AL80 has no passport id (the equipment parser drops the
      // system attribute on purpose), so the fill stays unlinked.
      expect(stored.every((f) => f.equipmentId == null), isTrue);
    });
  });
```

`FilePayload` is the merger's input record (`lib/features/universal_import/data/services/payload_merger.dart`, line 15: `fileId`, `fileName`, `payload`). If `UddfEntityImportResult` is not yet visible in this file, it is exported by `uddf_entity_importer.dart`, already imported.

Run: `flutter test test/core/services/export/csv/csv_round_trip_test.dart`
Expected: PASS, every test.

- [ ] **Step 3: Format, run the whole export and import test tree, commit**

Run: `dart format . && flutter analyze && flutter test test/core/services/export test/features/universal_import test/features/import_wizard test/features/cylinder_passports`
Expected: `No issues found!`, every test PASS.

```bash
git add test/core/services/export/csv/csv_round_trip_test.dart
git commit -m "test(csv): fills round trip in three unit modes, re-import, deletion, linking and batch

Refs #2339"
```

---

## Final whole-branch checks

- [ ] `dart format .` leaves no changes (`git status --short` shows nothing unstaged).
- [ ] `flutter analyze` reports `No issues found!` (infos are fatal in CI).
- [ ] `flutter gen-l10n` leaves the generated files unchanged (no stale `app_localizations_*.dart`).
- [ ] `flutter test test/l10n test/architecture` passes (parity across 11 locales, diacritics twin scan, the lib-wide guards over the three new `lib/` files).
- [ ] `flutter test test/core/services/export test/features/universal_import test/features/import_wizard test/features/cylinder_passports test/features/transfer test/features/settings/presentation/providers test/features/dive_import` passes.
- [ ] `git diff main --stat -- test/core/services/export/csv/goldens/` shows only the added `fills_metric.csv`.
- [ ] `git log main..HEAD --format=%B | grep -nP '\x{2014}|\x{2013}'` prints nothing; `git diff main | grep -nP '^\+.*(\x{2014}|\x{2013})'` prints nothing.
- [ ] `git log main..HEAD --format=%B | grep -inE "co-authored-by|generated with|/code/session_"` prints nothing (no tool or vendor attribution in any commit).
- [ ] Manual check on a device or desktop build: Transfer > Export CSV shows "Cylinder fills" with the unit selector; sharing and saving produce `fills_export_<date>.csv`; importing that file shows a "Fills (N)" tab in the review step and "Fills: N" on the summary; importing it a second time completes with no Fills line on the summary.

## PR body requirements

- Title: `feat(cylinder-passports): fills in their own Submersion CSV (#2339, PR 5 of 6)`.
- First line of the description: `Closes #2339` on its own line, then `Refs #2333` on its own line (keyword directly before the number; the "PR Issue Link" check reads these).
- Summary: the fourth Submersion CSV (writer, export sheet entry, signature, format, parser, wizard Fills group, id-keeping importer with passport linking), the spec amendment, no schema change.
- Screenshots section (this PR touches `lib/features/transfer/presentation/` and `lib/features/import_wizard/presentation/`): the CSV export sheet with the new "Cylinder fills" entry selected (light and dark), and the import wizard review step showing the "Fills" tab (light and dark). `gh` cannot upload images: capture them, hand the files to the maintainer, and list in the section what each image shows. Do not tick "No visible UI change".
- Testing line: the three-mode round trip, the five Review Focus cases, the wizard end-to-end test, `test/l10n` and `test/architecture`.
- No co-author trailer, no session link, no tool attribution anywhere in the body or in any commit.
