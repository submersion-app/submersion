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
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubResolver implements MediaSourceResolver {
  _StubResolver(this._data, this.sourceType);
  final MediaSourceData _data;
  @override
  final MediaSourceType sourceType;
  int resolveCalls = 0;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    resolveCalls++;
    return _data;
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

class _ThrowingResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    throw StateError('boom');
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

MediaItem _item({String id = 'x'}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

Widget _wrap({required Widget child, required MediaSourceResolver resolver}) {
  return ProviderScope(
    overrides: [
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({resolver.sourceType: resolver}),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

// Minimal valid 1x1 transparent PNG so Image.memory can decode it.
final _pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xFA,
  0xFF,
  0x1F,
  0x00,
  0x01,
  0xAD,
  0x4F,
  0x41,
  0x9F,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  testWidgets('renders Image.memory for BytesData', (tester) async {
    final stub = _StubResolver(
      BytesData(bytes: _pngBytes),
      MediaSourceType.platformGallery,
    );
    await tester.pumpWidget(
      _wrap(
        child: MediaItemView(item: _item()),
        resolver: stub,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders UnavailableMediaPlaceholder for UnavailableData', (
    tester,
  ) async {
    final stub = _StubResolver(
      const UnavailableData(kind: UnavailableKind.notFound),
      MediaSourceType.platformGallery,
    );
    await tester.pumpWidget(
      _wrap(
        child: MediaItemView(item: _item()),
        resolver: stub,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('File not found'), findsOneWidget);
  });

  testWidgets(
    'renders UnavailableMediaPlaceholder when resolver future throws',
    (tester) async {
      final resolver = _ThrowingResolver();
      await tester.pumpWidget(
        _wrap(
          child: MediaItemView(item: _item()),
          resolver: resolver,
        ),
      );
      await tester.pumpAndSettle();
      // notFound is the generic "we couldn't load this" fallback the widget
      // uses for any thrown resolver error — i.e. NOT a permanent shimmer.
      expect(find.text('File not found'), findsOneWidget);
    },
  );

  testWidgets('memoizes future across rebuilds with the same item', (
    tester,
  ) async {
    final stub = _StubResolver(
      BytesData(bytes: _pngBytes),
      MediaSourceType.platformGallery,
    );
    final key = UniqueKey();
    Widget treeWith(String label) => _wrap(
      child: Column(
        children: [
          Text(label),
          SizedBox(
            width: 50,
            height: 50,
            child: MediaItemView(key: key, item: _item()),
          ),
        ],
      ),
      resolver: stub,
    );

    await tester.pumpWidget(treeWith('first'));
    await tester.pumpAndSettle();
    expect(stub.resolveCalls, 1);

    // Force a rebuild by changing a sibling. Same MediaItem identity, same
    // widget key — the memoized future should NOT be recomputed.
    await tester.pumpWidget(treeWith('second'));
    await tester.pumpAndSettle();
    expect(stub.resolveCalls, 1);
  });

  testWidgets('recomputes future when item.id changes', (tester) async {
    final stub = _StubResolver(
      BytesData(bytes: _pngBytes),
      MediaSourceType.platformGallery,
    );
    final key = UniqueKey();
    Widget treeFor(String id) => _wrap(
      child: SizedBox(
        width: 50,
        height: 50,
        child: MediaItemView(
          key: key,
          item: _item(id: id),
        ),
      ),
      resolver: stub,
    );

    await tester.pumpWidget(treeFor('id-a'));
    await tester.pumpAndSettle();
    expect(stub.resolveCalls, 1);

    await tester.pumpWidget(treeFor('id-b'));
    await tester.pumpAndSettle();
    expect(stub.resolveCalls, 2);
  });
}
