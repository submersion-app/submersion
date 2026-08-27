import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';
import '../support/media_widget_harness.dart';

/// The full-screen viewer's decode budget (#1175).
///
/// Every `thumbnail: false` call site -- `media_viewer_page` and
/// `site_media_viewer_page` -- is a full-screen pager, and none of them pass a
/// [MediaItemView.targetSize]. `cacheWidth` used to be derived from that size
/// alone, so all three decoded at the file's NATIVE resolution: a 24 MP JPEG
/// becomes ~96 MB of RGBA. `PageView` keeps the outgoing and incoming pages
/// mounted during a swipe, and an image with a live listener is exempt from
/// `ImageCache`'s byte budget, so the peak is two of those regardless of the
/// 75 MB cap `applyMediaCacheCaps` sets. That is the Android OOM in #1175.
void main() {
  Future<Image> pumpViewer(
    WidgetTester tester, {
    Size? targetSize,
    bool thumbnail = false,
  }) async {
    final base = await getBaseOverrides();
    final resolver = FakeLocalFileResolver(BytesData(bytes: onePixelPng()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: resolver,
              MediaSourceType.platformGallery: resolver,
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaItemView(
              item: testMediaItem(),
              fit: BoxFit.contain,
              thumbnail: thumbnail,
              targetSize: targetSize,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<Image>(find.byType(Image));
  }

  /// 400x300 logical at 3x, so the expected bounds below are concrete numbers
  /// rather than a restatement of the production formula.
  void useViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a full-screen image decodes bounded by the viewport', (
    tester,
  ) async {
    useViewport(tester);

    final image = await pumpViewer(tester);

    final provider = image.image;
    expect(
      provider,
      isA<ResizeImage>(),
      reason:
          'no cacheWidth means Image decodes at the source resolution, and a '
          'full-frame original is tens of megabytes of bitmap',
    );
    // 400 logical longest side x 3.0 dpr x 2 (the zoom headroom PhotoView's
    // maxScale needs) = 2400.
    expect((provider as ResizeImage).width, 2400);
    expect(
      provider.height,
      isNull,
      reason: 'both dimensions would decode to exact bounds and distort',
    );
  });

  testWidgets('an explicit targetSize still wins over the viewport bound', (
    tester,
  ) async {
    useViewport(tester);

    final image = await pumpViewer(
      tester,
      thumbnail: true,
      targetSize: const Size(200, 200),
    );

    // 200 x 3.0 dpr = 600, unchanged by the viewport fallback.
    expect((image.image as ResizeImage).width, 600);
  });

  testWidgets('a sizeless thumbnail decodes to the default thumbnail target', (
    tester,
  ) async {
    // `thumbnail: true` alone is the caller's statement that a few hundred
    // pixels are all this will ever draw, and `_resolveInner` already honours
    // it by resolving against kDefaultThumbnailTarget when no size is given.
    // The decode bound has to agree: taking the full-screen fallback here
    // would hand a 128 px tile the viewer's budget, which is the same
    // "the flag is a silent no-op unless you also pass a Size" bug this
    // widget was fixed for once already.
    useViewport(tester);

    final image = await pumpViewer(tester, thumbnail: true);

    // kDefaultThumbnailTarget is 200x200; 200 x 3.0 dpr = 600. The viewport
    // fallback would be 2400.
    expect((image.image as ResizeImage).width, 600);
  });
}
