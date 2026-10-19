import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_role_repair_repository.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';

/// Makes a name-derived transmitter tank the bailout on one past dive and
/// gives it the bailout's mix (issue #3307), so a registry entry saying
/// "this transmitter is my bailout" leaves no dive on the 100% default.
///
/// The mix comes from the open-circuit cylinder the timeline says the tank
/// was breathed as; otherwise from the dive's single pressureless bailout
/// cylinder. Either is merged in when still as imported. Returns false when
/// neither exists: the caller changes the role alone and counts the dive.
///
/// No surfacing clip here: the diver has already said the tank is the
/// bailout, so the timeline only picks which cylinder it was breathed as.
class BailoutMixFixer {
  BailoutMixFixer({AppDatabase? database})
    : _database = database,
      _repair = TankRoleRepairRepository(database: database),
      _pressures = TankPressureRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final TankRoleRepairRepository _repair;
  final TankPressureRepository _pressures;

  Future<bool> fix(DiveTank row) async {
    // Only this transmitter's own computer: a second computer on the dive
    // logs its own switches and its own gas-list cylinders.
    bool sameComputer(String? computerId) =>
        row.computerId == null ||
        computerId == null ||
        computerId == row.computerId;
    final tanks = [
      for (final t in await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(row.diveId))).get())
        if (t.id == row.id || sameComputer(t.computerId)) t,
    ];
    final switches = [
      for (final s in await (_db.select(
        _db.gasSwitches,
      )..where((s) => s.diveId.equals(row.diveId))).get())
        if (sameComputer(s.computerId)) s,
    ];
    final series = await _pressures.getTankPressuresForComputer(
      row.diveId,
      row.computerId,
    );

    final roleById = {for (final t in tanks) t.id: t.tankRole};
    final evidence = bailoutEvidence<String>(
      switches: [for (final s in switches) (t: s.timestamp, tankKey: s.tankId)],
      isLoopTank: (id) => isLoopTankRole(roleById[id]),
      pressures: {
        if (series[row.id] != null)
          row.id: [
            for (final p in series[row.id]!) (t: p.timestamp, bar: p.pressure),
          ],
      },
      candidates: [row.id],
      inWaterEndSeconds: null,
    );

    final target =
        evidence?.firstOrNull?.ocTankKey ?? _singleBailout(tanks, row, series);
    if (target == null) return false;
    final result = await _repair.useAsBailout(
      diveId: row.diveId,
      tankId: row.id,
      ocTankId: target,
    );
    return result != null;
  }

  static String? _singleBailout(
    List<DiveTank> tanks,
    DiveTank row,
    Map<String, List<Object?>> series,
  ) {
    final bailouts = [
      for (final t in tanks)
        if (t.id != row.id &&
            t.tankRole == TankRole.bailout.name &&
            t.transmitterSerial == null &&
            series[t.id] == null)
          t.id,
    ];
    return bailouts.length == 1 ? bailouts.single : null;
  }
}
