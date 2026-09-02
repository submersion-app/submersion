import 'package:drift/drift.dart';
import 'package:submersion/core/database/legacy_tank_orphan_adoption.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';
import 'package:submersion/core/database/profile_series_pack_rows.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

/// What one packing pass inserted, dropped, and skipped.
typedef ProfilePackReport = ({
  int profileSeries,
  int tankSeries,
  int droppedSamples,
  int skippedOrphans,

  /// Legacy rows without a READABLE timestamp or depth (pressure, tank id
  /// for tanks), stepped over.
  ///
  /// Readable, not merely present: a hand-repaired or bit-rotted file can
  /// hold text in a REAL column, and such a row holds no sample for the
  /// same reason a null one does not.
  int skippedRows,

  /// Dives the packer could not read or encode, counted once per dive per
  /// legacy table and stepped over.
  ///
  /// What lands here is a whole GROUP the codec refuses to encode, not one
  /// bad value: an unreadable column is [skippedRows] and costs its own row.
  /// Isolating the rest per dive is what keeps one such group from costing
  /// every dive the scan had not reached yet, which after v183 (when
  /// nothing reads the legacy tables any more) would be a silent, permanent
  /// loss rather than a deferred retry.
  int failedDives,

  /// Dives whose legacy (or staged) rows were discarded because the dive
  /// already had a series row, counted once per dive per legacy table.
  ///
  /// Expected and harmless on the migration path: a retried ladder, or the
  /// beforeOpen backstop after the rung already packed, sees every dive this
  /// way. On the receive-side staging path it is the count that says an
  /// older peer's row-per-sample copy of a dive lost to the series this
  /// device already holds, which is the intended precedence but worth being
  /// able to see in the sync log.
  int skippedAlreadyPacked,
});

/// Packs every legacy `dive_profiles` and `tank_pressure_profiles` row into
/// the series tables (v182, spec 2026-08-28-profile-sample-storage).
///
/// Raw SQL throughout, never the legacy Drift classes: plan 2e removed those
/// classes and dropped the tables, and this function has to keep compiling
/// and keep no-oping on a database that has already lost them.
///
/// Memory is bounded by one dive's rows, never the table. Each identity group
/// becomes one row whose id is derived from the tuple
/// ([profileSeriesMigratedId]), so a second run, a retry after a failed
/// ladder, or a second device migrating the same synced rows all converge on
/// the same id: the insert is `INSERT OR IGNORE`.
///
/// Only dives with legacy rows and no series row are visited, which is what
/// lets the beforeOpen backstop call this on every open. Exact duplicate
/// samples (a repeated import) are dropped before packing, which is what
/// every read did on the way out until now.
///
/// Orphans are skipped and counted in [ProfilePackReport.skippedOrphans]: a
/// legacy row whose dive (or, for a pressure row, whose tank) is already
/// gone could never have been rendered, and under `PRAGMA foreign_keys = ON`
/// inserting it would abort the whole ladder on every retry. A dangling
/// `computer_id` or `source_id` is weaker: the samples are still the dive's,
/// so the group packs with that member resolved to null, and the derived id
/// uses the resolved value so every device agrees.
///
/// Both legacy tables are read through `PRAGMA table_info`: a database from
/// a very old backup can lack the identity columns entirely. A missing
/// `computer_id`/`source_id` reads as null, a missing `is_primary` as true,
/// and a table without `dive_id`, `timestamp`, or `depth` (`pressure` for
/// tanks) holds nothing packable and is skipped whole.
///
/// [nowMs] stamps `created_at` and `updated_at`; `hlc` advances the clock
/// persisted in `sync_metadata` so the first sync after the upgrade
/// publishes the rows. A device that never synced has nothing to publish to
/// and stays unstamped until a base publish, which exports everything.
///
/// [profileTable] / [tankTable] default to the legacy table names the v182
/// migration and the beforeOpen backstop read. `legacy_sample_staging.dart`
/// passes its own TEMP staging table names instead, so this same function
/// packs an older peer's inbound row-per-sample rows once the real
/// `dive_profiles` / `tank_pressure_profiles` tables are gone (v183).
///
/// A dive whose legacy rows are ALL malformed (no readable timestamp or
/// depth) gets
/// no series row and is rescanned on every open; that is a bounded per-open
/// cost on a damaged database, not a retry bug.
Future<ProfilePackReport> packLegacyProfileRows(
  DatabaseConnectionUser db, {
  int? nowMs,
  String profileTable = 'dive_profiles',
  String tankTable = 'tank_pressure_profiles',
  bool byGroupIdentity = false,
}) async {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final profileColumns = await legacyColumnNames(db, profileTable);
  final canPackProfiles = profileColumns.containsAll(const {
    'dive_id',
    'timestamp',
    'depth',
  });
  final tankColumns = await legacyColumnNames(db, tankTable);
  final canPackTanks = tankColumns.containsAll(const {
    'dive_id',
    'tank_id',
    'timestamp',
    'pressure',
  });
  final profileScan = canPackProfiles
      ? await _scanLegacyDives(
          db,
          legacyTable: profileTable,
          seriesTable: 'dive_profile_series',
          byTank: false,
          byGroupIdentity: byGroupIdentity,
        )
      : _emptyScan;
  // Migration path only. The pairing rule assumes it can see the dive's
  // COMPLETE pressure history, which is true of this device's own legacy
  // table and false of the receive shim's staging: a peer's payload can
  // carry a subset, so the same orphan would pair with a different cylinder
  // depending on where the payload boundaries fell, and a wrong-cylinder
  // attribution is worse than a row that stays staged. A staged orphan is
  // kept, not deleted, and the migration's own adoption still heals this
  // device's rows.
  if (canPackTanks && !byGroupIdentity) {
    await adoptStrandedTankPressures(db, tankTable);
  }
  final tankScan = canPackTanks
      ? await _scanLegacyDives(
          db,
          legacyTable: tankTable,
          seriesTable: 'tank_pressure_series',
          byTank: true,
          byGroupIdentity: byGroupIdentity,
        )
      : _emptyScan;
  final unpackedProfileDives = profileScan.unpacked;
  final unpackedTankDives = tankScan.unpacked;
  final alreadyPacked = profileScan.alreadyPacked + tankScan.alreadyPacked;
  if (unpackedProfileDives.isEmpty && unpackedTankDives.isEmpty) {
    // The common case on every open once a database is packed: nothing to
    // do, so nothing else is loaded. The already-packed count still rides
    // out, because this is the branch a late legacy row for a packed dive
    // takes.
    return (
      profileSeries: 0,
      tankSeries: 0,
      droppedSamples: 0,
      skippedOrphans: 0,
      skippedRows: 0,
      failedDives: 0,
      skippedAlreadyPacked: alreadyPacked,
    );
  }
  final hlc = await _migrationHlc(db, now);
  // The identities already packed. A dive reaches the loops below when ANY
  // of its rows is uncovered, so each group still has to be checked: without
  // this, re-visiting a half-packed dive would write a second series for an
  // identity that already has one (its id is a fresh uuid when the existing
  // series came from ordinary use rather than a migration, so INSERT OR
  // IGNORE would not catch it) and the dive would read as doubled samples.
  final coveredProfileGroups = await _coveredProfileGroups(db);
  final coveredProfiles = {
    for (final g in coveredProfileGroups) (g.diveId, g.computerId),
  };
  final coveredTanks = await _coveredTankIdentities(db);
  final diveIds = await _parentIds(db, 'dives');
  final computerIds = await _parentIds(db, 'dive_computers');
  final sourceIds = await _parentIds(db, 'dive_data_sources');
  final tankIds = await _parentIds(db, 'dive_tanks');
  var profileSeries = 0;
  var tankSeries = 0;
  var dropped = 0;
  var skipped = 0;
  var skippedRows = 0;
  var failedDives = 0;

  if (canPackProfiles) {
    const codec = ProfileSeriesCodec();
    final hasPrimary = profileColumns.contains('is_primary');
    for (final diveId in unpackedProfileDives) {
      // One transaction per dive. Each group's INSERT would otherwise
      // autocommit on its own, and the backstop runs outside any
      // transaction of its own: a process killed between two groups of
      // one dive leaves the rest unwritten, and two groups of the same
      // (dive, computer) differ only below the granularity the residue
      // count checks, so the survivors would read as covered and v183
      // would drop the legacy table with the missing group still only
      // in it. All of a dive's groups land, or none do.
      final before = (
        profileSeries: profileSeries,
        dropped: dropped,
        skipped: skipped,
        skippedRows: skippedRows,
      );
      try {
        await db.transaction(() async {
          // Ordered by timestamp alone: the map below does the grouping, and
          // ordering by the identity columns first would interleave two raw
          // groups that resolve to one key (a dangling computer id merging into
          // the null-computer group) out of timestamp order.
          final rows = await db
              .customSelect(
                'SELECT * FROM $profileTable WHERE dive_id = ? '
                'ORDER BY timestamp, rowid',
                variables: [Variable<String>(diveId)],
              )
              .get();
          final groups = <_ProfileKey, _ProfileGroup>{};
          for (final row in rows) {
            final sample = profileSampleOf(row.data);
            if (sample == null) {
              skippedRows++;
              continue;
            }
            // The RAW parent ids are kept alongside the resolved key. The
            // key resolves a dangling id to null so the insert can satisfy
            // the foreign key, which merges those rows into the
            // null-parent group; coverage is a different question, and it
            // is asked of the raw value, because "names no computer" and
            // "names a computer this device has not merged yet" are the
            // wildcard and a distinct source respectively. A merged group
            // therefore carries more than one raw identity, and is covered
            // only when every one of them is.
            final rawComputerId = _textOf(row.data['computer_id']);
            final rawSourceId = _textOf(row.data['source_id']);
            final key = _ProfileKey(
              computerId: _resolvedParent(rawComputerId, computerIds),
              sourceId: _resolvedParent(rawSourceId, sourceIds),
              isPrimary: hasPrimary ? _boolOf(row.data['is_primary']) : true,
            );
            (groups[key] ??= (samples: [], rawParents: {}))
              ..samples.add(sample)
              ..rawParents.add((
                computerId: rawComputerId,
                sourceId: rawSourceId,
              ));
          }
          for (final entry in groups.entries) {
            if (!diveIds.contains(diveId)) {
              skipped++;
              continue;
            }
            final key = entry.key;
            // byGroupIdentity asks the finer question the staging path
            // needs: a peer can hold two groups of one computer (an edit
            // and the original it demoted), and (dive, computer) alone
            // calls the second one done.
            final covered = byGroupIdentity
                ? entry.value.rawParents.every(
                    (raw) => coveredProfileGroups.any(
                      (g) =>
                          g.diveId == diveId &&
                          g.isPrimary == key.isPrimary &&
                          (raw.computerId == null ||
                              g.computerId == key.computerId) &&
                          (raw.sourceId == null || g.sourceId == key.sourceId),
                    ),
                  )
                : coveredProfiles.contains((diveId, key.computerId));
            if (covered) {
              // Already packed under this identity; the stored series wins.
              continue;
            }
            final samples = dedupeExactSamples(entry.value.samples);
            dropped += entry.value.samples.length - samples.length;
            final encoded = codec.encode(samples);
            final summary = encoded.summary;
            final inserted = await db.customUpdate(
              'INSERT OR IGNORE INTO dive_profile_series ('
              'id, dive_id, computer_id, source_id, is_primary, sample_count, '
              'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
              'has_deco_type, has_deco_stop, has_positive_ceiling, codec_version, '
              'samples, created_at, updated_at, hlc) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable<String>(
                  profileSeriesMigratedId(
                    diveId: diveId,
                    computerId: key.computerId,
                    sourceId: key.sourceId,
                    isPrimary: key.isPrimary,
                  ),
                ),
                Variable<String>(diveId),
                Variable<String>(key.computerId),
                Variable<String>(key.sourceId),
                Variable<int>(key.isPrimary ? 1 : 0),
                Variable<int>(summary.sampleCount),
                Variable<int>(summary.startTimestamp),
                Variable<int>(summary.endTimestamp),
                Variable<double>(summary.maxDepth),
                Variable<double>(summary.firstDepth),
                Variable<double>(summary.lastDepth),
                Variable<int>(summary.hasDecoType ? 1 : 0),
                Variable<int>(summary.hasDecoStop ? 1 : 0),
                Variable<int>(summary.hasPositiveCeiling ? 1 : 0),
                Variable<int>(encoded.codecVersion),
                Variable<Uint8List>(encoded.bytes),
                Variable<int>(now),
                Variable<int>(now),
                Variable<String>(hlc),
              ],
              updateKind: UpdateKind.insert,
            );
            profileSeries += inserted;
          }
        });
      } catch (_) {
        // The dive rolled back, so its partial counts did not happen.
        profileSeries = before.profileSeries;
        dropped = before.dropped;
        skipped = before.skipped;
        skippedRows = before.skippedRows;
        // One dive at a time. A legacy value no reader expects (a text
        // depth in a REAL column, from a hand-repaired or bit-rotted file)
        // or a group the codec refuses must not cost the dives the scan
        // has not reached yet: nothing reads the legacy tables after v183,
        // so those would be a silent permanent loss rather than a retry.
        // The residue count keeps the legacy table, so a later open tries
        // this dive again.
        failedDives++;
      }
    }
  }
  if (profileSeries > 0) {
    // Raw SQL bypasses Drift's own change tracking, so a stream built on
    // `tableUpdates(TableUpdateQuery.onTable(db.diveProfileSeries))` would
    // otherwise never fire for a table this function just populated.
    db.notifyUpdates({
      const TableUpdate('dive_profile_series', kind: UpdateKind.insert),
    });
  }

  if (canPackTanks) {
    const codec = TankPressureSeriesCodec();
    for (final diveId in unpackedTankDives) {
      // One transaction per dive. Each group's INSERT would otherwise
      // autocommit on its own, and the backstop runs outside any
      // transaction of its own: a process killed between two groups of
      // one dive leaves the rest unwritten, and two groups of the same
      // (dive, computer) differ only below the granularity the residue
      // count checks, so the survivors would read as covered and v183
      // would drop the legacy table with the missing group still only
      // in it. All of a dive's groups land, or none do.
      final before = (
        tankSeries: tankSeries,
        dropped: dropped,
        skipped: skipped,
        skippedRows: skippedRows,
      );
      try {
        await db.transaction(() async {
          final rows = await db
              .customSelect(
                'SELECT * FROM $tankTable WHERE dive_id = ? '
                'ORDER BY timestamp, rowid',
                variables: [Variable<String>(diveId)],
              )
              .get();
          final groups = <_TankKey, _TankGroup>{};
          for (final row in rows) {
            // Type tests, not casts, for the reason [profileSampleOf]
            // carries: an unreadable value means this ROW holds no sample,
            // which is what a null in the same column means and has always
            // been stepped over. A cast would throw instead, and the catch
            // is per dive.
            final tankId = _textOf(row.data['tank_id']);
            final timestamp = row.data['timestamp'];
            final pressure = row.data['pressure'];
            if (tankId == null || timestamp is! num || pressure is! num) {
              skippedRows++;
              continue;
            }
            // Raw alongside resolved, for the reason the profile loop above
            // documents.
            final rawComputerId = _textOf(row.data['computer_id']);
            final key = _TankKey(
              tankId: tankId,
              computerId: _resolvedParent(rawComputerId, computerIds),
            );
            (groups[key] ??= (samples: [], rawComputerIds: {}))
              ..samples.add(
                TankPressureSample(
                  timestamp: timestamp.toInt(),
                  pressure: pressure.toDouble(),
                ),
              )
              ..rawComputerIds.add(rawComputerId);
          }
          for (final entry in groups.entries) {
            final key = entry.key;
            if (!diveIds.contains(diveId) || !tankIds.contains(key.tankId)) {
              skipped++;
              continue;
            }
            // Same null-is-a-wildcard rule as the profile check above, on
            // the identity-grained path only, and asked of the raw ids for
            // the same reason.
            final coveredTank = byGroupIdentity
                ? entry.value.rawComputerIds.every(
                    (raw) => coveredTanks.any(
                      (g) =>
                          g.diveId == diveId &&
                          g.tankId == key.tankId &&
                          (raw == null || g.computerId == key.computerId),
                    ),
                  )
                : coveredTanks.contains((
                    diveId: diveId,
                    tankId: key.tankId,
                    computerId: key.computerId,
                  ));
            if (coveredTank) {
              continue;
            }
            final samples = dedupeExactPressureSamples(entry.value.samples);
            dropped += entry.value.samples.length - samples.length;
            final encoded = codec.encode(samples);
            final inserted = await db.customUpdate(
              'INSERT OR IGNORE INTO tank_pressure_series ('
              'id, dive_id, tank_id, computer_id, sample_count, start_timestamp, '
              'end_timestamp, codec_version, samples, created_at, updated_at, hlc) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable<String>(
                  tankPressureSeriesMigratedId(
                    diveId: diveId,
                    tankId: key.tankId,
                    computerId: key.computerId,
                  ),
                ),
                Variable<String>(diveId),
                Variable<String>(key.tankId),
                Variable<String>(key.computerId),
                Variable<int>(encoded.summary.sampleCount),
                Variable<int>(encoded.summary.startTimestamp),
                Variable<int>(encoded.summary.endTimestamp),
                Variable<int>(encoded.codecVersion),
                Variable<Uint8List>(encoded.bytes),
                Variable<int>(now),
                Variable<int>(now),
                Variable<String>(hlc),
              ],
              updateKind: UpdateKind.insert,
            );
            tankSeries += inserted;
          }
        });
      } catch (_) {
        // The dive rolled back, so its partial counts did not happen.
        tankSeries = before.tankSeries;
        dropped = before.dropped;
        skipped = before.skipped;
        skippedRows = before.skippedRows;
        // One dive at a time. A legacy value no reader expects (a text
        // depth in a REAL column, from a hand-repaired or bit-rotted file)
        // or a group the codec refuses must not cost the dives the scan
        // has not reached yet: nothing reads the legacy tables after v183,
        // so those would be a silent permanent loss rather than a retry.
        // The residue count keeps the legacy table, so a later open tries
        // this dive again.
        failedDives++;
      }
    }
  }
  if (tankSeries > 0) {
    db.notifyUpdates({
      const TableUpdate('tank_pressure_series', kind: UpdateKind.insert),
    });
  }

  return (
    profileSeries: profileSeries,
    tankSeries: tankSeries,
    droppedSamples: dropped,
    skippedOrphans: skipped,
    skippedRows: skippedRows,
    failedDives: failedDives,
    skippedAlreadyPacked: alreadyPacked,
  );
}

class _ProfileKey {
  const _ProfileKey({
    required this.computerId,
    required this.sourceId,
    required this.isPrimary,
  });

  final String? computerId;
  final String? sourceId;
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      other is _ProfileKey &&
      other.computerId == computerId &&
      other.sourceId == sourceId &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode => Object.hash(computerId, sourceId, isPrimary);
}

/// One packed profile group: the samples, plus every RAW `(computer_id,
/// source_id)` pair that resolved into this group's key. Coverage is asked
/// of the raw pairs, the way [legacyRowCoveredSql] asks it of the raw
/// columns; the key's resolved ids are what the insert can actually store.
typedef _ProfileGroup = ({
  List<ProfileSample> samples,
  Set<({String? computerId, String? sourceId})> rawParents,
});

/// [_ProfileGroup]'s pressure twin. A pressure row carries no source or
/// primary flag, so its raw identity is the computer id alone.
typedef _TankGroup = ({
  List<TankPressureSample> samples,
  Set<String?> rawComputerIds,
});

class _TankKey {
  const _TankKey({required this.tankId, required this.computerId});

  final String tankId;
  final String? computerId;

  @override
  bool operator ==(Object other) =>
      other is _TankKey &&
      other.tankId == tankId &&
      other.computerId == computerId;

  @override
  int get hashCode => Object.hash(tankId, computerId);
}

/// Every dive with legacy rows, split into the ones still to pack and a
/// count of the ones a series row already covers.
typedef _LegacyDiveScan = ({List<String> unpacked, int alreadyPacked});

const _LegacyDiveScan _emptyScan = (unpacked: <String>[], alreadyPacked: 0);

/// One pass over [legacyTable]'s distinct dive ids, marking each with
/// whether [seriesTable] already holds a row for it. Cheap once a database
/// is packed (an indexed EXISTS per legacy dive), which is what lets the
/// beforeOpen backstop call the packer on every open. Empty when the series
/// table is absent: `_assertProfileSeriesSchema` waits for that table's
/// foreign-key parents, so there is nothing to pack into yet.
///
/// The already-packed side is what feeds
/// [ProfilePackReport.skippedAlreadyPacked], and it comes from this same
/// scan rather than a second COUNT so the per-open cost does not change.
Future<_LegacyDiveScan> _scanLegacyDives(
  DatabaseConnectionUser db, {
  required String legacyTable,
  required String seriesTable,
  required bool byTank,
  bool byGroupIdentity = false,
}) async {
  if (!await legacyTableExists(db, seriesTable)) return _emptyScan;
  final covered = await legacyRowCoveredSql(
    db,
    legacyTable: legacyTable,
    seriesTable: seriesTable,
    byTank: byTank,
    byGroupIdentity: byGroupIdentity,
  );
  // A dive is done only when EVERY one of its legacy rows is covered, hence
  // MIN over the per-row predicate. Testing the dive alone would leave a
  // second computer's rows unpacked forever on a half-packed dive.
  // One row per identity, not per sample: the coverage predicate is a
  // correlated subquery, so evaluating it inside the aggregate over the raw
  // table cost an index seek per sample. Collapsing first makes the cost
  // one pass plus a seek per group, which is what this always claimed.
  final identity = (await legacyCoverageIdentityColumns(
    db,
    legacyTable: legacyTable,
    byTank: byTank,
    byGroupIdentity: byGroupIdentity,
  )).join(', ');
  final rows = await db
      .customSelect(
        'SELECT p.dive_id AS dive_id, '
        'MIN(CASE WHEN $covered THEN 1 ELSE 0 END) AS all_covered FROM '
        '(SELECT DISTINCT $identity FROM $legacyTable) p '
        'GROUP BY p.dive_id ORDER BY p.dive_id',
      )
      .get();
  final unpacked = <String>[];
  var alreadyPacked = 0;
  for (final row in rows) {
    if (row.read<int>('all_covered') != 0) {
      alreadyPacked++;
    } else {
      unpacked.add(row.read<String>('dive_id'));
    }
  }
  return (unpacked: unpacked, alreadyPacked: alreadyPacked);
}

/// The `(dive, computer, source, isPrimary)` groups `dive_profile_series`
/// already holds. Callers that only want the coarse `(dive, computer)`
/// coverage project the first two members out.
Future<
  Set<({String diveId, String? computerId, String? sourceId, bool isPrimary})>
>
_coveredProfileGroups(DatabaseConnectionUser db) async {
  if (!await legacyTableExists(db, 'dive_profile_series')) return const {};
  final rows = await db
      .customSelect(
        'SELECT dive_id, computer_id, source_id, is_primary '
        'FROM dive_profile_series',
      )
      .get();
  return {
    for (final r in rows)
      (
        diveId: r.read<String>('dive_id'),
        computerId: r.readNullable<String>('computer_id'),
        sourceId: r.readNullable<String>('source_id'),
        isPrimary: r.read<int>('is_primary') != 0,
      ),
  };
}

/// The `(dive, tank, computer)` identities `tank_pressure_series` holds.
Future<Set<({String diveId, String tankId, String? computerId})>>
_coveredTankIdentities(DatabaseConnectionUser db) async {
  if (!await legacyTableExists(db, 'tank_pressure_series')) return const {};
  final rows = await db
      .customSelect(
        'SELECT dive_id, tank_id, computer_id FROM tank_pressure_series',
      )
      .get();
  return {
    for (final r in rows)
      (
        diveId: r.read<String>('dive_id'),
        tankId: r.read<String>('tank_id'),
        computerId: r.readNullable<String>('computer_id'),
      ),
  };
}

/// Every id in [table], or an empty set when the table is absent. Loaded
/// once per run so the per-group parent checks below cost nothing.
Future<Set<String>> _parentIds(DatabaseConnectionUser db, String table) async {
  if (!await legacyTableExists(db, table)) return const {};
  final rows = await db.customSelect('SELECT id FROM $table').get();
  return {for (final row in rows) row.read<String>('id')};
}

/// [id] when it still names a row in [parents], null otherwise. A legacy
/// row can point at a computer or source that has since been deleted, which
/// under `PRAGMA foreign_keys = ON` no insert could carry.
String? _resolvedParent(String? id, Set<String> parents) =>
    id != null && parents.contains(id) ? id : null;

/// A legacy id column read as text, or null when the value is not text.
///
/// Every id column is declared TEXT, so SQLite's affinity has already made
/// this the identity function for anything a supported build wrote. It is
/// here for a restored or hand-repaired file, where a value of another
/// storage class would otherwise throw from a cast and cost the dive.
String? _textOf(Object? value) => value is String ? value : null;

/// The clock value migrated rows carry. Null when this device has never
/// synced: there is no device id to stamp with, and nothing to publish to.
Future<String?> _migrationHlc(DatabaseConnectionUser db, int nowMs) async {
  if (!await legacyTableExists(db, 'sync_metadata')) return null;
  final rows = await db
      .customSelect("SELECT * FROM sync_metadata WHERE id = 'global' LIMIT 1")
      .get();
  if (rows.isEmpty) return null;
  final deviceId = rows.first.data['device_id'] as String?;
  if (deviceId == null || deviceId.isEmpty) return null;
  // Advance the persisted clock rather than minting from wall-clock time:
  // a peer merge can have moved this device's clock ahead of now, and a
  // stamp below the publish watermark would never ride a changeset.
  final persisted = rows.first.data['hlc'] as String?;
  if (persisted != null && persisted.isNotEmpty) {
    try {
      final advanced = Hlc.parse(persisted).increment(nowMs);
      // The device id column is the authority on this device's node id.
      return Hlc(advanced.physicalTime, advanced.counter, deviceId).toString();
    } on FormatException {
      // Fall through to a fresh clock.
    }
  }
  return Hlc(nowMs, 0, deviceId).toString();
}

/// The legacy `is_primary` value as a bool.
///
/// The SQL half of this rule is `_primarySql` in
/// `profile_series_pack_coverage.dart`, and the two decide the same thing
/// for the same row: this one whether to WRITE the series, that one whether
/// the staged rows may be cleared. They have to agree on every value, so
/// change them together.
bool _boolOf(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  // Every legacy schema declares is_primary NOT NULL DEFAULT 1, so a null
  // here means the column is not carrying a value at all; a legacy row with
  // no flag is the dive's live profile, which is what true says. Text lands
  // here too: the staging table takes a peer's JSON, and INTEGER affinity
  // leaves a value it cannot convert as text.
  return true;
}
