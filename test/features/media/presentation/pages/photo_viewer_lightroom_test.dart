import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Enabled so the "Open in Lightroom" wiring can be verified; the flag
    // defaults to false while Lightroom is pending Adobe review.
    lightroomUiEnabled = true;
  });

  tearDown(() async {
    lightroomUiEnabled = false;
    await tearDownTestDatabase();
  });

  final account = domain.ConnectedAccount(
    id: 'acct1',
    kind: AccountKind.adobeLightroom,
    label: 'Eric',
    accountIdentifier: 'cat1',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  MediaItem item({
    MediaSourceType sourceType = MediaSourceType.serviceConnector,
  }) => MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    remoteAssetId: sourceType == MediaSourceType.serviceConnector
        ? 'lr1'
        : null,
    platformAssetId: sourceType == MediaSourceType.platformGallery
        ? 'g1'
        : null,
    takenAt: DateTime.utc(2026, 7, 1, 10),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  Future<void> pump(
    WidgetTester tester, {
    required MediaItem media,
    domain.ConnectedAccount? withAccount,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            lightroomAccountProvider.overrideWith((ref) async => withAccount),
            mediaForDiveProvider('d1').overrideWith((ref) async => [media]),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PhotoViewerPage(diveId: 'd1', initialMediaId: 'm1'),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  testWidgets('shows Open in Lightroom for a connector item on the '
      'connected device', (tester) async {
    await pump(tester, media: item(), withAccount: account);
    expect(find.byTooltip('Open in Lightroom'), findsOneWidget);
  });

  testWidgets('hides Open in Lightroom when lightroomUiEnabled is false even '
      'for a connected-device connector item (pending Adobe review)', (
    tester,
  ) async {
    lightroomUiEnabled = false;
    await pump(tester, media: item(), withAccount: account);
    expect(find.byTooltip('Open in Lightroom'), findsNothing);
  });

  testWidgets('hides Open in Lightroom without a connected account', (
    tester,
  ) async {
    await pump(tester, media: item());
    expect(find.byTooltip('Open in Lightroom'), findsNothing);
  });

  testWidgets('hides Open in Lightroom for non-connector items', (
    tester,
  ) async {
    await pump(
      tester,
      media: item(sourceType: MediaSourceType.platformGallery),
      withAccount: account,
    );
    expect(find.byTooltip('Open in Lightroom'), findsNothing);
  });

  testWidgets('a connector video shows the poster + Open in Lightroom, not '
      'the local player (which fails with "video file not found")', (
    tester,
  ) async {
    final video = MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
      remoteAssetId: 'lr1',
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await pump(tester, media: video, withAccount: account);

    // The connector-video body renders the Open-in-Lightroom play affordance
    // (a Text label) and never routes to the local player's error.
    expect(find.text('Open in Lightroom'), findsOneWidget);
    expect(find.text('Video file not found'), findsNothing);
  });

  testWidgets('the connector-video play affordance is a labeled semantic '
      'button for screen readers', (tester) async {
    final video = MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
      remoteAssetId: 'lr1',
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await pump(tester, media: video, withAccount: account);

    final labeled = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where(
          (s) =>
              s.properties.label == 'Open in Lightroom' &&
              s.properties.button == true,
        );
    expect(labeled, isNotEmpty);
  });
}
