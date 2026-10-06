# Media Provenance PR 1: The Provenance Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `MediaSourceData` value report which source produced it and which store tier it is, and record the outcome of real resolutions, so a later PR can tell the user where a media item's bytes are actually coming from.

**Architecture:** Provenance is stamped onto the value object at each production site rather than computed by consumers. Two independent native-then-store fallback paths (`MediaItemView._resolve` and `mediaBytesProvider`) therefore inherit correct provenance without either being rewritten, and cannot disagree. A bounded in-memory recorder captures each completed resolution, including the one fact only the fallback layer knows: that the native source failed and the store covered for it.

**Tech Stack:** Dart / Flutter, Riverpod 3, `flutter_test`, Drift (test fixtures only).

**Spec:** `docs/superpowers/specs/2026-08-16-media-provenance-design.md`

**Branch / worktree:** `worktree-media-provenance` at `.claude/worktrees/media-provenance`. All work happens there. The worktree init trio (submodules, `flutter pub get`, `build_runner`) has already been run.

## Global Constraints

- **No em-dashes.** The `—` (U+2014) character must not appear in any code, comment, doc, test name, or commit message. En-dashes used as prose punctuation and spaced hyphens are equally forbidden. Use commas, colons, semicolons, parentheses, or two sentences.
- **No emojis** in code, comments, or documentation.
- **No schema change.** This PR adds no columns, no migration, no schema version bump, and touches no synced entity. If a task appears to need one, stop: something has drifted from the spec.
- **No behavior change.** Every resolution returns the same bytes, the same `UnavailableKind`, and the same widget rendering as before. Only added metadata. Existing tests must pass unmodified.
- `dart format .` must produce no changes. Run it before every commit.
- `flutter analyze` must be clean with zero infos. CI treats infos as fatal.
- Lints in force (`analysis_options.yaml`): `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `always_use_package_imports`. Never use a relative import in `lib/`; test files use relative imports for test helpers only, matching existing files.
- Run the targeted test file after each change. Run the full `flutter test` only at the final task.

## Verified Facts (do not re-derive)

These were confirmed against the branch tip before this plan was written.

1. **Super-parameter defaults inherit correctly and stay const.** A subclass declaring `super.servedTier` with no explicit default picks up the base constructor's default, and `const UnavailableData()` still works. This was verified by compiling and running the exact pattern. You do not need to re-test it.
2. **`PlatformGalleryResolver`'s success paths are not unit-testable on a CI host.** They sit inside `coverage:ignore` blocks because `AssetEntity.fromId` requires a real device gallery. Task 3 stamps them but asserts only on the reachable unavailable paths. Do not invent a fake that pretends otherwise.
3. **`GalleryThumbnailCache._entries` is private**, so a test cannot pre-seed thumbnail bytes to reach the success branch. Same conclusion as above.

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/features/media/domain/value_objects/media_source_data.dart` | Modify: add `ServedFrom`, `ServedTier`, and the two base-class fields | 1 |
| `lib/features/media/data/resolvers/local_file_resolver.dart` | Modify: stamp `localDisk` | 2 |
| `lib/features/media/data/resolvers/platform_gallery_resolver.dart` | Modify: stamp `platformGallery` | 3 |
| `lib/features/media/data/resolvers/signature_resolver.dart` | Modify: stamp `embedded` | 4 |
| `lib/features/media/data/resolvers/http_url_media_resolver.dart` | Modify: stamp `networkUrl` | 4 |
| `lib/features/media/data/resolvers/connector_media_resolver.dart` | Modify: stamp `connectorCache` / `connectorNetwork` | 5 |
| `lib/features/media/data/resolvers/media_store_resolver.dart` | Modify: stamp cache vs network across three tiers | 6 |
| `lib/features/media/data/services/media_serving_recorder.dart` | Create: the recorder and its observation value object | 7 |
| `lib/features/media/presentation/providers/media_serving_providers.dart` | Create: the recorder's Riverpod provider | 7 |
| `lib/features/media/presentation/providers/media_bytes_providers.dart` | Modify: record the outcome | 8 |
| `lib/features/media/presentation/widgets/media_item_view.dart` | Modify: carry `storeFallbackUsed`, record the outcome, PDF provenance pass-through | 9 |

---

### Task 1: The provenance fields on MediaSourceData

**Files:**
- Modify: `lib/features/media/domain/value_objects/media_source_data.dart`
- Test: `test/features/media/domain/value_objects/media_source_data_provenance_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `enum ServedFrom { localDisk, platformGallery, storeCache, storeNetwork, networkUrl, connectorCache, connectorNetwork, embedded }`; `enum ServedTier { original, thumbnail, rendition }`; `MediaSourceData.servedFrom` (`ServedFrom?`) and `MediaSourceData.servedTier` (`ServedTier`, default `ServedTier.original`); all four subclasses accept `servedFrom` and `servedTier` as named optional parameters. Every later task depends on these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/media_source_data_provenance_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  test('defaults to no provenance and the original tier', () {
    final data = BytesData(bytes: Uint8List(0));
    expect(data.servedFrom, isNull);
    expect(data.servedTier, ServedTier.original);
  });

  test('FileData carries the stamp it was constructed with', () {
    final data = FileData(
      file: File('/tmp/x'),
      servedFrom: ServedFrom.storeCache,
      servedTier: ServedTier.thumbnail,
    );
    expect(data.servedFrom, ServedFrom.storeCache);
    expect(data.servedTier, ServedTier.thumbnail);
    expect(data.isPoster, isFalse);
  });

  test('UnavailableData never claims a source', () {
    const data = UnavailableData(kind: UnavailableKind.notFound);
    expect(data.servedFrom, isNull);
    expect(data.kind, UnavailableKind.notFound);
  });

  test('NetworkData stamps stay const-constructible', () {
    final data = NetworkData(
      url: Uri.parse('https://example.test/a.jpg'),
      servedFrom: ServedFrom.networkUrl,
    );
    expect(data.servedFrom, ServedFrom.networkUrl);
    expect(data.servedTier, ServedTier.original);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/domain/value_objects/media_source_data_provenance_test.dart`
Expected: FAIL to compile, "The getter 'servedFrom' isn't defined" and "Undefined name 'ServedTier'".

- [ ] **Step 3: Write the implementation**

In `lib/features/media/domain/value_objects/media_source_data.dart`, add the two enums immediately after the existing `UnavailableKind` enum:

```dart
/// Which concrete source produced a [MediaSourceData]'s bytes.
///
/// Distinct from [MediaSourceType], which records where a row was LINKED
/// from and never changes. This records where the bytes came from on THIS
/// resolution, which can differ: a gallery-sourced row whose asset has been
/// deleted from the photo library is served from the cloud store instead.
enum ServedFrom {
  /// A file read directly off a mounted volume by [LocalFileResolver].
  localDisk,

  /// Bytes handed over by photo_manager from the device photo library.
  platformGallery,

  /// A hit in the local media cache. No network was touched.
  storeCache,

  /// Downloaded from the cloud media store during this resolution.
  storeNetwork,

  /// A URL handed to cached_network_image, which owns the transport.
  networkUrl,

  /// A hit in the service connector's own cache pool.
  connectorCache,

  /// Fetched from the service connector's API during this resolution.
  connectorNetwork,

  /// A BLOB stored inline on the media row (signatures).
  embedded,
}

/// Which of the three store tiers a [MediaSourceData]'s bytes are.
///
/// Orthogonal to [ServedFrom]: the store can serve any tier from either its
/// cache or the network, so "a cached thumbnail" and "a freshly downloaded
/// thumbnail" differ in [ServedFrom] while sharing a tier.
enum ServedTier {
  /// The item's own full-resolution bytes.
  original,

  /// A derived small image: a resized photo, a video poster frame, or a
  /// document page-1 render.
  thumbnail,

  /// A compressed rendition uploaded in place of the original by a
  /// non-original upload quality setting.
  rendition,
}
```

Then change the sealed base class and all four subclass constructors. Replace the existing `sealed class MediaSourceData { const MediaSourceData(); }` with:

```dart
sealed class MediaSourceData {
  const MediaSourceData({
    this.servedFrom,
    this.servedTier = ServedTier.original,
  });

  /// Which source produced these bytes, or null when nothing did
  /// ([UnavailableData]) or the producer did not say.
  final ServedFrom? servedFrom;

  /// Which tier these bytes are. Meaningful mainly for store-served data;
  /// every other producer leaves it at [ServedTier.original] except when it
  /// returns a derived image.
  final ServedTier servedTier;
}
```

Add the two super parameters to each subclass constructor, keeping every existing parameter and doc comment untouched:

```dart
class FileData extends MediaSourceData {
  final File file;
  final bool isPoster;

  const FileData({
    required this.file,
    this.isPoster = false,
    super.servedFrom,
    super.servedTier,
  });
}
```

```dart
class NetworkData extends MediaSourceData {
  final Uri url;
  final Map<String, String> headers;
  const NetworkData({
    required this.url,
    this.headers = const {},
    super.servedFrom,
    super.servedTier,
  });
}
```

```dart
class BytesData extends MediaSourceData {
  final Uint8List bytes;
  const BytesData({required this.bytes, super.servedFrom, super.servedTier});
}
```

```dart
class UnavailableData extends MediaSourceData {
  final UnavailableKind kind;
  final String? userMessage;
  final String? originDeviceLabel;

  const UnavailableData({
    required this.kind,
    this.userMessage,
    this.originDeviceLabel,
  });
}
```

`UnavailableData` deliberately does NOT accept the super parameters. Nothing served it, so there is no honest value to pass, and omitting them makes that unrepresentable rather than merely conventional.

Do not touch the existing doc comment on `FileData.isPoster`. Leave it exactly as it is.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/domain/value_objects/media_source_data_provenance_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Verify nothing else broke**

Run: `flutter analyze lib/features/media test/features/media`
Expected: "No issues found." Every existing construction site keeps compiling because both new parameters are optional and defaulted.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/domain/value_objects/media_source_data.dart \
        test/features/media/domain/value_objects/media_source_data_provenance_test.dart
git commit -m "Add ServedFrom and ServedTier to MediaSourceData

Provenance rides on the value object so both native-then-store fallback
paths inherit it without either being rewritten. Both fields are optional
and defaulted, so every existing construction site is unchanged.
UnavailableData does not accept them: nothing served it."
```

---

### Task 2: Stamp LocalFileResolver

**Files:**
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart`
- Test: `test/features/media/data/resolvers/local_file_resolver_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom`, `ServedTier` from Task 1.
- Produces: nothing new. `LocalFileResolver.resolve` returns `FileData`/`BytesData` stamped `ServedFrom.localDisk`; `resolveThumbnail`'s video poster is stamped `ServedFrom.localDisk` with `ServedTier.thumbnail`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/local_file_resolver_provenance_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lfr_prov');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  MediaItem item({String? localPath}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: localPath,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  LocalFileResolver build() => LocalFileResolver(
    bookmarkStorage: LocalBookmarkStorage(),
    platform: LocalMediaPlatform(),
    exifExtractor: ExifExtractor(),
    usesSecurityScopedBookmarks: () => false,
  );

  test('a readable local file is stamped localDisk at original tier', () async {
    final f = File('${dir.path}/reef.jpg');
    await f.writeAsBytes(const [1, 2, 3], flush: true);

    final data = await build().resolve(item(localPath: f.path));

    expect(data, isA<FileData>());
    expect(data.servedFrom, ServedFrom.localDisk);
    expect(data.servedTier, ServedTier.original);
  });

  test('an unresolvable item claims no source', () async {
    final data = await build().resolve(item());

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });
}
```

If `LocalBookmarkStorage`, `LocalMediaPlatform`, or `ExifExtractor` cannot be zero-arg constructed, read `test/features/media/data/resolvers/local_file_resolver_test.dart` and copy its exact construction and stubs. Do not invent constructor signatures.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/local_file_resolver_provenance_test.dart`
Expected: FAIL on the first test, "Expected: <ServedFrom.localDisk> Actual: <null>".

- [ ] **Step 3: Write the implementation**

Three edits in `local_file_resolver.dart`, all inside `resolve`:

Desktop path, currently `if (blocker == null) return FileData(file: f);`:

```dart
if (blocker == null) {
  return FileData(file: f, servedFrom: ServedFrom.localDisk);
}
```

Android URI branch, currently `return BytesData(bytes: bytes);`:

```dart
return BytesData(bytes: bytes, servedFrom: ServedFrom.localDisk);
```

Security-scoped bookmark branch, currently `return BytesData(bytes: bytes);`:

```dart
return BytesData(bytes: bytes, servedFrom: ServedFrom.localDisk);
```

One edit in `resolveThumbnail`, currently `if (poster != null) return BytesData(bytes: poster);`:

```dart
if (poster != null) {
  return BytesData(
    bytes: poster,
    servedFrom: ServedFrom.localDisk,
    servedTier: ServedTier.thumbnail,
  );
}
```

Leave every `UnavailableData` return untouched. Leave the `coverage:ignore` markers exactly where they are.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/resolvers/local_file_resolver_provenance_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Verify the existing suite for this resolver still passes**

Run: `flutter test test/features/media/data/resolvers/local_file_resolver_test.dart test/features/media/data/resolvers/local_file_resolver_video_thumb_test.dart`
Expected: PASS, unchanged counts. These assert bytes and types, not provenance, so they must be untouched.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/local_file_resolver.dart \
        test/features/media/data/resolvers/local_file_resolver_provenance_test.dart
git commit -m "Stamp localDisk provenance in LocalFileResolver

Covers the desktop path read, both bookmark byte paths, and the desktop
video poster, which is the resolver's only thumbnail-tier product."
```

---

### Task 3: Stamp PlatformGalleryResolver

**Files:**
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart`
- Test: `test/features/media/data/resolvers/platform_gallery_resolver_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom`, `ServedTier` from Task 1.
- Produces: nothing new.

**Read this before starting.** The two success returns in this resolver sit inside `coverage:ignore-start` / `coverage:ignore-end` blocks because `AssetEntity.fromId` needs a real device photo library, and `GalleryThumbnailCache` keeps its entries private so a test cannot pre-seed a hit. You will stamp those two returns and you will NOT be able to assert on them from a test host. That is expected and correct. Assert on the unavailable paths, which are reachable, and do not build a fake that simulates a gallery.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/platform_gallery_resolver_provenance_test.dart`. Open `test/features/media/data/resolvers/platform_gallery_resolver_test.dart` first and reuse its `_StubPhotoPickerService` and `_FakeAssetResolutionService` verbatim by copying them into the new file (they are private to their file, so they cannot be imported).

```dart
// Copy _StubPhotoPickerService and _FakeAssetResolutionService from
// platform_gallery_resolver_test.dart, plus that file's imports.

void main() {
  MediaItem item({String? assetId}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: assetId,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('a row with no asset id claims no source', () async {
    final r = PlatformGalleryResolver(
      resolutionService: _FakeAssetResolutionService(
        ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );

    final data = await r.resolve(item());

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });

  test('an unresolvable thumbnail claims no source', () async {
    final r = PlatformGalleryResolver(
      resolutionService: _FakeAssetResolutionService(
        ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );

    final data = await r.resolveThumbnail(item(), target: const Size(128, 128));

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });
}
```

Match `ResolutionResult`'s real constructor to what `_FakeAssetResolutionService` in the existing test expects. Read it; do not guess.

- [ ] **Step 2: Run the test to verify it passes already**

Run: `flutter test test/features/media/data/resolvers/platform_gallery_resolver_provenance_test.dart`
Expected: PASS. This is the one task whose test does not fail first, because it pins the null-provenance contract on the unavailable paths, which Task 1 already satisfies. Its value is regression protection: it fails loudly if a later refactor ever stamps an `UnavailableData`.

- [ ] **Step 3: Write the implementation**

Two edits in `platform_gallery_resolver.dart`.

In `resolve`, inside the coverage-ignored block, currently `return BytesData(bytes: bytes);`:

```dart
return BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);
```

In `resolveThumbnail`, currently `return BytesData(bytes: bytes);`:

```dart
return BytesData(
  bytes: bytes,
  servedFrom: ServedFrom.platformGallery,
  servedTier: ServedTier.thumbnail,
);
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/data/resolvers/platform_gallery_resolver_provenance_test.dart test/features/media/data/resolvers/platform_gallery_resolver_test.dart test/features/media/data/resolvers/platform_gallery_resolver_extra_test.dart`
Expected: PASS, all three files.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/platform_gallery_resolver.dart \
        test/features/media/data/resolvers/platform_gallery_resolver_provenance_test.dart
git commit -m "Stamp platformGallery provenance in PlatformGalleryResolver

The two success returns need a real device gallery and stay inside their
coverage-ignore blocks, so the test pins the reachable contract instead:
an unavailable resolution never claims a source."
```

---

### Task 4: Stamp SignatureResolver and HttpUrlMediaResolver

**Files:**
- Modify: `lib/features/media/data/resolvers/signature_resolver.dart`
- Modify: `lib/features/media/data/resolvers/http_url_media_resolver.dart`
- Test: `test/features/media/data/resolvers/signature_http_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom` from Task 1.
- Produces: nothing new.

These two are grouped because each is a two-line change with no shared state, and splitting them would give a reviewer nothing extra to reject.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/signature_http_provenance_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _signature({Uint8List? imageData}) => MediaItem(
  id: 'sig',
  mediaType: MediaType.instructorSignature,
  sourceType: MediaSourceType.signature,
  imageData: imageData,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('an inline signature blob is stamped embedded', () async {
    final data = await SignatureResolver().resolve(
      _signature(imageData: Uint8List.fromList(const [1, 2, 3])),
    );

    expect(data, isA<BytesData>());
    expect(data.servedFrom, ServedFrom.embedded);
    expect(data.servedTier, ServedTier.original);
  });

  test('a signature with nothing to read claims no source', () async {
    final data = await SignatureResolver().resolve(_signature());

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });
}
```

Add a third test for the HTTP resolver in the same file. Read `test/features/media/data/resolvers/http_url_media_resolver_test.dart` first and copy its exact construction of `NetworkUrlResolver` and `UrlMetadataExtractor` stubs, since `HttpUrlMediaResolver` requires both:

```dart
test('a URL row is stamped networkUrl', () async {
  final resolver = HttpUrlMediaResolver(
    sourceType: MediaSourceType.networkUrl,
    networkUrlResolver: <stub from the existing test>,
    urlMetadataExtractor: <stub from the existing test>,
  );

  final data = await resolver.resolve(
    MediaItem(
      id: 'u1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.networkUrl,
      url: 'https://example.test/reef.jpg',
      takenAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );

  expect(data, isA<NetworkData>());
  expect(data.servedFrom, ServedFrom.networkUrl);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/signature_http_provenance_test.dart`
Expected: FAIL on tests 1 and 3, "Expected: <ServedFrom.embedded> Actual: <null>" and the `networkUrl` equivalent.

- [ ] **Step 3: Write the implementation**

In `signature_resolver.dart`, `resolve`:

```dart
if (item.imageData != null && item.imageData!.isNotEmpty) {
  return BytesData(bytes: item.imageData!, servedFrom: ServedFrom.embedded);
}
final path = item.filePath;
if (path != null && path.isNotEmpty) {
  final file = File(path);
  if (await file.exists()) {
    return FileData(file: file, servedFrom: ServedFrom.embedded);
  }
}
```

A signature stored as a file is still the app's own signature artifact rather than a user-linked asset, so both branches read `embedded`. That is deliberate.

In `http_url_media_resolver.dart`, `resolve`, currently `return NetworkData(url: uri);`:

```dart
return NetworkData(url: uri, servedFrom: ServedFrom.networkUrl);
```

This resolver registers for both `manifestEntry` and `networkUrl`, and both are HTTP transports handed to `cached_network_image`. `ServedFrom` records the transport, not the link provenance, so a single value is correct for both. The link provenance is `MediaItem.sourceType` and is already stored.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/resolvers/signature_http_provenance_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Verify the existing suites still pass**

Run: `flutter test test/features/media/data/resolvers/signature_resolver_test.dart test/features/media/data/resolvers/signature_resolver_extra_test.dart test/features/media/data/resolvers/http_url_media_resolver_test.dart`
Expected: PASS, unchanged counts.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/signature_resolver.dart \
        lib/features/media/data/resolvers/http_url_media_resolver.dart \
        test/features/media/data/resolvers/signature_http_provenance_test.dart
git commit -m "Stamp embedded and networkUrl provenance

ServedFrom records the byte transport, so the one HTTP resolver stamps
networkUrl for both the manifestEntry and networkUrl source types. The
link provenance those two differ in is already on MediaItem.sourceType."
```

---

### Task 5: Stamp ConnectorMediaResolver

**Files:**
- Modify: `lib/features/media/data/resolvers/connector_media_resolver.dart`
- Test: `test/features/media/data/resolvers/connector_media_resolver_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom`, `ServedTier` from Task 1.
- Produces: nothing new.

This resolver has four success returns inside `_resolveRendition`: one cache hit, two post-fetch cache writes (thumb and hash-verified original), and one uncached `BytesData`. The cache hit is `connectorCache`; the other three are `connectorNetwork`, because the bytes were pulled from the Lightroom API during this call even when they land in the cache on the way out.

Tier follows the `MediaCacheKind` the caller passed: `MediaCacheKind.thumb` maps to `ServedTier.thumbnail`, `MediaCacheKind.original` maps to `ServedTier.original`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/connector_media_resolver_provenance_test.dart`. Construct the resolver with a `hasLightroomAccount: false` item to reach the `signInRequired` path without any Lightroom stubbing:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/connector_media_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _connectorItem() => MediaItem(
  id: 'c1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.serviceConnector,
  remoteAssetId: 'asset-1',
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('a signed-out connector resolution claims no source', () async {
    final resolver = ConnectorMediaResolver(
      hasLightroomAccount: false,
      apiClient: () async => null,
      catalogId: () async => null,
      cache: () async => null,
    );

    final data = await resolver.resolve(_connectorItem());

    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.signInRequired);
    expect(data.servedFrom, isNull);
  });
}
```

Then add a cache-hit test. Build a real `MediaCacheStore` over an in-memory `LocalCacheDatabase` exactly as `test/features/media/data/media_store_resolver_test.dart` does in its `setUp`, seed it with `cache.put(hash, MediaCacheKind.original, stagingFile, extension: 'jpg')`, give the item that `contentHash`, and assert:

```dart
expect(data, isA<FileData>());
expect(data.servedFrom, ServedFrom.connectorCache);
expect(data.servedTier, ServedTier.original);
```

Set `hasLightroomAccount: true` for that test so the cache lookup is reached, and leave `apiClient` returning null so a cache miss would fall to `signInRequired` rather than hitting the network. That asymmetry is what proves the cache branch actually ran.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/connector_media_resolver_provenance_test.dart`
Expected: the signed-out test PASSES (null provenance already holds); the cache-hit test FAILS with "Expected: <ServedFrom.connectorCache> Actual: <null>".

- [ ] **Step 3: Write the implementation**

In `connector_media_resolver.dart`, add a tier helper just above `_resolveRendition`:

```dart
/// The cache pool a rendition request targets also names its tier: the
/// connector fetches a 'thumbnail2x' rendition into the thumb pool and a
/// '2048' rendition into the originals pool.
ServedTier _tierFor(MediaCacheKind kind) =>
    kind == MediaCacheKind.thumb ? ServedTier.thumbnail : ServedTier.original;
```

Then stamp the four success returns inside `_resolveRendition`:

Cache hit:

```dart
if (cached != null) {
  return FileData(
    file: cached,
    isPoster: isPoster,
    servedFrom: ServedFrom.connectorCache,
    servedTier: _tierFor(kind),
  );
}
```

Post-fetch thumb write:

```dart
return FileData(
  file: file,
  isPoster: isPoster,
  servedFrom: ServedFrom.connectorNetwork,
  servedTier: _tierFor(kind),
);
```

Post-fetch hash-verified original write: identical stamp to the thumb write above. Write it out in full rather than sharing a variable; the two sit in different branches.

Uncached fallthrough:

```dart
return BytesData(
  bytes: bytes,
  servedFrom: ServedFrom.connectorNetwork,
  servedTier: _tierFor(kind),
);
```

Leave all three `UnavailableData` returns untouched.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/resolvers/connector_media_resolver_provenance_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Verify existing connector tests still pass**

Run: `flutter test test/features/media`
Expected: PASS, unchanged counts. There is no dedicated connector-resolver test file today, so this directory run is the regression net for the Lightroom paths.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/connector_media_resolver.dart \
        test/features/media/data/resolvers/connector_media_resolver_provenance_test.dart
git commit -m "Stamp connector cache and network provenance

The three post-fetch returns all read connectorNetwork: bytes pulled from
the Lightroom API during this call are network-served even when they land
in the cache on the way out. Only the pre-fetch hit is connectorCache."
```

---

### Task 6: Stamp MediaStoreResolver

**Files:**
- Modify: `lib/features/media/data/resolvers/media_store_resolver.dart`
- Test: `test/features/media/data/media_store_resolver_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom`, `ServedTier` from Task 1.
- Produces: nothing new.

**This is the load-bearing task of the whole PR.** These six returns are the only place in the codebase that knows a cache hit from a network download, and discarding that distinction is the root cause the spec exists to fix. A wrong stamp here makes the entire feature decorative while still looking correct. Test it properly.

Each of the three fetch methods has exactly two success returns, in this order: the cache hit first, the post-download return second.

| Method | Cache hit | Post-download | Tier |
| --- | --- | --- | --- |
| `_fetchThumb` | `storeCache` | `storeNetwork` | `thumbnail` |
| `_fetchCompressed` | `storeCache` | `storeNetwork` | `rendition` |
| `_fetchOriginal` | `storeCache` | `storeNetwork` | `original` |

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/media_store_resolver_provenance_test.dart`. Copy the `setUp` / `tearDown` / `item` scaffolding from `test/features/media/data/media_store_resolver_test.dart` verbatim, including its relative import of `../../../helpers/in_memory_media_object_store.dart`:

```dart
test('an original download is storeNetwork, the re-read is storeCache', () async {
  final bytes = 'submersion'.codeUnits;
  final tmp = File('${root.path}/seed');
  await tmp.writeAsBytes(bytes, flush: true);
  final digest = await sha256OfFile(tmp);
  store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

  final first = await resolver.tryResolveRemote(
    item(hash: digest.hash, uploadedAt: DateTime(2026)),
    thumbnail: false,
  );
  expect(first!.servedFrom, ServedFrom.storeNetwork);
  expect(first.servedTier, ServedTier.original);

  // Emptying the store proves the second read cannot have gone to network.
  store.objects.clear();

  final second = await resolver.tryResolveRemote(
    item(hash: digest.hash, uploadedAt: DateTime(2026)),
    thumbnail: false,
  );
  expect(second!.servedFrom, ServedFrom.storeCache);
  expect(second.servedTier, ServedTier.original);
});
```

Write two more tests in the same shape:

- **Thumb tier.** Seed `store.objects[StoreKeys.thumbKey(hash)]` with any bytes, build the item with `remoteThumbUploadedAt: DateTime(2026)` and a `contentHash`, call with `thumbnail: true`. Assert `storeNetwork` then `storeCache`, both at `ServedTier.thumbnail`. Thumbs are not hash-verified, so the bytes can be arbitrary.
- **Rendition tier.** Seed `store.objects[StoreKeys.renditionKey(hash, ext: 'jpg')]`, build the item with `remoteCompressedUploadedAt: DateTime(2026)` and a `contentHash` but leave `remoteUploadedAt` null, call with `thumbnail: false`. Assert `storeNetwork` then `storeCache`, both at `ServedTier.rendition`. Read `MediaItem`'s constructor for the exact `remoteCompressedUploadedAt` parameter name before writing this; the `item` helper copied from the existing test does not accept it and must be extended.

Emptying `store.objects` between the two reads is the assertion's whole load-bearing mechanism. Without it, a `storeCache` stamp on the second read proves nothing, because a resolver that stamped `storeCache` unconditionally would also pass. Do not skip it.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/media_store_resolver_provenance_test.dart`
Expected: FAIL on all three tests, "Expected: <ServedFrom.storeNetwork> Actual: <null>".

- [ ] **Step 3: Write the implementation**

In `_fetchThumb`:

```dart
final cached = await _cache.get(hash, MediaCacheKind.thumb);
if (cached != null) {
  return FileData(
    file: cached,
    isPoster: isPoster,
    servedFrom: ServedFrom.storeCache,
    servedTier: ServedTier.thumbnail,
  );
}
```

and the post-download return:

```dart
return FileData(
  file: file,
  isPoster: isPoster,
  servedFrom: ServedFrom.storeNetwork,
  servedTier: ServedTier.thumbnail,
);
```

In `_fetchCompressed`:

```dart
if (cached != null) {
  return FileData(
    file: cached,
    servedFrom: ServedFrom.storeCache,
    servedTier: ServedTier.rendition,
  );
}
```

and:

```dart
return FileData(
  file: file,
  servedFrom: ServedFrom.storeNetwork,
  servedTier: ServedTier.rendition,
);
```

In `_fetchOriginal`:

```dart
final cached = await _cache.get(hash, MediaCacheKind.original);
if (cached != null) {
  return FileData(
    file: cached,
    servedFrom: ServedFrom.storeCache,
    servedTier: ServedTier.original,
  );
}
```

and:

```dart
return FileData(
  file: file,
  servedFrom: ServedFrom.storeNetwork,
  servedTier: ServedTier.original,
);
```

Do not touch `tryResolveRemote`'s tier-selection ladder, the hash verification, the video early-return, or `_discardStaging`. Six return expressions change and nothing else.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/media_store_resolver_provenance_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Verify the existing store-resolver suites still pass**

Run: `flutter test test/features/media/data/media_store_resolver_test.dart test/features/media/data/media_store_resolver_compressed_test.dart test/features/media/data/media_store_resolver_video_test.dart test/features/media/data/media_store_source_resolver_test.dart`
Expected: PASS, unchanged counts.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/media_store_resolver.dart \
        test/features/media/data/media_store_resolver_provenance_test.dart
git commit -m "Stamp store cache vs network provenance across all three tiers

These six returns were the only place in the app that knew a cache hit
from a fresh download, and they discarded it. Each test empties the object
store between the two reads, so a storeCache stamp on the second read can
only mean the cache actually served it."
```

---

### Task 7: The serving recorder

**Files:**
- Create: `lib/features/media/data/services/media_serving_recorder.dart`
- Create: `lib/features/media/presentation/providers/media_serving_providers.dart`
- Test: `test/features/media/data/services/media_serving_recorder_test.dart` (create)

**Interfaces:**
- Consumes: `ServedFrom`, `ServedTier`, `UnavailableKind` from Task 1.
- Produces, and Tasks 8 and 9 call these exact signatures:

```dart
class ServingObservation {
  const ServingObservation({
    required this.servedFrom,
    required this.servedTier,
    required this.failure,
    required this.storeFallbackUsed,
    required this.observedAt,
  });
  final ServedFrom? servedFrom;
  final ServedTier servedTier;
  final UnavailableKind? failure;
  final bool storeFallbackUsed;
  final DateTime observedAt;
}

class MediaServingRecorder extends ChangeNotifier {
  MediaServingRecorder({DateTime Function()? now, int maxEntries = 200});
  void record(
    String mediaId, {
    required bool thumbnail,
    ServedFrom? servedFrom,
    ServedTier servedTier = ServedTier.original,
    UnavailableKind? failure,
    bool storeFallbackUsed = false,
  });
  ServingObservation? lastFor(String mediaId, {required bool thumbnail});
  int get entryCount;
}

final mediaServingRecorderProvider = Provider<MediaServingRecorder>(...);
```

**Deviation from the spec, and why.** The spec sketched `Listenable listenableFor(String mediaId)`. This plan ships a single `ChangeNotifier` on the recorder instead. A per-id notifier map needs lifecycle management (creation on demand, disposal when the last listener leaves) that buys nothing while exactly one info panel is open at a time, which is the only consumer. The panel in PR 2 listens to the recorder and re-reads `lastFor` for its own id. If a real need for per-id granularity appears, add it then.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/media_serving_recorder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  test('records and reads back a successful resolution', () {
    final r = MediaServingRecorder(now: () => DateTime.utc(2026, 8, 16));

    r.record(
      'm1',
      thumbnail: false,
      servedFrom: ServedFrom.storeCache,
      servedTier: ServedTier.original,
    );

    final obs = r.lastFor('m1', thumbnail: false)!;
    expect(obs.servedFrom, ServedFrom.storeCache);
    expect(obs.servedTier, ServedTier.original);
    expect(obs.failure, isNull);
    expect(obs.storeFallbackUsed, isFalse);
    expect(obs.observedAt, DateTime.utc(2026, 8, 16));
  });

  test('thumbnail and original observations do not overwrite each other', () {
    final r = MediaServingRecorder();

    r.record('m1', thumbnail: true, servedFrom: ServedFrom.storeCache);
    r.record('m1', thumbnail: false, servedFrom: ServedFrom.storeNetwork);

    expect(r.lastFor('m1', thumbnail: true)!.servedFrom, ServedFrom.storeCache);
    expect(
      r.lastFor('m1', thumbnail: false)!.servedFrom,
      ServedFrom.storeNetwork,
    );
  });

  test('records a failure with no source', () {
    final r = MediaServingRecorder();

    r.record(
      'm1',
      thumbnail: false,
      failure: UnavailableKind.notFound,
      storeFallbackUsed: true,
    );

    final obs = r.lastFor('m1', thumbnail: false)!;
    expect(obs.servedFrom, isNull);
    expect(obs.failure, UnavailableKind.notFound);
    expect(obs.storeFallbackUsed, isTrue);
  });

  test('returns null for an item never observed', () {
    expect(MediaServingRecorder().lastFor('nope', thumbnail: false), isNull);
  });

  test('evicts least recently recorded beyond maxEntries', () {
    final r = MediaServingRecorder(maxEntries: 2);

    r.record('a', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('b', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('c', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(r.entryCount, 2);
    expect(r.lastFor('a', thumbnail: false), isNull);
    expect(r.lastFor('b', thumbnail: false), isNotNull);
    expect(r.lastFor('c', thumbnail: false), isNotNull);
  });

  test('re-recording an id refreshes its recency', () {
    final r = MediaServingRecorder(maxEntries: 2);

    r.record('a', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('b', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('a', thumbnail: false, servedFrom: ServedFrom.storeCache);
    r.record('c', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(r.lastFor('a', thumbnail: false)!.servedFrom, ServedFrom.storeCache);
    expect(r.lastFor('b', thumbnail: false), isNull);
  });

  test('notifies listeners on record', () {
    final r = MediaServingRecorder();
    var notifications = 0;
    r.addListener(() => notifications++);

    r.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(notifications, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/media_serving_recorder_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist: media_serving_recorder.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/features/media/data/services/media_serving_recorder.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// What one completed resolution produced.
///
/// [storeFallbackUsed] is the fact no resolver can report on its own: it
/// belongs to the layer that tried the row's native source first, saw it
/// fail, and asked the media store to cover. It is what turns "the cloud
/// served this" into "the photo library lookup failed and the cloud served
/// this", which is the difference between a status readout and a diagnosis.
@immutable
class ServingObservation {
  const ServingObservation({
    required this.servedFrom,
    required this.servedTier,
    required this.failure,
    required this.storeFallbackUsed,
    required this.observedAt,
  });

  final ServedFrom? servedFrom;
  final ServedTier servedTier;

  /// Set when the resolution produced no bytes at all.
  final UnavailableKind? failure;

  /// Whether the row's own source failed and the media store was asked.
  final bool storeFallbackUsed;

  final DateTime observedAt;
}

/// Remembers how each media item was most recently resolved, so the media
/// info panel can report what actually painted the pixels rather than
/// re-resolving and reporting what would happen if it tried again.
///
/// Deliberately NOT a StateNotifier or a Riverpod-managed state object.
/// Every visible tile writes here as it finishes resolving, and routing
/// that through provider state would rebuild the grid on every scroll.
/// Listeners are notified so an open info panel can refresh; when nothing
/// is listening, notification is free.
class MediaServingRecorder extends ChangeNotifier {
  MediaServingRecorder({DateTime Function()? now, this.maxEntries = 200})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Bound on retained observations. A library scroll would otherwise grow
  /// this map without limit for the lifetime of the process.
  final int maxEntries;

  /// Insertion-ordered, so the first key is the least recently recorded.
  /// A re-record removes and re-inserts to move the entry to the end.
  final Map<String, ServingObservation> _entries =
      <String, ServingObservation>{};

  @visibleForTesting
  int get entryCount => _entries.length;

  /// A thumbnail and an original are separate observations of the same row:
  /// a grid tile resolves the first while the viewer resolves the second,
  /// and they can legitimately come from different places.
  String _key(String mediaId, bool thumbnail) =>
      '$mediaId#${thumbnail ? 't' : 'o'}';

  void record(
    String mediaId, {
    required bool thumbnail,
    ServedFrom? servedFrom,
    ServedTier servedTier = ServedTier.original,
    UnavailableKind? failure,
    bool storeFallbackUsed = false,
  }) {
    final key = _key(mediaId, thumbnail);
    _entries.remove(key);
    _entries[key] = ServingObservation(
      servedFrom: servedFrom,
      servedTier: servedTier,
      failure: failure,
      storeFallbackUsed: storeFallbackUsed,
      observedAt: _now(),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    notifyListeners();
  }

  ServingObservation? lastFor(String mediaId, {required bool thumbnail}) =>
      _entries[_key(mediaId, thumbnail)];
}
```

Create `lib/features/media/presentation/providers/media_serving_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/services/media_serving_recorder.dart';

/// Process-wide recorder. A plain Provider with a concrete default, so no
/// consumer test needs an override to construct a widget tree that renders
/// media.
final mediaServingRecorderProvider = Provider<MediaServingRecorder>(
  (ref) => MediaServingRecorder(),
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/services/media_serving_recorder_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/services/media_serving_recorder.dart \
        lib/features/media/presentation/providers/media_serving_providers.dart \
        test/features/media/data/services/media_serving_recorder_test.dart
git commit -m "Add MediaServingRecorder

A bounded LRU of how each item was most recently resolved. Deliberately a
plain ChangeNotifier rather than Riverpod state: every visible tile writes
here while scrolling, and routing that through provider state would rebuild
the grid. Ships one notifier rather than the spec's per-id listenables,
since a single info panel is the only consumer."
```

---

### Task 8: Record from mediaBytesProvider

**Files:**
- Modify: `lib/features/media/presentation/providers/media_bytes_providers.dart`
- Test: `test/features/media/presentation/providers/media_bytes_provider_provenance_test.dart` (create)

**Interfaces:**
- Consumes: `MediaServingRecorder.record`, `mediaServingRecorderProvider` from Task 7; all resolver stamps from Tasks 2 to 6.
- Produces: nothing new. `mediaBytesProvider`'s return type is unchanged.

`mediaBytesProvider` always resolves full-resolution bytes, so every call records with `thumbnail: false`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/providers/media_bytes_provider_provenance_test.dart`. Build a `ProviderContainer` overriding `mediaSourceResolverRegistryProvider` with a registry whose `localFile` resolver returns a stamped `BytesData`, and overriding `mediaServingRecorderProvider` with a recorder you hold a reference to. Read `test/features/media/presentation/providers/` for an existing container-based test to copy the override style and the `mediaStoreRuntimeProvider` handling from; do not guess at how the runtime provider is stubbed.

```dart
test('a native success is recorded with no store fallback', () async {
  final recorder = MediaServingRecorder();
  final container = ProviderContainer(
    overrides: [
      mediaServingRecorderProvider.overrideWithValue(recorder),
      // registry override returning
      //   BytesData(bytes: ..., servedFrom: ServedFrom.localDisk)
      // for MediaSourceType.localFile, plus whatever the existing
      // container tests do for mediaStoreRuntimeProvider.
    ],
  );
  addTearDown(container.dispose);

  await container.read(mediaBytesProvider(item).future);

  final obs = recorder.lastFor(item.id, thumbnail: false)!;
  expect(obs.servedFrom, ServedFrom.localDisk);
  expect(obs.storeFallbackUsed, isFalse);
  expect(obs.failure, isNull);
});

test('a total failure is recorded with the native failure kind', () async {
  // Registry resolver returns
  //   const UnavailableData(kind: UnavailableKind.notFound)
  // and the store runtime resolves to null.
  final obs = recorder.lastFor(item.id, thumbnail: false)!;
  expect(obs.servedFrom, isNull);
  expect(obs.failure, UnavailableKind.notFound);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/presentation/providers/media_bytes_provider_provenance_test.dart`
Expected: FAIL, "Null check operator used on a null value" from `lastFor(...)!` because nothing records yet.

- [ ] **Step 3: Write the implementation**

Rewrite the `mediaBytesProvider` body. The three exit points each record once, and the existing doc comment above the provider stays exactly as it is:

```dart
final mediaBytesProvider =
    FutureProvider.family<ResolvedAssetResult, MediaItem>((ref, item) async {
      final recorder = ref.read(mediaServingRecorderProvider);

      final native = await _resolveNative(ref, item);
      final bytes = await _bytesOf(native, item);
      if (bytes != null) {
        recorder.record(
          item.id,
          thumbnail: false,
          servedFrom: native.servedFrom,
          servedTier: native.servedTier,
        );
        return ResolvedAssetResult(
          bytes: bytes,
          status: ResolutionStatus.resolved,
        );
      }

      // The store is the cross-device path for reference-linked media: the
      // originating device holds the file, everyone else holds the row. Its
      // resolver self-gates on the upload stamps, so an item that was never
      // uploaded costs one null return rather than a fetch.
      final remote = await _resolveRemote(ref, item);
      final remoteBytes = await _bytesOf(remote, item);
      if (remoteBytes != null) {
        recorder.record(
          item.id,
          thumbnail: false,
          servedFrom: remote?.servedFrom,
          servedTier: remote?.servedTier ?? ServedTier.original,
          storeFallbackUsed: true,
        );
        return ResolvedAssetResult(
          bytes: remoteBytes,
          status: ResolutionStatus.resolved,
        );
      }

      recorder.record(
        item.id,
        thumbnail: false,
        failure: native is UnavailableData
            ? native.kind
            : UnavailableKind.notFound,
        storeFallbackUsed: true,
      );
      return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
    });
```

Add the import for `media_serving_providers.dart`. `media_source_data.dart` is already imported.

Note the third branch's `native is UnavailableData ? native.kind : UnavailableKind.notFound`: a native resolution can also produce a `NetworkData`, which this provider deliberately never fetches, and which therefore yields no bytes without being an `UnavailableData`. Collapsing that to `notFound` is the honest reading for a byte consumer, and matches the existing doc comment's reasoning about why `NetworkData` is not fetched here.

`storeFallbackUsed: true` on the failure branch is correct: the store WAS asked and could not help. It records that the fallback ran, not that it succeeded.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/presentation/providers/media_bytes_provider_provenance_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Verify existing consumers still pass**

Run: `flutter test test/features/media`
Expected: PASS, unchanged counts. `mediaServingRecorderProvider` is a plain `Provider` with a concrete default, so no existing test needs an override.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/providers/media_bytes_providers.dart \
        test/features/media/presentation/providers/media_bytes_provider_provenance_test.dart
git commit -m "Record serving provenance from mediaBytesProvider

All three exits record once. The failure branch sets storeFallbackUsed so
the panel can distinguish an item nothing could serve from one the store
was never asked about."
```

---

### Task 9: Record from MediaItemView

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart`
- Test: `test/features/media/presentation/widgets/media_item_view_provenance_test.dart` (create)

**Interfaces:**
- Consumes: everything from Tasks 1 and 7.
- Produces: nothing new. `_Resolution` gains a `storeFallbackUsed` field but stays private to the file.

This widget resolves either a thumbnail or an original depending on `widget.thumbnail`, and records with that same flag. It has seven return sites in `_resolve`; rather than recording at each, add `storeFallbackUsed` to the `_Resolution` record and record once in a wrapper. That keeps the recording logic in one place and makes a missed site a compile error rather than a silent gap.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/media_item_view_provenance_test.dart`. Read `test/features/media/presentation/widgets/` for the existing `MediaItemView` test harness and copy its `ProviderScope` override set exactly; this widget reads several providers and inventing the overrides will not work.

```dart
testWidgets('a thumbnail resolution records under the thumbnail key', (
  tester,
) async {
  final recorder = MediaServingRecorder();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaServingRecorderProvider.overrideWithValue(recorder),
        // registry override whose localFile resolver returns
        //   BytesData(bytes: <1x1 png>, servedFrom: ServedFrom.localDisk,
        //             servedTier: ServedTier.thumbnail)
        // plus the harness's existing overrides.
      ],
      child: MaterialApp(home: MediaItemView(item: item, thumbnail: true)),
    ),
  );
  await tester.pumpAndSettle();

  final obs = recorder.lastFor(item.id, thumbnail: true)!;
  expect(obs.servedFrom, ServedFrom.localDisk);
  expect(obs.servedTier, ServedTier.thumbnail);
  expect(obs.storeFallbackUsed, isFalse);
  expect(recorder.lastFor(item.id, thumbnail: false), isNull);
});

testWidgets('a store fallback is recorded as such', (tester) async {
  // Registry resolver returns UnavailableData(notFound); the item carries a
  // contentHash and remoteUploadedAt so storeConfirmed passes; the store
  // runtime's resolver returns
  //   FileData(file: ..., servedFrom: ServedFrom.storeNetwork)
  final obs = recorder.lastFor(item.id, thumbnail: false)!;
  expect(obs.servedFrom, ServedFrom.storeNetwork);
  expect(obs.storeFallbackUsed, isTrue);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/media_item_view_provenance_test.dart`
Expected: FAIL, "Null check operator used on a null value".

- [ ] **Step 3: Write the implementation**

First extend the `_Resolution` typedef, keeping its existing doc comment and adding a paragraph for the new field:

```dart
/// [storeFallbackUsed] records that the row's own source could not produce
/// bytes here and the media store was asked to cover. No resolver can report
/// this: it is a fact about the sequence of attempts, not about any single
/// one, and it is what lets the info panel say "the photo library lookup
/// failed" rather than merely "served from cloud".
typedef _Resolution = ({
  MediaSourceData data,
  bool videoPosterMissing,
  bool documentRenderable,
  bool storeFallbackUsed,
});
```

Rename the existing `_resolve()` method to `_resolveInner()`, changing nothing inside it except adding `storeFallbackUsed` to each of its seven returned records. Use `false` for the three returns reached before the store is consulted (the PDF branch, the `native is! UnavailableData` return, and the `!storeConfirmed` return) and `true` for the four reached at or after the store attempt (`runtime == null`, the `remote != null` success, the `videoPosterMissing` return, and the `catch (_)` return).

The `runtime == null` case is `true` on purpose: the fallback was attempted and there was no store on this device to answer it. That is a different situation from never having looked, and the panel distinguishes them.

Then add the recording wrapper, and point `initState` and `didUpdateWidget` at it instead of `_resolveInner`:

```dart
/// Resolves and records the outcome. Recording once here rather than at
/// each of [_resolveInner]'s seven exits means a new exit added later
/// cannot silently skip it: the record type makes it a compile error.
Future<_Resolution> _resolve() async {
  final resolution = await _resolveInner();
  final data = resolution.data;
  ref
      .read(mediaServingRecorderProvider)
      .record(
        widget.item.id,
        thumbnail: widget.thumbnail,
        servedFrom: data.servedFrom,
        servedTier: data.servedTier,
        failure: data is UnavailableData ? data.kind : null,
        storeFallbackUsed: resolution.storeFallbackUsed,
      );
  return resolution;
}
```

Finally, the PDF page-1 branch. It builds a fresh `BytesData` from a render rather than returning the resolver's own value, so it must carry the source resolution's provenance across. Capture it through the closure:

```dart
if (widget.thumbnail && widget.item.isPdf) {
  // thumbFor caches its render, so on a cache hit the source closure is
  // never called and sourceFrom stays null. That is the honest answer:
  // this render's bytes did not come from anywhere on this pass.
  ServedFrom? sourceFrom;
  final page1 = await ref
      .read(pdfThumbnailServiceProvider)
      .thumbFor(
        widget.item,
        source: () async {
          final resolved = await resolver.resolve(widget.item);
          sourceFrom = resolved.servedFrom;
          return resolved;
        },
      );
  if (page1 != null) {
    return (
      data: BytesData(
        bytes: page1,
        servedFrom: sourceFrom,
        servedTier: ServedTier.thumbnail,
      ),
      videoPosterMissing: false,
      documentRenderable: true,
      storeFallbackUsed: false,
    );
  }
  // No local render (bytes unavailable here, or an unreadable PDF):
  // fall through, which reaches the store's own page-1 thumb below.
}
```

Verify that `PdfThumbnailService.thumbFor`'s `source` parameter accepts an async closure returning `Future<MediaSourceData>`. If its declared type is a synchronous `MediaSourceData Function()`, do not change the service; instead drop the capture and pass `servedFrom: null` with a comment saying the render's source is not observable through this API. Read the signature before writing this step.

Add the import for `media_serving_providers.dart`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/media_item_view_provenance_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Run the full media suite**

Run: `flutter test test/features/media test/features/media_store`
Expected: PASS, unchanged counts from before this PR.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_item_view.dart \
        test/features/media/presentation/widgets/media_item_view_provenance_test.dart
git commit -m "Record serving provenance from MediaItemView

_Resolution gains storeFallbackUsed and recording happens once in a
wrapper, so a return site added later cannot skip it: the record type
makes omission a compile error. The PDF page-1 branch carries its source
resolution's provenance across the render."
```

---

### Task 10: Full verification

**Files:** none modified.

- [ ] **Step 1: Confirm the tree is clean and formatted**

Run: `dart format --set-exit-if-changed .`
Expected: exit 0, no files listed.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found." Analyze the whole project, not a subdirectory, and do not pipe the output through `tail` or `grep`: a pipe masks the exit code and CI treats infos as fatal.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: zero failures. Compare the pass count against the count on `origin/main` before this branch. This PR adds tests and changes no behavior, so the count should rise by exactly the number of tests added (23 across Tasks 1 to 9) and nothing should have moved from pass to fail.

- [ ] **Step 4: Confirm no schema or sync file was touched**

```bash
git diff --stat origin/main...HEAD -- lib/core/database lib/features/sync
```
Expected: empty output. This PR must not touch the schema or the sync engine. Any output here means something has drifted from the spec; stop and report it rather than proceeding.

- [ ] **Step 5: Confirm no em-dashes entered the diff**

```bash
git diff origin/main...HEAD | grep -n '^+.*—' || echo "clean"
```
Expected: "clean".

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin worktree-media-provenance
gh pr create --base main --title "Media provenance PR 1: the provenance channel" --body "$(cat <<'BODY'
First of three PRs implementing docs/superpowers/specs/2026-08-16-media-provenance-design.md.

Adds ServedFrom and ServedTier to MediaSourceData, stamps them at every
resolver production site, and records the outcome of real resolutions in a
bounded MediaServingRecorder.

No user-visible change. No schema change. This PR is pure plumbing so that
PR 2 can build a media info panel that reports where an item was linked
from, whether it is backed up, and where its bytes are actually coming
from, and PR 3 can put a combined status badge on the grids.

The load-bearing change is in MediaStoreResolver: its six success returns
were the only place in the app that knew a media-cache hit from a fresh
cloud download, and all six discarded that fact. Each new test empties the
object store between two reads, so a storeCache stamp on the second read
can only mean the cache actually served it.

Provenance is stamped on the value object at construction rather than
computed by consumers, so the two independent native-then-store fallback
paths (MediaItemView._resolve and mediaBytesProvider) inherit it without
either being rewritten and cannot disagree.
BODY
)"
```

Per project convention the PR body carries no attribution line and no session URL.

---

## Self-Review

**Spec coverage.** Spec section 5.1 (value object) is Task 1. Section 5.2's stamping table is Tasks 2 to 6, one task per resolver file except the two trivial ones grouped in Task 4; every row of that table is claimed. Section 5.3 (recorder) is Task 7, and its PDF pass-through requirement is Task 9 step 3. Sections 6, 7 and 8 belong to PRs 2 and 3 and are correctly absent. Section 9's "load-bearing test" is Task 6. Section 10's PR 1 row is this entire plan. No PR 1 requirement is unclaimed.

**Deviations, both deliberate and both stated at their point of use.** The recorder ships one `ChangeNotifier` instead of the spec's per-id `listenableFor` (Task 7, with reasoning). `UnavailableData` does not accept the provenance parameters, which the spec left implicit (Task 1, with reasoning).

**Type consistency.** `record` is called in Tasks 8 and 9 with exactly the parameter names Task 7 defines: `thumbnail`, `servedFrom`, `servedTier`, `failure`, `storeFallbackUsed`. `lastFor` is called with `thumbnail:` in Tasks 7, 8 and 9. `ServedFrom` and `ServedTier` member names are identical everywhere they appear. `_Resolution`'s four fields in Task 9 match the three existing plus the one added.

**Known-unverifiable steps, flagged rather than faked.** Task 3's gallery success paths (device-only), Task 8's and Task 9's provider override sets (the plan directs the implementer to read the existing harness rather than guessing), and Task 9's `PdfThumbnailService.thumbFor` signature (with an explicit fallback instruction if the closure cannot be async). These are the three places where the plan tells the implementer to look rather than telling them the answer, because the answer was not verifiable from the files read while planning.
