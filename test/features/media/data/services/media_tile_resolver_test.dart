import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';

/// Remote resolver whose answer the test scripts. Extends the real class so
/// the type the tile resolver consumes is the production one.
class _ScriptedRemote extends MediaStoreResolver {
  _ScriptedRemote({required super.store, required super.cache});
  MediaSourceData? answer;
  Object? throwWith;
  int calls = 0;

  @override
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    calls++;
    if (throwWith != null) throw throwWith!;
    return answer;
  }
}

MediaItem _item({
  String? contentHash,
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
  DateTime? remoteCompressedUploadedAt,
  MediaType mediaType = MediaType.photo,
}) => MediaItem(
  id: 'm1',
  mediaType: mediaType,
  sourceType: MediaSourceType.localFile,
  localPath: '/nowhere/reef.jpg',
  takenAt: DateTime(2026, 7, 1),
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
  contentHash: contentHash,
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  remoteCompressedUploadedAt: remoteCompressedUploadedAt,
);

void main() {
  late Directory root;
  late LocalCacheDatabase cacheDb;
  late _ScriptedRemote remote;
  late FakeLocalFileResolver native;
  late MediaTileResolver resolver;
  const target = Size(200, 200);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tile_resolver');
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    remote = _ScriptedRemote(
      store: InMemoryMediaObjectStore(),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    native = FakeLocalFileResolver();
    resolver = MediaTileResolver(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: native,
      }),
      remote: () async => remote,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
  });

  group('storeConfirmed', () {
    test('false without a content hash even when stamped', () {
      expect(
        storeConfirmed(
          _item(remoteUploadedAt: DateTime(2026)),
          thumbnail: false,
        ),
        isFalse,
      );
    });

    test('thumb stamp alone confirms a thumbnail request only', () {
      final item = _item(
        contentHash: 'abc',
        remoteThumbUploadedAt: DateTime(2026),
      );
      expect(storeConfirmed(item, thumbnail: true), isTrue);
      expect(storeConfirmed(item, thumbnail: false), isFalse);
    });

    test('compressed stamp confirms a full request', () {
      final item = _item(
        contentHash: 'abc',
        remoteCompressedUploadedAt: DateTime(2026),
      );
      expect(storeConfirmed(item, thumbnail: false), isTrue);
    });
  });

  group('resolve', () {
    test('native success never consults the store', () async {
      native.data = BytesData(bytes: Uint8List.fromList([1, 2, 3]));
      final r = await resolver.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<BytesData>());
      expect(r.storeFallbackUsed, isFalse);
      expect(r.nativeFailure, isNull);
      expect(remote.calls, 0);
    });

    test('unconfirmed row keeps the native placeholder untouched', () async {
      native.data = const UnavailableData(
        kind: UnavailableKind.fromOtherDevice,
      );
      final r = await resolver.resolve(
        _item(),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect((r.data as UnavailableData).kind, UnavailableKind.fromOtherDevice);
      expect(r.storeFallbackUsed, isFalse);
      expect(r.nativeFailure, UnavailableKind.fromOtherDevice);
      expect(remote.calls, 0);
    });

    test(
      'confirmed row served by the store keeps the native failure',
      () async {
        native.data = const UnavailableData(kind: UnavailableKind.notFound);
        remote.answer = BytesData(bytes: Uint8List.fromList([9]));
        final r = await resolver.resolve(
          _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
          thumbnail: false,
          thumbnailTarget: target,
        );
        expect(r.data, isA<BytesData>());
        expect(r.storeFallbackUsed, isTrue);
        expect(r.nativeFailure, UnavailableKind.notFound);
      },
    );

    test('no store on this device reports the fallback as attempted', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      final noStore = MediaTileResolver(
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: native,
        }),
        remote: () async => null,
      );
      final r = await noStore.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<UnavailableData>());
      expect(r.storeFallbackUsed, isTrue);
    });

    test('store throw keeps the native placeholder', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      remote.throwWith = StateError('boom');
      final r = await resolver.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<UnavailableData>());
      expect(r.storeFallbackUsed, isTrue);
      expect(r.nativeFailure, UnavailableKind.notFound);
    });

    test(
      'video thumbnail with no thumb stamp reports a missing poster',
      () async {
        native.data = const UnavailableData(kind: UnavailableKind.notFound);
        remote.answer = null;
        final r = await resolver.resolve(
          _item(
            contentHash: 'abc',
            remoteUploadedAt: DateTime(2026),
            mediaType: MediaType.video,
          ),
          thumbnail: true,
          thumbnailTarget: target,
        );
        expect(r.videoPosterMissing, isTrue);
        expect(r.storeFallbackUsed, isTrue);
      },
    );

    test(
      'a thumbnail request asks the native resolver for a thumbnail',
      () async {
        native.data = const UnavailableData(kind: UnavailableKind.notFound);
        native.thumbnailData = BytesData(bytes: Uint8List.fromList([4]));
        final r = await resolver.resolve(
          _item(),
          thumbnail: true,
          thumbnailTarget: target,
        );
        expect(r.data, isA<BytesData>());
        expect(native.resolvedThumbnailTargets, [target]);
        expect(native.resolvedFullSize, isEmpty);
      },
    );
  });
}
