import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_parser.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

String _sample() => File(
  p.join('test', 'fixtures', 'equipment_catalogue', 'sample.json'),
).readAsStringSync();

Map<String, Object?> _record(Map<String, Object?> overrides) => {
  'id': 'maker-thing',
  'manufacturer': 'Maker',
  'model': 'Thing',
  'equipmentType': 'computer',
  'sources': [
    {
      'url': 'https://maker.example.org/thing',
      'publisher': 'manufacturer',
      'checked': '2026-11-27',
      'fields': ['manufacturer'],
    },
  ],
  ...overrides,
};

String _file(List<Map<String, Object?>> records, {int format = 1}) =>
    jsonEncode({
      'format': format,
      'generatedAt': '2026-11-27T00:00:00Z',
      'records': records,
    });

void main() {
  test('parses the shared sample', () {
    final file = parseEquipmentCatalogue(_sample())!;
    expect(file.format, 1);
    expect(file.generatedAt, DateTime.utc(2026, 11, 27));
    expect(file.records.map((r) => r.id), [
      'example-perdix-2',
      'example-puck-lite',
      'example-quad-light',
    ]);
    final perdix = file.records.first;
    expect(perdix.manufacturer, 'Shearwater');
    expect(perdix.manufacturerAliases, ['Shearwater Research']);
    expect(perdix.model, 'Perdix 2');
    expect(perdix.aliases, ['Perdix2']);
    expect(perdix.type, EquipmentType.computer);
    expect(perdix.attributes, {'connectivity': 'ble', 'mount': 'wrist'});
    expect(perdix.links.product, 'https://example.com/perdix-2');
    expect(perdix.links.manual, 'https://example.com/perdix-2/manual.pdf');
    expect(perdix.links.support, 'https://example.com/support');
    expect(perdix.firmwareId, 'example-perdix-2');
    expect(perdix.sources, hasLength(2));
    expect(perdix.sources.first.publisher, CataloguePublisher.manufacturer);
    expect(perdix.sources.first.checked, DateTime.utc(2026, 11, 27));
    expect(perdix.sources.first.fields, contains('links.manual'));
    expect(file.records[2].attributes, {'lumens': 1200, 'beam_type': 'spot'});
  });

  test('returns null for an unsupported format', () {
    expect(parseEquipmentCatalogue(_file([_record({})], format: 2)), isNull);
  });

  test('returns null for broken JSON', () {
    expect(parseEquipmentCatalogue('{"format": 1, "records": ['), isNull);
    expect(parseEquipmentCatalogue('[]'), isNull);
  });

  test('returns null without a generatedAt', () {
    expect(
      parseEquipmentCatalogue(jsonEncode({'format': 1, 'records': []})),
      isNull,
    );
  });

  test('skips a record missing manufacturer', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({'manufacturer': null}),
        _record({'id': 'b'}),
      ]),
    )!;
    expect(file.records.map((r) => r.id), ['b']);
  });

  test('skips a record with an unknown equipmentType', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({'equipmentType': 'jetpack'}),
      ]),
    )!;
    expect(file.records, isEmpty);
  });

  test('drops a non-https link and keeps the record', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({
          'links': {
            'product': 'javascript:alert(1)',
            'manual': 'http://maker.example.org/m.pdf',
            'support': 'https://maker.example.org/support',
          },
        }),
      ]),
    )!;
    final links = file.records.single.links;
    expect(links.product, isNull);
    expect(links.manual, isNull);
    expect(links.support, 'https://maker.example.org/support');
  });

  test('keeps the first of two records with one id', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({'model': 'First'}),
        _record({'model': 'Second'}),
      ]),
    )!;
    expect(file.records.single.model, 'First');
  });

  test('ignores unknown keys', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({'futureField': 1}),
      ]),
    )!;
    expect(file.records, hasLength(1));
  });

  test('drops attribute values whose key is not curated for the type', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({
          'attributes': {
            'lumens': 900,
            'connectivity': 'ble',
            'tank_identifier': 'A',
          },
        }),
      ]),
    )!;
    expect(file.records.single.attributes, {'connectivity': 'ble'});
  });

  test('drops a choice value that is not one of the choices', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({
          'attributes': {'connectivity': 'wifi'},
        }),
      ]),
    )!;
    expect(file.records.single.attributes, isEmpty);
  });

  test('drops a number attribute given as text', () {
    final file = parseEquipmentCatalogue(
      _file([
        _record({
          'equipmentType': 'light',
          'attributes': {'lumens': 'lots'},
        }),
      ]),
    )!;
    expect(file.records.single.attributes, isEmpty);
  });

  test('a record turns its values into the app attributes', () {
    final file = parseEquipmentCatalogue(_sample())!;
    final light = file.records[2];
    expect(light.attributeFor('lumens')!.valueNum, 1200);
    expect(light.attributeFor('beam_type')!.valueText, 'spot');
    expect(light.attributeFor('missing'), isNull);
  });
}
