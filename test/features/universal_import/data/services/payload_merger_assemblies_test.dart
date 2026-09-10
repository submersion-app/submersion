import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// The nested reference lists issue #1487 adds to entity maps (`components`
/// on an item, `gearLinks` on a dive) get the same per-file prefix and the
/// same fold rewriting as every other reference.
void main() {
  const merger = PayloadMerger();

  ImportPayload payloadWith({
    List<Map<String, dynamic>> dives = const [],
    List<Map<String, dynamic>> equipment = const [],
  }) => ImportPayload(
    entities: {
      if (dives.isNotEmpty) ImportEntityType.dives: dives,
      if (equipment.isNotEmpty) ImportEntityType.equipment: equipment,
    },
  );

  test('namespaces nested component and gear link refs per file', () {
    final a = payloadWith(
      equipment: [
        {
          'uddfId': 'equip_reg',
          'name': 'Reg',
          'type': 'regulator',
          'components': [
            {'componentRef': 'equip_hose', 'role': 'Primary', 'sortOrder': 0},
          ],
        },
        {'uddfId': 'equip_hose', 'name': 'Hose', 'type': 'hose'},
      ],
      dives: [
        {
          'dateTime': DateTime(2026, 1, 1, 9),
          'gearLinks': [
            {'itemRef': 'equip_hose', 'viaRef': 'equip_reg', 'setRef': 'set_w'},
            {'itemRef': 'equip_reg', 'viaRef': null, 'setRef': null},
          ],
        },
      ],
    );
    final merged = merger.merge([
      FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
    ]);

    final items = merged.entitiesOf(ImportEntityType.equipment);
    final reg = items.firstWhere((e) => e['name'] == 'Reg');
    final parts = reg['components'] as List;
    expect(parts.single['componentRef'], 'f0:equip_hose');
    expect(parts.single['role'], 'Primary');
    expect(
      items.firstWhere((e) => e['name'] == 'Hose').containsKey('components'),
      isFalse,
    );

    final links =
        merged.entitiesOf(ImportEntityType.dives)[0]['gearLinks'] as List;
    expect(links[0]['itemRef'], 'f0:equip_hose');
    expect(links[0]['viaRef'], 'f0:equip_reg');
    expect(links[0]['setRef'], 'f0:set_w');
    expect(links[1]['itemRef'], 'f0:equip_reg');
    expect(links[1]['viaRef'], isNull);
    expect(links[1]['setRef'], isNull);
  });

  test('rewrites folded equipment inside components and gear links', () {
    final a = payloadWith(
      equipment: [
        {'uddfId': 'h1', 'name': 'Hose', 'type': 'hose'},
      ],
    );
    final b = payloadWith(
      equipment: [
        {'uddfId': 'h2', 'name': 'Hose', 'type': 'hose'},
        {
          'uddfId': 'r2',
          'name': 'Reg',
          'type': 'regulator',
          'components': [
            {'componentRef': 'h2', 'role': '', 'sortOrder': 0},
          ],
        },
      ],
      dives: [
        {
          'dateTime': DateTime(2026, 2, 1, 9),
          'gearLinks': [
            {'itemRef': 'h2', 'viaRef': 'r2', 'setRef': null},
          ],
        },
      ],
    );
    final merged = merger.merge([
      FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
      FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
    ]);

    final reg = merged
        .entitiesOf(ImportEntityType.equipment)
        .firstWhere((e) => e['name'] == 'Reg');
    expect((reg['components'] as List).single['componentRef'], 'f0:h1');
    final links =
        merged.entitiesOf(ImportEntityType.dives)[0]['gearLinks'] as List;
    expect(links.single['itemRef'], 'f0:h1');
    expect(links.single['viaRef'], 'f1:r2');
  });
}
