import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/data/services/bailout_mix_fixer.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Thrown when an entry would share a serial (per diver) or a
/// (computer, channel) key with [existing].
class TransmitterConflictException implements Exception {
  final Transmitter existing;
  const TransmitterConflictException(this.existing);

  @override
  String toString() =>
      'TransmitterConflictException: conflicts with ${existing.label}';
}

/// A serial seen on downloaded tanks that has no registry entry.
typedef UnassignedTransmitterSerial = ({String serial, int diveCount});

/// Outcome of [TransmitterRepository.applyToExistingDives].
/// [mixesKept]: dives where a bailout entry changed the role but found no
/// bailout mix to give the tank, so it kept the one it had (issue #3307).
typedef ApplyToExistingResult = ({
  int tanksUpdated,
  int divesUpdated,
  int mixesKept,
});

class TransmitterRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

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
    await _db
        .into(_db.transmitters)
        .insert(_companion(normalized, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: normalized.id,
      localUpdatedAt: now,
    );
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

  Future<void> update(Transmitter t) async {
    final normalized = _normalized(t);
    await _checkConflicts(normalized);
    // The dives the entry matched before the edit lose its findings (or
    // gain an unknown-transmitter one) when its key changes, so they are
    // rescanned along with the dives it matches now.
    final previous = await getById(normalized.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.transmitters)
          ..where((r) => r.id.equals(normalized.id)))
        .write(_companion(normalized, now: now));
    await _syncRepository.markRecordPending(
      entityType: _entity,
      recordId: normalized.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    await _rescanAffectedDives([normalized, ?previous]);
  }

  Future<void> delete(String id) async {
    // Read before the row goes: its dives are rescanned by its key.
    final previous = await getById(id);
    await (_db.delete(_db.transmitters)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _entity, recordId: id);
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

  /// Distinct normalized serials on the diver's downloaded tanks with no
  /// registry entry, with how many dives each appears on. Rows whose serial
  /// normalizes to null (blank, all zeros) are skipped.
  Future<List<UnassignedTransmitterSerial>> getUnassignedSerials(
    String? diverId,
  ) async {
    final known = Transmitter.knownSerials(await getForDiver(diverId));
    final rows = await _db
        .customSelect(
          'SELECT dt.transmitter_serial AS serial, dt.dive_id AS dive_id '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL '
          'AND (? IS NULL OR d.diver_id = ?)',
          variables: [Variable<String>(diverId), Variable<String>(diverId)],
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    final divesBySerial = <String, Set<String>>{};
    for (final row in rows) {
      final serial = normalizeTransmitterSerial(row.read<String>('serial'));
      if (serial == null || known.contains(serial)) continue;
      divesBySerial
          .putIfAbsent(serial, () => {})
          .add(row.read<String>('dive_id'));
    }
    final out = [
      for (final e in divesBySerial.entries)
        (serial: e.key, diveCount: e.value.length),
    ]..sort((a, b) => a.serial.compareTo(b.serial));
    return out;
  }

  /// How many distinct serials seen on [computerId]'s dives have an entry,
  /// and how many do not.
  Future<({int known, int unassigned})> serialCountsForComputer(
    String computerId, {
    String? diverId,
  }) async {
    final knownSerials = Transmitter.knownSerials(await getForDiver(diverId));
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

  /// Retroactive fill for the tanks that carry [t]'s key: empty size,
  /// working pressure, material, preset, gear link and name are filled; the
  /// role is replaced while it is still the uninformed backGas default, and
  /// always while it is the computer's guess from the transmitter's name
  /// (issue #2595), which also drops that source: the entry is the diver's
  /// own configuration. A role the diver set is never replaced.
  /// One transaction; a failure leaves no half-applied dive.
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter t) async {
    final candidates = await _tanksForEntry(t);
    if (candidates.isEmpty) {
      return (tanksUpdated: 0, divesUpdated: 0, mixesKept: 0);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final touchedDives = <String>{};
    var tanks = 0;
    final mixesKeptDives = <String>{};
    final mixFixer = BailoutMixFixer();
    await _db.transaction(() async {
      for (final row in candidates) {
        final hasVolume = row.volume != null && row.volume! > 0;
        final nameDerived =
            TankRoleSource.fromName(row.roleSource) ==
            TankRoleSource.transmitterName;
        // An open-circuit entry (bailout, deco, stage) also replaces the
        // importer's 100% O2 default with that gas's own mix, before the role
        // write below (#3307).
        if (nameDerived && !isLoopTankRole(t.role.name)) {
          if (!await mixFixer.fix(row)) mixesKeptDives.add(row.diveId);
        }
        final companion = DiveTanksCompanion(
          volume: !hasVolume && t.volumeL != null
              ? Value(t.volumeL)
              : const Value.absent(),
          workingPressure:
              row.workingPressure == null && t.workingPressureBar != null
              ? Value(t.workingPressureBar)
              : const Value.absent(),
          tankMaterial: row.tankMaterial == null && t.material != null
              ? Value(t.material!.name)
              : const Value.absent(),
          presetName: row.presetName == null && t.presetName != null
              ? Value(t.presetName)
              : const Value.absent(),
          equipmentId: row.equipmentId == null && t.equipmentId != null
              ? Value(t.equipmentId)
              : const Value.absent(),
          tankName:
              (row.tankName == null || row.tankName!.isEmpty) &&
                  t.label.isNotEmpty
              ? Value(t.label)
              : const Value.absent(),
          tankRole:
              nameDerived ||
                  (row.tankRole == TankRole.backGas.name &&
                      t.role != TankRole.backGas)
              ? Value(t.role.name)
              : const Value.absent(),
          roleSource: nameDerived ? const Value(null) : const Value.absent(),
        );
        // Every field absent means nothing to write for this row.
        if (companion == const DiveTanksCompanion()) continue;
        await (_db.update(
          _db.diveTanks,
        )..where((d) => d.id.equals(row.id))).write(companion);
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: row.id,
          localUpdatedAt: now,
        );
        touchedDives.add(row.diveId);
        tanks++;
      }
    });
    if (tanks > 0) {
      SyncEventBus.notifyLocalChange();
      // The scan create/update queued ran on the roles before this apply,
      // so a finding about a role it just fixed would stay open (#3307).
      scheduleQualityScan(touchedDives);
    }
    return (
      tanksUpdated: tanks,
      divesUpdated: touchedDives.length,
      mixesKept: mixesKeptDives.length,
    );
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

  Future<void> _checkConflicts(Transmitter t) async {
    final siblings = await getForDiver(t.diverId);
    final serial = normalizeTransmitterSerial(t.transmitterSerial);
    for (final other in siblings) {
      if (other.id == t.id) continue;
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
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
