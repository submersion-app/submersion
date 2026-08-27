import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Runs out a route transition without pumpAndSettle.
///
/// This page animates the progress of in-flight transfers, so pumpAndSettle
/// never returns here. Widget tests run on a fake clock, so this advances
/// simulated time deterministically -- machine speed cannot affect it. The
/// duration deliberately overshoots any plausible menu or dialog transition
/// rather than matching Flutter's internal constants, which this test has no
/// business encoding.
///
/// Three frames, not one: the first starts the transition, the second runs it
/// out, and the third renders whatever the completed route caused. Selecting a
/// popup menu entry needs all three -- PopupMenuButton.onSelected fires only
/// once the pop animation finishes, so the dialog it opens appears a frame
/// after the menu is gone.
Future<void> pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// The page renders from SNAPSHOT streams here: live drift watch() streams
/// held open by the widget tree deadlock against db.close() in the
/// fake-async test zone. Stream behavior is covered by the repository
/// tests; these tests cover rendering and the retry action.
void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;
  late LocalAssetCacheRepository assetCache;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
    assetCache = LocalAssetCacheRepository(database: db);
  });

  tearDown(() => db.close());

  Widget app(List<MediaTransferQueueEntry> entries) => ProviderScope(
    overrides: [
      mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
      localAssetCacheRepositoryProvider.overrideWithValue(assetCache),
      mediaTransferEntriesProvider.overrideWith((ref) => Stream.value(entries)),
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(
      // Pinned: these tests find widgets by their English strings.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TransfersPage(),
    ),
  );

  // NOTE: this page does not run verifySelectionContract. The contract helper
  // calls pumpAndSettle, and as the header above explains, this page renders
  // from streams whose live form deadlocks against db.close() in the
  // fake-async zone -- a snapshot stream leaves the provider loading and the
  // spinner animating, so pumpAndSettle never returns. The selection
  // behaviour is covered by the targeted tests below instead: the Select
  // affordance, select-all, the retry gate, and bulk delete.

  testWidgets('exposes a visible Select affordance and select-all', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      await repo.enqueueUpload(mediaId: 'm-a');
      await repo.enqueueUpload(mediaId: 'm-b');
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selection_exit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
  });

  testWidgets('renders the checkbox inside the row, not beside it', (
    tester,
  ) async {
    // Stands in for the rowRoot assertion in verifySelectionContract, which
    // this page cannot run for the reason described above.
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      await repo.enqueueUpload(mediaId: 'm-a');
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byType(Checkbox),
      ),
      findsOneWidget,
    );
  });

  testWidgets('bulk retry requeues every checked failed entry', (tester) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final a = await repo.enqueueUpload(mediaId: 'm-a');
      final b = await repo.enqueueUpload(mediaId: 'm-b');
      await repo.markFailed(a, 'boom');
      await repo.markFailed(b, 'boom');
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pump();

    final retry = find.byKey(const ValueKey('selection_action_retry'));
    expect(
      tester.widget<IconButton>(retry).onPressed,
      isNotNull,
      reason: 'a uniformly failed selection is retryable',
    );

    await tester.tap(retry);
    await tester.pump();

    await tester.runAsync(() async {
      final rows = await repo.watchEntries().first;
      expect(
        rows.every((e) => e.state == 'pending' && e.errorMessage == null),
        isTrue,
        reason: 'retry must clear the error and requeue every checked entry',
      );
    });
  });

  testWidgets('a transferring entry cannot be bulk-retried', (tester) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final a = await repo.enqueueUpload(mediaId: 'm-a');
      await repo.markTransferring(a);
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    // pump, not pumpAndSettle: a transferring row animates a progress bar
    // that never settles.
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pump();

    // The worker still holds a transferring row; requeueing it would upload
    // the same asset twice.
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('selection_action_retry')),
          )
          .onPressed,
      isNull,
      reason: 'retry must stay disabled while an entry is transferring',
    );
  });

  testWidgets('bulk delete removes the checked queue entries', (tester) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      await repo.enqueueUpload(mediaId: 'm-a');
      await repo.enqueueUpload(mediaId: 'm-b');
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await pumpRoute(tester);
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await pumpRoute(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Delete').hitTestable().last);
    await tester.pump();

    await tester.runAsync(() async {
      final remaining = await repo.watchEntries().first;
      expect(remaining, isEmpty);
    });
  });

  testWidgets('renders the empty state', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pump();
    expect(find.text('No transfers'), findsOneWidget);
  });

  testWidgets('renders entries with their states and error text', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final a = await repo.enqueueUpload(mediaId: 'm-a');
      await repo.enqueueUpload(mediaId: 'm-b');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(a, 'no route to host');
      }
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('no route to host'), findsOneWidget);
  });

  testWidgets('retry button resets a failed entry', (tester) async {
    late List<MediaTransferQueueEntry> snapshot;
    late int failedId;
    await tester.runAsync(() async {
      failedId = await repo.enqueueUpload(mediaId: 'm-a');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(failedId, 'boom');
      }
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final row = (await tester.runAsync(() => repo.allForTesting()))!.single;
    expect(row.state, 'pending');
  });

  testWidgets('retry clears the asset-resolution negative cache', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-a');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(id, 'source unavailable on this device');
      }
      // Resolution gave up on this media and will refuse to re-scan the
      // gallery for 24h; without clearing it, retry drains straight back
      // into the same failure.
      await assetCache.cacheResolution(
        mediaId: 'm-a',
        localAssetId: null,
        method: 'unresolved',
      );
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final entry = await tester.runAsync(() => assetCache.getCacheEntry('m-a'));
    expect(entry, isNull);
  });

  testWidgets('a pending entry carrying an error can still be retried', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-a');
      // One failure only: still 'pending', but parked behind a long backoff.
      await repo.markFailed(
        id,
        'source unavailable on this device',
        retryAfter: const Duration(hours: 25),
      );
      snapshot = await repo.watchEntries().first;
    });

    expect(snapshot.single.state, 'pending');

    await tester.pumpWidget(app(snapshot));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a transferring entry carrying a stale error offers no Retry', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-a');
      await repo.markFailed(id, 'source unavailable on this device');
      // markTransferring does NOT clear errorMessage, so an in-flight row can
      // still carry the previous attempt's error. Retrying it would flip a row
      // the worker is actively uploading back to pending.
      await repo.markTransferring(id);
      snapshot = await repo.watchEntries().first;
    });

    expect(snapshot.single.state, 'transferring');
    expect(snapshot.single.errorMessage, isNotNull);

    await tester.pumpWidget(app(snapshot));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('transferring entries render a determinate progress bar', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-v');
      await repo.markTransferring(id);
      await repo.updateProgress(id, transferredBytes: 25, totalBytes: 100);
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
  });

  testWidgets('a completed entry shows Done and Clear removes it', (
    tester,
  ) async {
    late List<MediaTransferQueueEntry> snapshot;
    await tester.runAsync(() async {
      final id = await repo.enqueueUpload(mediaId: 'm-done');
      await repo.markTransferring(id);
      await repo.markDone(id);
      snapshot = await repo.watchEntries().first;
    });

    await tester.pumpWidget(app(snapshot));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfers-clear-done')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    final rows = (await tester.runAsync(() => repo.allForTesting()))!;
    expect(rows.where((r) => r.state == 'done'), isEmpty);
  });

  testWidgets('shows a spinner while the transfer list is loading', (
    tester,
  ) async {
    final controller = StreamController<List<MediaTransferQueueEntry>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
          mediaTransferEntriesProvider.overrideWith((ref) => controller.stream),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TransfersPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // Issue #1270: the dashboard's "N uploads pending" chip pushes straight
  // here, and go_router builds this route with a plain `builder` nested under
  // media-storage, so MediaStoragePage - the one screen whose build resolves
  // the runtime, and therefore the app's only reliable drain trigger - never
  // runs on the way in. Opening Transfers showed the stuck rows without doing
  // anything about them, which is precisely what the reporter expected it to
  // fix. Resolving the runtime here kicks the drain (see the unawaited
  // worker.drain() at the end of mediaStoreRuntimeProvider).
  testWidgets('opening the page resolves the runtime, which drains the queue', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
          localAssetCacheRepositoryProvider.overrideWithValue(assetCache),
          mediaTransferEntriesProvider.overrideWith(
            (ref) => Stream.value(const <MediaTransferQueueEntry>[]),
          ),
          mediaStoreRuntimeProvider.overrideWith((ref) async {
            builds++;
            return null;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TransfersPage(),
        ),
      ),
    );
    await pumpRoute(tester);

    expect(builds, 1);
  });
}
