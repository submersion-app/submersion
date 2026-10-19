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
  int calls = 0;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    calls++;
    return _data;
  }

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
    // Only the decoded frame is filtered, inside the Image.
    expect(
      find.descendant(
        of: find.byType(ColorFiltered),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unadjusted photo is drawn without a filter', (tester) async {
    await pump(tester, BytesData(bytes: png), _item(adjustment: null));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('saving an adjustment does not reload the image', (tester) async {
    final resolver = _StubResolver(BytesData(bytes: png));
    Widget view(MediaItem item) => ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: resolver,
          }),
        ),
        diverAutoColorCorrectionProvider.overrideWithValue(false),
      ],
      child: MaterialApp(home: MediaItemView(item: item, thumbnail: true)),
    );
    await tester.pumpWidget(view(_item(adjustment: null)));
    await tester.pump();
    expect(resolver.calls, 1);
    // A save changes the colour column and bumps updatedAt; the pixels the
    // tile resolves are the same.
    await tester.pumpWidget(
      view(_item().copyWith(updatedAt: DateTime.utc(2025))),
    );
    await tester.pump();
    expect(resolver.calls, 1);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('hydrating a lean row with its enrichment does not reload', (
    tester,
  ) async {
    final resolver = _StubResolver(BytesData(bytes: png));
    Widget view(MediaItem item) => ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: resolver,
          }),
        ),
        diverAutoColorCorrectionProvider.overrideWithValue(false),
      ],
      child: MaterialApp(home: MediaItemView(item: item)),
    );
    // The library hands the viewer a lean row; the page then reads the
    // full row, which adds the profile match.
    await tester.pumpWidget(view(_item(adjustment: null)));
    await tester.pump();
    await tester.pumpWidget(
      view(
        _item(adjustment: null).copyWith(
          enrichment: MediaEnrichment(
            id: 'e',
            mediaId: 'x',
            diveId: 'd',
            depthMeters: 12,
            elapsedSeconds: 300,
            matchConfidence: MatchConfidence.interpolated,
            createdAt: DateTime.utc(2024),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(resolver.calls, 1);
  });

  testWidgets('a broken image tile is never filtered', (tester) async {
    await pump(
      tester,
      BytesData(bytes: Uint8List.fromList([1, 2, 3, 4])),
      _item(),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
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
