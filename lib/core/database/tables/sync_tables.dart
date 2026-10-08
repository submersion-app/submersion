/// Sync bookkeeping.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// Global sync metadata - tracks sync state for this device
class SyncMetadata extends Table {
  TextColumn get id => text()(); // Always 'global' for single record
  IntColumn get lastSyncTimestamp =>
      integer().nullable()(); // Unix timestamp ms of last successful sync
  TextColumn get deviceId => text()(); // This device's unique UUID
  TextColumn get syncProvider =>
      text().nullable()(); // 'icloud', 'googledrive', or 's3'

  /// The connected account driving sync, or null pre-account-migration.
  /// syncProvider stays populated (kind name) for backward compatibility.
  TextColumn get syncAccountId => text().nullable()();
  TextColumn get remoteFileId =>
      text().nullable()(); // Provider-specific file reference
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(1))(); // Sync format version
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// Opaque per-database token, rotated on each launch and mirrored outside the
  /// database. A mismatch between this and the mirrored copy means the on-disk
  /// database was replaced (restore/overwrite), even when the device id is
  /// unchanged. Nullable: rows predating this column read as "no token yet".
  TextColumn get instanceToken => text().nullable()();

  /// The library epoch this device last accepted (see library_epoch.dart).
  /// Dual-anchored: mirrored in SharedPreferences so a database restore
  /// cannot silently rewind it. Null means the pre-epoch world.
  TextColumn get lastAcceptedEpochId => text().nullable()();

  /// The provider [lastSyncTimestamp] was minted against. A cursor read for a
  /// different provider returns null, so first contact with a newly switched
  /// backend is detectable. Null means a legacy cursor (pre-stamp rows),
  /// valid for any provider. Written only together with the cursor.
  TextColumn get lastSyncProvider => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-record sync tracking for conflict detection
class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // e.g., 'dives', 'dive_sites'
  TextColumn get recordId => text()(); // Primary key of the synced record
  IntColumn get localUpdatedAt => integer()(); // Local modification timestamp
  IntColumn get syncedAt => integer().nullable()(); // When last synced to cloud
  TextColumn get syncStatus => text().withDefault(
    const Constant('synced'),
  )(); // synced, pending, conflict
  TextColumn get conflictData =>
      text().nullable()(); // JSON of conflicting remote data
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Deletion log for tracking deleted records during sync
class DeletionLog extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // Which table the record was in
  TextColumn get recordId => text()(); // Primary key of deleted record
  IntColumn get deletedAt => integer()(); // Unix timestamp of deletion
  // Monotonic HLC stamped at deletion time (local filter metadata only, not on
  // the wire). Lets an incremental changeset carry only tombstones newer than
  // the published watermark instead of re-sending the whole log every sync.
  // Nullable as a safety net: the v86 migration backfills pre-existing rows to a
  // minimal sentinel, so null only arises for a delete logged before the sync
  // clock was configured; such a tombstone is always included in a base.
  TextColumn get hlc => text().nullable()();
  // The clock of the delete itself, as the deleting device stamped it, and
  // what the wire carries (v210). [hlc] above is re-issued by every device
  // that logs a peer's tombstone, so it says when this device heard of the
  // delete, which is too late to judge a child edit made in between. Null
  // for a tombstone logged before v210, or relayed from a peer that sent
  // none: such a tombstone is judged by the older rules.
  TextColumn get originHlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-peer download cursor: how far this device has consumed each peer's
/// changeset log. Scoped per provider so a backend switch starts fresh
/// (mirrors the v81 per-provider cursor lesson).
@DataClassName('SyncPeerCursor')
class SyncPeerCursors extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get provider => text()();
  IntColumn get baseSeqApplied => integer().nullable()();
  IntColumn get lastSeqApplied => integer().withDefault(const Constant(0))();

  // Highest HLC applied FROM this peer's log -- published in our manifest's
  // appliedPeerHlc map so the peer can garbage-collect tombstones we have
  // provably seen (fleet-acked horizon).
  TextColumn get appliedHlcHigh => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {peerDeviceId, provider};
}

/// This device's own published position in its changeset log, per provider.
/// Splits the old conflated lastSyncTimestamp: this is the upload side
/// (per-peer cursors are the download side).
@DataClassName('LocalPublishState')
class LocalPublishStates extends Table {
  TextColumn get provider => text()();
  IntColumn get baseSeq => integer().nullable()();
  IntColumn get basePartCount => integer().nullable()();
  IntColumn get baseBytes => integer().nullable()();
  IntColumn get headSeq => integer().withDefault(const Constant(0))();
  TextColumn get publishedHlcHigh => text().nullable()();
  IntColumn get changesetBytesSinceBase =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider};
}
