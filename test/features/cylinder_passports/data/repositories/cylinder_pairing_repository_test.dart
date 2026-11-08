import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';

import '../../../../helpers/test_database.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  late AppDatabase db;
  late CylinderPairingRepository repo;

  Future<void> seedCylinder(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
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

  Future<List<String>> pendingIds() async =>
      (await db
              .customSelect(
                "SELECT record_id FROM sync_records "
                "WHERE entity_type = 'cylinderPairings'",
              )
              .get())
          .map((r) => r.read<String>('record_id'))
          .toList();

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderPairingRepository();
    for (final id in const ['A', 'B', 'C', 'D']) {
      await seedCylinder(id);
    }
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'REG',
            name: 'REG',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('a new pairing reads back from both cylinders', () async {
    final p = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: DateTime(2026, 3, 3, 15, 30),
    );
    expect(p.pairedOn, d(2026, 3, 3));
    expect(p.isOpen, isTrue);
    expect((await repo.getForCylinder('A')).single.id, p.id);
    expect((await repo.getForCylinder('B')).single.id, p.id);
    expect(await repo.getForCylinder('C'), isEmpty);
    expect(await pendingIds(), contains(p.id));
  });

  test('a cylinder cannot pair with itself', () async {
    expect(
      () => repo.createPairing(
        cylinderAId: 'A',
        cylinderBId: 'A',
        pairedOn: d(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });

  test('pairing a cylinder that has a partner names the clash', () async {
    final ac = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'C',
      pairedOn: d(2026, 1, 1),
    );
    await expectLater(
      repo.createPairing(
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: d(2026, 9, 14),
      ),
      throwsA(
        isA<PairingClash>().having(
          (e) => e.clashes.map((p) => p.id),
          'clashes',
          [ac.id],
        ),
      ),
    );
    expect((await repo.getForCylinder('B')), isEmpty);
  });

  test('replace ends the open pairings on the new start day', () async {
    await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'C',
      pairedOn: d(2026, 1, 1),
    );
    await repo.createPairing(
      cylinderAId: 'B',
      cylinderBId: 'D',
      pairedOn: d(2026, 2, 1),
    );
    final ab = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2026, 9, 14),
      replace: true,
    );
    final ofA = await repo.getForCylinder('A');
    expect(ofA.first.id, ab.id);
    expect(ofA.last.partnerOf('A'), 'C');
    expect(ofA.last.unpairedOn, d(2026, 9, 14));
    final ofD = await repo.getForCylinder('D');
    expect(ofD.single.unpairedOn, d(2026, 9, 14));
    expect((await repo.pairingOn('A', DateTime(2026, 9, 14, 8)))!.id, ab.id);
    expect(
      (await repo.pairingOn('A', DateTime(2026, 9, 13, 8)))!.partnerOf('A'),
      'C',
    );
  });

  test('a backdated start inside a closed pairing is refused even with '
      'replace', () async {
    final ac = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'C',
      pairedOn: d(2025, 1, 1),
    );
    await repo.endPairing(ac.id, d(2025, 12, 1));
    await expectLater(
      repo.createPairing(
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: d(2025, 6, 1),
        replace: true,
      ),
      throwsA(isA<PairingClash>()),
    );
  });

  test(
    'replace refuses an open pairing that starts after the new one',
    () async {
      await repo.createPairing(
        cylinderAId: 'A',
        cylinderBId: 'C',
        pairedOn: d(2026, 6, 1),
      );
      await expectLater(
        repo.createPairing(
          cylinderAId: 'A',
          cylinderBId: 'B',
          pairedOn: d(2026, 1, 1),
          replace: true,
        ),
        throwsA(isA<PairingClash>()),
      );
    },
  );

  test('endPairing closes it on that day and refuses an end before the '
      'start', () async {
    final ab = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2026, 3, 3),
    );
    expect(() => repo.endPairing(ab.id, d(2026, 3, 3)), throwsArgumentError);
    await repo.endPairing(ab.id, DateTime(2026, 9, 14, 18));
    final p = (await repo.getForCylinder('A')).single;
    expect(p.unpairedOn, d(2026, 9, 14));
    expect(await repo.pairingOn('A', DateTime(2026, 9, 14)), isNull);
  });

  test('deletePairing removes it and logs a tombstone', () async {
    final ab = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2026, 3, 3),
    );
    await repo.deletePairing(ab.id);
    expect(await repo.getForCylinder('A'), isEmpty);
    final tombstones = await db
        .customSelect(
          'SELECT record_id FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString('cylinderPairings')],
        )
        .get();
    expect(tombstones.single.read<String>('record_id'), ab.id);
  });

  test('replacing a pairing made the same day deletes it, so a wrong link '
      'made today can be put right', () async {
    final wrong = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'C',
      pairedOn: d(2026, 11, 6),
    );
    final right = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2026, 11, 6),
      replace: true,
    );
    expect((await repo.getForCylinder('A')).map((p) => p.id), [right.id]);
    expect(await repo.getForCylinder('C'), isEmpty);
    final tombstones = await db
        .customSelect(
          'SELECT record_id FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString('cylinderPairings')],
        )
        .get();
    expect(tombstones.single.read<String>('record_id'), wrong.id);
  });

  test('only two cylinders can be paired', () async {
    expect(
      () => repo.createPairing(
        cylinderAId: 'A',
        cylinderBId: 'REG',
        pairedOn: d(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });

  test('a pairing can be created already ended, checked as a whole', () async {
    final past = await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2025, 1, 1),
      unpairedOn: d(2025, 6, 1),
    );
    expect(past.unpairedOn, d(2025, 6, 1));
    expect((await repo.getForCylinder('A')).single.unpairedOn, d(2025, 6, 1));
    // Open from later: no overlap with the ended one.
    await repo.createPairing(
      cylinderAId: 'A',
      cylinderBId: 'C',
      pairedOn: d(2025, 6, 1),
    );
    expect(
      () => repo.createPairing(
        cylinderAId: 'B',
        cylinderBId: 'D',
        pairedOn: d(2024, 1, 1),
        unpairedOn: d(2024, 1, 1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.createPairing(
        cylinderAId: 'B',
        cylinderBId: 'D',
        pairedOn: d(2025, 3, 1),
        unpairedOn: d(2025, 4, 1),
      ),
      throwsA(isA<PairingClash>()),
    );
  });
}
