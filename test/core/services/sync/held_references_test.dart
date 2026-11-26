import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/held_references.dart';

void main() {
  const parent = HeldParent(table: 'trips', column: 'id', value: 'trip');

  test('held references survive an encode and decode, blobs included', () {
    final blob = Uint8List.fromList([0, 1, 2, 250]);
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
      orphans: {
        for (final orphan in [
          HeldOrphan(
            table: 'trip_checklists',
            key: const {'id': 'list'},
            parent: parent,
            rows: [
              const HeldRow(
                table: 'trip_checklists',
                values: {'id': 'list', 'sort_order': 2, 'weight': 1.5},
              ),
              HeldRow(table: 'media', values: {'id': 'm', 'thumb': blob}),
            ],
          ),
        ])
          orphan.id: orphan,
      },
    );

    final decoded = HeldReferences.decode(
      links: held.encodeLinks(),
      orphans: held.encodeOrphans(),
    );

    expect(decoded.encodeLinks(), held.encodeLinks());
    expect(decoded.encodeOrphans(), held.encodeOrphans());
    final link = decoded.links.values.single;
    expect(link.key, {'dive_id': 'd', 'equipment_id': 'e'});
    expect(link.parent.value, 's');
    final rows = decoded.orphans.values.single.rows;
    expect(rows.first.values, {'id': 'list', 'sort_order': 2, 'weight': 1.5});
    expect(rows.last.values['thumb'], blob);
  });

  test('a row id does not depend on the order of its key columns', () {
    expect(
      heldRowId('t', {'a': 1, 'b': 'x'}),
      heldRowId('t', {'b': 'x', 'a': 1}),
    );
    expect(heldRowId('t', {'a': 1}), isNot(heldRowId('u', {'a': 1})));
  });

  test('nothing stored decodes to nothing held', () {
    expect(HeldReferences.decode().isEmpty, isTrue);
    expect(HeldReferences.decode(links: '', orphans: '').isEmpty, isTrue);
  });
}
