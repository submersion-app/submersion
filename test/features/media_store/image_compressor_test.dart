import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'support/fake_local_file_resolver.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late ImageCompressor compressor;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('img_compress');
    cache = MediaCacheStore(database: db, root: root);
    compressor = ImageCompressor(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: FakeLocalFileResolver(),
      }),
      cache: cache,
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem photo() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'shot.png',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<File> stagedPng(int width, int height) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(
      img.encodePng(img.Image(width: width, height: height)),
      flush: true,
    );
    return f;
  }

  test('downsizes a large image to the level ceiling and emits jpg', () async {
    final result = await compressor.compress(
      photo(),
      await stagedPng(4000, 3000),
      MediaUploadQuality.balanced,
    );
    expect(result, isNotNull);
    expect(result!.ext, 'jpg');
    final decoded = img.decodeJpg(await result.file.readAsBytes())!;
    expect(decoded.width, 2048); // balanced ceiling, aspect preserved
  });

  test(
    'returns null (upload original) when already under the ceiling',
    () async {
      final result = await compressor.compress(
        photo(),
        await stagedPng(800, 600),
        MediaUploadQuality.balanced,
      );
      expect(result, isNull);
    },
  );

  test('original level never compresses', () async {
    final result = await compressor.compress(
      photo(),
      await stagedPng(4000, 3000),
      MediaUploadQuality.original,
    );
    expect(result, isNull);
  });

  group('gallery ceiling rule', () {
    late FakeLocalFileResolver galleryResolver;
    late ImageCompressor galleryCompressor;

    setUp(() {
      // Registered under the platformGallery key; its resolveThumbnail serves
      // a real JPEG, so WITHOUT the ceiling short-circuit an under-cap photo
      // would still get a (lossy) rendition -- this is what makes the test
      // below discriminating.
      galleryResolver = FakeLocalFileResolver(
        BytesData(bytes: img.encodeJpg(img.Image(width: 64, height: 64))),
      );
      galleryCompressor = ImageCompressor(
        registry: MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: galleryResolver,
        }),
        cache: cache,
      );
    });

    MediaItem galleryPhoto({int? width, int? height}) => MediaItem(
      id: 'g1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      originalFilename: 'IMG_0001.HEIC',
      width: width,
      height: height,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('under-ceiling gallery photo uploads the original', () async {
      final result = await galleryCompressor.compress(
        galleryPhoto(width: 1600, height: 1200),
        await stagedPng(1600, 1200),
        MediaUploadQuality.balanced, // 2048 cap
      );
      expect(result, isNull, reason: 'known dims below cap: no re-encode');
    });

    test('over-ceiling gallery photo still renders a rendition', () async {
      final result = await galleryCompressor.compress(
        galleryPhoto(width: 5000, height: 4000),
        await stagedPng(5000, 4000),
        MediaUploadQuality.balanced,
      );
      expect(result, isNotNull);
      expect(result!.ext, 'jpg');
    });

    test('unknown dimensions fall through to the thumbnail path', () async {
      final result = await galleryCompressor.compress(
        galleryPhoto(),
        await stagedPng(1600, 1200),
        MediaUploadQuality.balanced,
      );
      expect(result, isNotNull, reason: 'cannot prove under cap: compress');
    });
  });
}
