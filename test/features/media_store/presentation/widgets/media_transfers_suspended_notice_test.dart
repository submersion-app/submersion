import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_reconnect_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_transfers_suspended_notice.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_media_store_reconnect.dart';

void main() {
  Future<void> pump(WidgetTester tester, MediaTransferHoldKind kind) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaTransfersSuspendedProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            mediaTransferSummaryProvider.overrideWith(
              (ref) => Stream.value(
                MediaTransferSummary(
                  queued: 2,
                  hold: MediaTransferHold(kind, 'raw error'),
                ),
              ),
            ),
            mediaStoreRuntimeProvider.overrideWith((ref) async => null),
            mediaStoreReconnectProvider.overrideWithValue(
              FakeMediaStoreReconnect(),
            ),
            photosCopiesProvider.overrideWith(
              (ref) async =>
                  (attached: true, store: null, group: null, label: 'Dropbox'),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MediaTransfersSuspendedNotice()),
          ),
        ),
      );

  // Issue #2303: the notice that names a mismatch is where the way out is.
  testWidgets('a marker mismatch offers the guided reconnect', (tester) async {
    await pump(tester, MediaTransferHoldKind.markerMismatch);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The account no longer holds the copies this device was using. '
        'Reconnect to choose what happens next.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('media-transfers-reconnect')));
    await tester.pumpAndSettle();

    expect(find.text('Reconnect photo copies'), findsOneWidget);
  });

  for (final kind in [
    MediaTransferHoldKind.detached,
    MediaTransferHoldKind.storeUnreachable,
  ]) {
    testWidgets('$kind offers no reconnect', (tester) async {
      await pump(tester, kind);
      await tester.pumpAndSettle();

      expect(find.text('Uploads paused'), findsOneWidget);
      expect(find.byKey(const Key('media-transfers-reconnect')), findsNothing);
    });
  }
}
