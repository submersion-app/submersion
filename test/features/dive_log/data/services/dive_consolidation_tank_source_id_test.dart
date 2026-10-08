import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #2716: two file imports of one dive that name no computer,
/// consolidated with their tank rows left unmerged (32% on one, 31% on the
/// other). Each copy must keep the source it came from, re-pointed at the
/// target's copy of that source.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService service;

  Future<void> seedFileImport(
    String diveId,
    String tankId,
    DateTime entry, {
    required double o2,
    bool tankAttributed = false,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: diveId,
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 40),
        maxDepth: 30,
        tanks: [
          domain.DiveTank(
            id: tankId,
            gasMix: domain.GasMix(o2: o2),
          ),
        ],
      ),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$diveId',
            diveId: diveId,
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ).copyWith(
            isPrimary: const Value(true),
            sourceFileName: const Value('log.csv'),
          ),
        );
    if (tankAttributed) {
      await (db.update(db.diveTanks)..where((t) => t.id.equals(tankId))).write(
        DiveTanksCompanion(sourceId: Value('src-$diveId')),
      );
    }
  }

  Future<Map<String, String?>> tankSources(String diveId) async => {
    for (final t in await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get())
      t.id: t.sourceId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = DiveConsolidationService(diveRepo);
  });

  tearDown(tearDownTestDatabase);

  for (final attributed in [false, true]) {
    test('each copy keeps its own source '
        '(tanks ${attributed ? 'already' : 'not yet'} attributed)', () async {
      await seedFileImport(
        'f1',
        'tank-f1',
        DateTime.utc(2026, 7, 18, 18),
        o2: 32,
        tankAttributed: attributed,
      );
      await seedFileImport(
        'f2',
        'tank-f2',
        DateTime.utc(2026, 7, 18, 18, 1),
        o2: 31,
        tankAttributed: attributed,
      );
      await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

      final copiedSource =
          (await (db.select(db.diveDataSources)..where(
                    (s) => s.diveId.equals('f1') & s.isPrimary.equals(false),
                  ))
                  .getSingle())
              .id;
      final sources = await tankSources('f1');
      expect(sources, hasLength(2));
      expect(sources['tank-f1'], 'src-f1');
      final copy = sources.keys.singleWhere((id) => id != 'tank-f1');
      expect(sources[copy], copiedSource);
    });
  }

  test('splitting a source off takes its own copy with it', () async {
    await seedFileImport(
      'f1',
      'tank-f1',
      DateTime.utc(2026, 7, 18, 18),
      o2: 32,
    );
    await seedFileImport(
      'f2',
      'tank-f2',
      DateTime.utc(2026, 7, 18, 18, 1),
      o2: 31,
    );
    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);
    final copiedSource =
        (await (db.select(db.diveDataSources)..where(
                  (s) => s.diveId.equals('f1') & s.isPrimary.equals(false),
                ))
                .getSingle())
            .id;

    final newDiveId = await DiveSplitService(
      diveRepo,
    ).split(diveId: 'f1', sourceId: copiedSource);

    // Before the column nothing told a computer-less source's tank apart,
    // so it stayed behind; now it leaves with its source.
    expect(await tankSources('f1'), {'tank-f1': 'src-f1'});
    final newSource = (await (db.select(
      db.diveDataSources,
    )..where((s) => s.diveId.equals(newDiveId))).getSingle()).id;
    final moved = await tankSources(newDiveId);
    expect(moved.values, [newSource]);
  });

  test(
    'splitting off a computer\'s primary leaves a hand-added tank',
    () async {
      // The only source of a downloaded dive claims a tank the diver added
      // (it is that source's); split by a computer moves by the computer
      // rule, as before, so the hand-added tank stays on the dive.
      for (final id in ['teric', 'perdix']) {
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion.insert(
                id: id,
                name: id,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }
      await seedFileImport(
        'f1',
        'tank-f1',
        DateTime.utc(2026, 7, 18, 18),
        o2: 32,
      );
      await (db.update(db.diveTanks)..where((t) => t.id.equals('tank-f1')))
          .write(const DiveTanksCompanion(computerId: Value('teric')));
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 'hand', diveId: 'f1').copyWith(
              tankOrder: const Value(1),
              sourceId: const Value('src-f1'),
            ),
          );
      await (db.update(db.diveDataSources)..where((s) => s.id.equals('src-f1')))
          .write(const DiveDataSourcesCompanion(computerId: Value('teric')));
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: 'src-p',
              diveId: 'f1',
              importedAt: DateTime.utc(2026, 7, 18),
              createdAt: DateTime.utc(2026, 7, 18),
            ).copyWith(computerId: const Value('perdix')),
          );

      final newDiveId = await DiveSplitService(
        diveRepo,
      ).split(diveId: 'f1', sourceId: 'src-f1');

      expect(await tankSources(newDiveId), hasLength(1));
      expect((await tankSources('f1')).keys, contains('hand'));
    },
  );

  test('undo restores each dive\'s tanks with their own sources', () async {
    await seedFileImport(
      'f1',
      'tank-f1',
      DateTime.utc(2026, 7, 18, 18),
      o2: 32,
      tankAttributed: true,
    );
    await seedFileImport(
      'f2',
      'tank-f2',
      DateTime.utc(2026, 7, 18, 18, 1),
      o2: 31,
      tankAttributed: true,
    );
    final outcome = await service.apply(
      targetDiveId: 'f1',
      secondaryDiveIds: ['f2'],
    );
    await service.undo(outcome.snapshot);

    expect(await tankSources('f1'), {'tank-f1': 'src-f1'});
    expect(await tankSources('f2'), {'tank-f2': 'src-f2'});
  });
}
