# Unit-aware CSV Round Trip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the dives, sites and equipment CSV exports a "My units" / "Metric" choice, and make every Submersion CSV (either mode, either unit system) re-import through the import wizard with the same stored values.

**Architecture:** A shared column codec under `lib/core/services/export/csv/codec/` owns the file format (header grammar `Base (suffix)`, units, decimals, date and time formats, tank capacity, attribute pairs). The exporters write through it; three new `ImportFormat`s with dedicated parsers under `lib/features/universal_import/data/parsers/submersion_csv/` read through it and emit the map keys `UddfEntityImporter` already consumes. A few importer gaps (site entry method, equipment attributes, dive weather and custom fields) are closed so the round trip is complete.

**Tech Stack:** Flutter, Dart 3 (patterns, records), Riverpod (`StateNotifier`), Drift, `csv` package, `intl` `DateFormat`, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-12-unit-aware-csv-round-trip-design.md`

## Global Constraints

- Metric mode output is byte-for-byte identical to the pre-change output for dives, sites and equipment (enforced by golden files captured in Task 1 before any exporter change).
- Every number written by the CSV exports uses `.` as the decimal separator (`toStringAsFixed` / `toString`, never a locale formatter).
- My units month names are always English: `DateFormat(pattern, 'en_US')`.
- Metric mode dates and times keep the existing `DateFormat('yyyy-MM-dd')` and `DateFormat('HH:mm')` (no explicit locale), so their bytes do not change.
- Never write the em-dash character (U+2014) or an en-dash used as punctuation in code, comments, docs, commit messages or PR text.
- No AI tool attribution, co-author trailers, "generated with" lines or session links in any commit, PR, comment or file.
- No emojis in code, comments or docs.
- Files: 200 to 400 lines typical, 800 max. New helpers go in their own files rather than growing `uddf_entity_importer.dart` (2,900+ lines) or `enums.dart`.
- Imports grouped: dart, flutter, packages, local; package imports use `package:submersion/...`.
- Run `dart format .` before every commit.
- Stage explicit paths only (never `git add -A` / `git add .`).
- Test commands: `flutter test <path>`; never pipe `flutter test` into `grep` (it hides the exit code).
- New user-facing strings go in `lib/l10n/arb/app_en.arb` (alphabetical) and are translated in all 11 locale files (`ar de en es fr he hu it nl pt zh`); in non-en files insert next to the neighbouring `transfer_csvExport_` key. Regenerate with `flutter gen-l10n`.

## File Structure

**Create (core codec, shared by export and import):**
- `lib/core/constants/enum_display_lookup.dart`: `enumByDisplayName` generic lookup.
- `lib/core/services/export/csv/codec/csv_header.dart`: `CsvHeader` (split `Base (suffix)`).
- `lib/core/services/export/csv/codec/csv_unit.dart`: `CsvQuantity`, `CsvUnit` (symbols, conversions, decimals).
- `lib/core/services/export/csv/codec/csv_column.dart`: `CsvColumn` and the `CsvColumns` declarations.
- `lib/core/services/export/csv/codec/csv_date_formats.dart`: date and time header suffixes, format and parse.
- `lib/core/services/export/csv/codec/csv_export_units.dart`: `CsvUnitMode`, `CsvExportUnits`.
- `lib/core/services/export/csv/codec/tank_capacity.dart`: rated capacity pair.
- `lib/core/services/export/csv/codec/csv_text.dart`: `sanitizeCsvField`, `unsanitizeCsvField`, `trimFixed`.
- `lib/core/services/export/csv/codec/csv_attribute_codec.dart`: equipment attribute pair write and read.
- `lib/core/services/export/csv/codec/submersion_csv_signatures.dart`: `SubmersionCsvKind`, header signature matching.
- `lib/core/services/export/csv/csv_dives_writer.dart`, `csv_sites_writer.dart`, `csv_equipment_writer.dart`: the three generators, moved out of `CsvExportService`.

**Create (import):**
- `lib/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart`
- `lib/features/universal_import/data/parsers/submersion_csv/site_location_text.dart`
- `lib/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart`
- `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart`
- `lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart`
- `lib/features/dive_import/data/services/import_map_readers.dart`: attribute and custom-field list readers for the importer.

**Create (UI):**
- `lib/features/settings/presentation/providers/csv_unit_mode_provider.dart`
- `lib/shared/widgets/csv_unit_mode_selector.dart`

**Modify:**
- `lib/core/constants/tank_presets.dart` (add `matchByCapacity`)
- `lib/core/services/export/csv/csv_export_service.dart` (delegate to writers, `units` params)
- `lib/core/services/export/export_service.dart` (facade `units` params)
- `lib/features/universal_import/data/models/import_enums.dart` (3 formats, override options)
- `lib/features/universal_import/data/parsers/parser_registry.dart`
- `lib/features/universal_import/data/services/format_detector.dart`
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` (site entryMethod, equipment attributes, dive weather and custom fields)
- `lib/features/import_wizard/data/adapters/universal_adapter.dart` (expose payload conversion for tests)
- `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`, `lib/features/transfer/presentation/pages/transfer_page.dart`
- `lib/features/settings/presentation/providers/export_providers.dart`
- `lib/shared/widgets/export_destination_sheet.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- `lib/l10n/arb/app_*.arb` (11 files)

---

### Task 1: Capture Metric-mode golden files

Characterization first: these goldens are generated from the unchanged exporter and pin Metric mode byte for byte for the rest of the plan.

**Files:**
- Create: `test/core/services/export/csv/csv_test_fixtures.dart`
- Create: `test/core/services/export/csv/csv_metric_golden_test.dart`
- Create (generated): `test/core/services/export/csv/goldens/dives_metric.csv`, `sites_metric.csv`, `equipment_metric.csv`

**Interfaces:**
- Produces: `List<Dive> goldenDives()`, `List<DiveSite> goldenSites()`, `List<EquipmentItem> goldenEquipment()`, `Map<String, List<String>> goldenComponentNames()` in `csv_test_fixtures.dart`; later tasks reuse them.

- [ ] **Step 1: Write the fixtures**

`test/core/services/export/csv/csv_test_fixtures.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Fixtures that touch every column of the three CSV exports. Values are
/// fixed (no clock, no time zone dependence) so the goldens are stable on
/// every machine: dates are wall-clock values formatted by field, and the
/// one epoch-millisecond attribute is a literal.
const goldenSite = DiveSite(
  id: 'site-1',
  name: 'Blue Hole',
  description: 'Sinkhole with an arch',
  location: GeoPoint(17.316, -87.535),
  maxDepth: 40.5,
  country: 'Belize',
  region: 'Lighthouse Reef',
  city: 'San Pedro',
  rating: 4.5,
  notes: 'Line 1\nLine 2',
  waterType: WaterType.salt,
  entryMethod: EntryMethod.boat,
);

List<DiveSite> goldenSites() => const [
  goldenSite,
  DiveSite(id: 'site-2', name: 'House Reef'),
];

List<Dive> goldenDives() => [
  Dive(
    id: 'dive-1',
    diveNumber: 12,
    name: 'Morning dive',
    dateTime: DateTime.utc(2025, 3, 15, 9, 5),
    bottomTime: const Duration(minutes: 41),
    runtime: const Duration(minutes: 47),
    maxDepth: 30.48,
    avgDepth: 18.25,
    waterTemp: 26.4,
    airTemp: 29.6,
    visibilityMeters: 21.3,
    diveTypeIds: const ['boat', 'deep_wreck'],
    buddy: 'Ana Reyes',
    diveMaster: 'Tom Lee',
    rating: 4,
    site: goldenSite,
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 11.1,
        workingPressure: 206.843,
        startPressure: 206.843,
        endPressure: 50.5,
        gasMix: GasMix(o2: 32),
      ),
    ],
    diveComputerModel: 'Perdix AI',
    diveComputerSerial: 'SN-001',
    diveComputerFirmware: '93',
    notes: 'Great viz\nsaw turtles',
    windSpeed: 4.2,
    windDirection: CurrentDirection.northEast,
    cloudCover: CloudCover.partlyCloudy,
    precipitation: Precipitation.none,
    humidity: 71,
    weatherDescription: 'Sunny',
    customFields: const [
      DiveCustomField(id: 'c1', key: 'Boat', value: 'Sea Dog'),
      DiveCustomField(id: 'c2', key: 'Formula', value: '=1+1'),
    ],
  ),
  Dive(
    id: 'dive-2',
    diveNumber: 13,
    dateTime: DateTime.utc(2025, 3, 15, 14, 30),
    bottomTime: const Duration(minutes: 35),
    maxDepth: 12.0,
    visibility: Visibility.good,
  ),
];

EquipmentAttribute _curated(String id, String key, {String? t, double? n}) =>
    EquipmentAttribute.curated(
      equipmentId: id,
      key: key,
      valueText: t,
      valueNum: n,
    );

List<EquipmentItem> goldenEquipment() => [
  EquipmentItem(
    id: 'e-hose',
    name: 'Long hose',
    type: EquipmentType.hose,
    attributes: [_curated('e-hose', 'hose_length_m', n: 0.5588)],
  ),
  EquipmentItem(
    id: 'e-suit',
    name: 'Suit',
    type: EquipmentType.wetsuit,
    brand: 'Fourth Element',
    model: 'Proteus',
    attributes: [
      _curated('e-suit', 'size', t: 'L'),
      _curated('e-suit', 'thickness_mm', t: '5/4', n: 5),
      _curated('e-suit', 'buoyancy_kg', n: 2.5),
      _curated('e-suit', 'dry_weight_kg', n: 3.25),
      _curated('e-suit', 'suit_style', t: 'full'),
    ],
  ),
  EquipmentItem(
    id: 'e-tank',
    name: 'AL80',
    type: EquipmentType.tank,
    serialNumber: '00123',
    attributes: [
      _curated('e-tank', 'volume_l', n: 11.1),
      _curated('e-tank', 'working_pressure_bar', n: 206.843),
      _curated('e-tank', 'tank_material', t: 'aluminum'),
    ],
  ),
  EquipmentItem(
    id: 'e-dpv',
    name: 'Scooter',
    type: EquipmentType.dpv,
    attributes: [
      _curated('e-dpv', 'speed_mps', n: 0.5),
      _curated('e-dpv', 'burn_time_h', n: 1.5),
    ],
  ),
  EquipmentItem(
    id: 'e-cell',
    name: 'Cell A',
    type: EquipmentType.o2Cell,
    attributes: [
      _curated('e-cell', 'cell_slot', n: 2),
      _curated('e-cell', 'installed_date', n: 1741996800000),
      const EquipmentAttribute(
        id: 'custom-1',
        equipmentId: 'e-cell',
        key: 'Batch',
        isCustom: true,
        valueText: 'B-77',
      ),
    ],
  ),
  EquipmentItem(
    id: 'e-first',
    name: 'Mk25',
    type: EquipmentType.firstStage,
    purchaseDate: DateTime(2023, 6, 1),
    lastServiceDate: DateTime(2025, 1, 10),
    serviceIntervalDays: 365,
    isActive: false,
    notes: 'DIN\nserviced',
  ),
  EquipmentItem(
    id: 'e-reg',
    name: 'Primary reg',
    type: EquipmentType.regulator,
  ),
];

Map<String, List<String>> goldenComponentNames() => {
  'e-reg': ['Mk25', 'Long hose'],
};
```

If a constructor rejects a named argument above (for example `DiveSite` requires another field), open the entity file, supply the minimal required value, and keep every value listed here.

- [ ] **Step 2: Write the golden test with a one-time writer**

`test/core/services/export/csv/csv_metric_golden_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';

import 'csv_test_fixtures.dart';

/// Metric mode must stay byte-for-byte identical to the pre-#1813 export.
/// The goldens were written by the unchanged exporter; regenerate ONLY with
/// `flutter test <this file> --dart-define=WRITE_CSV_GOLDENS=true`, and only
/// when a deliberate format change has been agreed.
const _write = bool.fromEnvironment('WRITE_CSV_GOLDENS');
const _dir = 'test/core/services/export/csv/goldens';

void _check(String name, String actual) {
  final file = File('$_dir/$name');
  if (_write) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

void main() {
  final service = CsvExportService();

  test('dives metric export matches the golden', () {
    _check('dives_metric.csv', service.generateDivesCsvContent(goldenDives()));
  });

  test('sites metric export matches the golden', () {
    _check('sites_metric.csv', service.generateSitesCsvContent(goldenSites()));
  });

  test('equipment metric export matches the golden', () {
    _check(
      'equipment_metric.csv',
      service.generateEquipmentCsvContent(
        goldenEquipment(),
        componentNames: goldenComponentNames(),
      ),
    );
  });
}
```

- [ ] **Step 3: Generate the goldens from the unchanged exporter**

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart --dart-define=WRITE_CSV_GOLDENS=true`
Expected: PASS, and three files appear under `test/core/services/export/csv/goldens/`. Open each and confirm it has a header row plus one row per fixture (dives 2, sites 2, equipment 7), that `dives_metric.csv` contains `Max Depth (m)` and `'=1+1`, and that `equipment_metric.csv` contains `hose_length_m=0.5588` and `installed_date=1741996800000.0`.

- [ ] **Step 4: Run the test in compare mode**

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format test/core/services/export/csv
git add test/core/services/export/csv/csv_test_fixtures.dart test/core/services/export/csv/csv_metric_golden_test.dart test/core/services/export/csv/goldens/dives_metric.csv test/core/services/export/csv/goldens/sites_metric.csv test/core/services/export/csv/goldens/equipment_metric.csv
git commit -m "test(csv): pin the metric CSV exports with golden files (#1813)"
```

---

### Task 2: Display-name enum lookup

**Files:**
- Create: `lib/core/constants/enum_display_lookup.dart`
- Test: `test/core/constants/enum_display_lookup_test.dart`

**Interfaces:**
- Produces: `T? enumByDisplayName<T extends Enum>(List<T> values, String Function(T) displayNameOf, String? text)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('every export enum round trips through its display name', () {
    void check<T extends Enum>(List<T> values, String Function(T) name) {
      for (final v in values) {
        expect(enumByDisplayName(values, name, name(v)), v, reason: '$v');
      }
    }

    check(WaterType.values, (v) => v.displayName);
    check(EntryMethod.values, (v) => v.displayName);
    check(EquipmentType.values, (v) => v.displayName);
    check(Visibility.values, (v) => v.displayName);
    check(CurrentDirection.values, (v) => v.displayName);
    check(CloudCover.values, (v) => v.displayName);
    check(Precipitation.values, (v) => v.displayName);
  });

  test('matching ignores case and surrounding spaces', () {
    expect(
      enumByDisplayName(EntryMethod.values, (v) => v.displayName, ' boat entry '),
      EntryMethod.boat,
    );
  });

  test('the enum name is accepted as a fallback', () {
    expect(
      enumByDisplayName(EquipmentType.values, (v) => v.displayName, 'firstStage'),
      EquipmentType.firstStage,
    );
  });

  test('blank or unknown text is null', () {
    expect(enumByDisplayName(WaterType.values, (v) => v.displayName, ''), isNull);
    expect(enumByDisplayName(WaterType.values, (v) => v.displayName, null), isNull);
    expect(
      enumByDisplayName(WaterType.values, (v) => v.displayName, 'Lava'),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/constants/enum_display_lookup_test.dart`
Expected: FAIL (import of `enum_display_lookup.dart` not found).

- [ ] **Step 3: Implement**

```dart
/// Resolves [text] to the enum value whose display name it is, falling back
/// to the value's `.name`. Both comparisons ignore case and surrounding
/// whitespace. Returns null for blank or unknown text.
///
/// The CSV exports write enums by their English display name ("Boat Entry",
/// "First Stage"); every importer elsewhere matches `.name` only, so reading
/// a Submersion CSV back needs this reverse lookup.
T? enumByDisplayName<T extends Enum>(
  List<T> values,
  String Function(T) displayNameOf,
  String? text,
) {
  final wanted = text?.trim().toLowerCase() ?? '';
  if (wanted.isEmpty) return null;
  for (final value in values) {
    if (displayNameOf(value).toLowerCase() == wanted) return value;
  }
  for (final value in values) {
    if (value.name.toLowerCase() == wanted) return value;
  }
  return null;
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/constants/enum_display_lookup_test.dart`
Expected: PASS (4 tests). If the first test fails because two values of one enum share a display name, stop and report it; the lookup cannot be exact for that enum.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/constants/enum_display_lookup.dart test/core/constants/enum_display_lookup_test.dart
git add lib/core/constants/enum_display_lookup.dart test/core/constants/enum_display_lookup_test.dart
git commit -m "feat(csv): look up export enums by display name (#1813)"
```

---

### Task 3: Header grammar, units and columns

**Files:**
- Create: `lib/core/services/export/csv/codec/csv_header.dart`
- Create: `lib/core/services/export/csv/codec/csv_unit.dart`
- Create: `lib/core/services/export/csv/codec/csv_column.dart`
- Create: `lib/core/services/export/csv/codec/csv_text.dart`
- Test: `test/core/services/export/csv/codec/csv_header_test.dart`, `csv_unit_test.dart`, `csv_text_test.dart`

**Interfaces:**
- Produces:
  - `class CsvHeader { final String base; final String? suffix; factory CsvHeader.parse(String raw); String get key; }` (`key` is `base.toLowerCase()`)
  - `enum CsvQuantity { depth, temperature, pressure, volume, weight, windSpeed }`
  - `enum CsvUnit { meters, feet, celsius, fahrenheit, bar, psi, liters, cubicFeet, kilograms, pounds, metersPerSecond, kilometersPerHour, knots; String symbol; CsvQuantity quantity; int myUnitsDecimals; double fromMetric(double); double toMetric(double); static CsvUnit metricFor(CsvQuantity); static CsvUnit? fromSymbol(String?) }`
  - `class CsvColumn { final String base; final CsvQuantity quantity; final int? metricDecimals; }` and `abstract final class CsvColumns` with `maxDepth, avgDepth, waterTemp, airTemp, visibility, startPressure, endPressure, tankVolume, workingPressure, windSpeed, buoyancy, dryWeight`
  - `String sanitizeCsvField(String? value)`, `String unsanitizeCsvField(String value)`, `String trimFixed(double value, int decimals)`

- [ ] **Step 1: Write the failing tests**

`test/core/services/export/csv/codec/csv_header_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_header.dart';

void main() {
  test('splits a unit suffix', () {
    final h = CsvHeader.parse('Max Depth (ft)');
    expect(h.base, 'Max Depth');
    expect(h.suffix, 'ft');
    expect(h.key, 'max depth');
  });

  test('splits a date format suffix that contains a comma', () {
    final h = CsvHeader.parse('Date (MMM D, YYYY)');
    expect(h.base, 'Date');
    expect(h.suffix, 'MMM D, YYYY');
  });

  test('a header with no suffix keeps its whole text', () {
    expect(CsvHeader.parse(' O2 % ').base, 'O2 %');
    expect(CsvHeader.parse('O2 %').suffix, isNull);
  });

  test('only a trailing group is a suffix', () {
    final h = CsvHeader.parse('Humidity (%)');
    expect(h.base, 'Humidity');
    expect(h.suffix, '%');
  });
}
```

`test/core/services/export/csv/codec/csv_unit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';

void main() {
  test('every unit round trips through its own conversion', () {
    for (final unit in CsvUnit.values) {
      expect(unit.toMetric(unit.fromMetric(12.345)), closeTo(12.345, 1e-9));
    }
  });

  test('conversions match the app formatter constants', () {
    expect(CsvUnit.feet.fromMetric(10), closeTo(32.8084, 1e-9));
    expect(CsvUnit.fahrenheit.fromMetric(20), closeTo(68, 1e-9));
    expect(CsvUnit.psi.fromMetric(200), closeTo(2900.76, 1e-6));
    expect(CsvUnit.pounds.fromMetric(1), closeTo(2.20462, 1e-9));
    expect(CsvUnit.kilometersPerHour.fromMetric(1), closeTo(3.6, 1e-9));
    expect(CsvUnit.knots.fromMetric(1), closeTo(1.94384, 1e-9));
  });

  test('symbols resolve back to their unit', () {
    for (final unit in CsvUnit.values) {
      expect(CsvUnit.fromSymbol(unit.symbol), unit);
    }
    expect(CsvUnit.fromSymbol('FT'), CsvUnit.feet);
    expect(CsvUnit.fromSymbol('furlongs'), isNull);
    expect(CsvUnit.fromSymbol(null), isNull);
  });

  test('metric units per quantity', () {
    expect(CsvUnit.metricFor(CsvQuantity.depth), CsvUnit.meters);
    expect(CsvUnit.metricFor(CsvQuantity.windSpeed), CsvUnit.metersPerSecond);
  });
}
```

`test/core/services/export/csv/codec/csv_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';

void main() {
  test('sanitize and unsanitize are inverses for guarded values', () {
    for (final v in ['=1+1', '+x', '-3', '@a', '\tq', '|p', 'plain', "'quoted"]) {
      expect(unsanitizeCsvField(sanitizeCsvField(v)), v, reason: v);
    }
  });

  test('a leading quote before an unguarded character is kept', () {
    expect(unsanitizeCsvField("'hello"), "'hello");
  });

  test('trimFixed drops trailing zeros only', () {
    expect(trimFixed(22.0, 1), '22');
    expect(trimFixed(22.04, 1), '22');
    expect(trimFixed(0.39251, 3), '0.393');
    expect(trimFixed(1.50, 2), '1.5');
  });
}
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `flutter test test/core/services/export/csv/codec/`
Expected: FAIL (missing files).

- [ ] **Step 3: Implement `csv_header.dart`**

```dart
/// One CSV header split into its base name and optional parenthesised
/// suffix: `Max Depth (ft)` is base `Max Depth`, suffix `ft`. The suffix
/// names a unit (`ft`, `°F`, `psi`) or a date/time format (`DD/MM/YYYY`,
/// `12-hour`). Submersion's CSV exports always write this shape, so the
/// importer can tell a feet column from a metres one by its header.
class CsvHeader {
  const CsvHeader(this.base, [this.suffix]);

  final String base;
  final String? suffix;

  static final _withSuffix = RegExp(r'^(.*\S)\s*\(([^()]+)\)$');

  factory CsvHeader.parse(String raw) {
    final text = raw.trim();
    final match = _withSuffix.firstMatch(text);
    if (match == null) return CsvHeader(text);
    return CsvHeader(match.group(1)!.trim(), match.group(2)!.trim());
  }

  /// Case-folded base, used to look a column up by name.
  String get key => base.toLowerCase();

  @override
  String toString() => suffix == null ? base : '$base ($suffix)';
}
```

- [ ] **Step 4: Implement `csv_unit.dart`**

```dart
import 'package:submersion/core/constants/units.dart';

/// What a unit-bearing CSV column measures.
enum CsvQuantity { depth, temperature, pressure, volume, weight, windSpeed }

/// A unit a Submersion CSV column can carry: the symbol written in its
/// header, the quantity it measures, and its conversion to and from the
/// canonical metric value the database stores. Conversions reuse the app's
/// unit enums (and the wind constants of `UnitFormatter`) so the CSV can
/// never disagree with what the app displays.
enum CsvUnit {
  meters('m', CsvQuantity.depth),
  feet('ft', CsvQuantity.depth),
  celsius('°C', CsvQuantity.temperature),
  fahrenheit('°F', CsvQuantity.temperature),
  bar('bar', CsvQuantity.pressure),
  psi('psi', CsvQuantity.pressure),
  liters('L', CsvQuantity.volume),
  cubicFeet('cuft', CsvQuantity.volume),
  kilograms('kg', CsvQuantity.weight),
  pounds('lbs', CsvQuantity.weight),
  metersPerSecond('m/s', CsvQuantity.windSpeed),
  kilometersPerHour('km/h', CsvQuantity.windSpeed),
  knots('kts', CsvQuantity.windSpeed);

  const CsvUnit(this.symbol, this.quantity);

  final String symbol;
  final CsvQuantity quantity;

  static const _msToKmh = 3.6;
  static const _msToKnots = 1.94384;

  static CsvUnit metricFor(CsvQuantity quantity) => switch (quantity) {
    CsvQuantity.depth => meters,
    CsvQuantity.temperature => celsius,
    CsvQuantity.pressure => bar,
    CsvQuantity.volume => liters,
    CsvQuantity.weight => kilograms,
    CsvQuantity.windSpeed => metersPerSecond,
  };

  /// Decimals a My units value is written with. Chosen so no value is
  /// rounded more coarsely than the Metric export rounds its counterpart.
  int get myUnitsDecimals => switch (this) {
    meters || feet => 1,
    celsius || fahrenheit => 0,
    bar => 1,
    psi => 0,
    liters || cubicFeet => 1,
    kilograms || pounds => 2,
    metersPerSecond || kilometersPerHour || knots => 1,
  };

  double fromMetric(double value) => switch (this) {
    meters || celsius || bar || liters || kilograms || metersPerSecond =>
      value,
    feet => DepthUnit.meters.convert(value, DepthUnit.feet),
    fahrenheit => TemperatureUnit.celsius.convert(
      value,
      TemperatureUnit.fahrenheit,
    ),
    psi => PressureUnit.bar.convert(value, PressureUnit.psi),
    cubicFeet => VolumeUnit.liters.convert(value, VolumeUnit.cubicFeet),
    pounds => WeightUnit.kilograms.convert(value, WeightUnit.pounds),
    kilometersPerHour => value * _msToKmh,
    knots => value * _msToKnots,
  };

  double toMetric(double value) => switch (this) {
    meters || celsius || bar || liters || kilograms || metersPerSecond =>
      value,
    feet => DepthUnit.feet.convert(value, DepthUnit.meters),
    fahrenheit => TemperatureUnit.fahrenheit.convert(
      value,
      TemperatureUnit.celsius,
    ),
    psi => PressureUnit.psi.convert(value, PressureUnit.bar),
    cubicFeet => VolumeUnit.cubicFeet.convert(value, VolumeUnit.liters),
    pounds => WeightUnit.pounds.convert(value, WeightUnit.kilograms),
    kilometersPerHour => value / _msToKmh,
    knots => value / _msToKnots,
  };

  /// The unit whose header symbol is [symbol], ignoring case, or null.
  static CsvUnit? fromSymbol(String? symbol) {
    final wanted = symbol?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return null;
    for (final unit in values) {
      if (unit.symbol.toLowerCase() == wanted) return unit;
    }
    return null;
  }
}
```

Check `PressureUnit.psi.convert` exists as `value / 14.5038` (it does, `lib/core/constants/units.dart:54`).

- [ ] **Step 5: Implement `csv_column.dart`**

```dart
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';

/// One unit-bearing column of a Submersion CSV export, declared once so the
/// exporter and the importer agree on its name and quantity.
class CsvColumn {
  const CsvColumn(this.base, this.quantity, {required this.metricDecimals});

  /// Header text before the unit suffix.
  final String base;

  final CsvQuantity quantity;

  /// Decimals the Metric export has always used for this column. Null means
  /// the value was written with `double.toString()`, which Metric mode keeps.
  final int? metricDecimals;
}

/// Every unit-bearing column the dives, sites and equipment exports write.
abstract final class CsvColumns {
  static const maxDepth = CsvColumn(
    'Max Depth',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const avgDepth = CsvColumn(
    'Avg Depth',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const waterTemp = CsvColumn(
    'Water Temp',
    CsvQuantity.temperature,
    metricDecimals: 0,
  );
  static const airTemp = CsvColumn(
    'Air Temp',
    CsvQuantity.temperature,
    metricDecimals: 0,
  );
  static const visibility = CsvColumn(
    'Visibility',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const startPressure = CsvColumn(
    'Start Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );
  static const endPressure = CsvColumn(
    'End Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );

  /// Physical volume in litres, or rated gas capacity when the unit is cuft
  /// (see `tank_capacity.dart`).
  static const tankVolume = CsvColumn(
    'Tank Volume',
    CsvQuantity.volume,
    metricDecimals: 0,
  );

  /// My units only: lets the importer turn a rated cuft back into litres.
  static const workingPressure = CsvColumn(
    'Working Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );
  static const windSpeed = CsvColumn(
    'Wind Speed',
    CsvQuantity.windSpeed,
    metricDecimals: 1,
  );
  static const buoyancy = CsvColumn(
    'Buoyancy',
    CsvQuantity.weight,
    metricDecimals: null,
  );
  static const dryWeight = CsvColumn(
    'Dry Weight',
    CsvQuantity.weight,
    metricDecimals: null,
  );
}
```

- [ ] **Step 6: Implement `csv_text.dart`**

```dart
/// Characters a spreadsheet would treat as the start of a formula.
const _formulaLeaders = {'=', '+', '-', '@', '\t', '\r', '|'};

/// Sanitize a string value to prevent CSV injection attacks.
///
/// Prefixes values starting with dangerous characters (=, +, -, @, tab,
/// carriage return, pipe) with a single quote, which forces spreadsheet
/// applications to treat the value as plain text.
///
/// References:
/// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
String sanitizeCsvField(String? value) {
  if (value == null || value.isEmpty) return '';
  return _formulaLeaders.contains(value[0]) ? "'$value" : value;
}

/// Reverses [sanitizeCsvField]: drops a leading quote only when it guards a
/// formula character, so a value the diver typed with a leading quote
/// survives the round trip.
String unsanitizeCsvField(String value) {
  if (value.length >= 2 &&
      value[0] == "'" &&
      _formulaLeaders.contains(value[1])) {
    return value.substring(1);
  }
  return value;
}

/// [value] with [decimals] places, trailing zeros (and a bare point)
/// removed, always with `.` as the decimal separator.
String trimFixed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
```

Note: `sanitizeCsvField` keeps the exact behaviour of `CsvExportService.sanitizeCsvField` (`lib/core/services/export/csv/csv_export_service.dart:31-48`); Task 6 makes the service delegate to it. `unsanitizeCsvField("'quoted")` returns `"'quoted"` because `q` is not a formula leader, which is what the first test expects (`sanitizeCsvField("'quoted")` does not add a quote).

- [ ] **Step 7: Run the tests**

Run: `flutter test test/core/services/export/csv/codec/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/services/export/csv/codec test/core/services/export/csv/codec
git add lib/core/services/export/csv/codec/csv_header.dart lib/core/services/export/csv/codec/csv_unit.dart lib/core/services/export/csv/codec/csv_column.dart lib/core/services/export/csv/codec/csv_text.dart test/core/services/export/csv/codec/csv_header_test.dart test/core/services/export/csv/codec/csv_unit_test.dart test/core/services/export/csv/codec/csv_text_test.dart
git commit -m "feat(csv): header grammar, units and column declarations (#1813)"
```

---

### Task 4: Date and time formats, and the export units value

**Files:**
- Create: `lib/core/services/export/csv/codec/csv_date_formats.dart`
- Create: `lib/core/services/export/csv/codec/csv_export_units.dart`
- Test: `test/core/services/export/csv/codec/csv_date_formats_test.dart`, `csv_export_units_test.dart`

**Interfaces:**
- Consumes: `CsvUnit`, `CsvQuantity`, `CsvColumn` (Task 3); `AppSettings` (`lib/features/settings/presentation/providers/settings_providers.dart`), `UnitFormatter` (`lib/core/utils/unit_formatter.dart`).
- Produces:
  - `DateFormatPreference? dateFormatForSuffix(String? suffix)`, `TimeFormat? timeFormatForSuffix(String? suffix)`
  - `DateTime? parseCsvDate(String text, DateFormatPreference? format)` (null format = ISO `yyyy-MM-dd`; returns a UTC date at midnight)
  - `({int hour, int minute})? parseCsvTime(String text, TimeFormat? format)` (null format = `HH:mm`)
  - `enum CsvUnitMode { myUnits, metric }`
  - `class CsvExportUnits { static const metric; factory CsvExportUnits.fromSettings(AppSettings); factory CsvExportUnits.forMode(CsvUnitMode, AppSettings); bool isMetric; UnitFormatter? formatter; DateFormatPreference? dateFormat; CsvUnit unitFor(CsvQuantity); String header(CsvColumn); String value(CsvColumn, double?); String dateHeader(String base); String timeHeader(String base); String date(DateTime); String time(DateTime); }`

- [ ] **Step 1: Write the failing tests**

`test/core/services/export/csv/codec/csv_date_formats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';

void main() {
  test('every date preference round trips through its header suffix', () {
    final date = DateTime.utc(2025, 3, 5);
    for (final f in DateFormatPreference.values) {
      expect(dateFormatForSuffix(f.displayName), f);
      final text = formatCsvDate(date, f);
      expect(parseCsvDate(text, f), date, reason: '${f.name}: $text');
    }
  });

  test('every time preference round trips through its header suffix', () {
    for (final f in TimeFormat.values) {
      expect(timeFormatForSuffix(f.displayName), f);
      final text = formatCsvTime(DateTime.utc(2025, 3, 5, 14, 7), f);
      expect(parseCsvTime(text, f), (hour: 14, minute: 7), reason: text);
    }
  });

  test('month names are English regardless of the default locale', () {
    expect(
      formatCsvDate(DateTime.utc(2025, 1, 9), DateFormatPreference.mmmDYYYY),
      'Jan 9, 2025',
    );
  });

  test('no suffix means ISO date and 24-hour time', () {
    expect(parseCsvDate('2025-03-05', null), DateTime.utc(2025, 3, 5));
    expect(parseCsvTime('09:05', null), (hour: 9, minute: 5));
  });

  test('unparseable text is null, not an exception', () {
    expect(parseCsvDate('05/03', DateFormatPreference.ddmmyyyy), isNull);
    expect(parseCsvTime('noon', null), isNull);
    expect(parseCsvDate('', null), isNull);
  });
}
```

`test/core/services/export/csv/codec/csv_export_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
  timeFormat: TimeFormat.twelveHour,
);

const metricDiver = AppSettings(
  dateFormat: DateFormatPreference.ddmmyyyy,
  timeFormat: TimeFormat.twentyFourHour,
);

void main() {
  group('Metric mode keeps the historical format', () {
    const units = CsvExportUnits.metric;

    test('headers', () {
      expect(units.header(CsvColumns.maxDepth), 'Max Depth (m)');
      expect(units.header(CsvColumns.waterTemp), 'Water Temp (°C)');
      expect(units.header(CsvColumns.windSpeed), 'Wind Speed (m/s)');
      expect(units.header(CsvColumns.buoyancy), 'Buoyancy (kg)');
      expect(units.dateHeader('Date'), 'Date');
      expect(units.timeHeader('Time'), 'Time');
    });

    test('values use each column\'s historical decimals', () {
      expect(units.value(CsvColumns.maxDepth, 30.48), '30.5');
      expect(units.value(CsvColumns.waterTemp, 26.4), '26');
      expect(units.value(CsvColumns.tankVolume, 11.1), '11');
      expect(units.value(CsvColumns.buoyancy, 2.5), '2.5');
      expect(units.value(CsvColumns.maxDepth, null), '');
    });

    test('ISO date and 24-hour time', () {
      final t = DateTime.utc(2025, 3, 15, 9, 5);
      expect(units.date(t), '2025-03-15');
      expect(units.time(t), '09:05');
    });
  });

  group('My units for an imperial diver', () {
    final units = CsvExportUnits.fromSettings(imperial);

    test('headers name the diver\'s units and formats', () {
      expect(units.header(CsvColumns.maxDepth), 'Max Depth (ft)');
      expect(units.header(CsvColumns.waterTemp), 'Water Temp (°F)');
      expect(units.header(CsvColumns.startPressure), 'Start Pressure (psi)');
      expect(units.header(CsvColumns.tankVolume), 'Tank Volume (cuft)');
      expect(units.header(CsvColumns.windSpeed), 'Wind Speed (kts)');
      expect(units.header(CsvColumns.dryWeight), 'Dry Weight (lbs)');
      expect(units.dateHeader('Date'), 'Date (MM/DD/YYYY)');
      expect(units.timeHeader('Time'), 'Time (12-hour)');
    });

    test('values are converted with the My units decimals', () {
      expect(units.value(CsvColumns.maxDepth, 30.48), '100.0');
      expect(units.value(CsvColumns.waterTemp, 26.4), '80');
      expect(units.value(CsvColumns.startPressure, 206.843), '3000');
      expect(units.value(CsvColumns.buoyancy, 2.5), '5.51');
      expect(units.value(CsvColumns.windSpeed, 4.2), '8.2');
    });

    test('dates and times follow the diver', () {
      final t = DateTime.utc(2025, 3, 15, 14, 30);
      expect(units.date(t), '03/15/2025');
      expect(units.time(t), '2:30 PM');
    });
  });

  test('a metric diver in My units gets km/h wind and 2-decimal kg', () {
    final units = CsvExportUnits.fromSettings(metricDiver);
    expect(units.header(CsvColumns.windSpeed), 'Wind Speed (km/h)');
    expect(units.value(CsvColumns.windSpeed, 4.2), '15.1');
    expect(units.value(CsvColumns.buoyancy, 2.5), '2.50');
    expect(units.dateHeader('Date'), 'Date (DD/MM/YYYY)');
  });

  test('forMode picks metric or the diver\'s units', () {
    expect(CsvExportUnits.forMode(CsvUnitMode.metric, imperial).isMetric, isTrue);
    expect(CsvExportUnits.forMode(CsvUnitMode.myUnits, imperial).isMetric, isFalse);
  });
}
```

If `AppSettings` cannot be `const` with these arguments, drop `const` and use `final`; the values are what matter.

- [ ] **Step 2: Run them to confirm they fail**

Run: `flutter test test/core/services/export/csv/codec/csv_date_formats_test.dart test/core/services/export/csv/codec/csv_export_units_test.dart`
Expected: FAIL (missing files).

- [ ] **Step 3: Implement `csv_date_formats.dart`**

```dart
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';

/// Month names in a My units file are always English, so a file written on
/// a French device parses on a German one.
const csvDateLocale = 'en_US';

const _isoDatePattern = 'yyyy-MM-dd';
const _isoTimePattern = 'HH:mm';

/// The date format a header suffix names (`DD/MM/YYYY`), or null for no or
/// an unknown suffix. Suffixes are `DateFormatPreference.displayName`.
DateFormatPreference? dateFormatForSuffix(String? suffix) {
  for (final format in DateFormatPreference.values) {
    if (format.displayName == suffix?.trim()) return format;
  }
  return null;
}

/// The time format a header suffix names (`12-hour`), or null.
TimeFormat? timeFormatForSuffix(String? suffix) {
  for (final format in TimeFormat.values) {
    if (format.displayName == suffix?.trim()) return format;
  }
  return null;
}

String formatCsvDate(DateTime date, DateFormatPreference format) =>
    DateFormat(format.pattern, csvDateLocale).format(date);

String formatCsvTime(DateTime time, TimeFormat format) =>
    DateFormat(format.pattern, csvDateLocale).format(time);

/// Parses a date cell written with [format] (ISO when null) into a UTC
/// midnight, or null when the text does not match.
DateTime? parseCsvDate(String text, DateFormatPreference? format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final parsed = DateFormat(
      format?.pattern ?? _isoDatePattern,
      csvDateLocale,
    ).parseStrict(trimmed);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  } on FormatException {
    return null;
  }
}

/// Parses a time cell written with [format] (24-hour when null).
({int hour, int minute})? parseCsvTime(String text, TimeFormat? format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final parsed = DateFormat(
      format?.pattern ?? _isoTimePattern,
      csvDateLocale,
    ).parseStrict(trimmed);
    return (hour: parsed.hour, minute: parsed.minute);
  } on FormatException {
    return null;
  }
}
```

- [ ] **Step 4: Implement `csv_export_units.dart`**

```dart
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Which units a CSV export writes.
enum CsvUnitMode {
  /// The active diver's unit, date and time settings, named in each header.
  myUnits,

  /// Canonical metric values and ISO dates: the historical format.
  metric,
}

/// The resolved units of one CSV export. [metric] reproduces the historical
/// output byte for byte; [CsvExportUnits.fromSettings] follows a diver.
class CsvExportUnits {
  const CsvExportUnits._({required this.isMetric, AppSettings? settings})
    : _settings = settings;

  static const metric = CsvExportUnits._(isMetric: true);

  factory CsvExportUnits.fromSettings(AppSettings settings) =>
      CsvExportUnits._(isMetric: false, settings: settings);

  factory CsvExportUnits.forMode(CsvUnitMode mode, AppSettings settings) =>
      mode == CsvUnitMode.metric
      ? metric
      : CsvExportUnits.fromSettings(settings);

  final bool isMetric;
  final AppSettings? _settings;

  // The historical formatters, kept without an explicit locale so Metric
  // mode's bytes cannot change.
  static final _isoDate = DateFormat('yyyy-MM-dd');
  static final _isoTime = DateFormat('HH:mm');

  /// Formatter for the diver's settings; null in Metric mode.
  UnitFormatter? get formatter =>
      _settings == null ? null : UnitFormatter(_settings);

  /// The diver's date format; null in Metric mode (ISO).
  DateFormatPreference? get dateFormat => _settings?.dateFormat;

  CsvUnit unitFor(CsvQuantity quantity) {
    final s = _settings;
    if (isMetric || s == null) return CsvUnit.metricFor(quantity);
    return switch (quantity) {
      CsvQuantity.depth =>
        s.depthUnit == DepthUnit.feet ? CsvUnit.feet : CsvUnit.meters,
      CsvQuantity.temperature =>
        s.temperatureUnit == TemperatureUnit.fahrenheit
            ? CsvUnit.fahrenheit
            : CsvUnit.celsius,
      CsvQuantity.pressure =>
        s.pressureUnit == PressureUnit.psi ? CsvUnit.psi : CsvUnit.bar,
      CsvQuantity.volume =>
        s.volumeUnit == VolumeUnit.cubicFeet
            ? CsvUnit.cubicFeet
            : CsvUnit.liters,
      CsvQuantity.weight =>
        s.weightUnit == WeightUnit.pounds
            ? CsvUnit.pounds
            : CsvUnit.kilograms,
      // Same rule as UnitFormatter._isMetricWind: wind follows depth.
      CsvQuantity.windSpeed =>
        s.depthUnit == DepthUnit.meters
            ? CsvUnit.kilometersPerHour
            : CsvUnit.knots,
    };
  }

  String header(CsvColumn column) =>
      '${column.base} (${unitFor(column.quantity).symbol})';

  /// [metricValue] written in this export's unit for [column], or '' when
  /// null.
  String value(CsvColumn column, double? metricValue) {
    if (metricValue == null) return '';
    if (isMetric) {
      final decimals = column.metricDecimals;
      return decimals == null
          ? metricValue.toString()
          : metricValue.toStringAsFixed(decimals);
    }
    final unit = unitFor(column.quantity);
    return unit.fromMetric(metricValue).toStringAsFixed(unit.myUnitsDecimals);
  }

  String dateHeader(String base) =>
      isMetric ? base : '$base (${_settings!.dateFormat.displayName})';

  String timeHeader(String base) =>
      isMetric ? base : '$base (${_settings!.timeFormat.displayName})';

  String date(DateTime date) => isMetric
      ? _isoDate.format(date)
      : formatCsvDate(date, _settings!.dateFormat);

  String time(DateTime time) => isMetric
      ? _isoTime.format(time)
      : formatCsvTime(time, _settings!.timeFormat);
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/export/csv/codec/`
Expected: PASS. If `units.value(CsvColumns.windSpeed, 4.2)` for imperial is not `8.2`, recompute `4.2 * 1.94384 = 8.164` -> `8.2` and fix the test only if the arithmetic in the test was wrong, never the constant.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/export/csv/codec test/core/services/export/csv/codec
git add lib/core/services/export/csv/codec/csv_date_formats.dart lib/core/services/export/csv/codec/csv_export_units.dart test/core/services/export/csv/codec/csv_date_formats_test.dart test/core/services/export/csv/codec/csv_export_units_test.dart
git commit -m "feat(csv): date formats and the per-export units value (#1813)"
```

---
### Task 5: Tank rated-capacity pair

**Files:**
- Modify: `lib/core/constants/tank_presets.dart` (add `matchByCapacity` after `matchBySpecs`)
- Create: `lib/core/services/export/csv/codec/tank_capacity.dart`
- Test: `test/core/services/export/csv/codec/tank_capacity_test.dart`

**Interfaces:**
- Produces:
  - `static TankPreset? TankPresets.matchByCapacity(double ratedCuft, double workingPressureBar)`
  - `double ratedCapacityCuft(double volumeLiters, double? workingPressureBar)`
  - `double volumeLitersFromCapacity(double cuft, double? workingPressureBar)`
  - `const double assumedWorkingPressureBar = 200`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';

void main() {
  test('a preset tank writes its rated capacity and reads back exactly', () {
    const al80 = TankPresets.al80;
    final cuft = ratedCapacityCuft(al80.volumeLiters, al80.workingPressureBar);
    expect(cuft, al80.ratedCapacityCuft);
    expect(
      volumeLitersFromCapacity(cuft, al80.workingPressureBar),
      al80.volumeLiters,
    );
  });

  test('every rated preset round trips', () {
    for (final p in TankPresets.all) {
      if (p.ratedCapacityCuft == null) continue;
      final cuft = ratedCapacityCuft(p.volumeLiters, p.workingPressureBar);
      final back = volumeLitersFromCapacity(cuft, p.workingPressureBar);
      // Presets indistinguishable by specs share a volume (see matchBySpecs).
      expect(back, closeTo(p.volumeLiters, 1e-9), reason: p.name);
    }
  });

  test('a non-preset tank uses ideal gas both ways', () {
    final cuft = ratedCapacityCuft(13.0, 232);
    expect(cuft, closeTo(13.0 * 232 / 28.3168, 1e-9));
    expect(volumeLitersFromCapacity(cuft, 232), closeTo(13.0, 1e-9));
  });

  test('a blank working pressure assumes 200 bar both ways', () {
    final cuft = ratedCapacityCuft(11.1, null);
    expect(cuft, closeTo(11.1 * 200 / 28.3168, 1e-9));
    expect(volumeLitersFromCapacity(cuft, null), closeTo(11.1, 1e-9));
  });

  test('the value written to one decimal still reads back within 0.01 L', () {
    final written = double.parse(ratedCapacityCuft(13.0, 232).toStringAsFixed(1));
    expect(volumeLitersFromCapacity(written, 232), closeTo(13.0, 0.01));
  });

  test('matchByCapacity needs both the rating and the pressure', () {
    expect(TankPresets.matchByCapacity(77.4, 206.843), TankPresets.al80);
    expect(TankPresets.matchByCapacity(77.4, 232), isNull);
    expect(TankPresets.matchByCapacity(78.0, 206.843), isNull);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/export/csv/codec/tank_capacity_test.dart`
Expected: FAIL (missing file and method).

- [ ] **Step 3: Add `matchByCapacity` to `TankPresets`**

Insert after `matchBySpecs` in `lib/core/constants/tank_presets.dart`:

```dart
  /// The inverse of reading [TankPreset.ratedCapacityCuft] off
  /// [matchBySpecs]: the first preset rated at [ratedCuft] (within 0.05, the
  /// rounding of a one-decimal CSV value) whose working pressure is within
  /// 2 bar of [workingPressureBar]. Used to turn an imperial CSV's rated
  /// capacity back into the cylinder's physical volume.
  static TankPreset? matchByCapacity(
    double ratedCuft,
    double workingPressureBar,
  ) {
    for (final preset in all) {
      final rated = preset.ratedCapacityCuft;
      if (rated != null &&
          (rated - ratedCuft).abs() < 0.05 &&
          (preset.workingPressureBar - workingPressureBar).abs() < 2.0) {
        return preset;
      }
    }
    return null;
  }
```

- [ ] **Step 4: Implement `tank_capacity.dart`**

```dart
import 'package:submersion/core/constants/tank_presets.dart';

/// Litre-bar per cubic foot of gas at the surface, the constant
/// `UnitFormatter.formatTankVolume` uses.
const _literBarPerCuft = 28.3168;

/// The working pressure `UnitFormatter.formatTankVolume` assumes when a
/// tank has none. The CSV reader assumes the same, so a blank pressure
/// still round trips.
const double assumedWorkingPressureBar = 200;

double? _pressureOrNull(double? bar) => bar != null && bar > 0 ? bar : null;

/// The number an imperial diver knows a cylinder by: the preset's rated
/// capacity when [volumeLiters] and [workingPressureBar] match one (exactly
/// what the app displays), otherwise the ideal-gas capacity.
double ratedCapacityCuft(double volumeLiters, double? workingPressureBar) {
  final pressure = _pressureOrNull(workingPressureBar);
  if (pressure != null) {
    final rated = TankPresets.matchBySpecs(
      volumeLiters,
      pressure,
    )?.ratedCapacityCuft;
    if (rated != null) return rated;
  }
  return volumeLiters * (pressure ?? assumedWorkingPressureBar) /
      _literBarPerCuft;
}

/// Inverse of [ratedCapacityCuft]: the physical volume in litres.
double volumeLitersFromCapacity(double cuft, double? workingPressureBar) {
  final pressure = _pressureOrNull(workingPressureBar);
  if (pressure != null) {
    final preset = TankPresets.matchByCapacity(cuft, pressure);
    if (preset != null) return preset.volumeLiters;
  }
  return cuft * _literBarPerCuft / (pressure ?? assumedWorkingPressureBar);
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/core/services/export/csv/codec/tank_capacity_test.dart`
Expected: PASS. If "every rated preset round trips" fails for a pair of presets that share a rating and pressure but differ in volume, that pair is indistinguishable in a CSV; report it rather than loosening the test.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/constants/tank_presets.dart lib/core/services/export/csv/codec/tank_capacity.dart test/core/services/export/csv/codec/tank_capacity_test.dart
git add lib/core/constants/tank_presets.dart lib/core/services/export/csv/codec/tank_capacity.dart test/core/services/export/csv/codec/tank_capacity_test.dart
git commit -m "feat(csv): rated tank capacity and its inverse (#1813)"
```

---

### Task 6: Equipment attribute pair codec

**Files:**
- Create: `lib/core/services/export/csv/codec/csv_attribute_codec.dart`
- Test: `test/core/services/export/csv/codec/csv_attribute_codec_test.dart`

**Interfaces:**
- Consumes: `CsvExportUnits` (Task 4), `trimFixed` (Task 3), `parseCsvDate` (Task 4), `attributeDisplayFromMetric` and `attributeUnitSymbol` (`lib/features/equipment/presentation/utils/equipment_attribute_units.dart`), `EquipmentAttributeCatalog`, `parsePrimaryThickness` (`lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`).
- Produces:
  - `typedef CsvAttribute = ({String key, bool isCustom, String? valueText, double? valueNum});`
  - `String formatAttributePair(EquipmentAttribute attribute, CsvExportUnits units)`
  - `String? myUnitsKeyFor(String key)`
  - `List<String> splitAttributePairs(String cell)`
  - `CsvAttribute? parseAttributePair(String pair, {DateFormatPreference? dateFormat})` (null = the pair could not be read)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
);
const _metricDiver = AppSettings(dateFormat: DateFormatPreference.ddmmyyyy);

EquipmentAttribute _num(String key, double n) =>
    EquipmentAttribute.curated(equipmentId: 'e', key: key, valueNum: n);

/// Every curated number attribute whose dimension carries a unit.
List<EquipmentAttributeDef> _unitDefs() {
  final seen = <String, EquipmentAttributeDef>{};
  for (final type in EquipmentType.values) {
    for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
      if (myUnitsKeyFor(def.key) != null) seen[def.key] = def;
    }
  }
  return seen.values.toList();
}

void main() {
  test('Metric mode writes the stored key and raw value', () {
    expect(
      formatAttributePair(_num('hose_length_m', 0.5588), CsvExportUnits.metric),
      'hose_length_m=0.5588',
    );
  });

  test('My units drops the metric suffix and names the unit', () {
    final imperial = CsvExportUnits.fromSettings(_imperial);
    expect(formatAttributePair(_num('hose_length_m', 0.5588), imperial),
        'hose_length=22 in');
    expect(formatAttributePair(_num('burn_time_h', 1.5), imperial),
        'burn_time=90 min');
    expect(formatAttributePair(_num('volume_l', 11.1), imperial),
        'volume=0.392 cuft');
    final metric = CsvExportUnits.fromSettings(_metricDiver);
    expect(formatAttributePair(_num('hose_length_m', 0.5588), metric),
        'hose_length=55.9 cm');
  });

  test('no My units pair ever uses a metric-suffixed key', () {
    final imperial = CsvExportUnits.fromSettings(_imperial);
    for (final def in _unitDefs()) {
      final pair = formatAttributePair(_num(def.key, 12.34), imperial);
      expect(pair.startsWith('${def.key}='), isFalse, reason: pair);
    }
  });

  test('stripped keys are unique across the catalog', () {
    final bases = _unitDefs().map((d) => myUnitsKeyFor(d.key)).toList();
    expect(bases.toSet().length, bases.length);
  });

  test('every unit attribute round trips in both unit systems', () {
    for (final settings in [_imperial, _metricDiver]) {
      final units = CsvExportUnits.fromSettings(settings);
      for (final def in _unitDefs()) {
        final pair = formatAttributePair(_num(def.key, 12.34), units);
        final back = parseAttributePair(pair)!;
        expect(back.key, def.key, reason: pair);
        expect(back.isCustom, isFalse);
        expect(back.valueNum, closeTo(12.34, 12.34 * 0.01), reason: pair);
      }
    }
  });

  test('Metric pairs read back exactly', () {
    expect(parseAttributePair('hose_length_m=0.5588'),
        (key: 'hose_length_m', isCustom: false, valueText: null, valueNum: 0.5588));
    expect(parseAttributePair('tank_material=aluminum'),
        (key: 'tank_material', isCustom: false, valueText: 'aluminum', valueNum: null));
    expect(parseAttributePair('installed_date=1741996800000.0')!.valueNum,
        1741996800000);
  });

  test('a My units date reads with the file date format as local midnight', () {
    final units = CsvExportUnits.fromSettings(_imperial);
    final ms = DateTime(2025, 3, 15).millisecondsSinceEpoch.toDouble();
    final pair = formatAttributePair(_num('installed_date', ms), units);
    expect(pair, 'installed_date=03/15/2025');
    expect(
      parseAttributePair(pair, dateFormat: DateFormatPreference.mmddyyyy)!
          .valueNum,
      ms,
    );
  });

  test('unknown keys become custom text; unreadable curated values are null',
      () {
    expect(parseAttributePair('Batch=B-77'),
        (key: 'Batch', isCustom: true, valueText: 'B-77', valueNum: null));
    expect(parseAttributePair('hose_length_m=long'), isNull);
    expect(parseAttributePair('no equals sign'), isNull);
  });

  test('splitting keeps a "; " that is inside a text value', () {
    expect(splitAttributePairs('retailer=A; B; sku=9'),
        ['retailer=A; B', 'sku=9']);
    expect(splitAttributePairs(''), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/export/csv/codec/csv_attribute_codec_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';

/// One attribute read back from an equipment CSV `key=value` pair.
typedef CsvAttribute = ({
  String key,
  bool isCustom,
  String? valueText,
  double? valueNum,
});

/// The metric suffixes the catalog puts on unit-bearing keys. My units drops
/// them, so a value in inches never sits under `hose_length_m`.
const _metricKeySuffixes = ['_mps', '_bar', '_kg', '_m', '_l', '_h'];

bool _carriesUnit(AttributeDimension d) =>
    d != AttributeDimension.none && d != AttributeDimension.thicknessMm;

/// [key] without its metric suffix when it is a curated number attribute
/// whose dimension carries a unit (`hose_length_m` -> `hose_length`), else
/// null.
String? myUnitsKeyFor(String key) {
  final def = EquipmentAttributeCatalog.defFor(key);
  if (def == null ||
      def.kind != AttributeKind.number ||
      !_carriesUnit(def.dimension)) {
    return null;
  }
  for (final suffix in _metricKeySuffixes) {
    if (key.endsWith(suffix)) {
      return key.substring(0, key.length - suffix.length);
    }
  }
  return null;
}

final Map<String, EquipmentAttributeDef> _defByMyUnitsKey = {
  for (final type in EquipmentType.values)
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      if (myUnitsKeyFor(def.key) case final key?) key: def,
};

/// One attribute as the equipment CSV's Attributes column writes it.
///
/// Metric mode keeps the historical `key=value` with the stored value. My
/// units converts a unit-bearing number with the same helpers the detail
/// page uses and names the unit (`hose_length=22 in`), and writes a date in
/// the file's date format. Text, choice, flag, thickness and custom
/// attributes are the same in both modes.
String formatAttributePair(EquipmentAttribute attribute, CsvExportUnits units) {
  final raw = '${attribute.key}=${attribute.valueText ?? attribute.valueNum}';
  final formatter = units.formatter;
  final number = attribute.valueNum;
  if (units.isMetric || attribute.isCustom || formatter == null) return raw;
  final def = EquipmentAttributeCatalog.defFor(attribute.key);
  if (def == null || number == null) return raw;
  if (def.kind == AttributeKind.date) {
    final date = DateTime.fromMillisecondsSinceEpoch(number.round());
    return '${attribute.key}=${units.date(date)}';
  }
  final key = myUnitsKeyFor(attribute.key);
  if (key == null) return raw;
  final display = attributeDisplayFromMetric(def.dimension, formatter, number);
  final symbol = attributeUnitSymbol(def.dimension, formatter);
  // A cylinder's water volume in cuft is a fraction of one; three places
  // keep it within 0.03 L of the stored litres.
  final decimals = def.dimension == AttributeDimension.volumeL &&
          symbol == VolumeUnit.cubicFeet.symbol
      ? 3
      : 1;
  return '$key=${trimFixed(display, decimals)} $symbol';
}

/// Splits an Attributes cell into pairs. The export joins pairs with '; ';
/// a '; ' inside a text value stays in it unless `key=` follows.
List<String> splitAttributePairs(String cell) => cell.trim().isEmpty
    ? const []
    : cell.split(RegExp(r'; (?=[^;=]+=)'));

final _numberWithSymbol = RegExp(r'^(-?\d+(?:\.\d+)?)\s+(\S.*)$');

/// Reads one pair back. A curated key is read by its catalog kind; a
/// suffix-stripped key with a trailing symbol is converted back to metric;
/// anything else becomes a custom text attribute. Null when the pair has no
/// `=`, or a curated value cannot be read as its kind requires.
///
/// [dateFormat] is the format the file's date columns name; null means the
/// file is Metric (a date attribute is then epoch milliseconds).
CsvAttribute? parseAttributePair(
  String pair, {
  DateFormatPreference? dateFormat,
}) {
  final eq = pair.indexOf('=');
  if (eq <= 0) return null;
  final key = pair.substring(0, eq).trim();
  final value = pair.substring(eq + 1).trim();
  if (key.isEmpty || value.isEmpty) return null;

  final def = EquipmentAttributeCatalog.defFor(key);
  if (def != null) return _readCurated(def, value, dateFormat);

  final unitDef = _defByMyUnitsKey[key];
  final match = _numberWithSymbol.firstMatch(value);
  if (unitDef != null && match != null) {
    final metric = _toMetric(
      unitDef.dimension,
      double.parse(match.group(1)!),
      match.group(2)!.trim(),
    );
    if (metric != null) {
      return (
        key: unitDef.key,
        isCustom: false,
        valueText: null,
        valueNum: metric,
      );
    }
  }
  return (key: key, isCustom: true, valueText: value, valueNum: null);
}

CsvAttribute? _readCurated(
  EquipmentAttributeDef def,
  String value,
  DateFormatPreference? dateFormat,
) {
  CsvAttribute withNumber(double n) =>
      (key: def.key, isCustom: false, valueText: null, valueNum: n);
  switch (def.kind) {
    case AttributeKind.number:
    case AttributeKind.flag:
      final n = double.tryParse(value);
      return n == null ? null : withNumber(n);
    case AttributeKind.date:
      final ms = double.tryParse(value);
      if (ms != null) return withNumber(ms);
      final date = parseCsvDate(value, dateFormat);
      if (date == null) return null;
      // Date attributes are stored as local midnight, as the date picker
      // writes them.
      return withNumber(
        DateTime(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch.toDouble(),
      );
    case AttributeKind.thickness:
      return (
        key: def.key,
        isCustom: false,
        valueText: value,
        valueNum: parsePrimaryThickness(value),
      );
    case AttributeKind.text:
    case AttributeKind.url:
    case AttributeKind.choice:
      return (key: def.key, isCustom: false, valueText: value, valueNum: null);
  }
}

/// Display value with [symbol] back to canonical metric. The inverse of
/// `attributeDisplayFromMetric`, keyed by the symbol the file wrote rather
/// than by the importing diver's settings.
double? _toMetric(AttributeDimension d, double n, String symbol) =>
    switch ((d, symbol)) {
      (AttributeDimension.massKg, 'kg') => n,
      (AttributeDimension.massKg, 'lbs') => WeightUnit.pounds.convert(
        n,
        WeightUnit.kilograms,
      ),
      (AttributeDimension.volumeL, 'L') => n,
      (AttributeDimension.volumeL, 'cuft') => VolumeUnit.cubicFeet.convert(
        n,
        VolumeUnit.liters,
      ),
      (AttributeDimension.pressureBar, 'bar') => n,
      (AttributeDimension.pressureBar, 'psi') => PressureUnit.psi.convert(
        n,
        PressureUnit.bar,
      ),
      (AttributeDimension.lengthM || AttributeDimension.depthM, 'm') => n,
      (AttributeDimension.lengthM || AttributeDimension.depthM, 'ft') =>
        DepthUnit.feet.convert(n, DepthUnit.meters),
      (AttributeDimension.shortLengthM, 'cm') => n / 100,
      (AttributeDimension.shortLengthM, 'in') => n * 2.54 / 100,
      (AttributeDimension.speedMps, 'm/min') => n / 60,
      (AttributeDimension.speedMps, 'ft/min') =>
        DepthUnit.feet.convert(n, DepthUnit.meters) / 60,
      (AttributeDimension.durationH, 'min') => n / 60,
      _ => null,
    };
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/services/export/csv/codec/csv_attribute_codec_test.dart`
Expected: PASS. Two expectations depend on arithmetic worth re-checking if they fail: `0.5588 m = 22.0 in` and `11.1 L = 0.39199 cuft -> 0.392`. If `attributeUnitSymbol` returns a different symbol than `_toMetric` expects (for example `lbs` vs `lb`), fix `_toMetric`'s table to match `attributeUnitSymbol`, never the other way round.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/export/csv/codec/csv_attribute_codec.dart test/core/services/export/csv/codec/csv_attribute_codec_test.dart
git add lib/core/services/export/csv/codec/csv_attribute_codec.dart test/core/services/export/csv/codec/csv_attribute_codec_test.dart
git commit -m "feat(csv): write and read equipment attribute pairs in either mode (#1813)"
```

---
### Task 7: Dives writer with My units

Moves dive CSV generation out of `CsvExportService` (448 lines, about to grow) into its own writer that formats every unit-bearing cell through `CsvExportUnits`.

**Files:**
- Create: `lib/core/services/export/csv/csv_dives_writer.dart`
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (dives methods delegate; `sanitizeCsvField` delegates to `csv_text.dart`)
- Modify: `lib/core/services/export/export_service.dart` (dives CSV facade methods gain `units`)
- Test: `test/core/services/export/csv/csv_dives_writer_test.dart`

**Interfaces:**
- Consumes: `CsvExportUnits`, `CsvColumns`, `CsvQuantity`, `CsvUnit`, `ratedCapacityCuft`, `sanitizeCsvField`.
- Produces:
  - `class CsvDivesWriter { CsvDivesWriter(CsvExportUnits units); String write(List<Dive> dives); }`
  - `CsvExportService.generateDivesCsvContent(List<Dive> dives, {CsvExportUnits units = CsvExportUnits.metric})`, and the same optional `units` on `exportDivesToCsv` and `saveDivesCsvToFile`; `ExportService` mirrors all three.

- [ ] **Step 1: Write the failing test**

`test/core/services/export/csv/csv_dives_writer_test.dart`:

```dart
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'csv_test_fixtures.dart';

const imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
  timeFormat: TimeFormat.twelveHour,
);

/// Row [row] of [csv] as a header -> cell map.
Map<String, String> rowOf(String csv, int row) {
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csv.replaceAll('\r\n', '\n'));
  final headers = rows.first.cast<String>();
  return {
    for (var i = 0; i < headers.length; i++) headers[i]: '${rows[row][i]}',
  };
}

void main() {
  test('imperial My units converts every unit column and names it', () {
    final csv = CsvDivesWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(goldenDives());
    final r = rowOf(csv, 1);
    expect(r['Date (MM/DD/YYYY)'], '03/15/2025');
    expect(r['Time (12-hour)'], '9:05 AM');
    expect(r['Max Depth (ft)'], '100.0');
    expect(r['Avg Depth (ft)'], '59.9');
    expect(r['Water Temp (°F)'], '80');
    expect(r['Air Temp (°F)'], '85');
    expect(r['Visibility (ft)'], '69.9');
    expect(r['Start Pressure (psi)'], '3000');
    expect(r['End Pressure (psi)'], '732');
    expect(r['Tank Volume (cuft)'], '77.4');
    expect(r['Working Pressure (psi)'], '3000');
    expect(r['Wind Speed (kts)'], '8.2');
    expect(r['Bottom Time (min)'], '41');
    expect(r['O2 %'], '32');
    expect(r['custom:Formula'], "'=1+1");
  });

  test('Working Pressure appears only in My units', () {
    final metric = CsvDivesWriter(CsvExportUnits.metric).write(goldenDives());
    expect(metric.split('\n').first, isNot(contains('Working Pressure')));
  });

  test('Metric writer output equals the golden', () {
    // The golden test covers this through CsvExportService; this guards the
    // writer on its own.
    final csv = CsvDivesWriter(CsvExportUnits.metric).write(goldenDives());
    expect(rowOf(csv, 1)['Max Depth (m)'], '30.5');
    expect(rowOf(csv, 1)['Date'], '2025-03-15');
  });
}
```

Arithmetic behind the expectations: 18.25 m = 59.88 ft; 29.6 C = 85.28 F; 21.3 m = 69.88 ft; 50.5 bar = 732.4 psi; AL80 at 206.843 bar = 77.4 cuft rated; 4.2 m/s = 8.16 kts.

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/export/csv/csv_dives_writer_test.dart`
Expected: FAIL (missing `csv_dives_writer.dart`).

- [ ] **Step 3: Implement the writer**

`lib/core/services/export/csv/csv_dives_writer.dart`:

```dart
import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Writes the dives CSV. Every unit-bearing cell and every date and time
/// goes through [units], so Metric mode reproduces the historical file and
/// My units follows the diver with the unit named in each header.
class CsvDivesWriter {
  CsvDivesWriter(this.units);

  final CsvExportUnits units;

  bool get _cuft => units.unitFor(CsvQuantity.volume) == CsvUnit.cubicFeet;

  String write(List<Dive> dives) {
    // Collect all distinct custom field keys across exported dives
    final sortedCustomKeys = {
      for (final dive in dives)
        for (final field in dive.customFields) field.key,
    }.toList()..sort();

    final headers = [
      'Dive Number',
      'Name',
      units.dateHeader('Date'),
      units.timeHeader('Time'),
      'Site',
      'Location',
      units.header(CsvColumns.maxDepth),
      units.header(CsvColumns.avgDepth),
      'Bottom Time (min)',
      'Runtime (min)',
      units.header(CsvColumns.waterTemp),
      units.header(CsvColumns.airTemp),
      // Split at v144: the measured distance is machine-readable, the rating
      // column carries a pre-v144 dive's bucket label.
      units.header(CsvColumns.visibility),
      'Visibility Rating',
      'Dive Type',
      'Buddy',
      'Dive Master',
      'Rating',
      units.header(CsvColumns.startPressure),
      units.header(CsvColumns.endPressure),
      units.header(CsvColumns.tankVolume),
      // My units only: a rated cuft needs the pressure to become litres
      // again. Metric keeps its historical columns.
      if (!units.isMetric) units.header(CsvColumns.workingPressure),
      'O2 %',
      'Dive Computer',
      'Serial Number',
      'Firmware Version',
      'Notes',
      units.header(CsvColumns.windSpeed),
      'Wind Direction',
      'Cloud Cover',
      'Precipitation',
      'Humidity (%)',
      'Weather Description',
      ...sortedCustomKeys.map((key) => sanitizeCsvField('custom:$key')),
    ];

    final rows = <List<dynamic>>[headers];

    for (final dive in dives) {
      final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
      rows.add([
        dive.diveNumber ?? '',
        dive.effectiveName?.replaceAll('\n', ' ') ?? '',
        units.date(dive.dateTime),
        units.time(dive.dateTime),
        dive.site?.name ?? '',
        dive.site?.locationString ?? '',
        units.value(CsvColumns.maxDepth, dive.maxDepth),
        units.value(CsvColumns.avgDepth, dive.avgDepth),
        dive.bottomTime?.inMinutes ?? '',
        dive.runtime?.inMinutes ?? '',
        units.value(CsvColumns.waterTemp, dive.waterTemp),
        units.value(CsvColumns.airTemp, dive.airTemp),
        units.value(CsvColumns.visibility, dive.visibilityMeters),
        dive.visibility?.displayName ?? '',
        dive.diveTypeNames.join('; '),
        dive.buddy ?? '',
        dive.diveMaster ?? '',
        dive.rating ?? '',
        units.value(CsvColumns.startPressure, tank?.startPressure),
        units.value(CsvColumns.endPressure, tank?.endPressure),
        _tankVolume(tank),
        if (!units.isMetric)
          units.value(CsvColumns.workingPressure, tank?.workingPressure),
        tank?.gasMix.o2.toStringAsFixed(0) ?? '',
        dive.diveComputerModel ?? '',
        dive.diveComputerSerial ?? '',
        dive.diveComputerFirmware ?? '',
        dive.notes.replaceAll('\n', ' '),
        units.value(CsvColumns.windSpeed, dive.windSpeed),
        dive.windDirection?.displayName ?? '',
        dive.cloudCover?.displayName ?? '',
        dive.precipitation?.displayName ?? '',
        dive.humidity?.toStringAsFixed(0) ?? '',
        dive.weatherDescription ?? '',
        ...sortedCustomKeys.map((key) {
          final field = dive.customFields
              .where((f) => f.key == key)
              .firstOrNull;
          return sanitizeCsvField(field?.value ?? '');
        }),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Litres, or the rated gas capacity an imperial diver knows the cylinder
  /// by (the number the app shows).
  String _tankVolume(DiveTank? tank) {
    final volume = tank?.volume;
    if (volume == null) return '';
    if (!_cuft) return units.value(CsvColumns.tankVolume, volume);
    return ratedCapacityCuft(
      volume,
      tank!.workingPressure,
    ).toStringAsFixed(CsvUnit.cubicFeet.myUnitsDecimals);
  }
}
```

Compare this line by line with the old `generateDivesCsvContent` (`csv_export_service.dart:167-262`): the header texts, the column order and every `?? ''` must be unchanged apart from the `units` calls and the one My-units-only column.

- [ ] **Step 4: Delegate from `CsvExportService`**

In `lib/core/services/export/csv/csv_export_service.dart`:

1. Add imports:

```dart
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart'
    as csv_text;
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
```

2. Replace the body of `sanitizeCsvField` (keep its doc comment and signature, since tests call it on the service):

```dart
  String sanitizeCsvField(String? value) => csv_text.sanitizeCsvField(value);
```

3. Replace `generateDivesCsvContent` entirely with:

```dart
  /// Generate CSV content for dives (without sharing). [units] defaults to
  /// the historical metric format.
  String generateDivesCsvContent(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvDivesWriter(units).write(dives);
```

4. Give `exportDivesToCsv` and `saveDivesCsvToFile` the same optional parameter and pass it through:

```dart
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvData = generateDivesCsvContent(dives, units: units);
    return saveAndShareFile(csvData, 'dives_export.csv', 'text/csv');
  }
```

```dart
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvContent = generateDivesCsvContent(dives, units: units);
    // ...rest of the method unchanged
```

- [ ] **Step 5: Mirror the parameter on the `ExportService` facade**

In `lib/core/services/export/export_service.dart` (import `csv_export_units.dart`), change the three dives CSV forwarders (lines 81-82, 95-96, 111-114) to:

```dart
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.exportDivesToCsv(dives, units: units);

  String generateDivesCsvContent(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.generateDivesCsvContent(dives, units: units);

  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.saveDivesCsvToFile(
    dives,
    dialogTitle: dialogTitle,
    units: units,
  );
```

- [ ] **Step 6: Run the writer, golden and existing CSV tests**

Run: `flutter test test/core/services/export/csv/ test/core/services/export/equipment_csv_export_test.dart`
Expected: PASS, including all three golden tests (Metric bytes unchanged).

- [ ] **Step 7: Commit**

```bash
dart format lib/core/services/export test/core/services/export/csv
git add lib/core/services/export/csv/csv_dives_writer.dart lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/export_service.dart test/core/services/export/csv/csv_dives_writer_test.dart
git commit -m "feat(csv): dives CSV follows the diver's units in My units mode (#1813)"
```

---

### Task 8: Sites and equipment writers with My units

**Files:**
- Create: `lib/core/services/export/csv/csv_sites_writer.dart`
- Create: `lib/core/services/export/csv/csv_equipment_writer.dart`
- Modify: `lib/core/services/export/csv/csv_export_service.dart`, `lib/core/services/export/export_service.dart`
- Test: `test/core/services/export/csv/csv_sites_equipment_writer_test.dart`
- Modify: `test/core/services/export/equipment_csv_export_test.dart` (the hose test comment still holds for Metric; update its wording only)

**Interfaces:**
- Consumes: `CsvExportUnits`, `CsvColumns`, `formatAttributePair` (Task 6).
- Produces:
  - `class CsvSitesWriter { CsvSitesWriter(CsvExportUnits units); String write(List<DiveSite> sites); }`
  - `class CsvEquipmentWriter { CsvEquipmentWriter(CsvExportUnits units); String write(List<EquipmentItem> equipment, {Map<String, List<String>> componentNames = const {}}); }`
  - `units` optional parameter (default `CsvExportUnits.metric`) on `generateSitesCsvContent`, `exportSitesToCsv`, `saveSitesCsvToFile`, `generateEquipmentCsvContent`, `exportEquipmentToCsv`, `saveEquipmentCsvToFile`, in both `CsvExportService` and `ExportService`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;
import 'csv_test_fixtures.dart';

void main() {
  final units = CsvExportUnits.fromSettings(imperial);

  test('sites: max depth follows the diver', () {
    final r = rowOf(CsvSitesWriter(units).write(goldenSites()), 1);
    expect(r['Max Depth (ft)'], '132.9');
    expect(r['Latitude'], '17.316000');
  });

  test('equipment: dates, weights and attributes follow the diver', () {
    final csv = CsvEquipmentWriter(units).write(
      goldenEquipment(),
      componentNames: goldenComponentNames(),
    );
    final suit = rowOf(csv, 2);
    expect(suit['Buoyancy (lbs)'], '5.51');
    expect(suit['Dry Weight (lbs)'], '7.17');
    expect(suit['Attributes'], 'suit_style=full');
    expect(rowOf(csv, 1)['Attributes'], 'hose_length=22 in');
    expect(rowOf(csv, 4)['Attributes'], 'speed=98.4 ft/min; burn_time=90 min');
    final first = rowOf(csv, 6);
    expect(first['Purchase Date (MM/DD/YYYY)'], '06/01/2023');
    expect(first['Next Service Due (MM/DD/YYYY)'], '01/10/2026');
    expect(first['Active'], 'No');
    expect(rowOf(csv, 7)['Components'], 'Mk25; Long hose');
  });

  test('no attribute pair puts a converted value under a metric key', () {
    final csv = CsvEquipmentWriter(units).write(goldenEquipment());
    expect(csv, isNot(contains('hose_length_m=')));
    expect(csv, isNot(contains('volume_l=')));
    expect(csv, isNot(contains('speed_mps=')));
  });
}
```

Arithmetic: 40.5 m = 132.87 ft; 3.25 kg = 7.165 lbs; 0.5 m/s = 30 m/min = 98.43 ft/min; 2025-01-10 + 365 days = 2026-01-10.

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/export/csv/csv_sites_equipment_writer_test.dart`
Expected: FAIL (missing writers).

- [ ] **Step 3: Implement `csv_sites_writer.dart`**

```dart
import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Writes the sites CSV; only Max Depth carries a unit.
class CsvSitesWriter {
  CsvSitesWriter(this.units);

  final CsvExportUnits units;

  String write(List<DiveSite> sites) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Country',
        'Region',
        'Latitude',
        'Longitude',
        units.header(CsvColumns.maxDepth),
        'Water Type',
        'Current',
        'Entry Type',
        'Rating',
        'Description',
        'Notes',
      ],
    ];

    for (final site in sites) {
      rows.add([
        site.name,
        site.country ?? '',
        site.region ?? '',
        site.location?.latitude.toStringAsFixed(6) ?? '',
        site.location?.longitude.toStringAsFixed(6) ?? '',
        units.value(CsvColumns.maxDepth, site.maxDepth),
        site.waterType?.displayName ?? '',
        // Typical current has no backing column; the header position is kept
        // so existing consumers of this CSV keep their column offsets.
        '',
        site.entryMethod?.displayName ?? '',
        site.rating?.toStringAsFixed(1) ?? '',
        site.description.replaceAll('\n', ' '),
        site.notes.replaceAll('\n', ' '),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
```

- [ ] **Step 4: Implement `csv_equipment_writer.dart`**

```dart
import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Writes the equipment CSV. [componentNames] maps an assembly's id to its
/// parts' names in template order (issue #1487); items absent from it get
/// an empty cell.
class CsvEquipmentWriter {
  CsvEquipmentWriter(this.units);

  final CsvExportUnits units;

  // Curated keys already covered by dedicated columns; excluded from the
  // combined Attributes column to avoid duplication. Custom fields are never
  // excluded even if their key collides with one of these, because the
  // dedicated columns read curated attributes only, so a custom "size"
  // would otherwise be dropped from the export entirely.
  static const _dedicatedAttrKeys = {
    EquipmentAttrKeys.size,
    EquipmentAttrKeys.thicknessMm,
    EquipmentAttrKeys.buoyancyKg,
    EquipmentAttrKeys.dryWeightKg,
  };

  String _date(DateTime? date) => date == null ? '' : units.date(date);

  String write(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
  }) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Type',
        'Brand',
        'Model',
        'Serial Number',
        'Size',
        'Thickness',
        units.dateHeader('Purchase Date'),
        units.dateHeader('Last Service'),
        units.dateHeader('Next Service Due'),
        units.header(CsvColumns.buoyancy),
        units.header(CsvColumns.dryWeight),
        'Attributes',
        'Components',
        'Active',
        'Notes',
      ],
    ];

    for (final item in equipment) {
      rows.add([
        item.name,
        item.type.displayName,
        item.brand ?? '',
        item.model ?? '',
        item.serialNumber ?? '',
        item.size ?? '',
        item.thickness ?? '',
        _date(item.purchaseDate),
        _date(item.lastServiceDate),
        _date(item.nextServiceDue),
        units.value(CsvColumns.buoyancy, item.buoyancyKg),
        units.value(CsvColumns.dryWeight, item.weightKg),
        item.attributes
            .where(
              (a) =>
                  a.hasValue &&
                  (a.isCustom || !_dedicatedAttrKeys.contains(a.key)),
            )
            .map((a) => formatAttributePair(a, units))
            .join('; '),
        componentNames[item.id]?.join('; ') ?? '',
        item.isActive ? 'Yes' : 'No',
        item.notes.replaceAll('\n', ' '),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
```

The comment above `_dedicatedAttrKeys` is the old service's comment with its double hyphen rewritten as ", so"; keep it that way.

- [ ] **Step 5: Delegate from `CsvExportService` and `ExportService`**

In `csv_export_service.dart`, import both writers and replace `generateSitesCsvContent` and `generateEquipmentCsvContent` with:

```dart
  /// Generate CSV content for sites (without sharing).
  String generateSitesCsvContent(
    List<DiveSite> sites, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvSitesWriter(units).write(sites);

  /// Generate CSV content for equipment (without sharing).
  /// [componentNames] maps an assembly's id to its parts' names in template
  /// order (issue #1487); items absent from it get an empty cell.
  String generateEquipmentCsvContent(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvEquipmentWriter(
    units,
  ).write(equipment, componentNames: componentNames);
```

Add `CsvExportUnits units = CsvExportUnits.metric` to `exportSitesToCsv`, `saveSitesCsvToFile`, `exportEquipmentToCsv` and `saveEquipmentCsvToFile`, passing `units: units` into the generate call in each. Remove the now-unused `EquipmentAttrKeys` import from the service if the analyzer flags it. Then mirror all six on `ExportService` (lines 84-129) exactly as Task 7 did for dives.

- [ ] **Step 6: Update the hose test's wording**

In `test/core/services/export/equipment_csv_export_test.dart`, the test named `'a hose length exports in canonical metres, as its key says'` still passes (it calls the Metric default). Rename it to `'Metric mode writes a hose length in canonical metres, as its key says'` and replace its first comment sentence with: `// Metric mode is the raw data export: "hose_length_m=15" would claim metres for an inch value, so the stored metres go out unconverted. My units writes "hose_length=<n> in" instead (issue #1813).`

- [ ] **Step 7: Run the CSV tests**

Run: `flutter test test/core/services/export/`
Expected: PASS, goldens included.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/services/export test/core/services/export
git add lib/core/services/export/csv/csv_sites_writer.dart lib/core/services/export/csv/csv_equipment_writer.dart lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/export_service.dart test/core/services/export/csv/csv_sites_equipment_writer_test.dart test/core/services/export/equipment_csv_export_test.dart
git commit -m "feat(csv): sites and equipment CSVs follow the diver's units in My units mode (#1813)"
```

---
### Task 9: Remembered unit choice, selector widget, Transfer dialog and strings

**Files:**
- Create: `lib/features/settings/presentation/providers/csv_unit_mode_provider.dart`
- Create: `lib/shared/widgets/csv_unit_mode_selector.dart`
- Modify: `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:471-511` (`_handleCsvExport`)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (the six dives/sites/equipment CSV methods)
- Modify: `lib/l10n/arb/app_*.arb` (11 files), then `flutter gen-l10n`
- Test: `test/features/settings/presentation/providers/csv_unit_mode_provider_test.dart`
- Test: `test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`
- Test: `test/features/settings/presentation/providers/export_csv_units_test.dart`

**Interfaces:**
- Consumes: `CsvUnitMode`, `CsvExportUnits.forMode` (Task 4); `sharedPreferencesProvider`, `settingsProvider`.
- Produces:
  - `final csvUnitModeProvider = StateNotifierProvider<CsvUnitModeNotifier, CsvUnitMode>`; `CsvUnitModeNotifier.set(CsvUnitMode mode)`; prefs key `'csv_export_unit_mode'`
  - `class CsvUnitModeSelector extends StatelessWidget { const CsvUnitModeSelector({required CsvUnitMode value, required ValueChanged<CsvUnitMode> onChanged}); }` with key `ValueKey('csv-unit-mode-selector')` on its `SegmentedButton`
  - `typedef CsvExportRequest = ({CsvExportType type, CsvUnitMode unitMode});` and `CsvExportDialog.show(BuildContext, {CsvUnitMode initialUnitMode = CsvUnitMode.myUnits}) -> Future<CsvExportRequest?>`; `CsvExportType.hasUnits`
  - `ExportNotifier.exportDivesToCsv({CsvUnitMode unitMode = CsvUnitMode.metric})`, and the same named parameter on `exportSitesToCsv`, `exportEquipmentToCsv`, `saveDivesCsvToFile`, `saveSitesCsvToFile`, `saveEquipmentCsvToFile`
  - l10n getters `transfer_csvExport_unitsHeader`, `transfer_csvExport_unitsMine`, `transfer_csvExport_unitsMetric`, `transfer_csvExport_unitsMineDescription`, `transfer_csvExport_unitsMetricDescription`

- [ ] **Step 1: Add the strings**

In `lib/l10n/arb/app_en.arb`, insert alphabetically after `"transfer_csvExport_typeSites": "Sites",`:

```json
  "transfer_csvExport_unitsHeader": "Units",
  "transfer_csvExport_unitsMetric": "Metric",
  "transfer_csvExport_unitsMetricDescription": "Metric values and ISO dates, the same format as earlier exports",
  "transfer_csvExport_unitsMine": "My units",
  "transfer_csvExport_unitsMineDescription": "Values in your unit, date and time settings, named in each column header",
```

In each other locale file, insert the same five keys directly after that file's `"transfer_csvExport_typeSites"` line, with these values (header, metric, metric description, mine, mine description):

| File | unitsHeader | unitsMetric | unitsMetricDescription | unitsMine | unitsMineDescription |
| --- | --- | --- | --- | --- | --- |
| app_ar.arb | الوحدات | متري | قيم مترية وتواريخ ISO، بنفس تنسيق عمليات التصدير السابقة | وحداتي | القيم بإعدادات الوحدات والتاريخ والوقت الخاصة بك، مع ذكرها في عنوان كل عمود |
| app_de.arb | Einheiten | Metrisch | Metrische Werte und ISO-Datumsangaben im selben Format wie frühere Exporte | Meine Einheiten | Werte in den eigenen Einheiten-, Datums- und Zeiteinstellungen, in jeder Spaltenüberschrift angegeben |
| app_es.arb | Unidades | Métrico | Valores métricos y fechas ISO, el mismo formato que las exportaciones anteriores | Mis unidades | Valores con tu configuración de unidades, fecha y hora, indicada en el encabezado de cada columna |
| app_fr.arb | Unités | Métrique | Valeurs métriques et dates ISO, au même format que les exports précédents | Mes unités | Valeurs selon vos réglages d'unités, de date et d'heure, indiqués dans l'en-tête de chaque colonne |
| app_he.arb | יחידות | מטרי | ערכים מטריים ותאריכי ISO, באותו פורמט כמו ייצואים קודמים | היחידות שלי | ערכים לפי הגדרות היחידות, התאריך והשעה שלך, עם ציון בכותרת כל עמודה |
| app_hu.arb | Mértékegységek | Metrikus | Metrikus értékek és ISO dátumok, a korábbi exportokkal azonos formátumban | Saját mértékegységek | Értékek a saját mértékegység-, dátum- és időbeállítások szerint, minden oszlopfejlécben feltüntetve |
| app_it.arb | Unità | Metrico | Valori metrici e date ISO, nello stesso formato delle esportazioni precedenti | Le mie unità | Valori nelle tue impostazioni di unità, data e ora, indicate nell'intestazione di ogni colonna |
| app_nl.arb | Eenheden | Metrisch | Metrische waarden en ISO-datums, in hetzelfde formaat als eerdere exports | Mijn eenheden | Waarden in je eigen instellingen voor eenheden, datum en tijd, vermeld in elke kolomkop |
| app_pt.arb | Unidades | Métrico | Valores métricos e datas ISO, no mesmo formato das exportações anteriores | Minhas unidades | Valores nas suas configurações de unidade, data e hora, indicadas no cabeçalho de cada coluna |
| app_zh.arb | 单位 | 公制 | 公制数值和 ISO 日期，与以前的导出格式相同 | 我的单位 | 按你的单位、日期和时间设置输出，并在每列标题中注明 |

Edit the ARB files with the Edit tool (anchor on the `transfer_csvExport_typeSites` line), not with a Python rewrite: some files in this repo are CRLF and a text-mode rewrite silently converts them. Then run: `flutter gen-l10n` and confirm `git diff --stat lib/l10n` shows only additions.

- [ ] **Step 2: Write the failing provider test**

`test/features/settings/presentation/providers/csv_unit_mode_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/csv_unit_mode_provider.dart';

void main() {
  test('starts at My units when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = CsvUnitModeNotifier(await SharedPreferences.getInstance());
    expect(notifier.state, CsvUnitMode.myUnits);
  });

  test('remembers the last choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await CsvUnitModeNotifier(prefs).set(CsvUnitMode.metric);
    expect(CsvUnitModeNotifier(prefs).state, CsvUnitMode.metric);
  });

  test('an unknown stored value falls back to My units', () async {
    SharedPreferences.setMockInitialValues({'csv_export_unit_mode': 'furlongs'});
    final notifier = CsvUnitModeNotifier(await SharedPreferences.getInstance());
    expect(notifier.state, CsvUnitMode.myUnits);
  });
}
```

- [ ] **Step 3: Write the failing dialog test**

`test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/transfer/presentation/widgets/csv_export_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<ValueGetter<Object?>> _open(
  WidgetTester tester, {
  CsvUnitMode initial = CsvUnitMode.myUnits,
}) async {
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await CsvExportDialog.show(
                context,
                initialUnitMode: initial,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('returns the type and the starting unit mode', (tester) async {
    final result = await _open(tester);
    expect(find.text('My units'), findsOneWidget);
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
    expect(result(), (type: CsvExportType.dives, unitMode: CsvUnitMode.myUnits));
  });

  testWidgets('switching to Metric is returned', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Metric'));
    await tester.pumpAndSettle();
    expect(
      find.text('Metric values and ISO dates, the same format as earlier exports'),
      findsOneWidget,
    );
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
    expect(result(), (type: CsvExportType.dives, unitMode: CsvUnitMode.metric));
  });

  testWidgets('opens on the remembered mode', (tester) async {
    await _open(tester, initial: CsvUnitMode.metric);
    final button = tester.widget<SegmentedButton<CsvUnitMode>>(
      find.byKey(const ValueKey('csv-unit-mode-selector')),
    );
    expect(button.selected, {CsvUnitMode.metric});
  });

  testWidgets('the unit choice is hidden for gear check-ins', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Gear check-ins'));
    await tester.pumpAndSettle();
    expect(find.text('My units'), findsNothing);
  });
}
```

`'Export CSV'` is both the dialog title and the button label (`transfer_csvExport_dialogTitle` and `transfer_csvExport_exportButton`), hence `.last`. If the sheet is taller than the test surface and a tap misses, add `await tester.binding.setSurfaceSize(const Size(800, 1400));` at the top of `_open` and reset it with `addTearDown(() => tester.binding.setSurfaceSize(null));`.

- [ ] **Step 4: Run both to confirm they fail**

Run: `flutter test test/features/settings/presentation/providers/csv_unit_mode_provider_test.dart test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`
Expected: FAIL (missing provider; `show` has no `initialUnitMode`).

- [ ] **Step 5: Implement the provider**

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kCsvUnitModeKey = 'csv_export_unit_mode';

/// The CSV unit choice, remembered on this device. Starts at My units; a
/// diver who feeds the CSV to a script picks Metric once and keeps it.
class CsvUnitModeNotifier extends StateNotifier<CsvUnitMode> {
  CsvUnitModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static CsvUnitMode _read(SharedPreferences prefs) =>
      CsvUnitMode.values.asNameMap()[prefs.getString(_kCsvUnitModeKey)] ??
      CsvUnitMode.myUnits;

  Future<void> set(CsvUnitMode mode) async {
    state = mode;
    await _prefs.setString(_kCsvUnitModeKey, mode.name);
  }
}

final csvUnitModeProvider =
    StateNotifierProvider<CsvUnitModeNotifier, CsvUnitMode>(
      (ref) => CsvUnitModeNotifier(ref.watch(sharedPreferencesProvider)),
    );
```

- [ ] **Step 6: Implement the selector widget**

`lib/shared/widgets/csv_unit_mode_selector.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "My units" / "Metric" for a CSV export, with a line saying what the
/// selected mode writes. Shared by the Transfer CSV dialog and the export
/// destination sheet so both read the same.
class CsvUnitModeSelector extends StatelessWidget {
  const CsvUnitModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CsvUnitMode value;
  final ValueChanged<CsvUnitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transfer_csvExport_unitsHeader,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CsvUnitMode>(
          key: const ValueKey('csv-unit-mode-selector'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: CsvUnitMode.myUnits,
              label: Text(l10n.transfer_csvExport_unitsMine),
            ),
            ButtonSegment(
              value: CsvUnitMode.metric,
              label: Text(l10n.transfer_csvExport_unitsMetric),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 4),
        Text(
          value == CsvUnitMode.myUnits
              ? l10n.transfer_csvExport_unitsMineDescription
              : l10n.transfer_csvExport_unitsMetricDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7: Update `CsvExportDialog`**

In `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`:

1. Add imports for `csv_export_units.dart` and `csv_unit_mode_selector.dart`.
2. Add to `enum CsvExportType`, after `icon`:

```dart
  /// Whether this export has unit-bearing columns. Gear check-ins do not.
  bool get hasUnits => this != CsvExportType.observations;
```

3. Above the class, add:

```dart
/// What the CSV dialog returns: the data type and the unit mode.
typedef CsvExportRequest = ({CsvExportType type, CsvUnitMode unitMode});
```

4. Replace the widget's constructor and `show`:

```dart
class CsvExportDialog extends StatefulWidget {
  const CsvExportDialog({super.key, this.initialUnitMode = CsvUnitMode.myUnits});

  /// The remembered unit choice the dialog opens on.
  final CsvUnitMode initialUnitMode;

  /// Show the dialog and return the chosen type and units, or null if
  /// cancelled.
  static Future<CsvExportRequest?> show(
    BuildContext context, {
    CsvUnitMode initialUnitMode = CsvUnitMode.myUnits,
  }) {
    return showModalBottomSheet<CsvExportRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CsvExportDialog(initialUnitMode: initialUnitMode),
    );
  }
```

5. In the state, add `late CsvUnitMode _unitMode = widget.initialUnitMode;` next to `_selected`.
6. In the options `Column`, after the `...CsvExportType.values.map(...)` entry, add:

```dart
                    if (_selected.hasUnits) ...[
                      const SizedBox(height: 8),
                      CsvUnitModeSelector(
                        value: _unitMode,
                        onChanged: (mode) => setState(() => _unitMode = mode),
                      ),
                    ],
```

7. Change the export button's `onPressed` to `() => Navigator.of(context).pop((type: _selected, unitMode: _unitMode))`.

- [ ] **Step 8: Run the provider and dialog tests**

Run: `flutter test test/features/settings/presentation/providers/csv_unit_mode_provider_test.dart test/features/transfer/presentation/widgets/csv_export_dialog_test.dart`
Expected: PASS.

- [ ] **Step 9: Write the failing notifier test**

`test/features/settings/presentation/providers/export_csv_units_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(_FakeExportService export) {
    final container = ProviderContainer(
      overrides: [
        divesProvider.overrideWith(
          (ref) async => [Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 1))],
        ),
        settingsProvider.overrideWith((ref) => _ImperialSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('My units builds the export units from the diver settings', () async {
    final export = _FakeExportService();
    await make(export)
        .read(exportNotifierProvider.notifier)
        .exportDivesToCsv(unitMode: CsvUnitMode.myUnits);
    expect(export.units?.isMetric, isFalse);
    expect(export.units?.formatter?.settings.depthUnit, DepthUnit.feet);
  });

  test('Metric passes the metric units', () async {
    final export = _FakeExportService();
    await make(export)
        .read(exportNotifierProvider.notifier)
        .saveDivesCsvToFile(unitMode: CsvUnitMode.metric);
    expect(export.units, same(CsvExportUnits.metric));
  });
}

class _FakeExportService implements ExportService {
  CsvExportUnits? units;

  @override
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImperialSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _ImperialSettings() : super(const AppSettings(depthUnit: DepthUnit.feet));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

If the notifier's dives read needs more overrides to run (compare `test/features/settings/presentation/providers/export_observations_test.dart`, which also overrides `diveRepositoryProvider` and `validatedCurrentDiverIdProvider`), copy those overrides in.

- [ ] **Step 10: Run it to confirm it fails**

Run: `flutter test test/features/settings/presentation/providers/export_csv_units_test.dart`
Expected: FAIL (`exportDivesToCsv` has no `unitMode` parameter).

- [ ] **Step 11: Thread the mode through `ExportNotifier`**

In `lib/features/settings/presentation/providers/export_providers.dart`, import `csv_export_units.dart` and add inside `ExportNotifier`:

```dart
  /// Units for a CSV export: the diver's settings for My units, or the
  /// historical metric format.
  CsvExportUnits _csvUnits(CsvUnitMode mode) =>
      CsvExportUnits.forMode(mode, _ref.read(settingsProvider));
```

Then give each of `exportDivesToCsv`, `exportSitesToCsv`, `exportEquipmentToCsv`, `saveDivesCsvToFile`, `saveSitesCsvToFile`, `saveEquipmentCsvToFile` the parameter `{CsvUnitMode unitMode = CsvUnitMode.metric}` and add `units: _csvUnits(unitMode)` to its `_exportService` call. For example:

```dart
  Future<void> exportDivesToCsv({
    CsvUnitMode unitMode = CsvUnitMode.metric,
  }) async {
    // ...unchanged until the service call:
      final path = await _exportService.exportDivesToCsv(
        dives,
        units: _csvUnits(unitMode),
      );
```

```dart
      final path = await _exportService.saveDivesCsvToFile(
        dives,
        dialogTitle: _l10n.settings_export_saveDivesCsvDialogTitle,
        units: _csvUnits(unitMode),
      );
```

- [ ] **Step 12: Wire the Transfer page**

Replace `_handleCsvExport` in `lib/features/transfer/presentation/pages/transfer_page.dart` with:

```dart
  /// Handle CSV export with type and units dialog, then share/save options.
  Future<void> _handleCsvExport(BuildContext context, WidgetRef ref) async {
    final request = await CsvExportDialog.show(
      context,
      initialUnitMode: ref.read(csvUnitModeProvider),
    );
    if (request == null || !context.mounted) return;
    if (request.type.hasUnits) {
      unawaited(ref.read(csvUnitModeProvider.notifier).set(request.unitMode));
    }
    final mode = request.unitMode;

    final notifier = ref.read(exportNotifierProvider.notifier);
    switch (request.type) {
      case CsvExportType.dives:
        await _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionDivesTitle,
          shareAction: (_) => notifier.exportDivesToCsv(unitMode: mode),
          saveAction: (_) => notifier.saveDivesCsvToFile(unitMode: mode),
        );
      case CsvExportType.sites:
        await _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionSitesTitle,
          shareAction: (_) => notifier.exportSitesToCsv(unitMode: mode),
          saveAction: (_) => notifier.saveSitesCsvToFile(unitMode: mode),
        );
      case CsvExportType.equipment:
        await _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionEquipmentTitle,
          shareAction: (_) => notifier.exportEquipmentToCsv(unitMode: mode),
          saveAction: (_) => notifier.saveEquipmentCsvToFile(unitMode: mode),
        );
      case CsvExportType.observations:
        await _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionObservationsTitle,
          shareAction: (_) => notifier.exportObservationsToCsv(),
          saveAction: (_) => notifier.saveObservationsCsvToFile(),
        );
    }
  }
```

Add the import for `csv_unit_mode_provider.dart`. `unawaited` comes from `dart:async`, which the page already imports.

- [ ] **Step 13: Run the notifier, dialog and Transfer tests**

Run: `flutter test test/features/settings/presentation/providers/ test/features/transfer/`
Expected: PASS.

- [ ] **Step 14: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/providers/csv_unit_mode_provider.dart lib/shared/widgets/csv_unit_mode_selector.dart lib/features/transfer/presentation/widgets/csv_export_dialog.dart lib/features/transfer/presentation/pages/transfer_page.dart lib/features/settings/presentation/providers/export_providers.dart lib/l10n test/features/settings/presentation/providers/csv_unit_mode_provider_test.dart test/features/transfer/presentation/widgets/csv_export_dialog_test.dart test/features/settings/presentation/providers/export_csv_units_test.dart
git commit -m "feat(csv): My units / Metric choice in the Transfer CSV dialog, remembered per device (#1813)"
```

---

### Task 10: Unit choice on the share/save sheet for dive detail and dive list CSV

**Files:**
- Modify: `lib/shared/widgets/export_destination_sheet.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_handleSingleDiveExport` and its CSV and UDDF callers, around lines 5540-5700)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_exportSelectedAs`, around lines 740-900)
- Test: `test/shared/widgets/export_destination_sheet_test.dart` (add cases)

**Interfaces:**
- Consumes: `CsvUnitModeSelector`, `csvUnitModeProvider` (Task 9), `CsvExportUnits.forMode`.
- Produces: `typedef ExportChoice = ({ExportDestination destination, UddfExportOptions options, CsvUnitMode csvUnitMode});` and `showExportDestinationSheetWithOptions(..., bool showCsvUnitsToggle = false, CsvUnitMode initialCsvUnitMode = CsvUnitMode.myUnits)`.

- [ ] **Step 1: Write the failing sheet tests**

Append to `test/shared/widgets/export_destination_sheet_test.dart` a host and two tests (add the `csv_export_units.dart` import):

```dart
Future<ValueGetter<Object?>> _pumpCsvHost(
  WidgetTester tester, {
  bool showCsvUnitsToggle = true,
}) async {
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showExportDestinationSheetWithOptions(
                context,
                title: 'Dive Log CSV',
                showCsvUnitsToggle: showCsvUnitsToggle,
                initialCsvUnitMode: CsvUnitMode.myUnits,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}
```

```dart
  testWidgets('the CSV unit choice is returned with the destination',
      (tester) async {
    final result = await _pumpCsvHost(tester);
    await tester.tap(find.text('Metric'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();
    final choice = result()! as ExportChoice;
    expect(choice.destination, ExportDestination.share);
    expect(choice.csvUnitMode, CsvUnitMode.metric);
  });

  testWidgets('no unit choice unless asked for', (tester) async {
    await _pumpCsvHost(tester, showCsvUnitsToggle: false);
    expect(find.text('My units'), findsNothing);
  });
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/shared/widgets/export_destination_sheet_test.dart`
Expected: FAIL (no `showCsvUnitsToggle` parameter).

- [ ] **Step 3: Extend the sheet**

In `lib/shared/widgets/export_destination_sheet.dart`:

1. Import `csv_export_units.dart` and `csv_unit_mode_selector.dart`.
2. Change the typedef and its doc comment:

```dart
/// What the user chose in an export destination sheet: where to deliver the
/// file, the UDDF content checkboxes as options, and, for a CSV, the unit
/// mode ([CsvUnitMode.myUnits] when the sheet did not offer the choice).
typedef ExportChoice = ({
  ExportDestination destination,
  UddfExportOptions options,
  CsvUnitMode csvUnitMode,
});
```

3. Add parameters `bool showCsvUnitsToggle = false, CsvUnitMode initialCsvUnitMode = CsvUnitMode.myUnits,` to `showExportDestinationSheetWithOptions`, and `var csvUnitMode = initialCsvUnitMode;` beside `var options = initialOptions;`. Mention the new flag in the function's doc comment: `[showCsvUnitsToggle] adds the My units / Metric choice for a CSV.`
4. Insert before the save `ListTile`:

```dart
              if (showCsvUnitsToggle) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: CsvUnitModeSelector(
                    value: csvUnitMode,
                    onChanged: (mode) =>
                        setSheetState(() => csvUnitMode = mode),
                  ),
                ),
                const Divider(height: 1),
              ],
```

5. Add `csvUnitMode: csvUnitMode,` to both popped records.

- [ ] **Step 4: Run the sheet tests**

Run: `flutter test test/shared/widgets/export_destination_sheet_test.dart`
Expected: PASS (old and new cases).

- [ ] **Step 5: Dive detail page**

In `dive_detail_page.dart`:

1. Change `_handleSingleDiveExport`'s callbacks to receive the whole choice, and add the CSV flag:

```dart
  Future<void> _handleSingleDiveExport(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<String> Function(ExportChoice choice) shareFn,
    required Future<String?> Function(ExportChoice choice) saveFn,
    bool offerRawData = false,
    bool offerDiveContent = false,
    bool offerCsvUnits = false,
  }) async {
    final choice = await showExportDestinationSheetWithOptions(
      context,
      title: title,
      showRawDataToggle: offerRawData,
      showDiveContentToggles: offerDiveContent,
      showCsvUnitsToggle: offerCsvUnits,
      initialCsvUnitMode: ref.read(csvUnitModeProvider),
    );
    if (choice == null || !context.mounted) return;
    if (offerCsvUnits) {
      unawaited(ref.read(csvUnitModeProvider.notifier).set(choice.csvUnitMode));
    }
    final destination = choice.destination;
```

   Delete the now-unused `final options = choice.options;` line and change the switch to `ExportDestination.share => await shareFn(choice)` / `ExportDestination.saveToFile => await saveFn(choice)`.

2. CSV caller (around line 5552):

```dart
                _handleSingleDiveExport(
                  context,
                  ref,
                  title: context.l10n.diveLog_export_csv,
                  offerCsvUnits: true,
                  shareFn: (choice) => ref
                      .read(exportServiceProvider)
                      .exportDivesToCsv([dive], units: csvUnitsFor(choice)),
                  saveFn: (choice) => ref
                      .read(exportServiceProvider)
                      .saveDivesCsvToFile(
                        [dive],
                        dialogTitle: saveTitle,
                        units: csvUnitsFor(choice),
                      ),
                );
```

   with a local helper defined just above it in the same builder: `CsvExportUnits csvUnitsFor(ExportChoice choice) => CsvExportUnits.forMode(choice.csvUnitMode, ref.read(settingsProvider));`

3. UDDF caller(s) (around lines 5576-5600): replace each `(options) async =>` with `(choice) async =>` and each use of `options` inside with `choice.options`. Search the file for every `_handleSingleDiveExport(` call and update any other caller the same way (`(_) =>` callbacks can stay as they are).
4. Add imports as needed: `dart:async` (for `unawaited`, if not already imported), `csv_export_units.dart`, `csv_unit_mode_provider.dart`, `settings_providers.dart`.

- [ ] **Step 6: Dive list bulk export**

In `dive_list_content.dart` `_exportSelectedAs`:

1. Pass the toggle:

```dart
    final choice = await showExportDestinationSheetWithOptions(
      context,
      title: formatLabel,
      showRawDataToggle: format == _BulkExportFormat.uddf,
      showDiveContentToggles: format == _BulkExportFormat.uddf,
      showCsvUnitsToggle: format == _BulkExportFormat.csv,
      initialCsvUnitMode: ref.read(csvUnitModeProvider),
    );
    if (choice == null || !mounted) return BulkActionOutcome.cancelled;
    if (format == _BulkExportFormat.csv) {
      unawaited(ref.read(csvUnitModeProvider.notifier).set(choice.csvUnitMode));
    }
    final csvUnits = CsvExportUnits.forMode(
      choice.csvUnitMode,
      ref.read(settingsProvider),
    );
```

2. In the `_BulkExportFormat.csv =>` arm, pass `units: csvUnits` to both `exportDivesToCsv(selectedDives, units: csvUnits)` and `saveDivesCsvToFile(selectedDives, dialogTitle: csvSaveTitle, units: csvUnits)`.
3. Add the imports (`csv_export_units.dart`, `csv_unit_mode_provider.dart`; `dart:async` if missing).

- [ ] **Step 7: Analyze and run the affected tests**

Run: `flutter analyze lib/shared lib/features/dive_log lib/features/transfer`
Expected: No issues.
Run: `flutter test test/shared/widgets/ test/features/dive_log/presentation/pages/ test/features/dive_log/presentation/widgets/`
Expected: PASS. A test that constructs `ExportChoice` records by hand now needs `csvUnitMode:`; add `csvUnitMode: CsvUnitMode.myUnits` there.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/shared/widgets/export_destination_sheet.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/shared/widgets/export_destination_sheet_test.dart
git commit -m "feat(csv): offer the unit choice for dive detail and dive list CSV exports (#1813)"
```

If Step 7 required changes to other test files, add those paths explicitly to the `git add`.

---
### Task 11: Submersion CSV formats and detection

**Files:**
- Create: `lib/core/services/export/csv/codec/submersion_csv_signatures.dart`
- Modify: `lib/features/universal_import/data/models/import_enums.dart`
- Modify: `lib/features/universal_import/data/services/format_detector.dart` (`_detectCsv`)
- Test: `test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`
- Test: `test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`

**Interfaces:**
- Consumes: `CsvHeader` (Task 3); the three writers (Tasks 7 and 8) in tests.
- Produces:
  - `enum SubmersionCsvKind { dives, sites, equipment }`; `abstract final class SubmersionCsvSignatures { static SubmersionCsvKind? match(List<String> headers); }`
  - `ImportFormat.submersionDivesCsv`, `ImportFormat.submersionSitesCsv`, `ImportFormat.submersionEquipmentCsv` (supported; display names `Submersion Dives CSV`, `Submersion Sites CSV`, `Submersion Equipment CSV`)

- [ ] **Step 1: Write the failing tests**

`test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/submersion_csv_signatures.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';

import '../csv_dives_writer_test.dart' show imperial;
import '../csv_test_fixtures.dart';

List<String> _headers(String csv) => csv.split('\r\n').first.split(',');

void main() {
  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    final label = units.isMetric ? 'metric' : 'my units';

    test('dives export matches in $label mode', () {
      final csv = CsvDivesWriter(units).write(goldenDives());
      expect(SubmersionCsvSignatures.match(_headers(csv)), SubmersionCsvKind.dives);
    });

    test('sites export matches in $label mode', () {
      final csv = CsvSitesWriter(units).write(goldenSites());
      expect(SubmersionCsvSignatures.match(_headers(csv)), SubmersionCsvKind.sites);
    });

    test('equipment export matches in $label mode', () {
      final csv = CsvEquipmentWriter(units).write(goldenEquipment());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.equipment,
      );
    });
  }

  test('other apps\' CSVs do not match', () {
    expect(
      SubmersionCsvSignatures.match([
        'Dive Number', 'Date', 'Time', 'Site', 'Max Depth', 'Bottom Time',
        'Water Temp', 'Start Pressure',
      ]),
      isNull,
    );
    expect(SubmersionCsvSignatures.match(['Date', 'Time', 'Depth']), isNull);
  });
}
```

`_headers` splits on `,` naively; that is safe here only because `MMM D, YYYY` is not in `imperial` (it uses `MM/DD/YYYY`). Keep it that way.

`test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const detector = FormatDetector();

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    test('each export is detected as its own format '
        '(${units.isMetric ? 'metric' : 'my units'})', () {
      final dives = detector.detect(
        _bytes(CsvDivesWriter(units).write(goldenDives())),
      );
      expect(dives.format, ImportFormat.submersionDivesCsv);
      expect(dives.sourceApp, SourceApp.submersion);
      expect(dives.isFormatSupported, isTrue);
      expect(
        detector.detect(_bytes(CsvSitesWriter(units).write(goldenSites()))).format,
        ImportFormat.submersionSitesCsv,
      );
      expect(
        detector
            .detect(_bytes(CsvEquipmentWriter(units).write(goldenEquipment())))
            .format,
        ImportFormat.submersionEquipmentCsv,
      );
    });
  }

  test('a Submersion-like CSV without the full signature stays generic CSV',
      () {
    final result = detector.detect(
      _bytes(
        'Dive Number,Date,Time,Site,Max Depth,Bottom Time,Water Temp,'
        'Start Pressure\n1,2024-01-01,09:00,Reef,20,40,24,200\n',
      ),
    );
    expect(result.format, ImportFormat.csv);
  });
}
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `flutter test test/core/services/export/csv/codec/submersion_csv_signatures_test.dart test/features/universal_import/data/services/format_detector_submersion_csv_test.dart`
Expected: FAIL (missing file; unknown enum values).

- [ ] **Step 3: Implement the signatures**

```dart
import 'package:submersion/core/services/export/csv/codec/csv_header.dart';

/// Which of Submersion's own CSV exports a file is.
enum SubmersionCsvKind { dives, sites, equipment }

/// Recognises Submersion's CSV exports by their full set of column base
/// names (unit and format suffixes stripped, case ignored), so a file
/// exported in either mode, in any unit system, is recognised, and a CSV
/// from another app cannot match by accident.
abstract final class SubmersionCsvSignatures {
  static const _dives = {
    'dive number', 'name', 'date', 'time', 'site', 'location', 'max depth',
    'avg depth', 'bottom time', 'runtime', 'water temp', 'air temp',
    'visibility', 'visibility rating', 'dive type', 'buddy', 'dive master',
    'rating', 'start pressure', 'end pressure', 'tank volume', 'o2 %',
    'dive computer', 'serial number', 'firmware version', 'notes',
    'wind speed', 'wind direction', 'cloud cover', 'precipitation',
    'humidity', 'weather description',
  };

  static const _sites = {
    'name', 'country', 'region', 'latitude', 'longitude', 'max depth',
    'water type', 'current', 'entry type', 'rating', 'description', 'notes',
  };

  static const _equipment = {
    'name', 'type', 'brand', 'model', 'serial number', 'size', 'thickness',
    'purchase date', 'last service', 'next service due', 'buoyancy',
    'dry weight', 'attributes', 'components', 'active', 'notes',
  };

  /// The export [headers] came from, or null.
  static SubmersionCsvKind? match(List<String> headers) {
    final bases = {
      for (final h in headers)
        if (!h.trim().toLowerCase().startsWith('custom:'))
          CsvHeader.parse(h).key,
    };
    if (bases.containsAll(_dives)) return SubmersionCsvKind.dives;
    if (bases.containsAll(_equipment)) return SubmersionCsvKind.equipment;
    if (bases.containsAll(_sites)) return SubmersionCsvKind.sites;
    return null;
  }
}
```

`dart format` will reflow the set literals one entry per line; that is fine.

- [ ] **Step 4: Add the formats**

In `lib/features/universal_import/data/models/import_enums.dart`:

1. Add after `csv,` in `enum ImportFormat`:

```dart
  // Submersion's own CSV exports (issue #1813): self-describing, so they
  // skip Map Fields and parse like UDDF.
  submersionDivesCsv,
  submersionSitesCsv,
  submersionEquipmentCsv,
```

2. In `displayName` add:

```dart
    submersionDivesCsv => 'Submersion Dives CSV',
    submersionSitesCsv => 'Submersion Sites CSV',
    submersionEquipmentCsv => 'Submersion Equipment CSV',
```

3. In `isSupported`, add `submersionDivesCsv || submersionSitesCsv || submersionEquipmentCsv ||` to the `true` arm.
4. In `SourceOverrideOption.supported`, add after the `Submersion (UDDF)` entry:

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.submersion,
      format: ImportFormat.submersionDivesCsv,
      displayName: 'Submersion (Dives CSV)',
    ),
    SourceOverrideOption(
      sourceApp: SourceApp.submersion,
      format: ImportFormat.submersionSitesCsv,
      displayName: 'Submersion (Sites CSV)',
    ),
    SourceOverrideOption(
      sourceApp: SourceApp.submersion,
      format: ImportFormat.submersionEquipmentCsv,
      displayName: 'Submersion (Equipment CSV)',
    ),
```

Until Tasks 13 to 15 add parsers, `parserForFormat` returns its `PlaceholderParser` default for these formats; nothing reaches it yet because no step routes a file there before those tasks land in the same PR.

- [ ] **Step 5: Detect them**

In `format_detector.dart`, import `submersion_csv_signatures.dart`, and in `_detectCsv` insert directly after `if (headers.isEmpty || headers.length < 2) return null;`:

```dart
    // Submersion's own exports carry their full column set, so they are
    // recognised exactly and routed to their dedicated parsers (#1813).
    final rawHeaders = rows.first.map((e) => e.toString().trim()).toList();
    final kind = SubmersionCsvSignatures.match(rawHeaders);
    if (kind != null) {
      return DetectionResult(
        format: switch (kind) {
          SubmersionCsvKind.dives => ImportFormat.submersionDivesCsv,
          SubmersionCsvKind.sites => ImportFormat.submersionSitesCsv,
          SubmersionCsvKind.equipment => ImportFormat.submersionEquipmentCsv,
        },
        sourceApp: SourceApp.submersion,
        confidence: 1.0,
        csvHeaders: rawHeaders,
      );
    }
```

- [ ] **Step 6: Run the new and existing detector tests**

Run: `flutter test test/core/services/export/csv/codec/submersion_csv_signatures_test.dart test/features/universal_import/`
Expected: PASS. If an existing universal_import test enumerates `ImportFormat.values` or `SourceOverrideOption.supported` with a fixed count, update that count and say so in the commit body.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/services/export/csv/codec lib/features/universal_import test/core/services/export/csv/codec test/features/universal_import/data/services
git add lib/core/services/export/csv/codec/submersion_csv_signatures.dart lib/features/universal_import/data/models/import_enums.dart lib/features/universal_import/data/services/format_detector.dart test/core/services/export/csv/codec/submersion_csv_signatures_test.dart test/features/universal_import/data/services/format_detector_submersion_csv_test.dart
git commit -m "feat(import): recognise Submersion's own dives, sites and equipment CSVs (#1813)"
```

---

### Task 12: CSV table reader and Location text

**Files:**
- Create: `lib/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart`
- Create: `lib/features/universal_import/data/parsers/submersion_csv/site_location_text.dart`
- Test: `test/features/universal_import/data/parsers/submersion_csv/submersion_csv_table_test.dart`
- Test: `test/features/universal_import/data/parsers/submersion_csv/site_location_text_test.dart`

**Interfaces:**
- Consumes: `CsvHeader`, `CsvUnit`, `CsvColumn`, `parseCsvDate`, `parseCsvTime`, `dateFormatForSuffix`, `timeFormatForSuffix`, `unsanitizeCsvField`.
- Produces:
  - `class SubmersionCsvTable { factory SubmersionCsvTable.parse(Uint8List bytes); List<List<String>> rows; String? text(List<String> row, String base); double? number(List<String> row, String base); int? integer(List<String> row, String base); CsvUnit? unitOf(CsvColumn column); double? quantity(List<String> row, CsvColumn column); DateFormatPreference? dateFormatOf(String base); DateTime? date(List<String> row, String base); ({int hour, int minute})? time(List<String> row, String base); List<({String key, String value})> customCells(List<String> row); List<String> unreadableUnitColumns(List<CsvColumn> columns); }`
  - `({String? region, String? country}) parseSiteLocationText(String? text)`

- [ ] **Step 1: Write the failing tests**

`submersion_csv_table_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

SubmersionCsvTable _table(String csv) =>
    SubmersionCsvTable.parse(Uint8List.fromList(utf8.encode(csv)));

void main() {
  test('reads cells by base name and converts by the header unit', () {
    final t = _table(
      '\u{FEFF}Max Depth (ft),Water Temp (°F),Serial Number\r\n'
      '100.0,80,00123\r\n',
    );
    final row = t.rows.single;
    expect(t.quantity(row, CsvColumns.maxDepth), closeTo(30.48, 1e-9));
    expect(t.quantity(row, CsvColumns.waterTemp), closeTo(26.667, 1e-3));
    // Numbers are not parsed by the CSV reader, so leading zeros survive.
    expect(t.text(row, 'serial number'), '00123');
    expect(t.unitOf(CsvColumns.maxDepth), CsvUnit.feet);
  });

  test('a header with no unit is metric, a blank cell is null', () {
    final t = _table('Max Depth (m),Date\n,2025-03-15\n');
    expect(t.quantity(t.rows.single, CsvColumns.maxDepth), isNull);
    expect(t.unitOf(CsvColumns.maxDepth), CsvUnit.meters);
    expect(t.date(t.rows.single, 'Date'), DateTime.utc(2025, 3, 15));
  });

  test('dates and times read with the header format', () {
    final t = _table(
      '"Date (MMM D, YYYY)",Time (12-hour)\n"Mar 5, 2025",2:07 PM\n',
    );
    expect(t.dateFormatOf('Date'), DateFormatPreference.mmmDYYYY);
    expect(t.date(t.rows.single, 'Date'), DateTime.utc(2025, 3, 5));
    expect(t.time(t.rows.single, 'Time'), (hour: 14, minute: 7));
  });

  test('custom columns are unsanitized, blank values dropped', () {
    final t = _table("Notes,custom:Boat,custom:Formula,custom:Empty\nx,Sea Dog,'=1+1,\n");
    expect(t.customCells(t.rows.single), [
      (key: 'Boat', value: 'Sea Dog'),
      (key: 'Formula', value: '=1+1'),
    ]);
  });

  test('a unit that does not fit the column is reported, not converted', () {
    final t = _table('Max Depth (psi)\n10\n');
    expect(t.quantity(t.rows.single, CsvColumns.maxDepth), isNull);
    expect(t.unreadableUnitColumns([CsvColumns.maxDepth]), ['Max Depth (psi)']);
  });

  test('blank lines are skipped', () {
    expect(_table('Name\nA\n\n,\nB\n').rows.length, 2);
  });
}
```

`site_location_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/site_location_text.dart';

void main() {
  test('locality prefix dropped, region and country split on the last comma',
      () {
    expect(parseSiteLocationText('San Pedro · Lighthouse Reef, Belize'),
        (region: 'Lighthouse Reef', country: 'Belize'));
  });

  test('a region containing a comma keeps it', () {
    expect(parseSiteLocationText('Bay Islands, Roatan, Honduras'),
        (region: 'Bay Islands, Roatan', country: 'Honduras'));
  });

  test('a single part is read as the country', () {
    expect(parseSiteLocationText('Egypt'), (region: null, country: 'Egypt'));
  });

  test('blank is empty', () {
    expect(parseSiteLocationText('  '), (region: null, country: null));
    expect(parseSiteLocationText(null), (region: null, country: null));
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/`
Expected: FAIL (missing files).

- [ ] **Step 3: Implement `submersion_csv_table.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_header.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';

/// A Submersion CSV export read as text cells, looked up by column base
/// name, with every unit and date/time format taken from the headers. A
/// header with no suffix is metric and ISO, which is what a Metric-mode
/// file (and every file before #1813) contains.
class SubmersionCsvTable {
  SubmersionCsvTable._(this._headers, this.rows);

  factory SubmersionCsvTable.parse(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\u{FEFF}')) text = text.substring(1);
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // shouldParseNumbers: false keeps "00123" and "0.5588" exactly as
    // written; every cell is parsed by the column that owns it.
    final all = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalized);
    if (all.isEmpty) return SubmersionCsvTable._(const [], const []);
    final headers = [for (final h in all.first) '$h'.trim()];
    final rows = [
      for (final r in all.skip(1))
        if (r.any((c) => '$c'.trim().isNotEmpty)) [for (final c in r) '$c'],
    ];
    return SubmersionCsvTable._(headers, rows);
  }

  final List<String> _headers;
  final List<List<String>> rows;

  static const _customPrefix = 'custom:';

  bool _isCustom(String header) =>
      header.toLowerCase().startsWith(_customPrefix);

  late final Map<String, int> _indexByKey = () {
    final index = <String, int>{};
    for (var i = 0; i < _headers.length; i++) {
      if (_isCustom(_headers[i])) continue;
      index.putIfAbsent(CsvHeader.parse(_headers[i]).key, () => i);
    }
    return index;
  }();

  CsvHeader? _header(String base) {
    final i = _indexByKey[base.toLowerCase()];
    return i == null ? null : CsvHeader.parse(_headers[i]);
  }

  /// The trimmed cell under [base], or null when blank or absent.
  String? text(List<String> row, String base) {
    final i = _indexByKey[base.toLowerCase()];
    if (i == null || i >= row.length) return null;
    final value = row[i].trim();
    return value.isEmpty ? null : value;
  }

  double? number(List<String> row, String base) {
    final value = text(row, base);
    return value == null ? null : double.tryParse(value);
  }

  int? integer(List<String> row, String base) {
    final value = text(row, base);
    if (value == null) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  /// The unit [column]'s header names (metric when it names none), or null
  /// when the column is absent or its unit does not measure its quantity.
  CsvUnit? unitOf(CsvColumn column) {
    final header = _header(column.base);
    if (header == null) return null;
    final suffix = header.suffix;
    if (suffix == null) return CsvUnit.metricFor(column.quantity);
    final unit = CsvUnit.fromSymbol(suffix);
    return unit?.quantity == column.quantity ? unit : null;
  }

  /// [column]'s cell converted to canonical metric.
  double? quantity(List<String> row, CsvColumn column) {
    final unit = unitOf(column);
    final value = number(row, column.base);
    if (unit == null || value == null) return null;
    return unit.toMetric(value);
  }

  /// Headers among [columns] that are present but name a unit that cannot
  /// be read, for one warning per column.
  List<String> unreadableUnitColumns(List<CsvColumn> columns) => [
    for (final column in columns)
      if (_header(column.base) != null && unitOf(column) == null)
        _header(column.base).toString(),
  ];

  DateFormatPreference? dateFormatOf(String base) =>
      dateFormatForSuffix(_header(base)?.suffix);

  DateTime? date(List<String> row, String base) {
    final value = text(row, base);
    return value == null ? null : parseCsvDate(value, dateFormatOf(base));
  }

  ({int hour, int minute})? time(List<String> row, String base) {
    final value = text(row, base);
    return value == null
        ? null
        : parseCsvTime(value, timeFormatForSuffix(_header(base)?.suffix));
  }

  /// `custom:<key>` cells with a value, in column order.
  List<({String key, String value})> customCells(List<String> row) => [
    for (var i = 0; i < _headers.length && i < row.length; i++)
      if (_isCustom(_headers[i]) && row[i].trim().isNotEmpty)
        (
          key: _headers[i].substring(_customPrefix.length),
          value: unsanitizeCsvField(row[i]),
        ),
  ];
}
```

Note: `row[i]` for a custom cell is not trimmed before unsanitizing so a value's own spaces survive; the `isNotEmpty` test uses the trimmed form only to skip blank cells.

- [ ] **Step 4: Implement `site_location_text.dart`**

```dart
/// Best-effort split of a dives CSV Location cell, written from
/// `DiveSite.locationString` as `[city or island · ]region, country`, into
/// region and country. The locality prefix is dropped; a cell with no comma
/// is read as the country. Used only when a dives CSV creates a site the
/// library does not have; an existing site is never changed by it.
({String? region, String? country}) parseSiteLocationText(String? text) {
  var rest = text?.trim() ?? '';
  final dot = rest.lastIndexOf(' · ');
  if (dot >= 0) rest = rest.substring(dot + 3).trim();
  if (rest.isEmpty) return (region: null, country: null);
  final comma = rest.lastIndexOf(',');
  if (comma < 0) return (region: null, country: rest);
  final region = rest.substring(0, comma).trim();
  final country = rest.substring(comma + 1).trim();
  return (
    region: region.isEmpty ? null : region,
    country: country.isEmpty ? null : country,
  );
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/universal_import/data/parsers/submersion_csv test/features/universal_import/data/parsers/submersion_csv
git add lib/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart lib/features/universal_import/data/parsers/submersion_csv/site_location_text.dart test/features/universal_import/data/parsers/submersion_csv/submersion_csv_table_test.dart test/features/universal_import/data/parsers/submersion_csv/site_location_text_test.dart
git commit -m "feat(import): read Submersion CSV cells by column, unit and date format (#1813)"
```

---

### Task 13: Close the importer gaps

**Files:**
- Create: `lib/features/dive_import/data/services/import_map_readers.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_importEquipment` ~641-723, site create ~1353-1371 and overwrite ~1279-1295, `Dive(...)` construction ~2167-2240)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (expose `payloadToUddfResult`)
- Test: `test/features/dive_import/data/services/import_map_readers_test.dart`
- Test: `test/features/dive_import/data/services/uddf_entity_importer_csv_fields_test.dart`

**Interfaces:**
- Produces:
  - `List<EquipmentAttribute> equipmentAttributesFromImport(Object? raw, {required String equipmentId, required String Function() newId, Set<String> takenKeys = const {}})`; each input entry `{'key': String, 'isCustom': bool, 'valueText': String?, 'valueNum': num?}`
  - `List<DiveCustomField> diveCustomFieldsFromImport(Object? raw)`; each input entry `{'key': String, 'value': String}`
  - Importer reads site `'entryMethod'` (enum `.name`), equipment `'attributes'`, dive `'windSpeed'`, `'windDirection'`, `'cloudCover'`, `'precipitation'` (enum `.name`), `'humidity'`, `'weatherDescription'`, `'customFields'`
  - `@visibleForTesting static UddfImportResult UniversalAdapter.payloadToUddfResult(ImportPayload payload)`

- [ ] **Step 1: Write the failing reader test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/import_map_readers.dart';

void main() {
  var n = 0;
  String newId() => 'id-${n++}';

  test('curated attributes get deterministic ids, custom ones new ids', () {
    final attrs = equipmentAttributesFromImport(
      [
        {'key': 'hose_length_m', 'isCustom': false, 'valueNum': 0.5588},
        {'key': 'Batch', 'isCustom': true, 'valueText': 'B-77'},
      ],
      equipmentId: 'e1',
      newId: newId,
    );
    expect(attrs[0].id, 'attr_e1_hose_length_m');
    expect(attrs[0].valueNum, 0.5588);
    expect(attrs[1].isCustom, isTrue);
    expect(attrs[1].id, startsWith('id-'));
    expect(attrs[1].valueText, 'B-77');
  });

  test('malformed, empty and taken entries are skipped', () {
    final attrs = equipmentAttributesFromImport(
      [
        'nope',
        {'key': '', 'valueText': 'x'},
        {'key': 'size', 'valueText': 'L'},
        {'key': 'suit_style'},
        {'key': 'suit_style', 'valueText': 'full', 'valueNum': 'bad'},
      ],
      equipmentId: 'e1',
      newId: newId,
      takenKeys: {'size'},
    );
    expect(attrs.map((a) => a.key), ['suit_style']);
    expect(attrs.single.valueNum, isNull);
  });

  test('custom fields keep order and skip malformed entries', () {
    final fields = diveCustomFieldsFromImport([
      {'key': 'Boat', 'value': 'Sea Dog'},
      {'key': 'Formula', 'value': '=1+1'},
      {'value': 'orphan'},
      7,
    ]);
    expect(fields.map((f) => (f.key, f.value, f.sortOrder)), [
      ('Boat', 'Sea Dog', 0),
      ('Formula', '=1+1', 1),
    ]);
    expect(diveCustomFieldsFromImport(null), isEmpty);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/features/dive_import/data/services/import_map_readers_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `import_map_readers.dart`**

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Equipment attribute rows from an import map's `attributes` list. Input
/// is untrusted: entries that are not maps, have a blank key, carry no
/// value, or repeat a key already taken ([takenKeys], or an earlier entry)
/// are skipped rather than aborting the import. Curated rows get their
/// deterministic id; custom rows get [newId].
List<EquipmentAttribute> equipmentAttributesFromImport(
  Object? raw, {
  required String equipmentId,
  required String Function() newId,
  Set<String> takenKeys = const {},
}) {
  if (raw is! List) return const [];
  final taken = {...takenKeys};
  final result = <EquipmentAttribute>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final key = entry['key'];
    if (key is! String || key.trim().isEmpty || taken.contains(key)) continue;
    final text = entry['valueText'] is String
        ? entry['valueText'] as String
        : null;
    final number = entry['valueNum'] is num
        ? (entry['valueNum'] as num).toDouble()
        : null;
    if ((text == null || text.trim().isEmpty) && number == null) continue;
    final isCustom = entry['isCustom'] == true;
    result.add(
      isCustom
          ? EquipmentAttribute(
              id: newId(),
              equipmentId: equipmentId,
              key: key,
              isCustom: true,
              valueText: text,
              valueNum: number,
              sortOrder: result.length,
            )
          : EquipmentAttribute.curated(
              equipmentId: equipmentId,
              key: key,
              valueText: text,
              valueNum: number,
            ),
    );
    taken.add(key);
  }
  return result;
}

/// Dive custom fields from an import map's `customFields` list of
/// `{key, value}` maps, in order. Ids are left empty for the repository to
/// assign.
List<DiveCustomField> diveCustomFieldsFromImport(Object? raw) {
  if (raw is! List) return const [];
  final result = <DiveCustomField>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final key = entry['key'];
    final value = entry['value'];
    if (key is! String || key.trim().isEmpty) continue;
    result.add(
      DiveCustomField(
        id: '',
        key: key,
        value: value is String ? value : '',
        sortOrder: result.length,
      ),
    );
  }
  return result;
}
```

- [ ] **Step 4: Run the reader test**

Run: `flutter test test/features/dive_import/data/services/import_map_readers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing importer test**

`test/features/dive_import/data/services/uddf_entity_importer_csv_fields_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// Fields the Submersion CSV importers hand the entity importer that no
/// other format carried before #1813.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<String> importData(UddfImportResult data) async {
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    return diverId;
  }

  test('a site keeps its entry method', () async {
    final diverId = await importData(
      const UddfImportResult(
        sites: [
          {'uddfId': 's1', 'name': 'Reef', 'entryMethod': 'giantStride'},
        ],
      ),
    );
    final site = (await SiteRepository().getAllSites(diverId: diverId)).single;
    expect(site.entryMethod, EntryMethod.giantStride);
  });

  test('equipment keeps every attribute, not only size', () async {
    final diverId = await importData(
      const UddfImportResult(
        equipment: [
          {
            'uddfId': 'e1',
            'name': 'Hose',
            'type': 'hose',
            'size': 'L',
            'attributes': [
              {'key': 'hose_length_m', 'isCustom': false, 'valueNum': 0.5588},
              {'key': 'Batch', 'isCustom': true, 'valueText': 'B-77'},
            ],
          },
        ],
      ),
    );
    final item = (await EquipmentRepository().getAllEquipment(
      diverId: diverId,
    )).single;
    expect(item.size, 'L');
    expect(item.attrNum('hose_length_m'), 0.5588);
    expect(
      item.attributes.where((a) => a.isCustom).single.valueText,
      'B-77',
    );
  });

  test('a dive keeps its weather and custom fields', () async {
    await importData(
      UddfImportResult(
        dives: [
          {
            'dateTime': DateTime.utc(2025, 3, 15, 9, 5),
            'maxDepth': 20.0,
            'windSpeed': 4.2,
            'windDirection': 'northEast',
            'cloudCover': 'partlyCloudy',
            'precipitation': 'none',
            'humidity': 71.0,
            'weatherDescription': 'Sunny',
            'customFields': [
              {'key': 'Boat', 'value': 'Sea Dog'},
            ],
          },
        ],
      ),
    );
    final id = (await DiveRepository().getAllDives()).single.id;
    final dive = (await DiveRepository().getDiveById(id))!;
    expect(dive.windSpeed, 4.2);
    expect(dive.windDirection, CurrentDirection.northEast);
    expect(dive.cloudCover, CloudCover.partlyCloudy);
    expect(dive.precipitation, Precipitation.none);
    expect(dive.humidity, 71.0);
    expect(dive.weatherDescription, 'Sunny');
    expect(dive.customFields.single.key, 'Boat');
    expect(dive.customFields.single.value, 'Sea Dog');
  });
}
```

- [ ] **Step 6: Run to confirm failure**

Run: `flutter test test/features/dive_import/data/services/uddf_entity_importer_csv_fields_test.dart`
Expected: FAIL on all three (entry method null, attribute missing, weather null).

- [ ] **Step 7: Patch `UddfEntityImporter`**

Import `import_map_readers.dart`, then:

1. `_importEquipment`: replace the `attributes: [ ... ],` argument of `EquipmentItem(...)` with:

```dart
        attributes: [
          if (size != null)
            EquipmentAttribute.curated(
              equipmentId: newId,
              key: EquipmentAttrKeys.size,
              valueText: size,
            ),
          // Every other attribute the source carried (the Submersion CSV
          // writes them all; issue #1813). A size in the list defers to the
          // dedicated key above.
          ...equipmentAttributesFromImport(
            equipData['attributes'],
            equipmentId: newId,
            newId: _uuid.v4,
            takenKeys: {if (size != null) EquipmentAttrKeys.size},
          ),
        ],
```

   and declare just above `final item = EquipmentItem(`:

```dart
      final sizeText = (equipData['size'] as String?)?.trim();
      final size = sizeText == null || sizeText.isEmpty ? null : sizeText;
```

   (`_uuid.v4` is a tear-off of the importer's `Uuid` instance; if `_uuid` is not a `Uuid`, use `() => _uuid.v4()`.)

2. Site create path (`final newSite = DiveSite(`): add `entryMethod: _parseEnum(siteData['entryMethod'], EntryMethod.values),` after `altitude:`.
3. Site overwrite path (`existing.copyWith(`): add the same `entryMethod:` argument after `altitude:`.
4. `Dive(...)` construction: after `altitude: asDoubleOrNull(diveData['altitude']),` add:

```dart
        // Weather and custom fields (issue #1813): the Submersion dives CSV
        // carries them; createDive already persists all of them.
        windSpeed: asDoubleOrNull(diveData['windSpeed']),
        windDirection: _parseEnum(
          diveData['windDirection'],
          CurrentDirection.values,
        ),
        cloudCover: _parseEnum(diveData['cloudCover'], CloudCover.values),
        precipitation: _parseEnum(
          diveData['precipitation'],
          Precipitation.values,
        ),
        humidity: asDoubleOrNull(diveData['humidity']),
        weatherDescription: diveData['weatherDescription'] as String?,
        customFields: diveCustomFieldsFromImport(diveData['customFields']),
```

   If the `Dive(...)` call already passes any of these arguments, keep one and report the duplicate.

5. In `universal_adapter.dart`, rename `_payloadToUddfResult` to `payloadToUddfResult`, annotate it `@visibleForTesting`, and update its one caller (line ~522). `flutter/material.dart` already exports the annotation.

- [ ] **Step 8: Run the importer tests**

Run: `flutter test test/features/dive_import/ test/features/import_wizard/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/features/dive_import lib/features/import_wizard test/features/dive_import
git add lib/features/dive_import/data/services/import_map_readers.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/dive_import/data/services/import_map_readers_test.dart test/features/dive_import/data/services/uddf_entity_importer_csv_fields_test.dart
git commit -m "fix(import): keep site entry method, equipment attributes, dive weather and custom fields (#1813)"
```

---
### Task 14: Sites CSV parser

**Files:**
- Create: `lib/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Test: `test/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser_test.dart`

**Interfaces:**
- Consumes: `SubmersionCsvTable` (Task 12), `enumByDisplayName` (Task 2), `CsvColumns`.
- Produces: `class SubmersionSitesCsvParser implements ImportParser` (const constructor); site maps with keys `uddfId` (`csv-site-<row>`), `name`, `country`, `region`, `latitude`/`longitude` (`double`), `maxDepth` (`double`), `waterType`/`entryMethod` (enum `.name`), `rating` (`double`), `description`, `notes`. Blank cells produce no key.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionSitesCsv),
      isA<SubmersionSitesCsvParser>(),
    );
  });

  test('an imperial My units file comes back in metric with enum names',
      () async {
    final csv = CsvSitesWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(goldenSites());
    final payload = await const SubmersionSitesCsvParser().parse(_bytes(csv));
    final sites = payload.entitiesOf(ImportEntityType.sites);
    expect(sites, hasLength(2));
    final blue = sites.first;
    expect(blue['name'], 'Blue Hole');
    expect(blue['country'], 'Belize');
    expect(blue['latitude'], 17.316);
    expect(blue['longitude'], -87.535);
    expect(blue['maxDepth'] as double, closeTo(40.5, 0.02));
    expect(blue['waterType'], 'salt');
    expect(blue['entryMethod'], 'boat');
    expect(blue['rating'], 4.5);
    expect(blue['notes'], 'Line 1 Line 2');
    expect(blue.containsKey('uddfId'), isTrue);
    // A blank cell is absent, so an overwrite keeps the existing value.
    expect(sites.last.keys, unorderedEquals(['uddfId', 'name']));
  });

  test('a row with no name is skipped with an error warning', () async {
    final payload = await const SubmersionSitesCsvParser().parse(
      _bytes(
        'Name,Country,Region,Latitude,Longitude,Max Depth (m),Water Type,'
        'Current,Entry Type,Rating,Description,Notes\n'
        ',Belize,,,,,,,,,,\n',
      ),
    );
    expect(payload.entitiesOf(ImportEntityType.sites), isEmpty);
    expect(payload.warnings.single.severity, ImportWarningSeverity.error);
  });
}
```

Add `import 'package:submersion/features/universal_import/data/models/import_warning.dart';` for `ImportWarningSeverity`.

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the parser**

```dart
import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's sites CSV export (either unit mode) back into site
/// maps for the entity importer.
class SubmersionSitesCsvParser implements ImportParser {
  const SubmersionSitesCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionSitesCsv,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.maxDepth,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.sites,
        ),
    ];
    final sites = <Map<String, dynamic>>[];

    for (final (i, row) in table.rows.indexed) {
      final name = table.text(row, 'Name');
      if (name == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no site name and was skipped',
            entityType: ImportEntityType.sites,
            itemIndex: i,
            field: 'Name',
          ),
        );
        continue;
      }
      final lat = table.number(row, 'Latitude');
      final lon = table.number(row, 'Longitude');
      sites.add(
        <String, dynamic>{
          'uddfId': 'csv-site-$i',
          'name': name,
          'country': table.text(row, 'Country'),
          'region': table.text(row, 'Region'),
          if (lat != null && lon != null) ...{'latitude': lat, 'longitude': lon},
          'maxDepth': table.quantity(row, CsvColumns.maxDepth),
          'waterType': enumByDisplayName(
            WaterType.values,
            (v) => v.displayName,
            table.text(row, 'Water Type'),
          )?.name,
          'entryMethod': enumByDisplayName(
            EntryMethod.values,
            (v) => v.displayName,
            table.text(row, 'Entry Type'),
          )?.name,
          'rating': table.number(row, 'Rating'),
          'description': table.text(row, 'Description'),
          'notes': table.text(row, 'Notes'),
        }..removeWhere((_, value) => value == null),
      );
    }

    return ImportPayload(
      entities: {if (sites.isNotEmpty) ImportEntityType.sites: sites},
      warnings: warnings,
    );
  }
}
```

- [ ] **Step 4: Register it**

In `parser_registry.dart`, import the parser and add `ImportFormat.submersionSitesCsv => const SubmersionSitesCsvParser(),` to the switch. Update the function's doc comment: `/// Parser for a self-describing format. Generic CSV needs per-file mapping state and stays in the notifier's _parserFor; Submersion's own CSV exports are self-describing and are routed here.`

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/universal_import test/features/universal_import/data/parsers/submersion_csv
git add lib/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart lib/features/universal_import/data/parsers/parser_registry.dart test/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser_test.dart
git commit -m "feat(import): import Submersion's sites CSV (#1813)"
```

---

### Task 15: Equipment CSV parser

**Files:**
- Create: `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Test: `test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart`

**Interfaces:**
- Consumes: `SubmersionCsvTable`, `splitAttributePairs`, `parseAttributePair`, `enumByDisplayName`, `parsePrimaryThickness`, `CsvColumns`, `EquipmentAttrKeys`.
- Produces: `class SubmersionEquipmentCsvParser implements ImportParser` (const); equipment maps with `uddfId` (`csv-equipment-<row>`), `name`, `type` (`EquipmentType.name`), `brand`, `model`, `serialNumber`, `size`, `purchaseDate`/`lastServiceDate` (`DateTime`, local midnight), `serviceIntervalDays` (`int`), `isActive` (`bool`), `notes`, `attributes` (`List<Map<String, dynamic>>` of `{key, isCustom, valueText, valueNum}`), `components` (`List<Map<String, dynamic>>` of `{componentRef, role, sortOrder}`).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

Map<String, dynamic> _byName(List<Map<String, dynamic>> items, String name) =>
    items.firstWhere((e) => e['name'] == name);

Map<String, dynamic> _attr(Map<String, dynamic> item, String key) =>
    (item['attributes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (a) => a['key'] == key,
    );

void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionEquipmentCsv),
      isA<SubmersionEquipmentCsvParser>(),
    );
  });

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    test('reads every column back (${units.isMetric ? 'metric' : 'my units'})',
        () async {
      final csv = CsvEquipmentWriter(units).write(
        roundTripEquipment(),
        componentNames: goldenComponentNames(),
      );
      final payload =
          await const SubmersionEquipmentCsvParser().parse(_bytes(csv));
      expect(payload.warnings, isEmpty);
      final items = payload.entitiesOf(ImportEntityType.equipment);
      expect(items, hasLength(7));

      final suit = _byName(items, 'Suit');
      expect(suit['type'], 'wetsuit');
      expect(suit['size'], 'L');
      expect(_attr(suit, 'thickness_mm')['valueText'], '5/4');
      expect(_attr(suit, 'buoyancy_kg')['valueNum'] as double,
          closeTo(2.5, 0.005));
      expect(_attr(suit, 'suit_style')['valueText'], 'full');

      final hose = _byName(items, 'Long hose');
      expect(_attr(hose, 'hose_length_m')['valueNum'] as double,
          closeTo(0.5588, 0.002));

      final tank = _byName(items, 'AL80');
      expect(tank['serialNumber'], '00123');
      expect(_attr(tank, 'volume_l')['valueNum'] as double,
          closeTo(11.1, 0.05));

      final cell = _byName(items, 'Cell A');
      expect(_attr(cell, 'installed_date')['valueNum'],
          DateTime(2025, 3, 15).millisecondsSinceEpoch.toDouble());
      expect(_attr(cell, 'Batch')['isCustom'], isTrue);

      final first = _byName(items, 'Mk25');
      expect(first['type'], 'firstStage');
      expect(first['purchaseDate'], DateTime(2023, 6, 1));
      expect(first['lastServiceDate'], DateTime(2025, 1, 10));
      expect(first['serviceIntervalDays'], 365);
      expect(first['isActive'], isFalse);

      final reg = _byName(items, 'Primary reg');
      final parts = (reg['components'] as List).cast<Map<String, dynamic>>();
      expect(parts.map((p) => p['componentRef']), [
        first['uddfId'],
        hose['uddfId'],
      ]);
      expect(parts.map((p) => p['sortOrder']), [0, 1]);
    });
  }

  test('an unknown component name is skipped with a warning', () async {
    final csv = CsvEquipmentWriter(CsvExportUnits.metric).write(
      roundTripEquipment(),
      componentNames: {'e-reg': ['Ghost']},
    );
    final payload =
        await const SubmersionEquipmentCsvParser().parse(_bytes(csv));
    expect(payload.warnings, hasLength(1));
    expect(
      _byName(payload.entitiesOf(ImportEntityType.equipment), 'Primary reg')
          .containsKey('components'),
      isFalse,
    );
  });
}
```

Add `roundTripEquipment()` to `test/core/services/export/csv/csv_test_fixtures.dart`: the golden equipment with the O2 cell's `installed_date` set to local midnight, because the golden's literal UTC epoch would be a different calendar day in a western time zone once My units writes it as a date:

```dart
/// [goldenEquipment] with the installed date stored the way the date picker
/// stores it (local midnight), so a My units round trip is exact in any
/// time zone.
List<EquipmentItem> roundTripEquipment() => [
  for (final item in goldenEquipment())
    item.id == 'e-cell'
        ? item.copyWith(
            attributes: [
              for (final a in item.attributes)
                a.key == 'installed_date'
                    ? a.copyWith(
                        valueNum: DateTime(
                          2025,
                          3,
                          15,
                        ).millisecondsSinceEpoch.toDouble(),
                      )
                    : a,
            ],
          )
        : item,
];
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the parser**

```dart
import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's equipment CSV export (either unit mode) back into
/// equipment maps, attributes and assembly parts included.
class SubmersionEquipmentCsvParser implements ImportParser {
  const SubmersionEquipmentCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionEquipmentCsv,
  ];

  static Map<String, dynamic> _attribute(CsvAttribute a) => {
    'key': a.key,
    'isCustom': a.isCustom,
    'valueText': a.valueText,
    'valueNum': a.valueNum,
  };

  /// A calendar date from the file as local midnight, the way the app's
  /// date pickers store equipment dates.
  static DateTime? _local(DateTime? utcDate) => utcDate == null
      ? null
      : DateTime(utcDate.year, utcDate.month, utcDate.day);

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final dateFormat = table.dateFormatOf('Purchase Date');
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.buoyancy,
        CsvColumns.dryWeight,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.equipment,
        ),
    ];
    final items = <Map<String, dynamic>>[];
    final componentCells = <int, String>{};

    for (final (i, row) in table.rows.indexed) {
      final name = table.text(row, 'Name');
      if (name == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no equipment name and was skipped',
            entityType: ImportEntityType.equipment,
            itemIndex: i,
            field: 'Name',
          ),
        );
        continue;
      }

      final attributes = <Map<String, dynamic>>[];
      final thickness = table.text(row, 'Thickness');
      if (thickness != null) {
        attributes.add({
          'key': EquipmentAttrKeys.thicknessMm,
          'isCustom': false,
          'valueText': thickness,
          'valueNum': parsePrimaryThickness(thickness),
        });
      }
      for (final (column, key) in const [
        (CsvColumns.buoyancy, EquipmentAttrKeys.buoyancyKg),
        (CsvColumns.dryWeight, EquipmentAttrKeys.dryWeightKg),
      ]) {
        final kg = table.quantity(row, column);
        if (kg != null) {
          attributes.add({'key': key, 'isCustom': false, 'valueNum': kg});
        }
      }
      for (final pair in splitAttributePairs(
        table.text(row, 'Attributes') ?? '',
      )) {
        final parsed = parseAttributePair(pair, dateFormat: dateFormat);
        if (parsed == null) {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: 'Attribute "$pair" of "$name" could not be read',
              entityType: ImportEntityType.equipment,
              itemIndex: items.length,
              field: 'Attributes',
            ),
          );
        } else {
          attributes.add(_attribute(parsed));
        }
      }

      final lastService = table.date(row, 'Last Service');
      final nextDue = table.date(row, 'Next Service Due');
      // Both are UTC midnights, so the difference is whole days even
      // across a daylight-saving change.
      final interval = lastService != null && nextDue != null
          ? nextDue.difference(lastService).inDays
          : null;
      final active = table.text(row, 'Active')?.toLowerCase();

      final components = table.text(row, 'Components');
      if (components != null) componentCells[items.length] = components;

      items.add(
        <String, dynamic>{
          'uddfId': 'csv-equipment-$i',
          'name': name,
          'type': (enumByDisplayName(
                    EquipmentType.values,
                    (v) => v.displayName,
                    table.text(row, 'Type'),
                  ) ??
                  EquipmentType.other)
              .name,
          'brand': table.text(row, 'Brand'),
          'model': table.text(row, 'Model'),
          'serialNumber': table.text(row, 'Serial Number'),
          'size': table.text(row, 'Size'),
          'purchaseDate': _local(table.date(row, 'Purchase Date')),
          'lastServiceDate': _local(lastService),
          'serviceIntervalDays': interval != null && interval > 0
              ? interval
              : null,
          'isActive': active == 'yes' ? true : (active == 'no' ? false : null),
          'notes': table.text(row, 'Notes'),
          if (attributes.isNotEmpty) 'attributes': attributes,
        }..removeWhere((_, value) => value == null),
      );
    }

    _resolveComponents(items, componentCells, warnings);

    return ImportPayload(
      entities: {if (items.isNotEmpty) ImportEntityType.equipment: items},
      warnings: warnings,
    );
  }

  /// The Components column lists part names; each resolves to the one row
  /// of this file with that name. A missing or ambiguous name is skipped
  /// with a warning rather than guessed.
  static void _resolveComponents(
    List<Map<String, dynamic>> items,
    Map<int, String> cells,
    List<ImportWarning> warnings,
  ) {
    final idsByName = <String, List<String>>{};
    for (final item in items) {
      idsByName
          .putIfAbsent(item['name'] as String, () => [])
          .add(item['uddfId'] as String);
    }
    for (final MapEntry(key: index, value: cell) in cells.entries) {
      final parts = <Map<String, dynamic>>[];
      for (final name in cell.split('; ').map((s) => s.trim())) {
        if (name.isEmpty) continue;
        final ids = idsByName[name] ?? const [];
        if (ids.length != 1) {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: ids.isEmpty
                  ? 'Part "$name" of "${items[index]['name']}" is not in '
                        'this file and was not linked'
                  : 'Part "$name" of "${items[index]['name']}" matches '
                        'several items and was not linked',
              entityType: ImportEntityType.equipment,
              itemIndex: index,
              field: 'Components',
            ),
          );
          continue;
        }
        parts.add({
          'componentRef': ids.single,
          'role': '',
          'sortOrder': parts.length,
        });
      }
      if (parts.isNotEmpty) items[index]['components'] = parts;
    }
  }
}
```

- [ ] **Step 4: Register it**

Add `ImportFormat.submersionEquipmentCsv => const SubmersionEquipmentCsvParser(),` to `parserForFormat`, with the import.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/universal_import test/features/universal_import/data/parsers/submersion_csv test/core/services/export/csv/csv_test_fixtures.dart
git add lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart lib/features/universal_import/data/parsers/parser_registry.dart test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart test/core/services/export/csv/csv_test_fixtures.dart
git commit -m "feat(import): import Submersion's equipment CSV with attributes and parts (#1813)"
```

---

### Task 16: Dives CSV parser

**Files:**
- Create: `lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Test: `test/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser_test.dart`

**Interfaces:**
- Consumes: `SubmersionCsvTable`, `parseSiteLocationText`, `volumeLitersFromCapacity`, `enumByDisplayName`, `CsvColumns`, `CsvUnit`, `DiveTypeEntity.generateSlug` (`lib/features/dive_types/domain/entities/dive_type_entity.dart`), `GasMix`.
- Produces: `class SubmersionDivesCsvParser implements ImportParser` (const). Dive maps with `dateTime` (UTC wall clock), `diveNumber` (`int`), `name`, `maxDepth`, `avgDepth`, `waterTemp`, `airTemp` (`double`), `duration`, `runtime` (`Duration`), `visibilityMeters` (`double`) or `visibility` (enum `.name`), `diveTypeIds` (`List<String>`), `buddy`, `diveMaster`, `rating` (`int`), `notes`, `diveComputerModel`, `diveComputerSerial`, `diveComputerFirmware`, `tanks` (`List<Map<String, dynamic>>` with `volume`, `workingPressure`, `startPressure`, `endPressure`, `gasMix`, `order`), `windSpeed`, `windDirection`, `cloudCover`, `precipitation`, `humidity`, `weatherDescription`, `customFields` (`List<Map<String, dynamic>>` of `{key, value}`), `site` (`{uddfId}`). Also `sites` entities `{uddfId, name, region?, country?}` and `diveTypes` entities `{id, name, uddfId}`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionDivesCsv),
      isA<SubmersionDivesCsvParser>(),
    );
  });

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    final label = units.isMetric ? 'metric' : 'my units';

    test('reads every column back ($label)', () async {
      final csv = CsvDivesWriter(units).write(goldenDives());
      final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
      expect(payload.warnings, isEmpty);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(2));
      final d = dives.first;
      expect(d['dateTime'], DateTime.utc(2025, 3, 15, 9, 5));
      expect(d['diveNumber'], 12);
      expect(d['name'], 'Morning dive');
      expect(d['maxDepth'] as double, closeTo(30.48, 0.06));
      expect(d['waterTemp'] as double, closeTo(26.4, 0.6));
      expect(d['duration'], const Duration(minutes: 41));
      expect(d['runtime'], const Duration(minutes: 47));
      expect(d['visibilityMeters'] as double, closeTo(21.3, 0.06));
      expect(d['diveTypeIds'], ['boat', 'deep_wreck']);
      expect(d['buddy'], 'Ana Reyes');
      expect(d['diveMaster'], 'Tom Lee');
      expect(d['rating'], 4);
      expect(d['notes'], 'Great viz saw turtles');
      expect(d['diveComputerModel'], 'Perdix AI');
      expect(d['windSpeed'] as double, closeTo(4.2, 0.06));
      expect(d['windDirection'], 'northEast');
      expect(d['cloudCover'], 'partlyCloudy');
      expect(d['precipitation'], 'none');
      expect(d['humidity'], 71.0);
      expect(d['weatherDescription'], 'Sunny');
      expect(d['customFields'], [
        {'key': 'Boat', 'value': 'Sea Dog'},
        {'key': 'Formula', 'value': '=1+1'},
      ]);

      final tank = (d['tanks'] as List<Map<String, dynamic>>).single;
      expect(tank['volume'] as double, closeTo(11.1, units.isMetric ? 0.5 : 1e-9));
      expect(tank['startPressure'] as double, closeTo(206.843, 0.06));
      expect(tank['endPressure'] as double, closeTo(50.5, 0.06));
      expect((tank['gasMix'] as GasMix).o2, 32);
      if (!units.isMetric) {
        expect(tank['workingPressure'] as double, closeTo(206.843, 0.04));
      }

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Blue Hole');
      expect(sites.single['region'], 'Lighthouse Reef');
      expect(sites.single['country'], 'Belize');
      expect(d['site'], {'uddfId': sites.single['uddfId']});

      final second = dives.last;
      expect(second['visibility'], 'good');
      expect(second.containsKey('tanks'), isFalse);
      expect(second.containsKey('site'), isFalse);
      expect(
        payload.entitiesOf(ImportEntityType.diveTypes).map((t) => t['id']),
        ['boat', 'deep_wreck'],
      );
    });
  }

  test('a row with no readable date is skipped with an error', () async {
    final csv = CsvDivesWriter(CsvExportUnits.metric)
        .write(goldenDives())
        .replaceFirst('2025-03-15', 'someday');
    final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(payload.warnings.single.severity, ImportWarningSeverity.error);
  });
}
```

Add the `import_warning.dart` import for `ImportWarningSeverity`. The tank-volume tolerance differs by mode on purpose: Metric writes whole litres (`11`), My units writes the rated cuft that maps back to the AL80 preset exactly.

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the parser**

```dart
import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/site_location_text.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's dives CSV export (either unit mode) back into dive,
/// site and dive type maps for the entity importer.
class SubmersionDivesCsvParser implements ImportParser {
  const SubmersionDivesCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionDivesCsv,
  ];

  static const _unitColumns = [
    CsvColumns.maxDepth,
    CsvColumns.avgDepth,
    CsvColumns.waterTemp,
    CsvColumns.airTemp,
    CsvColumns.visibility,
    CsvColumns.startPressure,
    CsvColumns.endPressure,
    CsvColumns.tankVolume,
    CsvColumns.workingPressure,
    CsvColumns.windSpeed,
  ];

  static Duration? _minutes(double? minutes) =>
      minutes == null ? null : Duration(seconds: (minutes * 60).round());

  static String? _enumName<T extends Enum>(
    List<T> values,
    String Function(T) displayName,
    String? text,
  ) => enumByDisplayName(values, displayName, text)?.name;

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(_unitColumns))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.dives,
        ),
    ];
    final dives = <Map<String, dynamic>>[];
    final sitesByName = <String, Map<String, dynamic>>{};
    final diveTypesBySlug = <String, Map<String, dynamic>>{};

    for (final (i, row) in table.rows.indexed) {
      final date = table.date(row, 'Date');
      if (date == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no readable date and was skipped',
            entityType: ImportEntityType.dives,
            itemIndex: i,
            field: 'Date',
          ),
        );
        continue;
      }
      final time = table.time(row, 'Time');
      final visibilityMeters = table.quantity(row, CsvColumns.visibility);

      final dive = <String, dynamic>{
        // Dive times are wall clocks stored UTC-flagged, like every other
        // importer's.
        'dateTime': DateTime.utc(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 0,
          time?.minute ?? 0,
        ),
        'diveNumber': table.integer(row, 'Dive Number'),
        'name': table.text(row, 'Name'),
        'maxDepth': table.quantity(row, CsvColumns.maxDepth),
        'avgDepth': table.quantity(row, CsvColumns.avgDepth),
        'duration': _minutes(table.number(row, 'Bottom Time')),
        'runtime': _minutes(table.number(row, 'Runtime')),
        'waterTemp': table.quantity(row, CsvColumns.waterTemp),
        'airTemp': table.quantity(row, CsvColumns.airTemp),
        'visibilityMeters': visibilityMeters,
        // A pre-v144 dive carries only the bucket; a measured distance wins.
        'visibility': visibilityMeters == null
            ? _enumName(
                Visibility.values,
                (v) => v.displayName,
                table.text(row, 'Visibility Rating'),
              )
            : null,
        'buddy': table.text(row, 'Buddy'),
        'diveMaster': table.text(row, 'Dive Master'),
        'rating': table.integer(row, 'Rating'),
        'notes': table.text(row, 'Notes'),
        'diveComputerModel': table.text(row, 'Dive Computer'),
        'diveComputerSerial': table.text(row, 'Serial Number'),
        'diveComputerFirmware': table.text(row, 'Firmware Version'),
        'windSpeed': table.quantity(row, CsvColumns.windSpeed),
        'windDirection': _enumName(
          CurrentDirection.values,
          (v) => v.displayName,
          table.text(row, 'Wind Direction'),
        ),
        'cloudCover': _enumName(
          CloudCover.values,
          (v) => v.displayName,
          table.text(row, 'Cloud Cover'),
        ),
        'precipitation': _enumName(
          Precipitation.values,
          (v) => v.displayName,
          table.text(row, 'Precipitation'),
        ),
        'humidity': table.number(row, 'Humidity'),
        'weatherDescription': table.text(row, 'Weather Description'),
      }..removeWhere((_, value) => value == null);

      final typeIds = <String>[];
      for (final name in (table.text(row, 'Dive Type') ?? '').split(';')) {
        final trimmed = name.trim();
        final slug = DiveTypeEntity.generateSlug(trimmed);
        if (slug.isEmpty || typeIds.contains(slug)) continue;
        typeIds.add(slug);
        diveTypesBySlug.putIfAbsent(
          slug,
          () => {'id': slug, 'name': trimmed, 'uddfId': slug},
        );
      }
      if (typeIds.isNotEmpty) dive['diveTypeIds'] = typeIds;

      final tank = _tank(table, row);
      if (tank != null) dive['tanks'] = <Map<String, dynamic>>[tank];

      final custom = table.customCells(row);
      if (custom.isNotEmpty) {
        dive['customFields'] = <Map<String, dynamic>>[
          for (final c in custom) {'key': c.key, 'value': c.value},
        ];
      }

      final siteName = table.text(row, 'Site');
      if (siteName != null) {
        final site = sitesByName.putIfAbsent(siteName, () {
          final location = parseSiteLocationText(table.text(row, 'Location'));
          return <String, dynamic>{
            'uddfId': 'csv-site-${sitesByName.length}',
            'name': siteName,
            'region': location.region,
            'country': location.country,
          }..removeWhere((_, value) => value == null);
        });
        dive['site'] = <String, dynamic>{'uddfId': site['uddfId']};
      }

      dives.add(dive);
    }

    return ImportPayload(
      entities: {
        if (dives.isNotEmpty) ImportEntityType.dives: dives,
        if (sitesByName.isNotEmpty)
          ImportEntityType.sites: sitesByName.values.toList(),
        if (diveTypesBySlug.isNotEmpty)
          ImportEntityType.diveTypes: diveTypesBySlug.values.toList(),
      },
      warnings: warnings,
    );
  }

  /// The first tank, or null when every tank cell is blank.
  static Map<String, dynamic>? _tank(
    SubmersionCsvTable table,
    List<String> row,
  ) {
    final workingPressure = table.quantity(row, CsvColumns.workingPressure);
    final start = table.quantity(row, CsvColumns.startPressure);
    final end = table.quantity(row, CsvColumns.endPressure);
    final o2 = table.number(row, 'O2 %');
    final size = table.number(row, CsvColumns.tankVolume.base);
    final double? volume = switch (table.unitOf(CsvColumns.tankVolume)) {
      _ when size == null => null,
      // An imperial file writes rated capacity, not water volume.
      CsvUnit.cubicFeet => volumeLitersFromCapacity(size!, workingPressure),
      CsvUnit.liters => size,
      _ => null,
    };
    if (volume == null && start == null && end == null && o2 == null) {
      return null;
    }
    return <String, dynamic>{
      'volume': volume,
      'workingPressure': workingPressure,
      'startPressure': start,
      'endPressure': end,
      'gasMix': GasMix(o2: o2 ?? 21),
      'order': 0,
    }..removeWhere((_, value) => value == null);
  }
}
```

If the analyzer rejects `size!` inside the switch arm (the guard does not promote), bind first: `if (size == null) volume = null; else volume = switch (...) { CsvUnit.cubicFeet => volumeLitersFromCapacity(size, workingPressure), CsvUnit.liters => size, _ => null };` using a `final double? volume;` declared above.

- [ ] **Step 4: Register it**

Add `ImportFormat.submersionDivesCsv => const SubmersionDivesCsvParser(),` to `parserForFormat`, with the import.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/universal_import/data/parsers/submersion_csv/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/universal_import test/features/universal_import/data/parsers/submersion_csv
git add lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart lib/features/universal_import/data/parsers/parser_registry.dart test/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser_test.dart
git commit -m "feat(import): import Submersion's dives CSV in either unit mode (#1813)"
```

---
### Task 17: Round-trip integration tests

Export, detect, parse and import through the adapter's payload conversion into an in-memory database, then compare what was stored with the originals, for an imperial diver and a metric diver in My units and for Metric mode.

**Files:**
- Test: `test/core/services/export/csv/csv_round_trip_test.dart`

**Interfaces:**
- Consumes: the three writers, `FormatDetector`, `parserForFormat`, `UniversalAdapter.payloadToUddfResult`, `UddfEntityImporter`, `buildRepositories`/`createTestDiver` (`test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart`), `setUpTestDatabase`/`tearDownTestDatabase` (`test/helpers/test_database.dart`), fixtures from Task 1 and Task 15.

- [ ] **Step 1: Write the test**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../helpers/test_database.dart';
import '../uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import 'csv_dives_writer_test.dart' show imperial;
import 'csv_test_fixtures.dart';

const _metricDiver = AppSettings(
  dateFormat: DateFormatPreference.ddmmyyyy,
  timeFormat: TimeFormat.twentyFourHour,
);

/// Issue #1813 acceptance: a CSV exported in either mode, by an imperial or
/// a metric diver, re-imports with the same stored values, within the
/// precision the file wrote.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final cases = <String, CsvExportUnits>{
    'Metric mode': CsvExportUnits.metric,
    'My units, imperial diver': CsvExportUnits.fromSettings(imperial),
    'My units, metric diver': CsvExportUnits.fromSettings(_metricDiver),
  };

  Future<String> importCsv(String csv, ImportFormat expected) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    expect(const FormatDetector().detect(bytes).format, expected);
    final payload = await parserForFormat(expected).parse(bytes);
    expect(payload.warnings, isEmpty);
    final data = UniversalAdapter.payloadToUddfResult(payload);
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
      retainSourceDiveNumbers: true,
    );
    return diverId;
  }

  for (final MapEntry(key: label, value: units) in cases.entries) {
    group(label, () {
      test('sites come back', () async {
        final diverId = await importCsv(
          CsvSitesWriter(units).write(goldenSites()),
          ImportFormat.submersionSitesCsv,
        );
        final sites = await SiteRepository().getAllSites(diverId: diverId);
        final blue = sites.firstWhere((s) => s.name == 'Blue Hole');
        expect(blue.country, goldenSite.country);
        expect(blue.region, goldenSite.region);
        expect(blue.location!.latitude, goldenSite.location!.latitude);
        expect(blue.location!.longitude, goldenSite.location!.longitude);
        expect(blue.maxDepth!, closeTo(goldenSite.maxDepth!, 0.06));
        expect(blue.waterType, goldenSite.waterType);
        expect(blue.entryMethod, goldenSite.entryMethod);
        expect(blue.rating, goldenSite.rating);
        expect(blue.description, goldenSite.description);
        expect(blue.notes, goldenSite.notes.replaceAll('\n', ' '));
        expect(sites.map((s) => s.name), contains('House Reef'));
      });

      test('equipment comes back', () async {
        final diverId = await importCsv(
          CsvEquipmentWriter(units).write(
            roundTripEquipment(),
            componentNames: goldenComponentNames(),
          ),
          ImportFormat.submersionEquipmentCsv,
        );
        final stored = {
          for (final e in await EquipmentRepository().getAllEquipment(
            diverId: diverId,
          ))
            e.name: e,
        };
        for (final original in roundTripEquipment()) {
          final back = stored[original.name]!;
          expect(back.type, original.type, reason: original.name);
          expect(back.brand, original.brand);
          expect(back.model, original.model);
          expect(back.serialNumber, original.serialNumber);
          expect(back.isActive, original.isActive);
          expect(back.purchaseDate, original.purchaseDate);
          expect(back.lastServiceDate, original.lastServiceDate);
          expect(back.serviceIntervalDays, original.serviceIntervalDays);
          expect(back.notes, original.notes.replaceAll('\n', ' '));
          for (final attr in original.attributes) {
            final match = back.attributes
                .where((a) => a.key == attr.key && a.isCustom == attr.isCustom)
                .single;
            expect(match.valueText, attr.valueText,
                reason: '${original.name} ${attr.key}');
            if (attr.valueNum == null) {
              expect(match.valueNum, isNull);
            } else {
              expect(match.valueNum!,
                  closeTo(attr.valueNum!, attr.valueNum!.abs() * 0.01),
                  reason: '${original.name} ${attr.key}');
            }
          }
        }
        final parts = await EquipmentComponentRepository().getComponents(
          stored['Primary reg']!.id,
        );
        expect(
          parts.map((p) => p.componentEquipmentId),
          [stored['Mk25']!.id, stored['Long hose']!.id],
        );
      });

      test('dives come back', () async {
        await importCsv(
          CsvDivesWriter(units).write(goldenDives()),
          ImportFormat.submersionDivesCsv,
        );
        final repo = DiveRepository();
        final all = await repo.getAllDives();
        expect(all, hasLength(2));
        for (final original in goldenDives()) {
          final summary = all.firstWhere(
            (d) => d.diveNumber == original.diveNumber,
          );
          final back = (await repo.getDiveById(summary.id))!;
          expect(back.dateTime, original.dateTime);
          expect(back.name, original.name);
          expect(back.bottomTime, original.bottomTime);
          expect(back.diveTypeIds.toSet(), original.diveTypeIds.toSet());
          expect(back.buddy, original.buddy);
          expect(back.diveMaster, original.diveMaster);
          expect(back.rating, original.rating);
          expect(back.notes, original.notes.replaceAll('\n', ' '));
          expect(back.visibility, original.visibility);
          expect(back.diveComputerModel, original.diveComputerModel);
          expect(back.windDirection, original.windDirection);
          expect(back.cloudCover, original.cloudCover);
          expect(back.precipitation, original.precipitation);
          expect(back.humidity, original.humidity);
          expect(back.weatherDescription, original.weatherDescription);
          expect(
            {for (final f in back.customFields) f.key: f.value},
            {for (final f in original.customFields) f.key: f.value},
          );
          void near(double? got, double? want, double tolerance, String what) {
            if (want == null) return expect(got, isNull, reason: what);
            expect(got!, closeTo(want, tolerance), reason: what);
          }

          near(back.maxDepth, original.maxDepth, 0.06, 'maxDepth');
          near(back.avgDepth, original.avgDepth, 0.06, 'avgDepth');
          near(back.waterTemp, original.waterTemp, 0.6, 'waterTemp');
          near(back.airTemp, original.airTemp, 0.6, 'airTemp');
          near(back.visibilityMeters, original.visibilityMeters, 0.06, 'vis');
          near(back.windSpeed, original.windSpeed, 0.06, 'windSpeed');
          if (original.tanks.isNotEmpty) {
            final want = original.tanks.first;
            final got = back.tanks.first;
            near(got.volume, want.volume, units.isMetric ? 0.5 : 0.06, 'vol');
            near(got.startPressure, want.startPressure, 0.06, 'start');
            near(got.endPressure, want.endPressure, 0.06, 'end');
            expect(got.gasMix.o2, want.gasMix.o2);
            if (!units.isMetric) {
              near(got.workingPressure, want.workingPressure, 0.04, 'wp');
            }
          }
          if (original.site != null) {
            expect(back.site?.name, original.site!.name);
            expect(back.site?.region, original.site!.region);
            expect(back.site?.country, original.site!.country);
          }
        }
      });
    });
  }
}
```

Tolerances follow the precision the file writes: depth 0.1 m or 0.1 ft, whole degrees, bar to 0.1 or whole psi, whole litres in Metric mode. Metric mode never wrote a working pressure, which is why that one comparison is My units only.

- [ ] **Step 2: Run it**

Run: `flutter test test/core/services/export/csv/csv_round_trip_test.dart`
Expected: PASS (9 tests). This is the first test that exercises the whole chain, so failures here point at seams between tasks. Diagnose each against the task that owns the seam, and fix the code, not the tolerance:
- a value stored as `null`: the parser emitted the wrong key or Dart type (strict `as double?` casts reject an `int`), or the importer does not read the key (Task 13);
- a wrong enum: a display-name lookup returned null (Task 2), or the importer matched `.name` against a display name;
- a site created twice: the dives CSV emitted two sites for one name (Task 16);
- `getAllDives` returning a type without `diveNumber`: use whatever id accessor it has and match on `dateTime` instead.
- the importer reverse-geocoding a site (a network call): only happens for sites with coordinates and a missing country or region; the fixtures set both, so a geocode means the parser dropped `country` or `region`.

- [ ] **Step 3: Commit**

```bash
dart format test/core/services/export/csv/csv_round_trip_test.dart
git add test/core/services/export/csv/csv_round_trip_test.dart
git commit -m "test(csv): round trip every CSV export through the importer in both modes (#1813)"
```

---

### Task 18: Whole-project verification, PR and CI

**Files:** none new.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: no changes, or only files this branch touched. If files outside this branch change, discard those (`git checkout -- <path>`) and report it.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (infos count as failures in CI). Do not pipe the output into another command; read the exit status.

- [ ] **Step 3: Verify generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: no output (the generated files committed in Task 9 are current).

- [ ] **Step 4: Run the full test suite once**

Run: `flutter test`
Expected: all tests pass. Run it once; do not overlap it with another test run. If an unrelated test fails, check whether it also fails on `origin/main` before touching it.

- [ ] **Step 5: Confirm no forbidden text**

Run: `git log origin/main..HEAD --format=%B | grep -niE "co-authored-by|generated with|session_" ; git diff origin/main --stat`
Expected: the grep prints nothing, and a read of the commit messages finds no tool attribution. Also scan the diff for the U+2014 character: `git diff origin/main | grep -n $'\xe2\x80\x94'` must print nothing for added lines (lines starting with `+`).

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin ericgriffin/github-issue-1813-885517
gh pr create --repo submersion-app/submersion --base main --title "feat(csv): unit-aware CSV export with a full re-import round trip (#1813)" --body-file <path to a body file written in the scratchpad>
```

The body covers: the My units / Metric choice at all three entry points (remembered per device); Metric output byte-identical (golden files); My units conversions, header units and date/time formats; equipment attributes as `hose_length=22 in`; rated cuft plus a Working Pressure column; the three new Submersion CSV import formats and their detection; the importer gaps closed (site entry method, equipment attributes, dive weather and custom fields); what is out of scope (fields the export never wrote); and a test plan listing the round-trip matrix. End with `Closes #1813`. No attribution lines of any kind.

- [ ] **Step 7: Track CI**

Watch the PR's checks until they finish. On a failure, read the failing job's log, fix the cause on this branch, commit, push, and watch again. A single shard failing on a native-library download hash mismatch is a known transient: rerun only the failed jobs.
