import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/local_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

class _BlobBookmarkStorage extends LocalBookmarkStorage {
  _BlobBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async =>
      Uint8List.fromList(ref.codeUnits);
}

class _CountingPlatform implements LocalMediaPlatform {
  _CountingPlatform(this._bytes);

  final Uint8List _bytes;
  int bookmarkReads = 0;

  @override
  Future<Uint8List> readBookmarkBytes(Uint8List bookmarkBlob) async {
    bookmarkReads++;
    return _bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Gallery thumbnails for local photo files come from the disk cache before
/// the original is touched (issue #3337).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCacheDatabase db;
  late Directory root;
  late Directory photos;
  late LocalThumbnailCache thumbnails;
  late List<(String, VerifyResult)> verdicts;
  late Completer<void> verdictArrived;
  late List<String> dropped;
  late LocalFileResolver resolver;

  const tile = Size(200, 200);

  LocalFileResolver build({
    LocalThumbnailCache? cache,
    LocalMediaPlatform? platform,
    bool bookmarks = false,
  }) {
    final built = LocalFileResolver(
      bookmarkStorage: _BlobBookmarkStorage(),
      platform: platform ?? _CountingPlatform(Uint8List(0)),
      usesSecurityScopedBookmarks: () => bookmarks,
      readsContentUris: () => false,
      thumbnails: cache,
      onOriginChecked: (item, verdict) async {
        verdicts.add((item.id, verdict));
        if (!verdictArrived.isCompleted) verdictArrived.complete();
      },
      onThumbnailDropped: (item) async => dropped.add(item.id),
    );
    addTearDown(built.dispose);
    return built;
  }

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('lfr_thumb_cache');
    photos = await Directory.systemTemp.createTemp('lfr_thumb_photos');
    final store = MediaCacheStore(database: db, root: root);
    thumbnails = LocalThumbnailCache(store: () async => store);
    verdicts = [];
    dropped = [];
    verdictArrived = Completer<void>();
    resolver = build(cache: thumbnails);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    await photos.delete(recursive: true);
  });

  File writePng(String name, {int width = 1600, int height = 1200}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(20, 80, 140));
    return File(p.join(photos.path, name))
      ..writeAsBytesSync(img.encodePng(image));
  }

  MediaItem item(
    File? file, {
    String id = 'm1',
    MediaType mediaType = MediaType.photo,
    String? bookmarkRef,
    bool isOrphaned = false,
  }) => MediaItem(
    id: id,
    mediaType: mediaType,
    sourceType: MediaSourceType.localFile,
    originalFilename: file == null ? 'reef.png' : p.basename(file.path),
    localPath: file?.path,
    bookmarkRef: bookmarkRef,
    isOrphaned: isOrphaned,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  bool inThumbPool(File file) =>
      p.isWithin(p.join(root.path, 'thumbs'), file.path);

  Future<void> waitForVerdict() =>
      verdictArrived.future.timeout(const Duration(seconds: 5));

  test('the first request makes the thumbnail and serves it', () async {
    final source = writePng('reef.png');

    final data = await resolver.resolveThumbnail(item(source), target: tile);

    expect(data, isA<FileData>());
    final file = (data as FileData).file;
    expect(inThumbPool(file), isTrue);
    expect(data.servedTier, ServedTier.thumbnail);
    expect(data.servedFrom, ServedFrom.localDisk);
    expect(
      data.originUntouched,
      isFalse,
      reason: 'the original was just read, so it is known to be there',
    );
    final decoded = img.decodeJpg(file.readAsBytesSync())!;
    expect(decoded.width, 512);
  });

  test('every gallery size gets the same 512px thumbnail', () async {
    final source = writePng('reef.png');

    final small = await resolver.resolveThumbnail(item(source), target: tile);
    final large = await resolver.resolveThumbnail(
      item(source),
      target: const Size(800, 800),
    );

    expect((large as FileData).file.path, (small as FileData).file.path);
  });

  test('a later request is served from the cache without the original, and '
      'says so', () async {
    final source = writePng('reef.png');
    final first = await resolver.resolveThumbnail(item(source), target: tile);
    source.deleteSync();

    final again = await resolver.resolveThumbnail(item(source), target: tile);

    expect(again, isA<FileData>());
    expect((again as FileData).file.path, (first as FileData).file.path);
    expect(again.servedTier, ServedTier.thumbnail);
    expect(again.originUntouched, isTrue);
  });

  test('the viewer still gets the original', () async {
    final source = writePng('reef.png');
    await resolver.resolveThumbnail(item(source), target: tile);

    final full = await resolver.resolve(item(source));

    expect((full as FileData).file.path, source.path);
    expect(full.servedTier, ServedTier.original);
  });

  group('the deferred check on the original', () {
    test('reports a file that has gone, once', () async {
      final source = writePng('reef.png');
      await resolver.resolveThumbnail(item(source), target: tile);
      source.deleteSync();

      await resolver.resolveThumbnail(item(source), target: tile);
      await waitForVerdict();
      await resolver.resolveThumbnail(item(source), target: tile);
      await resolver.resolveThumbnail(item(source), target: tile);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(verdicts, [('m1', VerifyResult.notFound)]);
    });

    test('reports a file that is still there', () async {
      final source = writePng('reef.png');
      await resolver.resolveThumbnail(item(source), target: tile);

      await resolver.resolveThumbnail(item(source), target: tile);
      await waitForVerdict();

      expect(verdicts, [('m1', VerifyResult.available)]);
    });

    test('does not run when the thumbnail was only just made', () async {
      final source = writePng('reef.png');

      await resolver.resolveThumbnail(item(source), target: tile);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(verdicts, isEmpty);
    });

    test('drops the thumbnail of a file changed since it was made', () async {
      final source = writePng('reef.png');
      final media = item(source);
      await resolver.resolveThumbnail(media, target: tile);
      source.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));

      await resolver.resolveThumbnail(media, target: tile);
      await waitForVerdict();
      // The eviction follows the verdict on the same deferred task.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await thumbnails.cached(media), isNull);
      // So the stale decode of the old thumbnail leaves memory with it.
      expect(dropped, ['m1']);
    });

    test('does not report a drop for an unchanged file', () async {
      final source = writePng('reef.png');
      await resolver.resolveThumbnail(item(source), target: tile);

      await resolver.resolveThumbnail(item(source), target: tile);
      await waitForVerdict();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(dropped, isEmpty);
    });
  });

  group('an orphaned row', () {
    test('is checked against its original, so a file put back is noticed, '
        'and keeps the thumbnail it has', () async {
      final source = writePng('reef.png');
      final first =
          await resolver.resolveThumbnail(item(source), target: tile)
              as FileData;
      final madeAt = DateTime(2026, 1, 1);
      first.file.setLastModifiedSync(madeAt);

      final served = await resolver.resolveThumbnail(
        item(source, isOrphaned: true),
        target: tile,
      );

      expect(served, isA<FileData>());
      expect((served as FileData).originUntouched, isFalse);
      expect(served.file.path, first.file.path);
      expect(
        served.file.lastModifiedSync(),
        madeAt,
        reason: 'served as it was, not made again',
      );
    });

    test('whose file is still gone gets the missing-file answer, not the '
        'cached picture', () async {
      final source = writePng('reef.png');
      await resolver.resolveThumbnail(item(source), target: tile);
      source.deleteSync();

      final served = await resolver.resolveThumbnail(
        item(source, isOrphaned: true),
        target: tile,
      );

      expect(served, isA<UnavailableData>());
    });
  });

  test('a bookmarked file is read once, then served from the cache', () async {
    final bytes = writePng(
      'reef.png',
      width: 800,
      height: 600,
    ).readAsBytesSync();
    final platform = _CountingPlatform(bytes);
    final bookmarked = build(
      cache: thumbnails,
      platform: platform,
      bookmarks: true,
    );
    final media = item(null, bookmarkRef: 'bm1');

    final first = await bookmarked.resolveThumbnail(media, target: tile);
    final again = await bookmarked.resolveThumbnail(media, target: tile);

    expect(platform.bookmarkReads, 1);
    expect(inThumbPool((first as FileData).file), isTrue);
    expect((again as FileData).file.path, first.file.path);
  });

  test('a photo that cannot be decoded falls back to the original', () async {
    final junk = File(p.join(photos.path, 'junk.png'))
      ..writeAsBytesSync([1, 2, 3, 4]);

    final data = await resolver.resolveThumbnail(item(junk), target: tile);

    expect((data as FileData).file.path, junk.path);
    expect(data.servedTier, ServedTier.original);
  });

  test('a missing photo is still reported missing', () async {
    final gone = File(p.join(photos.path, 'gone.png'));

    final data = await resolver.resolveThumbnail(item(gone), target: tile);

    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('a video is not given a photo thumbnail', () async {
    final source = writePng('clip.mp4');

    final data = await resolver.resolveThumbnail(
      item(source, mediaType: MediaType.video),
      target: tile,
    );

    expect((data as FileData).file.path, source.path);
    expect(await thumbnails.cached(item(source)), isNull);
  });

  test('without a thumbnail cache the original is served as before', () async {
    final plain = build();
    final source = writePng('reef.png');

    final data = await plain.resolveThumbnail(item(source), target: tile);

    expect((data as FileData).file.path, source.path);
  });
}
