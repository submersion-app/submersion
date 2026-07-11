import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';

import 'support/fake_local_file_resolver.dart';

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late FakeLocalFileResolver resolver;
  late ThumbnailGenerator generator;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('thumb_gen_test');
    cache = MediaCacheStore(database: db, root: root);
    resolver = FakeLocalFileResolver();
    generator = ThumbnailGenerator(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: resolver,
        MediaSourceType.platformGallery: resolver,
      }),
      cache: cache,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem item({
    MediaSourceType sourceType = MediaSourceType.localFile,
    String originalFilename = 'reef.png',
  }) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    originalFilename: originalFilename,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test(
    'an extension-less filename falls back to the generic decoder',
    () async {
      final large = img.Image(width: 700, height: 500);
      img.fill(large, color: img.ColorRgb8(30, 90, 150));
      final src = File('${root.path}/noext');
      await src.writeAsBytes(img.encodePng(large), flush: true);
      resolver.data = FileData(file: src);

      final file = await generator.generateFor(item(originalFilename: 'noext'));
      expect(file, isNotNull);
      final decoded = img.decodeImage(await file!.readAsBytes())!;
      expect(decoded.width, 512);
    },
  );

  test('gallery BytesData passes through untouched (photo_manager thumbnails '
      'are already compressed)', () async {
    final bytes = base64Decode(_onePixelPngBase64);
    resolver.data = BytesData(bytes: bytes);
    final file = await generator.generateFor(
      item(sourceType: MediaSourceType.platformGallery),
    );
    expect(file, isNotNull);
    expect(await file!.readAsBytes(), bytes);
  });

  test('non-gallery BytesData is resized and re-encoded (bookmark reads '
      'return full originals with EXIF)', () async {
    final large = img.Image(width: 800, height: 600);
    img.fill(large, color: img.ColorRgb8(200, 60, 10));
    final original = img.encodePng(large);
    resolver.data = BytesData(bytes: original);

    final file = await generator.generateFor(item());
    expect(file, isNotNull);
    final produced = await file!.readAsBytes();
    expect(produced, isNot(equals(original)));
    expect(produced.take(2).toList(), [0xFF, 0xD8], reason: 'JPEG re-encode');
    final decoded = img.decodeImage(produced)!;
    expect(decoded.width, 512);
  });

  test('FileData full-size photos are resized to <=512 and re-encoded as '
      'JPEG', () async {
    final large = img.Image(width: 800, height: 600);
    img.fill(large, color: img.ColorRgb8(10, 60, 200));
    final src = File('${root.path}/large.png');
    await src.writeAsBytes(img.encodePng(large), flush: true);
    resolver.data = FileData(file: src);

    final file = await generator.generateFor(item());
    expect(file, isNotNull);
    final decoded = img.decodeImage(await file!.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, lessThanOrEqualTo(512));
    final head = await file.openRead(0, 2).first;
    expect(head, [0xFF, 0xD8]);
  });

  test('small images are not upscaled', () async {
    final small = img.Image(width: 64, height: 48);
    img.fill(small, color: img.ColorRgb8(0, 0, 0));
    final src = File('${root.path}/small.png');
    await src.writeAsBytes(img.encodePng(small), flush: true);
    resolver.data = FileData(file: src);

    final file = await generator.generateFor(item());
    final decoded = img.decodeImage(await file!.readAsBytes())!;
    expect(decoded.width, 64);
  });

  test('unavailable source and undecodable bytes yield null', () async {
    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);
    expect(await generator.generateFor(item()), isNull);

    final junk = File('${root.path}/junk.png')..writeAsBytesSync([1, 2, 3, 4]);
    resolver.data = FileData(file: junk);
    expect(await generator.generateFor(item()), isNull);
  });
}
