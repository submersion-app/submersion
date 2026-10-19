import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

final _png = Uint8List.fromList(
  img.encodePng(
    img.Image(width: 4, height: 4)..clear(img.ColorRgb8(20, 100, 160)),
  ),
);

class _BytesResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      BytesData(bytes: _png);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem photo(String id, {ColorAdjustment? adjustment, String? siteId}) =>
    MediaItem(
      id: id,
      diveId: siteId == null ? 'd1' : null,
      siteId: siteId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      colorAdjustment: adjustment,
    );

/// Issue #3520: the Adjust color panel inside the viewers.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(400, 800),
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _BytesResolver(),
              }),
            ),
            ...overrides,
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page,
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('on a phone the panel opens under the photo', (tester) async {
    await pump(
      tester,
      MediaViewerPage(mediaList: [photo('a')], initialMediaId: 'a'),
    );
    await openPanel(tester);
    final rect = tester.getRect(find.byType(ColorAdjustPanel));
    expect(rect.left, 0);
    expect(rect.top, greaterThan(300));
  });

  testWidgets('on a desktop the panel docks to the right', (tester) async {
    await pump(
      tester,
      MediaViewerPage(mediaList: [photo('a')], initialMediaId: 'a'),
      size: const Size(1200, 800),
    );
    await openPanel(tester);
    final rect = tester.getRect(find.byType(ColorAdjustPanel));
    expect(rect.left, greaterThanOrEqualTo(800));
    expect(rect.top, 0);
  });

  testWidgets('Done closes the panel', (tester) async {
    await pump(
      tester,
      MediaViewerPage(mediaList: [photo('a')], initialMediaId: 'a'),
    );
    await openPanel(tester);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.byType(ColorAdjustPanel), findsNothing);
  });

  testWidgets('paging moves the panel to the next item', (tester) async {
    await pump(
      tester,
      MediaViewerPage(mediaList: [photo('a'), photo('b')], initialMediaId: 'a'),
      size: const Size(1200, 800),
    );
    await openPanel(tester);
    await tester.tap(find.byTooltip('Next media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(
      tester.widget<ColorAdjustPanel>(find.byType(ColorAdjustPanel)).item.id,
      'b',
    );
  });

  testWidgets('holding the photo shows the original', (tester) async {
    await pump(
      tester,
      MediaViewerPage(
        mediaList: [photo('a', adjustment: const ColorAdjustment(warmth: 1))],
        initialMediaId: 'a',
      ),
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ColorFiltered), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('an adjusted photo is labelled', (tester) async {
    await pump(
      tester,
      MediaViewerPage(
        mediaList: [photo('a', adjustment: const ColorAdjustment(tint: 0.3))],
        initialMediaId: 'a',
      ),
    );
    expect(find.text('Adjusted'), findsOneWidget);
  });

  testWidgets('the site viewer offers the panel too', (tester) async {
    await pump(
      tester,
      const SiteMediaViewerPage(
        siteId: 'site-1',
        initialMediaId: 'a',
        scope: SiteViewerScope.attachments,
      ),
      overrides: [
        mediaForSiteProvider(
          'site-1',
        ).overrideWith((ref) async => [photo('a', siteId: 'site-1')]),
        flatMediaFromDivesAtSiteProvider(
          'site-1',
        ).overrideWith((ref) async => const <MediaItem>[]),
      ],
    );
    await tester.tap(find.byTooltip('Adjust color'));
    await tester.pump();
    expect(find.byType(ColorAdjustPanel), findsOneWidget);
  });
}
