import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
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
    db = LocalCacheDatabase(NativeDatabase.memory());
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
