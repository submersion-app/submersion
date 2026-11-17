import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import 'identification_fixtures.dart';

void main() {
  late AppDatabase db;
  late MediaIdentificationRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    repo = MediaIdentificationRepository(database: db);
  });
  tearDown(() => db.close());

  Future<void> addMedia(String id) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(id: id, filePath: '', createdAt: 0, updatedAt: 0),
      );

  test('a stored run and its identifications read back unchanged', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);

    expect(await repo.runFor('m1'), run());
    expect(await repo.forMedia('m1'), [identification('a')]);
    expect(await repo.runFor('other'), isNull);
    expect(await repo.forMedia('other'), isEmpty);
  });

  test('a run with nothing found is stored', () async {
    await repo.storeRun(run(count: 0), insert: const [], deleteIds: const []);
    expect((await repo.runFor('m1'))!.detectionCount, 0);
  });

  test(
    'storing again replaces the run and removes what it is told to',
    () async {
      await repo.storeRun(
        run(),
        insert: [identification('a'), identification('b')],
        deleteIds: [],
      );
      final newer = run(count: 2).copyWith(packVersion: '2026.12.1');
      await repo.storeRun(
        newer,
        insert: [identification('c')],
        deleteIds: ['a'],
      );

      expect((await repo.runFor('m1'))!.packVersion, '2026.12.1');
      expect(
        (await repo.forMedia('m1')).map((i) => i.id),
        unorderedEquals(['b', 'c']),
      );
    },
  );

  test('decisions are updated in place', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final accepted = identification(
      'a',
      decision: IdentificationDecision.accepted,
      decidedSpeciesId: 'sp_queen_parrotfish',
      decidedAt: fixtureT1,
    );
    await repo.updateIdentifications([accepted]);
    expect(await repo.forMedia('m1'), [accepted]);
  });

  test('updating can also move the run on', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final renamed = run().copyWith(
      packVersion: '2026.12.1',
      locationCell: () => null,
    );
    await repo.updateIdentifications([identification('a')], run: renamed);
    expect(await repo.runFor('m1'), renamed);
  });

  test('an update that lands after the rows were cleared brings nothing '
      'back', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    final dismissed = identification(
      'a',
      decision: IdentificationDecision.rejected,
      decidedAt: fixtureT1,
    );
    await repo.deleteForMedia(['m1']);
    await repo.updateIdentifications([dismissed], run: run());
    expect(await repo.forMedia('m1'), isEmpty);
    expect(await repo.runFor('m1'), isNull);
  });

  test('deleting for media removes runs and identifications and returns '
      'the ids', () async {
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    await repo.storeRun(
      run(mediaId: 'm2'),
      insert: [identification('b', mediaId: 'm2')],
      deleteIds: [],
    );

    expect(await repo.deleteForMedia(['m1']), ['a']);
    expect(await repo.runFor('m1'), isNull);
    expect(await repo.forMedia('m2'), hasLength(1));
  });

  test('orphans are media ids with rows here but no media row', () async {
    await addMedia('m-live');
    await repo.storeRun(
      run(mediaId: 'm-live'),
      insert: [identification('a', mediaId: 'm-live')],
      deleteIds: [],
    );
    await repo.storeRun(
      run(mediaId: 'm-gone'),
      insert: const [],
      deleteIds: const [],
    );
    await repo.storeRun(
      run(mediaId: 'm-gone-2'),
      insert: [identification('b', mediaId: 'm-gone-2')],
      deleteIds: [],
    );

    expect(
      await repo.orphanMediaIds(),
      unorderedEquals(['m-gone', 'm-gone-2']),
    );
  });

  test('count and media ids cover every identification and run', () async {
    await repo.storeRun(
      run(),
      insert: [identification('a'), identification('b')],
      deleteIds: [],
    );
    await repo.storeRun(
      run(mediaId: 'm2', count: 0),
      insert: const [],
      deleteIds: const [],
    );
    expect(await repo.count(), 2);
    expect(await repo.mediaIds(), unorderedEquals(['m1', 'm2']));
  });

  test('tagged species come with their scientific names', () async {
    await addMedia('m1');
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'own-1',
            commonName: 'Brown Chromis',
            scientificName: const Value('Chromis multilineata'),
            category: 'fish',
          ),
        );
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 't1',
            mediaId: 'm1',
            speciesId: 'own-1',
            createdAt: 0,
          ),
        );
    expect(await repo.taggedSpecies('m1'), [
      const TaggedSpecies(
        speciesId: 'own-1',
        scientificName: 'Chromis multilineata',
      ),
    ]);
    expect(await repo.taggedSpecies('m2'), isEmpty);
  });

  test('a write ticks the change stream', () async {
    final ticks = <void>[];
    final sub = repo.watchChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await repo.storeRun(run(), insert: [identification('a')], deleteIds: []);
    await pumpEventQueue();
    expect(ticks, isNotEmpty);
  });
}
