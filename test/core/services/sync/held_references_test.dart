import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/held_references.dart';

void main() {
  test('held references survive an encode and decode', () {
    final held = HeldReferences(
      links: {
        for (final link in [
          const HeldLink(
            table: 'dive_equipment',
            key: {'dive_id': 'd', 'equipment_id': 'e'},
            column: 'via_set_id',
            parent: HeldParent(
              table: 'equipment_sets',
              column: 'id',
              value: 's',
            ),
            hlc: '000000000001000:000000:phone',
          ),
        ])
          link.id: link,
      },
    );

    final decoded = HeldReferences.decode(held.encode());

    expect(decoded.encode(), held.encode());
    final link = decoded.links.values.single;
    expect(link.key, {'dive_id': 'd', 'equipment_id': 'e'});
    expect(link.parent.value, 's');
  });

  test('a row id does not depend on the order of its key columns', () {
    expect(
      heldRowId('t', {'a': 1, 'b': 'x'}),
      heldRowId('t', {'b': 'x', 'a': 1}),
    );
    expect(heldRowId('t', {'a': 1}), isNot(heldRowId('u', {'a': 1})));
  });

  test('nothing stored decodes to nothing held', () {
    expect(HeldReferences.decode(null).isEmpty, isTrue);
    expect(HeldReferences.decode('').isEmpty, isTrue);
  });
}
