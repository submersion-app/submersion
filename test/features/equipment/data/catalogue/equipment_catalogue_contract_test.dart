import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/equipment/domain/catalogue/catalogue_attribute_keys.dart';

/// The contract shared with submersion-app/equipment-catalogue: its sample
/// file, byte for byte, and the attribute keys its validator checks records
/// against. A change on either side fails here, in the PR that makes it.
String _fixture(String name) => File(
  p.join('test', 'fixtures', 'equipment_catalogue', name),
).readAsStringSync();

/// The SHA-256 of schema/sample.json in the catalogue repository. Its own
/// test pins the same value.
const _sampleSha256 =
    '803f9d488dea5dac1be7fecfe18e2494ea37d3b5aa4d9fe6fa32d3c01a8fdd0c';

void main() {
  test('the sample fixture is the catalogue repository sample', () {
    final bytes = File(
      p.join('test', 'fixtures', 'equipment_catalogue', 'sample.json'),
    ).readAsBytesSync();
    expect(sha256.convert(bytes).toString(), _sampleSha256);
  });

  test('the attribute key fixture matches the curated attribute catalogue', () {
    final current = const JsonEncoder.withIndent(
      '  ',
    ).convert(exportEquipmentAttributeKeys());
    if (Platform.environment['UPDATE_EQUIPMENT_CATALOGUE_KEYS'] == '1') {
      File(
        p.join(
          'test',
          'fixtures',
          'equipment_catalogue',
          'attribute-keys.json',
        ),
      ).writeAsStringSync('$current\n');
    }
    expect(
      jsonDecode(current),
      jsonDecode(_fixture('attribute-keys.json')),
      reason:
          'Rerun this test with UPDATE_EQUIPMENT_CATALOGUE_KEYS=1 and copy '
          'test/fixtures/equipment_catalogue/attribute-keys.json to '
          'schema/attribute-keys.json in submersion-app/equipment-catalogue.',
    );
  });

  test('a catalogue never offers purchase, appearance or system keys', () {
    final keys = exportEquipmentAttributeKeys();
    for (final byKey in keys.values) {
      expect(byKey.keys, isNot(contains('product_url')));
      expect(byKey.keys, isNot(contains('color')));
      expect(byKey.keys, isNot(contains('passport_id')));
    }
  });

  test('a catalogue never offers what belongs to one physical item', () {
    final keys = exportEquipmentAttributeKeys();
    for (final byKey in keys.values) {
      for (final perItem in [
        'tank_identifier',
        'size',
        'prescription',
        'cell_slot',
        'cylinder_use',
        'worn_as',
      ]) {
        expect(byKey.keys, isNot(contains(perItem)));
      }
    }
  });

  test('a dive computer may be offered its connectivity and mount', () {
    final computer = exportEquipmentAttributeKeys()['computer']!;
    expect(computer['connectivity'], {
      'kind': 'choice',
      'choices': ['ble', 'usb', 'infrared', 'none'],
    });
    expect(computer.keys, contains('mount'));
  });
}
