# Local-file Video Thumbnails (Desktop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show OS-generated poster frames for local-file videos in the dive media grid on macOS, Windows, and Linux, matching how gallery videos already display.

**Architecture:** A new `generateVideoThumbnail` method on the existing `com.submersion.app/local_media` MethodChannel returns encoded poster bytes from the platform's native thumbnailer. A pure-Dart `VideoThumbnailService` adds a disk cache and orchestration; `LocalFileResolver.resolveThumbnail` returns the poster as `BytesData` for videos (falling back to the current raw-video `FileData` placeholder when generation is unavailable).

**Tech Stack:** Flutter/Dart, Riverpod, `package:crypto` (sha1 cache keys), `package:path`/`path_provider` (cache dir), Swift `QLThumbnailGenerator` (macOS), C++ `IShellItemImageFactory` (Windows), C + `ffmpegthumbnailer` subprocess (Linux).

## Global Constraints

- All Dart code must pass `dart format .` with no changes and `flutter analyze` clean (infos are fatal in CI).
- Anything displaying units must respect the active diver's unit settings. (N/A here — no units rendered.)
- No emojis in code/comments/docs.
- Poster max dimension default: `512` px (matches `ThumbnailGenerator.maxDimension`).
- Cache directory: `<getApplicationSupportDirectory()>/Submersion/video_thumbnails`.
- Native handlers return null (never throw) on unsupported platform, missing tool, or any failure; the channel wrapper maps `MissingPluginException`/`PlatformException`/null to a Dart `null`.
- Out of scope: iOS, Android (keep the existing placeholder).

---

## File Structure

- Create `lib/features/media/data/services/video_thumbnail_service.dart` — cache + orchestration (pure Dart).
- Modify `lib/features/media/data/services/local_media_platform.dart` — add `generateVideoThumbnail` channel wrapper.
- Modify `lib/features/media/data/resolvers/local_file_resolver.dart` — video branch in `resolveThumbnail`.
- Modify `lib/features/media/presentation/providers/media_resolver_providers.dart` — provide the service and inject it into the resolver.
- Create `test/features/media/data/services/video_thumbnail_service_test.dart`.
- Modify `test/features/media/data/resolvers/local_file_resolver_test.dart` (or create if absent).
- Modify `macos/Runner/LocalMediaHandler.swift` — `generateVideoThumbnail` case (QuickLook).
- Modify `windows/runner/flutter_window.cpp` (+ `.h`, + `CMakeLists.txt` link libs) — register the channel and implement it.
- Modify `linux/runner/my_application.cc` (+ `CMakeLists.txt`) — register the channel and implement it.

---

### Task 1: `generateVideoThumbnail` channel wrapper

**Files:**
- Modify: `lib/features/media/data/services/local_media_platform.dart`
- Test: `test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart` (create)

**Interfaces:**
- Produces: `Future<Uint8List?> LocalMediaPlatform.generateVideoThumbnail({String? path, Uint8List? bookmarkBlob, required int maxDimension})` — returns poster bytes, or null on any platform/channel failure.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.submersion.app/local_media');
  final platform = LocalMediaPlatform();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns bytes from the channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'generateVideoThumbnail');
      expect(call.arguments['maxDimension'], 512);
      return Uint8List.fromList([1, 2, 3]);
    });

    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNotNull);
    expect(bytes!.toList(), [1, 2, 3]);
  });

  test('returns null when the channel has no implementation', () async {
    // No mock handler installed -> MissingPluginException.
    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNull);
  });

  test('returns null when the channel throws a PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ERR');
    });
    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart`
Expected: FAIL — `generateVideoThumbnail` is not defined.

- [ ] **Step 3: Add the method**

Add to `LocalMediaPlatform` (in `local_media_platform.dart`), after `readUriBytes`:

```dart
  /// Desktop only (macOS / Windows / Linux). Asks the OS to generate a poster
  /// frame for a local video and returns encoded image bytes (JPEG/PNG), or
  /// null when the platform has no implementation, the native side fails, or
  /// no thumbnailer is available.
  ///
  /// Pass [path] for non-sandboxed platforms (Windows/Linux) and
  /// [bookmarkBlob] for sandboxed macOS (the native side resolves the bookmark
  /// and manages security-scoped access). Passing both is safe; the handler
  /// uses whichever it needs.
  Future<Uint8List?> generateVideoThumbnail({
    String? path,
    Uint8List? bookmarkBlob,
    required int maxDimension,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('generateVideoThumbnail', {
        'path': path,
        'bookmarkBlob': bookmarkBlob,
        'maxDimension': maxDimension,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/media/data/services/local_media_platform.dart test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart
flutter analyze lib/features/media/data/services/local_media_platform.dart
git add lib/features/media/data/services/local_media_platform.dart test/features/media/data/services/local_media_platform_generate_thumbnail_test.dart
git commit -m "feat(media): add generateVideoThumbnail channel wrapper"
```

---

### Task 2: `VideoThumbnailService` (cache + orchestration)

**Files:**
- Create: `lib/features/media/data/services/video_thumbnail_service.dart`
- Test: `test/features/media/data/services/video_thumbnail_service_test.dart`

**Interfaces:**
- Consumes: `LocalMediaPlatform.generateVideoThumbnail(...)` (Task 1); `LocalBookmarkStorage.read(String ref) -> Future<Uint8List?>`; `MediaItem` (`localPath`, `bookmarkRef`, `isVideo`).
- Produces:
  - `VideoThumbnailService({required LocalMediaPlatform platform, required LocalBookmarkStorage bookmarkStorage, required Future<Directory> Function() cacheDir})`
  - `Future<Uint8List?> posterFor(MediaItem item, {int maxDimension = 512})`
  - `@visibleForTesting static String cacheKeyFor({required String path, required int mtimeMs, required int sizeBytes, required int maxDimension})`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/media/data/services/video_thumbnail_service_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class _FakePlatform implements LocalMediaPlatform {
  Uint8List? toReturn;
  int calls = 0;
  Map<String, Object?>? lastArgs;

  @override
  Future<Uint8List?> generateVideoThumbnail({
    String? path,
    Uint8List? bookmarkBlob,
    required int maxDimension,
  }) async {
    calls++;
    lastArgs = {'path': path, 'blob': bookmarkBlob, 'max': maxDimension};
    return toReturn;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookmarkStorage implements LocalBookmarkStorage {
  Uint8List? blob;
  @override
  Future<Uint8List?> read(String ref) async => blob;
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _videoItem({String? localPath, String? bookmarkRef}) => MediaItem(
      id: 'm1',
      filePath: localPath,
      mediaType: MediaType.video,
      takenAt: DateTime.utc(2025, 1, 1),
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
      sourceType: MediaSourceType.localFile,
      localPath: localPath,
      bookmarkRef: bookmarkRef,
    );

void main() {
  late Directory tmp;
  late _FakePlatform platform;
  late _FakeBookmarkStorage bookmarks;
  late VideoThumbnailService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vts_test');
    platform = _FakePlatform();
    bookmarks = _FakeBookmarkStorage();
    service = VideoThumbnailService(
      platform: platform,
      bookmarkStorage: bookmarks,
      cacheDir: () async => Directory('${tmp.path}/cache'),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> makeVideoFile() async {
    final f = File('${tmp.path}/clip.mp4');
    await f.writeAsBytes(List<int>.filled(1024, 7));
    return f;
  }

  test('generates, caches, and returns bytes on a miss', () async {
    final f = await makeVideoFile();
    platform.toReturn = Uint8List.fromList([9, 9, 9]);

    final bytes = await service.posterFor(_videoItem(localPath: f.path));

    expect(bytes, isNotNull);
    expect(bytes!.toList(), [9, 9, 9]);
    expect(platform.calls, 1);
  });

  test('second call is served from cache without calling the platform',
      () async {
    final f = await makeVideoFile();
    platform.toReturn = Uint8List.fromList([9, 9, 9]);

    await service.posterFor(_videoItem(localPath: f.path));
    platform.toReturn = Uint8List.fromList([1]); // would differ if re-called
    final second = await service.posterFor(_videoItem(localPath: f.path));

    expect(platform.calls, 1); // still 1: cache hit
    expect(second!.toList(), [9, 9, 9]);
  });

  test('returns null (no cache write) when the platform returns null',
      () async {
    final f = await makeVideoFile();
    platform.toReturn = null;

    final bytes = await service.posterFor(_videoItem(localPath: f.path));

    expect(bytes, isNull);
    // A subsequent call still hits the platform (nothing was cached).
    await service.posterFor(_videoItem(localPath: f.path));
    expect(platform.calls, 2);
  });

  test('passes the bookmark blob when the item has a bookmarkRef', () async {
    final f = await makeVideoFile();
    bookmarks.blob = Uint8List.fromList([5, 5]);
    platform.toReturn = Uint8List.fromList([9]);

    await service.posterFor(
      _videoItem(localPath: f.path, bookmarkRef: 'ref-1'),
    );

    expect(platform.lastArgs!['blob'], isNotNull);
  });

  test('returns null when the item has no readable path', () async {
    final bytes = await service.posterFor(_videoItem(localPath: null));
    expect(bytes, isNull);
    expect(platform.calls, 0);
  });

  test('cacheKeyFor changes with mtime, size, and dimension', () {
    final base = VideoThumbnailService.cacheKeyFor(
        path: '/a.mp4', mtimeMs: 1, sizeBytes: 2, maxDimension: 512);
    expect(base,
        isNot(VideoThumbnailService.cacheKeyFor(
            path: '/a.mp4', mtimeMs: 9, sizeBytes: 2, maxDimension: 512)));
    expect(base,
        isNot(VideoThumbnailService.cacheKeyFor(
            path: '/a.mp4', mtimeMs: 1, sizeBytes: 9, maxDimension: 512)));
    expect(base,
        isNot(VideoThumbnailService.cacheKeyFor(
            path: '/a.mp4', mtimeMs: 1, sizeBytes: 2, maxDimension: 256)));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/services/video_thumbnail_service_test.dart`
Expected: FAIL — `VideoThumbnailService` is not defined.

- [ ] **Step 3: Implement the service**

```dart
// lib/features/media/data/services/video_thumbnail_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Produces and caches OS-generated poster frames for local-file videos.
///
/// On a cache miss it calls [LocalMediaPlatform.generateVideoThumbnail] and
/// stores the result on disk keyed by the source file's path + mtime + size +
/// requested dimension, so replacing the file (which changes its mtime) busts
/// the entry. Returns null when no poster can be produced, leaving the caller
/// to fall back to the raw-video placeholder.
class VideoThumbnailService {
  VideoThumbnailService({
    required LocalMediaPlatform platform,
    required LocalBookmarkStorage bookmarkStorage,
    required Future<Directory> Function() cacheDir,
  })  : _platform = platform,
        _bookmarkStorage = bookmarkStorage,
        _cacheDir = cacheDir;

  final LocalMediaPlatform _platform;
  final LocalBookmarkStorage _bookmarkStorage;
  final Future<Directory> Function() _cacheDir;
  Directory? _resolvedDir;

  Future<Uint8List?> posterFor(MediaItem item, {int maxDimension = 512}) async {
    final path = item.localPath;
    if (path == null || path.isEmpty) return null;

    // Best-effort stat for the cache key; a sandbox denial or missing file
    // just yields a coarser key (path + dimension only).
    int mtimeMs = 0;
    int sizeBytes = 0;
    try {
      final stat = File(path).statSync();
      mtimeMs = stat.modified.millisecondsSinceEpoch;
      sizeBytes = stat.size;
    } on FileSystemException {
      // Coarse key; native may still resolve via bookmark.
    }

    final key = cacheKeyFor(
      path: path,
      mtimeMs: mtimeMs,
      sizeBytes: sizeBytes,
      maxDimension: maxDimension,
    );

    final dir = _resolvedDir ??= await _cacheDir();
    final cacheFile = File(p.join(dir.path, '$key.jpg'));
    if (await cacheFile.exists()) {
      try {
        return await cacheFile.readAsBytes();
      } on FileSystemException {
        // Corrupt/unreadable cache entry: fall through and regenerate.
      }
    }

    Uint8List? blob;
    final ref = item.bookmarkRef;
    if (ref != null && ref.isNotEmpty) {
      blob = await _bookmarkStorage.read(ref);
    }

    final bytes = await _platform.generateVideoThumbnail(
      path: path,
      bookmarkBlob: blob,
      maxDimension: maxDimension,
    );
    if (bytes == null) return null;

    try {
      await dir.create(recursive: true);
      await cacheFile.writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      // Caching is best-effort; still return the freshly generated bytes.
    }
    return bytes;
  }

  @visibleForTesting
  static String cacheKeyFor({
    required String path,
    required int mtimeMs,
    required int sizeBytes,
    required int maxDimension,
  }) {
    final basis = '$path|$mtimeMs|$sizeBytes|$maxDimension';
    return sha1.convert(utf8.encode(basis)).toString();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/services/video_thumbnail_service_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/media/data/services/video_thumbnail_service.dart test/features/media/data/services/video_thumbnail_service_test.dart
flutter analyze lib/features/media/data/services/video_thumbnail_service.dart
git add lib/features/media/data/services/video_thumbnail_service.dart test/features/media/data/services/video_thumbnail_service_test.dart
git commit -m "feat(media): add VideoThumbnailService with disk cache"
```

---

### Task 3: Wire the service into `LocalFileResolver` + providers

**Files:**
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart`
- Test: `test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart` (create)

**Interfaces:**
- Consumes: `VideoThumbnailService.posterFor` (Task 2).
- Produces: `LocalFileResolver.resolveThumbnail` returns `BytesData` for videos when a poster is produced; unchanged (`FileData`) otherwise. New optional constructor param `VideoThumbnailService? videoThumbnails`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart
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
  Future<Uint8List?> posterFor(MediaItem item, {int maxDimension = 512}) async =>
      _bytes;
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

    final data = await r.resolveThumbnail(_video(f.path), target: const Size(200, 200));

    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes.toList(), [8, 8]);
  });

  test('video without a poster falls back to FileData', () async {
    final f = File('${tmp.path}/clip.mp4');
    await f.writeAsBytes([1, 2, 3]);
    final r = resolver(_StubThumbs(null));

    final data = await r.resolveThumbnail(_video(f.path), target: const Size(200, 200));

    expect(data, isA<FileData>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart`
Expected: FAIL — `videoThumbnails` named parameter is not defined.

- [ ] **Step 3: Add the dependency + video branch**

In `local_file_resolver.dart`, add the import and constructor field:

```dart
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
```

Add a field + optional constructor param (place `videoThumbnails` after `exifExtractor`):

```dart
  final VideoThumbnailService? _videoThumbnails;
```

```dart
  LocalFileResolver({
    required LocalBookmarkStorage bookmarkStorage,
    required LocalMediaPlatform platform,
    required ExifExtractor exifExtractor,
    VideoThumbnailService? videoThumbnails,
    VolumeStatus? volumeStatus,
  })  : _bookmarkStorage = bookmarkStorage,
        _platform = platform,
        _exifExtractor = exifExtractor,
        _videoThumbnails = videoThumbnails,
        _volumeStatus = volumeStatus ?? VolumeStatus();
```

Replace the existing `resolveThumbnail` body:

```dart
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    // Videos cannot be decoded as images; ask the OS for a poster frame and
    // return it as bytes. On any failure fall back to the raw-video FileData,
    // which MediaItemView renders as the movie-icon placeholder.
    if (item.isVideo && _videoThumbnails != null) {
      final maxDim = target.longestSide.round().clamp(1, 4096);
      final poster = await _videoThumbnails.posterFor(item, maxDimension: maxDim);
      if (poster != null) return BytesData(bytes: poster);
    }
    return resolve(item);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Wire the provider**

In `media_resolver_providers.dart`, add the import:

```dart
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
```

Add the service provider (after `localMediaPlatformProvider`):

```dart
final videoThumbnailServiceProvider = Provider<VideoThumbnailService>(
  (ref) => VideoThumbnailService(
    platform: ref.watch(localMediaPlatformProvider),
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    cacheDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'Submersion', 'video_thumbnails'));
    },
  ),
);
```

Inject it into `localFileResolverProvider`:

```dart
final localFileResolverProvider = Provider<LocalFileResolver>(
  (ref) => LocalFileResolver(
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    platform: ref.watch(localMediaPlatformProvider),
    exifExtractor: ref.watch(exifExtractorProvider),
    videoThumbnails: ref.watch(videoThumbnailServiceProvider),
  ),
);
```

Add `import 'dart:io';` to the providers file if not already present.

- [ ] **Step 6: Format, analyze, run the media suite, commit**

```bash
dart format lib/features/media/ test/features/media/
flutter analyze lib/features/media/
flutter test test/features/media/
git add lib/features/media/ test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart
git commit -m "feat(media): resolve local video thumbnails via VideoThumbnailService"
```

Expected: analyze clean; full media suite green.

---

### Task 4: macOS native handler (QuickLook)

**Files:**
- Modify: `macos/Runner/LocalMediaHandler.swift`

**Interfaces:**
- Consumes: channel args `{path: String?, bookmarkBlob: FlutterStandardTypedData?, maxDimension: Int}`.
- Produces: `FlutterStandardTypedData` (JPEG bytes) or `nil` on the `generateVideoThumbnail` method.

- [ ] **Step 1: Add the imports**

At the top of `LocalMediaHandler.swift`, ensure:

```swift
import QuickLookThumbnailing
import AppKit
```

- [ ] **Step 2: Add the method case**

Inside `handle(_:result:)`'s `switch call.method`, add:

```swift
        case "generateVideoThumbnail":
            guard let args = call.arguments as? [String: Any] else {
                result(nil); return
            }
            let maxDim = (args["maxDimension"] as? Int) ?? 512
            let blob = (args["bookmarkBlob"] as? FlutterStandardTypedData)?.data
            let path = args["path"] as? String
            generateVideoThumbnail(
                path: path, bookmarkBlob: blob, maxDimension: maxDim,
                result: result)
```

- [ ] **Step 3: Add the implementation**

Add this method to the class:

```swift
    /// Generates a poster frame via QuickLook. On the sandbox, resolves the
    /// security-scoped bookmark and brackets access; falls back to the raw
    /// path when no bookmark is supplied (unsandboxed dev builds).
    private func generateVideoThumbnail(
        path: String?, bookmarkBlob: Data?, maxDimension: Int,
        result: @escaping FlutterResult
    ) {
        var url: URL?
        var scoped = false
        if let blob = bookmarkBlob {
            var stale = false
            url = try? URL(
                resolvingBookmarkData: blob,
                options: [.withSecurityScope],
                relativeTo: nil, bookmarkDataIsStale: &stale)
            if let u = url { scoped = u.startAccessingSecurityScopedResource() }
        } else if let p = path {
            url = URL(fileURLWithPath: p)
        }
        guard let fileURL = url else { result(nil); return }

        let size = CGSize(width: maxDimension, height: maxDimension)
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL, size: size, scale: 1.0,
            representationTypes: .thumbnail)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            rep, _ in
            defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
            guard let cg = rep?.cgImage else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            let bitmap = NSBitmapImageRep(cgImage: cg)
            let jpeg = bitmap.representation(
                using: .jpeg, properties: [.compressionFactor: 0.8])
            DispatchQueue.main.async {
                if let data = jpeg {
                    result(FlutterStandardTypedData(bytes: data))
                } else {
                    result(nil)
                }
            }
        }
    }
```

- [ ] **Step 4: Build and smoke-test on macOS**

```bash
flutter run -d macos
```

In the app: open a dive, Add photo or video -> Files, pick the folder of GoPro `.mp4`s, link them. Verify video tiles now show a real poster frame (with the videocam badge) instead of the movie-icon placeholder. Scroll to confirm posters appear for newly visible tiles. Re-open the dive and confirm posters load instantly (cache hit).

- [ ] **Step 5: Commit**

```bash
git add macos/Runner/LocalMediaHandler.swift
git commit -m "feat(media): macOS QuickLook video thumbnails"
```

---

### Task 5: Windows native handler (IShellItemImageFactory)

**Files:**
- Modify: `windows/runner/flutter_window.h`
- Modify: `windows/runner/flutter_window.cpp`
- Modify: `windows/runner/CMakeLists.txt`

**Interfaces:**
- Consumes: channel args `{path: String, maxDimension: Int}` (Windows ignores `bookmarkBlob`).
- Produces: `std::vector<uint8_t>` (PNG bytes) or null on the `generateVideoThumbnail` method.

- [ ] **Step 1: Add channel headers to `flutter_window.h`**

Add includes and a member:

```cpp
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
```

Add a private member to the `FlutterWindow` class:

```cpp
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      local_media_channel_;
```

- [ ] **Step 2: Register the channel in `flutter_window.cpp`**

Inside `FlutterWindow::OnCreate()`, after `RegisterPlugins(...)` and the engine/controller are ready, add:

```cpp
  local_media_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.submersion.app/local_media",
          &flutter::StandardMethodCodec::GetInstance());
  local_media_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             res) {
        if (call.method_name() != "generateVideoThumbnail") {
          res->NotImplemented();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) { res->Success(); return; }
        std::string path;
        int max_dim = 512;
        auto pit = args->find(flutter::EncodableValue("path"));
        if (pit != args->end() &&
            std::holds_alternative<std::string>(pit->second)) {
          path = std::get<std::string>(pit->second);
        }
        auto mit = args->find(flutter::EncodableValue("maxDimension"));
        if (mit != args->end() &&
            std::holds_alternative<int32_t>(mit->second)) {
          max_dim = std::get<int32_t>(mit->second);
        }
        std::vector<uint8_t> png;
        if (path.empty() || !GenerateShellThumbnailPng(path, max_dim, &png)) {
          res->Success();  // null
          return;
        }
        res->Success(flutter::EncodableValue(png));
      });
```

- [ ] **Step 3: Add the shell-thumbnail helper in `flutter_window.cpp`**

Add these includes at the top:

```cpp
#include <shlobj.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>
#include <string>
#include <vector>
```

Add a file-scoped helper (anonymous namespace) before `FlutterWindow::OnCreate`:

```cpp
namespace {
using Microsoft::WRL::ComPtr;

std::wstring Widen(const std::string& utf8) {
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring w(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &w[0], len);
  if (!w.empty() && w.back() == L'\0') w.pop_back();
  return w;
}

// Encodes an HBITMAP to PNG bytes via WIC.
bool HBitmapToPng(HBITMAP hbmp, std::vector<uint8_t>* out) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IWICBitmap> bmp;
  if (FAILED(factory->CreateBitmapFromHBITMAP(
          hbmp, nullptr, WICBitmapUsePremultipliedAlpha, &bmp))) {
    return false;
  }
  ComPtr<IStream> stream;
  if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) return false;
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder))) {
    return false;
  }
  if (FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)))
    return false;
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IPropertyBag2> props;
  if (FAILED(encoder->CreateNewFrame(&frame, &props))) return false;
  if (FAILED(frame->Initialize(props.Get()))) return false;
  UINT w = 0, h = 0;
  bmp->GetSize(&w, &h);
  frame->SetSize(w, h);
  WICPixelFormatGUID fmt = GUID_WICPixelFormat32bppBGRA;
  frame->SetPixelFormat(&fmt);
  if (FAILED(frame->WriteSource(bmp.Get(), nullptr))) return false;
  if (FAILED(frame->Commit())) return false;
  if (FAILED(encoder->Commit())) return false;

  HGLOBAL hg = nullptr;
  if (FAILED(GetHGlobalFromStream(stream.Get(), &hg))) return false;
  SIZE_T size = GlobalSize(hg);
  void* data = GlobalLock(hg);
  if (!data) return false;
  out->assign(static_cast<uint8_t*>(data),
              static_cast<uint8_t*>(data) + size);
  GlobalUnlock(hg);
  return !out->empty();
}

bool GenerateShellThumbnailPng(const std::string& path, int max_dim,
                               std::vector<uint8_t>* out) {
  ComPtr<IShellItemImageFactory> factory;
  if (FAILED(SHCreateItemFromParsingName(
          Widen(path).c_str(), nullptr, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  SIZE size{max_dim, max_dim};
  HBITMAP hbmp = nullptr;
  if (FAILED(factory->GetImage(size, SIIGBF_THUMBNAILONLY, &hbmp))) {
    // Retry allowing the shell to synthesize (icon-or-thumbnail).
    if (FAILED(factory->GetImage(size, SIIGBF_BIGGERSIZEOK, &hbmp))) {
      return false;
    }
  }
  bool ok = HBitmapToPng(hbmp, out);
  DeleteObject(hbmp);
  return ok;
}
}  // namespace
```

- [ ] **Step 4: Link the required libraries in `windows/runner/CMakeLists.txt`**

Find the `target_link_libraries(${BINARY_NAME} PRIVATE ...)` line and add:

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE Shlwapi.lib Windowscodecs.lib)
```

(`Shell32`/`Ole32` are already linked by the default Flutter Windows runner; add them too if the build reports unresolved symbols for `SHCreateItemFromParsingName` / `CoCreateInstance`.)

- [ ] **Step 5: Build and smoke-test on Windows**

```bash
flutter run -d windows
```

Link a folder of local videos to a dive; confirm poster frames render on the tiles and persist (cache) across a reopen. If `GetImage` returns no thumbnail for a given codec, the tile keeps the placeholder (acceptable degradation).

- [ ] **Step 6: Commit**

```bash
git add windows/runner/flutter_window.cpp windows/runner/flutter_window.h windows/runner/CMakeLists.txt
git commit -m "feat(media): Windows shell video thumbnails"
```

---

### Task 6: Linux native handler (ffmpegthumbnailer)

**Files:**
- Modify: `linux/runner/my_application.cc`

**Interfaces:**
- Consumes: channel args `{path: String, maxDimension: Int}`.
- Produces: image bytes (PNG) or null on the `generateVideoThumbnail` method.

- [ ] **Step 1: Add includes to `my_application.cc`**

```cpp
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
```

- [ ] **Step 2: Register the channel after the view is created**

In `my_application_activate`, after `fl_register_plugins(FL_PLUGIN_REGISTRY(view))`, add:

```cpp
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* local_media_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.submersion.app/local_media", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      local_media_channel, local_media_method_call_cb, nullptr, nullptr);
```

(Keep a reference alive for the app lifetime; storing it on the `FlView`'s engine object via `g_object_set_data_full` with `g_object_unref` is sufficient.)

- [ ] **Step 3: Add the handler + generator above `my_application_activate`**

```cpp
// Returns PNG bytes for a video poster using ffmpegthumbnailer, or empty on
// failure / when the tool is not installed. No hard dependency: absence just
// yields the placeholder on the Dart side.
static std::vector<uint8_t> GenerateThumbnailPng(const std::string& path,
                                                 int max_dim) {
  std::vector<uint8_t> bytes;
  char tmpl[] = "/tmp/subm_vthumbXXXXXX.png";
  int fd = mkstemps(tmpl, 4);
  if (fd < 0) return bytes;
  close(fd);

  // -c png writes PNG to the output path; -s sets the size; -t 10% seeks.
  std::string cmd = "ffmpegthumbnailer -i '" + path + "' -o '" + tmpl +
                    "' -s " + std::to_string(max_dim) +
                    " -c png -t 10% >/dev/null 2>&1";
  int rc = std::system(cmd.c_str());
  if (rc == 0) {
    if (FILE* f = std::fopen(tmpl, "rb")) {
      std::fseek(f, 0, SEEK_END);
      long n = std::ftell(f);
      std::fseek(f, 0, SEEK_SET);
      if (n > 0) {
        bytes.resize(static_cast<size_t>(n));
        if (std::fread(bytes.data(), 1, bytes.size(), f) != bytes.size()) {
          bytes.clear();
        }
      }
      std::fclose(f);
    }
  }
  std::remove(tmpl);
  return bytes;
}

static void local_media_method_call_cb(FlMethodChannel* channel,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  if (g_strcmp0(fl_method_call_get_name(method_call),
                "generateVideoThumbnail") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(method_call);
  std::string path;
  int max_dim = 512;
  if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* p = fl_value_lookup_string(args, "path");
    if (p && fl_value_get_type(p) == FL_VALUE_TYPE_STRING) {
      path = fl_value_get_string(p);
    }
    FlValue* m = fl_value_lookup_string(args, "maxDimension");
    if (m && fl_value_get_type(m) == FL_VALUE_TYPE_INT) {
      max_dim = static_cast<int>(fl_value_get_int(m));
    }
  }

  g_autoptr(FlMethodResponse) response = nullptr;
  if (path.empty()) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    std::vector<uint8_t> png = GenerateThumbnailPng(path, max_dim);
    if (png.empty()) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      g_autoptr(FlValue) v = fl_value_new_uint8_list(png.data(), png.size());
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(v));
    }
  }
  fl_method_call_respond(method_call, response, nullptr);
}
```

- [ ] **Step 4: Build and smoke-test on Linux**

```bash
sudo apt-get install -y ffmpegthumbnailer   # if not present
flutter run -d linux
```

Link local videos to a dive; confirm posters render when `ffmpegthumbnailer` is installed, and that tiles keep the placeholder (no crash) when it is absent.

- [ ] **Step 5: Commit**

```bash
git add linux/runner/my_application.cc
git commit -m "feat(media): Linux ffmpegthumbnailer video thumbnails"
```

---

## Final verification

- [ ] Run the full suite: `flutter test` — all green.
- [ ] `flutter analyze` — no issues (infos are fatal in CI).
- [ ] `dart format .` — no changes.
- [ ] Confirm no regression in the media-store upload path. Local-video rows now resolve to `BytesData` via `resolveThumbnail`; `ThumbnailGenerator._resizeToJpeg` decodes by the row's `originalFilename`, so a `.mp4` name still yields null (exactly as the prior `FileData` video path did) — no regression. Reliably feeding the poster bytes into the upload thumbnail is a deliberate follow-up (it needs `_resizeToJpeg` to treat known poster bytes as an image regardless of the video filename), not part of this plan. Spot-check `thumbnail_generator_test` still passes.
