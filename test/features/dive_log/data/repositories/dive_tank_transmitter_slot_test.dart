import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// `dive_tanks.transmitter_slot` is computer-owned (issue #4347): it
/// round-trips, an edit never clears it, and it moves with the recording.
void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed() => repo.createDive(
    domain.Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 9, 8, 10),
      tanks: const [
        domain.DiveTank(
          id: 'tA',
          gasMix: domain.GasMix(o2: 21, he: 0),
          order: 0,
          transmitterSerial: '111',
          sourceTankIndex: 0,
          transmitterSlot: 2,
        ),
        domain.DiveTank(
          id: 'tB',
          gasMix: domain.GasMix(o2: 50, he: 0),
          order: 1,
          transmitterSerial: '222',
          sourceTankIndex: 1,
          transmitterSlot: 3,
        ),
      ],
    ),
  );

  Future<Map<String, int?>> slots() async {
    final dive = await repo.getDiveById('d1');
    return {for (final t in dive!.tanks) t.id: t.transmitterSlot};
  }

  test('the slot round-trips through create and read', () async {
    await seed();
    expect(await slots(), {'tA': 2, 'tB': 3});
  });

  test('an edit that does not carry the slot keeps the stored one', () async {
    await seed();
    final dive = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      dive.copyWith(
        tanks: [
          for (final t in dive.tanks)
            t.copyWith(volume: 12, clearTransmitterSlot: true),
        ],
      ),
    );
    expect(await slots(), {'tA': 2, 'tB': 3});
  });

  test('swapping recordings swaps the slots with them', () async {
    await seed();
    await TankPressureRepository().exchangeTankSources(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );
    final db = DatabaseService.instance.database;
    final rows = await db.select(db.diveTanks).get();
    expect({for (final r in rows) r.id: r.transmitterSlot}, {'tA': 3, 'tB': 2});
  });
}
