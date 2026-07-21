import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository queue;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: db);
  });
  tearDown(() => db.close());

  test(
    'enqueueReupload replaces prior rows and carries overrideLevel',
    () async {
      await queue.enqueueUpload(mediaId: 'm1');
      final id = await queue.enqueueReupload(
        mediaId: 'm1',
        overrideLevel: 'small',
      );
      final rows = await queue.allForTesting();
      expect(rows.where((r) => r.mediaId == 'm1').length, 1);
      expect(rows.single.id, id);
      expect(rows.single.overrideLevel, 'small');
      expect(rows.single.state, 'pending');
    },
  );

  test('a plain enqueueUpload carries no overrideLevel', () async {
    await queue.enqueueUpload(mediaId: 'm2');
    final rows = await queue.allForTesting();
    expect(rows.single.overrideLevel, isNull);
  });
}
