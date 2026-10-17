import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Never answers, so the view stays in its loading state for the whole test.
class _PendingResolver implements MediaSourceResolver {
  final _never = Completer<MediaSourceData>();
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) => _never.future;
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => _never.future;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

final _item = MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

/// The loading state of a full-screen view (issue #3298).
///
/// The viewers draw photos over a black gallery. A full-screen view that is
/// still resolving used to paint the grid tile's opaque surface colour, which
/// on a light theme is close to white: every swipe slid a pale panel in ahead
/// of the photo.
void main() {
  /// Pumps a view that never resolves and returns the tile fill colour.
  Future<Color> pumpLoading(
    WidgetTester tester, {
    required bool thumbnail,
  }) async {
    final theme = ThemeData.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _PendingResolver(),
            }),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaItemView(
              item: _item,
              fit: thumbnail ? BoxFit.cover : BoxFit.contain,
              thumbnail: thumbnail,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return theme.colorScheme.surfaceContainerHighest;
  }

  Finder paintedWith(Color color) => find.descendant(
    of: find.byType(MediaItemView),
    // ColoredBox alone: Container(color:) builds one, so matching both would
    // count a single fill twice.
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == color,
    ),
  );

  testWidgets('a full-screen view paints nothing while it loads', (
    tester,
  ) async {
    final surface = await pumpLoading(tester, thumbnail: false);

    expect(
      paintedWith(surface),
      findsNothing,
      reason: 'the gallery background must show through until the photo is in',
    );
  });

  testWidgets('a grid tile keeps its placeholder fill while it loads', (
    tester,
  ) async {
    final surface = await pumpLoading(tester, thumbnail: true);

    expect(paintedWith(surface), findsOneWidget);
  });
}
