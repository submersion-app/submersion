import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// dive_tanks.usage_duration (issue #1496): how long a cylinder was breathed
/// as the source log recorded it. Import-owned, like the transmitter serial:
/// an edit that rebuilds the tank without it must not wipe it.
void main() {
  late db.AppDatabase database;
  late DiveRepository repository;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> diveWithRecordedTank() => repository.createDive(
    Dive(
      id: '',
      dateTime: DateTime.utc(2026, 9, 12, 8),
      tanks: const [
        DiveTank(id: '', volume: 11.1, usageDuration: Duration(minutes: 25)),
      ],
    ),
  );

  Future<int?> storedUsageSeconds() async =>
      (await database.select(database.diveTanks).getSingle()).usageDuration;

  test('createDive stores the recorded duration in seconds', () async {
    await diveWithRecordedTank();
    expect(await storedUsageSeconds(), 25 * 60);
  });

  test('getDiveById reads it back onto the tank', () async {
    final created = await diveWithRecordedTank();
    final dive = await repository.getDiveById(created.id);
    expect(dive!.tanks.single.usageDuration, const Duration(minutes: 25));
  });

  test('getAllDives reads it back onto the tank', () async {
    await diveWithRecordedTank();
    final dives = await repository.getAllDives();
    expect(
      dives.single.tanks.single.usageDuration,
      const Duration(minutes: 25),
    );
  });

  test('an edit that rebuilds the tank without it keeps it', () async {
    final created = await diveWithRecordedTank();
    final dive = (await repository.getDiveById(created.id))!;
    final tank = dive.tanks.single;
    // Edit flows rebuild the tank field by field.
    await repository.updateDive(
      dive.copyWith(tanks: [DiveTank(id: tank.id, volume: 12.0)]),
    );
    expect(await storedUsageSeconds(), 25 * 60);
  });

  test('a tank added by an edit stores its own', () async {
    final created = await diveWithRecordedTank();
    final dive = (await repository.getDiveById(created.id))!;
    await repository.updateDive(
      dive.copyWith(
        tanks: [
          ...dive.tanks,
          const DiveTank(
            id: 'added',
            order: 1,
            usageDuration: Duration(minutes: 7),
          ),
        ],
      ),
    );
    final row = await (database.select(
      database.diveTanks,
    )..where((t) => t.id.equals('added'))).getSingle();
    expect(row.usageDuration, 7 * 60);
  });

  test('an undo restore puts it back; a template does not carry it', () async {
    final created = await diveWithRecordedTank();
    final tank = (await repository.getDiveById(created.id))!.tanks.single;

    await repository.bulkReplaceTanks([created.id], [tank]);
    expect(await storedUsageSeconds(), isNull);

    await repository.bulkReplaceTanks([created.id], [tank], restoreLinks: true);
    expect(await storedUsageSeconds(), 25 * 60);
  });
}
