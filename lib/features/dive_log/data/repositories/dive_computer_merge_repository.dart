import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// What a merge did, for the snackbar and for navigation.
class DiveComputerMergeResult {
  const DiveComputerMergeResult({
    required this.survivorId,
    required this.mergedComputerIds,
    required this.movedDiveCount,
  });

  /// The record every reference now points at.
  final String survivorId;

  /// The records that were folded in and deleted, in the order given.
  final List<String> mergedComputerIds;

  /// Distinct dives that referenced a merged record through any table.
  final int movedDiveCount;
}

/// Folds duplicate dive computer records into one (issue #645).
///
/// Extracted from [DiveComputerRepository], which is already at its size
/// limit, in the same way the buddy merge lives beside the buddy repository.
///
/// The same physical computer is saved once per host when its Bluetooth
/// identifier differs between a Mac, an iPhone and an iPad. Every table that
/// attributes data to a computer is repointed at the survivor in one
/// transaction, the duplicates are deleted with tombstones, and every dive
/// that referenced a duplicate is restamped: `dive_data_sources`,
/// `dive_tanks` and `dive_profile_events` have no clock of their own and only
/// replicate when their parent dive does.
class DiveComputerMergeRepository {
  DiveComputerMergeRepository({
    SyncRepository? syncRepository,
    ProfileSeriesRepository? profileSeries,
    TankPressureSeriesRepository? tankSeries,
  }) : _syncRepository = syncRepository ?? SyncRepository(),
       _profileSeries = profileSeries ?? ProfileSeriesRepository(),
       _tankSeries = tankSeries ?? TankPressureSeriesRepository();

  final SyncRepository _syncRepository;
  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;
  final _log = LoggerService.forClass(DiveComputerMergeRepository);

  db.AppDatabase get _db => DatabaseService.instance.database;

  /// Distinct dives a merge of [duplicateIds] into [survivorId] would move.
  ///
  /// Takes the survivor because gear links are counted the way the merge
  /// moves them: a dive can reference a duplicate through its gear twin
  /// alone, and whether that link moves depends on which twin the survivor
  /// ends up with.
  Future<int> countAffectedDives({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    final duplicates = _duplicatesToMerge(survivorId, duplicateIds);
    if (duplicates.isEmpty) return 0;

    final rows = await (_db.select(
      _db.diveComputers,
    )..where((t) => t.id.isIn([survivorId, ...duplicates]))).get();
    final byId = {for (final row in rows) row.id: row};

    final ids = await _affectedDiveIds(duplicates);
    ids.addAll(
      await _gearLinkedDiveIds(
        survivorTwinId: _adoptedTwinId(survivorId, duplicates, byId),
        duplicateTwinIds: {for (final id in duplicates) ?byId[id]?.equipmentId},
      ),
    );
    return ids.length;
  }

  /// The duplicates a merge actually folds in: [duplicateIds] without the
  /// survivor and without repeats, in the order given.
  List<String> _duplicatesToMerge(
    String survivorId,
    List<String> duplicateIds,
  ) => duplicateIds
      .where((id) => id != survivorId)
      .toSet()
      .toList(growable: false);

  /// The gear twin the survivor holds after the merge: its own, else the
  /// first one a duplicate has. Mirrors `mergedDiveComputer`, which fills the
  /// survivor's blank `equipmentId` from the first duplicate that has one,
  /// verbatim: it is a foreign key and has to match `equipment.id` exactly.
  String? _adoptedTwinId(
    String survivorId,
    List<String> duplicateIds,
    Map<String, db.DiveComputer> byId,
  ) {
    for (final id in [survivorId, ...duplicateIds]) {
      final twin = byId[id]?.equipmentId;
      if (twin != null && twin.trim().isNotEmpty) return twin;
    }
    return null;
  }

  /// The duplicate twins whose dive links move onto [survivorTwinId]. A twin
  /// the survivor already holds keeps its links where they are.
  List<String> _twinsToMove(
    String? survivorTwinId,
    Set<String> duplicateTwinIds,
  ) => survivorTwinId == null
      ? const []
      : duplicateTwinIds
            .where((id) => id != survivorTwinId)
            .toList(growable: false);

  /// Dives that reference a duplicate through its gear twin alone. These
  /// carry no `computer_id` of their own, so [_affectedDiveIds] cannot see
  /// them, but [_repointGearLinks] moves and restamps them.
  Future<Set<String>> _gearLinkedDiveIds({
    required String? survivorTwinId,
    required Set<String> duplicateTwinIds,
  }) async {
    final fromTwins = _twinsToMove(survivorTwinId, duplicateTwinIds);
    if (fromTwins.isEmpty) return {};
    final rows =
        await (_db.selectOnly(_db.diveEquipment)
              ..addColumns([_db.diveEquipment.diveId])
              ..where(_db.diveEquipment.equipmentId.isIn(fromTwins)))
            .get();
    return {for (final row in rows) row.read(_db.diveEquipment.diveId)!};
  }

  /// Folds [duplicateIds] into [survivorId].
  ///
  /// Throws [ArgumentError] when there is nothing to merge and [StateError]
  /// when any record is missing; nothing is written in either case.
  Future<DiveComputerMergeResult> mergeComputers({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    final duplicates = _duplicatesToMerge(survivorId, duplicateIds);
    if (duplicates.isEmpty) {
      throw ArgumentError.value(
        duplicateIds,
        'duplicateIds',
        'must name at least one computer other than the survivor',
      );
    }

    try {
      _log.info(
        'Merging ${duplicates.length} dive computer(s) into $survivorId',
      );

      final rows = await (_db.select(
        _db.diveComputers,
      )..where((t) => t.id.isIn([survivorId, ...duplicates]))).get();
      final byId = {for (final row in rows) row.id: row};
      final survivorRow = byId[survivorId];
      if (survivorRow == null) {
        throw StateError('Survivor dive computer $survivorId does not exist');
      }
      final missing = duplicates.where((id) => !byId.containsKey(id));
      if (missing.isNotEmpty) {
        throw StateError('Dive computers not found: ${missing.join(', ')}');
      }

      final survivor = _toDomain(survivorRow);
      final merged = mergedDiveComputer(survivor, [
        for (final id in duplicates) _toDomain(byId[id]!),
      ]);
      final duplicateTwinIds = {
        for (final id in duplicates) ?byId[id]!.equipmentId,
      };

      final now = DateTime.now().millisecondsSinceEpoch;
      late final Set<String> affectedDives;

      await _db.transaction(() async {
        affectedDives = await _affectedDiveIds(duplicates);

        await _repointDiveOwnedTables(duplicates, survivorId, now);
        await _repointQualityFindings(duplicates, survivorId, now);
        await _profileSeries.repointComputer(duplicates, survivorId, now: now);
        await _tankSeries.repointComputer(duplicates, survivorId, now: now);
        await _repointLegacyProfiles(duplicates, survivorId);

        final relinked = await _repointGearLinks(
          survivorTwinId: merged.equipmentId,
          duplicateTwinIds: duplicateTwinIds,
          now: now,
        );
        affectedDives.addAll(relinked);

        await _bumpDives(affectedDives.toList(growable: false), now);
        await _writeSurvivor(merged, now);

        for (final id in duplicates) {
          await (_db.delete(
            _db.diveComputers,
          )..where((t) => t.id.equals(id))).go();
          await _syncRepository.logDeletion(
            entityType: 'diveComputers',
            recordId: id,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info(
        'Merged ${duplicates.length} dive computer(s) into $survivorId; '
        '${affectedDives.length} dive(s) restamped',
      );

      return DiveComputerMergeResult(
        survivorId: survivorId,
        mergedComputerIds: duplicates,
        movedDiveCount: affectedDives.length,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to merge dive computers $duplicateIds into $survivorId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------------

  /// Every dive that references one of [computerIds] through any table.
  Future<Set<String>> _affectedDiveIds(List<String> computerIds) async {
    final ids = <String>{};

    final dives =
        await (_db.selectOnly(_db.dives)
              ..addColumns([_db.dives.id])
              ..where(_db.dives.computerId.isIn(computerIds)))
            .get();
    ids.addAll(dives.map((r) => r.read(_db.dives.id)!));

    Future<void> collect<T extends Table, R>(
      TableInfo<T, R> table,
      GeneratedColumn<String> diveId,
      GeneratedColumn<String> computerId,
    ) async {
      final rows =
          await (_db.selectOnly(table)
                ..addColumns([diveId])
                ..where(computerId.isIn(computerIds)))
              .get();
      ids.addAll(rows.map((r) => r.read(diveId)!));
    }

    await collect(
      _db.diveDataSources,
      _db.diveDataSources.diveId,
      _db.diveDataSources.computerId,
    );
    await collect(
      _db.diveTanks,
      _db.diveTanks.diveId,
      _db.diveTanks.computerId,
    );
    await collect(
      _db.diveProfileEvents,
      _db.diveProfileEvents.diveId,
      _db.diveProfileEvents.computerId,
    );
    await collect(
      _db.qualityFindings,
      _db.qualityFindings.diveId,
      _db.qualityFindings.computerId,
    );
    await collect(
      _db.diveProfileSeries,
      _db.diveProfileSeries.diveId,
      _db.diveProfileSeries.computerId,
    );
    await collect(
      _db.tankPressureSeries,
      _db.tankPressureSeries.diveId,
      _db.tankPressureSeries.computerId,
    );
    return ids;
  }

  /// The tables whose rows ride their parent dive's clock: a plain repoint,
  /// with the dive restamped afterwards by [_bumpDives].
  Future<void> _repointDiveOwnedTables(
    List<String> fromIds,
    String toId,
    int now,
  ) async {
    await (_db.update(
      _db.dives,
    )..where((t) => t.computerId.isIn(fromIds))).write(
      db.DivesCompanion(computerId: Value(toId), updatedAt: Value(now)),
    );
    await (_db.update(_db.diveDataSources)
          ..where((t) => t.computerId.isIn(fromIds)))
        .write(db.DiveDataSourcesCompanion(computerId: Value(toId)));
    await (_db.update(_db.diveTanks)..where((t) => t.computerId.isIn(fromIds)))
        .write(db.DiveTanksCompanion(computerId: Value(toId)));
    await (_db.update(_db.diveProfileEvents)
          ..where((t) => t.computerId.isIn(fromIds)))
        .write(db.DiveProfileEventsCompanion(computerId: Value(toId)));
  }

  /// Quality findings carry their own hlc, so each moved row is restamped.
  Future<void> _repointQualityFindings(
    List<String> fromIds,
    String toId,
    int now,
  ) async {
    final rows =
        await (_db.selectOnly(_db.qualityFindings)
              ..addColumns([_db.qualityFindings.id])
              ..where(_db.qualityFindings.computerId.isIn(fromIds)))
            .get();
    final ids = rows.map((r) => r.read(_db.qualityFindings.id)!).toList();
    if (ids.isEmpty) return;

    for (final chunk in seriesIdChunks(ids)) {
      await (_db.update(
        _db.qualityFindings,
      )..where((t) => t.id.isIn(chunk))).write(
        db.QualityFindingsCompanion(
          computerId: Value(toId),
          updatedAt: Value(now),
        ),
      );
      for (final id in chunk) {
        await _syncRepository.markRecordPending(
          entityType: 'qualityFindings',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
  }

  /// The pre-v183 row-per-sample table survives on a device whose pack could
  /// not finish, and its FK has no ON DELETE action, so a lingering reference
  /// would block the duplicate's delete (the #823 shape).
  Future<void> _repointLegacyProfiles(List<String> fromIds, String toId) async {
    final exists = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'dive_profiles'",
        )
        .get();
    if (exists.isEmpty) return;
    final placeholders = List.filled(fromIds.length, '?').join(', ');
    await _db.customStatement(
      'UPDATE dive_profiles SET computer_id = ? '
      'WHERE computer_id IN ($placeholders)',
      [toId, ...fromIds],
    );
  }

  /// Moves `dive_equipment` links from each duplicate's gear twin onto the
  /// survivor's twin. Returns the dives whose links changed so they can be
  /// restamped: the junction has no clock and rides the dive.
  ///
  /// The duplicate's gear item itself is left alone. It may carry service
  /// history the user wants, and the gear list has its own delete.
  Future<Set<String>> _repointGearLinks({
    required String? survivorTwinId,
    required Set<String> duplicateTwinIds,
    required int now,
  }) async {
    final touched = <String>{};
    if (survivorTwinId == null) return touched;
    final fromTwins = _twinsToMove(survivorTwinId, duplicateTwinIds);
    if (fromTwins.isEmpty) return touched;

    final links = await (_db.select(
      _db.diveEquipment,
    )..where((t) => t.equipmentId.isIn(fromTwins))).get();
    if (links.isEmpty) return touched;

    final alreadyLinked =
        await (_db.selectOnly(_db.diveEquipment)
              ..addColumns([_db.diveEquipment.diveId])
              ..where(_db.diveEquipment.equipmentId.equals(survivorTwinId)))
            .get();
    final linkedDives = {
      for (final row in alreadyLinked) row.read(_db.diveEquipment.diveId)!,
    };

    for (final link in links) {
      touched.add(link.diveId);
      if (linkedDives.add(link.diveId)) {
        // Re-key the row onto the survivor but keep its provenance, so a
        // twin that was a part of an assembly stays one (issue #1487).
        await _db
            .into(_db.diveEquipment)
            .insert(
              link
                  .toCompanion(false)
                  .copyWith(equipmentId: Value(survivorTwinId)),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveEquipment',
          recordId: '${link.diveId}|$survivorTwinId',
          localUpdatedAt: now,
        );
      }
      await (_db.delete(_db.diveEquipment)..where(
            (t) =>
                t.diveId.equals(link.diveId) &
                t.equipmentId.equals(link.equipmentId),
          ))
          .go();
      await _syncRepository.logDeletion(
        entityType: 'diveEquipment',
        recordId: '${link.diveId}|${link.equipmentId}',
      );
    }
    return touched;
  }

  /// Restamps every affected dive so its clockless children replicate.
  Future<void> _bumpDives(List<String> diveIds, int now) async {
    if (diveIds.isEmpty) return;
    for (final chunk in seriesIdChunks(diveIds)) {
      await (_db.update(_db.dives)..where((t) => t.id.isIn(chunk))).write(
        db.DivesCompanion(updatedAt: Value(now)),
      );
      for (final id in chunk) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
  }

  Future<void> _writeSurvivor(domain.DiveComputer merged, int now) async {
    await (_db.update(
      _db.diveComputers,
    )..where((t) => t.id.equals(merged.id))).write(
      db.DiveComputersCompanion(
        manufacturer: Value(merged.manufacturer),
        model: Value(merged.model),
        serialNumber: Value(merged.serialNumber),
        firmwareVersion: Value(merged.firmwareVersion),
        connectionType: Value(merged.connectionType),
        bluetoothAddress: Value(merged.bluetoothAddress),
        lastDiveFingerprint: Value(merged.lastDiveFingerprint),
        lastDownloadTimestamp: Value(
          merged.lastDownload?.millisecondsSinceEpoch,
        ),
        diveCount: Value(merged.diveCount),
        isFavorite: Value(merged.isFavorite),
        notes: Value(merged.notes),
        equipmentId: Value(merged.equipmentId),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveComputers',
      recordId: merged.id,
      localUpdatedAt: now,
    );
  }

  domain.DiveComputer _toDomain(db.DiveComputer row) => domain.DiveComputer(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    manufacturer: row.manufacturer,
    model: row.model,
    serialNumber: row.serialNumber,
    firmwareVersion: row.firmwareVersion,
    connectionType: row.connectionType,
    bluetoothAddress: row.bluetoothAddress,
    lastDiveFingerprint: row.lastDiveFingerprint,
    lastDownload: row.lastDownloadTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(row.lastDownloadTimestamp!)
        : null,
    diveCount: row.diveCount,
    isFavorite: row.isFavorite,
    notes: row.notes,
    equipmentId: row.equipmentId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
