import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// A cylinder a file import left without its transmitter serial takes the
/// serial of the downloaded cylinder merged into it, and with it the setup
/// the diver gave that transmitter (issue #4388).
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService consolidation;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    consolidation = DiveConsolidationService(diveRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// [tanks] is (o2, serial) per cylinder, in order.
  Future<void> seedDive(
    String id,
    String computerId,
    List<(double, String?)> tanks,
  ) async {
    final entry = DateTime.utc(2026, 8, 8, 10, 16);
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 47),
        maxDepth: 20,
        tanks: [
          for (final (i, (o2, _)) in tanks.indexed)
            domain.DiveTank(
              id: '$id-t$i',
              gasMix: domain.GasMix(o2: o2),
              order: i,
              computerId: computerId,
            ),
        ],
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 1400, depth: 20),
          domain.DiveProfilePoint(timestamp: 2820, depth: 0),
        ],
      ),
    );
    for (final (i, (_, serial)) in tanks.indexed) {
      await (db.update(db.diveTanks)..where((t) => t.id.equals('$id-t$i')))
          .write(DiveTanksCompanion(transmitterSerial: Value(serial)));
    }
    await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
      DivesCompanion(computerId: Value(computerId)),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 8, 8),
            createdAt: DateTime.utc(2026, 8, 8),
          ).copyWith(
            isPrimary: const Value(true),
            computerId: Value(computerId),
          ),
        );
  }

  Future<DiveTank> row(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  test('a merged cylinder with no serial takes the download\'s', () async {
    await seedDive('t', 'file', [(32, null)]);
    await seedDive('s', 'perdix', [(32, '76287')]);

    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    expect((await row('t-t0')).transmitterSerial, '76287');
  });

  test('a serial the target already has is never replaced', () async {
    await seedDive('t', 'file', [(32, '11111')]);
    await seedDive('s', 'perdix', [(32, '76287')]);

    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final tanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(tanks.map((t) => t.transmitterSerial), contains('11111'));
    expect((await row('t-t0')).transmitterSerial, '11111');
  });

  test('two cylinders on one mix are paired by guesswork, so neither '
      'takes a serial', () async {
    await seedDive('t', 'file', [(21, null), (21, null)]);
    await seedDive('s', 'perdix', [(21, '76287'), (21, '76290')]);

    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    expect((await row('t-t0')).transmitterSerial, isNull);
    expect((await row('t-t1')).transmitterSerial, isNull);
  });

  test('the merged dive takes the setup of a transmitter the diver set '
      'up', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver1', 'A', 1, 1)",
    );
    await TransmitterRepository().create(
      Transmitter(
        id: 'tx',
        diverId: 'diver1',
        transmitterSerial: '76287',
        label: 'T2',
        role: TankRole.sidemountLeft,
        volumeL: 10,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await seedDive('t', 'file', [(32, null)]);
    await seedDive('s', 'perdix', [(32, '76287')]);

    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final tank = await row('t-t0');
    expect(tank.tankRole, 'sidemountLeft');
    expect(tank.tankName, 'T2');
  });

  test('undo puts the serial back to empty', () async {
    await seedDive('t', 'file', [(32, null)]);
    await seedDive('s', 'perdix', [(32, '76287')]);

    final outcome = await consolidation.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
    );
    await consolidation.undo(outcome.snapshot);

    expect((await row('t-t0')).transmitterSerial, isNull);
  });
}
