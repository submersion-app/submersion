/// Dive computers, data sources, imported files and profile series.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/raw_dive_data_codec.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Dive computers (devices that record dive data)
class DiveComputers extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()(); // User-friendly name e.g., "My Perdix"
  TextColumn get manufacturer => text().nullable()(); // e.g., "Shearwater"
  TextColumn get model => text().nullable()(); // e.g., "Perdix AI"
  TextColumn get serialNumber => text().nullable()();
  TextColumn get firmwareVersion => text().nullable()();
  TextColumn get connectionType =>
      text().nullable()(); // "bluetooth", "usb", "ble"
  /// Device-local BLE/MAC identifier. This must not be synchronized because
  /// CoreBluetooth identifiers can differ between hosts for the same hardware.
  TextColumn get bluetoothAddress => text().nullable()();
  TextColumn get lastDiveFingerprint => text().nullable()();
  IntColumn get lastDownloadTimestamp =>
      integer().nullable()(); // Unix timestamp
  IntColumn get diveCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  /// The equipment row representing this device as gear, its "gear twin"
  /// (v175). Seeded once at registration, then owned by the user: renaming or
  /// retiring the gear item never writes back here, and renaming the computer
  /// never overwrites the gear name.
  ///
  /// Unlike [bluetoothAddress] this DOES synchronize, because equipment ids are
  /// fleet-stable and a peer holding a null here would dangle the reference.
  ///
  /// setNull rather than cascade: deleting the gear item leaves the device
  /// registered. The cleared column is also what makes that deletion permanent,
  /// because only a genuine computer insert ever mints a twin.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-source metadata snapshots for multi-source dives.
/// Only populated when a dive has data from multiple sources.
@DataClassName('DiveDataSourcesData')
class DiveDataSources extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get computerModel => text().nullable()();
  TextColumn get computerSerial => text().nullable()();
  TextColumn get sourceFormat => text().nullable()();
  TextColumn get sourceFileName => text().nullable()();
  TextColumn get sourceFileFormat => text().nullable()();

  /// The [ImportedFiles] row holding the original logbook file this source
  /// was parsed out of, so a later parser fix can be replayed onto the dive
  /// (issue #478). Null on every source that did not come from a file import.
  ///
  /// Deliberately not a declared foreign key. The row it names is reclaimed
  /// by refcount rather than by a cascade, and the sync apply runs with
  /// `defer_foreign_keys = ON` and a per-entity watermark, so a changeset can
  /// legitimately carry a source row whose file row travelled in an earlier
  /// one -- which a real constraint would reject at COMMIT, taking the whole
  /// changeset with it.
  TextColumn get importedFileId => text().nullable()();

  /// The diver a multi-diver logbook attributed this source's dive to
  /// (`SourceDiver.key`, as the file itself emits it), so a resync replays
  /// that diver's copy of a shared buddy dive and never another diver's
  /// (issue #1921). Null for every format without diver attribution and for
  /// every source imported before v233.
  TextColumn get sourceDiverKey => text().nullable()();
  RealColumn get maxDepth => real().nullable()();
  RealColumn get avgDepth => real().nullable()();
  IntColumn get duration => integer().nullable()();
  RealColumn get waterTemp => real().nullable()();
  RealColumn get entryLatitude => real().nullable()();
  RealColumn get entryLongitude => real().nullable()();
  RealColumn get exitLatitude => real().nullable()();
  RealColumn get exitLongitude => real().nullable()();
  DateTimeColumn get entryTime => dateTime().nullable()();
  DateTimeColumn get exitTime => dateTime().nullable()();
  RealColumn get maxAscentRate => real().nullable()();
  RealColumn get maxDescentRate => real().nullable()();
  IntColumn get surfaceInterval => integer().nullable()();
  RealColumn get cns => real().nullable()();
  RealColumn get otu => real().nullable()();
  TextColumn get decoAlgorithm => text().nullable()();
  IntColumn get gradientFactorLow => integer().nullable()();
  IntColumn get gradientFactorHigh => integer().nullable()();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  /// The raw bytes libdivecomputer returned for this download, zlib-compressed
  /// at rest behind a self-describing header (issue #227). The converter runs
  /// on every read and write, so callers see the original bytes and the sync
  /// layer keeps exchanging them uncompressed. See [RawDiveDataConverter].
  BlobColumn get rawData =>
      blob().map(const RawDiveDataConverter()).nullable()();
  BlobColumn get rawFingerprint => blob().nullable()();
  TextColumn get sourceUuid => text().nullable()();
  TextColumn get descriptorVendor => text().nullable()();
  TextColumn get descriptorProduct => text().nullable()();
  IntColumn get descriptorModel => integer().nullable()();
  TextColumn get libdivecomputerVersion => text().nullable()();
  DateTimeColumn get lastParsedAt => dateTime().nullable()();

  /// Seconds added to this source's own sample times to place them on the
  /// dive's timeline (issue #1177). Multi-computer consolidation re-bases a
  /// folded-in computer's profile so both strands share one clock; the shift
  /// it applied is recorded here because it cannot be recovered from the raw
  /// bytes. Re-parsing this source must add it back, or the strand slides
  /// away from the primary's. Null and 0 both mean "already on the dive's
  /// time base", which is every source that was never consolidated.
  IntColumn get timeOffsetSeconds => integer().nullable()();

  /// This row's position among its own original dive's data sources at the
  /// moment a sequential Combine carried it here (issue #1451). Null on every
  /// row a merge never carried, which is every row on an ordinary dive.
  ///
  /// `DiveMergeService.apply` copies each combined segment's
  /// `dive_data_sources` rows onto the merged dive as provenance, because
  /// each is the sole surviving copy of its half's rawData / rawFingerprint /
  /// sourceUuid. Two halves of one physical dive therefore arrive as two
  /// rows, and the display used to offer them as two switchable sources: the
  /// chart then drew only the active half. The rows are the same strand seen
  /// in two consecutive slices, not two competing recordings, so
  /// `_canonicalDataSourceRows` collapses rows sharing a slot into one
  /// display source. The rows themselves stay in the table untouched.
  ///
  /// A slot rather than a plain flag so a dive that was consolidated (two
  /// computers, slots 0 and 1 in each segment) and only then combined still
  /// shows one chip per computer instead of flattening both strands into one.
  /// Segments whose sources carry no computerId have nothing else to
  /// distinguish their strands by, which is exactly the case that was broken.
  IntColumn get mergeSourceSlot => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// The original logbook file a file import was parsed out of, kept so a later
/// parser fix can be replayed onto dives that were already imported (issue
/// #478).
///
/// One row per file, identified by the sha256 of its bytes, so a multi-dive
/// logbook is stored once however many dives came out of it and re-importing
/// the same file reuses the row it already has. Reclaimed by refcount:
/// `ImportedFileReclaimer` drops a row the moment no `dive_data_sources` row
/// names it any more.
///
/// A synced entity with its own `hlc`, so the files a diver has imported are
/// covered by backups and reach their other devices. Immutable once written
/// -- the id IS the content -- which is why it merges by blind upsert rather
/// than by conflict detection.
class ImportedFiles extends Table {
  /// Lowercase hex sha256 of [bytes] as the original file had them.
  TextColumn get id => text()();

  /// The file exactly as it was imported, zlib-compressed at rest behind the
  /// self-describing header the raw-download column uses (issue #227). The
  /// converter runs on every read and write, so callers and the sync layer
  /// both see the original bytes. See [RawDiveDataConverter].
  BlobColumn get bytes => blob().map(const RawDiveDataConverter())();

  /// The basename the file was imported under, which is all that is needed to
  /// hand the bytes back as a file again (the extension comes with it). Kept
  /// nullable because a picked file can arrive without a usable name.
  TextColumn get fileName => text().nullable()();

  /// Length of the original bytes, so size can be read without inflating the
  /// blob.
  IntColumn get byteCount => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Profile events (markers on dive profile)
class DiveProfileEvents extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()(); // seconds from dive start
  TextColumn get eventType => text()(); // See ProfileEventType enum
  TextColumn get severity =>
      text().withDefault(const Constant('info'))(); // info, warning, alert
  TextColumn get description => text().nullable()();
  RealColumn get depth => real().nullable()(); // depth at event (meters)
  RealColumn get value =>
      real().nullable()(); // event-specific value (e.g., ascent rate)
  TextColumn get tankId => text().nullable()(); // for gas switch events
  TextColumn get source =>
      text().withDefault(const Constant('imported'))(); // EventSource.name
  // Which computer contributed this event (null = primary source / manual).
  // Same null-means-primary semantics as dive_profiles.computerId; deletes
  // set null.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// v202: what only a profile-blob decode can produce, computed once per dive
/// version by the sensor summary service (phase 2). Device-local, never
/// synced; a restore rebuilds it by sweep.
@DataClassName('DiveSensorSummaryRow')
class DiveSensorSummaries extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get sourceUpdatedAt => integer()();
  IntColumn get computedAt => integer()();
  RealColumn get minTemperature => real().nullable()();
  RealColumn get maxDepth => real().nullable()();
  RealColumn get scrubberConsumedMinutes => real().nullable()();
  TextColumn get cellMetrics => text().withDefault(const Constant('[]'))();
  TextColumn get transmitterGaps => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// One packed series of profile samples: every sample a
/// (dive, computer, source, is_primary) group holds, encoded by
/// `ProfileSeriesCodec` (spec 2026-08-28-profile-sample-storage). Replaced
/// row-per-sample `dive_profiles`, which v183 dropped.
///
/// The identity columns mirror the ones `dive_profiles` carried, so every
/// ownership predicate ported one for one. The summary scalars are the values the SQL
/// consumers read instead of decoding the blob; they are computed from the
/// same samples the blob packs, so they can never disagree with it.
@DataClassName('DiveProfileSeriesRow')
class DiveProfileSeries extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get sourceId => text().nullable().references(
    DiveDataSources,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();
  IntColumn get sampleCount => integer()();

  /// Seconds from dive start of the first and last sample.
  IntColumn get startTimestamp => integer()();
  IntColumn get endTimestamp => integer()();

  /// Metres.
  RealColumn get maxDepth => real()();
  RealColumn get firstDepth => real()();
  RealColumn get lastDepth => real()();

  /// Any sample carries deco_type; any carries deco_type = 2; any carries
  /// ceiling > 0. The deco classification and deco-signal predicates read
  /// these instead of scanning samples.
  BoolColumn get hasDecoType => boolean().withDefault(const Constant(false))();
  BoolColumn get hasDecoStop => boolean().withDefault(const Constant(false))();
  BoolColumn get hasPositiveCeiling =>
      boolean().withDefault(const Constant(false))();
  IntColumn get codecVersion => integer()();

  /// `ProfileSeriesCodec` output.
  BlobColumn get samples => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// One packed series of tank pressure readings for a (dive, tank, computer)
/// group, encoded by `TankPressureSeriesCodec`. Replaced row-per-sample
/// `tank_pressure_profiles`, which v183 dropped.
///
/// Not the domain entity of the same name
/// (lib/features/dive_log/domain/entities/profile_series.dart); consumers
/// import that one as domain.
@DataClassName('TankPressureSeriesRow')
class TankPressureSeries extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tankId =>
      text().references(DiveTanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get sampleCount => integer()();
  IntColumn get startTimestamp => integer()();
  IntColumn get endTimestamp => integer()();
  IntColumn get codecVersion => integer()();
  BlobColumn get samples => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}
