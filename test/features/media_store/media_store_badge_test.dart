import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_badge.dart';

import 'media_store_badge_test.mocks.dart';

@GenerateMocks([MediaRepository])
void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;
  late MockMediaRepository mockRepo;
  late ProviderContainer container;

  MediaItem item({
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? remoteUploadedAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    remoteUploadedAt: remoteUploadedAt,
  );

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
    mockRepo = MockMediaRepository();
    container = ProviderContainer(
      overrides: [mediaTransferQueueRepositoryProvider.overrideWithValue(repo)],
    );
  });

  /// Container with a media repository and an explicit attach answer, for
  /// the settled-state cases. The default `container` from setUp overrides
  /// neither, which is what exercises the degradation guard.
  ProviderContainer attachedContainer({required bool attached}) =>
      ProviderContainer(
        overrides: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
          mediaRepositoryProvider.overrideWithValue(mockRepo),
          mediaStoreAttachedProvider.overrideWith((ref) async => attached),
        ],
      );

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Riverpod 3 auto-pauses providers without active listeners, so a bare
  // `.future` read never subscribes the underlying drift stream. Hold a
  // listener open and poll until the drift stream emits the expected
  // state (the stream re-emits on every table change on its own).
  Future<void> expectBadge(
    MediaItem i,
    MediaBadgeState expected, {
    ProviderContainer? using,
  }) async {
    final c = using ?? container;
    final sub = c.listen(mediaBadgeStateProvider(i), (_, _) {});
    try {
      for (var attempt = 0; attempt < 100; attempt++) {
        if (c.read(mediaBadgeStateProvider(i)).value == expected) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail(
        'badge never reached $expected; '
        'last: ${c.read(mediaBadgeStateProvider(i)).value}',
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

  group('settled state reflects backup status', () {
    test('no store attached means an unbacked item stays quiet', () async {
      final c = attachedContainer(attached: false);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      await expectBadge(item(), MediaBadgeState.none, using: c);
    });

    test('store attached and unbacked means notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      await expectBadge(item(), MediaBadgeState.notBackedUp, using: c);
    });

    test('store attached and already backed up stays quiet', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(
        mockRepo.getMediaById('m1'),
      ).thenAnswer((_) async => item(remoteUploadedAt: DateTime(2026, 6)));
      await expectBadge(item(), MediaBadgeState.none, using: c);
    });

    test('an ineligible source never shows notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      final net = item(sourceType: MediaSourceType.networkUrl);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => net);
      await expectBadge(net, MediaBadgeState.none, using: c);
    });

    test('an active transfer outranks notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      final id = await repo.enqueueUpload(mediaId: 'm1');
      await expectBadge(item(), MediaBadgeState.queued, using: c);
      await repo.markTransferring(id);
      await expectBadge(item(), MediaBadgeState.transferring, using: c);
    });

    test('a completed upload clears the badge using the fresh row, not the '
        'stale tile snapshot', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      // The tile still holds the pre-upload snapshot.
      final stale = item();
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => stale);
      final id = await repo.enqueueUpload(mediaId: 'm1');
      await expectBadge(stale, MediaBadgeState.queued, using: c);

      // The pipeline stamps the row before marking the queue row done.
      when(
        mockRepo.getMediaById('m1'),
      ).thenAnswer((_) async => item(remoteUploadedAt: DateTime(2026, 6)));
      await repo.markDone(id);

      await expectBadge(stale, MediaBadgeState.none, using: c);
    });

    test('an unavailable media repository degrades to none', () async {
      // `container` from setUp overrides neither the media repository nor
      // the attach state, so the settled-state computation throws and the
      // guard must swallow it.
      await expectBadge(item(), MediaBadgeState.none);
    });
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
      MediaBadgeState.notBackedUp,
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
