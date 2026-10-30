import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/local_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/native_image_resize.dart';

/// The on-disk thumbnail of a local photo file (issue #3337): one 512px JPEG
/// in the media cache's thumbnail pool, found again without the original.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCacheDatabase db;
  late Directory root;
  late Directory photos;
  late MediaCacheStore store;
  late int writes;
  late LocalThumbnailCache cache;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('local_thumb_cache');
    photos = await Directory.systemTemp.createTemp('local_thumb_photos');
    store = MediaCacheStore(database: db, root: root);
    writes = 0;
    cache = LocalThumbnailCache(
      store: () async => store,
      write: (request) {
        writes++;
        return resizeToJpegFileNative(request);
      },
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    await photos.delete(recursive: true);
  });

  File writePng(String name, {int width = 2000, int height = 1000}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(20, 80, 140));
    return File(p.join(photos.path, name))
      ..writeAsBytesSync(img.encodePng(image));
  }

  MediaItem photo(
    File file, {
    String id = 'm1',
    String? bookmarkRef,
    String? hash,
  }) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: p.basename(file.path),
    localPath: file.path,
    bookmarkRef: bookmarkRef,
    contentHash: hash,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('keyFor', () {
    test('is 64 hex characters, the same for the same file', () {
      final file = File(p.join(photos.path, 'a.jpg'));
      final key = LocalThumbnailCache.keyFor(photo(file));
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(LocalThumbnailCache.keyFor(photo(file, id: 'other')), key);
    });

    test('differs by path and by bookmark', () {
      final a = photo(File(p.join(photos.path, 'a.jpg')));
      final b = photo(File(p.join(photos.path, 'b.jpg')));
      final aBookmarked = photo(
        File(p.join(photos.path, 'a.jpg')),
        bookmarkRef: 'bm1',
      );
      expect(
        LocalThumbnailCache.keyFor(a),
        isNot(LocalThumbnailCache.keyFor(b)),
      );
      expect(
        LocalThumbnailCache.keyFor(a),
        isNot(LocalThumbnailCache.keyFor(aBookmarked)),
      );
    });

    test('is not the content hash, so a store thumbnail fetched for another '
        "device's row is never mistaken for a local one", () {
      final hash = 'ab${'0' * 62}';
      final item = photo(File(p.join(photos.path, 'a.jpg')), hash: hash);
      expect(LocalThumbnailCache.keyFor(item), isNot(hash));
    });
  });

  test('nothing is cached before a thumbnail has been made', () async {
    expect(await cache.cached(photo(writePng('reef.png'))), isNull);
  });

  test('generate writes a 512px JPEG into the thumbnail pool', () async {
    final source = writePng('reef.png');
    final item = photo(source);

    final made = await cache.generate(item, file: source);

    expect(made, isNotNull);
    expect(p.isWithin(p.join(root.path, 'thumbs'), made!.path), isTrue);
    final decoded = img.decodeJpg(made.readAsBytesSync())!;
    expect(decoded.width, 512);
    expect(decoded.height, 256);
    expect(await store.totalBytes(MediaCacheKind.thumb), made.lengthSync());
    expect(source.existsSync(), isTrue, reason: 'the original is only read');
  });

  test('generate from bytes writes the same thumbnail', () async {
    final source = writePng('reef.png', width: 800, height: 600);
    final item = photo(source);

    final made = await cache.generate(item, bytes: source.readAsBytesSync());

    final decoded = img.decodeJpg(made!.readAsBytesSync())!;
    expect(decoded.width, 512);
    expect(decoded.height, 384);
  });

  test('a made thumbnail is served again without decoding, and without the '
      'original', () async {
    final source = writePng('reef.png');
    final item = photo(source);
    final made = await cache.generate(item, file: source);
    source.deleteSync();

    final hit = await cache.cached(item);

    expect(hit, isNotNull);
    expect(hit!.path, made!.path);
    expect(writes, 1);
  });

  test('requests for one file made together share one generation', () async {
    final source = writePng('reef.png');
    final item = photo(source);

    final results = await Future.wait([
      cache.generate(item, file: source),
      cache.generate(item, file: source),
      cache.generate(photo(source, id: 'm2'), file: source),
    ]);

    expect(writes, 1);
    expect(results.map((f) => f?.path).toSet(), hasLength(1));
  });

  test('no more than the limit are generated at once', () async {
    var running = 0;
    var peak = 0;
    final release = Completer<void>();
    final limited = LocalThumbnailCache(
      store: () async => store,
      maxConcurrent: 2,
      write: (request) async {
        running++;
        if (running > peak) peak = running;
        await release.future;
        running--;
        return resizeToJpegFileNative(request);
      },
    );
    final sources = [
      for (var i = 0; i < 5; i++) writePng('p$i.png', width: 40, height: 30),
    ];

    final all = Future.wait([
      for (final s in sources) limited.generate(photo(s), file: s),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(peak, 2);
    release.complete();
    final made = await all;

    expect(made.whereType<File>(), hasLength(5));
    expect(peak, 2);
  });

  test(
    'a waiting request asked for last goes first, so the tiles on screen '
    'after a fast scroll are not stuck behind the ones scrolled past',
    () async {
      final order = <String>[];
      final release = Completer<void>();
      final single = LocalThumbnailCache(
        store: () async => store,
        maxConcurrent: 1,
        write: (request) async {
          order.add(p.basenameWithoutExtension(request.sourcePath!));
          if (order.length == 1) await release.future;
          return resizeToJpegFileNative(request);
        },
      );
      final sources = [
        for (var i = 0; i < 4; i++) writePng('p$i.png', width: 40, height: 30),
      ];

      final all = <Future<File?>>[];
      for (final s in sources) {
        all.add(single.generate(photo(s), file: s));
        // Each request reaches the queue before the next is made.
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      release.complete();
      await Future.wait(all);

      expect(order, ['p0', 'p3', 'p2', 'p1']);
    },
  );

  test('a request for a file already waiting moves it to the front, so a '
      'tile scrolled back into view is not left behind its old place in '
      'the queue', () async {
    final order = <String>[];
    final release = Completer<void>();
    final single = LocalThumbnailCache(
      store: () async => store,
      maxConcurrent: 1,
      write: (request) async {
        order.add(p.basenameWithoutExtension(request.sourcePath!));
        if (order.length == 1) await release.future;
        return resizeToJpegFileNative(request);
      },
    );
    final sources = [
      for (var i = 0; i < 4; i++) writePng('p$i.png', width: 40, height: 30),
    ];

    final all = <Future<File?>>[];
    for (final s in sources) {
      all.add(single.generate(photo(s), file: s));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // p1 is asked for again: its tile is back on screen.
    all.add(single.generate(photo(sources[1]), file: sources[1]));
    release.complete();
    await Future.wait(all);

    expect(order, ['p0', 'p1', 'p3', 'p2']);
  });

  test('the original is fetched only once a slot is free, so waiting '
      'requests hold no file in memory', () async {
    final release = Completer<void>();
    final single = LocalThumbnailCache(
      store: () async => store,
      maxConcurrent: 1,
      write: (request) async {
        await release.future;
        return resizeToJpegFileNative(request);
      },
    );
    final first = writePng('p0.png', width: 40, height: 30);
    final second = writePng('p1.png', width: 40, height: 30);
    var loads = 0;

    final a = single.generateFrom(photo(first), () async {
      loads++;
      return (file: first, bytes: null);
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final b = single.generateFrom(photo(second), () async {
      loads++;
      return (file: null, bytes: second.readAsBytesSync());
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(loads, 1, reason: 'the second waits for its slot unloaded');
    release.complete();
    await Future.wait([a, b]);
    expect(loads, 2);
  });

  test('a loader with no original gives null', () async {
    final made = await cache.generateFrom(
      photo(File(p.join(photos.path, 'gone.png'))),
      () async => null,
    );

    expect(made, isNull);
    expect(writes, 0);
  });

  test(
    'a source that cannot be decoded gives null and writes nothing',
    () async {
      final junk = File(p.join(photos.path, 'junk.png'))
        ..writeAsBytesSync([1, 2, 3, 4]);
      final item = photo(junk);

      expect(await cache.generate(item, file: junk), isNull);
      expect(await cache.cached(item), isNull);
      expect(await store.totalBytes(MediaCacheKind.thumb), 0);
      final staging = Directory(p.join(root.path, 'staging'));
      expect(
        staging.existsSync() ? staging.listSync() : const <FileSystemEntity>[],
        isEmpty,
      );
    },
  );

  test('a cache that cannot be opened gives null, not an error', () async {
    final broken = LocalThumbnailCache(
      store: () async => throw StateError('no cache database'),
    );
    final source = writePng('reef.png', width: 40, height: 30);
    final item = photo(source);

    expect(await broken.cached(item), isNull);
    expect(await broken.generate(item, file: source), isNull);
    await broken.remove(item);
  });

  test('removePath deletes the thumbnail of the file at that path', () async {
    final source = writePng('reef.png', width: 40, height: 30);
    final item = photo(source);
    final made = await cache.generate(item, file: source);

    await cache.removePath(source.path);

    expect(made!.existsSync(), isFalse);
    expect(await cache.cached(item), isNull);
  });

  test('remove deletes the thumbnail', () async {
    final source = writePng('reef.png', width: 40, height: 30);
    final item = photo(source);
    final made = await cache.generate(item, file: source);

    await cache.remove(item);

    expect(made!.existsSync(), isFalse);
    expect(await cache.cached(item), isNull);
    expect(await store.totalBytes(MediaCacheKind.thumb), 0);
  });

  // The bug as it showed in the gallery: two neighbouring thumbnails the
  // same, the earlier wearing the later one's picture. Production builds a
  // store per use, as here.
  test('photos made at the same moment each get their own picture', () async {
    final perUse = LocalThumbnailCache(
      store: () async => MediaCacheStore(database: db, root: root),
      maxConcurrent: 8,
    );
    File solid(String name, int red) {
      final image = img.Image(width: 64, height: 48);
      img.fill(image, color: img.ColorRgb8(red, 0, 0));
      return File(p.join(photos.path, name))
        ..writeAsBytesSync(img.encodePng(image));
    }

    final reds = [for (var i = 0; i < 16; i++) i * 16];
    final sources = [for (final red in reds) solid('r$red.png', red)];

    final made = await Future.wait([
      for (final source in sources)
        perUse.generate(photo(source), file: source),
    ]);

    for (var i = 0; i < reds.length; i++) {
      expect(made[i], isNotNull, reason: 'photo $i has no thumbnail');
      final pixel = img.decodeJpg(made[i]!.readAsBytesSync())!.getPixel(32, 24);
      expect(
        pixel.r,
        closeTo(reds[i], 6),
        reason: 'photo $i is wearing another photo\'s picture',
      );
    }
  });

  test('thumbnails made before the staging fix are not served', () async {
    // They may hold the wrong picture, and nothing on disk says which.
    final source = writePng('reef.png', width: 40, height: 30);
    final item = photo(source);
    final legacyKey = sha256
        .convert(utf8.encode('local-thumb\u0000${source.path}\u0000'))
        .toString();
    final stale = await store.stagingFile();
    await stale.writeAsBytes([1, 2, 3], flush: true);
    await store.put(legacyKey, MediaCacheKind.thumb, stale, extension: 'jpg');

    expect(await cache.cached(item), isNull);
  });
}
