import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
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
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../../helpers/in_memory_media_object_store.dart';

/// Valid 1x1 transparent PNG, generated with python3 (struct + zlib).
const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=';

class _UnavailableGalleryResolver implements MediaSourceResolver {
  const _UnavailableGalleryResolver();

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => false;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.fromOtherDevice);

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async => const UnavailableData(kind: UnavailableKind.fromOtherDevice);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async =>
      VerifyResult.fromOtherDevice;
}

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('miv_fallback_test');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Widget app(MediaItem item, {MediaStoreRuntime? runtime}) => ProviderScope(
    overrides: [
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: const _UnavailableGalleryResolver(),
        }),
      ),
      mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: MediaItemView(item: item),
        ),
      ),
    ),
  );

  MediaItem galleryItem({required String hash}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-from-other-device',
    originalFilename: 'reef.png',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: DateTime(2026, 7, 1),
  );

  testWidgets('renders the store bytes when native resolution is '
      'unavailable', (tester) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(_onePixelPngBase64);
      final seed = File('${root.path}/seed.png');
      await seed.writeAsBytes(bytes, flush: true);
      final digest = await sha256OfFile(seed);
      store.objects[StoreKeys.objectKey(digest.hash, extension: 'png')] = bytes;

      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      await tester.pumpWidget(
        app(galleryItem(hash: digest.hash), runtime: runtime),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
    });

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
  });

  testWidgets('a thumbnail renders from the store when only the thumb '
      'stamp is present', (tester) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(_onePixelPngBase64);
      final hash = 'a1${'9' * 62}';
      store.objects[StoreKeys.thumbKey(hash)] = bytes;

      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      // Thumb uploaded, original still in flight on the other device.
      // Built directly (not via galleryItem().copyWith) because copyWith
      // cannot clear remoteUploadedAt back to null.
      final earlyRow = MediaItem(
        id: 'm-early',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'asset-from-other-device',
        originalFilename: 'reef.png',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
        remoteThumbUploadedAt: DateTime(2026, 7, 1),
      );
      expect(earlyRow.remoteUploadedAt, isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery:
                    const _UnavailableGalleryResolver(),
              }),
            ),
            mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 100,
                height: 100,
                child: MediaItemView(
                  item: earlyRow,
                  thumbnail: true,
                  targetSize: const Size(100, 100),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
    });

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
  });

  // Regression: an upload-quality setting that stores a compressed rendition
  // instead of the original leaves remoteUploadedAt null forever, so gating
  // the store fallback on that stamp alone made the full-size view report
  // "File not found" on every other device — while the grid thumbnail beside
  // it rendered fine off the thumb stamp. MediaStoreResolver has always been
  // able to serve the rendition; only the gate in front of it was too narrow.
  testWidgets('renders the compressed rendition when only the compressed '
      'stamp is present', (tester) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(_onePixelPngBase64);
      final hash = 'c3${'7' * 62}';
      final uploadedAt = DateTime(2026, 7, 2);
      store.objects[StoreKeys.renditionKey(hash, ext: 'jpg')] = bytes;

      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      // Exactly the shape a "small" upload-quality row syncs with: thumb and
      // rendition uploaded, original never.
      final compressedRow = MediaItem(
        id: 'm-compressed',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'asset-from-other-device',
        originalFilename: 'reef.png',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
        remoteThumbUploadedAt: uploadedAt,
        remoteCompressedUploadedAt: uploadedAt,
      );
      expect(compressedRow.remoteUploadedAt, isNull);

      await tester.pumpWidget(app(compressedRow, runtime: runtime));
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
    });

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
  });

  // A video linked on a laptop reaches a phone with only its poster frame in
  // the store. The poster is a still image -- a JPEG in production, any
  // decodable image as far as this test is concerned -- but the row is a
  // video, so the view's "videos are not decodable images" guard used to
  // swallow it and draw the movie icon over a thumbnail it had already
  // downloaded. The seeded bytes stand in for the poster; what is under test
  // is which branch the view takes, not the encoding.
  testWidgets('renders a video poster from the store instead of the movie '
      'placeholder', (tester) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(_onePixelPngBase64);
      final hash = 'e5${'5' * 62}';
      store.objects[StoreKeys.thumbKey(hash)] = bytes;

      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      final videoRow = MediaItem(
        id: 'v-remote',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'asset-from-other-device',
        originalFilename: 'DIVE_001.mp4',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
        remoteThumbUploadedAt: DateTime(2026, 7, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery:
                    const _UnavailableGalleryResolver(),
              }),
            ),
            mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 100,
                height: 100,
                child: MediaItemView(
                  item: videoRow,
                  thumbnail: true,
                  targetSize: const Size(100, 100),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
    });

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
  });

  // The complement: without a poster the tile must still read as a video,
  // and must not have pulled the whole file down to get there.
  testWidgets('keeps the movie placeholder when the store holds no '
      'poster', (tester) async {
    await tester.runAsync(() async {
      final hash = 'a7${'3' * 62}';
      store.objects[StoreKeys.objectKey(hash, extension: 'mp4')] =
          'a-very-large-video'.codeUnits;

      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      final videoRow = MediaItem(
        id: 'v-no-poster',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'asset-from-other-device',
        originalFilename: 'DIVE_002.mp4',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
        remoteUploadedAt: DateTime(2026, 7, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery:
                    const _UnavailableGalleryResolver(),
              }),
            ),
            mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 100,
                height: 100,
                child: MediaItemView(
                  item: videoRow,
                  thumbnail: true,
                  targetSize: const Size(100, 100),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byIcon(Icons.movie_outlined).evaluate().isNotEmpty) break;
      }
    });

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
    expect(store.getFileKeys, isEmpty);
  });

  // The movie tile asserts something specific: this video simply has no
  // poster frame. Two other ways store resolution can return null must not be
  // dressed up as that, or an unreachable video reads as an intact one.
  MediaItem videoRow({
    required String id,
    required String hash,
    DateTime? uploadedAt,
    DateTime? thumbUploadedAt,
  }) => MediaItem(
    id: id,
    mediaType: MediaType.video,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-from-other-device',
    originalFilename: 'DIVE_003.mp4',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
    remoteThumbUploadedAt: thumbUploadedAt,
  );

  Widget videoApp(MediaItem item, {MediaStoreRuntime? runtime}) =>
      ProviderScope(
        overrides: [
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery:
                  const _UnavailableGalleryResolver(),
            }),
          ),
          mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: const Size(100, 100),
              ),
            ),
          ),
        ),
      );

  testWidgets('a video with no store attached keeps the native '
      'placeholder', (tester) async {
    await tester.runAsync(() async {
      // The row says it is uploaded, but this device has no store to reach:
      // the bytes are genuinely unavailable here, not merely poster-less.
      await tester.pumpWidget(
        videoApp(
          videoRow(
            id: 'v-no-runtime',
            hash: 'b8${'1' * 62}',
            uploadedAt: DateTime(2026, 7, 1),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(UnavailableMediaPlaceholder).evaluate().isNotEmpty) {
          break;
        }
      }
    });

    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
  });

  testWidgets('a poster that fails to download keeps the native '
      'placeholder', (tester) async {
    await tester.runAsync(() async {
      final hash = 'b9${'0' * 62}';
      // Stamped as uploaded, but the object is absent from the store, so the
      // fetch fails. That is an error, not an absence of poster.
      final runtime = MediaStoreRuntime(
        storeId: 'store-1',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
      );

      await tester.pumpWidget(
        videoApp(
          videoRow(
            id: 'v-thumb-fails',
            hash: hash,
            uploadedAt: DateTime(2026, 7, 1),
            thumbUploadedAt: DateTime(2026, 7, 1),
          ),
          runtime: runtime,
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(UnavailableMediaPlaceholder).evaluate().isNotEmpty) {
          break;
        }
      }
    });

    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
  });

  testWidgets('keeps the native placeholder when no store runtime '
      'exists', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(galleryItem(hash: 'a' * 64)));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(UnavailableMediaPlaceholder).evaluate().isNotEmpty) {
          break;
        }
      }
    });

    expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
