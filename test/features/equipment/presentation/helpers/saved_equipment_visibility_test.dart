import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/helpers/saved_equipment_visibility.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../../helpers/test_database.dart';

/// A just-saved item the list's current view hides gets a view that shows
/// it (#3068): the default view hides wishlist gear, so a new Wanted item
/// seemed not to have been saved at all.
void main() {
  late AppDatabase db;
  late QueryIdSetRunner runner;
  final ms = DateTime.now().millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    runner = QueryIdSetRunner(db);
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    Future<void> item(
      String id,
      String type, {
      String status = 'active',
      bool isActive = true,
    }) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            diverId: const Value('me'),
            status: Value(status),
            isActive: Value(isActive),
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await item('fins', 'fins');
    await item('wish', 'fins', status: 'wanted', isActive: false);
    await item('old', 'regulator', status: 'retired', isActive: false);
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<EquipmentFilterState?> reveal(
    EquipmentFilterState filter,
    String id,
    EquipmentStatus status,
  ) => viewRevealingSavedEquipment(
    runner: runner,
    filter: filter,
    diverId: 'me',
    equipmentId: id,
    status: status,
  );

  test(
    'a wanted item saved under the default view needs the Wanted view',
    () async {
      expect(
        await reveal(
          const EquipmentFilterState(),
          'wish',
          EquipmentStatus.wanted,
        ),
        const EquipmentFilterState(status: EquipmentStatus.wanted),
      );
    },
  );

  test(
    'a retired item saved under the default view needs the Retired view',
    () async {
      expect(
        await reveal(
          const EquipmentFilterState(),
          'old',
          EquipmentStatus.retired,
        ),
        const EquipmentFilterState(status: EquipmentStatus.retired),
      );
    },
  );

  test(
    'nothing to reveal when the current view already shows the item',
    () async {
      expect(
        await reveal(
          const EquipmentFilterState(),
          'fins',
          EquipmentStatus.active,
        ),
        isNull,
      );
      expect(
        await reveal(
          const EquipmentFilterState(status: EquipmentStatus.wanted),
          'wish',
          EquipmentStatus.wanted,
        ),
        isNull,
      );
    },
  );

  test(
    'an item hidden by another axis falls back to the default view',
    () async {
      expect(
        await reveal(
          const EquipmentFilterState(type: EquipmentType.bcd),
          'fins',
          EquipmentStatus.active,
        ),
        const EquipmentFilterState(),
      );
    },
  );
}
