import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4368. A download copies its computer's serial onto the source row
/// and the dive as it saves them, and a computer that learned its serial only
/// when the download completed left those copies empty for good. Saving the
/// serial on the computer now brings its downloaded copies along.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'teric',
            name: 'Shearwater Teric',
            manufacturer: const Value('Shearwater'),
            model: const Value('Teric'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final start = DateTime.utc(2026, 5, 1, 9);

  Future<String> download() => repository.importProfile(
    computerId: 'teric',
    profileStartTime: start,
    points: const [
      ProfilePointData(timestamp: 0, depth: 1.0),
      ProfilePointData(timestamp: 600, depth: 18.0),
      ProfilePointData(timestamp: 1200, depth: 6.0),
    ],
    durationSeconds: 1800,
    maxDepth: 18.0,
    forceNew: true,
  );

  test(
    'a serial saved after the download reaches its source and dive',
    () async {
      final diveId = await download();
      final source = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).getSingle();
      expect(source.computerSerial, isNull);

      final computer = (await repository.getComputerById('teric'))!;
      await repository.updateComputer(
        computer.copyWith(serialNumber: '8629AC48'),
      );

      final healed = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals(source.id))).getSingle();
      expect(healed.computerSerial, '8629AC48');
      expect(healed.hlc, source.hlc);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      expect(dive.diveComputerSerial, '8629AC48');
    },
  );
}
