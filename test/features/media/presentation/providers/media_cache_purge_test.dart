import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/local_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_cache_purge.dart';
import 'package:submersion/features/media/presentation/providers/media_tile_image_memo.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Unlinking a photo removes it from the library, so its cached copies go
/// with it: the thumbnail on disk and the decoded images in memory
/// (issue #3337).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCacheDatabase db;
  late Directory root;
  late Directory photos;
  late MediaCacheStore store;
  late LocalThumbnailCache thumbnails;
  late MediaTileImageMemo memo;
  late ui.Image image;
  final imageCache = PaintingBinding.instance.imageCache;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('cache_purge');
    photos = await Directory.systemTemp.createTemp('cache_purge_photos');
    store = MediaCacheStore(database: db, root: root);
    thumbnails = LocalThumbnailCache(store: () async => store);
    memo = MediaTileImageMemo();
    image = await createTestImage(width: 4, height: 4);
  });

  tearDown(() async {
    imageCache
      ..clear()
      ..clearLiveImages();
    image.dispose();
    await db.close();
    await root.delete(recursive: true);
    await photos.delete(recursive: true);
  });

  File writePng(String name) {
    final picture = img.Image(width: 40, height: 30);
    img.fill(picture, color: img.ColorRgb8(20, 80, 140));
    return File(p.join(photos.path, name))
      ..writeAsBytesSync(img.encodePng(picture));
  }

  MediaItem photo(String id, File file, {String? hash}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: p.basename(file.path),
    localPath: file.path,
    contentHash: hash,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// Makes [item]'s thumbnail and puts its decoded image in memory, as a
  /// gallery that has shown the tile would have.
  Future<(File, Object)> shown(MediaItem item, File source) async {
    final thumb = (await thumbnails.generate(item, file: source))!;
    memo.remember(item, thumbnail: true, cacheWidth: 200, file: thumb);
    final key = await MediaTileImageMemo.providerFor(
      thumb,
      200,
    ).obtainKey(ImageConfiguration.empty);
    imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image.clone())),
      ),
    );
    return (thumb, key);
  }

  Future<File> storeCopy(String hash, MediaCacheKind kind) async {
    final staged = await store.stagingFile();
    await staged.writeAsBytes([1, 2, 3], flush: true);
    return store.put(hash, kind, staged, extension: 'jpg');
  }

  test('removes the thumbnail from disk and the decoded image from memory, '
      'leaving other photos and the original alone', () async {
    final sourceA = writePng('a.png');
    final sourceB = writePng('b.png');
    final a = photo('a', sourceA);
    final b = photo('b', sourceB);
    final (thumbA, keyA) = await shown(a, sourceA);
    final (thumbB, keyB) = await shown(b, sourceB);

    await purgeMediaCaches([a], thumbnails: thumbnails, memo: memo);

    expect(thumbA.existsSync(), isFalse);
    expect(await thumbnails.cached(a), isNull);
    expect(imageCache.containsKey(keyA), isFalse);
    expect(thumbB.existsSync(), isTrue);
    expect(imageCache.containsKey(keyB), isTrue);
    expect(sourceA.existsSync(), isTrue);
  });

  test('removes copies fetched from the media store once no row uses the '
      'content any more', () async {
    final hash = 'ab${'1' * 62}';
    final source = writePng('a.png');
    final a = photo('a', source, hash: hash);
    final thumb = await storeCopy(hash, MediaCacheKind.thumb);
    final original = await storeCopy(hash, MediaCacheKind.original);
    final rendition = await storeCopy(hash, MediaCacheKind.rendition);

    await purgeMediaCaches(
      [a],
      thumbnails: thumbnails,
      memo: memo,
      store: () async => store,
      hashStillReferenced: (_) async => false,
    );

    expect(thumb.existsSync(), isFalse);
    expect(original.existsSync(), isFalse);
    expect(rendition.existsSync(), isFalse);
  });

  test('keeps store copies another row still uses', () async {
    final hash = 'cd${'2' * 62}';
    final a = photo('a', writePng('a.png'), hash: hash);
    final original = await storeCopy(hash, MediaCacheKind.original);

    await purgeMediaCaches(
      [a],
      thumbnails: thumbnails,
      memo: memo,
      store: () async => store,
      hashStillReferenced: (_) async => true,
    );

    expect(original.existsSync(), isTrue);
  });

  test('never throws: a cache that cannot be reached is skipped', () async {
    final a = photo('a', writePng('a.png'), hash: 'ef${'3' * 62}');

    await purgeMediaCaches(
      [a],
      thumbnails: LocalThumbnailCache(
        store: () async => throw StateError('no cache database'),
      ),
      memo: memo,
      store: () async => throw StateError('no cache database'),
      hashStillReferenced: (_) async => throw StateError('no database'),
    );
  });
}
