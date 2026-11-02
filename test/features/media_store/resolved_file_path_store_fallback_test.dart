import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late ProviderContainer container;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('rfp_fallback');
    store = InMemoryMediaObjectStore();
    final cache = MediaCacheStore(database: db, root: root);
    final runtime = MediaStoreRuntime(
      storeId: 's1',
      store: store,
      cache: cache,
      resolver: MediaStoreResolver(store: store, cache: cache),
    );
    container = ProviderContainer(
      overrides: [
        mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem videoItem({required String hash, String? localPath}) => MediaItem(
    id: 'v1',
    mediaType: MediaType.video,
    sourceType: MediaSourceType.localFile,
    localPath: localPath,
    originalFilename: 'dive.mp4',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: DateTime(2026, 7, 1),
  );

  test('existing localPath wins without touching the store', () async {
    final local = File('${root.path}/here.mp4')..writeAsBytesSync([1, 2]);
    final path = await container.read(
      resolvedFilePathProvider(
        videoItem(hash: 'a' * 64, localPath: local.path),
      ).future,
    );
    expect(path, local.path);
    expect(store.objects, isEmpty);
  });

  test('dead localPath falls back to the store and returns playable '
      'bytes', () async {
    final bytes = List<int>.generate(4096, (i) => (i * 5) % 251);
    final seed = File('${root.path}/seed.mp4')..writeAsBytesSync(bytes);
    final digest = await sha256OfFile(seed);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'mp4')] = bytes;

    final path = await container.read(
      resolvedFilePathProvider(
        videoItem(
          hash: digest.hash,
          localPath: '/nonexistent/on/this/device.mp4',
        ),
      ).future,
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), bytes);
    // Playable is not just "the right bytes": video_player hands this path
    // to a bare AVURLAsset, which infers the container from the extension
    // and fails with -11828 "Cannot Open" without one. Verified against
    // AVFoundation: identical bytes load at clip.mp4 and fail at an
    // extensionless path.
    expect(p.extension(path), '.mp4');
  });

  /// An item whose original is only in the store, plus that original's bytes.
  Future<(MediaItem, List<int>)> videoOnlyInStore() async {
    final bytes = List<int>.generate(4096, (i) => (i * 5) % 251);
    final seed = File(p.join(root.path, 'seed.mp4'))..writeAsBytesSync(bytes);
    final digest = await sha256OfFile(seed);
    await seed.delete();
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'mp4')] = bytes;
    return (
      videoItem(
        hash: digest.hash,
        localPath: '/nonexistent/on/this/device.mp4',
      ),
      bytes,
    );
  }

  /// Reads the path as a viewer opening the video does, then lets the
  /// provider dispose, which is always done by the time anything reopens it.
  Future<String?> open(MediaItem item) async {
    final path = await container.read(resolvedFilePathProvider(item).future);
    await Future<void>.delayed(Duration.zero);
    return path;
  }

  test('an original the OS purged is fetched again on the next read', () async {
    final (item, bytes) = await videoOnlyInStore();
    final first = await open(item);
    expect(File(first!).existsSync(), isTrue);

    // Android's "Clear cache" takes the whole tree with the app still alive.
    for (final entry in root.listSync()) {
      entry.deleteSync(recursive: true);
    }

    final second = await open(item);
    expect(await File(second!).readAsBytes(), bytes);
    expect(store.getFileKeys, hasLength(2));
  });

  test('an original missed while offline is found on the next read', () async {
    final (item, bytes) = await videoOnlyInStore();
    store.failNextWith = Exception('offline');
    expect(await open(item), isNull);

    final path = await open(item);
    expect(await File(path!).readAsBytes(), bytes);
  });

  test('a slow gallery lookup outlives the read that started it', () async {
    final lookup = Completer<ResolutionResult>();
    final gallery = ProviderContainer(
      overrides: [
        assetResolutionServiceProvider.overrideWithValue(
          _GalleryLookup(lookup.future),
        ),
        photoPickerServiceProvider.overrideWithValue(_GalleryFiles()),
      ],
    );
    addTearDown(gallery.dispose);

    final reading = gallery.read(
      resolvedFilePathProvider(
        videoItem(hash: 'c' * 64).copyWith(platformAssetId: 'asset-1'),
      ).future,
    );
    // A read holds no listener, so Riverpod would dispose an unheld provider
    // here, and the lookup's return would find its ref unusable.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    lookup.complete(
      const ResolutionResult(
        localAssetId: 'asset-1',
        status: ResolutionStatus.resolved,
      ),
    );

    expect(await reading, '/gallery/asset-1.mp4');
  });

  testWidgets('a running app asks again each time it opens a video', (
    tester,
  ) async {
    final files = _GalleryFiles();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetResolutionServiceProvider.overrideWithValue(
            _GalleryLookup(
              Future.value(
                const ResolutionResult(
                  localAssetId: 'asset-1',
                  status: ResolutionStatus.resolved,
                ),
              ),
            ),
          ),
          photoPickerServiceProvider.overrideWithValue(files),
        ],
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    );
    final item = videoItem(hash: 'd' * 64).copyWith(platformAssetId: 'asset-1');

    expect(await ref.read(resolvedFilePathProvider(item).future), isNotNull);
    await tester.pump();
    expect(await ref.read(resolvedFilePathProvider(item).future), isNotNull);

    expect(files.lookups, 2);
  });

  test('no store and no local file yields null', () async {
    final bare = ProviderContainer(
      overrides: [mediaStoreRuntimeProvider.overrideWith((ref) async => null)],
    );
    addTearDown(bare.dispose);
    final path = await bare.read(
      resolvedFilePathProvider(
        videoItem(hash: 'b' * 64, localPath: '/nope.mp4'),
      ).future,
    );
    expect(path, isNull);
  });
}

class _GalleryLookup extends Fake implements AssetResolutionService {
  _GalleryLookup(this.result);

  final Future<ResolutionResult> result;

  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) => result;
}

class _GalleryFiles extends Fake implements PhotoPickerService {
  int lookups = 0;

  @override
  Future<String?> getFilePath(String assetId) async {
    lookups++;
    return '/gallery/$assetId.mp4';
  }
}
