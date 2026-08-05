import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EmergencyChamberRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EmergencyChamberRepository();
  });

  tearDown(() => tearDownTestDatabase());

  test('create, list, delete round-trip with tombstone', () async {
    final created = await repo.createChamber(
      name: 'Local Chamber',
      country: 'US',
      phone: '+1-555-0100',
      city: 'Testville',
    );
    expect(created.isBuiltIn, isFalse);

    final chambers = await repo.getUserChambers();
    expect(chambers, hasLength(1));
    expect(chambers.single.name, 'Local Chamber');

    await repo.deleteChamber(created.id);
    expect(await repo.getUserChambers(), isEmpty);

    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.entityType), contains('emergencyChambers'));
  });

  test('watchChanges exposes a stream over the emergency_chambers table', () {
    expect(repo.watchChanges(), isA<Stream<void>>());
  });

  test('getUserChambers scopes to a diver plus null-diver globals', () async {
    // diver_id is an FK to divers, so the referenced rows must exist.
    for (final id in ['diver-a', 'diver-b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }

    await repo.createChamber(
      name: 'Diver A Chamber',
      country: 'US',
      phone: '+1-555-0001',
      diverId: 'diver-a',
    );
    await repo.createChamber(
      name: 'Diver B Chamber',
      country: 'US',
      phone: '+1-555-0002',
      diverId: 'diver-b',
    );
    await repo.createChamber(
      name: 'Legacy Global Chamber',
      country: 'US',
      phone: '+1-555-0003',
      // no diverId: legacy/global row visible to every diver
    );

    final forA = await repo.getUserChambers(diverId: 'diver-a');
    expect(
      forA.map((c) => c.name),
      containsAll(['Diver A Chamber', 'Legacy Global Chamber']),
    );
    expect(forA.map((c) => c.name), isNot(contains('Diver B Chamber')));

    // No active diver: all rows returned (no scoping applied).
    expect(await repo.getUserChambers(), hasLength(3));
  });
}
