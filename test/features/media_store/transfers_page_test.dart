import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The page renders from SNAPSHOT streams here: live drift watch() streams
/// held open by the widget tree deadlock against db.close() in the
/// fake-async test zone. Stream behavior is covered by the repository
/// tests; these tests cover rendering and the retry action.
void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  Widget app(List<MediaTransferQueueEntry> entries) => ProviderScope(
    overrides: [
      mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
      mediaTransferEntriesProvider.overrideWith((ref) => Stream.value(entries)),
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TransfersPage(),
    ),
  );

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
}
