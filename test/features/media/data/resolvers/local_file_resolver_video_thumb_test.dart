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

MediaItem _video(String path) => MediaItem(
  id: 'm1',
  filePath: path,
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2025, 1, 1),
  createdAt: DateTime.utc(2025, 1, 1),
  updatedAt: DateTime.utc(2025, 1, 1),
  sourceType: MediaSourceType.localFile,
  localPath: path,
);

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('lfr_test'));
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  LocalFileResolver resolver(VideoThumbnailService thumbs) => LocalFileResolver(
    bookmarkStorage: LocalBookmarkStorage(),
    platform: LocalMediaPlatform(),
    exifExtractor: ExifExtractor(),
    videoThumbnails: thumbs,
  );

  test('video with a poster resolves to BytesData', () async {
    final f = File('${tmp.path}/clip.mp4');
    await f.writeAsBytes([1, 2, 3]);
    final r = resolver(_StubThumbs(Uint8List.fromList([8, 8])));

    final data = await r.resolveThumbnail(
      _video(f.path),
      target: const Size(200, 200),
    );

    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes.toList(), [8, 8]);
  });

  test('video without a poster falls back to FileData', () async {
    final f = File('${tmp.path}/clip.mp4');
    await f.writeAsBytes([1, 2, 3]);
    final r = resolver(_StubThumbs(null));

    final data = await r.resolveThumbnail(
      _video(f.path),
      target: const Size(200, 200),
    );

    expect(data, isA<FileData>());
  });
}
