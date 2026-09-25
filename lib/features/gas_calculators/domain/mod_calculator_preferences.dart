import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';

/// The two minimum ppO2 values the calculator offers for a hypoxic mix.
const List<double> modMinPpO2Options = [0.16, 0.18];

/// What one mode of the MOD calculator remembers.
class ModModeInputs extends Equatable {
  final double o2Percent;
  final double hePercent;
  final double targetDepthMeters;
  final bool checkTargetDepth;

  const ModModeInputs({
    required this.o2Percent,
    required this.hePercent,
    required this.targetDepthMeters,
    required this.checkTargetDepth,
  });

  ModModeInputs copyWith({
    double? o2Percent,
    double? hePercent,
    double? targetDepthMeters,
    bool? checkTargetDepth,
  }) => ModModeInputs(
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    targetDepthMeters: targetDepthMeters ?? this.targetDepthMeters,
    checkTargetDepth: checkTargetDepth ?? this.checkTargetDepth,
  );

  Map<String, dynamic> toJson() => {
    'o2Percent': o2Percent,
    'hePercent': hePercent,
    'targetDepthMeters': targetDepthMeters,
    'checkTargetDepth': checkTargetDepth,
  };

  static ModModeInputs fromJson(Object? json, ModModeInputs fallback) {
    if (json is! Map) return fallback;
    final o2 = _number(json['o2Percent'], 1, 100) ?? fallback.o2Percent;
    final he = (_number(json['hePercent'], 0, 100) ?? fallback.hePercent)
        .clamp(0.0, 100.0 - o2)
        .toDouble();
    final check = json['checkTargetDepth'];
    return ModModeInputs(
      o2Percent: o2,
      hePercent: he,
      targetDepthMeters:
          _number(json['targetDepthMeters'], 0, tecTargetMaxMeters) ??
          fallback.targetDepthMeters,
      checkTargetDepth: check is bool ? check : fallback.checkTargetDepth,
    );
  }

  @override
  List<Object?> get props => [
    o2Percent,
    hePercent,
    targetDepthMeters,
    checkTargetDepth,
  ];
}

/// Everything the MOD calculator remembers between sessions (issue #2342).
///
/// The ppO2 limits and the CCR setpoint are overrides: null means "use the
/// active diver's profile value" (the OC or the CCR ppO2 limits in the
/// settings), so a diver who never touches them follows their profile, and
/// one who does sees the override marked against it.
class ModCalculatorPreferences extends Equatable {
  final ModCalculatorMode mode;
  final ModModeInputs rec;
  final ModModeInputs ocTec;
  final ModModeInputs ccrTec;

  /// Water type of the Tec modes; null follows the planner's default.
  final WaterType? waterType;

  final double minPpO2;
  final double? workingPpO2;
  final double? decoPpO2;
  final double? flushPpO2;

  /// CCR setpoint; null follows the profile's high setpoint.
  final double? setpointBar;

  const ModCalculatorPreferences({
    required this.mode,
    required this.rec,
    required this.ocTec,
    required this.ccrTec,
    required this.waterType,
    required this.minPpO2,
    required this.workingPpO2,
    required this.decoPpO2,
    required this.flushPpO2,
    required this.setpointBar,
  });

  static const defaults = ModCalculatorPreferences(
    mode: ModCalculatorMode.rec,
    rec: ModModeInputs(
      o2Percent: 32,
      hePercent: 0,
      targetDepthMeters: 30,
      checkTargetDepth: false,
    ),
    ocTec: ModModeInputs(
      o2Percent: 21,
      hePercent: 35,
      targetDepthMeters: 50,
      checkTargetDepth: false,
    ),
    ccrTec: ModModeInputs(
      o2Percent: 21,
      hePercent: 35,
      targetDepthMeters: 50,
      checkTargetDepth: false,
    ),
    waterType: null,
    minPpO2: 0.18,
    workingPpO2: null,
    decoPpO2: null,
    flushPpO2: null,
    setpointBar: null,
  );

  ModModeInputs inputsFor(ModCalculatorMode mode) => switch (mode) {
    ModCalculatorMode.rec => rec,
    ModCalculatorMode.ocTec => ocTec,
    ModCalculatorMode.ccrTec => ccrTec,
  };

  ModCalculatorPreferences withInputs(
    ModCalculatorMode mode,
    ModModeInputs inputs,
  ) => ModCalculatorPreferences(
    mode: this.mode,
    rec: mode == ModCalculatorMode.rec ? inputs : rec,
    ocTec: mode == ModCalculatorMode.ocTec ? inputs : ocTec,
    ccrTec: mode == ModCalculatorMode.ccrTec ? inputs : ccrTec,
    waterType: waterType,
    minPpO2: minPpO2,
    workingPpO2: workingPpO2,
    decoPpO2: decoPpO2,
    flushPpO2: flushPpO2,
    setpointBar: setpointBar,
  );

  /// The `clear*` flags reset an override to "follow the profile", which a
  /// null argument cannot express.
  ModCalculatorPreferences copyWith({
    ModCalculatorMode? mode,
    WaterType? waterType,
    double? minPpO2,
    double? workingPpO2,
    double? decoPpO2,
    double? flushPpO2,
    double? setpointBar,
    bool clearWorkingPpO2 = false,
    bool clearDecoPpO2 = false,
    bool clearFlushPpO2 = false,
    bool clearSetpoint = false,
  }) => ModCalculatorPreferences(
    mode: mode ?? this.mode,
    rec: rec,
    ocTec: ocTec,
    ccrTec: ccrTec,
    waterType: waterType ?? this.waterType,
    minPpO2: minPpO2 ?? this.minPpO2,
    workingPpO2: clearWorkingPpO2 ? null : workingPpO2 ?? this.workingPpO2,
    decoPpO2: clearDecoPpO2 ? null : decoPpO2 ?? this.decoPpO2,
    flushPpO2: clearFlushPpO2 ? null : flushPpO2 ?? this.flushPpO2,
    setpointBar: clearSetpoint ? null : setpointBar ?? this.setpointBar,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'rec': rec.toJson(),
    'ocTec': ocTec.toJson(),
    'ccrTec': ccrTec.toJson(),
    'waterType': waterType?.name,
    'minPpO2': minPpO2,
    'workingPpO2': workingPpO2,
    'decoPpO2': decoPpO2,
    'flushPpO2': flushPpO2,
    'setpointBar': setpointBar,
  };

  static ModCalculatorPreferences fromJson(Map<String, dynamic> json) {
    const d = defaults;
    final minPpO2 = json['minPpO2'];
    return ModCalculatorPreferences(
      mode: _enumByName(ModCalculatorMode.values, json['mode']) ?? d.mode,
      rec: ModModeInputs.fromJson(json['rec'], d.rec),
      ocTec: ModModeInputs.fromJson(json['ocTec'], d.ocTec),
      ccrTec: ModModeInputs.fromJson(json['ccrTec'], d.ccrTec),
      waterType: _enumByName(WaterType.values, json['waterType']),
      minPpO2: minPpO2 is num && modMinPpO2Options.contains(minPpO2.toDouble())
          ? minPpO2.toDouble()
          : d.minPpO2,
      // Each override is put back on its slider's grid, so a value saved on
      // an older grid (a 1.45 flush ppO2) cannot sit between two stops.
      workingPpO2: _onGrid(_limit(json['workingPpO2']), 0.05),
      decoPpO2: _onGrid(_limit(json['decoPpO2']), 0.05),
      flushPpO2: _onGrid(
        _number(json['flushPpO2'], modFlushPpO2Min, modFlushPpO2Max),
        0.1,
      ),
      setpointBar: _onGrid(
        _number(json['setpointBar'], modSetpointMinBar, modSetpointMaxBar),
        0.1,
      ),
    );
  }

  @override
  List<Object?> get props => [
    mode,
    rec,
    ocTec,
    ccrTec,
    waterType,
    minPpO2,
    workingPpO2,
    decoPpO2,
    flushPpO2,
    setpointBar,
  ];
}

double? _limit(Object? value) =>
    _number(value, modLimitPpO2Min, modLimitPpO2Max);

/// [value] rounded to the nearest multiple of [step]; null stays null.
///
/// Multiplies by the whole number of steps per bar rather than dividing by
/// [step]: 1.45 / 0.1 is 14.4999... in floating point and would round down,
/// 1.45 * 10 is exactly 14.5.
double? _onGrid(double? value, double step) {
  if (value == null) return null;
  final perBar = (1 / step).round();
  return (value * perBar).round() / perBar;
}

/// [value] as a double when it is a finite number within [min]..[max].
double? _number(Object? value, double min, double max) {
  if (value is! num) return null;
  final d = value.toDouble();
  if (!d.isFinite || d < min || d > max) return null;
  return d;
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
