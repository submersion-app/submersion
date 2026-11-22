import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';

import 'identification_fixtures.dart';

/// A run keeps the naming bars of the pack that named it (issue #4876), so
/// a device with no pack shows the same pills at the diver's level as the
/// device that analysed it (Review Focus 5).
void main() {
  late AppDatabase db;
  late MediaIdentificationRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    repo = MediaIdentificationRepository(database: db);
  });
  tearDown(() => db.close());

  // Surer suggests at 0.95; Eager at 0.5. The fixture's best name scores
  // 0.9, so it is an Eager suggestion only.
  const bars = NamingBars(
    minCropSide: 64,
    minOpenScore: 0.15,
    suggestScore: 0.95,
    suggestScoreNoLocation: 0.95,
    levels: [
      MeasuredNamingLevel(
        level: NamingLevel.eager,
        target: 0.65,
        suggestScore: 0.5,
        suggestScoreNoLocation: 0.5,
        precision: 0.7,
      ),
    ],
  );
  final named = identification('a').copyWith(suggestable: false);

  Future<void> store({NamingBars? kept}) => repo.storeRun(
    run().copyWith(namingBars: () => kept),
    insert: [named],
    deleteIds: const [],
  );

  group('with no pack installed', () {
    test('Eager names a run by the bars it kept', () async {
      await store(kept: bars);
      final rows = await identificationsAtLevel(
        repo,
        'm1',
        null,
        chosen: NamingLevel.eager,
      );
      expect(rows.single.suggestable, isTrue);
    });

    test('Surer reads as stored', () async {
      await store(kept: bars);
      final rows = await identificationsAtLevel(
        repo,
        'm1',
        null,
        chosen: NamingLevel.surer,
      );
      expect(rows.single.suggestable, isFalse);
    });

    test('a run without bars reads as stored', () async {
      await store();
      final rows = await identificationsAtLevel(
        repo,
        'm1',
        null,
        chosen: NamingLevel.eager,
      );
      expect(rows.single.suggestable, isFalse);
    });
  });

  test('the bars a run kept win over another installed pack', () async {
    await store(kept: bars);
    // Another pack, whose Eager would not suggest it.
    const other = LevelInForce(
      level: NamingLevel.eager,
      packVersion: '2026.12.1',
      minCropSide: 64,
      minOpenScore: 0.15,
      suggestScore: 0.99,
      suggestScoreNoLocation: 0.99,
    );
    final rows = await identificationsAtLevel(
      repo,
      'm1',
      other,
      chosen: NamingLevel.eager,
    );
    expect(rows.single.suggestable, isTrue);
  });

  group('fillNamingBars', () {
    test('fills this device\'s runs of the pack that kept none, and only '
        'those', () async {
      await repo.storeRun(
        run(mediaId: 'mine'),
        insert: const [],
        deleteIds: const [],
      );
      await repo.storeRun(
        run(mediaId: 'stamped').copyWith(analysedBy: () => 'laptop'),
        insert: const [],
        deleteIds: const [],
      );
      await repo.storeRun(
        run(mediaId: 'theirs').copyWith(analysedBy: () => 'phone'),
        insert: const [],
        deleteIds: const [],
      );
      await repo.storeRun(
        run(mediaId: 'older').copyWith(packVersion: '2026.10.1'),
        insert: const [],
        deleteIds: const [],
      );

      final filled = await repo.fillNamingBars(
        '2026.11.1',
        bars,
        deviceId: 'laptop',
      );

      expect(filled, 2);
      expect((await repo.runFor('mine'))!.namingBars, bars);
      expect((await repo.runFor('stamped'))!.namingBars, bars);
      expect((await repo.runFor('theirs'))!.namingBars, isNull);
      expect((await repo.runFor('older'))!.namingBars, isNull);
      expect(
        await repo.fillNamingBars('2026.11.1', bars, deviceId: 'laptop'),
        0,
      );
    });
  });

  test('applyChosenLevel leaves rows alone with no choice and no pack', () {
    final rows = [named];
    expect(
      applyChosenLevel(
        rows,
        run: run().copyWith(namingBars: () => bars),
        chosen: null,
        installed: null,
      ),
      rows,
    );
  });

  test(
    'a stored run with an unreadable naming_bars value reads none',
    () async {
      await store();
      await db.customStatement(
        "UPDATE media_identification_runs SET naming_bars = 'x'",
      );
      expect((await repo.runFor('m1'))!.namingBars, isNull);
      expect(
        (await identificationsAtLevel(
          repo,
          'm1',
          null,
          chosen: NamingLevel.eager,
        )).single.suggestable,
        isFalse,
      );
    },
  );

  test('an identification that is decided stays shown', () async {
    await repo.storeRun(
      run().copyWith(namingBars: () => bars, runId: () => 'r1'),
      insert: [
        identification(
          'd',
          decision: IdentificationDecision.accepted,
        ).copyWith(runId: () => 'old'),
      ],
      deleteIds: const [],
    );
    final rows = await identificationsAtLevel(
      repo,
      'm1',
      null,
      chosen: NamingLevel.eager,
    );
    expect(rows.single.id, 'd');
  });
}
