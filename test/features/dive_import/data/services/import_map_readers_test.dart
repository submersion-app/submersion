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

  test('a custom "size" sits beside the curated one', () {
    final attrs = equipmentAttributesFromImport(
      [
        {'key': 'size', 'isCustom': true, 'valueText': 'XL'},
      ],
      equipmentId: 'e1',
      newId: newId,
      takenKeys: {'size'},
    );
    expect(attrs.single.isCustom, isTrue);
    expect(attrs.single.valueText, 'XL');
  });
}
