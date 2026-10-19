import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubResolver implements MediaSourceResolver {
  _StubResolver(this._data);
  final MediaSourceData _data;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async => _data;
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

const _warm = ColorAdjustment(warmth: 0.5);

MediaItem _item({ColorAdjustment? adjustment = _warm}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2024),
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
  colorAdjustment: adjustment,
);

/// Issue #3520: every tile draws through MediaItemView, so the colour
/// correction applies to images there and never to placeholders.
void main() {
  final png = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 2, height: 2)..clear(img.ColorRgb8(20, 100, 160)),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    MediaSourceData data,
    MediaItem item,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _StubResolver(data),
            }),
          ),
          diverAutoColorCorrectionProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: MediaItemView(item: item, thumbnail: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('an adjusted photo draws its image through the matrix', (
    tester,
  ) async {
    await pump(tester, BytesData(bytes: png), _item());
    final filtered = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(
      filtered.colorFilter,
      ColorFilter.matrix(composeCorrection(adjustment: _warm).values),
    );
    expect(
      find.descendant(
        of: find.byType(ColorFiltered),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unadjusted photo is drawn without a filter', (tester) async {
    await pump(tester, BytesData(bytes: png), _item(adjustment: null));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('a placeholder is never filtered', (tester) async {
    await pump(
      tester,
      const UnavailableData(kind: UnavailableKind.notFound),
      _item(),
    );
    expect(find.byType(ColorFiltered), findsNothing);
  });
}
