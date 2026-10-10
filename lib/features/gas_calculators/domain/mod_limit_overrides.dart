import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';

/// The water type a Tec calculator uses when the diver has not chosen one:
/// [stored] if set, else the planner's own default, with a custom salinity
/// mapping to salt (the sea water it defaults to).
///
/// Shared by the MOD calculator and the Best Mix calculator so the fallback
/// rule cannot drift between the two.
WaterType resolveWaterType(
  WaterType? stored,
  PlannerWaterType plannerDefault,
) =>
    stored ??
    switch (plannerDefault) {
      PlannerWaterType.fresh => WaterType.fresh,
      PlannerWaterType.salt || PlannerWaterType.custom => WaterType.salt,
    };

/// The range the END limit override offers, matching the settings page's
/// own END limit dialog (`settings_page.dart`).
const double endLimitOverrideMinMeters = 20;
const double endLimitOverrideMaxMeters = 50;

/// The ppO2 limits of the active diver's profile, as the MOD calculator
/// reads them (issue #2342): the OC limits for Rec and OC Tec, the CCR
/// limits for CCR Tec. [endLimitMeters] and [o2Narcotic] are the diver's
/// narcosis settings, shared by both calculators the same way the ppO2
/// limits are.
class ModProfileLimits {
  final double workingPpO2;
  final double decoPpO2;
  final double flushPpO2;
  final double setpointBar;
  final double endLimitMeters;
  final bool o2Narcotic;

  const ModProfileLimits({
    required this.workingPpO2,
    required this.decoPpO2,
    required this.flushPpO2,
    required this.setpointBar,
    required this.endLimitMeters,
    required this.o2Narcotic,
  });
}

/// One diver's calculator overrides of their profile's ppO2 limits.
///
/// Null follows the profile. An override is kept per diver, so moving a
/// limit for one diver never carries over to another's profile.
class ModLimitOverrides extends Equatable {
  final double? workingPpO2;
  final double? decoPpO2;
  final double? flushPpO2;

  /// CCR setpoint; null follows the profile's high setpoint.
  final double? setpointBar;

  /// Null follows the profile's END limit / O2-narcotic setting.
  final double? endLimitMeters;
  final bool? o2Narcotic;

  const ModLimitOverrides({
    this.workingPpO2,
    this.decoPpO2,
    this.flushPpO2,
    this.setpointBar,
    this.endLimitMeters,
    this.o2Narcotic,
  });

  static const none = ModLimitOverrides();

  bool get isEmpty =>
      workingPpO2 == null &&
      decoPpO2 == null &&
      flushPpO2 == null &&
      setpointBar == null &&
      endLimitMeters == null &&
      o2Narcotic == null;

  /// The working and deco limits set together, each stored as "follow the
  /// profile" when it equals the profile value, so the calculator follows
  /// later profile changes again.
  ModLimitOverrides withLimits({
    required double workingPpO2,
    required double decoPpO2,
    required ModProfileLimits profile,
  }) => ModLimitOverrides(
    workingPpO2: _unlessProfile(workingPpO2, profile.workingPpO2),
    decoPpO2: _unlessProfile(decoPpO2, profile.decoPpO2),
    flushPpO2: flushPpO2,
    setpointBar: setpointBar,
    endLimitMeters: endLimitMeters,
    o2Narcotic: o2Narcotic,
  );

  ModLimitOverrides withFlushPpO2(double? value, ModProfileLimits profile) =>
      ModLimitOverrides(
        workingPpO2: workingPpO2,
        decoPpO2: decoPpO2,
        flushPpO2: value == null
            ? null
            : _unlessProfile(value, profile.flushPpO2),
        setpointBar: setpointBar,
        endLimitMeters: endLimitMeters,
        o2Narcotic: o2Narcotic,
      );

  ModLimitOverrides withSetpoint(double? value, ModProfileLimits profile) =>
      ModLimitOverrides(
        workingPpO2: workingPpO2,
        decoPpO2: decoPpO2,
        flushPpO2: flushPpO2,
        setpointBar: value == null
            ? null
            : _unlessProfile(value, profile.setpointBar),
        endLimitMeters: endLimitMeters,
        o2Narcotic: o2Narcotic,
      );

  ModLimitOverrides withEndLimit(double? value, ModProfileLimits profile) =>
      ModLimitOverrides(
        workingPpO2: workingPpO2,
        decoPpO2: decoPpO2,
        flushPpO2: flushPpO2,
        setpointBar: setpointBar,
        endLimitMeters: value == null
            ? null
            : _unlessProfile(value, profile.endLimitMeters),
        o2Narcotic: o2Narcotic,
      );

  ModLimitOverrides withO2Narcotic(bool? value, ModProfileLimits profile) =>
      ModLimitOverrides(
        workingPpO2: workingPpO2,
        decoPpO2: decoPpO2,
        flushPpO2: flushPpO2,
        setpointBar: setpointBar,
        endLimitMeters: endLimitMeters,
        o2Narcotic: value == profile.o2Narcotic ? null : value,
      );

  Map<String, dynamic> toJson() => {
    'workingPpO2': workingPpO2,
    'decoPpO2': decoPpO2,
    'flushPpO2': flushPpO2,
    'setpointBar': setpointBar,
    'endLimitMeters': endLimitMeters,
    'o2Narcotic': o2Narcotic,
  };

  /// Each override is put back on its slider's grid, so a value saved on an
  /// older grid (a 1.45 flush ppO2) cannot sit between two stops.
  static ModLimitOverrides fromJson(Object? json) {
    if (json is! Map) return none;
    final o2Narcotic = json['o2Narcotic'];
    return ModLimitOverrides(
      workingPpO2: modSnapToGrid(_limit(json['workingPpO2']), 0.05),
      decoPpO2: modSnapToGrid(_limit(json['decoPpO2']), 0.05),
      flushPpO2: modSnapToGrid(
        modNumberInRange(json['flushPpO2'], modFlushPpO2Min, modFlushPpO2Max),
        0.1,
      ),
      setpointBar: modSnapToGrid(
        modNumberInRange(
          json['setpointBar'],
          modSetpointMinBar,
          modSetpointMaxBar,
        ),
        0.1,
      ),
      endLimitMeters: modNumberInRange(
        json['endLimitMeters'],
        endLimitOverrideMinMeters,
        endLimitOverrideMaxMeters,
      ),
      o2Narcotic: o2Narcotic is bool ? o2Narcotic : null,
    );
  }

  @override
  List<Object?> get props => [
    workingPpO2,
    decoPpO2,
    flushPpO2,
    setpointBar,
    endLimitMeters,
    o2Narcotic,
  ];
}

/// The limits in effect, and whether each differs from the profile.
class ModResolvedLimits {
  final double workingPpO2;
  final double decoPpO2;
  final double flushPpO2;
  final double setpointBar;
  final double endLimitMeters;
  final bool o2Narcotic;
  final bool workingOverridden;
  final bool decoOverridden;
  final bool flushOverridden;
  final bool setpointOverridden;
  final bool endLimitOverridden;
  final bool o2NarcoticOverridden;

  const ModResolvedLimits({
    required this.workingPpO2,
    required this.decoPpO2,
    required this.flushPpO2,
    required this.setpointBar,
    required this.endLimitMeters,
    required this.o2Narcotic,
    required this.workingOverridden,
    required this.decoOverridden,
    required this.flushOverridden,
    required this.setpointOverridden,
    required this.endLimitOverridden,
    required this.o2NarcoticOverridden,
  });
}

/// [overrides] resolved against [profile].
///
/// A limit is marked as overridden by its value, not by an override being
/// stored: once the profile moves onto the override, it no longer differs.
/// Deco is held at or above working, the "never inverted" rule the profile
/// keeps, so the deco MOD is never shallower than the working MOD.
ModResolvedLimits resolveModLimits(
  ModLimitOverrides overrides,
  ModProfileLimits profile,
) {
  final working = overrides.workingPpO2 ?? profile.workingPpO2;
  final deco = math.max(overrides.decoPpO2 ?? profile.decoPpO2, working);
  final flush = overrides.flushPpO2 ?? profile.flushPpO2;
  final setpoint = overrides.setpointBar ?? profile.setpointBar;
  final endLimit = overrides.endLimitMeters ?? profile.endLimitMeters;
  final o2Narcotic = overrides.o2Narcotic ?? profile.o2Narcotic;
  return ModResolvedLimits(
    workingPpO2: working,
    decoPpO2: deco,
    flushPpO2: flush,
    setpointBar: setpoint,
    endLimitMeters: endLimit,
    o2Narcotic: o2Narcotic,
    workingOverridden: !modSameValue(working, profile.workingPpO2),
    decoOverridden: !modSameValue(deco, profile.decoPpO2),
    flushOverridden: !modSameValue(flush, profile.flushPpO2),
    setpointOverridden: !modSameValue(setpoint, profile.setpointBar),
    endLimitOverridden: !modSameValue(endLimit, profile.endLimitMeters),
    o2NarcoticOverridden: o2Narcotic != profile.o2Narcotic,
  );
}

bool modSameValue(double a, double b) => (a - b).abs() < 1e-9;

double? _unlessProfile(double value, double profileValue) =>
    modSameValue(value, profileValue) ? null : value;

double? _limit(Object? value) =>
    modNumberInRange(value, modLimitPpO2Min, modLimitPpO2Max);

/// [value] rounded to the nearest multiple of [step]; null stays null.
///
/// Multiplies by the whole number of steps per bar rather than dividing by
/// [step]: 1.45 / 0.1 is 14.4999... in floating point and would round down,
/// 1.45 * 10 is exactly 14.5.
double? modSnapToGrid(double? value, double step) {
  if (value == null) return null;
  final perBar = (1 / step).round();
  return (value * perBar).round() / perBar;
}

/// [value] as a double when it is a finite number within [min]..[max].
double? modNumberInRange(Object? value, double min, double max) {
  if (value is! num) return null;
  final d = value.toDouble();
  if (!d.isFinite || d < min || d > max) return null;
  return d;
}
