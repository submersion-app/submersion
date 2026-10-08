import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final shop = EquipmentLocation(
    id: 'shop',
    name: 'Shop',
    kind: EquipmentLocationKind.serviceShop,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentItem item(String id, EquipmentStatus status) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.regulator,
    status: status,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    // reg has one installed part, second; bcd stands alone.
    for (final id in ['reg', 'second', 'bcd']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              parentEquipmentId: Value(id == 'second' ? 'reg' : null),
            ),
          );
    }
    await db
        .into(db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: 'shop',
            name: 'Shop',
            kind: const Value('serviceShop'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('asks about parts, moves them, and offers status for every eligible '
      'item', () async {
    int? partsAsked;
    (EquipmentStatus, int)? statusAsked;
    List<String>? statusIds;
    final flow = EquipmentMoveFlow(
      moves: EquipmentLocationMoveRepository(),
      askMoveParts: (n) async {
        partsAsked = n;
        return true;
      },
      askStatus: (status, n) async {
        statusAsked = (status, n);
        return true;
      },
      setStatus: (ids, status) async => statusIds = ids,
    );
    final moved = await flow.run(
      items: [
        item('reg', EquipmentStatus.active),
        item('bcd', EquipmentStatus.inService),
      ],
      target: shop,
      movedAt: DateTime(2026, 9, 3),
      note: 'annual',
    );
    expect(partsAsked, 1);
    expect(moved, 3);
    expect(await EquipmentLocationMoveRepository().getCurrentLocationIds(), {
      'reg': 'shop',
      'second': 'shop',
      'bcd': 'shop',
    });
    // bcd is already In Service, so only reg and its part are offered.
    expect(statusAsked, (EquipmentStatus.inService, 2));
    expect(statusIds, unorderedEquals(['reg', 'second']));
  });

  test('declining parts moves only the selection; no offer for no '
      'location', () async {
    var statusAsked = false;
    final flow = EquipmentMoveFlow(
      moves: EquipmentLocationMoveRepository(),
      askMoveParts: (_) async => false,
      askStatus: (_, _) async => statusAsked = true,
      setStatus: (_, _) async {},
    );
    final moved = await flow.run(
      items: [item('reg', EquipmentStatus.active)],
      target: null,
      movedAt: DateTime(2026, 9, 3),
    );
    expect(moved, 1);
    expect(await EquipmentLocationMoveRepository().getCurrentLocationIds(), {
      'reg': null,
    });
    expect(statusAsked, isFalse);
  });

  test('no parts prompt when nothing is installed; declining the status '
      'offer writes nothing', () async {
    var partsAsked = false;
    var statusWritten = false;
    final flow = EquipmentMoveFlow(
      moves: EquipmentLocationMoveRepository(),
      askMoveParts: (_) async => partsAsked = true,
      askStatus: (_, _) async => false,
      setStatus: (_, _) async => statusWritten = true,
    );
    await flow.run(
      items: [item('bcd', EquipmentStatus.active)],
      target: shop,
      movedAt: DateTime(2026, 9, 3),
    );
    expect(partsAsked, isFalse);
    expect(statusWritten, isFalse);
  });

  test(
    'a failed status write is reported apart; the moves still count',
    () async {
      var reported = false;
      final flow = EquipmentMoveFlow(
        moves: EquipmentLocationMoveRepository(),
        askMoveParts: (_) async => false,
        askStatus: (_, _) async => true,
        setStatus: (_, _) async => throw StateError('disk full'),
        onStatusFailed: () => reported = true,
      );
      final moved = await flow.run(
        items: [item('bcd', EquipmentStatus.active)],
        target: shop,
        movedAt: DateTime(2026, 9, 3),
      );
      expect(moved, 1);
      expect(reported, isTrue);
      expect(await EquipmentLocationMoveRepository().getCurrentLocationIds(), {
        'bcd': 'shop',
      });
    },
  );
}
