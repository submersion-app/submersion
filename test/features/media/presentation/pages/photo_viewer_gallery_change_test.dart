import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// The viewer is opened at one photo but pages across the whole dive gallery,
/// and that gallery is live: a delete from the files tab, a dive-deletion
/// cascade or a sync pull rewrites it underneath the open viewer.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  MediaItem photo(String id) => MediaItem(
    id: id,
    diveId: 'd1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'g-$id',
    takenAt: DateTime.utc(2026, 7, 1, 10),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  final all = [photo('p1'), photo('p2'), photo('p3')];

  /// Mutable backing for the overridden gallery provider, so a test can
  /// rewrite the list and invalidate to replay a real-world change.
  late List<MediaItem> gallery;

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }

  /// Opens the viewer on the LAST photo, the way the home ribbon does: it
  /// shows the newest photos, which sit at the end of their dive's gallery.
  Future<ProviderContainer> pump(WidgetTester tester) async {
    gallery = List.of(all);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaForDiveProvider('d1').overrideWith((ref) async => gallery),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhotoViewerPage(diveId: 'd1', initialMediaId: 'p3'),
        ),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(PhotoViewerPage)),
    );
  }

  Future<void> replaceGallery(
    WidgetTester tester,
    ProviderContainer container,
    List<MediaItem> next,
  ) async {
    gallery = next;
    container.invalidate(mediaForDiveProvider('d1'));
    await settle(tester);
  }

  testWidgets('a gallery that shrinks past the open page does not throw', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final container = await pump(tester);
      expect(find.text('3 / 3'), findsOneWidget);

      // Two of the three photos are gone; the viewer was sitting on index 2.
      await replaceGallery(tester, container, [photo('p1')]);

      expect(
        tester.takeException(),
        isNull,
        reason: 'indexing the shrunken list must not go out of range',
      );
      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });
  });

  testWidgets('the page controller is created once and survives the gallery '
      'emptying and repopulating', (tester) async {
    await tester.runAsync(() async {
      final container = await pump(tester);
      final first = tester
          .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
          .pageController;
      expect(first, isNotNull);

      // Emptying unmounts the gallery, which detaches the controller. That
      // is the state the old hasClients check could not tell apart from
      // "not attached yet", so it minted a replacement and dropped the
      // original on the floor -- a leak on every such rebuild.
      await replaceGallery(tester, container, []);
      expect(find.byType(PhotoViewGallery), findsNothing);

      await replaceGallery(tester, container, List.of(all));
      final second = tester
          .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
          .pageController;

      expect(
        identical(first, second),
        isTrue,
        reason: 'the viewer must reuse its controller, not leak and replace',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
