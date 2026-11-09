import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_tank_filler.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

export 'package:submersion/features/transmitters/data/services/transmitter_tank_filler.dart'
    show ApplyToExistingResult;

/// Thrown when an entry would share a serial (per diver) or a
/// (computer, channel) key with [existing].
class TransmitterConflictException implements Exception {
  final Transmitter existing;
  const TransmitterConflictException(this.existing);

  @override
  String toString() =>
      'TransmitterConflictException: conflicts with ${existing.label}';
}

class TransmitterRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final TransmitterTankFiller _filler = TransmitterTankFiller();

  static const String _entity = 'transmitters';

  Stream<void> watchTransmittersChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.transmitters));

  /// Ticks when either the registry or the tanks it is matched against change.
  Stream<void> watchUnassignedChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.transmitters, _db.diveTanks]),
  );

  Future<List<Transmitter>> getForDiver(String? diverId) async {
    final query = _db.select(_db.transmitters)
      ..orderBy([(t) => OrderingTerm.asc(t.label.collate(Collate.noCase))]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }
    final rows = await query.get();
    return sortedByText(rows, (r) => r.label).map(_map).toList();
  }

  /// The registry keys behind Transmitter item [equipmentId] (issue #3676),
  /// most recently updated first: usually one serial, or a channel per
  /// computer that reports channels only.
  Future<List<Transmitter>> getForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.transmitters)
              ..where((t) => t.transmitterEquipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.updatedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(_map).toList();
  }

  /// Saves the diver's setup of Transmitter item [equipmentId] onto every
  /// key behind it, and marks each configured (issue #3676): role and
  /// cylinder belong to the physical transmitter, not to one key.
  /// [exceptKeyId] is a key the caller has just saved with this setup, so it
  /// is not written, staged and rescanned a second time.
  Future<void> saveSetup(
    String equipmentId, {
    required TankRole role,
    String? cylinderId,
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    String? presetName,
    String? exceptKeyId,
  }) async {
    for (final key in await getForEquipment(equipmentId)) {
      if (key.id == exceptKeyId) continue;
      await update(
        key.copyWith(
          role: role,
          equipmentId: cylinderId,
          clearEquipmentId: cylinderId == null,
          volumeL: volumeL,
          clearVolumeL: volumeL == null,
          workingPressureBar: workingPressureBar,
          clearWorkingPressureBar: workingPressureBar == null,
          material: material,
          clearMaterial: material == null,
          presetName: presetName,
          clearPresetName: presetName == null,
          isConfigured: true,
        ),
      );
    }
  }

  Future<Transmitter?> getById(String id) async {
    final row = await (_db.select(
      _db.transmitters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// The most recently logged [TankRole] among [diverId]'s own dives that
  /// used [equipmentId] as a cylinder, ordered by dive date descending: a
  /// sensible default when a diver links a transmitter to that cylinder
  /// (issue #3367), never a value that overrides a role they already set.
  /// Scoped to the diver: the picker also offers cylinders shared from
  /// another profile, whose dive history is that profile's own and must
  /// never leak into this one's suggestion. Only logged dives count, so a
  /// planned dive never outranks them, and only roles a person or the
  /// registry set: a role the computer read off the transmitter's name
  /// (issue #2595) is an unconfirmed guess, and suggesting it would let
  /// [applyToExistingDives] confirm it on every matching dive. Falls back
  /// to [TankRole.backGas] when no such history exists, matching that
  /// column's own default.
  Future<TankRole> lastRoleForEquipment(
    String equipmentId, {
    String? diverId,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT dt.tank_role AS tank_role FROM dive_tanks dt '
          'JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.equipment_id = ? '
          'AND d.is_planned = 0 '
          'AND dt.role_source IS NULL '
          'AND (? IS NULL OR d.diver_id = ?) '
          'ORDER BY d.dive_date_time DESC LIMIT 1',
          variables: [
            Variable<String>(equipmentId),
            Variable<String>(diverId),
            Variable<String>(diverId),
          ],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .getSingleOrNull();
    final tankRole = row?.read<String>('tank_role');
    return TankRole.values.firstWhere(
      (e) => e.name == tankRole,
      orElse: () => TankRole.backGas,
    );
  }

  /// The normalised serials of every registry row that names [equipmentId]
  /// as its transmitter gear item (condition phase 3b): the condition engine
  /// keys a transmitter item's gap entries on them. Not the row's
  /// equipmentId, which is the cylinder it feeds.
  Future<Set<String>> getSerialsForEquipment(String equipmentId) async {
    final rows = await (_db.select(
      _db.transmitters,
    )..where((t) => t.transmitterEquipmentId.equals(equipmentId))).get();
    return {
      for (final r in rows) ?normalizeTransmitterSerial(r.transmitterSerial),
    };
  }

  Future<Transmitter> create(Transmitter t) async {
    final normalized = _normalized(
      t,
    ).copyWith(id: t.id.isEmpty ? _uuid.v4() : t.id);
    await _checkConflicts(normalized);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _insertRow(normalized, now);
    SyncEventBus.notifyLocalChange();
    await _rescanAffectedDives([normalized]);
    return normalized.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// An unknown-transmitter finding clears itself on the next scan of its
  /// dive, so queue one, in a single batch, for the dives that carry any of
  /// [entries]' keys.
  Future<void> _rescanAffectedDives(Iterable<Transmitter> entries) async {
    final affected = {
      for (final t in entries)
        ...(await _tanksForEntry(t)).map((r) => r.diveId),
    };
    if (affected.isNotEmpty) scheduleQualityScan(affected);
  }

  /// Queues a rescan of the dives each of [transmitterIds] matches, after a
  /// change of owner (issue #2852): which profile's registry knows the
  /// serial decides the unknown-transmitter finding.
  Future<void> rescanDivesForTransmitters(
    Iterable<String> transmitterIds,
  ) async {
    for (final id in transmitterIds.toSet()) {
      final t = await getById(id);
      if (t != null) await _rescanAffectedDives([t]);
    }
  }

  /// Clears every registry link to [equipmentId], as the cylinder an entry
  /// feeds or the transmitter item it is, and stages each changed row. Call
  /// it before the item is deleted: ON DELETE SET NULL would clear the link
  /// too, but moves no clock and stages nothing, so a peer would keep it.
  Future<void> unlinkFromDeletedEquipment(String equipmentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.transmitters)..where(
                (t) =>
                    t.equipmentId.equals(equipmentId) |
                    t.transmitterEquipmentId.equals(equipmentId),
              ))
              .get();
      if (rows.isEmpty) return;
      await (_db.update(
        _db.transmitters,
      )..where((t) => t.equipmentId.equals(equipmentId))).write(
        TransmittersCompanion(
          equipmentId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(
        _db.transmitters,
      )..where((t) => t.transmitterEquipmentId.equals(equipmentId))).write(
        TransmittersCompanion(
          transmitterEquipmentId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      for (final row in rows) {
        await _syncRepository.markRecordPending(
          entityType: _entity,
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
    });
  }

  /// Before computer [computerId] is deleted (issue #3676): a row keyed only
  /// by its channel on that computer could never match again, so it is
  /// deleted and tombstoned; a row with a serial keeps the serial key and
  /// loses the channel, staged rather than nulled by the FK. The transmitter
  /// item stays, as gear.
  Future<void> detachFromDeletedComputer(String computerId) async {
    final rows = await (_db.select(
      _db.transmitters,
    )..where((t) => t.diveComputerId.equals(computerId))).get();
    if (rows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      if (normalizeTransmitterSerial(row.transmitterSerial) == null) {
        await (_db.delete(
          _db.transmitters,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: _entity,
          recordId: row.id,
        );
      } else {
        await (_db.update(
          _db.transmitters,
        )..where((t) => t.id.equals(row.id))).write(
          TransmittersCompanion(
            diveComputerId: const Value(null),
            channelIndex: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: _entity,
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
    }
    SyncEventBus.notifyLocalChange();
  }

  Future<void> update(Transmitter t) async {
    final normalized = _normalized(t);
    await _checkConflicts(normalized);
    // The dives the entry matched before the edit lose its findings (or
    // gain an unknown-transmitter one) when its key changes, so they are
    // rescanned along with the dives it matches now.
    final previous = await getById(normalized.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _writeRow(normalized, now);
    SyncEventBus.notifyLocalChange();
    await _rescanAffectedDives([normalized, ?previous]);
  }

  /// Writes [entry] onto [unclaimed]'s row, replacing the key [entry] edits
  /// if it has one (issue #3367). The row is kept rather than replaced: its
  /// id derives from the serial, so a peer downloading the same serial still
  /// lands on it. Returns the saved key, whose id is [unclaimed]'s only when
  /// the row was taken over.
  ///
  /// One transaction holds the checks, the delete and the write, and reads
  /// the row afresh: one a sync has set up since the clash refuses as a clash
  /// does, and one that is gone or no longer holds the serial has nothing to
  /// take over, so [entry] is saved as it is.
  Future<Transmitter> takeOverKey(
    Transmitter entry,
    Transmitter unclaimed,
  ) async {
    final normalized = _normalized(
      entry,
    ).copyWith(id: entry.id.isEmpty ? _uuid.v4() : entry.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    Transmitter? replaced;
    var saved = normalized;
    await _db.transaction(() async {
      final row = await getById(unclaimed.id);
      final holder =
          row != null &&
              normalizeTransmitterSerial(row.transmitterSerial) ==
                  normalized.transmitterSerial
          ? row
          : null;
      if (holder != null && holder.isConfigured) {
        throw TransmitterConflictException(holder);
      }
      if (holder != null) saved = normalized.copyWith(id: holder.id);
      await _checkConflicts(saved, ignoring: normalized.id);
      replaced = await getById(normalized.id);
      if (holder == null) {
        if (replaced == null) {
          await _insertRow(saved, now);
        } else {
          await _writeRow(saved, now);
        }
        return;
      }
      if (replaced != null) await _deleteRow(normalized.id);
      await _writeRow(saved, now);
    });
    SyncEventBus.notifyLocalChange();
    // The placeholder carried the same serial, so the saved key's dives
    // already include its own; the replaced key's are rescanned as an
    // edit's are.
    await _rescanAffectedDives([saved, ?replaced]);
    return saved;
  }

  Future<void> delete(String id) async {
    // Read before the row goes: its dives are rescanned by its key.
    final previous = await getById(id);
    await _deleteRow(id);
    SyncEventBus.notifyLocalChange();
    if (previous != null) await _rescanAffectedDives([previous]);
  }

  /// Queues a rescan of the dives matched by every entry that names
  /// [equipmentId] as its transmitter gear item, after that item's own
  /// serial changed (issue #3367): the gear-serial mismatch finding reads it.
  Future<void> rescanDivesForTransmitterItem(String equipmentId) async {
    final rows = await (_db.select(
      _db.transmitters,
    )..where((t) => t.transmitterEquipmentId.equals(equipmentId))).get();
    await _rescanAffectedDives(rows.map(_map));
  }

  /// The canonical serials of the diver's entries that are not set up
  /// (issue #3676): unconfigured, or naming no cylinder. What the
  /// post-download notice and the data-quality nudge ask about.
  Future<Set<String>> serialsNeedingSetup(String? diverId) async => {
    for (final t in await getForDiver(diverId))
      if (!t.isSetUp) ?normalizeTransmitterSerial(t.transmitterSerial),
  };

  /// The Transmitter item of the entry whose serial is [serial], if any.
  Future<String?> itemIdForSerial(String serial, {String? diverId}) async {
    final wanted = normalizeTransmitterSerial(serial);
    if (wanted == null) return null;
    for (final t in await getForDiver(diverId)) {
      if (normalizeTransmitterSerial(t.transmitterSerial) == wanted &&
          t.transmitterEquipmentId != null) {
        return t.transmitterEquipmentId;
      }
    }
    return null;
  }

  /// How many distinct serials seen on [computerId]'s dives have an entry
  /// that is set up, and how many do not. Set up, not merely registered
  /// (issue #3676): a download now registers every serial it sees.
  Future<({int known, int unassigned})> serialCountsForComputer(
    String computerId, {
    String? diverId,
  }) async {
    final knownSerials = Transmitter.setUpSerials(await getForDiver(diverId));
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT dt.transmitter_serial AS serial '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL '
          'AND (dt.computer_id = ? OR d.computer_id = ?)',
          variables: [
            Variable<String>(computerId),
            Variable<String>(computerId),
          ],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final seen = <String>{};
    for (final row in rows) {
      final serial = normalizeTransmitterSerial(row.read<String>('serial'));
      if (serial != null) seen.add(serial);
    }
    final known = seen.where(knownSerials.contains).length;
    return (known: known, unassigned: seen.length - known);
  }

  /// The counts [applyToExistingDives] would report, without writing.
  Future<ApplyToExistingResult> previewApplyToExistingDives(
    Transmitter t,
  ) async {
    final candidates = await _tanksForEntry(t);
    return (
      tanksUpdated: candidates.length,
      divesUpdated: candidates.map((r) => r.diveId).toSet().length,
      mixesKept: 0,
    );
  }

  /// Retroactive fill for the tanks that carry [t]'s key, by the rules of
  /// [TransmitterTankFiller].
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter t) async {
    final candidates = await _tanksForEntry(t);
    return _filler.fill([for (final row in candidates) (row, t)]);
  }

  /// Fills each set-up transmitter onto the tanks of [diveIds] that carry
  /// its serial (issue #4347): the step a file import or a dive merge runs
  /// on its own dives, so a serial the diver has already set up arrives
  /// configured instead of waiting for "Apply to existing dives". Matched
  /// on serial only, within each dive's own diver; a channel entry is left
  /// to "Apply to existing dives", since a file's tank order need not be
  /// the computer's channel. Fill-only, as [TransmitterTankFiller] is.
  Future<ApplyToExistingResult> applyToDives(Iterable<String> diveIds) async {
    final ids = diveIds.toSet().toList();
    if (ids.isEmpty) return noTanksFilled;
    final diverByTank = <String, String?>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, (i + 500).clamp(0, ids.length));
      final rows = await _db
          .customSelect(
            'SELECT dt.id AS id, d.diver_id AS diver_id '
            'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
            'WHERE dt.transmitter_serial IS NOT NULL AND d.id IN '
            '(${List.filled(chunk.length, '?').join(', ')})',
            variables: [for (final id in chunk) Variable<String>(id)],
            readsFrom: {_db.diveTanks, _db.dives},
          )
          .get();
      for (final r in rows) {
        diverByTank[r.read<String>('id')] = r.read<String?>('diver_id');
      }
    }
    if (diverByTank.isEmpty) return noTanksFilled;

    final matchers = <String?, TransmitterMatcher>{};
    for (final diverId in diverByTank.values.toSet()) {
      final entries = await getForDiver(diverId);
      matchers[diverId] = TransmitterMatcher.fromEntries([
        for (final e in entries)
          if (e.diverId == diverId) e,
      ]);
    }

    final tankIds = diverByTank.keys.toList();
    final pairs = <(DiveTank, Transmitter)>[];
    for (var i = 0; i < tankIds.length; i += 500) {
      final chunk = tankIds.sublist(i, (i + 500).clamp(0, tankIds.length));
      final rows =
          await (_db.select(_db.diveTanks)
                ..where((d) => d.id.isIn(chunk))
                ..orderBy([
                  (d) => OrderingTerm.asc(d.diveId),
                  (d) => OrderingTerm.asc(d.tankOrder),
                ]))
              .get();
      for (final row in rows) {
        final entry = matchers[diverByTank[row.id]]?.match(
          serial: row.transmitterSerial,
          computerId: null,
          index: row.tankOrder,
        );
        if (entry != null) pairs.add((row, entry));
      }
    }
    return _filler.fill(pairs);
  }

  Future<List<DiveTank>> _tanksForEntry(Transmitter t) async {
    // Canonical on both sides: an entry can arrive unnormalized through a
    // sync payload even though local writes normalize on the way in.
    final wanted = normalizeTransmitterSerial(t.transmitterSerial);
    if (wanted != null) {
      final rows = await (_db.select(
        _db.diveTanks,
      )..where((d) => d.transmitterSerial.isNotNull())).get();
      return rows
          .where(
            (r) => normalizeTransmitterSerial(r.transmitterSerial) == wanted,
          )
          .toList();
    }
    if (!t.hasChannel) return const [];
    final rows = await _db
        .customSelect(
          'SELECT dt.id AS id FROM dive_tanks dt '
          'JOIN dives d ON d.id = dt.dive_id '
          'WHERE (dt.computer_id = ? OR d.computer_id = ?) '
          'AND COALESCE(dt.source_tank_index, dt.tank_order) = ?',
          variables: [
            Variable<String>(t.diveComputerId),
            Variable<String>(t.diveComputerId),
            Variable<int>(t.channelIndex),
          ],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final ids = rows.map((r) => r.read<String>('id')).toList();
    if (ids.isEmpty) return const [];
    return (_db.select(_db.diveTanks)..where((d) => d.id.isIn(ids))).get();
  }

  Transmitter _normalized(Transmitter t) {
    final serial = normalizeTransmitterSerial(t.transmitterSerial);
    final channelComplete = t.diveComputerId != null && t.channelIndex != null;
    if (serial == null && !channelComplete) {
      throw ArgumentError(
        'A transmitter needs a serial or a dive computer plus channel index',
      );
    }
    return t.copyWith(
      transmitterSerial: serial,
      clearTransmitterSerial: serial == null,
      label: t.label.trim(),
    );
  }

  /// Inserts [t] and stages it, without the checks or notifications, so a
  /// caller can hold it in a transaction.
  Future<void> _insertRow(Transmitter t, int now) async {
    await _db
        .into(_db.transmitters)
        .insert(_companion(t, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: t.id,
      localUpdatedAt: now,
    );
  }

  /// Writes [t] over its stored row and stages it, as [_insertRow] does.
  Future<void> _writeRow(Transmitter t, int now) async {
    await (_db.update(
      _db.transmitters,
    )..where((r) => r.id.equals(t.id))).write(_companion(t, now: now));
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: t.id,
      localUpdatedAt: now,
    );
  }

  /// Deletes row [id] and tombstones it, as [_insertRow] does.
  Future<void> _deleteRow(String id) async {
    await (_db.delete(_db.transmitters)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _entity, recordId: id);
  }

  Future<void> _checkConflicts(Transmitter t, {String? ignoring}) async {
    final siblings = await getForDiver(t.diverId);
    final serial = normalizeTransmitterSerial(t.transmitterSerial);
    for (final other in siblings) {
      if (other.id == t.id || other.id == ignoring) continue;
      // The sibling may have been stored raw by a sync payload, so compare
      // canonical forms rather than trusting write-time normalization.
      final serialClash =
          serial != null &&
          normalizeTransmitterSerial(other.transmitterSerial) == serial;
      final channelClash =
          t.hasChannel &&
          other.diveComputerId == t.diveComputerId &&
          other.channelIndex == t.channelIndex;
      if (serialClash || channelClash) {
        throw TransmitterConflictException(other);
      }
    }
  }

  TransmittersCompanion _companion(
    Transmitter t, {
    required int now,
    int? createdAt,
  }) => TransmittersCompanion(
    id: Value(t.id),
    diverId: Value(t.diverId),
    transmitterSerial: Value(t.transmitterSerial),
    diveComputerId: Value(t.diveComputerId),
    channelIndex: Value(t.channelIndex),
    label: Value(t.label),
    tankRole: Value(t.role.name),
    volumeL: Value(t.volumeL),
    workingPressureBar: Value(t.workingPressureBar),
    tankMaterial: Value(t.material?.name),
    presetName: Value(t.presetName),
    equipmentId: Value(t.equipmentId),
    transmitterEquipmentId: Value(t.transmitterEquipmentId),
    isConfigured: Value(t.isConfigured),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    updatedAt: Value(now),
  );

  Transmitter _map(TransmitterRow r) => Transmitter(
    id: r.id,
    diverId: r.diverId,
    transmitterSerial: r.transmitterSerial,
    diveComputerId: r.diveComputerId,
    channelIndex: r.channelIndex,
    label: r.label,
    role: TankRole.values.firstWhere(
      (e) => e.name == r.tankRole,
      orElse: () => TankRole.backGas,
    ),
    volumeL: r.volumeL,
    workingPressureBar: r.workingPressureBar,
    material: r.tankMaterial == null
        ? null
        : TankMaterial.values.firstWhere(
            (e) => e.name == r.tankMaterial,
            orElse: () => TankMaterial.aluminum,
          ),
    presetName: r.presetName,
    equipmentId: r.equipmentId,
    transmitterEquipmentId: r.transmitterEquipmentId,
    isConfigured: r.isConfigured,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
