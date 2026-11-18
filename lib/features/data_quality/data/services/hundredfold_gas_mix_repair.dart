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
  /// or null when it wrote nothing.
  Future<StoredTankMix?> rescale({
    required String diveId,
    required String tankId,
    required GasMix mix,
  }) async {
    // Read and write in one transaction, so an edit landing between the
    // check and the write cannot be overwritten.
    final stored = await _db.transaction(() async {
      final stored = await _repo.tankMix(diveId: diveId, tankId: tankId);
      if (stored == null || hundredfoldCorrection(stored.mix) != mix) {
        return null;
      }
      await _repo.setGasMixes([(diveId: diveId, tankId: tankId, mix: mix)]);
      return stored;
    });
    if (stored != null) SyncEventBus.notifyLocalChange();
    return stored;
  }

  /// Divides every stored mix that dividing explains, as one automatic
  /// change, and queues a rescan of the dives it changed so the findings
  /// the old values raised retire. Runs on every launch: it costs one query
  /// when there is nothing to do, and puts right a value that arrived since
  /// from a device still on an older version, or a restored backup. A mix
  /// dividing does not explain stays for the impossible gas mix finding.
  /// Returns the dives it changed.
  Future<Set<String>> rescaleAll() async {
    // A first look outside the change log, so a launch with nothing to do
    // opens no operation.
    if ((await _fixes()).isEmpty) return const {};
    final changed = await ChangeLogScope.automatic(
      _database ?? DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.qualityRepair,
      body: _write,
    );
    if (changed.isNotEmpty) scheduleQualityScan(changed);
    return changed;
  }

  /// Every stored mix dividing explains, as the mix to write.
  Future<List<StoredTankMix>> _fixes() async => [
    for (final stored in await _repo.impossibleMixes())
      if (hundredfoldCorrection(stored.mix) case final mix?)
        (diveId: stored.diveId, tankId: stored.tankId, mix: mix),
  ];

  /// Reads the mixes again and writes them in one transaction, as [rescale]
  /// does: a sync or an edit landing after the first look must not be
  /// overwritten under a newer clock that every device would then take.
  Future<Set<String>> _write() async {
    final fixes = await _db.transaction(() async {
      final fixes = await _fixes();
      await _repo.setGasMixes(fixes);
      return fixes;
    });
    if (fixes.isEmpty) return const {};
    SyncEventBus.notifyLocalChange();
    return {for (final fix in fixes) fix.diveId};
  }
}
