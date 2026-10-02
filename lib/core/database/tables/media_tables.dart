/// Media, enrichment, albums, subscriptions and media stores.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/marine_life_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';

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
  TextColumn get filePath => text()();
  TextColumn get fileType => text().withDefault(
    const Constant('photo'),
  )(); // photo, video, instructor_signature
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get takenAt => integer().nullable()();
  TextColumn get caption => text().nullable()();
  // Signature fields (v1.5) - used when fileType='instructor_signature'
  TextColumn get signerId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get signerName => text().nullable()();
  // Signature type (v22) - distinguishes instructor vs buddy signatures
  TextColumn get signatureType => text().nullable()(); // 'instructor' | 'buddy'
  // Signature image data (v23) - stores signature as BLOB instead of file
  BlobColumn get imageData => blob().nullable()();
  // Gallery photo fields (v2.0) - for underwater photography feature
  TextColumn get platformAssetId =>
      text().nullable()(); // Platform-specific asset ID for gallery photos
  TextColumn get originalFilename => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()(); // For videos
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get thumbnailGeneratedAt => integer().nullable()();
  IntColumn get lastVerifiedAt => integer().nullable()();
  BoolColumn get isOrphaned => boolean().withDefault(const Constant(false))();
  // Source-type extension (v72)
  // Drift's build_runner replaces these getters with `GeneratedColumn`
  // declarations on the `$MediaTable` subclass, so the bodies below never
  // execute at runtime — they're DSL the schema generator reads as AST.
  // coverage:ignore-start
  TextColumn get sourceType =>
      text().withDefault(const Constant('platformGallery'))();
  TextColumn get localPath => text().nullable()();
  TextColumn get bookmarkRef => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get subscriptionId => text().nullable()();
  TextColumn get entryKey => text().nullable()();
  TextColumn get connectorAccountId => text().nullable()();
  TextColumn get remoteAssetId => text().nullable()();
  TextColumn get originDeviceId => text().nullable()();
  // v226: PhotoKit's cloud identifier for a gallery link (media sync
  // program spec 6.2), which names the same photo on every device sharing
  // an iCloud Photos library. Null when unknown; empty when a relink found
  // none, since a null never clears a peer's copy (nullToAbsent).
  TextColumn get cloudAssetId => text().nullable()();
  // Media store (v103) - content identity + upload confirmation stamps.
  // Nullable adds; a row with remote_uploaded_at set has its original bytes
  // confirmed present in the library's media store at the content-hash key.
  TextColumn get contentHash => text().nullable()();
  IntColumn get contentSizeBytes => integer().nullable()();
  IntColumn get remoteUploadedAt => integer().nullable()();
  IntColumn get remoteThumbUploadedAt => integer().nullable()();

  // Adjustable upload quality (v133): a compressed rendition, keyed by the
  // original's content hash, may be uploaded instead of the original.
  TextColumn get compressedLevel => text().nullable()();
  IntColumn get compressedSizeBytes => integer().nullable()();
  IntColumn get remoteCompressedUploadedAt => integer().nullable()();
  // Media section Phase 1 (v140): kept-in-library marker. Dormant until the
  // Phase 2 link-management UI sets it; the orphan sweep will exclude rows
  // where it is true. Synced with the row like every other media column.
  BoolColumn get retainInLibrary =>
      boolean().withDefault(const Constant(false))();
  // v164: the moment in the dive the diver pinned this item to, in seconds
  // from the dive start (issue #1090). Null means the position derives from
  // taken_at. Lives on the media row, not on media_enrichment, so it syncs
  // with the row and survives every enrichment recompute.
  IntColumn get manualElapsedSeconds => integer().nullable()();
  // v189: equipment attachment (issue #1517). Invoices, receipts and warranty
  // paperwork linked to a piece of gear, so an insurance claim after lost
  // luggage, theft or fire has the proof attached to the item it covers.
  // Same SET NULL semantics as [siteId]: the repository's deletion partition
  // decides whether a leftover row dies or survives, and it stamps the HLC a
  // silent FK never would.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // coverage:ignore-end
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  /// Clock of the upload facts (content identity, the three upload stamps
  /// and the compressed rendition's level and size). Every upload-fact write
  /// stamps this instead of [hlc], so a stamp never makes a stale caption win
  /// the row, and a cleared stamp still orders against a set one. Null falls
  /// back to [hlc] (v224, media sync program spec 5.1).
  TextColumn get uploadFactsHlc => text().nullable()();

  /// Clock of the verification facts (isOrphaned, lastVerifiedAt). Same
  /// contract as [uploadFactsHlc].
  TextColumn get verifyFactsHlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

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
  TextColumn get matchConfidence => text().withDefault(
    const Constant('exact'),
  )(); // exact, interpolated, estimated, no_profile
  IntColumn get timestampOffsetSeconds => integer().nullable()();
  IntColumn get createdAt => integer()();
  // v130: sync replication. media_enrichment is the depth/time association for
  // a linked photo; without an hlc it never travelled through sync and was
  // lost on other devices / after restore.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Species tags on media (many-to-many with optional spatial annotation)
class MediaSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get sightingId => text().nullable().references(
    Sightings,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Reserved for future spatial annotation (nullable for now)
  RealColumn get bboxX => real().nullable()();
  RealColumn get bboxY => real().nullable()();
  RealColumn get bboxWidth => real().nullable()();
  RealColumn get bboxHeight => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Hybrid Logical Clock, added in v195 (issue #1638). The row is
  /// write-once, so the clock is not here to resolve conflicts: it is what
  /// makes the tag visible to the incremental export, which ships rows whose
  /// `hlc` is above the peer watermark. Before v195 this table rode the
  /// parent `media.hlc`, and since tagging a photo never edits the photo,
  /// a tag reached peers only on a full base publish. Nullable: rows written
  /// before v195 are stamped by `SyncRepository.backfillMissingHlc`.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Repair history (Media section Phase 5, v143).
///
/// Deliberately NOT synced and NOT registered in [SyncRepository]: every
/// row records a device-specific path change, so replaying one device's
/// history onto another would describe files that never existed there.
/// Same per-device reasoning as [PendingPhotoSuggestions]. Pruned to the
/// newest 500 rows by MediaRepairLogRepository.
class MediaRepairLog extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId => text()();

  /// Groups every row written by one apply pass.
  TextColumn get batchId => text()();
  IntColumn get occurredAt => integer()();

  /// A `RepairLogAction.name`: relink | cloudBacked | autoRelink.
  TextColumn get action => text()();

  /// The pointer before and after the repair (path, asset id, or null for
  /// a cloud-backed conversion's new value).
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();

  /// A `RepairLogSource.name`: folder | photoLibrary | store | watcher |
  /// manual.
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A named saved library filter (Media section Phase 5, v143).
///
/// Synced like any other user data: the filter is expressed in ids and
/// enum names that mean the same thing on every device.
class MediaSmartAlbums extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// A serialized `MediaLibraryFilter`.
  TextColumn get filterJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending photo suggestions for background scan feature.
///
/// v106: connector suggestions (Lightroom) reuse this table. For those
/// rows `connectorAccountId`/`remoteAssetId` are set and the remote asset
/// id is mirrored into the NOT NULL `platformAssetId` key column.
class PendingPhotoSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get platformAssetId => text()();
  IntColumn get takenAt => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  TextColumn get connectorAccountId => text().nullable()();
  TextColumn get remoteAssetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Manifest-feed subscriptions (Atom/RSS, JSON, CSV) for periodic polling.
/// Synced across devices.
class MediaSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get manifestUrl => text()();
  TextColumn get format => text()();
  TextColumn get displayName => text().nullable()();
  IntColumn get pollIntervalSeconds =>
      integer().withDefault(const Constant(86400))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get credentialsHostId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution (v108;
  /// nullable: rows written before the rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-device polling state for each subscription. Not synced.
class MediaSubscriptionState extends Table {
  TextColumn get subscriptionId =>
      text().references(MediaSubscriptions, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastPolledAt => integer().nullable()();
  IntColumn get nextPollAt => integer().nullable()();
  TextColumn get lastEtag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get lastErrorAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {subscriptionId};
}

/// Per-host credentials for ad-hoc HTTP(S) media URLs. Not synced.
class NetworkCredentialHosts extends Table {
  TextColumn get id => text()();
  TextColumn get hostname => text()();
  TextColumn get authType => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get credentialsRef => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastUsedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Match the v72 migration's `hostname TEXT NOT NULL UNIQUE` so fresh
  // installs (created from the Drift schema) reject duplicate hostnames the
  // same way upgraded DBs do.
  @override
  List<Set<Column>> get uniqueKeys => [
    {hostname},
  ];
}

/// Per-device fetch error diagnostics for media items. Not synced.
class MediaFetchDiagnostics extends Table {
  TextColumn get mediaItemId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastErrorAt => integer().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaItemId};
}

/// The library's media store descriptor (secret-free). Synced so other
/// devices learn a store exists and can prompt to connect. Exactly one
/// active row is expected; credentials never live here (keychain only).
class MediaStores extends Table {
  TextColumn get id => text()(); // storeId UUID, matches smv1/store.json
  TextColumn get providerType => text()(); // 's3' (Phase 4 adds others)
  TextColumn get displayHint => text()(); // e.g. 'dive-media @ minio.host'
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();
  // v136: epoch millis of the last completed Verify Library sweep on ANY
  // device (fleet-wide cadence; orphan-prevention spec 6.4).
  IntColumn get lastSweepAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Linked credentialed endpoints (secret-free). Synced roster: other
/// devices see which accounts exist and prompt for sign-in (program spec
/// section 5). Credentials live in the keychain under
/// `account_<id>_credentials`, never here.
class ConnectedAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // AccountKind.name
  TextColumn get label => text()();
  TextColumn get accountIdentifier => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
