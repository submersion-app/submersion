# Cylinder Fills in UDDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A full UDDF backup carries every visible cylinder fill and each item's passport id, and a UDDF import restores them with the fills CSV rules, plus the UDDF service records the wizard drops today, their service kinds, the diver's custom kinds and each item's service clocks.

**Architecture:** A new `UddfFillWriters` (writer and parser, SI units) adds a `<cylinderfills>` section to `<applicationdata><submersion>`, and the `<item>` writer gains `<passportid>`. On import the fill maps use the fills CSV parser's keys, so `CsvFillImporter` stores them unchanged. A guarded `adoptImportedPassportId` runs between equipment and fills so a restore links. `UddfImportParser` maps fills and service records into the wizard payload.

**Tech Stack:** Flutter, Dart, Drift, Riverpod 3, `xml` package, flutter_test.

**Spec:** `docs/design/specs/2026-10-12-uddf-cylinder-fills-design.md`

## Global Constraints

- No em dashes or en dashes as punctuation in code, comments, docs or commits.
- No emojis. Immutability: never mutate a passed-in list or map.
- Paths in tests via `p.join`, temp space via `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- SI on the wire: fractions for O2/He, pascal, kelvin. Parse rounds to 0.01 % (O2, He), 0.001 bar, 0.01 degrees C.
- Fill element id prefix `fill_`, stripped on parse.
- Passport ids are adopted only into an empty slot with no other visible holder; an import never moves a tag, re-keys fills or throws for one.
- Full export only. The dives-only export and `UddfImportService` are unchanged.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests. After adding a file under `lib/`: `flutter test test/architecture/ test/shared/`.

## Review Focus

- Two items in one file carrying the same passport id (an old import wrote two): the first adopts, the second is refused, never two holders. Test in Task 6.
- Restoring a backup over the same library (every item matched as a duplicate): no fill is added, no passport id changes. Test in Task 7.
- A hand-edited `<o2>32</o2>` (percent, not fraction): the fill is dropped as an impossible mix, never stored as 3200 %. Test in Task 1.
- A zoneless `<datetime>` typed by hand: read as local wall clock, not rejected. Test in Task 1.
- A cylinder that already carries a different tag on the metal: it keeps its own id and the file's fills link only to whichever item holds theirs. Test in Task 5.

---

## File Structure

- Create `lib/core/services/export/uddf/uddf_fill_writers.dart`: `<cylinderfills>` writer and parser, SI conversion.
- Modify `lib/core/services/export/uddf/uddf_export_builders.dart`: `fills` parameter on `buildApplicationData`, `<passportid>` on `<item>`.
- Modify `lib/core/services/export/uddf/uddf_import_parsers.dart`: `parseEquipmentItem` reads `<passportid>`.
- Modify `lib/core/services/export/uddf/uddf_full_import_service.dart`: fills onto `UddfImportResult`.
- Modify `lib/core/services/export/uddf/uddf_full_export_service.dart` and `lib/core/services/export/export_service.dart`: thread `fills`.
- Modify `lib/features/settings/presentation/providers/export_providers.dart`: both full UDDF paths pass visible fills.
- Modify `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart`: `adoptImportedPassportId`.
- Create `lib/features/dive_import/data/services/import_passport_adoption.dart`: the importer's adoption pass.
- Modify `lib/features/dive_import/data/services/uddf_entity_importer.dart`: call the pass.
- Modify `lib/features/universal_import/data/parsers/uddf_import_parser.dart`: map fills and service records.
- Docs: `docs/guide/import-export.md`, `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md`.

---

### Task 1: `UddfFillWriters` writer and parser

**Files:**
- Create: `lib/core/services/export/uddf/uddf_fill_writers.dart`
- Test: `test/core/services/export/uddf/uddf_fill_writers_test.dart`

**Interfaces:**
- Produces: `abstract final class UddfFillWriters` with `static void writeFills(XmlBuilder builder, List<CylinderFill> fills)` and `static List<Map<String, dynamic>> parseFills(XmlElement submersion)`. Map keys: `uddfId`, `id`, `passportId`, `filledAt` (local `DateTime`), `o2Percent`, `hePercent`, and when present `pressureBar`, `temperatureC`, `analyzer`, `stationName`, `source`, `notes`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_fill_writers.dart';
import 'package:submersion/features/cylinder_passports/data/services/csv_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:xml/xml.dart';

/// The `<cylinderfills>` section of a full UDDF backup (issue #2651).
void main() {
  final full = CylinderFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    diverId: 'd1',
    passportId: 'pp-al80',
    equipmentId: 'tank-1',
    filledAt: DateTime(2025, 3, 15, 9, 5),
    o2Percent: 32,
    pressureBar: 206.843,
    temperatureC: 22,
    analyzer: 'Analox O2EII',
    stationName: 'Blue Hole Dive Center',
    stationKey: 'reserved-key',
    signedRecord: 'reserved-token',
    source: FillSource.qr,
    notes: 'Topped off',
    createdAt: DateTime(2025, 3, 15, 9, 6),
    updatedAt: DateTime(2025, 3, 15, 9, 6),
  );
  final bare = CylinderFill(
    id: '8a1d4c47-9e2a-4b7d-8c9e-0f113f0c2b8e',
    passportId: 'pp-foreign',
    filledAt: DateTime(2025, 3, 16, 14, 30),
    o2Percent: 18,
    hePercent: 45,
    createdAt: DateTime(2025, 3, 16),
    updatedAt: DateTime(2025, 3, 16),
  );

  XmlElement submersion(List<CylinderFill> fills) {
    final builder = XmlBuilder();
    builder.element(
      'submersion',
      nest: () => UddfFillWriters.writeFills(builder, fills),
    );
    return builder.buildDocument().rootElement;
  }

  XmlElement wrap(String fillsXml) =>
      XmlDocument.parse('<submersion>$fillsXml</submersion>').rootElement;

  test('writes one fill element per fill in SI, in the given order', () {
    final root = submersion([full, bare]);
    final fills = root
        .findElements('cylinderfills')
        .single
        .findElements('fill')
        .toList();
    expect(fills.map((f) => f.getAttribute('id')), [
      'fill_${full.id}',
      'fill_${bare.id}',
    ]);
    String text(XmlElement e, String name) =>
        e.findElements(name).single.innerText;
    final first = fills.first;
    expect(text(first, 'passportid'), 'pp-al80');
    expect(
      text(first, 'datetime'),
      full.filledAt.toUtc().toIso8601String(),
    );
    expect(text(first, 'o2'), '0.32');
    expect(text(first, 'he'), '0');
    expect(text(first, 'pressure'), '20684300');
    expect(text(first, 'temperature'), '295.15');
    expect(text(first, 'analyzer'), 'Analox O2EII');
    expect(text(first, 'filledby'), 'Blue Hole Dive Center');
    expect(text(first, 'source'), 'qr');
    expect(text(first, 'notes'), 'Topped off');
    // Reserved for signing; never written, like the fills CSV.
    expect(root.toXmlString(), isNot(contains('reserved')));
  });

  test('optional values are omitted when absent', () {
    final fill = submersion([bare]).findAllElements('fill').single;
    for (final name in [
      'pressure',
      'temperature',
      'analyzer',
      'filledby',
      'notes',
    ]) {
      expect(fill.findElements(name), isEmpty, reason: name);
    }
    expect(fill.findElements('source').single.innerText, 'manual');
  });

  test('no fills write no section', () {
    expect(submersion(const []).findElements('cylinderfills'), isEmpty);
  });

  test('parse returns the fills CSV keys, rounded back exactly', () {
    final rows = UddfFillWriters.parseFills(submersion([full, bare]));
    expect(rows, hasLength(2));
    final first = rows.first;
    expect(first['id'], full.id);
    expect(first['uddfId'], full.id);
    expect(first['passportId'], 'pp-al80');
    expect(first['filledAt'], DateTime(2025, 3, 15, 9, 5));
    expect(first['o2Percent'], 32.0);
    expect(first['hePercent'], 0.0);
    expect(first['pressureBar'], 206.843);
    expect(first['temperatureC'], 22.0);
    expect(first['analyzer'], 'Analox O2EII');
    expect(first['stationName'], 'Blue Hole Dive Center');
    expect(first['source'], 'qr');
    expect(first['notes'], 'Topped off');
    expect(rows[1]['hePercent'], 45.0);
    expect(rows[1].containsKey('pressureBar'), isFalse);
  });

  test('a parsed row is a fill CsvFillImporter accepts unchanged', () {
    final parsed = UddfFillWriters.parseFills(submersion([full]));
    final fill = CsvFillImporter.fromPayload(parsed.single)!;
    expect(fill.id, full.id);
    expect(fill.o2Percent, 32);
    expect(fill.pressureBar, 206.843);
    expect(fill.temperatureC, 22);
    expect(fill.source, FillSource.qr);
  });

  test('a fill missing its id, passport id, time or O2 is dropped', () {
    const ok =
        '<passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime><o2>0.32</o2>';
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills>'
        '<fill>$ok</fill>'
        '<fill id="fill_a"><datetime>2026-10-01T14:05:00Z</datetime>'
        '<o2>0.32</o2></fill>'
        '<fill id="fill_b"><passportid>pp</passportid>'
        '<datetime>yesterday</datetime><o2>0.32</o2></fill>'
        '<fill id="fill_c"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime></fill>'
        '<fill id="fill_d">$ok</fill>'
        '</cylinderfills>',
      ),
    );
    expect(rows.map((r) => r['id']), ['d']);
  });

  test('a zoneless time is read as local wall clock', () {
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills><fill id="fill_z"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00</datetime><o2>0.32</o2></fill>'
        '</cylinderfills>',
      ),
    );
    expect(rows.single['filledAt'], DateTime(2026, 10, 1, 14, 5));
  });

  test('O2 written as a percent is refused, never stored as 3200 %', () {
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills><fill id="fill_p"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime><o2>32</o2></fill>'
        '</cylinderfills>',
      ),
    );
    expect(CsvFillImporter.fromPayload(rows.single), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_fill_writers_test.dart`
Expected: FAIL, `uddf_fill_writers.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/csv/codec/csv_text.dart'
    show trimFixed;
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Cylinder fills in a full UDDF backup (issue #2651): a
/// `<cylinderfills>` section under `<applicationdata><submersion>`, one
/// `<fill>` per record keyed by passport id rather than by an item, so a
/// fill with no cylinder row survives too.
///
/// Values are in UDDF's SI units, as `<mix>` and `<tankdata>`: fractions
/// for O2 and He, pascal and kelvin. The parser rounds them back so a
/// stored 32 % returns as exactly 32, and returns the keys the fills CSV
/// parser emits, so CsvFillImporter stores both formats the same way.
abstract final class UddfFillWriters {
  static const _idPrefix = 'fill_';
  static const _pascalPerBar = 100000.0;
  static const _kelvinOffset = 273.15;

  /// Writes [fills] in their order; nothing at all when there are none.
  /// The reserved signing fields, the diver and the equipment link are left
  /// out: the importing diver owns the copy, and linking is by passport id.
  static void writeFills(XmlBuilder builder, List<CylinderFill> fills) {
    if (fills.isEmpty) return;
    builder.element(
      'cylinderfills',
      nest: () {
        for (final fill in fills) {
          _writeFill(builder, fill);
        }
      },
    );
  }

  static void _writeFill(XmlBuilder builder, CylinderFill fill) {
    builder.element(
      'fill',
      attributes: {'id': '$_idPrefix${fill.id}'},
      nest: () {
        builder.element('passportid', nest: fill.passportId);
        builder.element(
          'datetime',
          nest: fill.filledAt.toUtc().toIso8601String(),
        );
        builder.element('o2', nest: trimFixed(fill.o2Percent / 100, 4));
        builder.element('he', nest: trimFixed(fill.hePercent / 100, 4));
        if (fill.pressureBar case final bar?) {
          builder.element(
            'pressure',
            nest: (bar * _pascalPerBar).round().toString(),
          );
        }
        if (fill.temperatureC case final celsius?) {
          builder.element(
            'temperature',
            nest: trimFixed(celsius + _kelvinOffset, 2),
          );
        }
        _text(builder, 'analyzer', fill.analyzer);
        _text(builder, 'filledby', fill.stationName);
        builder.element('source', nest: fill.source.name);
        _text(builder, 'notes', fill.notes);
      },
    );
  }

  static void _text(XmlBuilder builder, String name, String? value) {
    if (value == null || value.isEmpty) return;
    builder.element(name, nest: value);
  }

  /// The fills under [submersion]'s `<cylinderfills>`, or none. A fill
  /// without an id, a passport id, a readable time or an O2 value is
  /// dropped; the gas-mix check stays with CsvFillImporter.fromPayload.
  static List<Map<String, dynamic>> parseFills(XmlElement submersion) {
    final section = submersion.findElements('cylinderfills').firstOrNull;
    if (section == null) return const [];
    return [
      for (final element in section.findElements('fill')) ?_parseFill(element),
    ];
  }

  static Map<String, dynamic>? _parseFill(XmlElement element) {
    final rawId = element.getAttribute('id')?.trim();
    final id = rawId != null && rawId.startsWith(_idPrefix)
        ? rawId.substring(_idPrefix.length)
        : rawId;
    final passportId = _read(element, 'passportid');
    // Local, like the fills CSV and the Log fill sheet; a zoneless value
    // already parses as local wall clock.
    final filledAt = DateTime.tryParse(
      _read(element, 'datetime') ?? '',
    )?.toLocal();
    final o2 = _number(element, 'o2');
    if (id == null ||
        id.isEmpty ||
        passportId == null ||
        filledAt == null ||
        o2 == null) {
      return null;
    }
    final he = _number(element, 'he');
    final pascal = _number(element, 'pressure');
    final kelvin = _number(element, 'temperature');
    return {
      'uddfId': id,
      'id': id,
      'passportId': passportId,
      'filledAt': filledAt,
      'o2Percent': _round(o2 * 100, 2),
      'hePercent': he == null ? 0.0 : _round(he * 100, 2),
      if (pascal != null) 'pressureBar': _round(pascal / _pascalPerBar, 3),
      if (kelvin != null) 'temperatureC': _round(kelvin - _kelvinOffset, 2),
      if (_read(element, 'analyzer') case final analyzer?)
        'analyzer': analyzer,
      if (_read(element, 'filledby') case final station?)
        'stationName': station,
      if (_read(element, 'source') case final source?) 'source': source,
      if (_read(element, 'notes') case final notes?) 'notes': notes,
    };
  }

  static String? _read(XmlElement element, String name) =>
      UddfImportParsers.getElementText(element, name);

  static double? _number(XmlElement element, String name) =>
      double.tryParse(_read(element, name) ?? '');

  static double _round(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).round() / factor;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/export/uddf/uddf_fill_writers_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_fill_writers.dart test/core/services/export/uddf/uddf_fill_writers_test.dart
git commit -m "feat(cylinder-passports): UDDF writer and parser for cylinder fills"
```

---

### Task 2: Passport id on the equipment `<item>`

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (the `<item>` builder inside `buildApplicationData`, after `UddfTagWriters.writeTagRefs`)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseEquipmentItem`, after `parentRef`)
- Test: `test/core/services/export/uddf/uddf_passport_id_test.dart`

**Interfaces:**
- Produces: `itemData['passportId']` (`String?`) from `UddfImportParsers.parseEquipmentItem`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:xml/xml.dart';

/// Each item's passport id rides in its `<item>` (issue #2651).
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
  final tagged = EquipmentItem(
    id: 'tank-1',
    name: 'Faber 12',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'tank-1',
        key: EquipmentAttrKeys.passportId,
        valueText: 'pp-1',
      ),
    ],
  );
  const untagged = EquipmentItem(
    id: 'bcd-1',
    name: 'Wing',
    type: EquipmentType.bcd,
  );

  Future<Map<String?, XmlElement>> items() async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tagged, untagged],
    );
    return {
      for (final e in XmlDocument.parse(xml).findAllElements('item'))
        e.getAttribute('id'): e,
    };
  }

  test('an item holding a passport id writes it, another writes none', () async {
    final byId = await items();
    expect(byId['equip_tank-1']!.findElements('passportid').single.innerText,
        'pp-1');
    expect(byId['equip_bcd-1']!.findElements('passportid'), isEmpty);
  });

  test('the parser reads it back onto the item map', () async {
    final byId = await items();
    expect(
      UddfImportParsers.parseEquipmentItem(byId['equip_tank-1']!)['passportId'],
      'pp-1',
    );
    expect(
      UddfImportParsers.parseEquipmentItem(byId['equip_bcd-1']!)['passportId'],
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_passport_id_test.dart`
Expected: FAIL, no `passportid` element.

- [ ] **Step 3: Write the implementation**

In `uddf_export_builders.dart`, after `UddfTagWriters.writeTagRefs(...)` inside the `<item>` nest:

```dart
                        // The item's tag identity (issue #2651), so a
                        // restore links the fills stored under it.
                        if (_passportIdOf(item) case final passportId?) {
                          builder.element('passportid', nest: passportId);
                        }
```

and a top-level helper next to `_buildObservation`:

```dart
/// [item]'s passport id: the curated `passport_id` attribute, or null.
String? _passportIdOf(EquipmentItem item) {
  for (final a in item.attributes) {
    if (a.isCustom || a.key != EquipmentAttrKeys.passportId) continue;
    final value = a.valueText?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
```

(import `equipment_attribute_catalog.dart` if the file does not already.)

In `parseEquipmentItem`, after `item['parentRef'] = ...`:

```dart
    // The item's tag identity (issue #2651); adopted by the entity
    // importer only into an empty slot.
    item['passportId'] = getElementText(itemElement, 'passportid');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/export/uddf/uddf_passport_id_test.dart test/core/services/export/uddf/uddf_observations_round_trip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_import_parsers.dart test/core/services/export/uddf/uddf_passport_id_test.dart
git commit -m "feat(cylinder-passports): carry each item's passport id in a full UDDF backup"
```

---

### Task 3: Fills through the full export and the full parser

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData`: `List<CylinderFill>? fills` parameter, `hasData`, call after service records)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (`_generateAllDataXml`, `generateAllDataXmlForTest`, `exportAllDataToUddf`, `saveAllDataToUddfFile`: a `List<CylinderFill>? fills` parameter next to `observations`, passed down)
- Modify: `lib/core/services/export/export_service.dart` (`exportAllDataToUddf`, `saveAllDataToUddfFile`: same)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (parse fills in the `submersionElement` block; `fills:` on the returned `UddfImportResult`)
- Test: `test/core/services/export/uddf/uddf_fills_round_trip_test.dart`

**Interfaces:**
- Consumes: `UddfFillWriters.writeFills`, `UddfFillWriters.parseFills` (Task 1).
- Produces: `fills:` named parameter on `ExportService.exportAllDataToUddf` / `saveAllDataToUddfFile` and on `UddfFullExportService.generateAllDataXmlForTest`; `UddfImportResult.fills` filled by `UddfFullImportService.importAllDataFromUddf`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../csv/csv_test_fixtures.dart';

/// Fills ride the full backup and come back from its parser (#2651).
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  test('the full export writes the fills and the full parser reads them', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      fills: goldenFills(),
    );
    expect(xml, contains('<cylinderfills>'));
    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    expect(result.fills.map((f) => f['id']), [
      for (final f in goldenFills()) f.id,
    ]);
    expect(result.fills.first['pressureBar'], 206.843);
  });

  test('a backup with no fills writes no section', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
    );
    expect(xml, isNot(contains('cylinderfills')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_fills_round_trip_test.dart`
Expected: FAIL to compile, no `fills` parameter.

- [ ] **Step 3: Write the implementation**

In `buildApplicationData`, add the parameter after `observations`:

```dart
    // Cylinder fills (issue #2651): keyed by passport id, so a section of
    // their own rather than a child of the item.
    List<CylinderFill>? fills,
```

add `(fills?.isNotEmpty ?? false) ||` to `hasData` after `observations`, and after the service records block:

```dart
            // Cylinder fills (issue #2651)
            UddfFillWriters.writeFills(builder, fills ?? const []);
```

In `uddf_full_export_service.dart`, add `List<CylinderFill>? fills,` after every `List<EquipmentObservation>? observations,` (four signatures) and `fills: fills,` after every `observations: observations,` (four calls, including the `buildApplicationData` call). In `export_service.dart`, the same for both methods. Import `cylinder_fill.dart` in each file.

In `uddf_full_import_service.dart`, declare `var fills = const <Map<String, dynamic>>[];` beside `serviceRecords`, set it inside the `if (submersionElement != null)` block after the service records:

```dart
        // Cylinder fills (issue #2651)
        fills = UddfFillWriters.parseFills(submersionElement);
```

and pass `fills: fills,` after `serviceRecords: serviceRecords,` in the returned `UddfImportResult`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/export/uddf/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/export/uddf/ lib/core/services/export/export_service.dart test/core/services/export/uddf/uddf_fills_round_trip_test.dart
git commit -m "feat(cylinder-passports): write and parse cylinder fills in the full UDDF backup"
```

---

### Task 4: The export provider passes the diver's visible fills

**Files:**
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (both `exportAllDataToUddf` and `saveAllDataToUddfFile` calls; a `_diverFills()` helper beside `_diverObservations`)
- Test: `test/features/settings/presentation/providers/export_uddf_fills_test.dart`

**Interfaces:**
- Consumes: `fills:` on `ExportService` (Task 3), `CylinderFillRepository.getAllVisibleTo`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths pass the diver's visible fills (#2651).
/// The round trips prove writer and parser agree; this proves the app
/// reaches them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CylinderFill fill(String id, String diverId) => CylinderFill(
    id: id,
    diverId: diverId,
    passportId: 'pp-$id',
    filledAt: DateTime(2026, 9, 28),
    o2Percent: 32,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    for (final id in ['me', 'other']) {
      await DiverRepository().createDiver(
        Diver(
          id: id,
          name: id,
          isDefault: id == 'me',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    // Unlinked fills are visible only to the diver who logged them.
    await CylinderFillRepository().create(fill('mine', 'me'));
    await CylinderFillRepository().create(fill('theirs', 'other'));
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final save in [false, true]) {
    test('${save ? 'saving' : 'sharing'} passes only the diver\'s fills', () async {
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.fills?.map((f) => f.id), ['mine']);
    });
  }
}

class _CapturingExportService implements ExportService {
  List<CylinderFill>? fills;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      fills = invocation.namedArguments[#fills] as List<CylinderFill>?;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/export_uddf_fills_test.dart`
Expected: FAIL, `export.fills` is null.

- [ ] **Step 3: Write the implementation**

Beside `_diverObservations`:

```dart
  /// The fills the validated diver can see, for the full UDDF backup
  /// (issue #2651): the fills CSV's scope (passports spec 10.8).
  Future<List<CylinderFill>> _diverFills() async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return const [];
    return _ref.read(cylinderFillRepositoryProvider).getAllVisibleTo(diverId);
  }
```

and `fills: await _diverFills(),` after `observations: await _diverObservations(),` in both calls.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/export_providers.dart test/features/settings/presentation/providers/export_uddf_fills_test.dart
git commit -m "feat(cylinder-passports): the full UDDF backup exports the diver's fills"
```

---

### Task 5: `adoptImportedPassportId`

**Files:**
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart` (after `assignPassportId`)
- Test: `test/features/cylinder_passports/data/repositories/cylinder_passport_adopt_test.dart`

**Interfaces:**
- Produces: `Future<bool> adoptImportedPassportId({required String equipmentId, required String passportId, String? diverId})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

import '../../../../helpers/test_database.dart';

/// A passport id from an import is written only into an empty slot
/// (issue #2651).
void main() {
  late AppDatabase db;
  late CylinderPassportRepository passports;

  Future<void> item(String id, String type, {String status = 'active'}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            status: Value(status),
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    passports = CylinderPassportRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'D', createdAt: t, updatedAt: t),
        );
    await item('tank-1', 'tank');
  });
  tearDown(tearDownTestDatabase);

  test('an empty slot takes the id and the orphan fills relink', () async {
    await CylinderFillRepository().create(
      CylinderFill(
        id: 'f1',
        diverId: 'd1',
        passportId: 'pp-1',
        filledAt: DateTime(2026, 9, 1),
        o2Percent: 32,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final adopted = await passports.adoptImportedPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-1',
      diverId: 'd1',
    );
    expect(adopted, isTrue);
    expect(await passports.getPassportId('tank-1'), 'pp-1');
    expect((await CylinderFillRepository().getById('f1'))!.equipmentId, 'tank-1');
  });

  test('an item with its own tag keeps it', () async {
    await passports.assignPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-own',
      diverId: 'd1',
    );
    final adopted = await passports.adoptImportedPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-file',
      diverId: 'd1',
    );
    expect(adopted, isFalse);
    expect(await passports.getPassportId('tank-1'), 'pp-own');
  });

  for (final status in ['active', 'retired']) {
    test('another $status holder keeps the id', () async {
      await item('tank-2', 'tank');
      await passports.assignPassportId(
        equipmentId: 'tank-2',
        passportId: 'pp-1',
        diverId: 'd1',
      );
      await db.customStatement(
        "UPDATE equipment SET status = '$status' WHERE id = 'tank-2'",
      );
      final adopted = await passports.adoptImportedPassportId(
        equipmentId: 'tank-1',
        passportId: 'pp-1',
        diverId: 'd1',
      );
      expect(adopted, isFalse);
      expect(await passports.getPassportId('tank-1'), isNull);
      expect(await passports.getPassportId('tank-2'), 'pp-1');
    });
  }

  test('a non-tank takes the id but collects no fills', () async {
    await item('bcd-1', 'bcd');
    await CylinderFillRepository().create(
      CylinderFill(
        id: 'f2',
        diverId: 'd1',
        passportId: 'pp-g',
        filledAt: DateTime(2026, 9, 1),
        o2Percent: 21,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    expect(
      await passports.adoptImportedPassportId(
        equipmentId: 'bcd-1',
        passportId: 'pp-g',
        diverId: 'd1',
      ),
      isTrue,
    );
    expect((await CylinderFillRepository().getById('f2'))!.equipmentId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cylinder_passports/data/repositories/cylinder_passport_adopt_test.dart`
Expected: FAIL to compile, no `adoptImportedPassportId`.

- [ ] **Step 3: Write the implementation**

```dart
  /// Writes [passportId] onto [equipmentId] for an import (issue #2651) and
  /// returns whether it did. Unlike [assignPassportId], which a diver runs
  /// deliberately, an import only fills an empty slot: an item keeps a tag
  /// it already has, and an id held by any other item [diverId] can see,
  /// in service or not, stays there. Nothing is released or re-keyed. A
  /// cylinder that takes the id relinks the fills stored under it.
  Future<bool> adoptImportedPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) => _db.transaction(() async {
    if (await getPassportId(equipmentId) != null) return false;
    final holders = await _holdersOf(passportId, diverId: diverId);
    if (holders.any((row) => row.id != equipmentId)) return false;
    final target = await (_db.select(
      _db.equipment,
    )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
    if (target == null) return false;
    final existing = await _equipment.getAttributesForEquipment(equipmentId);
    await _equipment.saveAttributes(equipmentId, [
      for (final a in existing)
        if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: EquipmentAttrKeys.passportId,
        valueText: passportId,
      ),
    ]);
    if (target.type == EquipmentType.tank.name) {
      await _fills.relinkToEquipment(
        passportId: passportId,
        equipmentId: equipmentId,
      );
    }
    return true;
  });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cylinder_passports/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart test/features/cylinder_passports/data/repositories/cylinder_passport_adopt_test.dart
git commit -m "feat(cylinder-passports): adopt an imported passport id only into an empty slot"
```

---

### Task 6: The entity importer adopts passport ids before fills

**Files:**
- Create: `lib/features/dive_import/data/services/import_passport_adoption.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (after `_importComponents`, before `_importServiceRecords`)
- Test: `test/features/dive_import/data/services/import_passport_adoption_test.dart`

**Interfaces:**
- Consumes: `adoptImportedPassportId` (Task 5), `itemData['passportId']` (Task 2).
- Produces: `Future<int> adoptImportedPassportIds(List<Map<String, dynamic>> items, Map<String, String> equipmentIdMapping, CylinderPassportRepository repository, {required String diverId})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/dive_import/data/services/import_passport_adoption.dart';

import '../../../../helpers/test_database.dart';

/// The importer's adoption pass (issue #2651).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'D', createdAt: t, updatedAt: t),
        );
    for (final id in ['a', 'b']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('two items carrying one id: the first adopts it, the second is '
      'refused', () async {
    final passports = CylinderPassportRepository();
    final count = await adoptImportedPassportIds(
      [
        {'uddfId': 'equip_x', 'passportId': 'pp-1'},
        {'uddfId': 'equip_y', 'passportId': 'pp-1'},
        {'uddfId': 'equip_z', 'passportId': 'pp-unmapped'},
        {'uddfId': 'equip_w'},
      ],
      {'equip_x': 'a', 'equip_y': 'b'},
      passports,
      diverId: 'd1',
    );
    expect(count, 1);
    expect(await passports.getPassportId('a'), 'pp-1');
    expect(await passports.getPassportId('b'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/import_passport_adoption_test.dart`
Expected: FAIL, file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';

const _log = LoggerService('importPassportAdoption');

/// Restores the passport ids a full UDDF backup carries on its items
/// (issue #2651), for every item the import created or matched to an
/// existing row ([equipmentIdMapping], keyed by the file's item id).
///
/// Runs after equipment and before fills, so a restored cylinder holds its
/// id by the time CsvFillImporter links fills by it. Each id goes only into
/// an empty slot ([CylinderPassportRepository.adoptImportedPassportId]); a
/// refusal or a failure is logged and the import carries on. Returns how
/// many ids were written.
Future<int> adoptImportedPassportIds(
  List<Map<String, dynamic>> items,
  Map<String, String> equipmentIdMapping,
  CylinderPassportRepository repository, {
  required String diverId,
}) async {
  var count = 0;
  for (final item in items) {
    final passportId = (item['passportId'] as String?)?.trim();
    final uddfId = item['uddfId'] as String?;
    if (passportId == null || passportId.isEmpty || uddfId == null) continue;
    final equipmentId = equipmentIdMapping[uddfId];
    if (equipmentId == null) continue;
    try {
      final adopted = await repository.adoptImportedPassportId(
        equipmentId: equipmentId,
        passportId: passportId,
        diverId: diverId,
      );
      if (adopted) {
        count++;
      } else {
        _log.info('Kept the existing tag; did not adopt $passportId');
      }
    } catch (e) {
      _log.warning('Could not adopt passport id $passportId: $e');
    }
  }
  return count;
}
```

In `uddf_entity_importer.dart`, after the `_importComponents` block:

```dart
    // Passport ids ride on the items of a full backup (issue #2651); they
    // must land before the fills below link to them.
    if (equipmentRan && repositories.cylinderPassportRepository != null) {
      await adoptImportedPassportIds(
        data.equipment,
        equipmentIdMapping,
        repositories.cylinderPassportRepository!,
        diverId: diverId,
      );
    }
```

(Check `LoggerService.info`'s signature at `lib/core/services/logger_service.dart:234` and match it.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_import/data/services/import_passport_adoption.dart lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/import_passport_adoption_test.dart
git commit -m "feat(dive-import): restore passport ids from a UDDF backup before its fills"
```

---

### Task 7: The wizard carries fills and service records from UDDF

**Files:**
- Modify: `lib/features/universal_import/data/parsers/uddf_import_parser.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_uddf_fills_test.dart`

**Interfaces:**
- Consumes: everything above; `importThroughWizard` (`test/features/import_wizard/data/adapters/wizard_import_harness.dart`).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../core/services/export/csv/csv_test_fixtures.dart';
import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);
Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// A full UDDF backup restored through the wizard into a clean library
/// (issue #2651): fills keep their ids and link through the restored
/// passport id, a second import adds nothing, a deleted fill stays
/// deleted, and the service records come along.
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
  final tank = EquipmentItem(
    id: 'e-tank',
    name: 'AL80',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'e-tank',
        key: EquipmentAttrKeys.passportId,
        valueText: 'pp-al80',
      ),
    ],
  );
  final service = ServiceRecord(
    id: 's1',
    equipmentId: 'e-tank',
    serviceCategory: ServiceCategory.inspection,
    serviceDate: DateTime(2026, 5, 1),
    provider: 'Hydro shop',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );

  Future<Uint8List> backup() async => Uint8List.fromList(
    utf8.encode(
      await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        equipment: [tank],
        serviceRecords: [service],
        fills: goldenFills(),
      ),
    ),
  );

  testWidgets('a full backup restores fills linked, once, with service '
      'records', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await tester.runAsync(() => DiverRepository().createDiver(_diver()));

    final payload = await UddfImportParser().parse(await backup());
    ImportBundle? review;
    final result = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
      onReview: (bundle) => review = bundle,
    );
    expect(result.errorMessage, isNull);
    expect(review!.groups[ImportEntityType.fills]!.items, hasLength(2));
    expect(result.importedCounts[ImportEntityType.fills], 2);

    late String restoredTank;
    await tester.runAsync(() async {
      final items = await EquipmentRepository().getAllEquipment(
        diverId: _diverId,
      );
      restoredTank = items.single.id;
      expect(
        await CylinderPassportRepository().getPassportId(restoredTank),
        'pp-al80',
      );
      final fills = CylinderFillRepository();
      final linked = (await fills.getById(goldenFills().first.id))!;
      expect(linked.equipmentId, restoredTank);
      expect(linked.pressureBar, 206.843);
      expect(linked.temperatureC, 22);
      final unlinked = (await fills.getById(goldenFills()[1].id))!;
      expect(unlinked.equipmentId, isNull);
      final records = await ServiceRecordRepository().getRecordsForEquipment(
        restoredTank,
      );
      expect(records.map((r) => r.provider), ['Hydro shop']);
    });

    // The same backup over the restored library: every fill is marked as
    // already here and nothing is added; the tag stays where it is.
    ImportBundle? again;
    final second = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
      onReview: (bundle) => again = bundle,
    );
    expect(again!.groups[ImportEntityType.fills]!.duplicateIndices, {0, 1});
    expect(second.importedCounts[ImportEntityType.fills], isNull);
    await tester.runAsync(() async {
      expect(
        await CylinderFillRepository().getAllVisibleTo(_diverId),
        hasLength(2),
      );
      expect(
        await CylinderPassportRepository().getPassportId(restoredTank),
        'pp-al80',
      );
      await CylinderFillRepository().delete(goldenFills().first.id);
    });

    // A fill deleted here does not come back.
    await importThroughWizard(tester, payload: payload, diver: _diver());
    await tester.runAsync(() async {
      expect(await CylinderFillRepository().getById(goldenFills().first.id),
          isNull);
    });
  });

  testWidgets('an id another item already holds is not adopted, and the '
      'fills link to that holder', (tester) async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await tester.runAsync(() async {
      await DiverRepository().createDiver(_diver());
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'holder',
              name: 'Steel 15',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(_diverId),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'holder',
        passportId: 'pp-al80',
        diverId: _diverId,
      );
    });

    final payload = await UddfImportParser().parse(await backup());
    await importThroughWizard(tester, payload: payload, diver: _diver());

    await tester.runAsync(() async {
      final items = await EquipmentRepository().getAllEquipment(
        diverId: _diverId,
      );
      final restored = items.singleWhere((i) => i.id != 'holder');
      expect(await CylinderPassportRepository().getPassportId(restored.id),
          isNull);
      expect(
        (await CylinderFillRepository().getById(goldenFills().first.id))!
            .equipmentId,
        'holder',
      );
    });
  });
}
```

(Before running, confirm the service record repository's file path and read method name with `grep -rn "class ServiceRecordRepository" lib` and use them; adjust `ImportEntityType` import if the harness re-exports the wizard enum under another name, following `universal_adapter_fills_csv_test.dart`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_uddf_fills_test.dart`
Expected: FAIL, no Fills group in the review (the parser never maps fills), and no service records.

- [ ] **Step 3: Write the implementation**

In `UddfImportParser.parse`, after the `customDiveTypes` mapping:

```dart
      // Service records and cylinder fills (issue #2651): the wizard keeps
      // only these entity lists, so a list left out here never reaches the
      // importer, which silently dropped every UDDF service record.
      if (result.serviceRecords.isNotEmpty) {
        entities[ImportEntityType.serviceRecords] = result.serviceRecords;
      }
      if (result.fills.isNotEmpty) {
        entities[ImportEntityType.fills] = result.fills;
      }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/import_wizard/ test/features/universal_import/`
Expected: PASS. If the second import's equipment is imported as a new row rather than matched, inspect `duplicateIndices` for `ImportEntityType.equipment` and confirm the default `DuplicateAction.skip` pre-resolves it; the passport assertion is the requirement.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/parsers/uddf_import_parser.dart test/features/import_wizard/data/adapters/universal_adapter_uddf_fills_test.dart
git commit -m "fix(universal-import): carry UDDF fills and service records into the wizard"
```

---

### Task 8: Service kinds, clocks and record kinds in the full export

Spec section 9.1 and 9.2.

**Files:**
- Create: `lib/core/services/export/uddf/uddf_service_clock_writers.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData`: `serviceKinds`, `serviceSchedulesByItem`; `<serviceschedules>` in `<item>`; `<servicekind>` in `<record>`)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart`, `lib/core/services/export/export_service.dart` (thread both, beside `fills`)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (both full UDDF paths)
- Test: `test/core/services/export/uddf/uddf_service_clock_writers_test.dart`; extend `test/features/settings/presentation/providers/export_uddf_fills_test.dart`

**Interfaces:**
- Produces: `abstract final class UddfServiceClockWriters` with
  `static void writeKinds(XmlBuilder b, List<ServiceKind> kinds)`,
  `static void writeSchedules(XmlBuilder b, List<ServiceSchedule> schedules)`,
  `static List<Map<String, dynamic>> parseKinds(XmlElement submersion)`,
  `static List<Map<String, dynamic>> parseSchedules(XmlElement item)`.
  Kind map keys: `id`, `name`, `applicableTypes` (`List<String>`), `defaultIntervalDays` (int), `defaultIntervalDives` (int), `defaultIntervalHours` (double), `exposureIntervals` (`Map<String, double>`), `defaultCost`, `defaultCurrency`, `defaultCategory` (String), `autoAttach` (bool).
  Schedule map keys: `kindRef`, `intervalDays`, `intervalDives`, `intervalHours`, `exposureIntervals`, `defaultCost`, `defaultCurrency`, `anchorDate` (local DateTime), `anchorSetAt`, `enabled` (bool).
  Named parameters `serviceKinds:` and `serviceSchedulesByItem:` on `ExportService.exportAllDataToUddf` / `saveAllDataToUddfFile` and `UddfFullExportService.generateAllDataXmlForTest`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_service_clock_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:xml/xml.dart';

/// Service kinds, clocks and record kinds in a full UDDF backup (#2651).
void main() {
  final kind = ServiceKind(
    id: 'k-burst',
    diverId: 'me',
    name: 'Burst disc',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    defaultIntervalHours: 50.5,
    exposureIntervals: const {ExposureUnit.saltHours: 50},
    defaultCost: 25,
    defaultCurrency: 'EUR',
    defaultCategory: ServiceCategory.inspection,
    autoAttach: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final clock = ServiceSchedule(
    id: 'auto-hydro-tank-1',
    equipmentId: 'tank-1',
    serviceKindId: 'hydro',
    intervalDays: 1095,
    exposureIntervals: const {ExposureUnit.cycles: 500},
    anchorDate: DateTime(2026, 1, 10),
    anchorSetAt: DateTime(2026, 1, 11, 8),
    enabled: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const tank = EquipmentItem(
    id: 'tank-1',
    name: 'AL80',
    type: EquipmentType.tank,
  );
  final record = ServiceRecord(
    id: 's1',
    equipmentId: 'tank-1',
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: 'k-burst',
    serviceDate: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<XmlDocument> backup() async => XmlDocument.parse(
    await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tank],
      serviceRecords: [record],
      serviceKinds: [kind],
      serviceSchedulesByItem: {
        'tank-1': [clock],
      },
    ),
  );

  test('kinds, clocks and the record kind round trip through the parser', () async {
    final doc = await backup();
    final submersion = doc.findAllElements('submersion').single;
    final kinds = UddfServiceClockWriters.parseKinds(submersion);
    expect(kinds.single, {
      'id': 'k-burst',
      'name': 'Burst disc',
      'applicableTypes': ['tank'],
      'defaultIntervalDays': 365,
      'defaultIntervalHours': 50.5,
      'exposureIntervals': {'saltHours': 50.0},
      'defaultCost': 25.0,
      'defaultCurrency': 'EUR',
      'defaultCategory': 'inspection',
      'autoAttach': true,
    });
    final item = doc.findAllElements('item').single;
    final schedules = UddfServiceClockWriters.parseSchedules(item);
    expect(schedules.single, {
      'kindRef': 'hydro',
      'intervalDays': 1095,
      'exposureIntervals': {'cycles': 500.0},
      'anchorDate': DateTime(2026, 1, 10),
      'anchorSetAt': DateTime(2026, 1, 11, 8),
      'enabled': false,
    });

    final result = await UddfFullImportService().importAllDataFromUddf(
      doc.toXmlString(),
    );
    expect(result.serviceKinds.single['id'], 'k-burst');
    expect(result.equipment.single['serviceSchedules'], hasLength(1));
    expect(result.serviceRecords.single['serviceKindRef'], 'k-burst');
  });

  test('no kinds and no clocks write no sections', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tank],
    );
    expect(xml, isNot(contains('servicekinds')));
    expect(xml, isNot(contains('serviceschedules')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_service_clock_writers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the writers and parsers**

```dart
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// Service kinds and clocks in a full UDDF backup (issue #2651, spec
/// section 9). Only custom kinds are written: built-in ids are fixed in
/// every database. A kind id is written as stored, built-in or custom, so a
/// ref never needs to know which it is. Clocks nest in their item.
abstract final class UddfServiceClockWriters {
  static void writeKinds(XmlBuilder builder, List<ServiceKind> kinds) {
    if (kinds.isEmpty) return;
    builder.element(
      'servicekinds',
      nest: () {
        for (final kind in kinds) {
          builder.element(
            'kind',
            attributes: {'id': kind.id},
            nest: () {
              builder.element('name', nest: kind.name);
              if (kind.applicableTypes.isNotEmpty) {
                builder.element(
                  'applicabletypes',
                  nest: () {
                    for (final t in kind.applicableTypes) {
                      builder.element('type', nest: t.name);
                    }
                  },
                );
              }
              _value(builder, 'intervaldays', kind.defaultIntervalDays);
              _value(builder, 'intervaldives', kind.defaultIntervalDives);
              _value(builder, 'intervalhours', kind.defaultIntervalHours);
              _exposure(builder, kind.exposureIntervals);
              _value(builder, 'defaultcost', kind.defaultCost);
              _value(builder, 'defaultcurrency', kind.defaultCurrency);
              _value(builder, 'defaultcategory', kind.defaultCategory?.name);
              builder.element('autoattach', nest: kind.autoAttach.toString());
            },
          );
        }
      },
    );
  }

  static void writeSchedules(
    XmlBuilder builder,
    List<ServiceSchedule> schedules,
  ) {
    if (schedules.isEmpty) return;
    builder.element(
      'serviceschedules',
      nest: () {
        for (final s in schedules) {
          builder.element(
            'schedule',
            attributes: {'kindref': s.serviceKindId},
            nest: () {
              _value(builder, 'intervaldays', s.intervalDays);
              _value(builder, 'intervaldives', s.intervalDives);
              _value(builder, 'intervalhours', s.intervalHours);
              _exposure(builder, s.exposureIntervals);
              _value(builder, 'defaultcost', s.defaultCost);
              _value(builder, 'defaultcurrency', s.defaultCurrency);
              _value(
                builder,
                'anchordate',
                s.anchorDate?.toUtc().toIso8601String(),
              );
              _value(
                builder,
                'anchorsetat',
                s.anchorSetAt?.toUtc().toIso8601String(),
              );
              builder.element('enabled', nest: s.enabled.toString());
            },
          );
        }
      },
    );
  }

  static void _value(XmlBuilder builder, String name, Object? value) {
    if (value == null) return;
    final text = value.toString();
    if (text.isEmpty) return;
    builder.element(name, nest: text);
  }

  static void _exposure(XmlBuilder builder, Map<ExposureUnit, double> map) {
    for (final entry in map.entries) {
      builder.element(
        'exposureinterval',
        attributes: {'unit': entry.key.dbValue},
        nest: entry.value.toString(),
      );
    }
  }

  static List<Map<String, dynamic>> parseKinds(XmlElement submersion) {
    final section = submersion.findElements('servicekinds').firstOrNull;
    if (section == null) return const [];
    return [
      for (final e in section.findElements('kind'))
        if (_parseKind(e) case final kind?) kind,
    ];
  }

  static Map<String, dynamic>? _parseKind(XmlElement e) {
    final id = e.getAttribute('id')?.trim();
    final name = _text(e, 'name');
    if (id == null || id.isEmpty || name == null) return null;
    final types = [
      for (final t
          in e
              .findElements('applicabletypes')
              .expand((a) => a.findElements('type')))
        if (t.innerText.trim() case final type when type.isNotEmpty) type,
    ];
    return {
      'id': id,
      'name': name,
      if (types.isNotEmpty) 'applicableTypes': types,
      if (_int(e, 'intervaldays') case final v?) 'defaultIntervalDays': v,
      if (_int(e, 'intervaldives') case final v?) 'defaultIntervalDives': v,
      if (_double(e, 'intervalhours') case final v?) 'defaultIntervalHours': v,
      if (_exposures(e) case final m when m.isNotEmpty) 'exposureIntervals': m,
      if (_double(e, 'defaultcost') case final v?) 'defaultCost': v,
      if (_text(e, 'defaultcurrency') case final v?) 'defaultCurrency': v,
      if (_text(e, 'defaultcategory') case final v?) 'defaultCategory': v,
      'autoAttach': _text(e, 'autoattach')?.toLowerCase() == 'true',
    };
  }

  static List<Map<String, dynamic>> parseSchedules(XmlElement item) {
    final section = item.findElements('serviceschedules').firstOrNull;
    if (section == null) return const [];
    return [
      for (final e in section.findElements('schedule'))
        if (e.getAttribute('kindref')?.trim() case final ref?
            when ref.isNotEmpty)
          {
            'kindRef': ref,
            if (_int(e, 'intervaldays') case final v?) 'intervalDays': v,
            if (_int(e, 'intervaldives') case final v?) 'intervalDives': v,
            if (_double(e, 'intervalhours') case final v?) 'intervalHours': v,
            if (_exposures(e) case final m when m.isNotEmpty)
              'exposureIntervals': m,
            if (_double(e, 'defaultcost') case final v?) 'defaultCost': v,
            if (_text(e, 'defaultcurrency') case final v?)
              'defaultCurrency': v,
            if (_date(e, 'anchordate') case final v?) 'anchorDate': v,
            if (_date(e, 'anchorsetat') case final v?) 'anchorSetAt': v,
            'enabled': _text(e, 'enabled')?.toLowerCase() != 'false',
          },
    ];
  }

  static Map<String, double> _exposures(XmlElement e) => {
    for (final x in e.findElements('exposureinterval'))
      if ((x.getAttribute('unit')?.trim(), double.tryParse(x.innerText.trim()))
          case (final String unit, final double value)
          when ExposureUnit.fromDbValue(unit) != null)
        unit: value,
  };

  static String? _text(XmlElement e, String name) =>
      UddfImportParsers.getElementText(e, name);
  static int? _int(XmlElement e, String name) =>
      int.tryParse(_text(e, name) ?? '');
  static double? _double(XmlElement e, String name) =>
      double.tryParse(_text(e, name) ?? '');
  static DateTime? _date(XmlElement e, String name) =>
      DateTime.tryParse(_text(e, name) ?? '')?.toLocal();
}
```

- [ ] **Step 4: Wire the builders and the plumbing**

In `buildApplicationData` add `List<ServiceKind>? serviceKinds,` and `Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {},` after `fills`; add `(serviceKinds?.isNotEmpty ?? false) ||` to `hasData`; write the kinds just before the service records block:

```dart
            // Custom service kinds (issue #2651), before anything refers
            // to them.
            UddfServiceClockWriters.writeKinds(builder, serviceKinds ?? const []);
```

inside the `<item>` nest, after the `<passportid>` lines:

```dart
                        // The item's service clocks (issue #2651).
                        UddfServiceClockWriters.writeSchedules(
                          builder,
                          serviceSchedulesByItem[item.id] ?? const [],
                        );
```

and in the `<record>` nest after `servicecategory`:

```dart
                        if (record.serviceKindId case final kind?) {
                          builder.element('servicekind', nest: kind);
                        }
```

Thread `serviceKinds` and `serviceSchedulesByItem` through the same four `UddfFullExportService` signatures and two `ExportService` methods as `fills` in Task 3 (`Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {}` as the default everywhere).

In `export_providers.dart`, beside `_diverFills`:

```dart
  /// The validated diver's custom service kinds (issue #2651); built-ins
  /// are fixed in every database and never exported.
  Future<List<ServiceKind>> _diverServiceKinds() async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    final kinds = await _ref
        .read(serviceKindRepositoryProvider)
        .getAllKinds(diverId: diverId);
    return [for (final k in kinds) if (!k.isBuiltIn) k];
  }
```

and in both full UDDF calls:

```dart
        serviceKinds: await _diverServiceKinds(),
        serviceSchedulesByItem: await _ref
            .read(serviceScheduleRepositoryProvider)
            .getSchedulesForEquipmentIds([for (final e in equipment) e.id]),
```

Extend `_CapturingExportService` in `export_uddf_fills_test.dart` to capture `#serviceKinds` and `#serviceSchedulesByItem`, create in `setUp` one custom kind for `me` (`ServiceKindRepository().createKind(...)`), and assert in both tests that `export.serviceKinds` holds only it (no built-ins) and `export.serviceSchedulesByItem` is a map (empty with no equipment).

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/export/uddf/ test/features/settings/presentation/providers/`
Expected: PASS. (The full parser fields `serviceKinds`, `serviceSchedules` and `serviceKindRef` arrive in Task 9; until then mark the last three `expect`s of the round-trip test as the Task 9 red test by moving that test into Task 9's file if they fail here.)

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/export/ lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_service_clock_writers_test.dart test/features/settings/presentation/providers/export_uddf_fills_test.dart
git commit -m "feat(equipment): write service kinds, clocks and record kinds in the full UDDF backup"
```

---

### Task 9: Restore service kinds, clocks and record kinds

Spec section 9.3.

**Files:**
- Modify: `lib/core/services/export/models/uddf_import_result.dart` (`serviceKinds` field, in `isEmpty`, the count and `copyWith`-style rebuild, following `customSiteTypes`)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (`serviceKinds: UddfServiceClockWriters.parseKinds(submersionElement)`)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseEquipmentItem`: `item['serviceSchedules']`; `parseServiceRecord`: `record['serviceKindRef']`)
- Modify: `lib/features/universal_import/data/models/import_payload.dart` (`static const serviceKindsKey = 'serviceKinds';`)
- Modify: `lib/features/universal_import/data/parsers/uddf_import_parser.dart` (metadata)
- Modify: `lib/features/universal_import/data/services/payload_merger.dart` (fold by id, like `customSiteTypesKey`)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`serviceKinds: _metadataRows(payload, ImportPayload.serviceKindsKey)`; `serviceKindRepository`, `serviceScheduleRepository` in `universalImportRepositories`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`ImportRepositories` fields; kinds before equipment; clocks after equipment; record kinds)
- Create: `lib/features/dive_import/data/services/import_service_clocks.dart`
- Test: `test/features/dive_import/data/services/import_service_clocks_test.dart`; extend `test/features/import_wizard/data/adapters/universal_adapter_uddf_fills_test.dart`, `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`, `test/features/universal_import/data/services/payload_merger_test.dart`

**Interfaces:**
- Consumes: Task 8's map keys.
- Produces:
  - `class ServiceKindResolver { String? resolve(String? ref); }`
  - `Future<ServiceKindResolver> importServiceKinds(List<Map<String, dynamic>> kinds, ServiceKindRepository repository, {required String diverId})`
  - `Future<int> restoreServiceClocks(List<Map<String, dynamic>> items, Set<int> selected, Map<String, String> equipmentIdMapping, Map<String, String> preResolvedEquipmentIds, ServiceScheduleRepository repository, ServiceKindResolver kinds)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/import_service_clocks.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../../helpers/test_database.dart';

/// Kinds map by id, then name, then are created; clocks merge by kind with
/// the clocks createEquipment seeds (issue #2651).
void main() {
  late AppDatabase db;
  final kinds = ServiceKindRepository();
  final schedules = ServiceScheduleRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'D', createdAt: t, updatedAt: t),
        );
  });
  tearDown(tearDownTestDatabase);

  test('a kind maps by id, then by name, else is created for the diver', () async {
    await kinds.createKind(
      ServiceKind(
        id: 'k-same-id',
        diverId: 'd1',
        name: 'Valve rebuild',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await kinds.createKind(
      ServiceKind(
        id: 'k-local',
        diverId: 'd1',
        name: 'Burst Disc',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final resolver = await importServiceKinds(
      [
        {'id': 'k-same-id', 'name': 'Renamed elsewhere'},
        {'id': 'k-file', 'name': 'burst disc'},
        {
          'id': 'k-new',
          'name': 'Scooter seals',
          'applicableTypes': ['other'],
          'defaultIntervalDays': 180,
          'exposureIntervals': {'cycles': 40.0},
          'autoAttach': false,
        },
      ],
      kinds,
      diverId: 'd1',
    );
    expect(resolver.resolve('k-same-id'), 'k-same-id');
    expect(resolver.resolve('k-file'), 'k-local');
    final created = resolver.resolve('k-new')!;
    expect(created, isNot('k-new'));
    final stored = (await kinds.getKindById(created))!;
    expect(stored.diverId, 'd1');
    expect(stored.name, 'Scooter seals');
    expect(stored.defaultIntervalDays, 180);
    expect(stored.exposureIntervals, {ExposureUnit.cycles: 40.0});
    expect(resolver.resolve('hydro'), 'hydro');
    expect(resolver.resolve('nowhere'), isNull);
    expect(resolver.resolve(null), isNull);

    // The same file again creates nothing more.
    final before = (await kinds.getAllKinds(diverId: 'd1')).length;
    await importServiceKinds(
      [
        {'id': 'k-new', 'name': 'Scooter seals'},
      ],
      kinds,
      diverId: 'd1',
    );
    expect((await kinds.getAllKinds(diverId: 'd1')).length, before);
  });

  test('a restored clock replaces the seeded clock of its kind, keeps its '
      'id, and a matched duplicate is left alone', () async {
    final repo = EquipmentRepository();
    final created = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank, diverId: 'd1'),
    );
    final matched = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Old', type: EquipmentType.tank, diverId: 'd1'),
    );
    final seeded = (await schedules.getSchedulesForEquipment(created.id))
        .where((s) => s.serviceKindId == 'hydro')
        .single;
    final matchedBefore = await schedules.getSchedulesForEquipment(matched.id);

    final resolver = await importServiceKinds(const [], kinds, diverId: 'd1');
    final items = [
      {
        'uddfId': 'equip_a',
        'serviceSchedules': [
          {
            'kindRef': 'hydro',
            'intervalDays': 1095,
            'anchorDate': DateTime(2026, 1, 10),
            'enabled': false,
          },
          {'kindRef': 'o2-clean', 'intervalDays': 365},
          {'kindRef': 'nowhere', 'intervalDays': 1},
        ],
      },
      {
        'uddfId': 'equip_b',
        'serviceSchedules': [
          {'kindRef': 'hydro', 'intervalDays': 1},
        ],
      },
    ];
    final count = await restoreServiceClocks(
      items,
      {0, 1},
      {'equip_a': created.id, 'equip_b': matched.id},
      {'equip_b': matched.id},
      schedules,
      resolver,
    );
    expect(count, 2);
    final after = await schedules.getSchedulesForEquipment(created.id);
    final hydro = after.where((s) => s.serviceKindId == 'hydro').toList();
    expect(hydro, hasLength(1));
    expect(hydro.single.id, seeded.id);
    expect(hydro.single.intervalDays, 1095);
    expect(hydro.single.anchorDate, DateTime(2026, 1, 10));
    expect(hydro.single.enabled, isFalse);
    expect(
      after.where((s) => s.serviceKindId == 'o2-clean').single.intervalDays,
      365,
    );
    expect(await schedules.getSchedulesForEquipment(matched.id), matchedBefore);
  });
}
```

(Check `EquipmentItem`'s const constructor and `createEquipment`'s return type before running; `o2-clean` must not be an auto-attach kind for tanks for the "new clock" assertion to mean what it says, so if it is, swap it for a built-in kind that is not, read from `service_tables.dart`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/import_service_clocks_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `import_service_clocks.dart`**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

const _log = LoggerService('importServiceClocks');

/// Resolves a kind ref from a backup to a kind in this library: through the
/// file's own kinds as they were mapped, else to itself when a visible kind
/// (a built-in) has that id, else to nothing.
class ServiceKindResolver {
  const ServiceKindResolver(this._mapped, this._localIds);

  final Map<String, String> _mapped;
  final Set<String> _localIds;

  String? resolve(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    return _mapped[ref] ?? (_localIds.contains(ref) ? ref : null);
  }
}

/// Imports a backup's custom service kinds for [diverId] (issue #2651):
/// each maps to the visible kind with its id, else the visible kind with
/// its name (case-insensitive), else a new kind owned by the diver.
Future<ServiceKindResolver> importServiceKinds(
  List<Map<String, dynamic>> kinds,
  ServiceKindRepository repository, {
  required String diverId,
}) async {
  final visible = await repository.getAllKinds(diverId: diverId);
  final localIds = {for (final k in visible) k.id};
  final byName = {for (final k in visible) k.name.toLowerCase(): k.id};
  final mapped = <String, String>{};
  final now = DateTime.now();
  for (final data in kinds) {
    final id = data['id'] as String?;
    final name = (data['name'] as String?)?.trim();
    if (id == null || name == null || name.isEmpty) continue;
    if (localIds.contains(id)) {
      mapped[id] = id;
      continue;
    }
    if (byName[name.toLowerCase()] case final existing?) {
      mapped[id] = existing;
      continue;
    }
    try {
      final created = await repository.createKind(
        ServiceKind(
          id: '',
          diverId: diverId,
          name: name,
          applicableTypes: [
            for (final t in (data['applicableTypes'] as List?) ?? const [])
              if (EquipmentType.values.asNameMap()[t] case final type?) type,
          ],
          defaultIntervalDays: data['defaultIntervalDays'] as int?,
          defaultIntervalDives: data['defaultIntervalDives'] as int?,
          defaultIntervalHours: (data['defaultIntervalHours'] as num?)
              ?.toDouble(),
          exposureIntervals: _exposures(data['exposureIntervals']),
          defaultCost: (data['defaultCost'] as num?)?.toDouble(),
          defaultCurrency: data['defaultCurrency'] as String?,
          defaultCategory: ServiceCategory.values.asNameMap()[
              data['defaultCategory']],
          autoAttach: data['autoAttach'] as bool? ?? false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      mapped[id] = created.id;
      localIds.add(created.id);
      byName[name.toLowerCase()] = created.id;
    } catch (e) {
      _log.warning('Could not import service kind $name: $e');
    }
  }
  return ServiceKindResolver(mapped, localIds);
}

/// Restores the clocks a backup carries on its items (issue #2651), only
/// for items this import created: a duplicate matched to an existing row
/// keeps its own clocks, as it keeps its service records. Each clock
/// replaces the item's unclaimed clock of the same kind (one
/// createEquipment just seeded), keeping its id, or is created. Returns how
/// many clocks were written.
Future<int> restoreServiceClocks(
  List<Map<String, dynamic>> items,
  Set<int> selected,
  Map<String, String> equipmentIdMapping,
  Map<String, String> preResolvedEquipmentIds,
  ServiceScheduleRepository repository,
  ServiceKindResolver kinds,
) async {
  var count = 0;
  for (final (i, item) in items.indexed) {
    if (!selected.contains(i)) continue;
    final uddfId = item['uddfId'] as String?;
    final rows = item['serviceSchedules'];
    if (uddfId == null || rows is! List || rows.isEmpty) continue;
    final equipmentId = equipmentIdMapping[uddfId];
    if (equipmentId == null ||
        preResolvedEquipmentIds[uddfId] == equipmentId) {
      continue;
    }
    final unclaimed = [...await repository.getSchedulesForEquipment(equipmentId)];
    final now = DateTime.now();
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final kindId = kinds.resolve(row['kindRef'] as String?);
      if (kindId == null) continue;
      final slot = unclaimed.where((s) => s.serviceKindId == kindId).firstOrNull;
      if (slot != null) unclaimed.remove(slot);
      final schedule = ServiceSchedule(
        id: slot?.id ?? '',
        equipmentId: equipmentId,
        serviceKindId: kindId,
        intervalDays: row['intervalDays'] as int?,
        intervalDives: row['intervalDives'] as int?,
        intervalHours: (row['intervalHours'] as num?)?.toDouble(),
        exposureIntervals: _exposures(row['exposureIntervals']),
        defaultCost: (row['defaultCost'] as num?)?.toDouble(),
        defaultCurrency: row['defaultCurrency'] as String?,
        anchorDate: row['anchorDate'] as DateTime?,
        anchorSetAt: row['anchorSetAt'] as DateTime?,
        enabled: row['enabled'] as bool? ?? true,
        createdAt: slot?.createdAt ?? now,
        updatedAt: now,
      );
      try {
        if (slot != null) {
          await repository.updateSchedule(schedule);
        } else {
          await repository.createSchedule(schedule);
        }
        count++;
      } catch (e) {
        _log.warning('Could not restore a $kindId clock on $equipmentId: $e');
      }
    }
  }
  return count;
}

Map<ExposureUnit, double> _exposures(Object? raw) => {
  if (raw is Map)
    for (final entry in raw.entries)
      if ((ExposureUnit.fromDbValue('${entry.key}'), entry.value)
          case (final ExposureUnit unit, final num value))
        unit: value.toDouble(),
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/import_service_clocks_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire parse, wizard, repositories and importer**

1. `UddfImportResult`: `final List<Map<String, dynamic>> serviceKinds;` (default `const []`), in `isEmpty` and rebuilt everywhere `customSiteTypes` is.
2. `UddfFullImportService`: `serviceKinds: UddfServiceClockWriters.parseKinds(submersionElement)` (an empty list when there is no `<submersion>`).
3. `parseEquipmentItem`: `item['serviceSchedules'] = UddfServiceClockWriters.parseSchedules(itemElement);`. `parseServiceRecord`: `record['serviceKindRef'] = getElementText(recordElement, 'servicekind');`.
4. `ImportPayload.serviceKindsKey`; `UddfImportParser` metadata `if (result.serviceKinds.isNotEmpty) ImportPayload.serviceKindsKey: result.serviceKinds,`; `PayloadMerger` folds it by `id` exactly as `customSiteTypesKey` (a `serviceKinds` map, `putIfAbsent`, written back when non-empty); `UniversalAdapter._payloadToUddfResult` reads `serviceKinds: _metadataRows(payload, ImportPayload.serviceKindsKey)`.
5. `ImportRepositories`: optional `final ServiceKindRepository? serviceKindRepository;` and `final ServiceScheduleRepository? serviceScheduleRepository;` with a doc comment in the existing style; `universalImportRepositories` passes `ref.read(serviceKindRepositoryProvider)` and `ref.read(serviceScheduleRepositoryProvider)`; `universal_adapter_repositories_test.dart` asserts both are non-null.
6. `UddfEntityImporter.import`: before the equipment stage

```dart
    // Custom service kinds (issue #2651) land before equipment, so
    // auto-attach sees them as the source library did.
    final kindResolver = !equipmentRan ||
            repositories.serviceKindRepository == null
        ? const ServiceKindResolver({}, {})
        : await importServiceKinds(
            data.serviceKinds,
            repositories.serviceKindRepository!,
            diverId: diverId,
          );
```

   (move `final equipmentRan = !stopped();` above it). After the passport adoption pass:

```dart
    // Each created item's clocks (issue #2651), merged by kind with the
    // ones createEquipment seeded.
    if (equipmentRan && repositories.serviceScheduleRepository != null) {
      await restoreServiceClocks(
        data.equipment,
        selections.equipment,
        equipmentIdMapping,
        preResolvedEquipmentIds,
        repositories.serviceScheduleRepository!,
        kindResolver,
      );
    }
```

   and pass `kindResolver` to `_importServiceRecords`, which sets `serviceKindId: kinds.resolve(recordData['serviceKindRef'] as String?)` on each record.
7. `payload_merger_test.dart`: a test that two payloads' `serviceKinds` metadata fold by id into one list.
8. Extend `universal_adapter_uddf_fills_test.dart`'s first test: the backup also carries a custom kind `k-burst` ("Burst disc"), a `hydro` clock on the tank with `intervalDays: 1095`, a `k-burst` clock, and the service record with `serviceKindId: 'k-burst'`; after the first import assert one custom kind named "Burst disc" for the diver, one `hydro` clock with 1095 days on the restored tank, a clock whose kind is that custom kind, and the record's `serviceKindId` equal to that kind's local id; after the second import assert the kind and clock counts are unchanged.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/services/export/ test/features/dive_import/ test/features/import_wizard/ test/features/universal_import/ test/features/equipment/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add <each Modify/Create/Test path listed in this task>
git status --short   # confirm nothing else is staged
git commit -m "feat(equipment): restore service kinds, clocks and record kinds from a UDDF backup"
```

---

### Task 10: Docs, full checks

**Files:**
- Modify: `docs/guide/import-export.md`
- Modify: `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md` (section 4 non-goal "UDDF export of fills", section 18 bullet "UDDF export of fills.")

- [ ] **Step 1: Update the guide**

Find the UDDF backup paragraph (`grep -n -i "uddf" docs/guide/import-export.md`) and add, in its style: a full UDDF backup now carries every cylinder fill you can see and each item's tag (passport) id; restoring it brings fills back once, skips any already here or deleted here, and links them to the cylinder holding their tag; an item that already has a tag keeps it. It also carries service records with their service type, your custom service types and each item's service clocks, which come back on a restored item (merged with the clocks a new item gets by default).

- [ ] **Step 2: Mark the passports spec**

Under both "UDDF export of fills" lines add: `Decided 2026-10-12 (#2651): built; see 2026-10-12-uddf-cylinder-fills-design.md.`

- [ ] **Step 3: Full checks**

Run: `dart format . && flutter analyze && python3.14 scripts/check_docs_links.py && flutter test test/core/services/export/ test/features/cylinder_passports/ test/features/dive_import/ test/features/import_wizard/ test/features/universal_import/ test/features/settings/ test/architecture/ test/shared/`
Expected: no format changes left, no analyzer issues, all pass.

- [ ] **Step 4: Commit**

```bash
git add docs/guide/import-export.md docs/design/specs/2026-09-25-smart-cylinder-passports-design.md
git commit -m "docs(cylinder-passports): UDDF backups carry fills and passport ids"
```
