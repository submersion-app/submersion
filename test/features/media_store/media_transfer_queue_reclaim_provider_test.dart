import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
    container = ProviderContainer(
      overrides: [mediaTransferQueueRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('reclaim returns a stranded transferring row to pending', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    // Stuck: nextPending never selects 'transferring'.
    expect(await repo.nextPending(DateTime.now()), isNull);

    await container.read(mediaTransferQueueReclaimProvider.future);

    expect((await repo.allForTesting()).single.state, 'pending');
    expect(await repo.nextPending(DateTime.now()), isNotNull);
  });

  test('reclaim runs once per process and never re-runs to clobber a live '
      'transfer', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    await container.read(mediaTransferQueueReclaimProvider.future);
    expect((await repo.allForTesting()).single.state, 'pending');

    // A worker now legitimately picks the row up and marks it transferring.
    // A second read (e.g. the runtime rebuilt on connect/disconnect) must NOT
    // reclaim it again: the provider is cached, so requeueStale does not fire
    // and the live transfer is left alone.
    await repo.markTransferring(id);
    await container.read(mediaTransferQueueReclaimProvider.future);

    expect(
      (await repo.allForTesting()).single.state,
      'transferring',
      reason: 'cached reclaim must not re-run and flip a live transfer',
    );
  });
}
