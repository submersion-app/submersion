# Cross-Device Photo Resolution Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable photos linked to dives to display correctly when the Submersion database is synced to a different device (Mac to iPhone, etc.) by resolving platform-specific gallery asset IDs locally on each device.

**Architecture:** A separate local-only Drift database (`submersion_local.db`) caches per-device asset ID mappings. New "resolved" providers sit between the widget layer and the existing raw-asset providers, transparently resolving cross-device IDs via tiered metadata matching (filename+timestamp, then dimensions). Existing raw providers are preserved for the photo picker flow.

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod, photo_manager package

**Spec:** `docs/superpowers/specs/2026-03-13-cross-device-photo-resolution-design.md`

---

## Chunk 1: Local Cache Database and Repository

### Task 1: Create the Local Cache Drift Database

**Files:**

- Create: `lib/core/database/local_cache_database.dart`

- [ ] **Step 1: Create the Drift database definition**

```dart
import 'package:drift/drift.dart';

part 'local_cache_database.g.dart';

/// Local-only table for caching resolved asset IDs per device.
/// This table is NOT synced — it lives in a separate database file.
class LocalAssetCache extends Table {
  TextColumn get mediaId => text()();
  TextColumn get localAssetId => text().nullable()();
  IntColumn get resolvedAt => integer()();
  TextColumn get resolutionMethod => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaId};
}

@DriftDatabase(tables: [LocalAssetCache])
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 2: Run build_runner to generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `local_cache_database.g.dart` generated successfully

- [ ] **Step 3: Commit**

```bash
git add lib/core/database/local_cache_database.dart lib/core/database/local_cache_database.g.dart
git commit -m "feat: add local cache Drift database for cross-device asset resolution"
```

---

### Task 2: Create LocalCacheDatabaseService

**Files:**

- Create: `lib/core/services/local_cache_database_service.dart`
- Reference: `lib/core/services/database_service.dart` (for pattern reference — similar singleton, but for the local cache DB)

- [ ] **Step 1: Create the service singleton**

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/database/local_cache_database.dart';

/// Singleton service managing the local-only cache database.
///
/// This database is stored in getApplicationSupportDirectory() and is
/// never synced between devices. It holds per-device asset ID mappings
/// for cross-device photo resolution.
class LocalCacheDatabaseService {
  LocalCacheDatabaseService._();

  static final LocalCacheDatabaseService instance =
      LocalCacheDatabaseService._();

  LocalCacheDatabase? _database;

  LocalCacheDatabase get database {
    if (_database == null) {
      throw StateError(
        'Local cache database not initialized. Call initialize() first.',
      );
    }
    return _database!;
  }

  /// For testing only: allows injecting a test database
  @visibleForTesting
  void setTestDatabase(LocalCacheDatabase db) {
    _database = db;
  }

  /// For testing only: resets the database instance
  @visibleForTesting
  void resetForTesting() {
    _database = null;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'Submersion', 'submersion_local.db');

    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final file = File(dbPath);
    _database = LocalCacheDatabase(NativeDatabase(file));
  }

  Future<void> close() async {
    if (_database == null) return;
    try {
      await _database!.close().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore close errors
    } finally {
      _database = null;
    }
  }

  /// On both iOS and macOS, getApplicationSupportDirectory() returns a
  /// path inside ~/Library/Application Support/ (macOS) or
  /// <sandbox>/Library/Application Support/ (iOS). Neither location is
  /// synced by iCloud Drive — iCloud only syncs the iCloud Drive folder
  /// and app-specific iCloud containers. No explicit
  /// NSURLIsExcludedFromBackupKey is needed for Application Support.
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/services/local_cache_database_service.dart
git commit -m "feat: add LocalCacheDatabaseService singleton for local cache lifecycle"
```

---

### Task 3: Create LocalAssetCacheRepository

**Files:**

- Create: `lib/features/media/data/repositories/local_asset_cache_repository.dart`
- Create: `test/features/media/data/repositories/local_asset_cache_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late LocalAssetCacheRepository repository;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repository = LocalAssetCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  group('LocalAssetCacheRepository', () {
    test('getCachedAssetId returns null for unknown mediaId', () async {
      final result = await repository.getCachedAssetId('unknown-id');
      expect(result, isNull);
    });

    test('cacheResolution stores and retrieves a resolved asset ID', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      final result = await repository.getCachedAssetId('media-1');
      expect(result, equals('local-asset-abc'));
    });

    test('cacheResolution stores null for unresolved entries', () async {
      await repository.cacheResolution(
        mediaId: 'media-2',
        localAssetId: null,
        method: 'unresolved',
      );

      final entry = await repository.getCacheEntry('media-2');
      expect(entry, isNotNull);
      expect(entry!.localAssetId, isNull);
      expect(entry.resolutionMethod, equals('unresolved'));
    });

    test('clearEntry removes a cached entry', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      await repository.clearEntry('media-1');

      final result = await repository.getCachedAssetId('media-1');
      expect(result, isNull);
    });

    test('isExpired returns true for unresolved entry past backoff', () async {
      // Create an unresolved entry with resolved_at in the past
      final pastTime = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;

      await db
          .into(db.localAssetCache)
          .insert(LocalAssetCacheCompanion.insert(
            mediaId: 'media-old',
            resolvedAt: pastTime,
            resolutionMethod: 'unresolved',
            attemptCount: Value(0),
          ));

      final expired = await repository.isExpired('media-old');
      expect(expired, isTrue);
    });

    test('isExpired returns false for resolved entry', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: 'local-asset-abc',
        method: 'original_id',
      );

      final expired = await repository.isExpired('media-1');
      expect(expired, isFalse);
    });

    test('incrementAttempt increases attempt_count', () async {
      await repository.cacheResolution(
        mediaId: 'media-1',
        localAssetId: null,
        method: 'unresolved',
      );

      await repository.incrementAttempt('media-1');

      final entry = await repository.getCacheEntry('media-1');
      expect(entry!.attemptCount, equals(1));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/repositories/local_asset_cache_repository_test.dart`
Expected: FAIL — `local_asset_cache_repository.dart` does not exist

- [ ] **Step 3: Write the repository implementation**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Cache entry with all fields for inspection.
class CacheEntry {
  final String mediaId;
  final String? localAssetId;
  final int resolvedAt;
  final String resolutionMethod;
  final int attemptCount;

  const CacheEntry({
    required this.mediaId,
    this.localAssetId,
    required this.resolvedAt,
    required this.resolutionMethod,
    required this.attemptCount,
  });
}

/// Repository for the local asset resolution cache.
///
/// Provides CRUD operations on the local_asset_cache table.
/// This table is device-local and never synced.
class LocalAssetCacheRepository {
  LocalCacheDatabase get _db =>
      LocalCacheDatabaseService.instance.database;

  /// Escalating backoff intervals for unresolved entries.
  static const _backoffDurations = [
    Duration(hours: 24),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// Get the cached local asset ID for a media item.
  /// Returns null if no cache entry exists.
  Future<String?> getCachedAssetId(String mediaId) async {
    final row = await (_db.select(_db.localAssetCache)
          ..where((t) => t.mediaId.equals(mediaId)))
        .getSingleOrNull();
    return row?.localAssetId;
  }

  /// Get the full cache entry for inspection/testing.
  Future<CacheEntry?> getCacheEntry(String mediaId) async {
    final row = await (_db.select(_db.localAssetCache)
          ..where((t) => t.mediaId.equals(mediaId)))
        .getSingleOrNull();
    if (row == null) return null;

    return CacheEntry(
      mediaId: row.mediaId,
      localAssetId: row.localAssetId,
      resolvedAt: row.resolvedAt,
      resolutionMethod: row.resolutionMethod,
      attemptCount: row.attemptCount,
    );
  }

  /// Cache a resolution result (resolved or unresolved).
  Future<void> cacheResolution({
    required String mediaId,
    required String? localAssetId,
    required String method,
  }) async {
    await _db.into(_db.localAssetCache).insertOnConflictUpdate(
      LocalAssetCacheCompanion.insert(
        mediaId: mediaId,
        localAssetId: Value(localAssetId),
        resolvedAt: DateTime.now().millisecondsSinceEpoch,
        resolutionMethod: method,
        attemptCount: const Value(0),
      ),
    );
  }

  /// Remove a cached entry (e.g., when re-resolution is needed).
  Future<void> clearEntry(String mediaId) async {
    await (_db.delete(_db.localAssetCache)
          ..where((t) => t.mediaId.equals(mediaId)))
        .go();
  }

  /// Check if an unresolved entry has exceeded its backoff period.
  /// Returns false for resolved entries (they never expire).
  Future<bool> isExpired(String mediaId) async {
    final entry = await getCacheEntry(mediaId);
    if (entry == null) return true;
    if (entry.localAssetId != null) return false; // Resolved entries don't expire

    final backoffIndex = entry.attemptCount.clamp(0, _backoffDurations.length - 1);
    final backoff = _backoffDurations[backoffIndex];
    final resolvedAt = DateTime.fromMillisecondsSinceEpoch(entry.resolvedAt);

    return DateTime.now().isAfter(resolvedAt.add(backoff));
  }

  /// Increment the attempt count for an unresolved entry.
  Future<void> incrementAttempt(String mediaId) async {
    final entry = await getCacheEntry(mediaId);
    if (entry == null) return;

    await (_db.update(_db.localAssetCache)
          ..where((t) => t.mediaId.equals(mediaId)))
        .write(LocalAssetCacheCompanion(
          attemptCount: Value(entry.attemptCount + 1),
          resolvedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/repositories/local_asset_cache_repository_test.dart`
Expected: All 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/local_asset_cache_repository.dart test/features/media/data/repositories/local_asset_cache_repository_test.dart
git commit -m "feat: add LocalAssetCacheRepository with CRUD and backoff logic"
```

---

### Task 4: Initialize Local Cache DB at App Startup

**Files:**

- Modify: `lib/main.dart:81` (add initialization after main DB init)

- [ ] **Step 1: Add LocalCacheDatabaseService initialization**

In `lib/main.dart`, add the import at the top:

```dart
import 'package:submersion/core/services/local_cache_database_service.dart';
```

After line 81 (`await DatabaseService.instance.initialize(...)`) add:

```dart
  // Initialize local-only cache database (device-specific, never synced)
  await LocalCacheDatabaseService.instance.initialize();
```

- [ ] **Step 2: Run the app to verify startup works**

Run: `flutter run -d macos`
Expected: App launches without errors

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize local cache database at app startup"
```

---

## Chunk 2: Asset Resolution Service

### Task 5: Create AssetResolutionService

**Files:**

- Create: `lib/features/media/data/services/asset_resolution_service.dart`
- Create: `test/features/media/data/services/asset_resolution_service_test.dart`
- Reference: `lib/features/media/data/services/photo_picker_service.dart` (for `AssetInfo`, `PhotoPickerService`)
- Reference: `lib/features/media/domain/entities/media_item.dart` (for `MediaItem`)
- Reference: `lib/features/media/data/repositories/local_asset_cache_repository.dart`

- [ ] **Step 1: Write failing tests for the resolution logic**

The service is hard to unit test against real `photo_manager` calls, so we test the matching logic and cache interaction with mockable dependencies. Add `@GenerateMocks` for the dependencies.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

@GenerateMocks([LocalAssetCacheRepository, PhotoPickerService])
import 'asset_resolution_service_test.mocks.dart';

void main() {
  late MockLocalAssetCacheRepository mockCache;
  late MockPhotoPickerService mockPicker;
  late AssetResolutionService service;

  setUp(() {
    mockCache = MockLocalAssetCacheRepository();
    mockPicker = MockPhotoPickerService();
    service = AssetResolutionService(
      cacheRepository: mockCache,
      photoPickerService: mockPicker,
    );
  });

  MediaItem createTestItem({
    String id = 'media-1',
    String? platformAssetId = 'original-asset-id',
    String? originalFilename = 'IMG_001.jpg',
    DateTime? takenAt,
    int width = 4032,
    int height = 3024,
  }) {
    return MediaItem(
      id: id,
      platformAssetId: platformAssetId,
      originalFilename: originalFilename,
      mediaType: MediaType.photo,
      takenAt: takenAt ?? DateTime(2025, 6, 15, 10, 30, 0),
      width: width,
      height: height,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('resolveAssetId', () {
    test('returns cached ID when cache hit exists', () async {
      when(mockCache.getCachedAssetId('media-1'))
          .thenAnswer((_) async => 'cached-local-id');
      when(mockCache.isExpired('media-1'))
          .thenAnswer((_) async => false);

      final result = await service.resolveAssetId(createTestItem());

      expect(result.localAssetId, equals('cached-local-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
      verifyNever(mockPicker.getAssetsInDateRange(any, any));
    });

    test('returns null with unresolved status when cache has unexpired unresolved entry', () async {
      when(mockCache.getCachedAssetId('media-1'))
          .thenAnswer((_) async => null);
      when(mockCache.getCacheEntry('media-1'))
          .thenAnswer((_) async => const CacheEntry(
                mediaId: 'media-1',
                localAssetId: null,
                resolvedAt: 0,
                resolutionMethod: 'unresolved',
                attemptCount: 0,
              ));
      when(mockCache.isExpired('media-1'))
          .thenAnswer((_) async => false);

      final result = await service.resolveAssetId(createTestItem());

      expect(result.localAssetId, isNull);
      expect(result.status, equals(ResolutionStatus.unavailable));
    });

    test('returns platformAssetId for desktop platforms', () async {
      when(mockPicker.supportsGalleryBrowsing).thenReturn(false);

      final item = createTestItem();
      final result = await service.resolveAssetId(item);

      expect(result.localAssetId, equals('original-asset-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
    });
  });

  group('matchByFilenameAndTimestamp (tier 1)', () {
    test('matches single asset with same filename and close timestamp', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'local-match',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
        AssetInfo(
          id: 'local-other',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 2),
          width: 4032,
          height: 3024,
          filename: 'IMG_002.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByFilenameAndTimestamp(
        item,
        candidates,
      );

      expect(match, equals('local-match'));
    });

    test('returns null when multiple assets match filename', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'dup-1',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
        AssetInfo(
          id: 'dup-2',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 2),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByFilenameAndTimestamp(
        item,
        candidates,
      );

      expect(match, isNull);
    });
  });

  group('matchByTimestampAndDimensions (tier 2)', () {
    test('matches single asset with same dimensions and tight timestamp', () {
      final item = createTestItem(
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
        width: 4032,
        height: 3024,
      );

      final candidates = [
        AssetInfo(
          id: 'dim-match',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'different.jpg',
        ),
        AssetInfo(
          id: 'dim-miss',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 1920,
          height: 1080,
          filename: 'other.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByTimestampAndDimensions(
        item,
        candidates,
      );

      expect(match, equals('dim-match'));
    });

    test('returns null when timestamp exceeds 2-second window', () {
      final item = createTestItem(
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
        width: 4032,
        height: 3024,
      );

      final candidates = [
        AssetInfo(
          id: 'too-far',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 4),
          width: 4032,
          height: 3024,
          filename: 'file.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByTimestampAndDimensions(
        item,
        candidates,
      );

      expect(match, isNull);
    });
  });
}
```

- [ ] **Step 2: Run build_runner then run tests to verify they fail**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/media/data/services/asset_resolution_service_test.dart`
Expected: FAIL — `asset_resolution_service.dart` does not exist

- [ ] **Step 3: Write the AssetResolutionService implementation**

```dart
import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Status of an asset resolution attempt.
enum ResolutionStatus {
  /// Asset ID was resolved successfully (from cache, original ID, or matching).
  resolved,

  /// No matching asset found on this device.
  unavailable,
}

/// Result of resolving a media item's asset ID on the current device.
class ResolutionResult {
  final String? localAssetId;
  final ResolutionStatus status;

  const ResolutionResult({
    this.localAssetId,
    required this.status,
  });
}

/// Service for resolving cross-device photo asset IDs.
///
/// When a database is synced from another device, the platformAssetId
/// values won't resolve locally. This service finds the matching local
/// asset by metadata (filename, timestamp, dimensions) and caches the
/// mapping for future lookups.
///
/// Gallery query coalescing: when multiple photos from the same dive
/// trigger resolution concurrently (e.g., opening a dive with 20 photos),
/// the service caches gallery query results by time range so only one
/// actual gallery scan is performed. The cache is short-lived (30 seconds)
/// to cover the burst of concurrent provider evaluations.
class AssetResolutionService {
  final LocalAssetCacheRepository _cacheRepository;
  final PhotoPickerService _photoPickerService;
  final _log = LoggerService.forClass(AssetResolutionService);

  /// In-flight resolution futures keyed by mediaId to prevent duplicate work.
  final Map<String, Future<ResolutionResult>> _pendingResolutions = {};

  /// Short-lived cache of gallery query results to coalesce concurrent queries.
  /// Keyed by a time-range bucket string (start~end in ms epoch).
  final Map<String, _GalleryQueryCacheEntry> _galleryQueryCache = {};

  AssetResolutionService({
    required LocalAssetCacheRepository cacheRepository,
    required PhotoPickerService photoPickerService,
  }) : _cacheRepository = cacheRepository,
       _photoPickerService = photoPickerService;

  /// Resolve the local asset ID for a media item.
  ///
  /// Resolution order:
  /// 1. Check local cache
  /// 2. Try original platformAssetId (works on originating device)
  /// 3. Search gallery by metadata (tiered matching)
  Future<ResolutionResult> resolveAssetId(MediaItem item) async {
    // Desktop platforms don't use gallery asset IDs
    if (!_photoPickerService.supportsGalleryBrowsing) {
      return ResolutionResult(
        localAssetId: item.platformAssetId,
        status: ResolutionStatus.resolved,
      );
    }

    if (item.platformAssetId == null) {
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    // Check cache first
    final cachedId = await _cacheRepository.getCachedAssetId(item.id);
    if (cachedId != null) {
      return ResolutionResult(
        localAssetId: cachedId,
        status: ResolutionStatus.resolved,
      );
    }

    // Check if we have an unexpired unresolved entry
    final cacheEntry = await _cacheRepository.getCacheEntry(item.id);
    if (cacheEntry != null && cacheEntry.localAssetId == null) {
      final expired = await _cacheRepository.isExpired(item.id);
      if (!expired) {
        return const ResolutionResult(status: ResolutionStatus.unavailable);
      }
    }

    // Deduplicate concurrent resolution requests for the same media
    if (_pendingResolutions.containsKey(item.id)) {
      return _pendingResolutions[item.id]!;
    }

    final future = _resolveFromGallery(item);
    _pendingResolutions[item.id] = future;

    try {
      return await future;
    } finally {
      _pendingResolutions.remove(item.id);
    }
  }

  /// Attempt to resolve by trying the original ID, then metadata matching.
  Future<ResolutionResult> _resolveFromGallery(MediaItem item) async {
    _log.info('Resolving asset for media ${item.id}');

    // Step 2: Try original platformAssetId
    final originalWorks = await _verifyAssetLoadable(item.platformAssetId!);
    if (originalWorks) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: item.platformAssetId!,
        method: 'original_id',
      );
      _log.info('Resolved via original ID: ${item.platformAssetId}');
      return ResolutionResult(
        localAssetId: item.platformAssetId,
        status: ResolutionStatus.resolved,
      );
    }

    // Step 3: Search gallery by metadata (with query coalescing)
    final timeWindow = const Duration(seconds: 5);
    final start = item.takenAt.subtract(timeWindow);
    final end = item.takenAt.add(timeWindow);

    List<AssetInfo> candidates;
    try {
      candidates = await _getAssetsCoalesced(start, end);
    } catch (e) {
      _log.error('Gallery query failed for media ${item.id}', e);
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    if (candidates.isEmpty) {
      await _cacheUnresolved(item.id);
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    // Tier 1: filename + timestamp
    final tier1Match = matchByFilenameAndTimestamp(item, candidates);
    if (tier1Match != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: tier1Match,
        method: 'filename_timestamp',
      );
      _log.info('Resolved via filename+timestamp: $tier1Match');
      return ResolutionResult(
        localAssetId: tier1Match,
        status: ResolutionStatus.resolved,
      );
    }

    // Tier 2: timestamp + dimensions
    final tier2Match = matchByTimestampAndDimensions(item, candidates);
    if (tier2Match != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: tier2Match,
        method: 'timestamp_dimensions',
      );
      _log.info('Resolved via timestamp+dimensions: $tier2Match');
      return ResolutionResult(
        localAssetId: tier2Match,
        status: ResolutionStatus.resolved,
      );
    }

    // Tier 3: unresolved
    await _cacheUnresolved(item.id);
    _log.info('Could not resolve media ${item.id} — marked unresolved');
    return const ResolutionResult(status: ResolutionStatus.unavailable);
  }

  /// Verify that a platformAssetId actually loads on this device.
  Future<bool> _verifyAssetLoadable(String assetId) async {
    try {
      final thumbnail = await _photoPickerService.getThumbnail(
        assetId,
        size: 50,
      );
      return thumbnail != null && thumbnail.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheUnresolved(String mediaId) async {
    final cacheEntry = await _cacheRepository.getCacheEntry(mediaId);
    if (cacheEntry != null && cacheEntry.resolutionMethod == 'unresolved') {
      // Existing unresolved entry — increment attempt count
      await _cacheRepository.incrementAttempt(mediaId);
    } else {
      // New unresolved entry
      await _cacheRepository.cacheResolution(
        mediaId: mediaId,
        localAssetId: null,
        method: 'unresolved',
      );
    }
  }

  /// Get gallery assets for a time range, coalescing concurrent queries.
  ///
  /// When opening a dive with many photos, all providers fire near-simultaneously
  /// with overlapping time windows. This method caches the gallery query results
  /// for 30 seconds so only one actual gallery scan is performed per time window.
  Future<List<AssetInfo>> _getAssetsCoalesced(
    DateTime start,
    DateTime end,
  ) async {
    // Round to 1-minute buckets to maximize cache hits across photos
    // from the same dive (whose ±5s windows will overlap heavily)
    final bucketStart = DateTime(
      start.year, start.month, start.day,
      start.hour, start.minute,
    );
    final bucketEnd = DateTime(
      end.year, end.month, end.day,
      end.hour, end.minute + 1,
    );
    final cacheKey =
        '${bucketStart.millisecondsSinceEpoch}~${bucketEnd.millisecondsSinceEpoch}';

    // Check for a valid cached result
    final cached = _galleryQueryCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    // Query the gallery and cache the result
    final results = await _photoPickerService.getAssetsInDateRange(
      bucketStart,
      bucketEnd,
    );
    _galleryQueryCache[cacheKey] = _GalleryQueryCacheEntry(
      results: results,
      createdAt: DateTime.now(),
    );

    // Prune expired entries to prevent memory leaks
    _galleryQueryCache.removeWhere((_, entry) => entry.isExpired);

    return results;
  }

  /// Tier 1: Match by original filename and timestamp within +/-5 seconds.
  /// Returns the matching asset ID, or null if zero or multiple matches.
  static String? matchByFilenameAndTimestamp(
    MediaItem item,
    List<AssetInfo> candidates,
  ) {
    if (item.originalFilename == null) return null;

    final matches = candidates.where((c) {
      if (c.filename != item.originalFilename) return false;
      final diff = c.createDateTime.difference(item.takenAt).abs();
      return diff <= const Duration(seconds: 5);
    }).toList();

    return matches.length == 1 ? matches.first.id : null;
  }

  /// Tier 2: Match by dimensions and timestamp within +/-2 seconds.
  /// Returns the matching asset ID, or null if zero or multiple matches.
  static String? matchByTimestampAndDimensions(
    MediaItem item,
    List<AssetInfo> candidates,
  ) {
    if (item.width == null || item.height == null) return null;

    final matches = candidates.where((c) {
      if (c.width != item.width || c.height != item.height) return false;
      final diff = c.createDateTime.difference(item.takenAt).abs();
      return diff <= const Duration(seconds: 2);
    }).toList();

    return matches.length == 1 ? matches.first.id : null;
  }
}

/// Short-lived cache entry for gallery query results.
/// Expires after 30 seconds — long enough to cover the burst of
/// concurrent provider evaluations when opening a dive detail page.
class _GalleryQueryCacheEntry {
  final List<AssetInfo> results;
  final DateTime createdAt;

  static const _ttl = Duration(seconds: 30);

  _GalleryQueryCacheEntry({
    required this.results,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(createdAt.add(_ttl));
}
```

- [ ] **Step 4: Run build_runner then run tests to verify they pass**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/media/data/services/asset_resolution_service_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/services/asset_resolution_service.dart test/features/media/data/services/asset_resolution_service_test.dart test/features/media/data/services/asset_resolution_service_test.mocks.dart
git commit -m "feat: add AssetResolutionService with tiered matching and cache"
```

---

## Chunk 3: Resolved Providers and Placeholder Widget

### Task 6: Create the Resolved Asset Providers

**Files:**

- Create: `lib/features/media/presentation/providers/resolved_asset_providers.dart`
- Reference: `lib/features/media/presentation/providers/photo_picker_providers.dart` (existing raw providers — keep unchanged)
- Reference: `lib/features/media/data/services/asset_resolution_service.dart`

- [ ] **Step 1: Create the resolved providers**

```dart
import 'dart:typed_data';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// Provider for the asset resolution service (singleton).
final assetResolutionServiceProvider = Provider<AssetResolutionService>((ref) {
  return AssetResolutionService(
    cacheRepository: LocalAssetCacheRepository(),
    photoPickerService: ref.watch(photoPickerServiceProvider),
  );
});

/// Result type for resolved asset loading.
/// Wraps either loaded bytes or an unavailable status.
class ResolvedAssetResult {
  final Uint8List? bytes;
  final ResolutionStatus status;

  const ResolvedAssetResult({this.bytes, required this.status});

  bool get isAvailable => status == ResolutionStatus.resolved && bytes != null;
  bool get isUnavailable => status == ResolutionStatus.unavailable;
}

/// Resolved thumbnail provider for displaying already-linked media.
///
/// Resolves the media item's asset ID on the current device via
/// AssetResolutionService, then loads the thumbnail.
/// Use this instead of assetThumbnailProvider for display contexts.
final resolvedThumbnailProvider =
    FutureProvider.family<ResolvedAssetResult, MediaItem>((ref, item) async {
  final service = ref.watch(assetResolutionServiceProvider);
  final resolution = await service.resolveAssetId(item);

  if (resolution.status == ResolutionStatus.unavailable ||
      resolution.localAssetId == null) {
    return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
  }

  final pickerService = ref.watch(photoPickerServiceProvider);
  final bytes = await pickerService.getThumbnail(resolution.localAssetId!);

  // If cached ID no longer loads, the photo was deleted — clear cache
  if (bytes == null) {
    final cache = LocalAssetCacheRepository();
    await cache.clearEntry(item.id);
    return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
  }

  return ResolvedAssetResult(
    bytes: bytes,
    status: ResolutionStatus.resolved,
  );
});

/// Resolved full-resolution provider for photo viewer.
///
/// Same pattern as resolvedThumbnailProvider but loads full-res bytes.
final resolvedFullResolutionProvider =
    FutureProvider.family<ResolvedAssetResult, MediaItem>((ref, item) async {
  final service = ref.watch(assetResolutionServiceProvider);
  final resolution = await service.resolveAssetId(item);

  if (resolution.status == ResolutionStatus.unavailable ||
      resolution.localAssetId == null) {
    return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
  }

  final pickerService = ref.watch(photoPickerServiceProvider);
  final bytes = await pickerService.getFileBytes(resolution.localAssetId!);

  if (bytes == null) {
    final cache = LocalAssetCacheRepository();
    await cache.clearEntry(item.id);
    return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
  }

  return ResolvedAssetResult(
    bytes: bytes,
    status: ResolutionStatus.resolved,
  );
});

/// Resolved file path provider for video playback.
final resolvedFilePathProvider =
    FutureProvider.family<String?, MediaItem>((ref, item) async {
  final service = ref.watch(assetResolutionServiceProvider);
  final resolution = await service.resolveAssetId(item);

  if (resolution.status == ResolutionStatus.unavailable ||
      resolution.localAssetId == null) {
    return null;
  }

  final pickerService = ref.watch(photoPickerServiceProvider);
  return pickerService.getFilePath(resolution.localAssetId!);
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/media/presentation/providers/resolved_asset_providers.dart
git commit -m "feat: add resolved asset providers for cross-device photo display"
```

---

### Task 7: Create the Unavailable Photo Placeholder Widget

**Files:**

- Create: `lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart`
- Reference: `lib/features/media/presentation/widgets/dive_media_section.dart:499-515` (existing `_OrphanedPlaceholder` — similar pattern but distinct visuals)

- [ ] **Step 1: Create the placeholder widget**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Placeholder shown when a photo exists in the database but cannot be
/// found in this device's photo gallery. Distinct from the orphaned
/// placeholder (which means the photo was deleted).
class UnavailablePhotoPlaceholder extends StatelessWidget {
  const UnavailablePhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.media_unavailablePlaceholder_notOnDevice,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen version of the unavailable placeholder for the photo viewer.
class UnavailablePhotoFullScreen extends StatelessWidget {
  const UnavailablePhotoFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Colors.white.withValues(alpha: 0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.media_unavailablePlaceholder_notOnDevice,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add l10n key to `lib/l10n/arb/app_en.arb`**

Add the following key (alphabetically near other `media_` keys):

```json
"media_unavailablePlaceholder_notOnDevice": "Not on this device"
```

- [ ] **Step 3: Run l10n generation**

Run: `flutter gen-l10n`
Expected: Localization files regenerated

- [ ] **Step 4: Commit**

```bash
git add lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat: add unavailable photo placeholder widget and l10n key"
```

---

## Chunk 4: Widget Migration

### Task 8: Migrate dive_media_section.dart

**Files:**

- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart:365,459`

- [ ] **Step 1: Add imports**

Add to the imports at the top of the file:

```dart
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_photo_placeholder.dart';
```

- [ ] **Step 2: Update `_MediaThumbnailContent.build` to use resolved provider**

Replace the `_buildAssetThumbnail` method (lines ~457-488) with a version that uses `resolvedThumbnailProvider`:

In `_MediaThumbnailContent.build`, change the condition at line 365:

```dart
// Before:
else if (item.platformAssetId != null)
  _buildAssetThumbnail(ref, colorScheme)
else
  _buildPlaceholder(colorScheme),

// After:
else if (item.platformAssetId != null)
  _buildResolvedThumbnail(ref, colorScheme)
else
  _buildPlaceholder(colorScheme),
```

Replace `_buildAssetThumbnail` method with:

```dart
Widget _buildResolvedThumbnail(WidgetRef ref, ColorScheme colorScheme) {
  final resultAsync = ref.watch(resolvedThumbnailProvider(item));

  return resultAsync.when(
    data: (result) {
      if (result.isUnavailable) {
        return const UnavailablePhotoPlaceholder();
      }
      if (result.bytes == null) {
        return _buildPlaceholder(colorScheme);
      }
      return Image.memory(
        result.bytes!,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stack) =>
            _buildPlaceholder(colorScheme),
      );
    },
    loading: () => Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    error: (error, stack) => _buildPlaceholder(colorScheme),
  );
}
```

Remove the old `_buildAssetThumbnail` method.

- [ ] **Step 3: Run the app and verify dive media thumbnails load**

Run: `flutter run -d macos`
Expected: Photos display in the dive detail media section

- [ ] **Step 4: Commit**

```bash
git add lib/features/media/presentation/widgets/dive_media_section.dart
git commit -m "refactor: migrate dive_media_section to resolved thumbnail provider"
```

---

### Task 9: Migrate photo_viewer_page.dart

**Files:**

- Modify: `lib/features/media/presentation/pages/photo_viewer_page.dart:215,332,431,522`

- [ ] **Step 1: Add imports**

Add to the imports:

```dart
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_photo_placeholder.dart';
```

- [ ] **Step 2: Update `_shareCurrentPhoto` (line ~215)**

Change the null check and provider call:

```dart
// Before:
if (item.platformAssetId == null) {
  _showError(l10n.media_photoViewer_cannotShare);
  return;
}
// ...
final bytes = await ref.read(
  assetFullResolutionProvider(item.platformAssetId!).future,
);

// After:
final resolvedResult = await ref.read(
  resolvedFullResolutionProvider(item).future,
);
if (resolvedResult.isUnavailable || resolvedResult.bytes == null) {
  _showError(l10n.media_photoViewer_cannotShare);
  if (mounted) Navigator.of(context, rootNavigator: true).pop();
  return;
}
final bytes = resolvedResult.bytes;
```

Remove the earlier `platformAssetId == null` check since the resolved provider handles it.

- [ ] **Step 3: Update `_PhotoItem.build` (line ~424-431)**

```dart
// Before:
if (item.platformAssetId == null) {
  return const Center(
    child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
  );
}
final imageAsync = ref.watch(
  assetFullResolutionProvider(item.platformAssetId!),
);
return imageAsync.when(
  data: (bytes) {
    if (bytes == null) { ... }
    ...
  },

// After:
final imageAsync = ref.watch(resolvedFullResolutionProvider(item));
return imageAsync.when(
  data: (result) {
    if (result.isUnavailable) {
      return const UnavailablePhotoFullScreen();
    }
    if (result.bytes == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }
    return PhotoView(
      imageProvider: MemoryImage(result.bytes!),
      ...
    );
  },
```

- [ ] **Step 4: Update `_VideoItem._initializeVideo` (line ~512-522)**

```dart
// Before:
if (widget.item.platformAssetId == null) { ... }
final path = await ref.read(
  assetFilePathProvider(widget.item.platformAssetId!).future,
);

// After:
final path = await ref.read(
  resolvedFilePathProvider(widget.item).future,
);
```

Remove the `platformAssetId == null` check — resolved provider handles it (returns null path).

- [ ] **Step 5: Update cache invalidation after metadata write (line ~332)**

```dart
// Before:
ref.invalidate(assetFullResolutionProvider(item.platformAssetId!));

// After:
ref.invalidate(resolvedFullResolutionProvider(item));
```

- [ ] **Step 6: Run the app and verify photo viewer works**

Run: `flutter run -d macos`
Expected: Full-screen photo viewer displays photos, share works, video playback works

- [ ] **Step 7: Commit**

```bash
git add lib/features/media/presentation/pages/photo_viewer_page.dart
git commit -m "refactor: migrate photo_viewer_page to resolved asset providers"
```

---

### Task 10: Migrate trip_photo_viewer_page.dart

**Files:**

- Modify: `lib/features/media/presentation/pages/trip_photo_viewer_page.dart:203,218,297,304`

- [ ] **Step 1: Add imports**

```dart
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_photo_placeholder.dart';
```

- [ ] **Step 2: Update `_shareCurrentPhoto` (line ~203-218)**

Same pattern as photo_viewer_page — use `resolvedFullResolutionProvider(item)` instead of raw provider. Replace the `platformAssetId == null` check with resolved provider result check.

- [ ] **Step 3: Update `_PhotoItem.build` (line ~297-304)**

Same pattern as photo_viewer_page — use `resolvedFullResolutionProvider(item)` and `UnavailablePhotoFullScreen()`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/media/presentation/pages/trip_photo_viewer_page.dart
git commit -m "refactor: migrate trip_photo_viewer_page to resolved asset providers"
```

---

### Task 11: Migrate trip_photo_section.dart and trip_gallery_page.dart

**Files:**

- Modify: `lib/features/trips/presentation/widgets/trip_photo_section.dart:267`
- Modify: `lib/features/trips/presentation/pages/trip_gallery_page.dart:418`

- [ ] **Step 1: Update trip_photo_section.dart**

Add import and change `_buildAssetThumbnail` method to use `resolvedThumbnailProvider(item)` instead of `assetThumbnailProvider(item.platformAssetId!)`. Add `UnavailablePhotoPlaceholder` for unavailable results.

Follow the same pattern used in dive_media_section.dart Task 8.

- [ ] **Step 2: Update trip_gallery_page.dart**

Add import and change `_buildAssetThumbnail` method to use `resolvedThumbnailProvider(item)` instead of `assetThumbnailProvider(item.platformAssetId!)`. Add `UnavailablePhotoPlaceholder` for unavailable results.

Follow the same pattern used in dive_media_section.dart Task 8.

- [ ] **Step 3: Run the app and verify trip galleries work**

Run: `flutter run -d macos`
Expected: Trip photo section and gallery display photos correctly

- [ ] **Step 4: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_photo_section.dart lib/features/trips/presentation/pages/trip_gallery_page.dart
git commit -m "refactor: migrate trip photo widgets to resolved asset providers"
```

---

## Chunk 5: Final Verification

### Task 12: Run Full Test Suite and Format

**Files:**

- All modified and new files

- [ ] **Step 1: Format all code**

Run: `dart format lib/ test/`
Expected: No formatting changes needed (or changes applied)

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No errors or warnings

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All existing tests pass, new tests pass

- [ ] **Step 4: Manual verification on device**

Test these scenarios:
1. Open a dive with linked photos — thumbnails load correctly
2. Open full-screen photo viewer — photos display with zoom
3. Share a photo from the viewer
4. Open a trip gallery — photos display correctly
5. Video playback works in photo viewer

- [ ] **Step 5: Final commit if any formatting/analyzer fixes were needed**

```bash
git add -A
git commit -m "chore: format and fix lint for cross-device photo resolution"
```
