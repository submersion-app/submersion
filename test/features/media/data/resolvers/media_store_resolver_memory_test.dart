import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../../helpers/in_memory_media_object_store.dart';

/// A browser has no file to download into (issue #4121): its store
/// resolver serves what the store holds from memory, with the same tiers,
/// checks and fallbacks as the disk one.
void main() {
  final bytes = List<int>.generate(512, (i) => (i * 7) % 251);
  final hash = sha256.convert(bytes).toString();
  final at = DateTime(2026, 7, 1);
  late InMemoryMediaObjectStore store;
  late MediaStoreResolver resolver;

  setUp(() {
    store = InMemoryMediaObjectStore();
    resolver = MediaStoreResolver.inMemory(store: store);
  });

  tearDown(() => resolver.dispose());

  MediaItem item({
    MediaType mediaType = MediaType.photo,
    String filename = 'reef.jpg',
    DateTime? thumbAt,
    DateTime? originalAt,
    DateTime? renditionAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: MediaSourceType.localFile,
    localPath: p.join('elsewhere', filename),
    originalFilename: filename,
    contentHash: hash,
    remoteThumbUploadedAt: thumbAt,
    remoteUploadedAt: originalAt,
    remoteCompressedUploadedAt: renditionAt,
    takenAt: at,
    createdAt: at,
    updatedAt: at,
  );

  String originalKey([String filename = 'reef.jpg']) =>
      StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor(filename));

  test('a thumbnail is served from memory as bytes', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    final served = await resolver.tryResolveRemote(
      item(thumbAt: at),
      thumbnail: true,
    );

    expect(served, isA<BytesData>());
    final data = served! as BytesData;
    expect(data.bytes, bytes);
    expect(data.isPoster, isFalse);
    expect(data.servedTier, ServedTier.thumbnail);
    expect(data.servedFrom, ServedFrom.storeNetwork);
  });

  test("a video's thumbnail is flagged as its poster frame", () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    final served = await resolver.tryResolveRemote(
      item(mediaType: MediaType.video, filename: 'reef.mp4', thumbAt: at),
      thumbnail: true,
    );

    expect((served! as BytesData).isPoster, isTrue);
  });

  test('a photo original serves only when its bytes match the hash', () async {
    store.objects[originalKey()] = bytes;
    final served = await resolver.tryResolveRemote(
      item(originalAt: at),
      thumbnail: false,
    );
    expect((served! as BytesData).bytes, bytes);
    expect(served.servedTier, ServedTier.original);

    final other = MediaStoreResolver.inMemory(store: store);
    addTearDown(other.dispose);
    store.objects[originalKey()] = [1, 2, 3];
    expect(
      await other.tryResolveRemote(item(originalAt: at), thumbnail: false),
      isNull,
    );
  });

  test('a photo rendition is served from memory', () async {
    store.objects[StoreKeys.renditionKey(
          hash,
          ext: StoreKeys.renditionExtension(isVideo: false),
        )] =
        bytes;

    final served = await resolver.tryResolveRemote(
      item(renditionAt: at),
      thumbnail: false,
    );

    expect((served! as BytesData).servedTier, ServedTier.rendition);
  });

  test("a video's original and rendition are never downloaded into "
      'memory', () async {
    store.objects[originalKey('reef.mp4')] = bytes;
    store.objects[StoreKeys.renditionKey(
          hash,
          ext: StoreKeys.renditionExtension(isVideo: true),
        )] =
        bytes;

    final served = await resolver.tryResolveRemote(
      item(
        mediaType: MediaType.video,
        filename: 'reef.mp4',
        originalAt: at,
        renditionAt: at,
      ),
      thumbnail: false,
    );

    expect(served, isNull);
    expect(store.getBytesKeys, isEmpty);
  });

  test('a second ask is served from memory without another download', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    await resolver.tryResolveRemote(item(thumbAt: at), thumbnail: true);
    final again = await resolver.tryResolveRemote(
      item(thumbAt: at),
      thumbnail: true,
    );

    expect(store.getBytesKeys, hasLength(1));
    expect((again! as BytesData).servedFrom, ServedFrom.storeCache);
  });

  test('a failed download serves nothing', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;
    store.failNextWith = const MediaStoreException(
      'offline',
      kind: MediaStoreErrorKind.transient,
    );

    expect(
      await resolver.tryResolveRemote(item(thumbAt: at), thumbnail: true),
      isNull,
    );
  });

  test('an unstamped row is probed and served from memory', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    final served = await resolver.tryResolveProbed(item(), thumbnail: true);

    expect(served, isA<BytesData>());
  });
}
