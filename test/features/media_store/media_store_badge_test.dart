import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_badge.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;
  late ProviderContainer container;

  MediaItem item() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

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

  // Riverpod 3 auto-pauses providers without active listeners, so a bare
  // `.future` read never subscribes the underlying drift stream. Hold a
  // listener open and poll until the drift stream emits the expected
  // state (the stream re-emits on every table change on its own).
  Future<void> expectBadge(MediaItem i, MediaBadgeState expected) async {
    final sub = container.listen(mediaBadgeStateProvider(i), (_, _) {});
    try {
      for (var attempt = 0; attempt < 100; attempt++) {
        if (container.read(mediaBadgeStateProvider(i)).value == expected) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail(
        'badge never reached $expected; '
        'last: ${container.read(mediaBadgeStateProvider(i)).value}',
      );
    } finally {
      sub.close();
    }
  }

  test('no row means none', () async {
    await expectBadge(item(), MediaBadgeState.none);
  });

  test('pending row means queued; transferring and failed map through; '
      'done means none', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await expectBadge(item(), MediaBadgeState.queued);

    await repo.markTransferring(id);
    await expectBadge(item(), MediaBadgeState.transferring);

    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'x');
    }
    await expectBadge(item(), MediaBadgeState.failed);

    await repo.retry(id);
    await repo.markDone(id);
    await expectBadge(item(), MediaBadgeState.none);
  });

  Widget badgeApp(MediaItem i, MediaBadgeState state) => ProviderScope(
    // Keyed by state so each pump builds a fresh element rather than
    // reusing the prior one's cached async value.
    key: ValueKey(state),
    overrides: [
      mediaBadgeStateProvider(i).overrideWith((ref) => Stream.value(state)),
    ],
    child: MaterialApp(
      home: Scaffold(body: MediaStoreBadge(item: i)),
    ),
  );

  testWidgets('the badge renders an avatar for each active state', (
    tester,
  ) async {
    for (final state in [
      MediaBadgeState.queued,
      MediaBadgeState.transferring,
      MediaBadgeState.failed,
    ]) {
      await tester.pumpWidget(badgeApp(item(), state));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('media-store-badge')),
        findsOneWidget,
        reason: '$state renders a badge',
      );
    }
  });

  testWidgets('the badge renders nothing when quiet', (tester) async {
    await tester.pumpWidget(badgeApp(item(), MediaBadgeState.none));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-store-badge')), findsNothing);
  });
}
