import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

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

/// Resolver pinned to the security-scoped-bookmark branch (the iOS / macOS
/// path) on any host. The unit shards run on Linux, so without this the
/// bookmark branch — the only one that can resolve a sandboxed file — would
/// never execute in CI.
LocalFileResolver _bookmarkResolver({
  required LocalBookmarkStorage bookmarkStorage,
  required LocalMediaPlatform platform,
}) => LocalFileResolver(
  bookmarkStorage: bookmarkStorage,
  platform: platform,
  exifExtractor: ExifExtractor(),
  usesSecurityScopedBookmarks: () => true,
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
      // Pinned to the bookmark branch so the missing-blob path (and its
      // diagnostic warning) executes on every host, not just Apple ones.
      final r = _bookmarkResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
      );
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-123'));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test(
    'resolve falls through to Unavailable on a host without bookmarks',
    () async {
      // The default predicate on a non-Apple host: the bookmark branch is
      // skipped entirely and resolve() exits at the final return.
      final r = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: _StubPlatform(),
        exifExtractor: ExifExtractor(),
        usesSecurityScopedBookmarks: () => false,
      );
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-123'));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
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

  // The security-scoped-bookmark branch (iOS / macOS in production). These
  // pin the branch via `usesSecurityScopedBookmarks` rather than gating on
  // the host, so they run on the Linux unit shards too. The Android
  // URI-bytes branch stays host-gated — it needs a real Android runtime.
  test(
    'resolve returns BytesData via readBookmarkBytes on the bookmark branch',
    () async {
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async =>
            Uint8List.fromList([10, 20, 30]));
      final r = _bookmarkResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
      );
      final data = await r.resolve(_localFile(bookmarkRef: 'ref-1'));
      expect(data, isA<BytesData>());
      expect((data as BytesData).bytes, [10, 20, 30]);
    },
  );

  test('resolve returns Unavailable when readBookmarkBytes throws', () async {
    final platform = _StubPlatform()
      ..onReadBookmarkBytes = ((blob) async => throw 'boom');
    final r = _bookmarkResolver(
      bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
      platform: platform,
    );
    final data = await r.resolve(_localFile(bookmarkRef: 'ref-1'));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test(
    'extractMetadata over BytesData round-trips through a temp file',
    () async {
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = ((blob) async =>
            Uint8List.fromList([0, 1, 2, 3]));
      final r = _bookmarkResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
        platform: platform,
      );
      final meta = await r.extractMetadata(_localFile(bookmarkRef: 'ref-1'));
      // BytesData branch writes a temp file, runs extractor, deletes — so we
      // expect a non-null metadata. Mtime fallback covers the takenAt field.
      expect(meta, isNotNull);
      expect(meta!.takenAt, isNotNull);
    },
  );

  test('extractMetadata cleans up the temp file after BytesData run', () async {
    final platform = _StubPlatform()
      ..onReadBookmarkBytes = ((blob) async =>
          Uint8List.fromList([0, 1, 2, 3]));
    final item = _localFile(bookmarkRef: 'ref-cleanup');
    final r = _bookmarkResolver(
      bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
      platform: platform,
    );
    await r.extractMetadata(item);
    final tmp = File('${Directory.systemTemp.path}/exif_${item.id}.bin');
    expect(tmp.existsSync(), isFalse);
  });
  // Regression: a sandboxed macOS build can STAT a user file (~/Downloads)
  // but not OPEN it — File.exists() returns true while any read throws
  // EPERM. The resolver must probe readability, not existence, before
  // taking the direct-file fast path; otherwise it returns FileData that
  // Image.file can never load and the working security-scoped bookmark is
  // never consulted. chmod 000 reproduces the same exists-but-unreadable
  // split without a sandbox, on both macOS and Linux (CI runs the unit
  // shards on ubuntu, so guarding these on macOS alone would mean the
  // regression is never exercised in CI).
  group('exists-but-unreadable localPath (sandbox)', () {
    /// Creates a file at [path] that exists but cannot be opened, or returns
    /// null when this environment cannot produce that state — Windows has no
    /// chmod semantics, and chmod cannot deny root, so a root test runner
    /// (some CI containers) would silently get a readable file and fail for
    /// the wrong reason. Callers skip in that case.
    Future<File?> unreadableFile(String path) async {
      if (Platform.isWindows) {
        markTestSkipped('chmod permission semantics are POSIX-only');
        return null;
      }
      final f = File(path)..writeAsBytesSync([1, 2, 3]);
      final chmod = await Process.run('chmod', ['000', f.path]);
      expect(chmod.exitCode, 0, reason: 'chmod 000 failed: ${chmod.stderr}');
      addTearDown(() => Process.run('chmod', ['644', f.path]));
      // Confirm the state we actually need, rather than assuming chmod
      // implies it.
      try {
        await (await f.open()).close();
        markTestSkipped('running as root: chmod cannot deny read access');
        return null;
      } on FileSystemException {
        return f;
      }
    }

    test(
      'resolve falls back to the bookmark when localPath is unreadable',
      () async {
        final f = await unreadableFile('${tempDir.path}/locked.jpg');
        if (f == null) return;

        final platform = _StubPlatform()
          ..onReadBookmarkBytes = ((blob) async =>
              Uint8List.fromList([10, 20, 30]));
        final r = _bookmarkResolver(
          bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2])),
          platform: platform,
        );
        final data = await r.resolve(
          _localFile(localPath: f.path, bookmarkRef: 'ref-1'),
        );
        expect(data, isA<BytesData>());
        expect((data as BytesData).bytes, [10, 20, 30]);
      },
    );

    test(
      'resolve reads unreadable localPath as Unavailable when no bookmark',
      () async {
        final f = await unreadableFile('${tempDir.path}/locked2.jpg');
        if (f == null) return;

        final r = _resolver();
        final data = await r.resolve(_localFile(localPath: f.path));
        expect(data, isA<UnavailableData>());
        expect((data as UnavailableData).kind, UnavailableKind.notFound);
      },
    );

    // The bytes are still on disk, so the re-verify sweep must not flag the
    // row "missing from device" — that state is sticky and misleading, and a
    // re-granted permission restores the file with no user action.
    test('verify reports transientError (not notFound) for a present but '
        'unreadable file', () async {
      final f = await unreadableFile('${tempDir.path}/locked3.jpg');
      if (f == null) return;

      final r = _resolver();
      expect(
        await r.verify(_localFile(localPath: f.path)),
        VerifyResult.transientError,
      );
    });

    test('verify still reports notFound for a genuinely absent file', () async {
      final r = _resolver();
      expect(
        await r.verify(_localFile(localPath: '${tempDir.path}/gone.jpg')),
        VerifyResult.notFound,
      );
    });
  });

  group('volume awareness', () {
    LocalFileResolver volumeResolver({required bool volumeOnline}) =>
        LocalFileResolver(
          bookmarkStorage: _NullBookmarkStorage(),
          platform: LocalMediaPlatform(),
          exifExtractor: ExifExtractor(),
          volumeStatus: VolumeStatus(
            directoryExists: (_) async => volumeOnline,
          ),
        );

    // A path shaped like a macOS network mount whose file is absent. With
    // the volume offline the row must read volumeOffline, not notFound.
    const nasPath = '/Volumes/NAS/photos/missing.jpg';

    test(
      'missing file on an unmounted volume reads volumeOffline',
      () async {
        final r = volumeResolver(volumeOnline: false);
        final data = await r.resolve(_localFile(localPath: nasPath));
        expect(data, isA<UnavailableData>());
        expect((data as UnavailableData).kind, UnavailableKind.volumeOffline);
        expect(
          await r.verify(_localFile(localPath: nasPath)),
          VerifyResult.volumeOffline,
        );
      },
      skip: !Platform.isMacOS ? 'macOS volume-root heuristics' : null,
    );

    test(
      'missing file on a mounted volume stays notFound',
      () async {
        final r = volumeResolver(volumeOnline: true);
        final data = await r.resolve(_localFile(localPath: nasPath));
        expect(data, isA<UnavailableData>());
        expect((data as UnavailableData).kind, UnavailableKind.notFound);
        expect(
          await r.verify(_localFile(localPath: nasPath)),
          VerifyResult.notFound,
        );
      },
      skip: !Platform.isMacOS ? 'macOS volume-root heuristics' : null,
    );
  });
}
