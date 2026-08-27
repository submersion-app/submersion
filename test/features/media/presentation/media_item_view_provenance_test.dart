import 'dart:async';
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
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../../helpers/in_memory_media_object_store.dart';

/// Valid 1x1 transparent PNG.
const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=';

/// Returns whatever it is handed, so a test can pin the stamp that reaches
/// the recorder without depending on any real source.
///
/// When [gate] is supplied, resolution parks on it until the test completes
/// it, which is how the disposal test gets a tile unmounted mid-resolution.
class _StubResolver implements MediaSourceResolver {
  const _StubResolver(this._data, {this.gate});

  final MediaSourceData _data;
  final Future<void>? gate;

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    if (gate != null) await gate;
    return _data;
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    if (gate != null) await gate;
    return _data;
  }

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaServingRecorder recorder;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('miv_prov_test');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    recorder = MediaServingRecorder();
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Widget app(
    MediaItem item, {
    required MediaSourceData nativeData,
    required bool thumbnail,
    MediaStoreRuntime? runtime,
    Future<void>? gate,
  }) => ProviderScope(
    overrides: [
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: _StubResolver(
            nativeData,
            gate: gate,
          ),
        }),
      ),
      mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
      mediaServingRecorderProvider.overrideWithValue(recorder),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: MediaItemView(item: item, thumbnail: thumbnail),
        ),
      ),
    ),
  );

  MediaItem galleryItem({String? hash}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-1',
    originalFilename: 'reef.png',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: hash == null ? null : DateTime(2026, 7, 1),
  );

  testWidgets('a thumbnail resolution records under the thumbnail key', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(_onePixelPngBase64);

      await tester.pumpWidget(
        app(
          galleryItem(),
          nativeData: BytesData(
            bytes: bytes,
            servedFrom: ServedFrom.platformGallery,
            servedTier: ServedTier.thumbnail,
          ),
          thumbnail: true,
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (recorder.lastFor('m1', thumbnail: true) != null) break;
      }

      final obs = recorder.lastFor('m1', thumbnail: true)!;
      expect(obs.servedFrom, ServedFrom.platformGallery);
      expect(obs.servedTier, ServedTier.thumbnail);
      expect(obs.storeFallbackUsed, isFalse);
      expect(obs.failure, isNull);
      // The original was never asked for, so it must have no observation.
      expect(recorder.lastFor('m1', thumbnail: false), isNull);
    });
  });

  testWidgets('a store fallback is recorded as such', (tester) async {
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
        app(
          galleryItem(hash: digest.hash),
          nativeData: const UnavailableData(kind: UnavailableKind.notFound),
          thumbnail: false,
          runtime: runtime,
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (recorder.lastFor('m1', thumbnail: false) != null) break;
      }

      final obs = recorder.lastFor('m1', thumbnail: false)!;
      expect(obs.servedFrom, ServedFrom.storeNetwork);
      expect(obs.servedTier, ServedTier.original);
      expect(obs.storeFallbackUsed, isTrue);
      expect(obs.failure, isNull);
    });
  });

  // Riverpod's WidgetRef.read throws StateError once the element is unmounted
  // (flutter_riverpod consumer.dart, read -> _assertNotDisposed). Recording
  // happens after the resolution await, so a tile scrolled out of a grid
  // mid-resolution reaches that read while disposed. Nothing awaits the
  // Future at that point either, so the throw would surface as an unhandled
  // async error rather than anything the FutureBuilder could render.
  testWidgets('a tile disposed mid-resolution does not record or throw', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final gate = Completer<void>();
      final bytes = base64Decode(_onePixelPngBase64);

      await tester.pumpWidget(
        app(
          galleryItem(),
          nativeData: BytesData(
            bytes: bytes,
            servedFrom: ServedFrom.platformGallery,
            servedTier: ServedTier.thumbnail,
          ),
          thumbnail: true,
          gate: gate.future,
        ),
      );
      await tester.pump();

      // Replace the tree, disposing the view while resolution is parked.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(recorder.lastFor('m1', thumbnail: true), isNull);
    });
  });

  testWidgets('an unresolvable item records its failure kind', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          // No contentHash, so storeConfirmed is false and the store is
          // never consulted.
          galleryItem(),
          nativeData: const UnavailableData(
            kind: UnavailableKind.volumeOffline,
          ),
          thumbnail: false,
        ),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (recorder.lastFor('m1', thumbnail: false) != null) break;
      }

      final obs = recorder.lastFor('m1', thumbnail: false)!;
      expect(obs.servedFrom, isNull);
      expect(obs.failure, UnavailableKind.volumeOffline);
      expect(obs.storeFallbackUsed, isFalse);
    });
  });
}
