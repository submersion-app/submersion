# Site Media Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Attach photos, videos, and documents (PDFs and common file types) to dive sites, and enable document attachments on dives (issues #211, #627).

**Architecture:** Reuse the existing `media` table's `siteId` FK (already synced and merge-safe); add the missing read path, providers, and UI. Extract a shared media grid core from `DiveMediaSection` and build a new `SiteMediaSection` on it. Documents are a new `MediaType.document` stored by reference (bookmark/SAF/path) like desktop photos; PDFs render in-app via `pdfrx` and get real page-1 thumbnails; site deletion gets an HLC-stamped media cascade mirroring the dive-side fix.

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod (legacy StateNotifier imports), file_picker, photo_manager, pdfrx (new dependency), share_plus.

**Spec:** `docs/superpowers/specs/2026-08-10-site-media-attachments-design.md`

## Global Constraints

- Work in worktree `.claude/worktrees/site-media-attachments`, branch `worktree-site-media-attachments`. Run all commands from the worktree root.
- After every task: `dart format .` (whole project) must produce no changes at commit time.
- `flutter analyze` on the WHOLE project must be clean — infos are fatal in CI.
- Every user-visible string goes through `context.l10n.<key>`. New keys must be added to ALL 11 ARB files: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`, then run `flutter gen-l10n`. EXCEPTION: shared widgets that both dive and site sections consume take display strings as constructor parameters (adding l10n inside a shared widget breaks consumer widget tests — established project trap).
- SHARED-WIDGET TRAP: widget tests that pump a widget using `context.l10n` need a `MaterialApp` with localization delegates. Follow the pattern in `test/features/media/presentation/widgets/dive_media_section_test.dart`.
- No emojis anywhere. No `console.log`-style debug prints. Immutability (copyWith) for entities.
- Schema version goes 147 -> 148 exactly once (Task 3). Any task run out of order must not re-bump it.
- Commit after each task with the message given in the task. Do NOT add a Co-Authored-By line or session URL.
- Tests use `flutter test <path>` per task; a per-file timeout of 120s is normal for repository tests. The full suite runs in Task 15 only.
- Riverpod: this project uses Riverpod 3 with legacy StateNotifier imported via `package:submersion/core/providers/provider.dart` (NOT `package:flutter_riverpod/flutter_riverpod.dart` for providers files). Copy imports from the files you modify.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/media/domain/entities/media_item.dart` | Modify: `MediaType.document`, `isDocument`/`isPdf`/`documentExtension` getters, mime cases |
| `lib/features/media/data/repositories/media_repository.dart` | Modify: site reads, site-deletion partition/unlink |
| `lib/core/database/database.dart` | Modify: v148 migration (site index + dedupe unique index) |
| `lib/core/database/performance_indexes.dart` | Modify: `idx_media_site_id` |
| `lib/features/dive_sites/data/repositories/site_repository_impl.dart` | Modify: media cascade on site delete |
| `lib/features/media/presentation/providers/site_media_providers.dart` | Create: site media providers + notifier |
| `lib/features/media/presentation/widgets/media_grid.dart` | Create: shared grid pieces (tile, selection header, empty state) |
| `lib/features/media/presentation/widgets/dive_media_section.dart` | Modify: compose shared pieces, add-document menu |
| `lib/features/media/presentation/widgets/site_media_section.dart` | Create: site attachments section |
| `lib/features/media/presentation/pages/site_media_viewer_page.dart` | Create: site-scoped photo viewer |
| `lib/features/media/presentation/pages/document_viewer_page.dart` | Create: in-app PDF viewer |
| `lib/features/media/data/services/document_import_service.dart` | Create: reference-linking document attach |
| `lib/features/media/data/services/pdf_page_renderer.dart` | Create: PDF page-1 -> JPEG bytes |
| `lib/features/media/data/services/media_import_service.dart` | Modify: `importPhotosForSite` |
| `lib/features/media/presentation/helpers/site_media_import_helper.dart` | Create: site add-photos / add-document flows |
| `lib/features/media_store/data/thumbnail_generator.dart` | Modify: PDF branch |
| `lib/core/services/media_store/store_keys.dart` | Modify: document content types |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | Modify: mount `SiteMediaSection` |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Modify: add-document wiring |
| `lib/features/media/presentation/pages/photo_viewer_page.dart` | Modify: exclude documents from photo list |

---

## Phase 1: Data layer

### Task 1: `MediaType.document` and document getters

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart`
- Test: `test/features/media/domain/entities/media_item_document_test.dart` (create)

**Interfaces:**
- Produces: `MediaType.document`; `MediaItem.isDocument` (bool), `MediaItem.isPdf` (bool), `MediaItem.documentExtension` (String, lowercase without dot, `''` when unknown). Later tasks (tiles, thumbnails, viewers) branch on these.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/entities/media_item_document_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem _doc(String? filename) => MediaItem(
  id: 'm1',
  mediaType: MediaType.document,
  originalFilename: filename,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('MediaType.document round-trips through fromString', () {
    expect(MediaType.fromString('document'), MediaType.document);
    expect(MediaType.document.name, 'document');
  });

  test('isDocument true only for document type', () {
    expect(_doc('map.pdf').isDocument, isTrue);
    expect(
      _doc('map.pdf').copyWith(mediaType: MediaType.photo).isDocument,
      isFalse,
    );
  });

  test('isPdf keys on extension case-insensitively', () {
    expect(_doc('reef-map.pdf').isPdf, isTrue);
    expect(_doc('reef-map.PDF').isPdf, isTrue);
    expect(_doc('notes.docx').isPdf, isFalse);
    expect(_doc(null).isPdf, isFalse);
  });

  test('documentExtension lowercases and strips the dot', () {
    expect(_doc('Map.PDF').documentExtension, 'pdf');
    expect(_doc('notes.docx').documentExtension, 'docx');
    expect(_doc('README').documentExtension, '');
    expect(_doc(null).documentExtension, '');
  });

  test('shareMimeType maps pdf', () {
    expect(_doc('map.pdf').shareMimeType, 'application/pdf');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/entities/media_item_document_test.dart`
Expected: FAIL — `document` is not a member of `MediaType`.

- [ ] **Step 3: Implement**

In `lib/features/media/domain/entities/media_item.dart`:

1. Add `document` to the enum (line ~7) and its `displayName` case:

```dart
enum MediaType {
  photo,
  video,
  instructorSignature,
  document;

  String get displayName {
    switch (this) {
      case MediaType.photo:
        return 'Photo';
      case MediaType.video:
        return 'Video';
      case MediaType.instructorSignature:
        return 'Instructor Signature';
      case MediaType.document:
        return 'Document';
    }
  }
  // fromString unchanged (name-based, picks up the new member automatically)
}
```

2. Next to `bool get isVideo` (line ~153) add:

```dart
  /// True for attachment documents (PDFs and opaque files).
  bool get isDocument => mediaType == MediaType.document;

  /// Lowercased extension of [originalFilename] without the dot; '' when
  /// absent. Presentation-only: storage addressing uses StoreKeys.
  String get documentExtension {
    final name = originalFilename;
    if (name == null) return '';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// True for documents that render in the in-app PDF viewer.
  bool get isPdf => isDocument && documentExtension == 'pdf';
```

3. In the `shareMimeType` switch (line ~171), add cases before the default:

```dart
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'gpx':
        return 'application/gpx+xml';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/domain/entities/media_item_document_test.dart`
Expected: PASS. Also run `flutter test test/features/media/domain/` to catch enum-exhaustiveness breaks in sibling tests; fix any switch over `MediaType` that fails to compile by adding a `document` case that behaves like `photo` unless the surrounding code is video-specific.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add MediaType.document with pdf/document helpers"
```

### Task 2: Repository site reads

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/repositories/media_repository_site_test.dart` (create)

**Interfaces:**
- Consumes: existing `_mapRowToMediaItem`, `_db.media`, `_db.mediaEnrichment`.
- Produces:
  - `Future<List<domain.MediaItem>> getMediaForSite(String siteId)` — ordered by `takenAt` ascending, includes enrichment when present.
  - `Future<int> getMediaCountForSite(String siteId)`
  - `Future<Set<String>> getLinkedAssetIdsForSite(String siteId)` — non-null `platformAssetId`s of rows with this `siteId` (dedupe for gallery imports).
  - `Future<Set<String>> getLinkedLocalPathsForSite(String siteId)` — non-null `localPath`s (dedupe for file imports).

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/repositories/media_repository_site_test.dart`. Copy the test-database setUp/tearDown scaffolding from the top of `test/features/media/data/repositories/media_repository_test.dart` verbatim (in-memory `AppDatabase` + `DatabaseService` override) — do not invent your own harness. Then:

```dart
  group('getMediaForSite', () {
    test('returns only media linked to the site, ordered by takenAt', () async {
      // Insert a site row 'site-1' and a dive row 'dive-1' using the same
      // companion helpers the existing tests in media_repository_test.dart
      // use. Then three media rows via repository.createMedia:
      final late1 = await repository.createMedia(
        MediaItem(
          id: '',
          siteId: 'site-1',
          mediaType: MediaType.photo,
          takenAt: DateTime(2026, 3, 2),
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
      );
      final early = await repository.createMedia(
        MediaItem(
          id: '',
          siteId: 'site-1',
          mediaType: MediaType.document,
          originalFilename: 'map.pdf',
          takenAt: DateTime(2026, 3, 1),
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );
      await repository.createMedia(
        MediaItem(
          id: '',
          diveId: 'dive-1',
          mediaType: MediaType.photo,
          takenAt: DateTime(2026, 3, 3),
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      );

      final result = await repository.getMediaForSite('site-1');
      expect(result.map((m) => m.id), [early.id, late1.id]);
      expect(await repository.getMediaCountForSite('site-1'), 2);
      expect(await repository.getMediaCountForSite('site-none'), 0);
    });

    test('linked asset ids and local paths for dedupe', () async {
      await repository.createMedia(
        MediaItem(
          id: '',
          siteId: 'site-1',
          platformAssetId: 'asset-9',
          mediaType: MediaType.photo,
          takenAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await repository.createMedia(
        MediaItem(
          id: '',
          siteId: 'site-1',
          sourceType: MediaSourceType.localFile,
          localPath: '/tmp/map.pdf',
          mediaType: MediaType.document,
          originalFilename: 'map.pdf',
          takenAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      expect(await repository.getLinkedAssetIdsForSite('site-1'), {'asset-9'});
      expect(await repository.getLinkedLocalPathsForSite('site-1'), {
        '/tmp/map.pdf',
      });
    });
  });
```

Note: creating media with a `siteId` requires the referenced site row to exist only if FKs are ON in the harness — the existing scaffolding runs with `PRAGMA foreign_keys = ON` via `beforeOpen`, so insert minimal `dive_sites` / `dives` parent rows first (copy the insert helpers used by `media_repository_cascade_test.dart` in `test/features/media/data/`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/repositories/media_repository_site_test.dart`
Expected: FAIL — `getMediaForSite` undefined.

- [ ] **Step 3: Implement**

In `media_repository.dart`, directly below `getMediaForDive` (line ~70), mirroring its shape:

```dart
  /// Get all media directly attached to a site, ordered by takenAt.
  /// Enrichment rides along for rows that are also dive-linked.
  Future<List<domain.MediaItem>> getMediaForSite(String siteId) async {
    try {
      final query =
          _db.select(_db.media).join([
              leftOuterJoin(
                _db.mediaEnrichment,
                _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
              ),
            ])
            ..where(_db.media.siteId.equals(siteId))
            ..orderBy([OrderingTerm.asc(_db.media.takenAt)]);

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return _mapRowToMediaItem(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Count of media directly attached to a site (badges/headers).
  Future<int> getMediaCountForSite(String siteId) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(_db.media.siteId.equals(siteId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Platform asset ids already linked to [siteId] (gallery-import dedupe;
  /// site counterpart of getLinkedAssetIdsForDive).
  Future<Set<String>> getLinkedAssetIdsForSite(String siteId) async {
    final assetId = _db.media.platformAssetId;
    final query = _db.selectOnly(_db.media)
      ..addColumns([assetId])
      ..where(_db.media.siteId.equals(siteId) & assetId.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(assetId)!).toSet();
  }

  /// Local paths already linked to [siteId] (file-import dedupe; site
  /// counterpart of getLinkedLocalPathsForDive).
  Future<Set<String>> getLinkedLocalPathsForSite(String siteId) async {
    final path = _db.media.localPath;
    final query = _db.selectOnly(_db.media)
      ..addColumns([path])
      ..where(_db.media.siteId.equals(siteId) & path.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(path)!).toSet();
  }
```

Before writing, open the existing `getLinkedAssetIdsForDive` / `getLinkedLocalPathsForDive` in the same file and match their exact style (column selection, null handling) — if they differ from the above, follow the file, not this plan.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/repositories/media_repository_site_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add site media read path to MediaRepository"
```

### Task 3: Migration v148 — site index and site dedupe index

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/database/performance_indexes.dart`

**Interfaces:**
- Produces: schema version 148; indexes `idx_media_site_id` and `idx_media_asset_site_unique` exist on fresh and upgraded databases.

- [ ] **Step 1: Bump schema version**

In `lib/core/database/database.dart`:
- `static const int currentSchemaVersion = 147;` (line ~2939) becomes `148`.
- Append `148,` to the end of the `migrationVersions` list (line ~2944).
- Confirm `schemaVersion` getter reads `currentSchemaVersion` (it does; no other change).

- [ ] **Step 2: Add the migration block**

Directly after `if (from < 147) await reportProgress();` (line ~7666), add:

```dart
        if (from < 148) {
          // Site media (issues #211/#627). Query index for the site gallery;
          // dedupe cleanup + partial unique index mirroring the dive-side
          // v38 pair so the same gallery asset cannot be linked to the same
          // site twice. Keep the oldest duplicate (lowest created_at).
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_site_id
            ON media(site_id)
          ''');
          await customStatement('''
            DELETE FROM media WHERE id IN (
              SELECT m.id FROM media m
              INNER JOIN (
                SELECT platform_asset_id, site_id, MIN(created_at) as min_created
                FROM media
                WHERE platform_asset_id IS NOT NULL AND site_id IS NOT NULL
                GROUP BY platform_asset_id, site_id
                HAVING COUNT(*) > 1
              ) dupes ON m.platform_asset_id = dupes.platform_asset_id
                AND m.site_id = dupes.site_id
                AND m.created_at > dupes.min_created
            )
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_asset_site_unique
            ON media(platform_asset_id, site_id)
            WHERE platform_asset_id IS NOT NULL AND site_id IS NOT NULL
          ''');
        }
        if (from < 148) await reportProgress();
```

- [ ] **Step 3: Register the query index for fresh databases**

In `lib/core/database/performance_indexes.dart`, add to the media group (near `idx_media_platform_asset_id`, line ~176):

```dart
  (
    name: 'idx_media_site_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_site_id '
        'ON media(site_id)',
  ),
```

(The partial unique index is migration-created; check how `idx_media_asset_dive_unique` is asserted for fresh databases — search `database.dart` for `idx_media_asset_dive_unique` outside the `from < 38` block. If it is also created in `beforeOpen` or an `onCreate` path, add `idx_media_asset_site_unique` beside it the same way; if fresh databases get it purely via `onCreate` running all migrations, no extra step is needed.)

- [ ] **Step 4: Verify**

Run: `flutter test test/core/database/` (schema/migration tests)
Expected: PASS. If a schema-verification test asserts the exact version, it now sees 148 from the constant, so no fixture edit should be needed; if one fails listing expected indexes, add the two new names to it.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add v148 migration: media site index and site dedupe index"
```

### Task 4: HLC-stamped media cascade on site deletion

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Test: `test/features/media/data/media_repository_site_cascade_test.dart` (create)

**Interfaces:**
- Consumes: `MediaDeletionCoordinator` (`lib/features/media_store/data/media_deletion_coordinator.dart` — verify path via its import in `dive_repository_impl.dart`), `MediaTransferQueueRepository`.
- Produces:
  - `MediaRepository.partitionMediaForSiteDeletion(List<String> siteIds)` -> `({List<domain.MediaItem> doomed, List<String> unlinkIds})`
  - `MediaRepository.unlinkMediaFromDeletedSites(List<String> mediaIds)`
  - `SiteRepository` factory now injectable: `SiteRepository({MediaRepository? mediaRepository, MediaDeletionCoordinator? mediaDeletionCoordinator})`; `deleteSite(String id, {bool cascadeMedia = true})`, `bulkDeleteSites(List<String> ids, {bool cascadeMedia = true})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/media_repository_site_cascade_test.dart`, scaffolding copied from `test/features/media/data/media_repository_cascade_test.dart` (same DB harness and parent-row helpers). Test bodies:

```dart
  MediaItem _media({String? siteId, String? diveId, MediaSourceType sourceType =
      MediaSourceType.platformGallery}) => MediaItem(
    id: '',
    siteId: siteId,
    diveId: diveId,
    sourceType: sourceType,
    mediaType: MediaType.photo,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('partitionMediaForSiteDeletion', () {
    test('site-only media is doomed; dive-linked and library rows unlink',
        () async {
      // parent rows: site-1, dive-1 (insert with the harness helpers)
      final siteOnly = await repository.createMedia(_media(siteId: 'site-1'));
      final diveLinked = await repository.createMedia(
        _media(siteId: 'site-1', diveId: 'dive-1'),
      );
      final libraryRow = await repository.createMedia(
        _media(siteId: 'site-1', sourceType: MediaSourceType.networkUrl),
      );

      final split = await repository.partitionMediaForSiteDeletion(['site-1']);
      expect(split.doomed.map((m) => m.id), [siteOnly.id]);
      expect(
        split.unlinkIds.toSet(),
        {diveLinked.id, libraryRow.id},
      );
    });

    test('empty input returns empty partition', () async {
      final split = await repository.partitionMediaForSiteDeletion([]);
      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, isEmpty);
    });
  });

  group('unlinkMediaFromDeletedSites', () {
    test('nulls siteId and marks sync-pending', () async {
      final m = await repository.createMedia(_media(siteId: 'site-1'));
      await repository.unlinkMediaFromDeletedSites([m.id]);
      final after = await repository.getMediaById(m.id);
      expect(after!.siteId, isNull);
      // sync pending: assert via the same sync_pending query the dive
      // cascade test uses (copy its helper verbatim).
    });
  });
```

Also add a `SiteRepository.deleteSite` integration case: create site + site-only media + dive-linked media, call `SiteRepository(...).deleteSite('site-1')` with an injected recording `MediaDeletionCoordinator` fake (copy the fake from the dive cascade test), and assert: the site row is gone, the site-only item was passed to `deleteMediaItems`, the dive-linked row survives with `siteId == null`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/media_repository_site_cascade_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement the repository half**

In `media_repository.dart` directly below `unlinkMediaFromDeletedDives` (line ~1067):

```dart
  /// Splits a dying site's media: `doomed` rows die with the site
  /// (site-only, non-library), `unlinkIds` survive as dive-linked or
  /// library-level rows with siteId nulled. Site counterpart of
  /// [partitionMediaForDiveDeletion].
  Future<({List<domain.MediaItem> doomed, List<String> unlinkIds})>
  partitionMediaForSiteDeletion(List<String> siteIds) async {
    if (siteIds.isEmpty) {
      return (doomed: const <domain.MediaItem>[], unlinkIds: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.siteId.isIn(siteIds))).get();
    final doomed = <domain.MediaItem>[];
    final unlinkIds = <String>[];
    for (final row in rows) {
      final keep =
          row.diveId != null ||
          libraryLevelSourceTypes.contains(row.sourceType);
      if (keep) {
        unlinkIds.add(row.id);
      } else {
        doomed.add(_mapRowToMediaItem(row));
      }
    }
    return (doomed: doomed, unlinkIds: unlinkIds);
  }

  /// Explicitly unlinks surviving media from deleted sites, with the HLC
  /// stamp the silent FK SET NULL never produced. Site counterpart of
  /// [unlinkMediaFromDeletedDives].
  Future<void> unlinkMediaFromDeletedSites(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(siteId: const Value(null), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 4: Implement the site-repository half**

In `site_repository_impl.dart` (class is named `SiteRepository`, line 15):

1. Mirror `DiveRepository`'s injectable factory (see `dive_repository_impl.dart:62-84`):

```dart
  factory SiteRepository({
    MediaRepository? mediaRepository,
    MediaDeletionCoordinator? mediaDeletionCoordinator,
  }) {
    final media = mediaRepository ?? MediaRepository();
    return SiteRepository._(
      media,
      mediaDeletionCoordinator ??
          MediaDeletionCoordinator(
            mediaRepository: media,
            queue: () => MediaTransferQueueRepository(),
          ),
    );
  }

  SiteRepository._(this._mediaRepository, this._mediaDeletionCoordinator);

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _mediaDeletionCoordinator;
```

If `SiteRepository` currently has a default generative constructor used broadly, keep source compatibility: the factory above IS the unnamed constructor, so `SiteRepository()` callers compile unchanged. Copy the exact imports for `MediaDeletionCoordinator` and `MediaTransferQueueRepository` from `dive_repository_impl.dart`.

2. Add the cascade and wire it in:

```dart
  /// Cascade a dying site's media: site-only rows die with the site
  /// (via the coordinator's enqueue-before-delete path); dive-linked and
  /// library-level rows survive with siteId nulled and HLC-stamped.
  /// Mirrors DiveRepository._cascadeMediaForDiveDeletion.
  Future<void> _cascadeMediaForSiteDeletion(List<String> ids) async {
    final split = await _mediaRepository.partitionMediaForSiteDeletion(ids);
    if (split.doomed.isNotEmpty) {
      await _mediaDeletionCoordinator.deleteMediaItems(split.doomed);
    }
    if (split.unlinkIds.isNotEmpty) {
      await _mediaRepository.unlinkMediaFromDeletedSites(split.unlinkIds);
    }
  }
```

In `deleteSite` (line ~301) add the parameter and call before the row delete:

```dart
  Future<void> deleteSite(String id, {bool cascadeMedia = true}) async {
    try {
      _log.info('Deleting site: $id');
      if (cascadeMedia) await _cascadeMediaForSiteDeletion([id]);
      await (_db.delete(_db.diveSites)..where((t) => t.id.equals(id))).go();
      ...
```

Same pattern in `bulkDeleteSites` (line ~336): `if (cascadeMedia) await _cascadeMediaForSiteDeletion(ids);` before the bulk delete.

3. Check the site MERGE path (`mergeSites`, line ~359 onward): it relinks media to the survivor via `_relinkMedia` BEFORE deleting merged-away sites. Find how merged sites are deleted — if via `deleteSite`/`bulkDeleteSites`, pass `cascadeMedia: false` there (media was already relinked; the cascade must not race the undo snapshot). If it deletes rows directly with `_db.delete`, leave it as is.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/media/data/media_repository_site_cascade_test.dart test/features/media/data/media_repository_cascade_test.dart test/features/dive_sites/`
Expected: PASS (existing site tests confirm the factory change broke nothing).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Cascade site deletion through media partition with HLC stamps"
```

---

## Phase 2: Providers

### Task 5: Site media providers

**Files:**
- Create: `lib/features/media/presentation/providers/site_media_providers.dart`
- Test: `test/features/media/presentation/providers/site_media_providers_test.dart` (create)

**Interfaces:**
- Consumes: `mediaRepositoryProvider`, `mediaDeletionCoordinatorProvider` (exported by `media_store_providers.dart`), `diveRepositoryProvider.getDivesForSite(siteId)`.
- Produces:
  - `mediaForSiteProvider` — `FutureProvider.family<List<MediaItem>, String>`
  - `mediaCountForSiteProvider` — `FutureProvider.family<int, String>`
  - `siteMediaListNotifierProvider` — `StateNotifierProvider.family<SiteMediaListNotifier, AsyncValue<List<MediaItem>>, String>` with `refresh()`, `addMedia(MediaItem)`, `updateMedia(MediaItem)`, `deleteMultipleMedia(List<String>)`
  - `mediaFromDivesAtSiteProvider` — `FutureProvider.family<Map<Dive, List<MediaItem>>, String>` (dive-photo aggregation, trip pattern)
  - `flatMediaFromDivesAtSiteProvider` — `FutureProvider.family<List<MediaItem>, String>` (viewer navigation, sorted by takenAt)

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/providers/site_media_providers_test.dart`. Use a `ProviderContainer` with the real repository over the standard in-memory DB harness (copy container setup from `test/features/media/presentation/providers/` siblings — if none exists there, copy the DB harness from `media_repository_site_test.dart` and build a bare `ProviderContainer()`):

```dart
  test('mediaForSiteProvider returns direct attachments', () async {
    // seed site-1 + one media row via MediaRepository
    final list = await container.read(mediaForSiteProvider('site-1').future);
    expect(list, hasLength(1));
    expect(await container.read(mediaCountForSiteProvider('site-1').future), 1);
  });

  test('notifier deleteMultipleMedia removes rows and refreshes', () async {
    // seed site-1 with two media rows m1, m2 via MediaRepository.createMedia
    final notifier = container.read(
      siteMediaListNotifierProvider('site-1').notifier,
    );
    await notifier.refresh();
    await notifier.deleteMultipleMedia([m1.id]);
    final state = container.read(siteMediaListNotifierProvider('site-1'));
    expect(state.value!.map((m) => m.id), [m2.id]);
  });

  test('mediaFromDivesAtSiteProvider groups by dive and drops empty dives',
      () async {
    // seed dive-1 at site-1 with one media row, dive-2 at site-1 with none
    final grouped = await container.read(
      mediaFromDivesAtSiteProvider('site-1').future,
    );
    expect(grouped.keys.map((d) => d.id), ['dive-1']);
  });
```

Flesh out seeding with the same parent-row helpers as Task 2's test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/providers/site_media_providers_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/media/presentation/providers/site_media_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Media directly attached to a site (attachments group), ordered by takenAt.
final mediaForSiteProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaForSite(siteId);
});

/// Count of direct site attachments (badges/headers).
final mediaCountForSiteProvider = FutureProvider.family<int, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaCountForSite(siteId);
});

/// Media from dives logged at the site, grouped by dive with empty dives
/// dropped. Same bounded fan-out as mediaForTripProvider.
final mediaFromDivesAtSiteProvider =
    FutureProvider.family<Map<Dive, List<MediaItem>>, String>((
      ref,
      siteId,
    ) async {
      final dives = await ref
          .watch(diveRepositoryProvider)
          .getDivesForSite(siteId);
      if (dives.isEmpty) return {};

      const chunkSize = 12;
      final mediaLists = <List<MediaItem>>[];
      for (var offset = 0; offset < dives.length; offset += chunkSize) {
        final chunk = dives.skip(offset).take(chunkSize);
        mediaLists.addAll(
          await Future.wait(
            chunk.map(
              (dive) => ref.watch(mediaForDiveProvider(dive.id).future),
            ),
          ),
        );
      }

      final Map<Dive, List<MediaItem>> result = {};
      for (var i = 0; i < dives.length; i++) {
        if (mediaLists[i].isNotEmpty) {
          result[dives[i]] = mediaLists[i];
        }
      }
      return result;
    });

/// Flat, chronological dive-photo list for the site viewer.
final flatMediaFromDivesAtSiteProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, siteId) async {
      final grouped = await ref.watch(
        mediaFromDivesAtSiteProvider(siteId).future,
      );
      final all = grouped.values.expand((list) => list).toList();
      all.sort((a, b) => a.takenAt.compareTo(b.takenAt));
      return all;
    });

/// Mutations on a site's direct attachments. Site counterpart of
/// MediaListNotifier.
class SiteMediaListNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  final Ref _ref;
  final String _siteId;

  SiteMediaListNotifier(this._repository, this._ref, this._siteId)
    : super(const AsyncValue.loading()) {
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    state = const AsyncValue.loading();
    try {
      final media = await _repository.getMediaForSite(_siteId);
      state = AsyncValue.data(media);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMedia();
    _ref.invalidate(mediaForSiteProvider(_siteId));
    _ref.invalidate(mediaCountForSiteProvider(_siteId));
  }

  Future<MediaItem> addMedia(MediaItem item) async {
    final newItem = await _repository.createMedia(item);
    await refresh();
    return newItem;
  }

  Future<void> updateMedia(MediaItem item) async {
    await _repository.updateMedia(item);
    await refresh();
    _ref.invalidate(mediaByIdProvider(item.id));
  }

  /// Routed through the deletion coordinator so remote-blob delete intents
  /// are enqueued before rows die (orphan-prevention spec 5.2).
  Future<void> deleteMultipleMedia(List<String> ids) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids);
    await refresh();
  }
}

final siteMediaListNotifierProvider =
    StateNotifierProvider.family<
      SiteMediaListNotifier,
      AsyncValue<List<MediaItem>>,
      String
    >((ref, siteId) {
      final repository = ref.watch(mediaRepositoryProvider);
      return SiteMediaListNotifier(repository, ref, siteId);
    });
```

Verify `getDivesForSite` exists on the dive repository (`dive_repository_impl.dart:2046`) and returns `List<Dive>`; verify `invalidateSelfWhen` is available via `core/providers/provider.dart` (it is used the same way in `mediaForDiveProvider`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/providers/site_media_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add site media providers and mutation notifier"
```

---

## Phase 3: Shared grid extraction

### Task 6: Extract shared media grid pieces

**Files:**
- Create: `lib/features/media/presentation/widgets/media_grid.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Test: existing `test/features/media/presentation/widgets/dive_media_section_test.dart` must keep passing; new `test/features/media/presentation/widgets/media_grid_test.dart`

**Interfaces:**
- Produces (all in `media_grid.dart`, all taking display strings as parameters — NO `context.l10n` inside these shared widgets, per the global l10n constraint):

```dart
class MediaSelectionHeader extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onUnlinkSelected;
  final String selectedCountLabel;   // e.g. l10n.media_diveMediaSection_selectedCount(n)
  final String selectAllLabel;
  final String cancelTooltip;
  final String unlinkTooltip;
  const MediaSelectionHeader({...});
}

class MediaEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const MediaEmptyState({required this.icon, required this.message, ...});
}

class MediaThumbnailTile extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;
  final bool isSelectionMode;
  final bool isSelected;
  final String semanticsLabel;
  const MediaThumbnailTile({...});
}

class OrphanedMediaPlaceholder extends StatelessWidget { ... }
```

- [ ] **Step 1: Move the pieces**

Create `media_grid.dart` by MOVING (not copying) these private classes out of `dive_media_section.dart`, renamed public:
- `_SelectionHeader` -> `MediaSelectionHeader` (lines 467-514). Replace the four `context.l10n.*` calls with the new string parameters.
- `_EmptyMediaState` -> `MediaEmptyState` (lines 517-551). Parameterize icon and message (`Icons.photo_camera_outlined` + `l10n.media_diveMediaSection_emptyState` become the dive call-site's arguments).
- `_MediaThumbnailContent` -> `MediaThumbnailTile` (lines 559-688). Parameterize the semantics label. Keep the store badge, video badge, selection overlays, and depth badge exactly as they are (the depth badge self-hides when `item.enrichment == null`, so site usage needs no flag). Add ONE new branch after the video-icon block — the document tile treatment:

```dart
            // Document badge (top-right, mirrors the video badge slot)
            if (item.isDocument && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.documentExtension.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
```

- `_OrphanedPlaceholder` -> `OrphanedMediaPlaceholder` (lines 691-708).

Imports for the new file: copy from `dive_media_section.dart` (MediaItem, MediaItemView, MediaStoreBadge, UnitFormatter, settings providers, material).

- [ ] **Step 2: Rewire `DiveMediaSection`**

In `dive_media_section.dart`: import `media_grid.dart`; replace the four private-class usages with the public ones, passing the l10n strings at the call sites, e.g.:

```dart
              mediaAsync.whenOrNull(
                    data: (media) => MediaSelectionHeader(
                      selectedCount: _selectedIndices.length,
                      totalCount: media.length,
                      onSelectAll: () => _selectAll(media.length),
                      onCancel: _exitSelectionMode,
                      onUnlinkSelected: () => _unlinkSelected(context, media),
                      selectedCountLabel: context.l10n
                          .media_diveMediaSection_selectedCount(
                            _selectedIndices.length,
                          ),
                      selectAllLabel: context
                          .l10n.media_diveMediaSection_selectAllButton,
                      cancelTooltip: context
                          .l10n.media_diveMediaSection_cancelSelectionButton,
                      unlinkTooltip: context.l10n
                          .media_diveMediaSection_unlinkSelectedButton(
                            _selectedIndices.length,
                          ),
                    ),
                  ) ??
                  const SizedBox.shrink()
```

and

```dart
                if (media.isEmpty) {
                  return MediaEmptyState(
                    icon: Icons.photo_camera_outlined,
                    message: context.l10n.media_diveMediaSection_emptyState,
                  );
                }
```

and in the itemBuilder:

```dart
                  itemBuilder: (context, item, isSelected) {
                    final thumbnail = MediaThumbnailTile(
                      item: item,
                      settings: settings,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      semanticsLabel:
                          context.l10n.media_diveMediaSection_thumbnailLabel,
                    );
                    ...
```

The orphaned branch inside `MediaThumbnailTile` moves WITH the tile (the tile itself decides `item.isOrphaned ? OrphanedMediaPlaceholder() : MediaItemView(...)`) so both sections get it for free — mirror how `_MediaThumbnailContent` currently receives the decision from outside (lines 589-597) by moving that `if` INSIDE the tile's build.

- [ ] **Step 3: Write the grid test**

Create `test/features/media/presentation/widgets/media_grid_test.dart` (harness copied from `dive_media_section_test.dart` — MaterialApp + ProviderScope with overrides):

```dart
  testWidgets('MediaEmptyState renders icon and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaEmptyState(icon: Icons.map_outlined, message: 'No media'),
        ),
      ),
    );
    expect(find.text('No media'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });

  testWidgets('MediaSelectionHeader disables unlink at zero selection',
      (tester) async {
    // pump with selectedCount: 0 and assert the delete IconButton onPressed
    // is null; with selectedCount: 1 assert it is enabled.
  });
```

(Do not attempt to render `MediaThumbnailTile` with a real item — it needs the resolver pipeline; the existing dive tests already cover the composed rendering paths.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/media/presentation/widgets/media_grid_test.dart test/features/media/presentation/widgets/dive_media_section_test.dart test/features/media/presentation/widgets/dive_media_section_lightroom_test.dart`
Expected: PASS — the refactor is behavior-preserving.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Extract shared media grid pieces from DiveMediaSection"
```

---

## Phase 4: Site UI

### Task 7: Site media viewer page

**Files:**
- Create: `lib/features/media/presentation/pages/site_media_viewer_page.dart`
- Test: `test/features/media/presentation/pages/site_media_viewer_page_test.dart` (create)

**Interfaces:**
- Consumes: `mediaForSiteProvider`, `flatMediaFromDivesAtSiteProvider` (Task 5), `MediaItemView`, `resolvedFullResolutionProvider`, `writeShareTempFile`.
- Produces: `SiteMediaViewerPage({required String siteId, required String initialMediaId, required SiteViewerScope scope})` where `enum SiteViewerScope { attachments, divePhotos }` picks which list backs the pager.

- [ ] **Step 1: Implement the page**

Model on `trip_photo_viewer_page.dart` with these deltas (copy its structure wholesale, then apply):

1. Class/fields:

```dart
enum SiteViewerScope { attachments, divePhotos }

class SiteMediaViewerPage extends ConsumerStatefulWidget {
  final String siteId;
  final String initialMediaId;
  final SiteViewerScope scope;

  const SiteMediaViewerPage({
    super.key,
    required this.siteId,
    required this.initialMediaId,
    required this.scope,
  });
  ...
}
```

2. List source in `build` — filter documents out (they open in `DocumentViewerPage`, not the photo pager):

```dart
    final sourceAsync = widget.scope == SiteViewerScope.attachments
        ? ref.watch(mediaForSiteProvider(widget.siteId))
        : ref.watch(flatMediaFromDivesAtSiteProvider(widget.siteId));
    final mediaAsync = sourceAsync.whenData(
      (list) => list.where((m) => !m.isDocument).toList(),
    );
```

3. Drop the dive-context pieces: no `mediaForTripProvider` lookup, no `_findDiveForMedia`, no `PositionedMiniProfileOverlay`, and the bottom overlay passes `siteName: null` (delete the site-name row entirely). Everything else — immersive mode, `PhotoViewGallery` via `MediaItemView(fit: BoxFit.contain)`, swipe-down-to-close, share via `resolvedFullResolutionProvider` + `writeShareTempFile` + `SharePlus` — stays identical to the trip page (reuse its l10n keys `media_photoViewer_*`, which are viewer-generic).

4. The private helper classes `_PhotoGallery`, `_TopOverlay`, `_BottomMetadataOverlay`, `_MetadataChip` are small and page-private in the trip file; replicate the ones you need privately in this file rather than exporting them from the trip page (they are 40-120 lines each; page-private duplication is the established pattern — the trip page itself duplicated them from `photo_viewer_page.dart`).

- [ ] **Step 2: Write the smoke test**

```dart
  testWidgets('shows empty message when site has no photos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaForSiteProvider('site-1').overrideWith(
            (ref) async => const <MediaItem>[],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'x',
            scope: SiteViewerScope.attachments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // media_photoViewer_noPhotosAvailable, English value:
    expect(find.textContaining('No photos'), findsOneWidget);
  });
```

If the family override syntax differs in this Riverpod version, copy the override style from an existing provider-family widget test (e.g. how `dive_media_section_test.dart` overrides `mediaForDiveProvider`); match the found text to the actual English value of `media_photoViewer_noPhotosAvailable` in `app_en.arb`.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/media/presentation/pages/site_media_viewer_page_test.dart`
Expected: PASS.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add site-scoped media viewer page"
```

### Task 8: SiteMediaSection widget

**Files:**
- Create: `lib/features/media/presentation/widgets/site_media_section.dart`
- Test: `test/features/media/presentation/widgets/site_media_section_test.dart` (create)

**Interfaces:**
- Consumes: Task 5 providers, Task 6 grid pieces, Task 7 viewer. Document opening is injected via callback (wired to `DocumentOpenHelper` in Task 13), so this task has no dependency on the viewer pages.
- Produces: `SiteMediaSection({required String siteId, VoidCallback? onAddPhotosPressed, VoidCallback? onAddDocumentPressed, void Function(MediaItem)? onOpenDocument})` — the section renders the attachments grid + dive-photos group; add actions and document-opening are injected by the page (keeps this widget free of picker/viewer wiring, mirroring how `DiveMediaSection` takes `onAddPressed`).

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/site_media_section_test.dart` (harness from `dive_media_section_test.dart`, overriding `mediaForSiteProvider` / `mediaFromDivesAtSiteProvider` / `siteMediaListNotifierProvider` dependencies via a real container over the in-memory DB, or provider overrides — follow whichever style the dive test uses):

```dart
  Widget _host({VoidCallback? onPhotos, VoidCallback? onDoc}) => ProviderScope(
    overrides: [
      mediaForSiteProvider('site-1').overrideWith(
        (ref) async => const <MediaItem>[],
      ),
      mediaFromDivesAtSiteProvider('site-1').overrideWith(
        (ref) async => const <Dive, List<MediaItem>>{},
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SiteMediaSection(
          siteId: 'site-1',
          onAddPhotosPressed: onPhotos,
          onAddDocumentPressed: onDoc,
        ),
      ),
    ),
  );

  testWidgets('empty state renders site empty message', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(
      find.text('No maps, photos, or documents attached to this site'),
      findsOneWidget,
    );
  });

  testWidgets('add menu exposes photos and document actions', (tester) async {
    var photos = 0;
    var docs = 0;
    await tester.pumpWidget(
      _host(onPhotos: () => photos++, onDoc: () => docs++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add document'));
    await tester.pumpAndSettle();
    expect(docs, 1);
    expect(photos, 0);
  });

  testWidgets('dive photos group hidden when no dives have media',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
  });
```

(The settings provider may need overriding too — copy whatever overrides `dive_media_section_test.dart` pumps with. If family `.overrideWith` on a `FutureProvider.family` needs different syntax in this Riverpod version, mirror the dive test's override style.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/site_media_section_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Implement**

Create `site_media_section.dart`. Structure (follow `DiveMediaSection`'s state handling for selection mode; ~250 lines):

```dart
class SiteMediaSection extends ConsumerStatefulWidget {
  final String siteId;
  final VoidCallback? onAddPhotosPressed;
  final VoidCallback? onAddDocumentPressed;
  final void Function(MediaItem)? onOpenDocument;

  const SiteMediaSection({
    super.key,
    required this.siteId,
    this.onAddPhotosPressed,
    this.onAddDocumentPressed,
    this.onOpenDocument,
  });
  ...
}
```

Build, inside a `Card` (same padding/typography as `DiveMediaSection`):

1. Header row: `Icons.photo_library` icon, `context.l10n.media_siteMediaSection_title`, spacer, and a `PopupMenuButton<String>` with `Icons.add_photo_alternate` as its child exposing two items — `'photos'` (`l10n.media_siteMediaSection_addPhotos`) and `'document'` (`l10n.media_siteMediaSection_addDocument`) — dispatching to the two callbacks. In selection mode swap the header for `MediaSelectionHeader` wired to `siteMediaListNotifierProvider(widget.siteId).notifier.deleteMultipleMedia` with a confirm dialog (copy `_unlinkSelected` from `DiveMediaSection`, swapping the notifier and the l10n keys for the `media_siteMediaSection_*` variants).
2. Attachments grid: `ref.watch(mediaForSiteProvider(widget.siteId))` -> empty: `MediaEmptyState(icon: Icons.map_outlined, message: l10n.media_siteMediaSection_emptyState)`; non-empty: `DragSelectGridView<MediaItem>` exactly as `DiveMediaSection` builds it (4 columns, shrinkWrap, `MediaThumbnailTile` items), with `onItemTap`:

```dart
                  onItemTap: (index) {
                    final item = media[index];
                    if (item.isDocument) {
                      widget.onOpenDocument?.call(item);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => SiteMediaViewerPage(
                          siteId: widget.siteId,
                          initialMediaId: item.id,
                          scope: SiteViewerScope.attachments,
                        ),
                      ),
                    );
                  },
```

3. Dive-photos group, collapsed by default so site reference material stays prominent (spec decision 2):

```dart
            final grouped =
                ref.watch(mediaFromDivesAtSiteProvider(widget.siteId));
            ...
            if (flat.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: false,
                title: Text(
                  context.l10n.media_siteMediaSection_divePhotosGroup(
                    flat.length,
                  ),
                  style: textTheme.titleSmall,
                ),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: flat.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => SiteMediaViewerPage(
                            siteId: widget.siteId,
                            initialMediaId: flat[index].id,
                            scope: SiteViewerScope.divePhotos,
                          ),
                        ),
                      ),
                      child: MediaThumbnailTile(
                        item: flat[index],
                        settings: settings,
                        isSelectionMode: false,
                        isSelected: false,
                        semanticsLabel: context
                            .l10n.media_siteMediaSection_divePhotoLabel,
                      ),
                    ),
                  ),
                ],
              ),
```

where `flat` is the grouped map's values flattened in `takenAt` order (compute inline; the dive-photos group is read-only, no selection mode).

- [ ] **Step 4: Add the l10n keys (English only for now)**

Add to `lib/l10n/arb/app_en.arb` (full-locale sweep happens in Task 14):

```json
  "media_siteMediaSection_title": "Site Media",
  "media_siteMediaSection_addPhotos": "Add photos or videos",
  "media_siteMediaSection_addDocument": "Add document",
  "media_siteMediaSection_emptyState": "No maps, photos, or documents attached to this site",
  "media_siteMediaSection_divePhotosGroup": "Photos from dives here ({count})",
  "@media_siteMediaSection_divePhotosGroup": {
    "placeholders": { "count": { "type": "int" } }
  },
  "media_siteMediaSection_divePhotoLabel": "Dive photo",
  "media_siteMediaSection_unlinkSelectedTitle": "Remove {count} attachments?",
  "@media_siteMediaSection_unlinkSelectedTitle": {
    "placeholders": { "count": { "type": "int" } }
  },
  "media_siteMediaSection_unlinkSelectedContent": "The selected items will be removed from this site. Files in your photo library or on disk are not deleted.",
  "@media_siteMediaSection_unlinkSelectedContent": {
    "placeholders": { "count": { "type": "int" } }
  },
  "media_siteMediaSection_unlinkSelectedSuccess": "Removed {count} attachments",
  "@media_siteMediaSection_unlinkSelectedSuccess": {
    "placeholders": { "count": { "type": "int" } }
  }
```

Match the exact placeholder/metadata style of the neighboring `media_diveMediaSection_*` keys in `app_en.arb` (open them and copy the format — some use `num` with plurals; mirror whichever form the dive keys use). Run `flutter gen-l10n`. Other locales get a temporary English copy ONLY if `flutter analyze` requires all locales to define every key (it does — untranslated keys fail generation); in that case copy the English strings into the other 10 ARBs now and mark Task 14 as the translation pass.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/media/presentation/widgets/site_media_section_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add SiteMediaSection with attachments grid and dive photos group"
```

### Task 9: Site photo import and detail-page mount

**Files:**
- Modify: `lib/features/media/data/services/media_import_service.dart`
- Create: `lib/features/media/presentation/helpers/site_media_import_helper.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- Test: `test/features/media/data/services/media_import_service_site_test.dart` (create)

**Interfaces:**
- Consumes: `showPhotoPicker` (`photo_picker_page.dart:~695` — takes `diveStartTime`/`diveEndTime`/`buffer`/`alreadyLinkedIds`/optional `diveId`), `mediaImportServiceProvider` (`photo_picker_providers.dart:239`), Task 5 providers.
- Produces:
  - `MediaImportService.importPhotosForSite({required List<AssetInfo> selectedAssets, required String siteId})` -> `ImportResult` — same dedupe semantics as the dive version, no enrichment.
  - `SiteMediaImportHelper.importPhotosForSite({required BuildContext context, required WidgetRef ref, required String siteId})` -> `Future<bool>`.

- [ ] **Step 1: Write the failing service test**

Create `test/features/media/data/services/media_import_service_site_test.dart`, harness copied from the existing `media_import_service` test in `test/features/media/data/services/` (find it with `ls`; it constructs the service with an in-memory repository and a fake documents directory):

```dart
  test('importPhotosForSite links assets to the site without enrichment',
      () async {
    final result = await service.importPhotosForSite(
      selectedAssets: [assetInfo('a1'), assetInfo('a2')],
      siteId: 'site-1',
    );
    expect(result.imported, hasLength(2));
    expect(result.imported.every((m) => m.siteId == 'site-1'), isTrue);
    expect(result.imported.every((m) => m.diveId == null), isTrue);
  });

  test('importPhotosForSite skips assets already linked to the site',
      () async {
    await service.importPhotosForSite(
      selectedAssets: [assetInfo('a1')],
      siteId: 'site-1',
    );
    final second = await service.importPhotosForSite(
      selectedAssets: [assetInfo('a1')],
      siteId: 'site-1',
    );
    expect(second.imported, isEmpty);
    expect(second.skippedDuplicates, 1);
  });
```

(`assetInfo(...)` = whatever AssetInfo factory the existing service test uses; reuse it.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/media_import_service_site_test.dart`
Expected: FAIL — method undefined.

- [ ] **Step 3: Implement `importPhotosForSite`**

In `media_import_service.dart`, below `importPhotosForDive` (line ~189). It is `importPhotosForDive` minus enrichment, with site dedupe lookups and a site-flavored row builder. Extract the shared per-asset row construction rather than duplicating: rename `_createMediaItemFromAsset(AssetInfo asset, String diveId)` to `_createMediaItemFromAsset(AssetInfo asset, {String? diveId, String? siteId})` and set both fields in the returned `MediaItem` (`diveId: diveId, siteId: siteId`); the dive call site passes `diveId:`, the new site loop passes `siteId:`. The new method:

```dart
  /// Import selected assets as direct site attachments. Same dedupe
  /// contract as [importPhotosForDive]; no enrichment (sites have no
  /// profile to position photos on).
  Future<ImportResult> importPhotosForSite({
    required List<AssetInfo> selectedAssets,
    required String siteId,
  }) async {
    final List<MediaItem> imported = [];
    final Map<String, String> failures = {};

    bool hasPath(AssetInfo a) => a.filePath != null && a.filePath!.isNotEmpty;
    final anyPaths = selectedAssets.any(hasPath);
    final anyGallery = selectedAssets.any((a) => !hasPath(a));

    final existingAssetIds = anyGallery
        ? await _mediaRepository.getLinkedAssetIdsForSite(siteId)
        : const <String>{};
    final existingPaths = anyPaths
        ? await _mediaRepository.getLinkedLocalPathsForSite(siteId)
        : const <String>{};

    final newAssets = selectedAssets.where((a) {
      if (hasPath(a)) return !existingPaths.contains(a.filePath);
      return !existingAssetIds.contains(a.id);
    }).toList();
    final skippedCount = selectedAssets.length - newAssets.length;

    for (final asset in newAssets) {
      try {
        final mediaItem = _createMediaItemFromAsset(asset, siteId: siteId);
        final saved = await _mediaRepository.createMedia(mediaItem);
        imported.add(saved);
        onMediaCreated?.call(saved.id);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to import asset ${asset.id} for site',
          error: e,
          stackTrace: stackTrace,
        );
        failures[asset.id] = e.toString();
      }
    }

    return ImportResult(
      imported: imported,
      failures: failures,
      skippedDuplicates: skippedCount,
    );
  }
```

- [ ] **Step 4: Implement the helper**

Create `site_media_import_helper.dart`, modeled on `photo_import_helper.dart` with the dive-window logic removed — a site has no time window, so the picker opens wide:

```dart
class SiteMediaImportHelper {
  /// Opens the photo picker (no date filtering) and imports the selection
  /// as direct site attachments. Returns true if anything was imported.
  static Future<bool> importPhotosForSite({
    required BuildContext context,
    required WidgetRef ref,
    required String siteId,
  }) async {
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final alreadyLinkedIds = await mediaRepo.getLinkedAssetIdsForSite(siteId);
    if (!context.mounted) return false;

    // Sites have no dive window: open the picker over all time. buffer is
    // zeroed so showPhotoPicker does not widen the range further.
    final selectedAssets = await showPhotoPicker(
      context: context,
      diveStartTime: DateTime.fromMillisecondsSinceEpoch(0),
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
      alreadyLinkedIds: alreadyLinkedIds,
    );
    if (selectedAssets == null ||
        selectedAssets.isEmpty ||
        !context.mounted) {
      return false;
    }

    try {
      final importService = ref.read(mediaImportServiceProvider);
      final result = await importService.importPhotosForSite(
        selectedAssets: selectedAssets,
        siteId: siteId,
      );
      ref.invalidate(mediaForSiteProvider(siteId));
      ref.invalidate(mediaCountForSiteProvider(siteId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_importedPhotos(
                result.imported.length,
              ),
            ),
          ),
        );
      }
      return result.imported.isNotEmpty;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_failedToImportError(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }
}
```

Imports mirror `photo_import_helper.dart` plus `site_media_providers.dart`. Note the picker's Files tab: `showPhotoPicker` without `diveId` shows the Files tab in its no-dive mode (files land unmatched, Link button hidden) — acceptable for now; the Files tab is desktop-only surface and the gallery tab is the site flow's path. Do NOT try to thread siteId through the Files tab in this task.

- [ ] **Step 5: Mount on the site detail page**

In `site_detail_page.dart` after the `SiteMarineLifeSection` block (line ~216) insert:

```dart
          // Site Media Section (attachments + dive photos)
          SiteMediaSection(
            siteId: site.id,
            onAddPhotosPressed: () => SiteMediaImportHelper.importPhotosForSite(
              context: context,
              ref: ref,
              siteId: site.id,
            ),
            onAddDocumentPressed: null, // wired in Task 13
            onOpenDocument: null, // wired in Task 13
          ),
          const SizedBox(height: 16),
```

Add the imports. The page is a `ConsumerStatefulWidget` (`_SiteDetailContentState` has `ref` available); if the build method in scope only has `context`, use the state's `ref` field directly.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/media/data/services/media_import_service_site_test.dart test/features/dive_sites/`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add site photo import flow and mount SiteMediaSection"
```

---

## Phase 5: Documents and PDF

### Task 10: Document import service (reference-linking)

**Files:**
- Create: `lib/features/media/data/services/document_import_service.dart`
- Create: provider registration in `lib/features/media/presentation/providers/site_media_providers.dart` (append)
- Test: `test/features/media/data/services/document_import_service_test.dart` (create)

**Interfaces:**
- Consumes: `LocalMediaPlatform` (`createBookmark`, `takePersistableUri`) and `LocalBookmarkStorage` — copy the exact types/imports from `files_tab_providers.dart` (`localMediaPlatformProvider`, `localBookmarkStorageProvider`); `MediaRepository.createMedia`; `onMediaCreated` hook.
- Produces: `DocumentImportService.importDocuments({required List<({String path, String filename})> picked, String? diveId, String? siteId})` -> `Future<List<MediaItem>>`; `documentImportServiceProvider`.
- Allowed extensions constant: `DocumentImportService.allowedExtensions = ['pdf', 'doc', 'docx', 'txt', 'gpx']`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/document_import_service_test.dart` with fake platform/bookmark storage (copy the fakes from `test/features/media/presentation/providers/files_tab_providers_test.dart` — it tests `_persistOne`'s branches with the same seams):

```dart
  test('imports a pdf as a document media row linked to the site', () async {
    final created = await service.importDocuments(
      picked: [(path: '/tmp/reef-map.pdf', filename: 'reef-map.pdf')],
      siteId: 'site-1',
    );
    expect(created, hasLength(1));
    final item = created.single;
    expect(item.mediaType, MediaType.document);
    expect(item.siteId, 'site-1');
    expect(item.sourceType, MediaSourceType.localFile);
    expect(item.originalFilename, 'reef-map.pdf');
  });

  test('links to a dive when diveId is given', () async {
    final created = await service.importDocuments(
      picked: [(path: '/tmp/waiver.pdf', filename: 'waiver.pdf')],
      diveId: 'dive-1',
    );
    expect(created.single.diveId, 'dive-1');
    expect(created.single.siteId, isNull);
  });

  test('fires onMediaCreated per row for media-store enqueue', () async {
    // service constructed with a recording onMediaCreated callback;
    // expect one call per imported row.
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/document_import_service_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `document_import_service.dart`. The persist logic is `FilesTabNotifier._persistOne` (`files_tab_providers.dart:260-...`) retargeted at documents — reference-everything, per-platform (spec decisions 5 and the per-platform semantics block):

```dart
/// Links picked document files (PDFs and common formats) to a dive or a
/// site by reference — bookmark on iOS/macOS, persisted SAF URI on
/// Android, plain path on Windows/Linux. Never copies bytes; the media
/// store upload (enqueued via [onMediaCreated]) is the durability path.
class DocumentImportService {
  DocumentImportService({
    required this.mediaRepository,
    required this.platform,
    required this.bookmarkStorage,
    this.onMediaCreated,
  });

  final MediaRepository mediaRepository;
  final LocalMediaPlatform platform;
  final LocalBookmarkStorage bookmarkStorage;
  final void Function(String mediaId)? onMediaCreated;
  final _uuid = const Uuid();

  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'gpx',
  ];

  Future<List<MediaItem>> importDocuments({
    required List<({String path, String filename})> picked,
    String? diveId,
    String? siteId,
  }) async {
    assert(
      (diveId == null) != (siteId == null),
      'exactly one of diveId/siteId must be set',
    );
    final created = <MediaItem>[];
    for (final file in picked) {
      String? localPath;
      String? bookmarkRef;

      if (Platform.isIOS || Platform.isMacOS) {
        final blob = await platform.createBookmark(file.path);
        bookmarkRef = _uuid.v4();
        await bookmarkStorage.write(bookmarkRef, blob);
        if (Platform.isMacOS) {
          localPath = file.path;
        }
      } else if (Platform.isAndroid) {
        bookmarkRef = await platform.takePersistableUri(file.path);
      } else {
        localPath = file.path;
      }

      final now = DateTime.now();
      final item = MediaItem(
        id: '',
        diveId: diveId,
        siteId: siteId,
        mediaType: MediaType.document,
        sourceType: MediaSourceType.localFile,
        originalFilename: file.filename,
        localPath: localPath,
        bookmarkRef: bookmarkRef,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final saved = await mediaRepository.createMedia(item);
      onMediaCreated?.call(saved.id);
      created.add(saved);
    }
    return created;
  }
}
```

Imports: `dart:io`, uuid, media_item/media_source_type, media_repository, plus the `LocalMediaPlatform`/`LocalBookmarkStorage` types (find their files via the imports of `files_tab_providers.dart`). Platform branches make macOS-host tests exercise the bookmark path; keep the fakes' platform override seam identical to the files-tab tests (if those tests inject a platform wrapper rather than branching on `Platform`, mirror THAT design instead — read them first).

Append the provider to `site_media_providers.dart`:

```dart
final documentImportServiceProvider = Provider<DocumentImportService>((ref) {
  return DocumentImportService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    platform: ref.watch(localMediaPlatformProvider),
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    onMediaCreated: ref.watch(mediaStoreEnqueueProvider),
  );
});
```

Check how `mediaImportServiceProvider` (`photo_picker_providers.dart:239`) obtains its `onMediaCreated` — use the identical source (it may be `mediaStoreEnqueueProvider` or a function read from `media_store_enqueue_provider.dart:8`); copy that wiring exactly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/services/document_import_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add reference-linking document import service"
```

### Task 11: pdfrx dependency and PDF page renderer

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/media/data/services/pdf_page_renderer.dart`
- Create: `test/fixtures/sample.pdf` (tiny fixture)
- Test: `test/features/media/data/services/pdf_page_renderer_test.dart` (create)

**Interfaces:**
- Produces: `PdfPageRenderer.renderFirstPageJpeg({File? file, Uint8List? bytes, int maxDimension = 512, int quality = 80})` -> `Future<Uint8List?>` (null on any failure — corrupt file, zero pages, engine error). Static-method utility class; safe to call from any isolate that has run `pdfrxInitialize()` (the renderer calls it lazily itself).

- [ ] **Step 1: Add the dependency**

```bash
flutter pub add pdfrx
```

Then open `pubspec.yaml` and record the resolved version constraint. Confirm `flutter pub get` succeeds. pdfrx supports iOS/Android/macOS/Windows/Linux (pdfium-based) — if `pub add` surfaces a platform-support error for any of the five targets, STOP and flag it (fallback candidate: `pdfx`), do not proceed silently.

- [ ] **Step 2: Create the fixture**

`test/fixtures/sample.pdf` — a minimal one-page PDF. Write these exact bytes as text:

```
%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] >> endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
trailer << /Size 4 /Root 1 0 R >>
startxref
187
%%EOF
```

If pdfium rejects the hand-built xref offsets, generate the fixture instead: `python3 -c "import subprocess"` is not available — use macOS's built-in: `cupsfilter -o media=A4 /etc/hosts > test/fixtures/sample.pdf 2>/dev/null` or export any one-page PDF; the test only needs a valid single-page document, its content is irrelevant.

- [ ] **Step 3: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';

void main() {
  test('renders first page of a pdf to a jpeg within maxDimension', () async {
    final bytes = await PdfPageRenderer.renderFirstPageJpeg(
      file: File('test/fixtures/sample.pdf'),
      maxDimension: 256,
    );
    expect(bytes, isNotNull);
    final decoded = img.decodeJpg(bytes!);
    expect(decoded, isNotNull);
    expect(
      decoded!.width <= 256 && decoded.height <= 256,
      isTrue,
      reason: 'longest edge must be capped',
    );
  });

  test('returns null for garbage bytes', () async {
    final bytes = await PdfPageRenderer.renderFirstPageJpeg(
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(bytes, isNull);
  });
}
```

NOTE: pdfrx needs its native pdfium binary; if `flutter test` cannot load it on the host (`Invalid argument(s): Failed to load dynamic library`), mark these two tests with `@TestOn('mac-os')` or skip with a comment referencing the CI platform, and rely on the garbage-bytes test plus manual smoke. Determine this empirically in Step 4 — do not preemptively skip.

- [ ] **Step 4: Implement**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Renders the first page of a PDF to JPEG bytes for thumbnails.
/// Every failure path returns null: thumbnail absence must never block
/// an upload or a grid render (same contract as ThumbnailGenerator).
class PdfPageRenderer {
  PdfPageRenderer._();

  static final _log = LoggerService.forClass(PdfPageRenderer);
  static bool _initialized = false;

  static Future<Uint8List?> renderFirstPageJpeg({
    File? file,
    Uint8List? bytes,
    int maxDimension = 512,
    int quality = 80,
  }) async {
    assert((file == null) != (bytes == null), 'pass exactly one source');
    PdfDocument? document;
    try {
      if (!_initialized) {
        await pdfrxInitialize();
        _initialized = true;
      }
      document = file != null
          ? await PdfDocument.openFile(file.path)
          : await PdfDocument.openData(bytes!);
      if (document.pages.isEmpty) return null;
      final page = document.pages[0];
      final scale = maxDimension / (page.width > page.height
          ? page.width
          : page.height);
      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
      );
      if (pageImage == null) return null;
      try {
        final image = pageImage.createImageNF();
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      } finally {
        pageImage.dispose();
      }
    } on Exception catch (e) {
      _log.warning('PDF page render failed: $e');
      return null;
    } finally {
      document?.close();
    }
  }
}
```

API check against the installed pdfrx version: `pdfrxInitialize()`, `PdfDocument.openFile/openData`, `page.render(width:, height:)`, `pageImage.createImageNF()`, `pageImage.dispose()`, `document.close()` — open the package source under `~/.pub-cache` (or its dartdoc) and match the real names/nullability before writing; the shapes above are from pdfrx's current README (which uses `close()` for documents and `dispose()` for page images).

- [ ] **Step 5: Run tests, format, commit**

Run: `flutter test test/features/media/data/services/pdf_page_renderer_test.dart`
Expected: PASS (or documented host-skip per Step 3 note).

```bash
dart format .
git add -A
git commit -m "Add pdfrx and first-page PDF thumbnail renderer"
```

### Task 12: Thumbnail pipeline and store content types for documents

**Files:**
- Modify: `lib/features/media_store/data/thumbnail_generator.dart`
- Modify: `lib/core/services/media_store/store_keys.dart`
- Test: extend `test/core/services/media_store/store_keys_test.dart` (find exact path with `ls`; create if absent) and the existing thumbnail generator test

**Interfaces:**
- Consumes: `PdfPageRenderer` (Task 11), `MediaItem.isPdf`/`isDocument` (Task 1).
- Produces: `ThumbnailGenerator.generateFor` returns a real page-1 thumb for PDFs and null for other documents; `StoreKeys.contentTypeFor('pdf') == 'application/pdf'` etc.

- [ ] **Step 1: Write the failing tests**

StoreKeys additions:

```dart
  test('document content types', () {
    expect(StoreKeys.contentTypeFor('pdf'), 'application/pdf');
    expect(StoreKeys.contentTypeFor('txt'), 'text/plain');
    expect(StoreKeys.contentTypeFor('gpx'), 'application/gpx+xml');
    expect(StoreKeys.contentTypeFor('doc'), 'application/msword');
    expect(
      StoreKeys.contentTypeFor('docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(StoreKeys.contentTypeFor('exe'), 'application/octet-stream');
  });
```

ThumbnailGenerator: in its existing test file, add a case that resolves a `MediaType.document` item with `originalFilename: 'sample.pdf'` whose resolver returns `FileData(File('test/fixtures/sample.pdf'))` (use the test's existing fake registry seam) and asserts a non-null staged JPEG; and a `notes.txt` document case asserting null.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/media_store/ test/features/media_store/data/thumbnail_generator_test.dart` (adjust paths to what `ls` shows)
Expected: FAIL.

- [ ] **Step 3: Implement**

`store_keys.dart` — add cases to `contentTypeFor` before `default`:

```dart
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'gpx':
        return 'application/gpx+xml';
```

`thumbnail_generator.dart` — inside `generateFor`, add a document gate before the existing `switch` on resolved data (after the resolver call, line ~40):

```dart
      if (item.isDocument) {
        if (!item.isPdf) return null; // opaque documents have no thumbnail
        return switch (data) {
          FileData(file: final f) => _stagePdfThumb(file: f),
          BytesData(bytes: final b) => _stagePdfThumb(bytes: b),
          NetworkData() || UnavailableData() => null,
        };
      }
```

and the helper beside `_resizeToJpeg`:

```dart
  Future<File?> _stagePdfThumb({File? file, Uint8List? bytes}) async {
    final jpeg = await PdfPageRenderer.renderFirstPageJpeg(
      file: file,
      bytes: bytes,
      maxDimension: maxDimension,
      quality: jpegQuality,
    );
    if (jpeg == null) return null;
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(jpeg, flush: true);
    return staged;
  }
```

(`resolveThumbnail` for a localFile document returns the original bytes/file — exactly what the PDF renderer needs; no resolver changes required.)

- [ ] **Step 4: Run tests, format, commit**

Run the two test files from Step 2. Expected: PASS.

```bash
dart format .
git add -A
git commit -m "Generate PDF thumbnails and document content types in media store"
```

### Task 13: Document viewer, open-externally, and tile rendering

**Files:**
- Create: `lib/features/media/presentation/pages/document_viewer_page.dart`
- Create: `lib/features/media/presentation/helpers/document_open_helper.dart`
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (wire the two null callbacks from Task 9)
- Test: `test/features/media/presentation/pages/document_viewer_page_test.dart` (create)

**Interfaces:**
- Consumes: pdfrx `PdfViewer.file` / `PdfViewer.data`, resolver registry, `writeShareTempFile`, `SharePlus`, `DocumentImportService` + `FilePicker` (attach flow), Task 8's callbacks.
- Produces:
  - `DocumentViewerPage({required MediaItem item})` — full-screen PDF viewer with share and open-externally actions; unavailable state when bytes cannot be resolved.
  - `DocumentOpenHelper.open(BuildContext context, WidgetRef ref, MediaItem item)` — PDFs push `DocumentViewerPage`; other documents resolve to a temp file and open externally (desktop `open`/`xdg-open`/`start`, mobile share sheet).
  - `DocumentOpenHelper.pickAndAttach({required BuildContext context, required WidgetRef ref, String? diveId, String? siteId})` — `FilePicker.pickFiles(type: FileType.custom, allowedExtensions: DocumentImportService.allowedExtensions, allowMultiple: true)` -> `documentImportServiceProvider.importDocuments(...)` -> invalidate the relevant providers -> snackbar.

- [ ] **Step 1: Implement `DocumentViewerPage`**

```dart
class DocumentViewerPage extends ConsumerStatefulWidget {
  final MediaItem item;
  const DocumentViewerPage({super.key, required this.item});
  ...
}
```

State resolves the item once in `initState` via the resolver registry (same memoized-future pattern as `MediaItemView._resolve`, including the media-store `tryResolveRemote` fallback — copy that block, minus the thumbnail branches). Build:

- `Scaffold` with an `AppBar` titled `widget.item.originalFilename ?? context.l10n.media_documentViewer_title`, actions: share (resolve -> `writeShareTempFile` -> `SharePlus`, copied from `trip_photo_viewer_page.dart:199-234`) and an overflow "open externally" invoking `DocumentOpenHelper.openExternally`.
- Body `FutureBuilder`: `FileData(file: f)` -> `PdfViewer.file(f.path)`; `BytesData(bytes: b)` -> `PdfViewer.data(b, sourceName: widget.item.id)`; `UnavailableData` / error -> centered column with `Icons.picture_as_pdf_outlined`, `context.l10n.media_documentViewer_unavailable`, and — when `widget.item.originDeviceId != null` — `context.l10n.media_documentViewer_availableOnOriginDevice`.
- A `PdfViewer` load error (corrupt file) must show the unavailable column with an open-externally button, not crash: wrap with the viewer's error callback if the installed pdfrx exposes one (check `PdfViewerParams` for an error builder), else guard with `FutureBuilder` on a pre-flight `PdfPageRenderer.renderFirstPageJpeg` null-check.

- [ ] **Step 2: Implement `DocumentOpenHelper`**

```dart
class DocumentOpenHelper {
  /// Route a tapped document: PDFs to the in-app viewer, everything else
  /// to the platform (desktop-save vs mobile-share duality).
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    if (item.isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => DocumentViewerPage(item: item),
        ),
      );
      return;
    }
    await openExternally(context, ref, item);
  }

  static Future<void> openExternally(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final resolved = await ref.read(
      resolvedFullResolutionProvider(item).future,
    );
    if (resolved.isUnavailable || resolved.bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.media_documentViewer_unavailable),
          ),
        );
      }
      return;
    }
    final file = await writeShareTempFile(item, resolved.bytes!);
    if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    } else {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: item.shareMimeType)]),
      );
    }
  }

  static Future<void> pickAndAttach({
    required BuildContext context,
    required WidgetRef ref,
    String? diveId,
    String? siteId,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentImportService.allowedExtensions,
      allowMultiple: true,
    );
    if (result == null || !context.mounted) return;
    final picked = [
      for (final f in result.files)
        if (f.path != null) (path: f.path!, filename: f.name),
    ];
    if (picked.isEmpty) return;
    final service = ref.read(documentImportServiceProvider);
    final created = await service.importDocuments(
      picked: picked,
      diveId: diveId,
      siteId: siteId,
    );
    if (siteId != null) {
      ref.invalidate(mediaForSiteProvider(siteId));
      ref.invalidate(mediaCountForSiteProvider(siteId));
    }
    if (diveId != null) {
      ref.invalidate(mediaForDiveProvider(diveId));
      ref.invalidate(mediaCountForDiveProvider(diveId));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.media_documentViewer_attached(created.length),
          ),
        ),
      );
    }
  }
}
```

- [ ] **Step 3: Document rendering in `MediaItemView`**

In `media_item_view.dart`'s result `switch` (line ~172), documents must not be fed to `Image.file`/`Image.memory`. Add BEFORE the video-poster case:

```dart
          FileData() when widget.item.isDocument =>
            _DocumentThumbnailPlaceholder(item: widget.item),
          BytesData() when widget.item.isDocument && !_isStoreThumb =>
            _DocumentThumbnailPlaceholder(item: widget.item),
```

Nuance: a PDF's media-store THUMB resolves to JPEG bytes/file that SHOULD render as an image. The store fallback path (`tryResolveRemote(thumbnail: true)`) is the only source of such bytes; track it with a boolean set where the remote resolution happens (`_isStoreThumb = true` alongside `remote != null` when `widget.thumbnail`), defaulting false. If threading the flag proves invasive, an acceptable simplification: always show `_DocumentThumbnailPlaceholder` for documents in this widget (local tiles), since store-thumb rendering only affects other-device tiles and the placeholder still communicates the document. Choose the simplification only if the flag genuinely tangles the resolve path — note which you chose in the commit message.

The placeholder (add at file bottom, matching `_VideoThumbnailPlaceholder`'s style):

```dart
class _DocumentThumbnailPlaceholder extends StatelessWidget {
  final MediaItem item;
  const _DocumentThumbnailPlaceholder({required this.item});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              color: scheme.onSurfaceVariant,
            ),
            if (item.originalFilename != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.originalFilename!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the site detail page**

Replace Task 9's two `null` callbacks in `site_detail_page.dart`:

```dart
            onAddDocumentPressed: () => DocumentOpenHelper.pickAndAttach(
              context: context,
              ref: ref,
              siteId: site.id,
            ),
            onOpenDocument: (item) =>
                DocumentOpenHelper.open(context, ref, item),
```

- [ ] **Step 5: l10n keys (English)**

Add to `app_en.arb` (and mirror to other locales as in Task 8 Step 4):

```json
  "media_documentViewer_title": "Document",
  "media_documentViewer_unavailable": "This document is not available on this device",
  "media_documentViewer_availableOnOriginDevice": "It is available on the device it was added from, or via a configured media store.",
  "media_documentViewer_attached": "Attached {count} documents",
  "@media_documentViewer_attached": {
    "placeholders": { "count": { "type": "int" } }
  },
  "media_documentViewer_openExternally": "Open in another app"
```

- [ ] **Step 6: Test and verify**

`test/features/media/presentation/pages/document_viewer_page_test.dart`: pump `DocumentViewerPage` with an item whose resolver override returns `UnavailableData` and assert the unavailable message renders (no pdfium needed for that path). Run:

`flutter test test/features/media/presentation/pages/document_viewer_page_test.dart test/features/media/presentation/widgets/media_item_view_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add PDF viewer, document open flows, and document tiles"
```

---

## Phase 6: Dive-side documents

### Task 14: Documents on dives

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: `lib/features/media/presentation/pages/photo_viewer_page.dart`
- Test: extend `test/features/media/presentation/widgets/dive_media_section_test.dart`

**Interfaces:**
- Consumes: `DocumentOpenHelper` (Task 13).
- Produces: `DiveMediaSection` gains `onAddDocumentPressed` (VoidCallback?) and `onOpenDocument` (void Function(MediaItem)?) parameters; dive photo viewer never receives documents.

- [ ] **Step 1: Write the failing test**

In `dive_media_section_test.dart` add:

```dart
  testWidgets('add menu shows document action when callback provided',
      (tester) async {
    var photos = 0;
    var docs = 0;
    // pumpSection = this file's existing harness function for DiveMediaSection
    await pumpSection(
      tester,
      onAddPressed: () => photos++,
      onAddDocumentPressed: () => docs++,
    );
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    expect(find.text('Add document'), findsOneWidget);
    await tester.tap(find.text('Add document'));
    await tester.pumpAndSettle();
    expect(docs, 1);
    expect(photos, 0);
  });

  testWidgets('plain add button preserved when no document callback',
      (tester) async {
    var photos = 0;
    await pumpSection(tester, onAddPressed: () => photos++);
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    expect(photos, 1); // fired directly, no menu
  });
```

(`pumpSection` stands for however the existing file pumps `DiveMediaSection` — extend that helper with the new optional callbacks rather than building a fresh harness.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/dive_media_section_test.dart`
Expected: new cases FAIL — parameter undefined.

- [ ] **Step 3: Implement the section changes**

1. Add the two parameters to `DiveMediaSection` (fields + constructor).
2. In the header (line ~368), replace the plain add `IconButton`:

```dart
                  if (widget.onAddPressed != null &&
                      widget.onAddDocumentPressed == null)
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onPressed: widget.onAddPressed,
                    )
                  else if (widget.onAddPressed != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onSelected: (value) {
                        if (value == 'photos') widget.onAddPressed!();
                        if (value == 'document') {
                          widget.onAddDocumentPressed!();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'photos',
                          child: Text(
                            context.l10n.media_siteMediaSection_addPhotos,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'document',
                          child: Text(
                            context.l10n.media_siteMediaSection_addDocument,
                          ),
                        ),
                      ],
                    ),
```

3. In `onItemTap` (line ~403), route documents:

```dart
                  onItemTap: (index) {
                    final item = media[index];
                    if (item.isDocument) {
                      widget.onOpenDocument?.call(item);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => PhotoViewerPage(
                          diveId: widget.diveId,
                          initialMediaId: item.id,
                        ),
                      ),
                    );
                  },
```

4. Enrichment backfill guard in `_scheduleEnrichmentBackfill` (line ~88): documents never enrich —

```dart
    final missing = items
        .where((m) => m.enrichment == null && !m.isDocument)
        .map((m) => m.id)
        .toSet();
```

- [ ] **Step 4: Wire the dive detail page**

In `dive_detail_page.dart` `_buildMediaSection` (line ~4526):

```dart
    return DiveMediaSection(
      diveId: dive.id,
      onScanPressed: () => _scanGalleryForDive(context, ref, dive),
      onAddPressed: () async {
        await PhotoImportHelper.importPhotosForDive(
          context: context,
          ref: ref,
          dive: dive,
        );
      },
      onAddDocumentPressed: () => DocumentOpenHelper.pickAndAttach(
        context: context,
        ref: ref,
        diveId: dive.id,
      ),
      onOpenDocument: (item) => DocumentOpenHelper.open(context, ref, item),
    );
```

- [ ] **Step 5: Exclude documents from the dive photo viewer**

Open `photo_viewer_page.dart` and find where it materializes the media list from `mediaForDiveProvider(diveId)` (mirror of the trip viewer's `flatMediaAsync.when(data: (mediaList) {...})`). Filter documents at that point:

```dart
          final mediaList =
              rawList.where((m) => !m.isDocument).toList();
```

(adapt the variable names to the file — the invariant is: every list the pager, page indicator, and initial-index lookup use must be the filtered one). Do the same in the gallery-scan suggestion path only if it iterates `mediaForDiveProvider` output (check; scan flows create photo suggestions and should be unaffected).

- [ ] **Step 6: Run tests, format, commit**

Run: `flutter test test/features/media/presentation/widgets/dive_media_section_test.dart test/features/media/presentation/widgets/dive_media_section_lightroom_test.dart test/features/media/presentation/pages/`
Expected: PASS.

```bash
dart format .
git add -A
git commit -m "Enable document attachments on dives"
```

---

## Phase 7: Localization and verification

### Task 15: Translate all new l10n keys

**Files:**
- Modify: all 11 of `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`

The keys added in Tasks 8, 13 (and any stragglers — diff `app_en.arb` against `origin/main` to enumerate):
`media_siteMediaSection_title`, `media_siteMediaSection_addPhotos`, `media_siteMediaSection_addDocument`, `media_siteMediaSection_emptyState`, `media_siteMediaSection_divePhotosGroup`, `media_siteMediaSection_divePhotoLabel`, `media_siteMediaSection_unlinkSelectedTitle`, `media_siteMediaSection_unlinkSelectedContent`, `media_siteMediaSection_unlinkSelectedSuccess`, `media_documentViewer_title`, `media_documentViewer_unavailable`, `media_documentViewer_availableOnOriginDevice`, `media_documentViewer_attached`, `media_documentViewer_openExternally`.

- [ ] **Step 1: Translate**

For each non-English ARB, replace the temporary English copies with real translations of the English source strings. Match each locale's existing tone and terminology — open the neighboring `media_diveMediaSection_*` translations in the same file and reuse their vocabulary (e.g. how "unlink"/"attach" is already rendered in that language). Preserve placeholder syntax exactly (`{count}`).

- [ ] **Step 2: Regenerate and verify**

```bash
flutter gen-l10n
flutter analyze
```

Expected: analyze clean (missing-translation infos are fatal).

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A
git commit -m "Translate site media and document viewer strings for all locales"
```

### Task 16: Roadmap note and full verification

**Files:**
- Modify: `docs/FEATURE_ROADMAP.md` (line ~1230: mark "User-submitted site photos" as shipped/in-PR with a pointer to issues #211/#627)
- Modify: `docs/contributing/roadmap.md` (line ~239 "Site photo galleries" — same)

- [ ] **Step 1: Update the two roadmap lines**

Follow the exact status vocabulary neighboring rows use (e.g. change `📋 Planned` to the symbol used for completed items in that table — copy from an adjacent shipped row; do not invent emoji, reuse the table's own).

- [ ] **Step 2: Full verification (evidence before assertions)**

```bash
dart format .          # must be a no-op
flutter analyze        # zero issues
flutter test           # full suite
```

Known-flaky context: backup tests, media upload pipeline drain, OCR scan-page-under-load, media store fallback walltime, and recovery-code yoyo tests are documented flaky under full-suite load in this project — a failure in one of those, passing in isolation, is pre-existing; anything touching media/site/document code paths is NOT excusable and must be fixed.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "Update roadmap for site media attachments"
```

Do NOT push or open a PR — the branch owner decides integration (superpowers:finishing-a-development-branch).

---

## Spec coverage map

| Spec requirement | Task(s) |
| --- | --- |
| `MediaType.document`, extension-based behavior | 1 |
| Site read path + providers | 2, 5 |
| Migration v148 (site index, dedupe index) | 3 |
| HLC-stamped site-deletion cascade | 4 |
| Shared grid extraction (Approach B) | 6 |
| Site viewer (trip-viewer model, no dive overlay) | 7 |
| SiteMediaSection: attachments + separated dive photos | 8 |
| Site photo add flow (no time window) | 9 |
| Reference-everything document linking (bookmark/SAF/path) | 10 |
| PDF page-1 thumbnails (pdfrx), 512px JPEG | 11, 12 |
| Store content types for documents | 12 |
| In-app PDF viewer + unavailable/origin-device state | 13 |
| Non-PDF opaque tiles + open externally | 6 (badge), 13 |
| Documents on dives, enrichment skipped | 14 |
| l10n all locales | 8, 13, 15 |
| Media-store sync contract (no inline blobs) | inherent — no new sync code anywhere |

Deliberate deviation from the spec: content hashes are NOT computed at attach time — the upload pipeline computes and records them exactly as it does for photos today (`recordContentHash`). The spec's "hash at attach" wording predates checking how photos actually behave; consistency wins and nothing downstream needs the hash earlier.
