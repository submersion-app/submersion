# Storage Usage (Slice A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the user a page that shows, by category, how many bytes the app is holding on this device.

**Architecture:** A `StorageCategory` descriptor carries an id, a group, and a `measure()` closure that each category implements in its cheapest available form (an indexed `SUM` for the media cache, an FMTC-native call for tiles, a directory walk for the rest). `StorageInventory` builds the descriptor list from injected directory resolvers so it is testable without `path_provider`. A `FutureProvider.family` keyed by category id gives every row independent loading, so the page never blocks on its slowest measurement and one failing category cannot blank the page.

**Tech Stack:** Flutter, Riverpod 3 (manual providers, no codegen), Drift, `go_router`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-29-storage-reclamation-design.md`

## Global Constraints

- **Worktree:** all work happens in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-1375-storage-usage` on branch `worktree-issue-1375-storage-usage`. Never edit the main checkout.
- **Slice A is read-only.** No file is deleted that is not already deletable through existing UI. No cap is changed. No sweep is scheduled. `startup_page.dart` is not touched.
- **No em-dashes** (U+2014) in any output: code, comments, docs, commit messages. En-dashes as sentence punctuation and " - " as prose punctuation are equally forbidden. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **All 11 locales.** Every new ARB key goes into all ten non-English files, not just `app_en.arb`. `test/l10n/arb_parity_test.dart` fails otherwise.
- **File size:** 200 to 400 lines typical, 800 maximum.
- **Immutability:** never mutate objects or arrays.
- **`dart format .`** is run over the whole project before the final commit.
- **`measure()` returns `Future<int?>`.** `null` means genuinely unmeasurable and is not the same as zero.

---

## File Structure

**Create:**
- `lib/core/utils/byte_format.dart` - shared `formatBytes(int)`, extracted from the private copy in `sync_devices_page.dart`
- `lib/core/services/storage/directory_size.dart` - `measureDirectoryBytes`, `measureFileGroupBytes`, `measureLooseFilesBytes`
- `lib/core/services/storage/storage_category.dart` - `StorageGroup`, `StorageCategory`, `StorageCategoryId`
- `lib/core/services/storage/storage_inventory.dart` - builds the 14 descriptors from injected resolvers
- `lib/features/settings/presentation/providers/storage_usage_providers.dart` - `storageInventoryProvider`, `storageCategoriesProvider`, `storageCategorySizeProvider`
- `lib/features/settings/presentation/pages/storage_usage_page.dart` - the page

**Modify:**
- `lib/features/settings/presentation/pages/sync_devices_page.dart:342` - drop the private `_formatBytes`, import the shared one
- `lib/features/settings/presentation/pages/storage_settings_page.dart` - add a tile linking to the new page
- `lib/core/router/app_router.dart` - add the `storage-usage` route
- `lib/l10n/arb/app_*.arb` (11 files) - new keys

**Test:**
- `test/core/utils/byte_format_test.dart`
- `test/core/services/storage/directory_size_test.dart`
- `test/core/services/storage/storage_inventory_test.dart`
- `test/features/settings/presentation/pages/storage_usage_page_test.dart`

---

## Error semantics (read before Task 2)

Each `measure()` owns its own error policy. The split is deliberate:

- **A missing directory returns 0.** That is a true measurement: the directory holds no bytes.
- **A real I/O failure throws.** The provider surfaces it as an error in that one row. Swallowing it would report a falsely low total, and a falsely low total is worse than a visible error because the user acts on it.
- **`null` is reserved for structurally unmeasurable.** Two cases exist today: the tile cache when `TileCacheService` never initialized (startup swallows its failure at `startup_page.dart:666`), and an Android SAF backup location, which is a `content://` tree URI with no `Directory` to enumerate.

---

## Task 1: Shared byte formatter

**Files:**
- Create: `lib/core/utils/byte_format.dart`
- Test: `test/core/utils/byte_format_test.dart`
- Modify: `lib/features/settings/presentation/pages/sync_devices_page.dart` (remove private `_formatBytes` at :342, import shared)

**Interfaces:**
- Consumes: nothing
- Produces: `String formatBytes(int bytes)`

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/byte_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/byte_format.dart';

void main() {
  group('formatBytes', () {
    test('reports raw bytes below one kibibyte', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('switches to KB at one kibibyte', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
    });

    test('drops the decimal at ten units and above', () {
      expect(formatBytes(10 * 1024), '10 KB');
    });

    test('climbs through MB, GB and TB', () {
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
      expect(formatBytes(2 * 1024 * 1024 * 1024 * 1024), '2.0 TB');
    });

    test('a negative count is clamped to zero rather than formatted', () {
      expect(formatBytes(-1), '0 B');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/byte_format_test.dart`
Expected: FAIL, "Target of URI doesn't exist: package:submersion/core/utils/byte_format.dart".

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/utils/byte_format.dart`:

```dart
/// Formats a byte count for display.
///
/// Bytes are not a diver-facing unit, so this deliberately ignores the active
/// diver's unit settings: a megabyte is a megabyte in metric and imperial
/// alike. Sizes are a floor, since a source that reports no size counts zero.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/byte_format_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Migrate the existing caller**

In `lib/features/settings/presentation/pages/sync_devices_page.dart`, delete the private `_formatBytes` function (the whole function including its doc comment, at roughly line 341 to 351), add the import

```dart
import 'package:submersion/core/utils/byte_format.dart';
```

in the correct group (local package imports, alphabetical), and rename every `_formatBytes(` call site in that file to `formatBytes(`.

Find the call sites with: `grep -n "_formatBytes" lib/features/settings/presentation/pages/sync_devices_page.dart`

- [ ] **Step 6: Verify the migration compiles and its tests still pass**

Run: `flutter analyze lib/features/settings/presentation/pages/sync_devices_page.dart lib/core/utils/byte_format.dart`
Expected: "No issues found."

Run: `flutter test test/features/settings/ -r compact`
Expected: PASS, no new failures.

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/byte_format.dart test/core/utils/byte_format_test.dart lib/features/settings/presentation/pages/sync_devices_page.dart
git commit -m "refactor(settings): extract the byte formatter for reuse"
```

---

## Task 2: Directory measurement helpers

**Files:**
- Create: `lib/core/services/storage/directory_size.dart`
- Test: `test/core/services/storage/directory_size_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Future<int> measureDirectoryBytes(Directory dir)`
  - `Future<int> measureFileGroupBytes(Iterable<File> files)`
  - `Future<int> measureLooseFilesBytes(Directory dir, {required bool Function(String name) exclude})`

These are plain `test()` cases against real temporary directories, deliberately not `testWidgets`. Awaiting `dart:io` inside `testWidgets` parks forever with no output and no timeout firing.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/storage/directory_size_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/storage/directory_size.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_size_test');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<File> writeFile(String relative, int bytes) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    return file;
  }

  group('measureDirectoryBytes', () {
    test('sums every file in the tree, including nested ones', () async {
      await writeFile('a.bin', 100);
      await writeFile('nested/b.bin', 250);
      await writeFile('nested/deeper/c.bin', 50);

      expect(await measureDirectoryBytes(root), 400);
    });

    test('an empty directory measures zero', () async {
      expect(await measureDirectoryBytes(root), 0);
    });

    test('a directory that does not exist measures zero, not null', () async {
      final absent = Directory(p.join(root.path, 'never_created'));
      expect(await measureDirectoryBytes(absent), 0);
    });
  });

  group('measureFileGroupBytes', () {
    test('sums the files that exist and skips those that do not', () async {
      final present = await writeFile('db.sqlite', 300);
      final absent = File(p.join(root.path, 'db.sqlite-wal'));

      expect(await measureFileGroupBytes([present, absent]), 300);
    });
  });

  group('measureLooseFilesBytes', () {
    test('counts files in the top level only, never subdirectories', () async {
      await writeFile('export.csv', 100);
      await writeFile('Submersion/database.db', 9999);

      final total = await measureLooseFilesBytes(
        root,
        exclude: (name) => false,
      );

      expect(total, 100);
    });

    test('honours the exclusion predicate', () async {
      await writeFile('export.csv', 100);
      await writeFile('database.db', 500);

      final total = await measureLooseFilesBytes(
        root,
        exclude: (name) => name.startsWith('database.db'),
      );

      expect(total, 100);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/storage/directory_size_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/services/storage/directory_size.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Recursively sums the bytes held by every file under [dir].
///
/// A directory that does not exist measures zero: that is a true measurement,
/// not a failure. A real I/O error (a permission denial, say) is allowed to
/// throw, because reporting a falsely low total is worse than showing the user
/// an error on the row that failed.
Future<int> measureDirectoryBytes(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}

/// Sums a known set of files, skipping any that are absent.
///
/// Used for a database and its sidecars, where the `-wal` and `-shm` files
/// exist only while a connection is open.
Future<int> measureFileGroupBytes(Iterable<File> files) async {
  var total = 0;
  for (final file in files) {
    if (await file.exists()) {
      total += await file.length();
    }
  }
  return total;
}

/// Sums the files directly inside [dir], never descending into subdirectories,
/// skipping any whose basename [exclude] returns true for.
///
/// The Documents root needs this shape: exported files land loose at the top
/// level, while the database and the `Submersion/` subtree live alongside them
/// and must not be counted as exports.
Future<int> measureLooseFilesBytes(
  Directory dir, {
  required bool Function(String name) exclude,
}) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is! File) continue;
    if (exclude(p.basename(entity.path))) continue;
    total += await entity.length();
  }
  return total;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/storage/directory_size_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage/directory_size.dart test/core/services/storage/directory_size_test.dart
git commit -m "feat(storage): add directory and file measurement helpers"
```

---

## Task 3: The `StorageCategory` descriptor

**Files:**
- Create: `lib/core/services/storage/storage_category.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum StorageGroup { appData, mediaCache, caches, backups, temporary, exports }`
  - `class StorageCategory { final String id; final StorageGroup group; final Future<int?> Function() measure; }`
  - `abstract final class StorageCategoryId` with the 14 id constants

This task has no test of its own: it is a data holder with no behaviour, and Task 4 exercises it. Adding a test that asserts a constructor assigns its fields would be testing the language, not the code.

- [ ] **Step 1: Write the implementation**

Create `lib/core/services/storage/storage_category.dart`:

```dart
/// Where a storage category is shown on the usage page.
enum StorageGroup { appData, mediaCache, caches, backups, temporary, exports }

/// Stable category ids.
///
/// These key the l10n label, the size provider, and the reclaim policy that a
/// later slice adds. They are deliberately not derived from directory names:
/// a directory can be renamed without breaking a saved layout or a test, and
/// an id cannot.
abstract final class StorageCategoryId {
  static const database = 'database';
  static const localCache = 'localCache';
  static const mediaCacheOriginals = 'mediaCacheOriginals';
  static const mediaCacheThumbs = 'mediaCacheThumbs';
  static const mediaCacheRenditions = 'mediaCacheRenditions';
  static const mediaCacheStaging = 'mediaCacheStaging';
  static const mediaCacheTranscode = 'mediaCacheTranscode';
  static const mapTiles = 'mapTiles';
  static const networkImages = 'networkImages';
  static const videoThumbnails = 'videoThumbnails';
  static const pdfThumbnails = 'pdfThumbnails';
  static const backups = 'backups';
  static const temporary = 'temporary';
  static const exports = 'exports';
}

/// One place on disk where the app accumulates bytes.
///
/// Measurement cost is uneven by an order of magnitude across categories: the
/// media cache pools are a SUM over an index, the tile cache has a native size
/// call, and the rest need a recursive walk. Each category therefore brings its
/// own strategy rather than everything sharing one directory walk, and the page
/// renders each result as it arrives instead of being paced by the slowest.
class StorageCategory {
  const StorageCategory({
    required this.id,
    required this.group,
    required this.measure,
  });

  /// One of [StorageCategoryId].
  final String id;

  final StorageGroup group;

  /// Returns the bytes held, or null when the category is structurally
  /// unmeasurable on this platform or in this configuration. Null is not zero:
  /// an Android SAF backup location has no directory to enumerate, and
  /// reporting it as empty would tell the user their backups had vanished.
  final Future<int?> Function() measure;
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `flutter analyze lib/core/services/storage/storage_category.dart`
Expected: "No issues found."

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/storage/storage_category.dart
git commit -m "feat(storage): add the StorageCategory descriptor"
```

---

## Task 4: `StorageInventory`

**Files:**
- Create: `lib/core/services/storage/storage_inventory.dart`
- Test: `test/core/services/storage/storage_inventory_test.dart`

**Interfaces:**
- Consumes: `StorageCategory`, `StorageGroup`, `StorageCategoryId` (Task 3); `measureDirectoryBytes`, `measureFileGroupBytes`, `measureLooseFilesBytes` (Task 2)
- Produces: `class StorageInventory` with `List<StorageCategory> get categories`

Every external dependency is injected as a closure so the whole class is testable without `path_provider`, a real database, or an initialized FMTC store.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/storage/storage_inventory_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/services/storage/storage_inventory.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_inventory_test');
    support = Directory(p.join(root.path, 'support'));
    documents = Directory(p.join(root.path, 'documents'));
    temporary = Directory(p.join(root.path, 'temporary'));
    for (final dir in [support, documents, temporary]) {
      await dir.create(recursive: true);
    }
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> writeFile(String absolute, int bytes) async {
    final file = File(absolute);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0));
  }

  StorageInventory build({
    Future<int> Function(MediaCacheKind)? mediaCacheBytes,
    Future<double?> Function()? mapTileKibibytes,
    Future<int> Function()? networkImageBytes,
    Future<String?> Function()? backupsDirectoryPath,
    Future<String> Function()? databasePath,
  }) {
    return StorageInventory(
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      temporaryDirectory: () async => temporary,
      databasePath: databasePath ??
          () async => p.join(documents.path, 'submersion.db'),
      backupsDirectoryPath: backupsDirectoryPath ?? () async => null,
      mediaCacheBytes: mediaCacheBytes ?? (_) async => 0,
      mapTileKibibytes: mapTileKibibytes ?? () async => null,
      networkImageBytes: networkImageBytes ?? () async => 0,
    );
  }

  StorageCategory categoryFor(StorageInventory inventory, String id) =>
      inventory.categories.firstWhere((c) => c.id == id);

  test('exposes exactly the fourteen documented categories', () {
    final ids = build().categories.map((c) => c.id).toList();

    expect(ids, hasLength(14));
    expect(ids.toSet(), hasLength(14), reason: 'ids must be unique');
    expect(ids, contains(StorageCategoryId.database));
    expect(ids, contains(StorageCategoryId.exports));
  });

  test('the database category counts the file and its sidecars', () async {
    final dbPath = p.join(documents.path, 'submersion.db');
    await writeFile(dbPath, 100);
    await writeFile('$dbPath-wal', 40);
    await writeFile('$dbPath-shm', 10);

    final inventory = build(databasePath: () async => dbPath);

    expect(
      await categoryFor(inventory, StorageCategoryId.database).measure(),
      150,
    );
  });

  test('the local cache category measures submersion_local.db', () async {
    await writeFile(
      p.join(support.path, 'Submersion', 'submersion_local.db'),
      321,
    );

    expect(
      await categoryFor(build(), StorageCategoryId.localCache).measure(),
      321,
    );
  });

  test('each media cache pool reads its own indexed total', () async {
    final inventory = build(
      mediaCacheBytes: (kind) async => switch (kind) {
        MediaCacheKind.original => 1000,
        MediaCacheKind.thumb => 200,
        MediaCacheKind.rendition => 30,
      },
    );

    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.mediaCacheOriginals,
      ).measure(),
      1000,
    );
    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.mediaCacheThumbs,
      ).measure(),
      200,
    );
    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.mediaCacheRenditions,
      ).measure(),
      30,
    );
  });

  test('staging and transcode are walked, not read from the index', () async {
    final cache = p.join(support.path, 'Submersion', 'media_cache');
    await writeFile(p.join(cache, 'staging', 'stage_1'), 70);
    await writeFile(p.join(cache, 'transcode', 'abc_high.mp4'), 900);

    final inventory = build();

    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.mediaCacheStaging,
      ).measure(),
      70,
    );
    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.mediaCacheTranscode,
      ).measure(),
      900,
    );
  });

  test('map tiles convert the FMTC kibibyte reading into bytes', () async {
    final inventory = build(mapTileKibibytes: () async => 4.0);

    expect(
      await categoryFor(inventory, StorageCategoryId.mapTiles).measure(),
      4096,
    );
  });

  test('map tiles report null when the store never initialized', () async {
    final inventory = build(mapTileKibibytes: () async => null);

    expect(
      await categoryFor(inventory, StorageCategoryId.mapTiles).measure(),
      isNull,
    );
  });

  test('the thumbnail categories walk their own directories', () async {
    await writeFile(
      p.join(support.path, 'Submersion', 'video_thumbnails', 'a.img'),
      12,
    );
    await writeFile(
      p.join(support.path, 'Submersion', 'pdf_thumbnails', 'b.jpg'),
      34,
    );

    final inventory = build();

    expect(
      await categoryFor(
        inventory,
        StorageCategoryId.videoThumbnails,
      ).measure(),
      12,
    );
    expect(
      await categoryFor(inventory, StorageCategoryId.pdfThumbnails).measure(),
      34,
    );
  });

  test('backups measure the resolved directory when there is one', () async {
    final backups = p.join(documents.path, 'Submersion', 'Backups');
    await writeFile(p.join(backups, 'backup.db'), 500);

    final inventory = build(backupsDirectoryPath: () async => backups);

    expect(
      await categoryFor(inventory, StorageCategoryId.backups).measure(),
      500,
    );
  });

  test('backups report null when the location cannot be enumerated', () async {
    final inventory = build(backupsDirectoryPath: () async => null);

    expect(
      await categoryFor(inventory, StorageCategoryId.backups).measure(),
      isNull,
    );
  });

  test('temporary counts picked files and loose share files', () async {
    await writeFile(p.join(temporary.path, 'picked', '0', 'dives.zip'), 800);
    await writeFile(p.join(temporary.path, 'shared_photo.jpg'), 60);

    expect(
      await categoryFor(build(), StorageCategoryId.temporary).measure(),
      860,
    );
  });

  test('exports exclude the database, its sidecars and subdirectories',
      () async {
    final dbPath = p.join(documents.path, 'submersion.db');
    await writeFile(dbPath, 5000);
    await writeFile('$dbPath-wal', 400);
    await writeFile(p.join(documents.path, 'Submersion', 'Backups', 'b.db'), 9);
    await writeFile(p.join(documents.path, 'dives_export.csv'), 77);

    final inventory = build(databasePath: () async => dbPath);

    expect(
      await categoryFor(inventory, StorageCategoryId.exports).measure(),
      77,
    );
  });

  test('a database stored outside Documents leaves exports unaffected',
      () async {
    final elsewhere = Directory(p.join(root.path, 'elsewhere'));
    await elsewhere.create(recursive: true);
    final dbPath = p.join(elsewhere.path, 'submersion.db');
    await writeFile(dbPath, 5000);
    await writeFile(p.join(documents.path, 'dives_export.csv'), 77);

    final inventory = build(databasePath: () async => dbPath);

    expect(
      await categoryFor(inventory, StorageCategoryId.exports).measure(),
      77,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/storage/storage_inventory_test.dart`
Expected: FAIL, "Target of URI doesn't exist: .../storage_inventory.dart".

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/services/storage/storage_inventory.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/storage/directory_size.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Builds the list of places this app accumulates bytes on disk.
///
/// Every external dependency arrives as a closure rather than being looked up
/// internally, so the whole inventory is testable without path_provider, a real
/// database, or an initialized FMTC store.
class StorageInventory {
  StorageInventory({
    required Future<Directory> Function() supportDirectory,
    required Future<Directory> Function() documentsDirectory,
    required Future<Directory> Function() temporaryDirectory,
    required Future<String> Function() databasePath,
    required Future<String?> Function() backupsDirectoryPath,
    required Future<int> Function(MediaCacheKind kind) mediaCacheBytes,
    required Future<double?> Function() mapTileKibibytes,
    required Future<int> Function() networkImageBytes,
  }) : _supportDirectory = supportDirectory,
       _documentsDirectory = documentsDirectory,
       _temporaryDirectory = temporaryDirectory,
       _databasePath = databasePath,
       _backupsDirectoryPath = backupsDirectoryPath,
       _mediaCacheBytes = mediaCacheBytes,
       _mapTileKibibytes = mapTileKibibytes,
       _networkImageBytes = networkImageBytes;

  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<String> Function() _databasePath;
  final Future<String?> Function() _backupsDirectoryPath;
  final Future<int> Function(MediaCacheKind kind) _mediaCacheBytes;
  final Future<double?> Function() _mapTileKibibytes;
  final Future<int> Function() _networkImageBytes;

  /// Order is display order on the usage page.
  List<StorageCategory> get categories => [
    StorageCategory(
      id: StorageCategoryId.database,
      group: StorageGroup.appData,
      measure: _measureDatabase,
    ),
    StorageCategory(
      id: StorageCategoryId.localCache,
      group: StorageGroup.appData,
      measure: () async => measureFileGroupBytes([
        File(p.join((await _supportDirectory()).path, _appDir, _localCacheDb)),
      ]),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheOriginals,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.original),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheThumbs,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.thumb),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheRenditions,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.rendition),
    ),
    // Staging and transcode are walked rather than read from the index: the
    // LRU caps in MediaCacheStore are enforced only over rows in
    // media_cache_entries, and neither subdirectory is indexed. Their bytes are
    // invisible to the 3.25 GiB budget, which is precisely why they get rows.
    StorageCategory(
      id: StorageCategoryId.mediaCacheStaging,
      group: StorageGroup.mediaCache,
      measure: () => _measureSupportSubdirectory(['media_cache', 'staging']),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheTranscode,
      group: StorageGroup.mediaCache,
      measure: () => _measureSupportSubdirectory(['media_cache', 'transcode']),
    ),
    StorageCategory(
      id: StorageCategoryId.mapTiles,
      group: StorageGroup.caches,
      measure: _measureMapTiles,
    ),
    StorageCategory(
      id: StorageCategoryId.networkImages,
      group: StorageGroup.caches,
      measure: _networkImageBytes,
    ),
    StorageCategory(
      id: StorageCategoryId.videoThumbnails,
      group: StorageGroup.caches,
      measure: () => _measureSupportSubdirectory(['video_thumbnails']),
    ),
    StorageCategory(
      id: StorageCategoryId.pdfThumbnails,
      group: StorageGroup.caches,
      measure: () => _measureSupportSubdirectory(['pdf_thumbnails']),
    ),
    StorageCategory(
      id: StorageCategoryId.backups,
      group: StorageGroup.backups,
      measure: _measureBackups,
    ),
    StorageCategory(
      id: StorageCategoryId.temporary,
      group: StorageGroup.temporary,
      measure: _measureTemporary,
    ),
    StorageCategory(
      id: StorageCategoryId.exports,
      group: StorageGroup.exports,
      measure: _measureExports,
    ),
  ];

  static const _appDir = 'Submersion';
  static const _localCacheDb = 'submersion_local.db';

  Future<int?> _measureDatabase() async {
    final path = await _databasePath();
    return measureFileGroupBytes([
      File(path),
      File('$path-wal'),
      File('$path-shm'),
    ]);
  }

  Future<int?> _measureSupportSubdirectory(List<String> segments) async {
    final support = await _supportDirectory();
    return measureDirectoryBytes(
      Directory(p.joinAll([support.path, _appDir, ...segments])),
    );
  }

  /// FMTC reports kibibytes as a double. Converting here rather than at the
  /// call site keeps every category's contract in bytes.
  Future<int?> _measureMapTiles() async {
    final kibibytes = await _mapTileKibibytes();
    if (kibibytes == null) return null;
    return (kibibytes * 1024).round();
  }

  Future<int?> _measureBackups() async {
    final path = await _backupsDirectoryPath();
    if (path == null) return null;
    return measureDirectoryBytes(Directory(path));
  }

  Future<int?> _measureTemporary() async {
    final temp = await _temporaryDirectory();
    return measureDirectoryBytes(temp);
  }

  /// Loose files in the Documents root, which is where saveAndShareFile leaves
  /// every export permanently. The database may or may not live here depending
  /// on the configured location, so it is excluded by name either way, as are
  /// its sidecars and every subdirectory.
  Future<int?> _measureExports() async {
    final documents = await _documentsDirectory();
    final dbName = p.basename(await _databasePath());
    return measureLooseFilesBytes(
      documents,
      exclude: (name) => name.startsWith(dbName),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/storage/storage_inventory_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage/storage_inventory.dart test/core/services/storage/storage_inventory_test.dart
git commit -m "feat(storage): build the storage category inventory"
```

---

## Task 5: Providers

**Files:**
- Create: `lib/features/settings/presentation/providers/storage_usage_providers.dart`

**Interfaces:**
- Consumes: `StorageInventory` (Task 4), `StorageCategory` (Task 3)
- Produces:
  - `final storageInventoryProvider = Provider<StorageInventory>(...)`
  - `final storageCategoriesProvider = Provider<List<StorageCategory>>(...)`
  - `final storageCategorySizeProvider = FutureProvider.family<int?, String>(...)`

The family keyed by id, rather than one future over the whole list, is what gives each row independent loading and stops one throwing category from blanking the page.

This task has no dedicated test: the providers are wiring over code Task 4 already covers, and Task 7's widget tests override `storageCategorySizeProvider` directly. Constructing the real inventory in a unit test would require `path_provider`, which is exactly the dependency Task 4's injection exists to avoid.

- [ ] **Step 1: Write the implementation**

Create `lib/features/settings/presentation/providers/storage_usage_providers.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/services/storage/storage_inventory.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';

/// The real inventory, wired to path_provider and the live services.
final storageInventoryProvider = Provider<StorageInventory>((ref) {
  return StorageInventory(
    supportDirectory: getApplicationSupportDirectory,
    documentsDirectory: getApplicationDocumentsDirectory,
    temporaryDirectory: getTemporaryDirectory,
    databasePath: () =>
        ref.read(databaseLocationServiceProvider).getDatabasePath(),
    backupsDirectoryPath: _resolveBackupsDirectoryPath,
    mediaCacheBytes: (kind) async {
      final support = await getApplicationSupportDirectory();
      final store = MediaCacheStore(
        database: LocalCacheDatabaseService.instance.database,
        root: Directory(p.join(support.path, 'Submersion', 'media_cache')),
      );
      return store.totalBytes(kind);
    },
    mapTileKibibytes: _resolveMapTileKibibytes,
    networkImageBytes: () => CachedNetworkImageDiagnostics().cacheSize(),
  );
});

/// The descriptor list. Pure construction, so a plain Provider.
final storageCategoriesProvider = Provider<List<StorageCategory>>(
  (ref) => ref.watch(storageInventoryProvider).categories,
);

/// One future per category, keyed by [StorageCategory.id].
///
/// Keyed rather than a single future over the whole list so every row loads
/// independently: the media cache pools resolve instantly off an index while
/// the network image walk can take seconds, and a category that throws shows an
/// error on its own row instead of blanking the page.
final storageCategorySizeProvider = FutureProvider.family<int?, String>((
  ref,
  id,
) {
  final category = ref
      .watch(storageCategoriesProvider)
      .firstWhere((c) => c.id == id);
  return category.measure();
});

/// Returns null when the backup location cannot be enumerated as a directory.
///
/// An Android SAF location is a content:// tree URI with no Directory behind
/// it. Reporting it as zero bytes would tell the user their backups had
/// vanished, so it reports unavailable instead.
Future<String?> _resolveBackupsDirectoryPath() async {
  final prefs = await SharedPreferences.getInstance();
  final location = BackupPreferences(prefs).getSettings().backupLocation;
  if (location != null && location.startsWith('content://')) return null;
  if (location != null && location.isNotEmpty) return location;
  return BackupService.resolveDefaultBackupsDirectory();
}

/// Returns null when the tile store never initialized.
///
/// Startup swallows a tile cache initialization failure (startup_page.dart
/// around line 666), so an uninitialized store is a normal state rather than a
/// bug, and getTotalCacheSize would throw a StateError on it.
Future<double?> _resolveMapTileKibibytes() async {
  try {
    return await TileCacheService.instance.getTotalCacheSize();
  } on StateError {
    return null;
  }
}
```

- [ ] **Step 2: Verify the imports and provider names resolve**

Run: `flutter analyze lib/features/settings/presentation/providers/storage_usage_providers.dart`
Expected: "No issues found."

`databaseLocationServiceProvider` is confirmed to live at
`lib/features/settings/presentation/providers/storage_providers.dart:69`, which
is why that file is imported above. Reuse it rather than adding a new provider.

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/presentation/providers/storage_usage_providers.dart
git commit -m "feat(storage): add storage usage providers"
```

---

## Task 6: Localisation keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale files

**Interfaces:**
- Consumes: nothing
- Produces: the l10n getters Task 7 calls, all of the form `settings_storageUsage_*`

All eleven files, not just English. `test/l10n/arb_parity_test.dart` asserts every English key exists in all ten non-English locales, and it reports the failure against every locale at once, which makes a partial fanout look like a much larger problem than it is.

- [ ] **Step 1: Add the English keys**

Insert these into `lib/l10n/arb/app_en.arb`, keeping the file's existing alphabetical-by-key ordering within its section. None of them take placeholders, so no `@key` metadata blocks are needed.

```json
"settings_storageUsage_appBar_title": "Storage Usage",
"settings_storageUsage_tile_title": "Storage Usage",
"settings_storageUsage_tile_subtitle": "See what is using space on this device",
"settings_storageUsage_total": "Total",
"settings_storageUsage_totalPartial": "Total so far",
"settings_storageUsage_refresh_tooltip": "Recalculate",
"settings_storageUsage_unavailable": "Not available",
"settings_storageUsage_measureFailed": "Could not measure",
"settings_storageUsage_group_appData": "App Data",
"settings_storageUsage_group_mediaCache": "Media Cache",
"settings_storageUsage_group_caches": "Caches",
"settings_storageUsage_group_backups": "Backups",
"settings_storageUsage_group_temporary": "Temporary Files",
"settings_storageUsage_group_exports": "Exported Files",
"settings_storageUsage_category_database": "Dive log database",
"settings_storageUsage_category_localCache": "Local cache database",
"settings_storageUsage_category_mediaCacheOriginals": "Original photos and videos",
"settings_storageUsage_category_mediaCacheThumbs": "Thumbnails",
"settings_storageUsage_category_mediaCacheRenditions": "Video renditions",
"settings_storageUsage_category_mediaCacheStaging": "Staged transfers",
"settings_storageUsage_category_mediaCacheTranscode": "Transcoded video",
"settings_storageUsage_category_mapTiles": "Map tiles",
"settings_storageUsage_category_networkImages": "Network images",
"settings_storageUsage_category_videoThumbnails": "Video thumbnails",
"settings_storageUsage_category_pdfThumbnails": "Document thumbnails",
"settings_storageUsage_category_backups": "Backup files",
"settings_storageUsage_category_temporary": "Temporary files",
"settings_storageUsage_category_exports": "Exported files",
```

- [ ] **Step 2: Translate into all ten other locales**

Add the same 28 keys, translated, to each of: `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`.

Translate the values properly for each language. Do not copy the English strings across. Arabic and Hebrew are right-to-left; Flutter handles the direction, so translate the text normally.

- [ ] **Step 3: Regenerate the localizations**

Run: `flutter gen-l10n`
Expected: completes with no error; `lib/l10n/arb/app_localizations.dart` and the eleven per-locale files are rewritten.

- [ ] **Step 4: Verify parity**

Run: `flutter test test/l10n/arb_parity_test.dart`
Expected: PASS. A failure naming missing keys against every locale means the fanout is incomplete, not that English has too many.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): add storage usage strings in all locales"
```

---

## Task 7: The Storage usage page

**Files:**
- Create: `lib/features/settings/presentation/pages/storage_usage_page.dart`
- Test: `test/features/settings/presentation/pages/storage_usage_page_test.dart`

**Interfaces:**
- Consumes: `storageCategoriesProvider`, `storageCategorySizeProvider` (Task 5); `StorageGroup`, `StorageCategoryId` (Task 3); `formatBytes` (Task 1); the l10n keys (Task 6)
- Produces: `class StorageUsagePage extends ConsumerWidget`

Two traps are designed against rather than discovered:

- The test font renders one em per glyph, so a `Row` of label plus size overflows a 360px surface unless the label is `Flexible`. Every row is built that way from the start.
- Widget tests override `storageCategorySizeProvider` so that no real `dart:io` runs. Awaiting real file I/O inside `testWidgets` parks forever with no output and no timeout firing.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/pages/storage_usage_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/features/settings/presentation/pages/storage_usage_page.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget harness({required Map<String, Future<int?>> sizes}) {
    return ProviderScope(
      overrides: [
        storageCategorySizeProvider.overrideWith(
          (ref, id) => sizes[id] ?? Future<int?>.value(0),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StorageUsagePage(),
      ),
    );
  }

  testWidgets('renders a row for every category', (tester) async {
    await tester.pumpWidget(harness(sizes: {}));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorageUsagePage)),
    );
    final expected = container.read(storageCategoriesProvider).length;

    expect(find.byType(StorageUsageRow), findsNWidgets(expected));
  });

  testWidgets('shows a formatted size once a category resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.database: Future<int?>.value(1536),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.5 KB'), findsOneWidget);
  });

  testWidgets('a null measurement reads as unavailable, never as zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.backups: Future<int?>.value(null),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('a failing category errors on its own row and its siblings '
      'still resolve', (tester) async {
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.networkImages: Future<int?>.error(
            const FileSystemException('denied'),
          ),
          StorageCategoryId.database: Future<int?>.value(2048),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not measure'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('the total sums only the categories that resolved', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.database: Future<int?>.value(1024),
          StorageCategoryId.localCache: Future<int?>.value(1024),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('a row does not overflow at a narrow width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.mediaCacheOriginals: Future<int?>.value(
            5 * 1024 * 1024 * 1024,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

Note on the total test: every unlisted category defaults to `0`, so a total of exactly 2048 bytes proves the sum, and `'2.0 KB'` appearing once rather than three times proves the two 1024-byte rows render as `'1.0 KB'`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/storage_usage_page_test.dart`
Expected: FAIL, "Target of URI doesn't exist: .../storage_usage_page.dart".

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/settings/presentation/pages/storage_usage_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reports how many bytes the app holds on this device, by category.
///
/// Read-only by design. Nothing on this page deletes anything: the categories
/// that can be reclaimed today are reclaimed from the pages that already own
/// that action, and the ones that cannot be reclaimed safely at all are shown
/// here precisely so the user can decide for themselves.
class StorageUsagePage extends ConsumerWidget {
  const StorageUsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(storageCategoriesProvider);
    final grouped = <StorageGroup, List<StorageCategory>>{};
    for (final category in categories) {
      grouped.putIfAbsent(category.group, () => []).add(category);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_storageUsage_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.settings_storageUsage_refresh_tooltip,
            onPressed: () {
              for (final category in categories) {
                ref.invalidate(storageCategorySizeProvider(category.id));
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _TotalHeader(categories: categories),
          for (final group in StorageGroup.values)
            if (grouped[group] != null) ...[
              _GroupHeader(group: group),
              for (final category in grouped[group]!)
                StorageUsageRow(category: category),
            ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// The running total across every category that has resolved so far.
///
/// Labelled as partial while any category is still measuring, because a total
/// that silently grows as rows land would read as a wrong number rather than an
/// incomplete one.
class _TotalHeader extends ConsumerWidget {
  const _TotalHeader({required this.categories});

  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    var total = 0;
    var pending = false;
    for (final category in categories) {
      final size = ref.watch(storageCategorySizeProvider(category.id));
      switch (size) {
        case AsyncData(:final value?):
          total += value;
        case AsyncData():
          break;
        case AsyncError():
          break;
        default:
          pending = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pending
                ? context.l10n.settings_storageUsage_totalPartial
                : context.l10n.settings_storageUsage_total,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(formatBytes(total), style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final StorageGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        _labelFor(context, group),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _labelFor(BuildContext context, StorageGroup group) {
    final l10n = context.l10n;
    return switch (group) {
      StorageGroup.appData => l10n.settings_storageUsage_group_appData,
      StorageGroup.mediaCache => l10n.settings_storageUsage_group_mediaCache,
      StorageGroup.caches => l10n.settings_storageUsage_group_caches,
      StorageGroup.backups => l10n.settings_storageUsage_group_backups,
      StorageGroup.temporary => l10n.settings_storageUsage_group_temporary,
      StorageGroup.exports => l10n.settings_storageUsage_group_exports,
    };
  }
}

/// One category's row.
///
/// The label is Flexible on purpose: the test font renders one em per glyph, so
/// a fixed label beside a size overflows a 360px surface.
class StorageUsageRow extends ConsumerWidget {
  const StorageUsageRow({required this.category, super.key});

  final StorageCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = ref.watch(storageCategorySizeProvider(category.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              _labelFor(context, category.id),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          _SizeLabel(size: size),
        ],
      ),
    );
  }

  static String _labelFor(BuildContext context, String id) {
    final l10n = context.l10n;
    return switch (id) {
      StorageCategoryId.database =>
        l10n.settings_storageUsage_category_database,
      StorageCategoryId.localCache =>
        l10n.settings_storageUsage_category_localCache,
      StorageCategoryId.mediaCacheOriginals =>
        l10n.settings_storageUsage_category_mediaCacheOriginals,
      StorageCategoryId.mediaCacheThumbs =>
        l10n.settings_storageUsage_category_mediaCacheThumbs,
      StorageCategoryId.mediaCacheRenditions =>
        l10n.settings_storageUsage_category_mediaCacheRenditions,
      StorageCategoryId.mediaCacheStaging =>
        l10n.settings_storageUsage_category_mediaCacheStaging,
      StorageCategoryId.mediaCacheTranscode =>
        l10n.settings_storageUsage_category_mediaCacheTranscode,
      StorageCategoryId.mapTiles =>
        l10n.settings_storageUsage_category_mapTiles,
      StorageCategoryId.networkImages =>
        l10n.settings_storageUsage_category_networkImages,
      StorageCategoryId.videoThumbnails =>
        l10n.settings_storageUsage_category_videoThumbnails,
      StorageCategoryId.pdfThumbnails =>
        l10n.settings_storageUsage_category_pdfThumbnails,
      StorageCategoryId.backups => l10n.settings_storageUsage_category_backups,
      StorageCategoryId.temporary =>
        l10n.settings_storageUsage_category_temporary,
      StorageCategoryId.exports => l10n.settings_storageUsage_category_exports,
      _ => id,
    };
  }
}

class _SizeLabel extends StatelessWidget {
  const _SizeLabel({required this.size});

  final AsyncValue<int?> size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return switch (size) {
      AsyncData(:final value?) => Text(
        formatBytes(value),
        style: theme.textTheme.bodyMedium,
      ),
      AsyncData() => Text(
        context.l10n.settings_storageUsage_unavailable,
        style: muted,
      ),
      AsyncError() => Text(
        context.l10n.settings_storageUsage_measureFailed,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      _ => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/pages/storage_usage_page_test.dart`
Expected: PASS, 6 tests.

If the loading spinner keeps a `pumpAndSettle` from ever settling, the override is returning a future that never completes; check the harness returns `Future<int?>.value(0)` for unlisted ids.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/storage_usage_page.dart test/features/settings/presentation/pages/storage_usage_page_test.dart
git commit -m "feat(settings): add the storage usage page"
```

---

## Task 8: Route and entry point

**Files:**
- Modify: `lib/core/router/app_router.dart` (near the existing `storage` route, around line 982)
- Modify: `lib/features/settings/presentation/pages/storage_settings_page.dart`

**Interfaces:**
- Consumes: `StorageUsagePage` (Task 7), the l10n tile keys (Task 6)
- Produces: the named route `storageUsage` at path `storage-usage`

- [ ] **Step 1: Add the route**

In `lib/core/router/app_router.dart`, add the import

```dart
import 'package:submersion/features/settings/presentation/pages/storage_usage_page.dart';
```

alongside the existing `storage_settings_page.dart` import, then add this `GoRoute` immediately after the existing `storage` route:

```dart
GoRoute(
  path: 'storage-usage',
  name: 'storageUsage',
  builder: (context, state) => const StorageUsagePage(),
),
```

- [ ] **Step 2: Add the entry tile**

In `lib/features/settings/presentation/pages/storage_settings_page.dart`, add a tile just before the Danger Zone block in `build`. The surrounding code is:

```dart
                // Danger Zone
                const SizedBox(height: 16),
```

Insert immediately above that comment:

```dart
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: Text(context.l10n.settings_storageUsage_tile_title),
                  subtitle: Text(
                    context.l10n.settings_storageUsage_tile_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('storageUsage'),
                ),
```

If `context.pushNamed` is not already available in that file, add

```dart
import 'package:go_router/go_router.dart';
```

to the package import group.

- [ ] **Step 3: Verify it analyzes and the existing page tests still pass**

Run: `flutter analyze lib/core/router/app_router.dart lib/features/settings/presentation/pages/storage_settings_page.dart`
Expected: "No issues found."

Run: `flutter test test/features/settings/presentation/pages/ -r compact`
Expected: PASS, no new failures. `storage_settings_reset_test.dart`, `storage_settings_pick_failure_test.dart` and `storage_settings_custom_folder_subtitle_test.dart` all build this page, so a missing l10n key or a bad import shows up here.

- [ ] **Step 4: Check the file size ceiling**

Run: `wc -l lib/features/settings/presentation/pages/storage_settings_page.dart`
Expected: under 800. It was 754 before this task, and the tile adds about 11 lines.

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/settings/presentation/pages/storage_settings_page.dart
git commit -m "feat(settings): link the storage usage page from storage settings"
```

---

## Task 9: Whole-project verification

**Files:** none created; this task proves the branch is releasable.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: reports the files it changed. Formatting the whole project, not just the touched files, is the project rule.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found."

Do not pipe this through `grep` or `head`. A pipe returns the exit status of the last command in the pipeline, which masks an analyzer failure. Infos count as failures in CI, so a clean run means zero output of any severity.

- [ ] **Step 3: Run the full test suite once**

Run: `flutter test -r compact`
Expected: all tests pass.

One full run is sufficient before a PR. Do not overlap it with another local test run: concurrent runs fake a lone failure. If a test fails, rerun that file alone before believing it.

- [ ] **Step 4: Commit any formatting churn**

```bash
git add -u
git commit -m "style: dart format"
```

Skip this step if `git status` is clean. Stage with `git add -u` rather than `git add -A`, and only after confirming `git status` shows nothing from a sibling worktree.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin worktree-issue-1375-storage-usage
```

PR title: `feat(storage): show on-device storage usage by category`

PR body: summarise the slice, link the spec, state that it is read-only, and reference `#1375` without closing it, since slices B through E remain. No Claude Code attribution line and no session URL.

---

## Self-Review

**Spec coverage.** Every Slice A requirement in the spec maps to a task: the `StorageCategory` contract to Task 3, all 14 categories with their per-category strategies to Task 4, the provider family to Task 5, the page and its four render states to Task 7, the shared byte formatter to Task 1, the eleven-locale fanout to Task 6, and the new-page-rather-than-append constraint to Task 8 Step 4. The spec's two named test traps (the Ahem-font row overflow and real I/O under `testWidgets`) are designed into Tasks 7 and 2 respectively rather than left to be rediscovered.

**Slices B through E** are documented in the spec and deliberately have no tasks here.

**Type consistency.** `measure` is `Future<int?> Function()` in Task 3, Task 4 and the Task 5 family. `formatBytes(int)` is defined in Task 1 and called in Task 7. `StorageCategoryId` constants are defined in Task 3 and consumed by name in Tasks 4 and 7. `mapTileKibibytes` returns `Future<double?>` in both the Task 4 constructor and the Task 5 wiring, and the kibibyte-to-byte conversion happens once, inside `_measureMapTiles`.

**Identifiers verified.** Every API this plan calls was read from the tree before being written down: `MediaCacheStore.totalBytes` and `MediaCacheKind` (`media_cache_store.dart:240`), `TileCacheService.getTotalCacheSize` (`tile_cache_service.dart:387`, which returns kibibytes as a `double`, hence the conversion in `_measureMapTiles`), `CachedNetworkImageDiagnostics.cacheSize` (`cached_network_image_diagnostics.dart:41`), `BackupService.resolveDefaultBackupsDirectory` (`backup_service.dart:1147`), `DatabaseLocationService.getDatabasePath` (`database_location_service.dart:120`) reached through `databaseLocationServiceProvider` (`storage_providers.dart:69`), and the `context.l10n` extension (`lib/l10n/l10n_extension.dart`).
