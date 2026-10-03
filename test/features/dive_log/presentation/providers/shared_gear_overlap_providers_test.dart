import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('one profile gives no notes without a query', () async {
    final t = DateTime(2026);
    final container = ProviderContainer(
      overrides: [
        allDiversProvider.overrideWith(
          (ref) async => [
            Diver(id: 'bill', name: 'Bill', createdAt: t, updatedAt: t),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(allDiversProvider.future);
    final notes = await container.read(
      sharedGearOverlapProvider((
        diveId: null,
        diverId: 'bill',
        entry: DateTime.utc(2026, 5, 1, 10),
        exit: DateTime.utc(2026, 5, 1, 10, 40),
      )).future,
    );
    expect(notes, isEmpty);
  });

  group('with two profiles', () {
    late AppDatabase db;
    setUp(() async => db = await setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    test("reads the gear on the other profile's overlapping dive", () async {
      final t = DateTime(2026);
      for (final id in ['bill', 'anna']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id == 'anna' ? 'Anna' : 'Bill',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'light',
              name: 'Light',
              type: 'light',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final annaEntry = DateTime.utc(2026, 5, 1, 10, 2);
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'a1',
              diverId: const Value('anna'),
              diveDateTime: annaEntry.millisecondsSinceEpoch,
              entryTime: Value(annaEntry.millisecondsSinceEpoch),
              runtime: const Value(40 * 60),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'a1', equipmentId: 'light'),
          );
      final container = ProviderContainer(
        overrides: [
          allDiversProvider.overrideWith(
            (ref) async => [
              Diver(id: 'bill', name: 'Bill', createdAt: t, updatedAt: t),
              Diver(id: 'anna', name: 'Anna', createdAt: t, updatedAt: t),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(allDiversProvider.future);
      final notes = await container.read(
        sharedGearOverlapProvider((
          diveId: null,
          diverId: 'bill',
          entry: DateTime.utc(2026, 5, 1, 10),
          exit: DateTime.utc(2026, 5, 1, 10, 40),
        )).future,
      );
      expect(notes.keys, ['light']);
      expect(notes['light']!.diverName, 'Anna');
      expect(notes['light']!.entry, annaEntry);
    });
  });
}
