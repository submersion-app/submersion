/// Where a CCR dive's gas went: how much of each cylinder left it on the loop,
/// how much after a bailout, and how fast O2 and diluent were used (issue
/// #4082).
///
/// A loop gas is not breathed at depth the way an open-circuit gas is: O2 use
/// is metabolic and diluent use follows volume changes, so neither scales with
/// ambient pressure. A loop rate is plain surface litres per minute of loop
/// time, with no depth correction. The Cylinders card and the gas statistics
/// both read this, so one dive cannot show two figures.
library;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_gas_schedule.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// Smallest loop drop, in bar, that counts on a cylinder not marked as loop
/// gas. A cylinder filled warm loses pressure as it cools: an 11 L bailout
/// loses about 13 bar in 5 C water without being touched, which over an hour
/// would read as 2.5 L/min.
const double kMinUnmarkedLoopDropBar = 20.0;

/// One cylinder of a CCR dive.
class CcrCylinderUse {
  const CcrCylinderUse({
    required this.tankId,
    this.loopLiters = 0,
    this.loopRate,
    this.bailoutStartBar,
    this.bailoutEndBar,
    this.bailoutWindows = const [],
  });

  final String tankId;

  /// Surface litres lost on the loop; 0 when none.
  final double loopLiters;

  /// [loopLiters] per minute of the dive's loop time, in L/min. Null when
  /// there is no loop gas or no loop time.
  final double? loopRate;

  /// The pressures bounding the gas lost after a bailout, in bar: the first
  /// reading, and that less the whole drop. Null when there is none.
  final double? bailoutStartBar;
  final double? bailoutEndBar;

  /// When this cylinder was breathed on bailout.
  final List<TankUsageWindow> bailoutWindows;
}

/// A CCR dive's cylinders, and the rates its statistics plot.
class CcrDiveUse {
  const CcrDiveUse({
    required this.cylinders,
    required this.loopSeconds,
    this.o2Rate,
    this.diluentRate,
  });

  final List<CcrCylinderUse> cylinders;

  /// The dive's time on the loop, in seconds.
  final int loopSeconds;

  /// Loop gas of the oxygen cylinders per minute of loop time, in L/min.
  final double? o2Rate;

  /// Loop gas of every other cylinder per minute of loop time, in L/min: past
  /// the minimum drop, anything else leaving a cylinder on the loop went into
  /// the loop, whatever role the cylinder was logged with.
  final double? diluentRate;
}

/// A fall in a cylinder's pressure over one stretch of the dive.
typedef _Drop = ({double from, double to});

/// Works out [CcrDiveUse] for a dive of [tanks] ending at [diveEnd] seconds.
///
/// Loop time and bailout time come from [classifyCcrGasChanges], so this
/// agrees with the profile and the decompression schedule about when the diver
/// was bailed out, and inherits its reading of a switch: only a cylinder
/// marked Diluent means the loop. A bailout onto one reads as staying on the
/// loop, and a return onto any other reads as more bailout.
///
/// [tankPressures] splits a cylinder between the two. Without a usable series
/// a cylinder gets one figure: bailout gas if the diver bailed onto it, unless
/// it is marked as loop gas, otherwise loop gas.
CcrDiveUse ccrDiveUse({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank>? gasSwitches,
  required Map<String, List<TankPressurePoint>>? tankPressures,
  required int diveEnd,
  required GasModel gasModel,
}) {
  // Dropped before classifying: a switch at the first sample names the
  // starting gas, and a dive does not begin bailed out.
  final switches = [
    for (final sw in knownGasSwitches(tanks, gasSwitches, before: diveEnd))
      if (sw.gasSwitch.timestamp > startingSwitchGraceSeconds) sw,
  ];
  final bailouts = _bailoutPeriods(switches, tanks, diveEnd);
  final loops = _loopPeriods(bailouts, diveEnd);
  final loopSeconds = loops.breathedSeconds;
  final series = resolveTankPressureSeries(tanks, tankPressures);

  final cylinders = [
    for (final tank in tanks)
      _cylinderUse(
        tank: tank,
        tanks: tanks,
        switches: switches,
        series: series[tank.id],
        bailouts: bailouts,
        loops: loops,
        loopSeconds: loopSeconds,
        diveEnd: diveEnd,
        gasModel: gasModel,
      ),
  ];

  double? rateOf(bool Function(DiveTank tank) included) {
    var liters = 0.0;
    for (var i = 0; i < tanks.length; i++) {
      if (included(tanks[i])) liters += cylinders[i].loopLiters;
    }
    return _perMinute(liters, loopSeconds);
  }

  return CcrDiveUse(
    cylinders: cylinders,
    loopSeconds: loopSeconds,
    o2Rate: rateOf(_holdsOxygen),
    diluentRate: rateOf((tank) => !_holdsOxygen(tank)),
  );
}

List<TankUsageWindow> _bailoutPeriods(
  List<GasSwitchWithTank> switches,
  List<DiveTank> tanks,
  int diveEnd,
) {
  final periods = <TankUsageWindow>[];
  int? start;
  for (final change in classifyCcrGasChanges(switches, tanks)) {
    if (change.kind == CcrGasChangeKind.openCircuit) {
      start ??= change.timestamp;
    } else if (start != null) {
      periods.add((start: start, end: change.timestamp));
      start = null;
    }
  }
  if (start != null) periods.add((start: start, end: diveEnd));
  return periods;
}

/// The dive from 0 to [diveEnd] less [bailouts].
List<TankUsageWindow> _loopPeriods(
  List<TankUsageWindow> bailouts,
  int diveEnd,
) {
  if (diveEnd <= 0) return const [];
  final periods = <TankUsageWindow>[];
  var start = 0;
  for (final bailout in bailouts) {
    if (bailout.start > start) {
      periods.add((start: start, end: bailout.start));
    }
    start = bailout.end;
  }
  if (diveEnd > start) periods.add((start: start, end: diveEnd));
  return periods;
}

CcrCylinderUse _cylinderUse({
  required DiveTank tank,
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> switches,
  required List<TankPressurePoint>? series,
  required List<TankUsageWindow> bailouts,
  required List<TankUsageWindow> loops,
  required int loopSeconds,
  required int diveEnd,
  required GasModel gasModel,
}) {
  final bailoutWindows = [
    for (final period in bailouts)
      ...tankUsageWindows(
        tank: tank,
        gasSwitches: switches,
        diveStart: 0,
        diveEnd: diveEnd,
        tanks: tanks,
      ).within(period.start, period.end),
  ];

  var loopDrops = const <_Drop>[];
  var bailoutDrops = const <_Drop>[];
  final usable = _usableSeries(series, diveEnd);
  if (usable != null) {
    loopDrops = _dropsAcross(usable, loops);
    // A cylinder not breathed on bailout has no bailout figure to carry.
    if (bailoutWindows.isNotEmpty) {
      bailoutDrops = _dropsAcross(usable, bailouts);
    }
  } else {
    final (start, end) = resolvedTankPressures(tank, series);
    if (start != null && end != null && end < start) {
      final whole = [(from: start, to: end)];
      if (bailoutWindows.isEmpty || _isMarkedLoopGas(tank)) {
        loopDrops = whole;
      } else {
        bailoutDrops = whole;
      }
    }
  }

  final loopBar = _totalBar(loopDrops);
  if (!_isMarkedLoopGas(tank) && loopBar <= kMinUnmarkedLoopDropBar) {
    loopDrops = const [];
  }

  final volume = consumptionVolume(tank, tanks);
  var loopLiters = 0.0;
  if (volume != null) {
    for (final drop in loopDrops) {
      loopLiters +=
          _gasVolumeAt(tank, volume, drop.from, gasModel) -
          _gasVolumeAt(tank, volume, drop.to, gasModel);
    }
  }

  final bailoutBar = _totalBar(bailoutDrops);
  final bailoutStart = bailoutDrops.isEmpty ? null : bailoutDrops.first.from;
  return CcrCylinderUse(
    tankId: tank.id,
    loopLiters: loopLiters,
    loopRate: _perMinute(loopLiters, loopSeconds),
    bailoutStartBar: bailoutStart,
    bailoutEndBar: bailoutStart == null ? null : bailoutStart - bailoutBar,
    bailoutWindows: bailoutWindows,
  );
}

/// [series] without transmitter dropouts, or null when it shows no fall over
/// the dive: a flat or lost transmitter says nothing (issue #3373).
List<TankPressurePoint>? _usableSeries(
  List<TankPressurePoint>? series,
  int diveEnd,
) {
  if (series == null || diveEnd <= 0) return null;
  final tankId = series.isEmpty ? '' : series.first.tankId;
  final cleaned = [
    for (final sample in withoutDropouts([
      for (final p in series) (t: p.timestamp, bar: p.pressure),
    ]))
      TankPressurePoint(
        tankId: tankId,
        timestamp: sample.t,
        pressure: sample.bar,
      ),
  ];
  if (cleaned.length < 2) return null;
  final first = pressureAtTime(cleaned, 0)!;
  final last = pressureAtTime(cleaned, diveEnd)!;
  return last < first ? cleaned : null;
}

/// The fall across each of [periods]. A period whose pressure rose lost
/// nothing, so it adds none.
List<_Drop> _dropsAcross(
  List<TankPressurePoint> series,
  List<TankUsageWindow> periods,
) {
  final drops = <_Drop>[];
  for (final period in periods) {
    final from = pressureAtTime(series, period.start)!;
    final to = pressureAtTime(series, period.end)!;
    if (to < from) drops.add((from: from, to: to));
  }
  return drops;
}

double _totalBar(List<_Drop> drops) =>
    drops.fold(0.0, (total, drop) => total + drop.from - drop.to);

double _gasVolumeAt(
  DiveTank tank,
  double volume,
  double pressureBar,
  GasModel model,
) => gasVolume(
  tankSizeLiters: volume,
  pressureBar: pressureBar,
  o2Percent: tank.gasMix.o2,
  hePercent: tank.gasMix.he,
  model: model,
);

double? _perMinute(double liters, int seconds) =>
    liters > 0 && seconds > 0 ? liters / (seconds / 60) : null;

bool _isMarkedLoopGas(DiveTank tank) =>
    isLoopTankRole(ccrCylinderRole(tank).name);

bool _holdsOxygen(DiveTank tank) =>
    ccrCylinderRole(tank) == TankRole.oxygenSupply || tank.gasMix.o2 >= 99.0;
