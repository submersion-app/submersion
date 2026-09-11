import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
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
typedef ApplyToExistingResult = ({int tanksUpdated, int divesUpdated});

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
      ..orderBy([(t) => OrderingTerm.asc(t.label)]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  Future<Transmitter?> getById(String id) async {
    final row = await (_db.select(
      _db.transmitters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
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
    await _rescanAffectedDives(normalized);
    return normalized.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// An unknown-transmitter finding clears itself on the next scan of its
  /// dive, so queue one for the dives that carry this entry's key.
  Future<void> _rescanAffectedDives(Transmitter t) async {
    final affected = (await _tanksForEntry(t)).map((r) => r.diveId).toSet();
    if (affected.isNotEmpty) scheduleQualityScan(affected);
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
    await _rescanAffectedDives(normalized);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.transmitters)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _entity, recordId: id);
    SyncEventBus.notifyLocalChange();
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
    );
  }

  /// Retroactive fill for the tanks that carry [t]'s key: empty size,
  /// working pressure, material, preset, gear link and name are filled; the
  /// role is replaced only while it is still the uninformed backGas default.
  /// One transaction; a failure leaves no half-applied dive.
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter t) async {
    final candidates = await _tanksForEntry(t);
    if (candidates.isEmpty) return (tanksUpdated: 0, divesUpdated: 0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final touchedDives = <String>{};
    var tanks = 0;
    await _db.transaction(() async {
      for (final row in candidates) {
        final hasVolume = row.volume != null && row.volume! > 0;
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
              row.tankRole == TankRole.backGas.name &&
                  t.role != TankRole.backGas
              ? Value(t.role.name)
              : const Value.absent(),
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
    if (tanks > 0) SyncEventBus.notifyLocalChange();
    return (tanksUpdated: tanks, divesUpdated: touchedDives.length);
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
