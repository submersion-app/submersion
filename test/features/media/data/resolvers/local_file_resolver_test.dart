import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Stub that bypasses keychain I/O. Always returns null from [read].
class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async => null;
}

MediaItem _localFile({String? localPath, String? bookmarkRef}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: localPath,
  bookmarkRef: bookmarkRef,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

LocalFileResolver _resolver() => LocalFileResolver(
  bookmarkStorage: _NullBookmarkStorage(),
  platform: LocalMediaPlatform(),
  exifExtractor: ExifExtractor(),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_resolver_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('sourceType getter returns localFile', () {
    expect(_resolver().sourceType, MediaSourceType.localFile);
  });

  test(
    'resolve returns FileData when localPath points to existing file',
    () async {
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = _resolver();
      final data = await r.resolve(_localFile(localPath: f.path));
      expect(data, isA<FileData>());
      expect((data as FileData).file.path, f.path);
    },
  );

  test(
    'resolve returns Unavailable when both localPath and bookmarkRef null',
    () async {
      final r = _resolver();
      final data = await r.resolve(_localFile());
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test('resolve returns Unavailable when localPath file is missing', () async {
    final r = _resolver();
    final data = await r.resolve(
      _localFile(localPath: '${tempDir.path}/does_not_exist.jpg'),
    );
    expect(data, isA<UnavailableData>());
  });

  test(
    'resolve returns Unavailable when bookmarkRef present but storage returns null',
    () async {
      final r = _resolver();
      // Non-Android / non-iOS desktop host: bookmarkRef present but
      // _NullBookmarkStorage returns null -> UnavailableData.
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-123'));
      expect(data, isA<UnavailableData>());
    },
  );

  test('canResolveOnThisDevice always returns true', () {
    final r = _resolver();
    expect(r.canResolveOnThisDevice(_localFile()), isTrue);
  });

  test('resolveThumbnail delegates to resolve', () async {
    final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final r = _resolver();
    final data = await r.resolveThumbnail(
      _localFile(localPath: f.path),
      target: const Size(200, 200),
    );
    expect(data, isA<FileData>());
  });

  test('verify returns notFound when nothing to read', () async {
    final r = _resolver();
    final v = await r.verify(_localFile());
    expect(v.toString(), contains('notFound'));
  });

  test('verify returns available when file exists', () async {
    final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final r = _resolver();
    final v = await r.verify(_localFile(localPath: f.path));
    expect(v.toString(), contains('available'));
  });

  test('extractMetadata returns null when no file to read', () async {
    final r = _resolver();
    final meta = await r.extractMetadata(_localFile());
    expect(meta, isNull);
  });
}
