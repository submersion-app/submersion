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
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Stub that bypasses keychain I/O. Always returns null from [read].
class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async => null;
}

/// Bookmark storage stub that returns the provided [_blob] for any ref.
class _StubBookmarkStorage extends LocalBookmarkStorage {
  _StubBookmarkStorage(this._blob) : super(storage: null as dynamic);
  final Uint8List? _blob;

  @override
  Future<Uint8List?> read(String ref) async => _blob;
}

/// Platform stub for tests that need to control [readBookmarkBytes] and
/// [readUriBytes]. Override the relevant method per test.
class _StubPlatform implements LocalMediaPlatform {
  Future<Uint8List> Function(Uint8List)? onReadBookmarkBytes;
  Future<Uint8List> Function(String)? onReadUriBytes;

  @override
  Future<Uint8List> readBookmarkBytes(Uint8List bookmarkBlob) async {
    final h = onReadBookmarkBytes;
    if (h == null) {
      throw UnimplementedError('readBookmarkBytes not stubbed');
    }
    return h(bookmarkBlob);
  }

  @override
  Future<Uint8List> readUriBytes(String uri) async {
    final h = onReadUriBytes;
    if (h == null) {
      throw UnimplementedError('readUriBytes not stubbed');
    }
    return h(uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
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

  test(
    'extractMetadata over FileData returns metadata with mtime fallback',
    () async {
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([0]);
      final r = _resolver();
      final meta = await r.extractMetadata(_localFile(localPath: f.path));
      expect(meta, isNotNull);
      // Mtime fallback for files without parseable EXIF.
      expect(meta!.takenAt, isNotNull);
      expect(meta.mimeType, 'image/jpeg');
    },
  );

  test('verify returns available when file exists at localPath', () async {
    final f = File('${tempDir.path}/p.jpg')..writeAsBytesSync([0]);
    final r = _resolver();
    final v = await r.verify(_localFile(localPath: f.path));
    expect(v, VerifyResult.available);
  });

  test(
    'verify returns notFound when bookmarkRef present but resolves to null',
    () async {
      final r = _resolver();
      final v = await r.verify(_localFile(bookmarkRef: 'ref-x'));
      expect(v, VerifyResult.notFound);
    },
  );

  // The Android branch (Platform.isAndroid: readUriBytes) and the
  // iOS / macOS bookmark-bytes branch are exercised together via the
  // BytesData round-trip in extractMetadata. On macOS hosts the
  // bookmark-bytes branch fires; on Android hosts the URI-bytes branch
  // fires. Below we assert the iOS/macOS branch (the host this suite
  // runs on in dev / CI).
  test(
    'resolve returns BytesData via readBookmarkBytes on iOS/macOS hosts',
    () async {
      if (!Platform.isIOS && !Platform.isMacOS) return;
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async =>
            Uint8List.fromList([10, 20, 30]));
      final r = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
        exifExtractor: ExifExtractor(),
      );
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-1'));
      expect(data, isA<BytesData>());
      expect((data as BytesData).bytes, [10, 20, 30]);
    },
  );

  test(
    'resolve returns Unavailable when readBookmarkBytes throws (iOS/macOS)',
    () async {
      if (!Platform.isIOS && !Platform.isMacOS) return;
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async => throw 'boom');
      final r = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
        exifExtractor: ExifExtractor(),
      );
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-1'));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test(
    'extractMetadata over BytesData round-trips through a temp file (iOS/macOS)',
    () async {
      if (!Platform.isIOS && !Platform.isMacOS) return;
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async =>
            Uint8List.fromList([0, 1, 2, 3]));
      final r = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
        exifExtractor: ExifExtractor(),
      );
      final meta = await r.extractMetadata(_localFile(bookmarkRef: 'ref-1'));
      // BytesData branch writes a temp file, runs extractor, deletes — so we
      // expect a non-null metadata. Mtime fallback covers the takenAt field.
      expect(meta, isNotNull);
      expect(meta!.takenAt, isNotNull);
    },
  );

  test(
    'extractMetadata cleans up the temp file after BytesData run (iOS/macOS)',
    () async {
      if (!Platform.isIOS && !Platform.isMacOS) return;
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async =>
            Uint8List.fromList([0, 1, 2, 3]));
      final item = _localFile(bookmarkRef: 'ref-cleanup');
      final r = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
        exifExtractor: ExifExtractor(),
      );
      await r.extractMetadata(item);
      final tmp = File('${Directory.systemTemp.path}/exif_${item.id}.bin');
      expect(tmp.existsSync(), isFalse);
    },
  );
}
