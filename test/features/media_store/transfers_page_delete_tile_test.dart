import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  MediaTransferQueueData entry({
    required String direction,
    required String state,
  }) => MediaTransferQueueData(
    id: 1,
    mediaId: 'dead-row',
    direction: direction,
    objectKind: 'original',
    contentHash: 'aa',
    state: state,
    attempts: 0,
    priority: 0,
    createdAt: 0,
    updatedAt: 0,
  );

  Widget app(MediaTransferQueueData row) => ProviderScope(
    overrides: [
      mediaTransferEntriesProvider.overrideWith((ref) => Stream.value([row])),
      // Without these the page builds the real runtime and reaches for a
      // database and SharedPreferences neither of which this test sets up;
      // it passed only because both widgets swallow the failure.
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
      mediaTransferLabelsProvider.overrideWith((ref) async => const {}),
      mediaTransfersSuspendedProvider.overrideWith(
        (ref) => Stream.value(false),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TransfersPage(),
    ),
  );

  testWidgets('a transferring delete entry shows the removing label', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(entry(direction: 'delete', state: 'transferring')),
    );
    await tester.pump();

    expect(find.text('Removing from cloud'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsNothing);
  });

  testWidgets('a pending delete entry keeps the delete icon', (tester) async {
    await tester.pumpWidget(app(entry(direction: 'delete', state: 'pending')));
    await tester.pump();

    expect(find.text('Waiting'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('upload entries are unchanged', (tester) async {
    await tester.pumpWidget(
      app(entry(direction: 'upload', state: 'transferring')),
    );
    await tester.pump();

    expect(find.text('Uploading'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });
}
