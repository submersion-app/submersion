import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/connector_media_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cmr_prov');
    cache = MediaCacheStore(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  MediaItem item({String? contentHash}) => MediaItem(
    id: 'c1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.serviceConnector,
    remoteAssetId: 'asset-1',
    contentHash: contentHash,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('a signed-out connector resolution claims no source', () async {
    final resolver = ConnectorMediaResolver(
      hasLightroomAccount: false,
      apiClient: () async => null,
      catalogId: () async => null,
      cache: () async => null,
    );

    final data = await resolver.resolve(item());

    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.signInRequired);
    expect(data.servedFrom, isNull);
  });

  test('a cache hit is stamped connectorCache at the original tier', () async {
    const hash = 'abc123';
    final staging = await cache.stagingFile();
    await staging.writeAsBytes(const [1, 2, 3], flush: true);
    await cache.put(hash, MediaCacheKind.original, staging, extension: 'jpg');

    // apiClient stays null on purpose: a cache MISS would fall through to
    // signInRequired, so a FileData here can only mean the cache served it.
    final resolver = ConnectorMediaResolver(
      hasLightroomAccount: true,
      apiClient: () async => null,
      catalogId: () async => null,
      cache: () async => cache,
    );

    final data = await resolver.resolve(item(contentHash: hash));

    expect(data, isA<FileData>());
    expect(data.servedFrom, ServedFrom.connectorCache);
    expect(data.servedTier, ServedTier.original);
  });

  test('a thumb cache hit carries the thumbnail tier', () async {
    const hash = 'def456';
    final staging = await cache.stagingFile();
    await staging.writeAsBytes(const [4, 5, 6], flush: true);
    await cache.put(hash, MediaCacheKind.thumb, staging, extension: 'jpg');

    final resolver = ConnectorMediaResolver(
      hasLightroomAccount: true,
      apiClient: () async => null,
      catalogId: () async => null,
      cache: () async => cache,
    );

    final data = await resolver.resolveThumbnail(
      item(contentHash: hash),
      target: const Size(128, 128),
    );

    expect(data, isA<FileData>());
    expect(data.servedFrom, ServedFrom.connectorCache);
    expect(data.servedTier, ServedTier.thumbnail);
  });
}
