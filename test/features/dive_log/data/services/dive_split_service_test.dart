import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late DiveSplitService service;
  late AppDatabase db;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  final baseTime = DateTime.utc(2026, 5, 7, 14, 6).millisecondsSinceEpoch;

  Future<void> insertComputer(String id, String name) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(baseTime),
            updatedAt: Value(baseTime),
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(baseTime),
            computerId: Value(computerId),
            entryTime: Value(baseTime),
            exitTime: Value(baseTime + 56 * 60 * 1000),
            maxDepth: const Value(21.7),
            createdAt: Value(baseTime),
            updatedAt: Value(baseTime),
          ),
        );
  }

  Future<void> insertSource(
    String id,
    String diveId,
    String? computerId, {
    required bool isPrimary,
    double? maxDepth,
    DateTime? createdAt,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            maxDepth: Value(maxDepth),
            importedAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
            createdAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
          ),
        );
  }

  var rowCounter = 0;

  /// One single-sample series per call, for tests exercising the split
  /// writer, which now reads and writes series rows instead of legacy
  /// `dive_profiles` rows.
  Future<String> insertProfileSeriesRow(
    String diveId,
    String? computerId, {
    required bool isPrimary,
    int timestamp = 0,
    double depth = 10.0,
  }) {
    return profileSeries.insertSeries(
      diveId: diveId,
      computerId: computerId,
      isPrimary: isPrimary,
      samples: [ProfileSample(timestamp: timestamp, depth: depth)],
      now: 1000,
    );
  }

  Future<String> insertTank(String diveId, String? computerId) async {
    final id = 'tank-${rowCounter++}';
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            tankOrder: const Value(0),
          ),
        );
    return id;
  }

  /// Inserts one single-sample tank pressure series, for tests exercising
  /// the split writer, which now reads and writes series rows instead of
  /// legacy `tank_pressure_profiles` rows.
  Future<String> insertTankPressureSeriesRow(
    String diveId,
    String tankId,
    String? computerId,
  ) {
    return tankSeries.insertSeries(
      diveId: diveId,
      tankId: tankId,
      computerId: computerId,
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
  }

  Future<String> insertEvent(String diveId, String? computerId) async {
    final id = 'ev-${rowCounter++}';
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            timestamp: const Value(30),
            eventType: const Value('bookmark'),
            createdAt: Value(baseTime),
          ),
        );
    return id;
  }

  Future<String> insertGasSwitch(String diveId, String tankId) async {
    final id = 'gs-${rowCounter++}';
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            tankId: Value(tankId),
            timestamp: const Value(600),
            createdAt: Value(baseTime),
          ),
        );
    return id;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    service = DiveSplitService(repository);
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    rowCounter = 0;

    // Foreign keys must be enforced for these tests to be meaningful.
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);

    await insertComputer('dc-a', 'Kiyans Teric');
    await insertComputer('dc-b', 'Erics Teric');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<String>> fkViolations() async {
    final rows = await db.customSelect('PRAGMA foreign_key_check').get();
    return rows.map((r) => r.data.toString()).toList();
  }

  test('splitting a secondary source moves its rows to a new dive', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource(
      'src-b',
      'dive-1',
      'dc-b',
      isPrimary: false,
      maxDepth: 18.3,
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
      depth: 21.7,
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
      timestamp: 10,
      depth: 20.0,
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-b',
      isPrimary: false,
      depth: 18.3,
    );
    final tankB = await insertTank('dive-1', 'dc-b');
    await insertTankPressureSeriesRow('dive-1', tankB, 'dc-b');
    await insertEvent('dive-1', 'dc-b');

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-b');

    // New dive carries the secondary's data, marked primary there.
    final newProfiles = await profileSeries.getSeriesForDive(newDiveId);
    expect(newProfiles.length, 1);
    expect(newProfiles.single.samples.single.depth, 18.3);
    expect(newProfiles.single.isPrimary, isTrue);
    final newDive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(newDiveId))).getSingle();
    expect(newDive.computerId, 'dc-b');
    expect(newDive.maxDepth, 18.3);

    final newSources = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(newDiveId))).get();
    expect(newSources.length, 1);
    expect(newSources.single.isPrimary, isTrue);

    // Original dive keeps only its own data.
    final oldProfiles = await profileSeries.getSeriesForDive('dive-1');
    expect(oldProfiles.length, 2);
    expect(oldProfiles.every((s) => s.computerId == 'dc-a'), isTrue);
    final oldTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(oldTanks, isEmpty);
    final oldSources = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(oldSources.length, 1);
    expect(oldSources.single.id, 'src-a');

    expect(await fkViolations(), isEmpty);
  });

  test('splitting the primary promotes the remaining source', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource(
      'src-a',
      'dive-1',
      'dc-a',
      isPrimary: true,
      maxDepth: 21.7,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await insertSource(
      'src-b',
      'dive-1',
      'dc-b',
      isPrimary: false,
      maxDepth: 18.3,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
      depth: 21.7,
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-b',
      isPrimary: false,
      depth: 18.3,
    );

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    final remaining = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(remaining.length, 1);
    expect(remaining.single.id, 'src-b');
    expect(remaining.single.isPrimary, isTrue);

    final oldDive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(oldDive.computerId, 'dc-b');
    expect(oldDive.maxDepth, 18.3);

    // Promoted source's profile series become primary so getDiveProfile
    // (isPrimary filter) still returns a profile.
    final oldProfiles = await profileSeries.getSeriesForDive('dive-1');
    expect(oldProfiles.single.computerId, 'dc-b');
    expect(oldProfiles.single.isPrimary, isTrue);

    final newProfiles = await profileSeries.getSeriesForDive(newDiveId);
    expect(newProfiles.single.samples.single.depth, 21.7);

    expect(await fkViolations(), isEmpty);
  });

  test('splitting refuses a dive whose series cannot be decoded', () async {
    // Split moves tanks and lets tank_pressure_series cascade on tank_id, so
    // a blob the reads answer with null is invisible to the "anything still
    // references this tank" check, loses its tank, and is deleted with no
    // tombstone: gone here and kept forever by every peer.
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    final seriesId = await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
    );
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
    final row = (await profileSeries.getRowsForDives([
      'dive-1',
    ])).firstWhere((r) => r.id == seriesId);
    await db.customStatement(
      'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
      [Uint8List.fromList(row.samples)..[3] ^= 0xFF, seriesId],
    );

    await expectLater(
      service.split(diveId: 'dive-1', sourceId: 'src-b'),
      throwsA(isA<UnreadableSeriesException>()),
    );

    expect((await db.select(db.dives).get()).length, 1);
    expect(await profileSeries.getRowsForDives(['dive-1']), hasLength(2));
  });

  test('splitting the only source throws and writes nothing', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);

    expect(
      () => service.split(diveId: 'dive-1', sourceId: 'src-a'),
      throwsArgumentError,
    );

    final dives = await db.select(db.dives).get();
    expect(dives.length, 1);
    final profiles = await profileSeries.getSeriesForDive('dive-1');
    expect(profiles.length, 1);
  });

  test('split tombstones every moved row', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    final movedProfile = await insertProfileSeriesRow(
      'dive-1',
      'dc-b',
      isPrimary: false,
    );
    final movedTank = await insertTank('dive-1', 'dc-b');
    final movedPressure = await insertTankPressureSeriesRow(
      'dive-1',
      movedTank,
      'dc-b',
    );
    final movedEvent = await insertEvent('dive-1', 'dc-b');

    await service.split(diveId: 'dive-1', sourceId: 'src-b');

    final tombstones = await db.select(db.deletionLog).get();
    final byRecord = {for (final t in tombstones) t.recordId: t.entityType};
    expect(byRecord[movedProfile], 'diveProfileSeries');
    expect(byRecord[movedTank], 'diveTanks');
    expect(byRecord[movedPressure], 'tankPressureSeries');
    expect(byRecord[movedEvent], 'diveProfileEvents');
    expect(byRecord['src-b'], 'diveDataSources');
  });

  test(
    'consolidate then split restores an equivalent secondary dive',
    () async {
      await insertDive('dive-1', computerId: 'dc-a');
      await insertDive('dive-2', computerId: 'dc-b');
      await insertProfileSeriesRow(
        'dive-1',
        null,
        isPrimary: true,
        depth: 21.7,
      );
      await insertProfileSeriesRow(
        'dive-2',
        null,
        isPrimary: true,
        depth: 18.3,
      );
      await insertProfileSeriesRow(
        'dive-2',
        null,
        isPrimary: true,
        timestamp: 10,
        depth: 17.0,
      );

      final consolidation = DiveConsolidationService(repository);
      await consolidation.apply(
        targetDiveId: 'dive-1',
        secondaryDiveIds: ['dive-2'],
      );

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      final secondarySource = sources.firstWhere((s) => s.computerId == 'dc-b');

      final newDiveId = await service.split(
        diveId: 'dive-1',
        sourceId: secondarySource.id,
      );

      final newProfiles = await profileSeries.getSeriesForDive(newDiveId);
      expect(newProfiles.length, 2);
      expect(
        newProfiles
            .map((s) => s.samples.single.depth)
            .reduce((a, b) => a > b ? a : b),
        18.3,
      );
      final newDive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(newDiveId))).getSingle();
      expect(newDive.computerId, 'dc-b');

      expect(await fkViolations(), isEmpty);
    },
  );
  test('a deduped shared tank stays behind with attribution cleared while a '
      'clone carries the departing pressures', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
    // One tank deduped during consolidation: attributed to the departing
    // computer but carrying BOTH computers' pressure curves.
    final sharedTank = await insertTank('dive-1', 'dc-b');
    final stayingPressure = await insertTankPressureSeriesRow(
      'dive-1',
      sharedTank,
      'dc-a',
    );
    final movingPressure = await insertTankPressureSeriesRow(
      'dive-1',
      sharedTank,
      'dc-b',
    );

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-b');

    // The shared tank stays on the original, attribution cleared.
    final originalTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(originalTanks.map((t) => t.id), contains(sharedTank));
    expect(
      originalTanks.firstWhere((t) => t.id == sharedTank).computerId,
      isNull,
    );

    // The other computer's pressure curve stays with it.
    final stayingRows = await tankSeries.getSeriesForDive('dive-1');
    expect(stayingRows.map((s) => s.id), contains(stayingPressure));

    // A clone on the new dive carries the departing computer's rows.
    final newTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(newDiveId))).get();
    expect(newTanks, hasLength(1));
    expect(newTanks.single.computerId, 'dc-b');
    final movedRows = await tankSeries.getSeriesForDive(newDiveId);
    expect(movedRows, hasLength(1));
    expect(movedRows.single.tankId, newTanks.single.id);

    // The moved pressure series was tombstoned; the shared tank was not.
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId), contains(movingPressure));
    expect(tombstones.map((t) => t.recordId), isNot(contains(sharedTank)));

    expect(await fkViolations(), isEmpty);
  });

  test('a gas switch pins its tank to the original dive', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
    final tank = await insertTank('dive-1', 'dc-b');
    final gasSwitch = await insertGasSwitch('dive-1', tank);

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-b');

    // The switch and its tank stay on the original (gas plan intact).
    final switches = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(switches.map((g) => g.id), contains(gasSwitch));
    final originalTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(originalTanks.map((t) => t.id), contains(tank));

    // The departing computer still gets its clone on the new dive.
    final newTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(newDiveId))).get();
    expect(newTanks, hasLength(1));
    expect(newTanks.single.computerId, 'dc-b');

    expect(await fkViolations(), isEmpty);
  });

  test(
    'departing pressures on a tank the source never owned get a clone',
    () async {
      await insertDive('dive-1', computerId: 'dc-a');
      await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
      await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
      await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
      await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
      final primaryTank = await insertTank('dive-1', 'dc-a');
      await insertTankPressureSeriesRow('dive-1', primaryTank, 'dc-a');
      await insertTankPressureSeriesRow('dive-1', primaryTank, 'dc-b');

      final newDiveId = await service.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      // Primary tank untouched on the original.
      final originalTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(originalTanks.single.id, primaryTank);
      expect(originalTanks.single.computerId, 'dc-a');

      // New dive gets a clone carrying dc-b's pressure series.
      final newTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newTanks, hasLength(1));
      final movedRows = await tankSeries.getSeriesForDive(newDiveId);
      expect(movedRows, hasLength(1));
      expect(movedRows.single.tankId, newTanks.single.id);

      expect(await fkViolations(), isEmpty);
    },
  );
  test('splitting the primary moves its null-computerId family, preserving '
      'edited-vs-original flags', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    // Edited profile: demoted original (dc-a, isPrimary=false) plus the
    // edited replacement (computerId NULL, isPrimary=true).
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: false,
      depth: 21.7,
    );
    await insertProfileSeriesRow('dive-1', null, isPrimary: true, depth: 20.5);
    await insertProfileSeriesRow(
      'dive-1',
      'dc-b',
      isPrimary: false,
      depth: 18.3,
    );

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    // Both family series moved: the edited series stays primary on the new
    // dive; the demoted original keeps its flag.
    final newProfiles = await profileSeries.getSeriesForDive(newDiveId);
    expect(newProfiles, hasLength(2));
    expect(
      newProfiles.firstWhere((s) => s.isPrimary).samples.single.depth,
      20.5,
    );
    expect(
      newProfiles.firstWhere((s) => !s.isPrimary).samples.single.depth,
      21.7,
    );

    // The original dive keeps only the promoted source's series, now
    // primary.
    final oldProfiles = await profileSeries.getSeriesForDive('dive-1');
    expect(oldProfiles.single.computerId, 'dc-b');
    expect(oldProfiles.single.isPrimary, isTrue);

    expect(await fkViolations(), isEmpty);
  });

  test('split copies the source surface interval and promotion refreshes the '
      'remaining dive snapshot fields', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-a'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-a'),
            isPrimary: const Value(true),
            surfaceInterval: const Value(3600),
            decoAlgorithm: const Value('Buhlmann ZHL-16C'),
            gradientFactorLow: const Value(50),
            gradientFactorHigh: const Value(85),
            importedAt: Value(DateTime.utc(2026, 1, 1)),
            createdAt: Value(DateTime.utc(2026, 1, 1)),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-b'),
            isPrimary: const Value(false),
            surfaceInterval: const Value(5400),
            decoAlgorithm: const Value('DSAT'),
            gradientFactorLow: const Value(40),
            gradientFactorHigh: const Value(95),
            importedAt: Value(DateTime.utc(2026, 1, 2)),
            createdAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
      depth: 21.7,
    );
    await insertProfileSeriesRow(
      'dive-1',
      'dc-b',
      isPrimary: false,
      depth: 18.3,
    );

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    // The new dive carries the split source's snapshot.
    final newDive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(newDiveId))).getSingle();
    expect(newDive.surfaceIntervalSeconds, 3600);
    expect(newDive.decoAlgorithm, 'Buhlmann ZHL-16C');

    // The original dive's summary follows its promoted source.
    final oldDive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(oldDive.surfaceIntervalSeconds, 5400);
    expect(oldDive.decoAlgorithm, 'DSAT');
    expect(oldDive.gradientFactorLow, 40);
    expect(oldDive.gradientFactorHigh, 95);
  });
  test('the new dive is dated by the source entry time', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    final bronzeEntry = DateTime.utc(2026, 5, 7, 14, 8);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-b'),
            isPrimary: const Value(false),
            entryTime: Value(bronzeEntry),
            importedAt: Value(DateTime.utc(2026, 1, 2)),
            createdAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-b');

    final newDive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(newDiveId))).getSingle();
    expect(newDive.diveDateTime, bronzeEntry.millisecondsSinceEpoch);
  });

  test('split moves every series of the source onto the new dive', () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow(
      'dive-1',
      'dc-a',
      isPrimary: true,
      depth: 21.7,
    );
    final tankA = await insertTank('dive-1', 'dc-a');
    await insertTankPressureSeriesRow('dive-1', tankA, 'dc-a');

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    // Every series moved, so the source dive has no samples left.
    expect(await repository.getDiveProfile('dive-1'), isEmpty);

    final newProfiles = await profileSeries.getSeriesForDive(newDiveId);
    expect(newProfiles.single.samples.single.depth, 21.7);
    final newPressures = await tankSeries.getSeriesForDive(newDiveId);
    expect(newPressures.single.samples.single.pressure, 200.0);

    expect(await fkViolations(), isEmpty);
  });
}
