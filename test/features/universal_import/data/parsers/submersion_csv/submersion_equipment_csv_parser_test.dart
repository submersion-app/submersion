import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
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
    test(
      'reads every column back (${units.isMetric ? 'metric' : 'my units'})',
      () async {
        final csv = CsvEquipmentWriter(
          units,
        ).write(roundTripEquipment(), componentNames: goldenComponentNames());
        final payload = await const SubmersionEquipmentCsvParser().parse(
          _bytes(csv),
        );
        expect(payload.warnings, isEmpty);
        final items = payload.entitiesOf(ImportEntityType.equipment);
        expect(items, hasLength(7));

        final suit = _byName(items, 'Suit');
        expect(suit['type'], 'wetsuit');
        expect(suit['size'], 'L');
        expect(_attr(suit, 'thickness_mm')['valueText'], '5/4');
        expect(
          _attr(suit, 'buoyancy_kg')['valueNum'] as double,
          closeTo(2.5, 0.005),
        );
        expect(_attr(suit, 'suit_style')['valueText'], 'full');

        final hose = _byName(items, 'Long hose');
        expect(
          _attr(hose, 'hose_length_m')['valueNum'] as double,
          closeTo(0.5588, 0.002),
        );

        final tank = _byName(items, 'AL80');
        expect(tank['serialNumber'], '00123');
        expect(
          _attr(tank, 'volume_l')['valueNum'] as double,
          closeTo(11.1, 0.05),
        );

        final cell = _byName(items, 'Cell A');
        expect(
          _attr(cell, 'installed_date')['valueNum'],
          DateTime(2025, 3, 15).millisecondsSinceEpoch.toDouble(),
        );
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
      },
    );
  }

  test('an unknown component name is skipped with a warning', () async {
    final csv = CsvEquipmentWriter(CsvExportUnits.metric).write(
      roundTripEquipment(),
      componentNames: {
        'e-reg': ['Ghost'],
      },
    );
    final payload = await const SubmersionEquipmentCsvParser().parse(
      _bytes(csv),
    );
    expect(payload.warnings, hasLength(1));
    expect(
      _byName(
        payload.entitiesOf(ImportEntityType.equipment),
        'Primary reg',
      ).containsKey('components'),
      isFalse,
    );
  });

  group('Tags column (#1942)', () {
    const reg = EquipmentItem(
      id: 'r',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    const mask = EquipmentItem(id: 'm', name: 'Mask', type: EquipmentType.mask);
    const fins = EquipmentItem(id: 'f', name: 'Fins', type: EquipmentType.fins);

    String csv() => CsvEquipmentWriter(CsvExportUnits.metric).write(
      const [reg, mask, fins],
      tagNames: const {
        'r': ['Salt; fresh', 'Travel'],
        'm': ['=Deep', 'travel '],
      },
    );

    test(
      'each distinct name becomes one equipment tag the rows reference',
      () async {
        final payload = await const SubmersionEquipmentCsvParser().parse(
          _bytes(csv()),
        );
        expect(payload.warnings, isEmpty);
        final tags = payload.entitiesOf(ImportEntityType.tags);
        // "travel " is "Travel": the tags table is unique on lower(trim(name)).
        expect(tags.map((t) => t['name']), ['Salt; fresh', 'Travel', '=Deep']);
        for (final tag in tags) {
          expect(tag['appliesToEquipment'], isTrue);
          expect(tag['appliesToDives'], isFalse);
          expect(tag['appliesToSites'], isFalse);
        }
        final ids = {for (final t in tags) t['name']: t['uddfId']};
        final items = payload.entitiesOf(ImportEntityType.equipment);
        expect(_byName(items, 'Reg')['tagRefs'], [
          ids['Salt; fresh'],
          ids['Travel'],
        ]);
        expect(_byName(items, 'Mask')['tagRefs'], [
          ids['=Deep'],
          ids['Travel'],
        ]);
        expect(
          _byName(items, 'Fins').containsKey('tagRefs'),
          isFalse,
          reason: 'a blank cell adds nothing',
        );
      },
    );

    test('a file from before the Tags column reads with no tags', () async {
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csv());
      final at = rows.first.indexOf('Tags');
      final legacy = const ListToCsvConverter().convert([
        for (final row in rows) [...row]..removeAt(at),
      ]);
      final payload = await const SubmersionEquipmentCsvParser().parse(
        _bytes(legacy),
      );
      expect(payload.entitiesOf(ImportEntityType.equipment), hasLength(3));
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
    });
  });

  // Issue #2334: files written before the writer stopped exporting it still
  // carry passport_id; importing it would give two cylinders one tag.
  test('a passport id in an older file is ignored', () async {
    final csv = CsvEquipmentWriter(CsvExportUnits.metric)
        .write([
          const EquipmentItem(
            id: 'tank',
            name: 'Faber 12',
            type: EquipmentType.tank,
            attributes: [
              EquipmentAttribute(
                id: 'a1',
                equipmentId: 'tank',
                key: EquipmentAttrKeys.passportId,
                valueText: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
              ),
              EquipmentAttribute(
                id: 'a2',
                equipmentId: 'tank',
                key: 'valve_type',
                valueText: 'din',
              ),
            ],
          ),
        ])
        .replaceFirst(
          'valve_type=din',
          'passport_id=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab; valve_type=din',
        );
    expect(csv, contains('passport_id='));
    final payload = await const SubmersionEquipmentCsvParser().parse(
      _bytes(csv),
    );
    final tank = _byName(
      payload.entitiesOf(ImportEntityType.equipment),
      'Faber 12',
    );
    final keys = (tank['attributes'] as List).cast<Map<String, dynamic>>().map(
      (a) => a['key'],
    );
    expect(keys, contains('valve_type'));
    expect(keys, isNot(contains('passport_id')));
  });
}
