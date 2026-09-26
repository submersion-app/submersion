import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';

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
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-1',
            name: 'Steel 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('fills follow the passport id and refresh on a write', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final pid = await CylinderPassportRepository().ensurePassportId('eq-1');
    // A listener keeps the providers active, as a mounted widget would. With
    // none, Riverpod 3 treats them as paused and invalidateSelfWhen defers
    // the refresh until they resume.
    container.listen(fillsForEquipmentProvider('eq-1'), (_, _) {});
    container.listen(newestFillProvider('eq-1'), (_, _) {});

    expect(
      await container.read(fillsForEquipmentProvider('eq-1').future),
      isEmpty,
    );
    expect(await container.read(newestFillProvider('eq-1').future), isNull);

    final t = DateTime(2026, 9, 1);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: pid,
        equipmentId: 'eq-1',
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final fills = await container.read(
      fillsForEquipmentProvider('eq-1').future,
    );
    expect(fills.map((f) => f.o2Percent), [32]);
    expect(
      (await container.read(newestFillProvider('eq-1').future))!.o2Percent,
      32,
    );
    expect(await container.read(passportIdProvider('eq-1').future), pid);
  });
}
