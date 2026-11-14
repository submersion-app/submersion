import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, Tag;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// An editing sitting is saved in one transaction and one change log
/// operation, and writes only what the diver changed onto the dive as it is
/// stored at that moment (issue #4527).
void main() {
  late AppDatabase db;
  late DiveEditSaveService service;
  late Tag wreck;
  late Tag night;
  final changeLog = ChangeLogRepository();
  final dives = DiveRepository();
  final tags = TagRepository();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Dive> stored() async => (await dives.getDiveById('dive'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    service = DiveEditSaveService(dives);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    wreck = await tags.createTag(
      Tag(
        id: 'wreck',
        diverId: 'me',
        name: 'Wreck',
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    night = await tags.createTag(
      Tag(
        id: 'night',
        diverId: 'me',
        name: 'Night',
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    // One save through the repository, so the dive is stored the way the
    // app stores it, with children of several kinds. What follows then
    // shows only what a sitting itself writes.
    await dives.updateDive(
      (await stored()).copyWith(
        diveTypeIds: const ['shore'],
        tags: [wreck, night],
      ),
    );
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  test('a notes-only save records exactly one changed field', () async {
    final result = await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current'),
      changedCardIds: ['notes'],
    );

    expect(result!.before.notes, 'Calm');
    expect(result.after.notes, 'Current');
    final events = await logEvents(db);
    expect(
      [for (final e in events) e['table_name']],
      ['dives'],
      reason:
          'an extra table here names a writer in updateDive that rewrites '
          'rows it should have left alone',
    );
    expect(await logFields(db, events.single['id']! as int), {
      'notes': ('Calm', 'Current'),
    });
  });

  test('one sitting is one operation, labelled with its cards', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current', tags: [wreck]),
      changedCardIds: ['tags', 'notes'],
    );

    final operation = (await operations()).single;
    expect(operation['source'], 'manual');
    expect(operation['label'], 'record_edit:dives:notes,tags');
  });

  test('changes are applied to the dive as stored at save time', () async {
    // Something else changes the stored dive after the sitting began.
    await dives.updateDive((await stored()).copyWith(rating: 5));

    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current'),
      changedCardIds: ['notes'],
    );

    final saved = await stored();
    expect(saved.notes, 'Current');
    expect(saved.rating, 5);
  });

  test('a sitting that changes nothing writes nothing', () async {
    final result = await service.save(
      diveId: 'dive',
      apply: (dive) => dive,
      changedCardIds: const [],
    );

    expect(result, isNull);
    expect(await logEvents(db), isEmpty);
    expect(await operations(), isEmpty);
  });

  test('a dive that no longer exists throws and writes nothing', () async {
    await dives.deleteDive('dive');
    await changeLog.settleAll();
    await clearLog(db);

    await expectLater(
      service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(notes: 'x'),
        changedCardIds: ['notes'],
      ),
      throwsStateError,
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a write the repository rejects leaves the dive unchanged', () async {
    // updateDive refuses a tank with an empty id.
    await expectLater(
      service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(
          notes: 'Current',
          tanks: [dive.tanks.first.copyWith(id: '')],
        ),
        changedCardIds: ['notes'],
      ),
      throwsArgumentError,
    );

    expect((await stored()).notes, 'Calm');
    expect(await logEvents(db), isEmpty);
  });

  test('reverting the sitting restores what it changed', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current', tags: const []),
      changedCardIds: ['notes', 'tags'],
    );
    expect((await stored()).tags, isEmpty);
    final operationId = (await operations()).single['id']! as String;

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(operationId));

    final reverted = await stored();
    expect(reverted.notes, 'Calm');
    expect(reverted.tags.map((tag) => tag.id).toSet(), {'wreck', 'night'});
  });
}
