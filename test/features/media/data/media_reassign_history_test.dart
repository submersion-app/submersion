import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The media library's Move to dive is one labelled entry in History
/// (issue #4527, media library plan 1).
void main() {
  late AppDatabase db;
  late MediaRepository repo;
  final changeLog = ChangeLogRepository();
  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(String id, {String? diveId}) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/photos/$id.jpg',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    await insertDive('d1');
    await insertDive('d2');
    await repo.createMedia(item('m1', diveId: 'd1'));
    await repo.createMedia(item('m2', diveId: 'd1'));
    // A row on no dive: a site-only or gear-only photo.
    await repo.createMedia(item('m3'));
    // The rows above are setup, not what is under test.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    await db.customStatement('DELETE FROM change_log_events');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String?>> operationLabels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  Future<String?> diveOf(String id) async =>
      (await repo.getMediaById(id))?.diveId;

  test('a move is one entry in History, labelled as a move', () async {
    await repo.reassignMediaToDive(['m1', 'm2', 'm3'], 'd2');

    expect(await operationLabels(), [ChangeLogLabels.moveMedia]);
    expect(await diveOf('m1'), 'd2');
    expect(await diveOf('m2'), 'd2');
    expect(await diveOf('m3'), 'd2');
  });

  test('a move is filed under the dive the items moved to', () async {
    await repo.reassignMediaToDive(['m1', 'm2'], 'd2');
    await changeLog.settleAll();

    final roots = await db
        .customSelect(
          'SELECT DISTINCT root_table, root_id FROM change_log_events',
        )
        .get();
    final pairs = {
      for (final row in roots)
        (row.read<String?>('root_table'), row.read<String?>('root_id')),
    };
    expect(pairs, contains(('dives', 'd2')));
    expect(pairs, isNot(contains(('dives', 'd1'))));
  });

  test('a move inside another operation is part of it', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.bulkEdit,
      body: () => repo.reassignMediaToDive(['m1'], 'd2'),
    );

    expect(await operationLabels(), [ChangeLogLabels.bulkEdit]);
  });

  test('moving nothing writes no entry', () async {
    await repo.reassignMediaToDive(const [], 'd2');

    expect(await operationLabels(), isEmpty);
  });
}
