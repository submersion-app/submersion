import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/media_fetch_gate.dart';
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

/// Bookmark storage that turns a ref into distinct bytes, so two rows with
/// different bookmarks are distinguishable in the result.
class _EchoBookmarkStorage extends LocalBookmarkStorage {
  _EchoBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async =>
      Uint8List.fromList(ref.codeUnits);
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

    test('missing file on an unmounted volume reads volumeOffline', () async {
      final r = volumeResolver(volumeOnline: false);
      final data = await r.resolve(_localFile(localPath: nasPath));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.volumeOffline);
      expect(
        await r.verify(_localFile(localPath: nasPath)),
        VerifyResult.volumeOffline,
      );
    }, skip: !Platform.isMacOS ? 'macOS volume-root heuristics' : null);

    test('missing file on a mounted volume stays notFound', () async {
      final r = volumeResolver(volumeOnline: true);
      final data = await r.resolve(_localFile(localPath: nasPath));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
      expect(
        await r.verify(_localFile(localPath: nasPath)),
        VerifyResult.notFound,
      );
    }, skip: !Platform.isMacOS ? 'macOS volume-root heuristics' : null);
  });

  group('the volume probe runs before the file is touched (#1182)', () {
    /// Builds a resolver whose every path is treated as living on one mount
    /// root, so the volume branch is exercised on any host rather than only
    /// on macOS, and counts the probes it makes.
    ({LocalFileResolver resolver, List<String> probes}) mountedResolver({
      required bool online,
      Duration ttl = kVolumeProbeTtl,
      DateTime Function()? clock,
    }) {
      final probes = <String>[];
      return (
        resolver: LocalFileResolver(
          bookmarkStorage: _NullBookmarkStorage(),
          platform: LocalMediaPlatform(),
          exifExtractor: ExifExtractor(),
          volumeStatus: _FakeMountVolumeStatus(
            directoryExists: (path) async {
              probes.add(path);
              return online;
            },
          ),
          volumeProbeTtl: ttl,
          clock: clock,
        ),
        probes: probes,
      );
    }

    test('an offline volume answers without ever touching the file', () async {
      // The file genuinely EXISTS and is readable. Before #1182 the resolver
      // stat'd it first and returned FileData, only consulting the volume
      // afterwards -- which is why a dead share cost a stat per grid tile
      // before anything could short-circuit. Reaching volumeOffline here is
      // only possible if the probe now runs first.
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = mountedResolver(online: false);

      final data = await r.resolver.resolve(_localFile(localPath: f.path));

      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.volumeOffline);
      expect(r.probes, hasLength(1));
    });

    test('an online volume falls straight through to the file', () async {
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = mountedResolver(online: true);

      final data = await r.resolver.resolve(_localFile(localPath: f.path));

      expect(data, isA<FileData>());
      expect((data as FileData).file.path, f.path);
    });

    test(
      'a screenful of tiles on one dead mount costs a single probe',
      () async {
        final r = mountedResolver(online: false);

        // 60 tiles, which is what a 140 px grid puts on screen on desktop.
        // Distinct paths so the fetch gate cannot be what collapses them --
        // this is the volume memo's job.
        final results = await Future.wait([
          for (var i = 0; i < 60; i++)
            r.resolver.resolve(
              _localFile(localPath: '${tempDir.path}/missing$i.jpg'),
            ),
        ]);

        expect(r.probes, hasLength(1));
        expect(
          results.every(
            (d) =>
                d is UnavailableData && d.kind == UnavailableKind.volumeOffline,
          ),
          isTrue,
        );
      },
    );

    test('the memo expires, so a remount is picked up', () async {
      var clock = DateTime(2026, 8, 19, 12);
      var online = false;
      final probes = <String>[];
      final r = LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        volumeStatus: _FakeMountVolumeStatus(
          directoryExists: (path) async {
            probes.add(path);
            return online;
          },
        ),
        volumeProbeTtl: const Duration(seconds: 5),
        clock: () => clock,
      );
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);

      expect(
        await r.resolve(_localFile(localPath: f.path)),
        isA<UnavailableData>(),
      );

      online = true;
      clock = clock.add(const Duration(seconds: 5));
      // The resolver is a long-lived singleton, so without a real expiry the
      // library would stay marked offline for the life of the process after
      // the user plugged the share back in.
      expect(await r.resolve(_localFile(localPath: f.path)), isA<FileData>());
      expect(probes, hasLength(2));
    });

    test('a path on the system volume is never probed at all', () async {
      final probes = <String>[];
      final r = LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        // The REAL volume-root heuristics: a temp path lives on the system
        // volume on every platform the app ships to.
        volumeStatus: VolumeStatus(
          directoryExists: (path) async {
            probes.add(path);
            return false;
          },
        ),
      );
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);

      expect(await r.resolve(_localFile(localPath: f.path)), isA<FileData>());
      // An all-internal-disk library must pay nothing for any of this.
      expect(probes, isEmpty);
    });

    test('a probe that throws falls through to the file rather than '
        'guessing offline', () async {
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        volumeStatus: _FakeMountVolumeStatus(
          directoryExists: (_) async =>
              throw const FileSystemException('probe blew up'),
        ),
      );

      // The file is right there; a failed probe must not turn it into an
      // offline volume.
      expect(await r.resolve(_localFile(localPath: f.path)), isA<FileData>());
    });
  });

  group('resolution is gated (#1182)', () {
    LocalFileResolver gatedBookmarkResolver({
      required MediaFetchGate gate,
      required LocalMediaPlatform platform,
    }) => LocalFileResolver(
      bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([9])),
      platform: platform,
      exifExtractor: ExifExtractor(),
      gate: gate,
      usesSecurityScopedBookmarks: () => true,
    );

    test('concurrent resolutions are capped', () async {
      final release = Completer<void>();
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = (_) async {
          await release.future;
          return Uint8List.fromList([1]);
        };
      final gate = MediaFetchGate(maxConcurrent: 2);
      final r = gatedBookmarkResolver(gate: gate, platform: platform);

      final all = [
        for (var i = 0; i < 5; i++)
          r.resolve(_localFile(bookmarkRef: 'ref-$i')),
      ];
      await Future<void>.delayed(Duration.zero);

      // Without the cap, a screenful of tiles on a hung mount opens one
      // filesystem operation per tile and starves the dart:io pool that
      // drift's SQLite shares.
      expect(gate.runningCount, 2);
      expect(gate.waitingCount, 3);

      release.complete();
      expect(await Future.wait(all), everyElement(isA<BytesData>()));
    });

    test('two rows pointing at one file share a single resolution', () async {
      var reads = 0;
      final release = Completer<void>();
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = (_) async {
          reads++;
          await release.future;
          return Uint8List.fromList([1]);
        };
      final r = gatedBookmarkResolver(
        gate: MediaFetchGate(maxConcurrent: 4),
        platform: platform,
      );

      // Media is reference-linked, so the same photo attached to two dives is
      // two rows with one pointer.
      final both = [
        r.resolve(_localFile(bookmarkRef: 'same-ref')),
        r.resolve(_localFile(bookmarkRef: 'same-ref')),
      ];
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait(both);

      expect(reads, 1);
    });

    test(
      'rows sharing a path but not a bookmark do NOT share a resolution',
      () async {
        final refs = <Uint8List>[];
        final release = Completer<void>();
        final platform = _StubPlatform()
          ..onReadBookmarkBytes = (blob) async {
            refs.add(blob);
            await release.future;
            return blob;
          };
        final r = LocalFileResolver(
          bookmarkStorage: _EchoBookmarkStorage(),
          platform: platform,
          exifExtractor: ExifExtractor(),
          gate: MediaFetchGate(maxConcurrent: 4),
          usesSecurityScopedBookmarks: () => true,
        );

        // A dead path both rows fall through, and two different bookmarks
        // behind it. Keyed on the path alone, the second row would be handed
        // the first row's bytes.
        final both = [
          r.resolve(
            MediaItem(
              id: 'one',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              localPath: '${tempDir.path}/gone.jpg',
              bookmarkRef: 'bookmark-one',
              takenAt: DateTime.utc(2024, 1, 1),
              createdAt: DateTime.utc(2024, 1, 1),
              updatedAt: DateTime.utc(2024, 1, 1),
            ),
          ),
          r.resolve(
            MediaItem(
              id: 'two',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              localPath: '${tempDir.path}/gone.jpg',
              bookmarkRef: 'bookmark-two',
              takenAt: DateTime.utc(2024, 1, 1),
              createdAt: DateTime.utc(2024, 1, 1),
              updatedAt: DateTime.utc(2024, 1, 1),
            ),
          ),
        ];
        await Future<void>.delayed(Duration.zero);
        release.complete();
        final results = await Future.wait(both);

        expect(refs, hasLength(2));
        expect(
          (results[0] as BytesData).bytes,
          isNot((results[1] as BytesData).bytes),
        );
      },
    );

    test('resolveThumbnail does not re-enter the gate', () async {
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = (_) async => Uint8List.fromList([1]);
      final r = gatedBookmarkResolver(
        // One slot. If resolveThumbnail took a slot of its own before
        // delegating to resolve, this would park forever on itself.
        gate: MediaFetchGate(maxConcurrent: 1),
        platform: platform,
      );

      final data = await r
          .resolveThumbnail(
            _localFile(bookmarkRef: 'ref'),
            target: const Size(128, 128),
          )
          .timeout(const Duration(seconds: 5));

      expect(data, isA<BytesData>());
    });

    test('verify does not re-enter the gate', () async {
      final platform = _StubPlatform()
        ..onReadBookmarkBytes = (_) async => Uint8List.fromList([1]);
      final r = gatedBookmarkResolver(
        gate: MediaFetchGate(maxConcurrent: 1),
        platform: platform,
      );

      expect(
        await r
            .verify(_localFile(bookmarkRef: 'ref'))
            .timeout(const Duration(seconds: 5)),
        VerifyResult.available,
      );
    });

    test('extractMetadata does not re-enter the gate', () async {
      final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        gate: MediaFetchGate(maxConcurrent: 1),
      );

      await r
          .extractMetadata(_localFile(localPath: f.path))
          .timeout(const Duration(seconds: 5));
    });
  });

  /// Only notFound and unauthenticated flip `MediaItem.isOrphaned`, so a slow
  /// share must never reach either. The gate answers stillFetching once a read
  /// outlives its budget, which is a statement about time, not about whether
  /// the file exists.
  group('verify does not orphan a row for being slow', () {
    test('a still-fetching read reports transientError', () async {
      final platform = _StubPlatform()
        // Never completes: the shape of a read against a hung-but-mounted
        // share, which is exactly what the budget exists to bound.
        ..onReadBookmarkBytes = ((_) => Completer<Uint8List>().future);

      final resolver = LocalFileResolver(
        bookmarkStorage: _StubBookmarkStorage(Uint8List.fromList([1, 2, 3])),
        platform: platform,
        exifExtractor: ExifExtractor(),
        usesSecurityScopedBookmarks: () => true,
        gate: MediaFetchGate(
          maxConcurrent: 1,
          slotBudget: Duration.zero,
          totalBudget: Duration.zero,
        ),
      );

      final data = await resolver
          .resolve(_localFile(bookmarkRef: 'ref'))
          .timeout(const Duration(seconds: 5));
      expect(
        (data as UnavailableData).kind,
        UnavailableKind.stillFetching,
        reason: 'precondition: the budget produced the state under test',
      );

      final result = await resolver
          .verify(_localFile(bookmarkRef: 'ref'))
          .timeout(const Duration(seconds: 5));
      expect(
        result,
        VerifyResult.transientError,
        reason: 'notFound here would flag a reachable file missing, stickily',
      );
    });
  });
}

/// A [VolumeStatus] that treats every path as living on one mount root.
///
/// The real heuristics are per-platform (`/Volumes/...`, a UNC path, a
/// non-`C:` drive letter), so tests written against them run on one host and
/// skip on the rest. Overriding the root makes the volume branch reachable
/// everywhere while leaving the probe itself -- the part under test -- real.
class _FakeMountVolumeStatus extends VolumeStatus {
  _FakeMountVolumeStatus({required super.directoryExists});

  @override
  String? volumeRootOf(String path, {String? platformOverride}) =>
      '/fake-mount-root';
}
