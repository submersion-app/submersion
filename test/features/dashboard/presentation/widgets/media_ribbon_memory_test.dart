import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

final _t0 = DateTime.utc(2026, 1, 1);

MediaItem _photo(String id) => MediaItem(
  id: id,
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-$id',
  takenAt: _t0,
  createdAt: _t0,
  updatedAt: _t0,
);

/// The ribbon draws 128x96 tiles. Resolving the full-resolution original for
/// one is already wasteful; doing it for a screenful of them, on top of the
/// full-resolution images the photo viewer legitimately holds, is what pushed
/// the iPhone over its memory limit and had iOS kill the app on the way back
/// out of the viewer.
void main() {
  testWidgets('the ribbon resolves thumbnails, never full-resolution '
      'originals', (tester) async {
    final base = await getBaseOverrides();
    final resolver = FakeLocalFileResolver(BytesData(bytes: onePixelPng()));

    // Pinned so the expected target is exact rather than whatever the host
    // view happens to report. ThumbnailSize is in device pixels, so a 128 pt
    // tile on a 3x screen wants 384 of them.
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: resolver,
            }),
          ),
          recentMediaProvider.overrideWith(
            (ref) async => [for (var i = 0; i < 12; i++) _photo('p$i')],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: MediaRibbonCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      resolver.resolvedFullSize,
      isEmpty,
      reason:
          'a 128x96 tile must not pull AssetEntity.originBytes; that is a '
          'full-size decode per visible photo',
    );
    expect(resolver.resolvedThumbnailTargets, isNotEmpty);
    for (final target in resolver.resolvedThumbnailTargets) {
      expect(
        target,
        const Size.square(128 * 3.0),
        reason: 'the target is the tile in device pixels, not a magic number',
      );
    }
  });
}
