import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_tile_image_memo.dart';

/// What lets a tile scrolling back into view paint on its first frame, and
/// what unlinking clears out of memory (issue #3337).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image image;
  final imageCache = PaintingBinding.instance.imageCache;

  setUpAll(() async {
    image = await createTestImage(width: 4, height: 4);
  });

  tearDownAll(() => image.dispose());

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  File fileNamed(String name) => File(p.join(Directory.systemTemp.path, name));

  MediaItem item(String id, {String? localPath}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: localPath ?? p.join(Directory.systemTemp.path, '$id.jpg'),
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// Puts a decoded image in the image cache under the key a tile showing
  /// [file] at [cacheWidth] uses.
  Future<Object> seed(File file, int cacheWidth) async {
    final key = await MediaTileImageMemo.providerFor(
      file,
      cacheWidth,
    ).obtainKey(ImageConfiguration.empty);
    imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image.clone())),
      ),
    );
    return key;
  }

  test('offers nothing for an item it has not seen', () {
    final memo = MediaTileImageMemo();
    expect(
      memo.cachedProvider(item('m1'), thumbnail: true, cacheWidth: 200),
      isNull,
    );
  });

  test('offers nothing when the decoded image has left memory', () {
    final memo = MediaTileImageMemo();
    memo.remember(
      item('m1'),
      thumbnail: true,
      cacheWidth: 200,
      file: fileNamed('t1.jpg'),
    );

    expect(
      memo.cachedProvider(item('m1'), thumbnail: true, cacheWidth: 200),
      isNull,
    );
  });

  test('offers the image provider while its decoded image is in '
      'memory', () async {
    final memo = MediaTileImageMemo();
    final file = fileNamed('t1.jpg');
    memo.remember(item('m1'), thumbnail: true, cacheWidth: 200, file: file);
    final key = await seed(file, 200);

    final provider = memo.cachedProvider(
      item('m1'),
      thumbnail: true,
      cacheWidth: 200,
    );

    expect(provider, isNotNull);
    expect(await provider!.obtainKey(ImageConfiguration.empty), key);
  });

  test('a different size, a full-size request or a re-pointed row is a '
      'miss', () async {
    final memo = MediaTileImageMemo();
    final file = fileNamed('t1.jpg');
    memo.remember(item('m1'), thumbnail: true, cacheWidth: 200, file: file);
    await seed(file, 200);

    expect(
      memo.cachedProvider(item('m1'), thumbnail: true, cacheWidth: 400),
      isNull,
    );
    expect(
      memo.cachedProvider(item('m1'), thumbnail: false, cacheWidth: 200),
      isNull,
    );
    expect(
      memo.cachedProvider(
        item('m1', localPath: p.join(Directory.systemTemp.path, 'moved.jpg')),
        thumbnail: true,
        cacheWidth: 200,
      ),
      isNull,
    );
  });

  test('evictItems takes the decoded images out of memory and forgets the '
      'items', () async {
    final memo = MediaTileImageMemo();
    final thumb = fileNamed('t1.jpg');
    final full = fileNamed('full1.jpg');
    final other = fileNamed('t2.jpg');
    memo.remember(item('m1'), thumbnail: true, cacheWidth: 200, file: thumb);
    memo.remember(item('m1'), thumbnail: false, cacheWidth: 2400, file: full);
    memo.remember(item('m2'), thumbnail: true, cacheWidth: 200, file: other);
    final thumbKey = await seed(thumb, 200);
    final fullKey = await seed(full, 2400);
    final otherKey = await seed(other, 200);

    await memo.evictItems(['m1']);

    expect(imageCache.containsKey(thumbKey), isFalse);
    expect(imageCache.containsKey(fullKey), isFalse);
    expect(imageCache.containsKey(otherKey), isTrue);
    expect(
      memo.cachedProvider(item('m1'), thumbnail: true, cacheWidth: 200),
      isNull,
    );
    expect(
      memo.cachedProvider(item('m2'), thumbnail: true, cacheWidth: 200),
      isNotNull,
    );
  });

  test('forgets the item seen longest ago past its limit', () async {
    final memo = MediaTileImageMemo(maxItems: 2);
    for (final id in ['m1', 'm2', 'm3']) {
      final file = fileNamed('$id.jpg');
      memo.remember(item(id), thumbnail: true, cacheWidth: 200, file: file);
      await seed(file, 200);
    }

    expect(
      memo.cachedProvider(item('m1'), thumbnail: true, cacheWidth: 200),
      isNull,
    );
    expect(
      memo.cachedProvider(item('m3'), thumbnail: true, cacheWidth: 200),
      isNotNull,
    );
  });
}
