import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/repairs/gas_mix_scale_rules.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_gas_mix_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// Divides cylinder mixes older imports stored 100 times too high back to
/// what was meant (issue #4714): UDDF files giving percentages (#4705) and
/// MacDive gas tables (#1493) were read as fractions, so EAN32 was stored
/// as 3200% O2.
///
/// Every write goes through [TankGasMixRepository], under a new clock, so
/// other devices and the cloud copy take the corrected mix too; a schema
/// migration could not stamp one, and a device syncing the logbook later
/// would have pulled the old value back.
class HundredfoldGasMixRepair {
  HundredfoldGasMixRepair({
    TankGasMixRepository? repository,
    AppDatabase? database,
  }) : _database = database,
       _repo = repository ?? TankGasMixRepository(database: database);

  final AppDatabase? _database;
  final TankGasMixRepository _repo;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Divides [tankId]'s mix to [mix], the diver's one-tap repair, while the
  /// stored mix still divides to it: one corrected by hand since the scan,
  /// or edited to another value, is left alone. Returns the mix it replaced,
  /// for undo, or null when it wrote nothing.
  Future<StoredTankMix?> rescale({
    required String diveId,
    required String tankId,
    required GasMix mix,
  }) async {
    final stored = await _repo.tankMix(diveId: diveId, tankId: tankId);
    if (stored == null || hundredfoldCorrection(stored.mix) != mix) {
      return null;
    }
    await _write([(diveId: diveId, tankId: tankId, mix: mix)]);
    return stored;
  }

  /// Writes [prior] back: the undo of [rescale].
  Future<void> restore(StoredTankMix prior) => _write([prior]);

  /// Divides every stored mix that dividing explains, as one automatic
  /// change, and queues a rescan of the dives it changed so the findings
  /// the old values raised retire. Runs on every launch: it costs one query
  /// when there is nothing to do, and puts right a value that arrived since
  /// from a device still on an older version, or a restored backup. A mix
  /// dividing does not explain stays for the impossible gas mix finding.
  /// Returns the dives it changed.
  Future<Set<String>> rescaleAll() async {
    final fixes = [
      for (final stored in await _repo.impossibleMixes())
        if (hundredfoldCorrection(stored.mix) case final mix?)
          (diveId: stored.diveId, tankId: stored.tankId, mix: mix),
    ];
    if (fixes.isEmpty) return const {};
    await ChangeLogScope.automatic(
      _database ?? DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.qualityRepair,
      body: () => _write(fixes),
    );
    final changed = {for (final fix in fixes) fix.diveId};
    scheduleQualityScan(changed);
    return changed;
  }

  Future<void> _write(List<StoredTankMix> mixes) async {
    await _db.transaction(() => _repo.setGasMixes(mixes));
    SyncEventBus.notifyLocalChange();
  }
}
