import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in const ['A', 'B']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'tank',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('current and dated pairings follow repository writes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(currentPairingProvider('A'), (_, _) {});
    addTearDown(sub.close);
    for (final day in [DateTime(2026, 3, 3, 9), DateTime(2026, 3, 2)]) {
      final keep = container.listen(
        pairingOnProvider((equipmentId: 'B', day: day)),
        (_, _) {},
      );
      addTearDown(keep.close);
    }
    expect(await container.read(currentPairingProvider('A').future), isNull);

    await container
        .read(cylinderPairingRepositoryProvider)
        .createPairing(
          cylinderAId: 'A',
          cylinderBId: 'B',
          pairedOn: DateTime(2026, 3, 3),
        );
    await pumpEventQueue();

    final current = await container.read(currentPairingProvider('A').future);
    expect(current?.partnerOf('A'), 'B');
    final dated = await container.read(
      pairingOnProvider((
        equipmentId: 'B',
        day: DateTime(2026, 3, 3, 9),
      )).future,
    );
    expect(dated?.partnerOf('B'), 'A');
    final before = await container.read(
      pairingOnProvider((equipmentId: 'B', day: DateTime(2026, 3, 2))).future,
    );
    expect(before, isNull);
    final history = await container.read(
      pairingsForCylinderProvider('B').future,
    );
    expect(history, hasLength(1));
  });
}
