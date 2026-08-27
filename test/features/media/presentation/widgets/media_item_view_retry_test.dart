import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A 1x1 transparent PNG, so Image.memory has something it can decode.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);

/// Answers with [first] once, then [then] on every later call.
class _RelentingResolver implements MediaSourceResolver {
  _RelentingResolver({required this.first, required this.then});

  final MediaSourceData first;
  final MediaSourceData then;
  int calls = 0;

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    calls++;
    return calls == 1 ? first : then;
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem _item() => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _wrap(MediaSourceResolver resolver) => ProviderScope(
  overrides: [
    mediaSourceResolverRegistryProvider.overrideWithValue(
      MediaSourceResolverRegistry({resolver.sourceType: resolver}),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 140,
          height: 140,
          child: MediaItemView(item: _item(), thumbnail: true),
        ),
      ),
    ),
  ),
);

/// A still-loading tile is a dead end unless tapping it re-resolves: the
/// placeholder's own copy promises a retry.
void main() {
  testWidgets('tapping a still-loading tile re-resolves it', (tester) async {
    final resolver = _RelentingResolver(
      first: const UnavailableData(kind: UnavailableKind.stillFetching),
      then: BytesData(bytes: _png),
    );

    await tester.pumpWidget(_wrap(resolver));
    await tester.pumpAndSettle();

    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
    expect(resolver.calls, 1);

    await tester.tap(find.byType(UnavailableMediaPlaceholder));
    await tester.pumpAndSettle();

    expect(resolver.calls, 2);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('tapping a genuinely missing tile does not re-resolve', (
    tester,
  ) async {
    final resolver = _RelentingResolver(
      first: const UnavailableData(kind: UnavailableKind.notFound),
      then: BytesData(bytes: _png),
    );

    await tester.pumpWidget(_wrap(resolver));
    await tester.pumpAndSettle();

    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);

    await tester.tap(find.byType(UnavailableMediaPlaceholder));
    await tester.pumpAndSettle();

    expect(
      resolver.calls,
      1,
      reason: 'retrying a dead pointer on tap would be a placebo',
    );
    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
  });

  testWidgets('a retry that is still slow stays retryable', (tester) async {
    final resolver = _RelentingResolver(
      first: const UnavailableData(kind: UnavailableKind.stillFetching),
      then: const UnavailableData(kind: UnavailableKind.stillFetching),
    );

    await tester.pumpWidget(_wrap(resolver));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UnavailableMediaPlaceholder));
    await tester.pumpAndSettle();
    expect(resolver.calls, 2);

    await tester.tap(find.byType(UnavailableMediaPlaceholder));
    await tester.pumpAndSettle();
    expect(resolver.calls, 3);
  });
}
