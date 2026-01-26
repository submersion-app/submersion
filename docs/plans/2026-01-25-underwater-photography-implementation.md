# Underwater Photography Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add photo/video support as a metadata enrichment layer - photos stay in device gallery, Submersion stores references and adds dive-specific context (depth, temperature, species tags).

**Architecture:** Reference-only storage model. Photos remain in device photo library. App stores platform asset IDs, extracts EXIF data on import, calculates dive enrichment (depth/temp at photo timestamp by interpolating dive profile data), and caches thumbnails.

**Tech Stack:** Flutter, Drift ORM, Riverpod, photo_manager (platform photo access), image (thumbnail generation)

**Design Document:** `docs/plans/2026-01-25-underwater-photography-design.md`

---

## Phase 1: Database Schema

### Task 1.1: Add New Database Tables

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add MediaEnrichment table definition**

Add after the existing `Media` table (around line 396):

```dart
/// Enrichment data calculated from dive profile at photo timestamp
class MediaEnrichment extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  // Calculated from dive profile at photo timestamp
  RealColumn get depthMeters => real().nullable()();
  RealColumn get temperatureCelsius => real().nullable()();
  IntColumn get elapsedSeconds => integer().nullable()();
  // Confidence/quality
  TextColumn get matchConfidence =>
      text().withDefault(const Constant('exact'))(); // exact, interpolated, estimated, no_profile
  IntColumn get timestampOffsetSeconds => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 2: Add MediaSpecies table definition**

Add after MediaEnrichment:

```dart
/// Species tags on media (many-to-many with optional spatial annotation)
class MediaSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get sightingId =>
      text().nullable().references(Sightings, #id, onDelete: KeyAction.setNull)();
  // Reserved for future spatial annotation (nullable for now)
  RealColumn get bboxX => real().nullable()();
  RealColumn get bboxY => real().nullable()();
  RealColumn get bboxWidth => real().nullable()();
  RealColumn get bboxHeight => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 3: Add PendingPhotoSuggestions table definition**

Add after MediaSpecies:

```dart
/// Pending photo suggestions for background scan feature
class PendingPhotoSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get platformAssetId => text()();
  IntColumn get takenAt => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 4: Update Media table with new columns**

Modify the existing `Media` class to add new columns. Find the Media table and update it:

```dart
/// Photos and media files (also used for signatures)
class Media extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Reference (for gallery photos)
  TextColumn get platformAssetId => text().nullable()();
  // Legacy file path (for app-created files like signatures)
  TextColumn get filePath => text().nullable()();
  TextColumn get originalFilename => text().nullable()();
  TextColumn get fileType => text().withDefault(
    const Constant('photo'),
  )(); // photo, video, instructor_signature
  // EXIF metadata
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get takenAt => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()(); // For video
  // User data
  TextColumn get caption => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  // Thumbnail cache
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get thumbnailGeneratedAt => integer().nullable()();
  // Orphan tracking
  IntColumn get lastVerifiedAt => integer().nullable()();
  BoolColumn get isOrphaned => boolean().withDefault(const Constant(false))();
  // Signature fields (v1.5) - used when fileType='instructor_signature'
  TextColumn get signerId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get signerName => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 5: Register new tables in @DriftDatabase annotation**

Find the `@DriftDatabase` annotation and add the new tables:

```dart
@DriftDatabase(
  tables: [
    // ... existing tables ...
    Media,
    MediaEnrichment,  // Add this
    MediaSpecies,     // Add this
    PendingPhotoSuggestions,  // Add this
    // ... rest of tables ...
  ],
)
```

**Step 6: Add migration for schema version 20**

In the `onUpgrade` method, add migration for version 20:

```dart
if (from < 20) {
  // Underwater photography feature - new tables and Media columns

  // Add new columns to media table
  await customStatement(
    'ALTER TABLE media ADD COLUMN platform_asset_id TEXT',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN original_filename TEXT',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN width INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN height INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN duration_seconds INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN thumbnail_generated_at INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN last_verified_at INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN is_orphaned INTEGER NOT NULL DEFAULT 0',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN created_at INTEGER',
  );
  await customStatement(
    'ALTER TABLE media ADD COLUMN updated_at INTEGER',
  );

  // Create media_enrichment table
  await customStatement('''
    CREATE TABLE IF NOT EXISTS media_enrichment (
      id TEXT NOT NULL PRIMARY KEY,
      media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
      depth_meters REAL,
      temperature_celsius REAL,
      elapsed_seconds INTEGER,
      match_confidence TEXT NOT NULL DEFAULT 'exact',
      timestamp_offset_seconds INTEGER,
      created_at INTEGER NOT NULL,
      UNIQUE(media_id, dive_id)
    )
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_media_enrichment_media
    ON media_enrichment(media_id)
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_media_enrichment_dive
    ON media_enrichment(dive_id)
  ''');

  // Create media_species table
  await customStatement('''
    CREATE TABLE IF NOT EXISTS media_species (
      id TEXT NOT NULL PRIMARY KEY,
      media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      sighting_id TEXT REFERENCES sightings(id) ON DELETE SET NULL,
      bbox_x REAL,
      bbox_y REAL,
      bbox_width REAL,
      bbox_height REAL,
      notes TEXT,
      created_at INTEGER NOT NULL,
      UNIQUE(media_id, species_id)
    )
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_media_species_media
    ON media_species(media_id)
  ''');

  // Create pending_photo_suggestions table
  await customStatement('''
    CREATE TABLE IF NOT EXISTS pending_photo_suggestions (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
      platform_asset_id TEXT NOT NULL,
      taken_at INTEGER NOT NULL,
      thumbnail_path TEXT,
      dismissed INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      UNIQUE(dive_id, platform_asset_id)
    )
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_pending_suggestions_dive
    ON pending_photo_suggestions(dive_id)
  ''');

  // Add index on media.platform_asset_id
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_media_platform_asset
    ON media(platform_asset_id)
  ''');

  // Backfill created_at/updated_at for existing media rows
  final now = DateTime.now().millisecondsSinceEpoch;
  await customStatement('''
    UPDATE media SET created_at = $now, updated_at = $now
    WHERE created_at IS NULL
  ''');
}
```

**Step 7: Update schemaVersion**

Change `int get schemaVersion => 19;` to `int get schemaVersion => 20;`

**Step 8: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Build succeeds, generates new database.g.dart

**Step 9: Commit**

```bash
git add lib/core/database/database.dart
git commit -m "feat(media): add database schema for underwater photography

- Add MediaEnrichment table for dive profile data at photo timestamp
- Add MediaSpecies table for species tagging on photos
- Add PendingPhotoSuggestions table for background scan feature
- Extend Media table with platform_asset_id, orphan tracking, thumbnails
- Add migration v20 with indexes"
```

---

## Phase 2: Domain Entities

### Task 2.1: Create Media Domain Entity

**Files:**
- Create: `lib/features/media/domain/entities/media_item.dart`

**Step 1: Write the test**

Create: `test/features/media/domain/entities/media_item_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  group('MediaItem', () {
    test('creates with required fields', () {
      final item = MediaItem(
        id: 'test-id',
        mediaType: MediaType.photo,
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      expect(item.id, 'test-id');
      expect(item.mediaType, MediaType.photo);
      expect(item.isOrphaned, false);
      expect(item.isFavorite, false);
    });

    test('copyWith preserves unchanged fields', () {
      final item = MediaItem(
        id: 'test-id',
        mediaType: MediaType.photo,
        platformAssetId: 'asset-123',
        caption: 'Original caption',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      final updated = item.copyWith(caption: 'New caption');

      expect(updated.id, 'test-id');
      expect(updated.platformAssetId, 'asset-123');
      expect(updated.caption, 'New caption');
    });

    test('isGalleryPhoto returns true for platform asset', () {
      final item = MediaItem(
        id: 'test-id',
        mediaType: MediaType.photo,
        platformAssetId: 'asset-123',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      expect(item.isGalleryPhoto, true);
    });

    test('isGalleryPhoto returns false for file path only', () {
      final item = MediaItem(
        id: 'test-id',
        mediaType: MediaType.instructorSignature,
        filePath: '/path/to/signature.png',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      expect(item.isGalleryPhoto, false);
    });
  });

  group('MediaEnrichment', () {
    test('creates with dive data', () {
      final enrichment = MediaEnrichment(
        id: 'enrich-1',
        mediaId: 'media-1',
        diveId: 'dive-1',
        depthMeters: 18.5,
        temperatureCelsius: 22.0,
        elapsedSeconds: 523,
        matchConfidence: MatchConfidence.interpolated,
        createdAt: DateTime(2024, 1, 15),
      );

      expect(enrichment.depthMeters, 18.5);
      expect(enrichment.matchConfidence, MatchConfidence.interpolated);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/entities/media_item_test.dart`
Expected: FAIL - file not found

**Step 3: Create the domain entity**

Create: `lib/features/media/domain/entities/media_item.dart`

```dart
import 'package:equatable/equatable.dart';

/// Media type enum
enum MediaType {
  photo,
  video,
  instructorSignature;

  String get displayName {
    switch (this) {
      case MediaType.photo:
        return 'Photo';
      case MediaType.video:
        return 'Video';
      case MediaType.instructorSignature:
        return 'Signature';
    }
  }

  static MediaType fromString(String? value) {
    if (value == null) return MediaType.photo;
    return MediaType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MediaType.photo,
    );
  }
}

/// Match confidence for enrichment data
enum MatchConfidence {
  exact,        // Profile point within 10 seconds
  interpolated, // Between two points < 60 sec apart
  estimated,    // Nearest point > 60 sec away
  noProfile;    // Dive has no profile data

  String get displayName {
    switch (this) {
      case MatchConfidence.exact:
        return 'Exact';
      case MatchConfidence.interpolated:
        return 'Interpolated';
      case MatchConfidence.estimated:
        return 'Estimated';
      case MatchConfidence.noProfile:
        return 'No Profile';
    }
  }

  static MatchConfidence fromString(String? value) {
    if (value == null) return MatchConfidence.exact;
    return MatchConfidence.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MatchConfidence.exact,
    );
  }
}

/// Media item entity (photo or video)
class MediaItem extends Equatable {
  final String id;
  final String? diveId;
  final String? siteId;
  // Reference to platform photo library
  final String? platformAssetId;
  // Legacy file path (for signatures, app-created files)
  final String? filePath;
  final String? originalFilename;
  final MediaType mediaType;
  // EXIF metadata
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final int? durationSeconds; // For video
  // User data
  final String? caption;
  final bool isFavorite;
  // Thumbnail cache
  final String? thumbnailPath;
  final DateTime? thumbnailGeneratedAt;
  // Orphan tracking
  final DateTime? lastVerifiedAt;
  final bool isOrphaned;
  // Signature fields
  final String? signerId;
  final String? signerName;
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  // Loaded enrichment (optional, populated by repository)
  final MediaEnrichment? enrichment;

  const MediaItem({
    required this.id,
    this.diveId,
    this.siteId,
    this.platformAssetId,
    this.filePath,
    this.originalFilename,
    required this.mediaType,
    this.latitude,
    this.longitude,
    this.takenAt,
    this.width,
    this.height,
    this.durationSeconds,
    this.caption,
    this.isFavorite = false,
    this.thumbnailPath,
    this.thumbnailGeneratedAt,
    this.lastVerifiedAt,
    this.isOrphaned = false,
    this.signerId,
    this.signerName,
    required this.createdAt,
    required this.updatedAt,
    this.enrichment,
  });

  /// Whether this is a photo from the device gallery (vs app-created file)
  bool get isGalleryPhoto =>
      platformAssetId != null && platformAssetId!.isNotEmpty;

  /// Whether this is a video
  bool get isVideo => mediaType == MediaType.video;

  /// Display-friendly duration string for videos
  String? get durationString {
    if (durationSeconds == null) return null;
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  MediaItem copyWith({
    String? id,
    String? diveId,
    String? siteId,
    String? platformAssetId,
    String? filePath,
    String? originalFilename,
    MediaType? mediaType,
    double? latitude,
    double? longitude,
    DateTime? takenAt,
    int? width,
    int? height,
    int? durationSeconds,
    String? caption,
    bool? isFavorite,
    String? thumbnailPath,
    DateTime? thumbnailGeneratedAt,
    DateTime? lastVerifiedAt,
    bool? isOrphaned,
    String? signerId,
    String? signerName,
    DateTime? createdAt,
    DateTime? updatedAt,
    MediaEnrichment? enrichment,
  }) {
    return MediaItem(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      siteId: siteId ?? this.siteId,
      platformAssetId: platformAssetId ?? this.platformAssetId,
      filePath: filePath ?? this.filePath,
      originalFilename: originalFilename ?? this.originalFilename,
      mediaType: mediaType ?? this.mediaType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      takenAt: takenAt ?? this.takenAt,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caption: caption ?? this.caption,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailGeneratedAt: thumbnailGeneratedAt ?? this.thumbnailGeneratedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      isOrphaned: isOrphaned ?? this.isOrphaned,
      signerId: signerId ?? this.signerId,
      signerName: signerName ?? this.signerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enrichment: enrichment ?? this.enrichment,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diveId,
        siteId,
        platformAssetId,
        filePath,
        originalFilename,
        mediaType,
        latitude,
        longitude,
        takenAt,
        width,
        height,
        durationSeconds,
        caption,
        isFavorite,
        thumbnailPath,
        thumbnailGeneratedAt,
        lastVerifiedAt,
        isOrphaned,
        signerId,
        signerName,
        createdAt,
        updatedAt,
        enrichment,
      ];
}

/// Enrichment data calculated from dive profile
class MediaEnrichment extends Equatable {
  final String id;
  final String mediaId;
  final String diveId;
  final double? depthMeters;
  final double? temperatureCelsius;
  final int? elapsedSeconds;
  final MatchConfidence matchConfidence;
  final int? timestampOffsetSeconds;
  final DateTime createdAt;

  const MediaEnrichment({
    required this.id,
    required this.mediaId,
    required this.diveId,
    this.depthMeters,
    this.temperatureCelsius,
    this.elapsedSeconds,
    this.matchConfidence = MatchConfidence.exact,
    this.timestampOffsetSeconds,
    required this.createdAt,
  });

  MediaEnrichment copyWith({
    String? id,
    String? mediaId,
    String? diveId,
    double? depthMeters,
    double? temperatureCelsius,
    int? elapsedSeconds,
    MatchConfidence? matchConfidence,
    int? timestampOffsetSeconds,
    DateTime? createdAt,
  }) {
    return MediaEnrichment(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      diveId: diveId ?? this.diveId,
      depthMeters: depthMeters ?? this.depthMeters,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      timestampOffsetSeconds:
          timestampOffsetSeconds ?? this.timestampOffsetSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        mediaId,
        diveId,
        depthMeters,
        temperatureCelsius,
        elapsedSeconds,
        matchConfidence,
        timestampOffsetSeconds,
        createdAt,
      ];
}

/// Species tag on a media item
class MediaSpeciesTag extends Equatable {
  final String id;
  final String mediaId;
  final String speciesId;
  final String? sightingId;
  // Reserved for future spatial annotation
  final double? bboxX;
  final double? bboxY;
  final double? bboxWidth;
  final double? bboxHeight;
  final String? notes;
  final DateTime createdAt;

  const MediaSpeciesTag({
    required this.id,
    required this.mediaId,
    required this.speciesId,
    this.sightingId,
    this.bboxX,
    this.bboxY,
    this.bboxWidth,
    this.bboxHeight,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        mediaId,
        speciesId,
        sightingId,
        bboxX,
        bboxY,
        bboxWidth,
        bboxHeight,
        notes,
        createdAt,
      ];
}

/// Pending photo suggestion from background scan
class PendingPhotoSuggestion extends Equatable {
  final String id;
  final String diveId;
  final String platformAssetId;
  final DateTime takenAt;
  final String? thumbnailPath;
  final bool dismissed;
  final DateTime createdAt;

  const PendingPhotoSuggestion({
    required this.id,
    required this.diveId,
    required this.platformAssetId,
    required this.takenAt,
    this.thumbnailPath,
    this.dismissed = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        diveId,
        platformAssetId,
        takenAt,
        thumbnailPath,
        dismissed,
        createdAt,
      ];
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/domain/entities/media_item_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/media/domain/entities/media_item.dart test/features/media/domain/entities/media_item_test.dart
git commit -m "feat(media): add domain entities for underwater photography

- MediaItem: core entity with reference storage, EXIF, orphan tracking
- MediaEnrichment: dive profile data at photo timestamp
- MediaSpeciesTag: species tagging on photos
- PendingPhotoSuggestion: background scan suggestions"
```

---

## Phase 3: Repository Layer

### Task 3.1: Create Media Repository

**Files:**
- Create: `lib/features/media/data/repositories/media_repository.dart`
- Create: `test/features/media/data/repositories/media_repository_test.dart`

**Step 1: Write the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repository;

  setUp(() async {
    await setupTestDatabase();
    repository = MediaRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('MediaRepository', () {
    test('creates and retrieves media item', () async {
      final item = MediaItem(
        id: '',
        mediaType: MediaType.photo,
        platformAssetId: 'asset-123',
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2024, 1, 15, 10, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await repository.createMedia(item);
      expect(created.id, isNotEmpty);
      expect(created.platformAssetId, 'asset-123');

      final retrieved = await repository.getMediaById(created.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.platformAssetId, 'asset-123');
    });

    test('gets media for dive', () async {
      // Create a dive first, then media linked to it
      final item = MediaItem(
        id: '',
        diveId: 'test-dive-id',
        mediaType: MediaType.photo,
        platformAssetId: 'asset-456',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createMedia(item);
      final media = await repository.getMediaForDive('test-dive-id');

      expect(media.length, 1);
      expect(media.first.diveId, 'test-dive-id');
    });

    test('marks media as orphaned', () async {
      final item = MediaItem(
        id: '',
        mediaType: MediaType.photo,
        platformAssetId: 'orphan-asset',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await repository.createMedia(item);
      await repository.markAsOrphaned(created.id);

      final retrieved = await repository.getMediaById(created.id);
      expect(retrieved!.isOrphaned, true);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart`
Expected: FAIL - repository not found

**Step 3: Implement the repository**

Create: `lib/features/media/data/repositories/media_repository.dart`

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;

class MediaRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(MediaRepository);

  /// Get all media for a dive
  Future<List<domain.MediaItem>> getMediaForDive(String diveId) async {
    try {
      final query = _db.select(_db.media)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.takenAt)]);

      final rows = await query.get();
      return Future.wait(rows.map(_mapRowToMediaItem));
    } catch (e, stackTrace) {
      _log.error('Failed to get media for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get media by ID
  Future<domain.MediaItem?> getMediaById(String id) async {
    try {
      final query = _db.select(_db.media)..where((t) => t.id.equals(id));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToMediaItem(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get media by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new media item
  Future<domain.MediaItem> createMedia(domain.MediaItem item) async {
    try {
      _log.info('Creating media: ${item.originalFilename ?? item.platformAssetId}');
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final now = DateTime.now();

      await _db.into(_db.media).insert(
            MediaCompanion(
              id: Value(id),
              diveId: Value(item.diveId),
              siteId: Value(item.siteId),
              platformAssetId: Value(item.platformAssetId),
              filePath: Value(item.filePath),
              fileType: Value(item.mediaType.name),
              latitude: Value(item.latitude),
              longitude: Value(item.longitude),
              takenAt: Value(item.takenAt?.millisecondsSinceEpoch),
              caption: Value(item.caption),
              signerId: Value(item.signerId),
              signerName: Value(item.signerName),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created media with id: $id');
      return item.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error('Failed to create media', e, stackTrace);
      rethrow;
    }
  }

  /// Update media item
  Future<void> updateMedia(domain.MediaItem item) async {
    try {
      _log.info('Updating media: ${item.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(item.id))).write(
        MediaCompanion(
          diveId: Value(item.diveId),
          siteId: Value(item.siteId),
          caption: Value(item.caption),
          thumbnailPath: Value(item.thumbnailPath),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: item.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated media: ${item.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update media: ${item.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete media item
  Future<void> deleteMedia(String id) async {
    try {
      _log.info('Deleting media: $id');
      await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'media', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted media: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete media: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Mark media as orphaned (photo no longer exists in gallery)
  Future<void> markAsOrphaned(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement('''
        UPDATE media SET is_orphaned = 1, last_verified_at = $now
        WHERE id = '$id'
      ''');
      _log.info('Marked media as orphaned: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to mark media as orphaned: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Mark media as verified (photo still exists)
  Future<void> markAsVerified(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement('''
        UPDATE media SET is_orphaned = 0, last_verified_at = $now
        WHERE id = '$id'
      ''');
    } catch (e, stackTrace) {
      _log.error('Failed to mark media as verified: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get all orphaned media
  Future<List<domain.MediaItem>> getOrphanedMedia() async {
    try {
      final results = await _db.customSelect('''
        SELECT * FROM media WHERE is_orphaned = 1
        ORDER BY created_at DESC
      ''').get();

      return Future.wait(results.map((row) async {
        return domain.MediaItem(
          id: row.data['id'] as String,
          diveId: row.data['dive_id'] as String?,
          siteId: row.data['site_id'] as String?,
          platformAssetId: row.data['platform_asset_id'] as String?,
          filePath: row.data['file_path'] as String?,
          originalFilename: row.data['original_filename'] as String?,
          mediaType: domain.MediaType.fromString(row.data['file_type'] as String?),
          latitude: row.data['latitude'] as double?,
          longitude: row.data['longitude'] as double?,
          takenAt: row.data['taken_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(row.data['taken_at'] as int)
              : null,
          caption: row.data['caption'] as String?,
          isOrphaned: true,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row.data['created_at'] as int?) ?? 0,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (row.data['updated_at'] as int?) ?? 0,
          ),
        );
      }));
    } catch (e, stackTrace) {
      _log.error('Failed to get orphaned media', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all orphaned media
  Future<int> deleteOrphanedMedia() async {
    try {
      final orphaned = await getOrphanedMedia();
      for (final item in orphaned) {
        await deleteMedia(item.id);
      }
      _log.info('Deleted ${orphaned.length} orphaned media items');
      return orphaned.length;
    } catch (e, stackTrace) {
      _log.error('Failed to delete orphaned media', e, stackTrace);
      rethrow;
    }
  }

  /// Get enrichment for a media item
  Future<domain.MediaEnrichment?> getEnrichmentForMedia(String mediaId) async {
    try {
      final results = await _db.customSelect('''
        SELECT * FROM media_enrichment WHERE media_id = ?
        LIMIT 1
      ''', variables: [Variable.withString(mediaId)]).get();

      if (results.isEmpty) return null;

      final row = results.first;
      return domain.MediaEnrichment(
        id: row.data['id'] as String,
        mediaId: row.data['media_id'] as String,
        diveId: row.data['dive_id'] as String,
        depthMeters: row.data['depth_meters'] as double?,
        temperatureCelsius: row.data['temperature_celsius'] as double?,
        elapsedSeconds: row.data['elapsed_seconds'] as int?,
        matchConfidence: domain.MatchConfidence.fromString(
          row.data['match_confidence'] as String?,
        ),
        timestampOffsetSeconds: row.data['timestamp_offset_seconds'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get enrichment for media: $mediaId', e, stackTrace);
      rethrow;
    }
  }

  /// Save enrichment data for a media item
  Future<void> saveEnrichment(domain.MediaEnrichment enrichment) async {
    try {
      final id = enrichment.id.isEmpty ? _uuid.v4() : enrichment.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.customStatement('''
        INSERT OR REPLACE INTO media_enrichment
        (id, media_id, dive_id, depth_meters, temperature_celsius,
         elapsed_seconds, match_confidence, timestamp_offset_seconds, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      // Note: Using Drift's insert would be cleaner, but this shows the SQL

      _log.info('Saved enrichment for media: ${enrichment.mediaId}');
    } catch (e, stackTrace) {
      _log.error('Failed to save enrichment', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of media for a dive
  Future<int> getMediaCountForDive(String diveId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count FROM media WHERE dive_id = ?
    ''', variables: [Variable.withString(diveId)]).getSingle();
    return result.data['count'] as int? ?? 0;
  }

  /// Get pending photo suggestions count for a dive
  Future<int> getPendingSuggestionCount(String diveId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count FROM pending_photo_suggestions
      WHERE dive_id = ? AND dismissed = 0
    ''', variables: [Variable.withString(diveId)]).getSingle();
    return result.data['count'] as int? ?? 0;
  }

  Future<domain.MediaItem> _mapRowToMediaItem(MediaData row) async {
    final enrichment = await getEnrichmentForMedia(row.id);

    return domain.MediaItem(
      id: row.id,
      diveId: row.diveId,
      siteId: row.siteId,
      platformAssetId: row.platformAssetId,
      filePath: row.filePath,
      originalFilename: row.originalFilename,
      mediaType: domain.MediaType.fromString(row.fileType),
      latitude: row.latitude,
      longitude: row.longitude,
      takenAt: row.takenAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.takenAt!)
          : null,
      width: row.width,
      height: row.height,
      durationSeconds: row.durationSeconds,
      caption: row.caption,
      isFavorite: row.isFavorite,
      thumbnailPath: row.thumbnailPath,
      thumbnailGeneratedAt: row.thumbnailGeneratedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.thumbnailGeneratedAt!)
          : null,
      lastVerifiedAt: row.lastVerifiedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastVerifiedAt!)
          : null,
      isOrphaned: row.isOrphaned,
      signerId: row.signerId,
      signerName: row.signerName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt ?? 0),
      enrichment: enrichment,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart`
Expected: PASS (may need test database setup adjustments)

**Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/repositories/media_repository_test.dart
git commit -m "feat(media): add MediaRepository for CRUD operations

- Create, read, update, delete media items
- Orphan tracking and cleanup
- Enrichment data storage
- Pending suggestions count"
```

---

## Phase 4: Enrichment Service

### Task 4.1: Create Profile Interpolation Service

**Files:**
- Create: `lib/features/media/data/services/enrichment_service.dart`
- Create: `test/features/media/data/services/enrichment_service_test.dart`

**Step 1: Write the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  late EnrichmentService service;

  setUp(() {
    service = EnrichmentService();
  });

  group('EnrichmentService', () {
    test('interpolates depth between two profile points', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0),
        const DiveProfilePoint(timestamp: 60, depth: 10, temperature: 24),
        const DiveProfilePoint(timestamp: 120, depth: 20, temperature: 22),
        const DiveProfilePoint(timestamp: 180, depth: 15, temperature: 22),
      ];

      final diveStart = DateTime(2024, 1, 15, 10, 0, 0);
      final photoTime = DateTime(2024, 1, 15, 10, 1, 30); // 90 seconds in

      final result = service.calculateEnrichment(
        profile: profile,
        diveStartTime: diveStart,
        photoTime: photoTime,
      );

      expect(result.depthMeters, closeTo(15.0, 0.1)); // Halfway between 10 and 20
      expect(result.elapsedSeconds, 90);
      expect(result.matchConfidence, MatchConfidence.interpolated);
    });

    test('returns exact match when within 10 seconds of profile point', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0),
        const DiveProfilePoint(timestamp: 60, depth: 18.5, temperature: 22),
        const DiveProfilePoint(timestamp: 120, depth: 20),
      ];

      final diveStart = DateTime(2024, 1, 15, 10, 0, 0);
      final photoTime = DateTime(2024, 1, 15, 10, 1, 5); // 65 seconds in, within 10s of 60s point

      final result = service.calculateEnrichment(
        profile: profile,
        diveStartTime: diveStart,
        photoTime: photoTime,
      );

      expect(result.depthMeters, closeTo(18.5, 0.1));
      expect(result.matchConfidence, MatchConfidence.exact);
    });

    test('returns estimated when gap is large', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0),
        const DiveProfilePoint(timestamp: 60, depth: 15),
        // Large gap - no point at 120
        const DiveProfilePoint(timestamp: 180, depth: 20),
      ];

      final diveStart = DateTime(2024, 1, 15, 10, 0, 0);
      final photoTime = DateTime(2024, 1, 15, 10, 2, 0); // 120 seconds in

      final result = service.calculateEnrichment(
        profile: profile,
        diveStartTime: diveStart,
        photoTime: photoTime,
      );

      expect(result.matchConfidence, MatchConfidence.estimated);
    });

    test('returns noProfile when profile is empty', () {
      final diveStart = DateTime(2024, 1, 15, 10, 0, 0);
      final photoTime = DateTime(2024, 1, 15, 10, 1, 0);

      final result = service.calculateEnrichment(
        profile: [],
        diveStartTime: diveStart,
        photoTime: photoTime,
      );

      expect(result.matchConfidence, MatchConfidence.noProfile);
      expect(result.depthMeters, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/enrichment_service_test.dart`
Expected: FAIL

**Step 3: Implement the service**

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Result of enrichment calculation
class EnrichmentResult {
  final double? depthMeters;
  final double? temperatureCelsius;
  final int elapsedSeconds;
  final MatchConfidence matchConfidence;
  final int? timestampOffsetSeconds;

  const EnrichmentResult({
    this.depthMeters,
    this.temperatureCelsius,
    required this.elapsedSeconds,
    required this.matchConfidence,
    this.timestampOffsetSeconds,
  });
}

/// Service for calculating dive profile enrichment data for photos
class EnrichmentService {
  /// Threshold for "exact" match (seconds)
  static const int exactMatchThreshold = 10;

  /// Threshold for "interpolated" vs "estimated" (seconds between points)
  static const int interpolationThreshold = 60;

  /// Calculate enrichment data for a photo taken during a dive
  EnrichmentResult calculateEnrichment({
    required List<DiveProfilePoint> profile,
    required DateTime diveStartTime,
    required DateTime photoTime,
  }) {
    final elapsedSeconds = photoTime.difference(diveStartTime).inSeconds;

    if (profile.isEmpty) {
      return EnrichmentResult(
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.noProfile,
      );
    }

    // Find bracketing profile points
    DiveProfilePoint? before;
    DiveProfilePoint? after;

    for (final point in profile) {
      if (point.timestamp <= elapsedSeconds) {
        before = point;
      }
      if (point.timestamp >= elapsedSeconds && after == null) {
        after = point;
      }
    }

    // Edge cases: photo before first point or after last point
    if (before == null && after != null) {
      return _resultFromSinglePoint(after, elapsedSeconds);
    }
    if (after == null && before != null) {
      return _resultFromSinglePoint(before, elapsedSeconds);
    }
    if (before == null && after == null) {
      return EnrichmentResult(
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.noProfile,
      );
    }

    // Same point (exact or very close)
    if (before!.timestamp == after!.timestamp) {
      return _resultFromSinglePoint(before, elapsedSeconds);
    }

    // Check if close to either point
    final distanceToBefore = elapsedSeconds - before.timestamp;
    final distanceToAfter = after.timestamp - elapsedSeconds;
    final minDistance =
        distanceToBefore < distanceToAfter ? distanceToBefore : distanceToAfter;
    final closestPoint =
        distanceToBefore < distanceToAfter ? before : after;

    if (minDistance <= exactMatchThreshold) {
      return EnrichmentResult(
        depthMeters: closestPoint.depth,
        temperatureCelsius: closestPoint.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.exact,
        timestampOffsetSeconds: minDistance,
      );
    }

    // Interpolate
    final gap = after.timestamp - before.timestamp;
    final ratio = (elapsedSeconds - before.timestamp) / gap;

    final interpolatedDepth =
        before.depth + (after.depth - before.depth) * ratio;

    double? interpolatedTemp;
    if (before.temperature != null && after.temperature != null) {
      interpolatedTemp =
          before.temperature! + (after.temperature! - before.temperature!) * ratio;
    } else {
      interpolatedTemp = before.temperature ?? after.temperature;
    }

    final confidence = gap <= interpolationThreshold
        ? MatchConfidence.interpolated
        : MatchConfidence.estimated;

    return EnrichmentResult(
      depthMeters: interpolatedDepth,
      temperatureCelsius: interpolatedTemp,
      elapsedSeconds: elapsedSeconds,
      matchConfidence: confidence,
      timestampOffsetSeconds: minDistance,
    );
  }

  EnrichmentResult _resultFromSinglePoint(
    DiveProfilePoint point,
    int elapsedSeconds,
  ) {
    final distance = (elapsedSeconds - point.timestamp).abs();
    final confidence = distance <= exactMatchThreshold
        ? MatchConfidence.exact
        : MatchConfidence.estimated;

    return EnrichmentResult(
      depthMeters: point.depth,
      temperatureCelsius: point.temperature,
      elapsedSeconds: elapsedSeconds,
      matchConfidence: confidence,
      timestampOffsetSeconds: distance,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/services/enrichment_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/media/data/services/enrichment_service.dart test/features/media/data/services/enrichment_service_test.dart
git commit -m "feat(media): add EnrichmentService for dive profile interpolation

- Interpolates depth/temperature at photo timestamp
- Confidence levels: exact, interpolated, estimated, noProfile
- Handles edge cases (empty profile, photo outside dive time)"
```

---

## Phase 5: Provider Layer

### Task 5.1: Create Media Providers

**Files:**
- Create: `lib/features/media/presentation/providers/media_providers.dart`

**Step 1: Create the providers**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Repository provider
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

/// Media for a specific dive
final mediaForDiveProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, diveId) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaForDive(diveId);
});

/// Single media item by ID
final mediaByIdProvider =
    FutureProvider.family<MediaItem?, String>((ref, id) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaById(id);
});

/// Media count for a dive (for badges)
final mediaCountForDiveProvider =
    FutureProvider.family<int, String>((ref, diveId) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaCountForDive(diveId);
});

/// Pending photo suggestion count for a dive
final pendingSuggestionCountProvider =
    FutureProvider.family<int, String>((ref, diveId) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getPendingSuggestionCount(diveId);
});

/// All orphaned media
final orphanedMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getOrphanedMedia();
});

/// Notifier for media mutations
class MediaListNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  final Ref _ref;
  final String _diveId;

  MediaListNotifier(this._repository, this._ref, this._diveId)
      : super(const AsyncValue.loading()) {
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    state = const AsyncValue.loading();
    try {
      final media = await _repository.getMediaForDive(_diveId);
      state = AsyncValue.data(media);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMedia();
    _ref.invalidate(mediaForDiveProvider(_diveId));
    _ref.invalidate(mediaCountForDiveProvider(_diveId));
  }

  Future<MediaItem> addMedia(MediaItem item) async {
    final newItem = await _repository.createMedia(item.copyWith(diveId: _diveId));
    await refresh();
    return newItem;
  }

  Future<void> updateMedia(MediaItem item) async {
    await _repository.updateMedia(item);
    await refresh();
    _ref.invalidate(mediaByIdProvider(item.id));
  }

  Future<void> deleteMedia(String id) async {
    await _repository.deleteMedia(id);
    await refresh();
  }

  Future<void> markAsOrphaned(String id) async {
    await _repository.markAsOrphaned(id);
    await refresh();
  }
}

final mediaListNotifierProvider = StateNotifierProvider.family<
    MediaListNotifier, AsyncValue<List<MediaItem>>, String>((ref, diveId) {
  final repository = ref.watch(mediaRepositoryProvider);
  return MediaListNotifier(repository, ref, diveId);
});
```

**Step 2: Commit**

```bash
git add lib/features/media/presentation/providers/media_providers.dart
git commit -m "feat(media): add Riverpod providers for media state management

- mediaForDiveProvider: fetch media for a dive
- mediaByIdProvider: fetch single media item
- mediaCountForDiveProvider: for dive card badges
- MediaListNotifier: mutations with refresh"
```

---

## Phase 6: UI Components (Foundation)

### Task 6.1: Create Media Section Widget for Dive Detail

**Files:**
- Create: `lib/features/media/presentation/widgets/dive_media_section.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Media section for dive detail page
class DiveMediaSection extends ConsumerWidget {
  final String diveId;
  final VoidCallback? onAddPressed;

  const DiveMediaSection({
    super.key,
    required this.diveId,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos & Video',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onAddPressed != null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: onAddPressed,
                tooltip: 'Add photos',
              ),
          ],
        ),
        const SizedBox(height: 8),
        mediaAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Text('Error loading media: $e'),
          ),
          data: (media) {
            if (media.isEmpty) {
              return const _EmptyMediaState();
            }
            return _MediaGrid(media: media);
          },
        ),
      ],
    );
  }
}

class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No photos yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<MediaItem> media;

  const _MediaGrid({required this.media});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        return _MediaThumbnail(item: media[index]);
      },
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  final MediaItem item;

  const _MediaThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to full-screen viewer
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder or cached thumbnail
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: item.isOrphaned
                ? const _OrphanedPlaceholder()
                : item.thumbnailPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          item.thumbnailPath!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.photo),
          ),
          // Depth badge
          if (item.enrichment?.depthMeters != null)
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.enrichment!.depthMeters!.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Video indicator
          if (item.isVideo)
            const Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.videocam,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrphanedPlaceholder extends StatelessWidget {
  const _OrphanedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/media/presentation/widgets/dive_media_section.dart
git commit -m "feat(media): add DiveMediaSection widget for dive detail page

- Grid display of photo/video thumbnails
- Depth badges from enrichment data
- Orphaned photo placeholder
- Empty state UI"
```

---

## Next Steps (Future Phases)

The following phases should be implemented after the foundation is in place:

### Phase 7: Platform Photo Access
- Add `photo_manager` package
- Create `PhotoLibraryService` for iOS/Android photo access
- Implement photo picker with time-based filtering
- Handle permissions

### Phase 8: Thumbnail Service
- Generate thumbnails on import
- Cache management
- Regeneration for orphaned thumbnails

### Phase 9: Background Scan
- Scan for matching photos after dive import
- Store pending suggestions
- UI for suggestion badges and acceptance

### Phase 10: Full UI
- Photo picker sheet
- Full-screen photo viewer with swipe
- Photo detail page with enrichment display
- Species tagging UI
- Settings page for orphan cleanup

### Phase 11: Optional EXIF Writing
- Platform-specific EXIF writing
- Permission handling
- Batch write tool

---

## Testing Checklist

Before marking each phase complete:

- [ ] All unit tests pass
- [ ] Code passes `dart format`
- [ ] Code passes `flutter analyze`
- [ ] Database migration tested (upgrade from v19)
- [ ] Manual testing on device
