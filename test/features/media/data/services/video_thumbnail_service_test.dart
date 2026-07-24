import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class _FakePlatform implements LocalMediaPlatform {
  Uint8List? toReturn;
  int calls = 0;
  Map<String, Object?>? lastArgs;

  @override
  Future<Uint8List?> generateVideoThumbnail({
    String? path,
    Uint8List? bookmarkBlob,
    required int maxDimension,
  }) async {
    calls++;
    lastArgs = {'path': path, 'blob': bookmarkBlob, 'max': maxDimension};
    return toReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookmarkStorage implements LocalBookmarkStorage {
  Uint8List? blob;
  Object? throwOnRead;
  @override
  Future<Uint8List?> read(String ref) async {
    final err = throwOnRead;
    if (err != null) throw err;
    return blob;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _videoItem({String? localPath, String? bookmarkRef}) => MediaItem(
  id: 'm1',
  filePath: localPath,
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2025, 1, 1),
  createdAt: DateTime.utc(2025, 1, 1),
  updatedAt: DateTime.utc(2025, 1, 1),
  sourceType: MediaSourceType.localFile,
  localPath: localPath,
  bookmarkRef: bookmarkRef,
);

void main() {
  late Directory tmp;
  late _FakePlatform platform;
  late _FakeBookmarkStorage bookmarks;
  late VideoThumbnailService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vts_test');
    platform = _FakePlatform();
    bookmarks = _FakeBookmarkStorage();
    service = VideoThumbnailService(
      platform: platform,
      bookmarkStorage: bookmarks,
      cacheDir: () async => Directory('${tmp.path}/cache'),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> makeVideoFile() async {
    final f = File('${tmp.path}/clip.mp4');
    await f.writeAsBytes(List<int>.filled(1024, 7));
    return f;
  }

  test('generates, caches, and returns bytes on a miss', () async {
    final f = await makeVideoFile();
    platform.toReturn = Uint8List.fromList([9, 9, 9]);

    final bytes = await service.posterFor(_videoItem(localPath: f.path));

    expect(bytes, isNotNull);
    expect(bytes!.toList(), [9, 9, 9]);
    expect(platform.calls, 1);
  });

  test(
    'second call is served from cache without calling the platform',
    () async {
      final f = await makeVideoFile();
      platform.toReturn = Uint8List.fromList([9, 9, 9]);

      await service.posterFor(_videoItem(localPath: f.path));
      platform.toReturn = Uint8List.fromList([1]); // would differ if re-called
      final second = await service.posterFor(_videoItem(localPath: f.path));

      expect(platform.calls, 1); // still 1: cache hit
      expect(second!.toList(), [9, 9, 9]);
    },
  );

  test(
    'returns null (no cache write) when the platform returns null',
    () async {
      final f = await makeVideoFile();
      platform.toReturn = null;

      final bytes = await service.posterFor(_videoItem(localPath: f.path));

      expect(bytes, isNull);
      // A subsequent call still hits the platform (nothing was cached).
      await service.posterFor(_videoItem(localPath: f.path));
      expect(platform.calls, 2);
    },
  );

  test('passes the bookmark blob when the item has a bookmarkRef', () async {
    final f = await makeVideoFile();
    bookmarks.blob = Uint8List.fromList([5, 5]);
    platform.toReturn = Uint8List.fromList([9]);

    await service.posterFor(
      _videoItem(localPath: f.path, bookmarkRef: 'ref-1'),
    );

    expect(platform.lastArgs!['blob'], isNotNull);
  });

  test('still generates when the bookmark read throws', () async {
    // LocalBookmarkStorage.read base64-decodes the stored value (FormatException
    // on a corrupt/legacy entry) after a secure-storage read that can raise a
    // PlatformException (e.g. a macOS keychain error). Neither may escape into
    // grid rendering; the null blob just lets native try the plain path.
    final f = await makeVideoFile();
    bookmarks.throwOnRead = const FormatException('bad base64');
    platform.toReturn = Uint8List.fromList([7, 7]);

    final bytes = await service.posterFor(
      _videoItem(localPath: f.path, bookmarkRef: 'ref-1'),
    );

    expect(bytes, isNotNull);
    expect(bytes!.toList(), [7, 7]);
    expect(platform.calls, 1);
    expect(platform.lastArgs!['blob'], isNull);
  });

  test(
    'propagates null when the bookmark read throws and native fails',
    () async {
      final f = await makeVideoFile();
      bookmarks.throwOnRead = Exception('keychain unavailable');
      platform.toReturn = null;

      final bytes = await service.posterFor(
        _videoItem(localPath: f.path, bookmarkRef: 'ref-1'),
      );

      expect(bytes, isNull);
    },
  );

  test('still generates when the cache directory cannot be resolved', () async {
    // getApplicationSupportDirectory() can throw (MissingPluginException on
    // a platform without path_provider, PlatformException otherwise). That
    // must not escape into grid rendering: caching degrades, posters do not.
    final f = await makeVideoFile();
    platform.toReturn = Uint8List.fromList([4, 2]);
    final failing = VideoThumbnailService(
      platform: platform,
      bookmarkStorage: bookmarks,
      cacheDir: () async => throw Exception('no support dir'),
    );

    final bytes = await failing.posterFor(_videoItem(localPath: f.path));

    expect(bytes, isNotNull);
    expect(bytes!.toList(), [4, 2]);
    expect(platform.calls, 1);
  });

  test('returns null when the item has no readable path', () async {
    final bytes = await service.posterFor(_videoItem(localPath: null));
    expect(bytes, isNull);
    expect(platform.calls, 0);
  });

  test('cacheKeyFor changes with mtime, size, and dimension', () {
    final base = VideoThumbnailService.cacheKeyFor(
      path: '/a.mp4',
      mtimeMs: 1,
      sizeBytes: 2,
      maxDimension: 512,
    );
    expect(
      base,
      isNot(
        VideoThumbnailService.cacheKeyFor(
          path: '/a.mp4',
          mtimeMs: 9,
          sizeBytes: 2,
          maxDimension: 512,
        ),
      ),
    );
    expect(
      base,
      isNot(
        VideoThumbnailService.cacheKeyFor(
          path: '/a.mp4',
          mtimeMs: 1,
          sizeBytes: 9,
          maxDimension: 512,
        ),
      ),
    );
    expect(
      base,
      isNot(
        VideoThumbnailService.cacheKeyFor(
          path: '/a.mp4',
          mtimeMs: 1,
          sizeBytes: 2,
          maxDimension: 256,
        ),
      ),
    );
  });
}
