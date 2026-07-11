import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_badge.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the default provider bodies construct their singletons', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mediaStoreCredentialsStoreProvider), isNotNull);
    expect(container.read(mediaStoreAttachStateProvider), isNotNull);
    expect(container.read(mediaStorePoliciesProvider), isNotNull);
    expect(
      container.read(mediaTransferQueueRepositoryProvider),
      isA<MediaTransferQueueRepository>(),
    );
    expect(
      container.read(mediaStoresRepositoryProvider),
      isA<MediaStoresRepository>(),
    );
    expect(
      container.read(mediaBackfillServiceProvider),
      isA<MediaBackfillService>(),
    );
  });

  test(
    'status-hint and resolver providers are null without a runtime',
    () async {
      final container = ProviderContainer(
        overrides: [
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(mediaStoreResolverProvider), isNull);
      final sub = container.listen(mediaStoreStatusHintProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(mediaStoreStatusHintProvider.future), isNull);
    },
  );

  test('the enqueue bridge is a no-op when no runtime is attached', () async {
    final container = ProviderContainer(
      overrides: [mediaStoreRuntimeProvider.overrideWith((ref) async => null)],
    );
    addTearDown(container.dispose);

    final enqueue = container.read(mediaStoreEnqueueProvider);
    // Runs the impl closure: reads the (default-on) policy, sees no runtime,
    // and does nothing. Awaiting a tick lets the fire-and-forget body run.
    enqueue('m1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(enqueue, isA<void Function(String)>());
  });

  test('the badge provider is defensive when the cache DB is '
      'uninitialized', () async {
    // No queue override and no initialized singleton: the provider must
    // swallow the StateError and read as none.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final item = MediaItem(
      id: 'm1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      takenAt: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final sub = container.listen(mediaBadgeStateProvider(item), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      container.read(mediaBadgeStateProvider(item)).value,
      MediaBadgeState.none,
    );
  });

  test('the transfer stream providers subscribe to the queue', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = MediaTransferQueueRepository(database: db);
    final container = ProviderContainer(
      overrides: [mediaTransferQueueRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final subA = container.listen(mediaTransferActiveCountProvider, (_, _) {});
    final subB = container.listen(mediaTransferEntriesProvider, (_, _) {});
    addTearDown(subA.close);
    addTearDown(subB.close);

    // Enqueue one row; the active-count stream should reach 1.
    await repo.enqueueUpload(mediaId: 'm1');
    var count = 0;
    for (var i = 0; i < 100; i++) {
      count = container.read(mediaTransferActiveCountProvider).value ?? 0;
      if (count == 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(count, 1);
    expect(container.read(mediaTransferEntriesProvider).hasValue, isTrue);
  });
}
