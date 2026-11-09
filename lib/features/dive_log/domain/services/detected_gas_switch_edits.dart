import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switches.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// What the switch editor changes to match the cylinder pressures (issue
/// #4335): [retanked] maps a row's id to the cylinder it should name, and
/// [added] are the switches to add as new rows.
typedef GasSwitchEdits = ({
  Map<String, String> retanked,
  List<MissedSwitch> added,
});

/// How many rows [edits] adds or changes.
int gasSwitchEditCount(GasSwitchEdits edits) =>
    edits.retanked.length + edits.added.length;

/// The edits that bring the editor's [switches] in line with what the
/// cylinder pressures [detected] (from [inferredGasSwitches]) show, on a
/// dive with [tanks] whose profile begins at [diveStart].
///
/// The last row by [startingSwitchGraceSeconds] after [diveStart] is the
/// starting gas a computer logs, as the gas timeline reads it. A computer logs a gas, not a cylinder, so when that
/// row names a cylinder carrying the same mix as the one the pressures show
/// the dive began on, it was a guess between them and is re-pointed. A row
/// on another gas is the computer's own word and stays. With such a row, a
/// detected switch at the start is its business and is not added.
///
/// A detected switch is also left out when its cylinder is no longer on the
/// dive, when another row sits on its second (a switch a second), or when a
/// row on the same cylinder lies within [kGasSwitchClaimSeconds] of it: the
/// computer logged that one already.
GasSwitchEdits detectedGasSwitchEdits({
  required List<GasSwitch> switches,
  required List<DiveTank> tanks,
  required MissedSwitches detected,
  required int diveStart,
}) {
  final tankById = {for (final t in tanks) t.id: t};
  final ordered = [...switches]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  // The last row by then, as the timeline reads it (`activeTankAt` takes
  // the latest switch at or before a moment): a 0:00 row overrides one a
  // second computer logged before the start, and a lone pre-start row is
  // still what the dive began on.
  final startRow = ordered
      .where((s) => s.timestamp <= diveStart + startingSwitchGraceSeconds)
      .lastOrNull;

  final retanked = <String, String>{};
  final pressureStart = tankById[detected.startingTankId];
  final rowTank = tankById[startRow?.tankId];
  if (startRow != null &&
      pressureStart != null &&
      rowTank != null &&
      rowTank.id != pressureStart.id &&
      _sameMix(rowTank.gasMix, pressureStart.gasMix)) {
    retanked[startRow.id] = pressureStart.id;
  }

  final rows = [
    for (final s in ordered)
      (tankId: retanked[s.id] ?? s.tankId, t: s.timestamp),
  ];
  final added = <MissedSwitch>[];
  for (final missed in detected.addable) {
    if (!tankById.containsKey(missed.tankId)) continue;
    if (startRow != null &&
        missed.t <= diveStart + startingSwitchGraceSeconds) {
      continue;
    }
    final taken = rows.any(
      (r) =>
          r.t == missed.t ||
          (r.tankId == missed.tankId &&
              (r.t - missed.t).abs() <= kGasSwitchClaimSeconds),
    );
    if (taken) continue;
    added.add(missed);
  }
  return (retanked: retanked, added: added);
}

bool _sameMix(GasMix a, GasMix b) => a.o2 == b.o2 && a.he == b.he;
