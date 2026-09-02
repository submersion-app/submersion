import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Attaches the gear twins of the dive computers that logged a dive (v175).
///
/// Used by the non-interactive creation seams (dive-computer download, file
/// import), alongside `DiveEquipmentDefaulter`, `ChecklistDiveLinker` and
/// `DiveAltitudeEnricher`.
///
/// Link-only: it never creates an equipment row. Creation happens once, at
/// computer registration, so a twin the user deleted (which clears
/// `dive_computers.equipment_id`) simply produces no link and stays deleted.
class DiveComputerGearLinker {
  DiveComputerGearLinker({DiveRepository? diveRepository})
    : _dives = diveRepository ?? DiveRepository();

  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when at least one twin was attached.
  ///
  /// MUST run after `DiveEquipmentDefaulter` at every seam: the defaulter bails
  /// when the dive already has any `dive_equipment` row, so linking first would
  /// silently suppress the diver's default and geofenced equipment sets.
  ///
  /// Unlike the defaulter this is NOT gated on the dive being empty: the
  /// computer belongs on the dive whether or not a set already applied.
  ///
  /// Best-effort: any failure is swallowed so equipment linking can never abort
  /// a download or import that has already persisted the dive.
  Future<bool> linkComputerGearForDive({required String diveId}) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final computerIds = await _computerIdsForDive(diveId);
      if (computerIds.isEmpty) return false;

      final rows = await (_db.select(
        _db.diveComputers,
      )..where((t) => t.id.isIn(computerIds))).get();
      final equipmentIds = rows
          .map((r) => r.equipmentId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (equipmentIds.isEmpty) return false;

      await _dives.bulkAddEquipment([diveId], equipmentIds);
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (_) {
      // Best-effort: never let gear linking fail the dive operation.
      return false;
    }
  }

  /// Every computer that logged [diveId].
  ///
  /// Deliberately NOT `DiveComputerRepository.getComputerIdsForDive`, which
  /// reads `dive_profile_series` and so sees only dives that carry samples.
  /// A file-imported dive registered by #1288 can have `computer_id` stamped
  /// and a data-source row while having no samples at all, and its computer
  /// belongs on it just the same.
  ///
  /// `dives.computer_id` alone is not enough either: it holds only the primary,
  /// so a dive logged on two computers would list one. This is the same union
  /// the v175 backfill applies, so the migration and the runtime path agree.
  Future<List<String>> _computerIdsForDive(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT computer_id FROM ('
          '  SELECT computer_id FROM dive_data_sources '
          '   WHERE dive_id = ? AND computer_id IS NOT NULL'
          '  UNION'
          '  SELECT computer_id FROM dives '
          '   WHERE id = ? AND computer_id IS NOT NULL'
          ')',
          variables: [Variable<String>(diveId), Variable<String>(diveId)],
        )
        .get();
    return rows
        .map((row) => row.read<String?>('computer_id'))
        .whereType<String>()
        .toList();
  }
}
