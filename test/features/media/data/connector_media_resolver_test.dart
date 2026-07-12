import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/connector_media_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

class _FakeRenditionApi extends LightroomApiClient {
  _FakeRenditionApi({required this.bytes, this.statusCode})
    : super(auth: AdobeImsAuthManager());

  final Uint8List bytes;
  final int? statusCode;
  int calls = 0;

  @override
  Future<Uint8List> getRendition({
    required String catalogId,
    required String assetId,
    required String size,
  }) async {
    calls++;
    final status = statusCode;
    if (status != null) {
      throw LightroomApiException(status, 'error $status');
    }
    return bytes;
  }
}

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cmr_test');
    cache = MediaCacheStore(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  ConnectorMediaResolver resolver(
    _FakeRenditionApi api, {
    bool hasAccount = true,
    MediaCacheStore? withCache,
  }) => ConnectorMediaResolver(
    hasLightroomAccount: hasAccount,
    apiClient: () async => api,
    catalogId: () async => 'cat1',
    cache: () async => withCache,
  );

  MediaItem item({String? contentHash, String? remoteAssetId = 'lr1'}) =>
      MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.serviceConnector,
        connectorAccountId: 'acct1',
        remoteAssetId: remoteAssetId,
        contentHash: contentHash,
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  test('declines on a device without the account', () async {
    final api = _FakeRenditionApi(bytes: jpeg);
    final r = resolver(api, hasAccount: false);
    expect(r.canResolveOnThisDevice(item()), isFalse);
    final data = await r.resolve(item());
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.signInRequired);
    expect(await r.verify(item()), VerifyResult.unauthenticated);
  });

  test('fresh download without contentHash returns bytes', () async {
    final api = _FakeRenditionApi(bytes: jpeg);
    final data = await resolver(api).resolve(item());
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, jpeg);
  });

  test('matching contentHash enters the cache; second resolve is a cache '
      'hit', () async {
    final api = _FakeRenditionApi(bytes: jpeg);
    // Hash of the rendition bytes, computed the same way the pipeline does.
    final staged = File('${root.path}/probe')..writeAsBytesSync(jpeg);
    final digest = await sha256OfFile(staged);

    final r = resolver(api, withCache: cache);
    final first = await r.resolve(item(contentHash: digest.hash));
    expect(first, isA<FileData>());
    expect(api.calls, 1);

    final second = await r.resolve(item(contentHash: digest.hash));
    expect(second, isA<FileData>());
    expect(api.calls, 1, reason: 'second resolve must hit the cache');
  });

  test(
    'hash mismatch degrades to bytes and does not poison the cache',
    () async {
      final api = _FakeRenditionApi(bytes: jpeg);
      final wrongHash = 'a' * 64;
      final r = resolver(api, withCache: cache);
      final data = await r.resolve(item(contentHash: wrongHash));
      expect(data, isA<BytesData>());
      expect(await cache.get(wrongHash, MediaCacheKind.original), isNull);
    },
  );

  test('thumbnail path caches under the thumb pool unverified', () async {
    final api = _FakeRenditionApi(bytes: jpeg);
    final hash = 'b' * 64;
    final r = resolver(api, withCache: cache);
    final data = await r.resolveThumbnail(
      item(contentHash: hash),
      target: const Size(200, 200),
    );
    expect(data, isA<FileData>());
    expect(await cache.get(hash, MediaCacheKind.thumb), isNotNull);
    expect(api.calls, 1);

    await r.resolveThumbnail(
      item(contentHash: hash),
      target: const Size(200, 200),
    );
    expect(api.calls, 1, reason: 'thumb re-resolve must hit the cache');
  });

  test('401 maps to unauthenticated, 500 to networkError', () async {
    final unauth = await resolver(
      _FakeRenditionApi(bytes: jpeg, statusCode: 401),
    ).resolve(item());
    expect((unauth as UnavailableData).kind, UnavailableKind.unauthenticated);

    final network = await resolver(
      _FakeRenditionApi(bytes: jpeg, statusCode: 500),
    ).resolve(item());
    expect((network as UnavailableData).kind, UnavailableKind.networkError);
  });
}
