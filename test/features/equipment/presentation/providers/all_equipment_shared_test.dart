import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'bcd',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('owner'),
          ),
        );
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
  });

  tearDown(tearDownTestDatabase);

  test(
    'the list every export reads includes gear shared with the diver',
    () async {
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'wife'),
        ],
      );
      addTearDown(container.dispose);
      final items = await container.read(allEquipmentProvider.future);
      expect(items.map((e) => e.id), ['bcd']);
    },
  );
}
