import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../support/fake_keychain_storage.dart';

/// The Media Storage page's transfer indicator. Regression cover for a
/// spinning indeterminate progress bar shown while the queue was idle: rows
/// parked in markFailed's multi-hour retry backoff are 'pending' in the
/// table, but nextPending will not select them, so nothing is transferring.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(MediaTransferSummary summary) => ProviderScope(
    overrides: [
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
      mediaStoreCredentialsStoreProvider.overrideWithValue(
        MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      ),
      mediaStoreStatusHintProvider.overrideWith(
        (ref) async => 'dive-media @ minio',
      ),
      mediaTransferSummaryProvider.overrideWith((ref) => Stream.value(summary)),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaStoragePage(),
    ),
  );

  Future<void> settle(WidgetTester tester, MediaTransferSummary summary) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app(summary));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
  }

  testWidgets('work parked in retry backoff shows no progress bar', (
    tester,
  ) async {
    await settle(
      tester,
      const MediaTransferSummary(
        transferring: 0,
        queued: 0,
        waiting: 4,
        waitingReason: 'source unavailable on this device',
      ),
    );

    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'nothing is transferring, so nothing may animate',
    );
    expect(find.byKey(const Key('media-transfer-waiting')), findsOneWidget);
    expect(find.text('4 waiting to retry'), findsOneWidget);
    expect(find.text('source unavailable on this device'), findsOneWidget);
  });

  testWidgets('the waiting row routes into Transfers', (tester) async {
    await settle(
      tester,
      const MediaTransferSummary(transferring: 0, queued: 0, waiting: 4),
    );

    final tile = tester.widget<ListTile>(
      find.byKey(const Key('media-transfer-waiting')),
    );
    expect(tile.onTap, isNotNull);
  });

  testWidgets('an in-flight transfer shows the progress bar and count', (
    tester,
  ) async {
    await settle(
      tester,
      const MediaTransferSummary(transferring: 1, queued: 2, waiting: 0),
    );

    expect(find.byKey(const Key('media-transfer-progress')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const Key('media-transfer-waiting')), findsNothing);
  });

  testWidgets('due-but-not-started work reads as queued, not moving', (
    tester,
  ) async {
    await settle(
      tester,
      const MediaTransferSummary(transferring: 0, queued: 3, waiting: 0),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('3 queued'), findsOneWidget);
  });

  testWidgets('an empty queue renders no indicator at all', (tester) async {
    await settle(tester, const MediaTransferSummary());

    expect(find.byKey(const Key('media-transfer-progress')), findsNothing);
    expect(find.byKey(const Key('media-transfer-waiting')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
