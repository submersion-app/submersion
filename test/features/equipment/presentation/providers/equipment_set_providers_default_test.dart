import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('defaultEquipmentSetProvider returns the flagged set', () async {
    final repo = EquipmentSetRepository();
    await repo.createSet(
      EquipmentSet(
        id: 'a',
        diverId: 'd1',
        name: 'A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.setAsDefault('a', diverId: 'd1');

    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(defaultEquipmentSetProvider.future);
    expect(result?.id, 'a');
  });
}
