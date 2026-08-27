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

/// `thumbnail: true` is the caller's statement that a few hundred pixels are
/// all this tile will ever draw. Honouring it only when a [Size] happens to
/// be supplied made the flag a silent no-op at any call site that forgot one,
/// and the fallback is not a cheap one: for a gallery item it is
/// `AssetEntity.originBytes`, the untouched original, decoded at full native
/// resolution because the Image widgets carry no cacheWidth. A dozen 12 MP
/// originals is roughly 600 MB of RGBA, which is how an iPhone gets jetsammed.
void main() {
  late FakeLocalFileResolver resolver;

  Future<void> pumpView(
    WidgetTester tester, {
    required bool thumbnail,
    Size? targetSize,
  }) async {
    final base = await getBaseOverrides();
    resolver = FakeLocalFileResolver(BytesData(bytes: onePixelPng()));
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
            body: SizedBox(
              width: 128,
              height: 96,
              child: MediaItemView(
                item: testMediaItem(),
                thumbnail: thumbnail,
                targetSize: targetSize,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a sized thumbnail request resolves a thumbnail', (tester) async {
    await pumpView(tester, thumbnail: true, targetSize: const Size(200, 200));

    expect(resolver.resolvedThumbnailTargets, [const Size(200, 200)]);
    expect(resolver.resolvedFullSize, isEmpty);
  });

  testWidgets('an unsized thumbnail request still resolves a thumbnail, not '
      'the full-resolution original', (tester) async {
    await pumpView(tester, thumbnail: true);

    expect(
      resolver.resolvedFullSize,
      isEmpty,
      reason: 'thumbnail: true must never fall through to the original',
    );
    expect(resolver.resolvedThumbnailTargets, hasLength(1));
  });

  testWidgets('a non-thumbnail request resolves the full-resolution original', (
    tester,
  ) async {
    await pumpView(tester, thumbnail: false);

    expect(resolver.resolvedFullSize, ['m1']);
    expect(resolver.resolvedThumbnailTargets, isEmpty);
  });
}
