import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Returns a fixed blob for any ref, so the security-scoped bookmark branch
/// can be reached without keychain I/O.
class _StubBookmarkStorage extends LocalBookmarkStorage {
  _StubBookmarkStorage(this._blob);
  final Uint8List? _blob;

  @override
  Future<Uint8List?> read(String ref) async => _blob;
}

class _StubPlatform implements LocalMediaPlatform {
  _StubPlatform(this._bytes);
  final Uint8List _bytes;

  @override
  Future<Uint8List> readBookmarkBytes(Uint8List bookmarkBlob) async => _bytes;

  @override
  Future<Uint8List> readUriBytes(String uri) async => _bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _StubThumbs extends VideoThumbnailService {
  _StubThumbs(this._bytes)
    : super(
        platform: LocalMediaPlatform(),
        bookmarkStorage: LocalBookmarkStorage(),
        cacheDir: () async => Directory.systemTemp,
      );
  final Uint8List? _bytes;

  @override
  Future<Uint8List?> posterFor(
    MediaItem item, {
    int maxDimension = 512,
  }) async => _bytes;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lfr_prov');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  MediaItem item({
    String? localPath,
    String? bookmarkRef,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: MediaSourceType.localFile,
    localPath: localPath,
    bookmarkRef: bookmarkRef,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('a readable local file is stamped localDisk at original tier', () async {
    final f = File('${dir.path}/reef.jpg');
    await f.writeAsBytes(const [1, 2, 3], flush: true);
    final resolver = LocalFileResolver(
      bookmarkStorage: LocalBookmarkStorage(),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
      usesSecurityScopedBookmarks: () => false,
    );

    final data = await resolver.resolve(item(localPath: f.path));

    expect(data, isA<FileData>());
    expect(data.servedFrom, ServedFrom.localDisk);
    expect(data.servedTier, ServedTier.original);
  });

  test('bookmark-read bytes are stamped localDisk', () async {
    final resolver = LocalFileResolver(
      bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList(const [9])),
      platform: _StubPlatform(Uint8List.fromList(const [4, 5, 6])),
      exifExtractor: ExifExtractor(),
      usesSecurityScopedBookmarks: () => true,
    );

    final data = await resolver.resolve(item(bookmarkRef: 'ref-1'));

    expect(data, isA<BytesData>());
    expect(data.servedFrom, ServedFrom.localDisk);
    expect(data.servedTier, ServedTier.original);
  });

  test('a video poster is stamped localDisk at thumbnail tier', () async {
    final f = File('${dir.path}/clip.mp4');
    await f.writeAsBytes(const [1, 2, 3], flush: true);
    final resolver = LocalFileResolver(
      bookmarkStorage: LocalBookmarkStorage(),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
      videoThumbnails: _StubThumbs(Uint8List.fromList(const [8, 8])),
      usesSecurityScopedBookmarks: () => false,
    );

    final data = await resolver.resolveThumbnail(
      item(localPath: f.path, mediaType: MediaType.video),
      target: const Size(128, 128),
    );

    expect(data, isA<BytesData>());
    expect(data.servedFrom, ServedFrom.localDisk);
    expect(data.servedTier, ServedTier.thumbnail);
  });

  test('an unresolvable item claims no source', () async {
    final resolver = LocalFileResolver(
      bookmarkStorage: LocalBookmarkStorage(),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
      usesSecurityScopedBookmarks: () => false,
    );

    final data = await resolver.resolve(item());

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });
}
