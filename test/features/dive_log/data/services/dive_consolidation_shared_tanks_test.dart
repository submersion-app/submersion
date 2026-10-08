import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// A cylinder two computers both logged is kept once by consolidation; the
/// computer merged into it must still be recorded as breathing it, and a
/// split must hand it back.
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

  Future<void> seedDive(
    String id,
    String computerId,
    List<double> o2Percents, {
    List<(int, int)> switches = const [],
    bool switchesEntered = false,
  }) async {
    final entry = DateTime.utc(2026, 8, 8, 10, 16);
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 47),
        maxDepth: 40,
        tanks: [
          for (var i = 0; i < o2Percents.length; i++)
            domain.DiveTank(
              id: '$id-t$i',
              gasMix: domain.GasMix(o2: o2Percents[i]),
              order: i,
              computerId: computerId,
            ),
        ],
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 1400, depth: 40),
          domain.DiveProfilePoint(timestamp: 2820, depth: 0),
        ],
      ),
    );
    await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
      DivesCompanion(computerId: Value(computerId)),
    );
    // Switches as a download writes them, its computer's (v258, #2582), or
    // as the diver entered them: unattributed. (timestamp, tank index)
    for (final (timestamp, tankIndex) in switches) {
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: '$id-sw$timestamp',
              diveId: id,
              timestamp: timestamp,
              tankId: '$id-t$tankIndex',
              createdAt: 0,
            ).copyWith(computerId: Value(switchesEntered ? null : computerId)),
          );
    }
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

  Future<List<domain.DiveTank>> tanksOf(String diveId) async =>
      (await diveRepo.getDiveById(diveId))!.tanks;

  Future<void> consolidateSuuntoAndGarmin() async {
    await seedDive('t', 'suunto', [21, 50], switches: [(0, 0), (1740, 1)]);
    await seedDive(
      's',
      'garmin',
      [21, 50, 100],
      switches: [(0, 0), (1980, 1), (2340, 2)],
    );
    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);
  }

  test('merged cylinders record the secondary that shares them', () async {
    await consolidateSuuntoAndGarmin();

    final tanks = await tanksOf('t');
    final byO2 = {for (final t in tanks) t.gasMix.o2: t};
    expect(tanks, hasLength(3));
    expect(byO2[21]!.sharedComputerIds, ['garmin']);
    expect(byO2[50]!.sharedComputerIds, ['garmin']);
    expect(byO2[100]!.computerId, 'garmin');
    expect(byO2[100]!.sharedComputerIds, isEmpty);
    expect(byO2[100]!.sharedComputerIds, isNotNull);

    expect(tanks.where((t) => t.isUsedBy('garmin')), hasLength(3));
    expect(
      tanks.where((t) => t.isUsedBy('suunto')).map((t) => t.gasMix.o2),
      unorderedEquals([21, 50]),
    );
  });

  test('the fold marks the cylinders nobody shares as recorded, so the '
      'open-time inference never guesses for them', () async {
    await consolidateSuuntoAndGarmin();

    final rows = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(
      {for (final r in rows) r.o2Percent: r.sharedComputerIds},
      {21: '["garmin"]', 50: '["garmin"]', 100: '[]'},
    );
  });

  test('saving a dive keeps recorded-with-nobody apart from never '
      'recorded', () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'n',
        diverId: 'diver1',
        dateTime: DateTime.utc(2026, 8, 8),
        tanks: const [
          domain.DiveTank(id: 'n-recorded', sharedComputerIds: []),
          domain.DiveTank(id: 'n-never', order: 1),
        ],
      ),
    );
    final rows = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('n'))).get();
    expect(
      {for (final r in rows) r.id: r.sharedComputerIds},
      {'n-recorded': '[]', 'n-never': null},
    );
    final tanks = {for (final t in await tanksOf('n')) t.id: t};
    expect(tanks['n-recorded']!.sharedComputerIds, isEmpty);
    expect(tanks['n-never']!.sharedComputerIds, isNull);
  });

  test('an edit of the dive keeps what the fold recorded', () async {
    await consolidateSuuntoAndGarmin();

    final dive = (await diveRepo.getDiveById('t'))!;
    await diveRepo.updateDive(dive.copyWith(notes: 'edited'));

    final air = (await tanksOf('t')).firstWhere((t) => t.gasMix.o2 == 21);
    expect(air.sharedComputerIds, ['garmin']);
  });

  test(
    'splitting the secondary out gives it back the cylinders it shared',
    () async {
      await consolidateSuuntoAndGarmin();

      final garminSource = (await diveRepo.getDataSources(
        't',
      )).firstWhere((s) => s.computerId == 'garmin');
      final newDiveId = await DiveSplitService(
        diveRepo,
      ).split(diveId: 't', sourceId: garminSource.id);

      final split = await tanksOf(newDiveId);
      expect(split.map((t) => t.gasMix.o2), unorderedEquals([21, 50, 100]));
      expect(split.every((t) => t.computerId == 'garmin'), isTrue);
      // The new dive has one computer, so nothing is recorded there.
      expect(split.every((t) => t.sharedComputerIds == null), isTrue);

      final original = await tanksOf('t');
      expect(original.map((t) => t.gasMix.o2), unorderedEquals([21, 50]));
      // Emptied, the lists stay recorded: never-recorded would let the
      // open-time inference guess for these cylinders again.
      final rows = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('t'))).get();
      expect(rows.map((r) => r.sharedComputerIds), everyElement('[]'));
    },
  );

  test('a switch the diver entered stays unattributed through the fold, so '
      'it keeps applying to every computer', () async {
    await seedDive(
      't',
      'suunto',
      [21, 50],
      switches: [(1740, 1)],
      switchesEntered: true,
    );
    await seedDive(
      's',
      'garmin',
      [21, 50],
      switches: [(1980, 1)],
      switchesEntered: true,
    );
    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final switches = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(switches, hasLength(2));
    expect(switches.map((s) => s.computerId), everyElement(isNull));
  });

  test('splitting the owner out hands each shared cylinder to the computer '
      'that shares it', () async {
    await consolidateSuuntoAndGarmin();
    // A third computer on its own gas, so a cylinder left unattributed
    // would wrongly become its too.
    await seedDive('o', 'ocean', [32]);
    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['o']);

    final suuntoSource = (await diveRepo.getDataSources(
      't',
    )).firstWhere((s) => s.computerId == 'suunto');
    await DiveSplitService(
      diveRepo,
    ).split(diveId: 't', sourceId: suuntoSource.id);

    final left = await tanksOf('t');
    final byO2 = {for (final t in left) t.gasMix.o2: t};
    expect(byO2[21]!.computerId, 'garmin');
    expect(byO2[21]!.sharedComputerIds, isNotNull);
    expect(byO2[21]!.sharedComputerIds, isEmpty);
    expect(byO2[50]!.computerId, 'garmin');
    expect(left.where((t) => t.isUsedBy('ocean')).map((t) => t.gasMix.o2), [
      32,
    ]);
  });

  test(
    'each computer\'s gas switches keep their computer through the fold',
    () async {
      await consolidateSuuntoAndGarmin();

      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals('t'))).get();
      final byComputer = <String?, List<int>>{};
      for (final sw in switches) {
        byComputer.putIfAbsent(sw.computerId, () => []).add(sw.timestamp);
      }
      expect(byComputer.keys, unorderedEquals(['suunto', 'garmin']));
      expect(byComputer['suunto'], unorderedEquals([0, 1740]));
      expect(byComputer['garmin'], unorderedEquals([0, 1980, 2340]));
    },
  );

  test(
    'a split takes the departing computer\'s gas switches with it',
    () async {
      await consolidateSuuntoAndGarmin();

      final garminSource = (await diveRepo.getDataSources(
        't',
      )).firstWhere((s) => s.computerId == 'garmin');
      final newDiveId = await DiveSplitService(
        diveRepo,
      ).split(diveId: 't', sourceId: garminSource.id);

      Future<List<int>> timestampsOn(String diveId) async => [
        for (final sw in await (db.select(
          db.gasSwitches,
        )..where((t) => t.diveId.equals(diveId))).get())
          sw.timestamp,
      ];
      expect(await timestampsOn(newDiveId), unorderedEquals([0, 1980, 2340]));
      expect(await timestampsOn('t'), unorderedEquals([0, 1740]));

      // Every moved switch points at a tank on the new dive.
      final newTankIds = {for (final t in await tanksOf(newDiveId)) t.id};
      final moved = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(moved.every((sw) => newTankIds.contains(sw.tankId)), isTrue);
    },
  );

  test('a later fold leaves an already consolidated dive\'s unattributed '
      'switches alone', () async {
    await consolidateSuuntoAndGarmin();
    // A switch the diver entered, or one on a merged cylinder that v258
    // could not attribute: it applies to both and must keep doing so.
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'legacy-switch',
            diveId: 't',
            timestamp: 1200,
            tankId: 't-t1',
            createdAt: 0,
          ),
        );
    await seedDive('o', 'ocean', [21], switches: [(0, 0)]);

    await consolidation.apply(targetDiveId: 't', secondaryDiveIds: ['o']);

    final legacy = await (db.select(
      db.gasSwitches,
    )..where((t) => t.id.equals('legacy-switch'))).getSingle();
    expect(legacy.computerId, isNull);
  });
}
