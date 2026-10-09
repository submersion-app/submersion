import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart'
    show recTargetMaxMeters, tecTargetMaxMeters;
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';

/// Key of the overrides kept while no diver is active, matching
/// `mod_calculator_preferences.dart`'s `modNoDiverKey`.
const String bestMixNoDiverKey = '';

/// What one mode of the Best Mix calculator remembers.
///
/// [recPpO2] is read only by the Rec slot (one of the three ppO2 chips);
/// the Tec slots carry it too so every slot has the same shape, but their
/// ppO2 limit comes from the resolved profile instead.
class BestMixModeInputs extends Equatable {
  final double depthMeters;
  final bool densityAware;
  final double recPpO2;

  const BestMixModeInputs({
    required this.depthMeters,
    required this.densityAware,
    required this.recPpO2,
  });

  BestMixModeInputs copyWith({
    double? depthMeters,
    bool? densityAware,
    double? recPpO2,
  }) => BestMixModeInputs(
    depthMeters: depthMeters ?? this.depthMeters,
    densityAware: densityAware ?? this.densityAware,
    recPpO2: recPpO2 ?? this.recPpO2,
  );

  Map<String, dynamic> toJson() => {
    'depthMeters': depthMeters,
    'densityAware': densityAware,
    'recPpO2': recPpO2,
  };

  /// [maxDepthMeters] is the slot's own depth slider maximum, so a stored
  /// depth the slider cannot show is never computed against.
  static BestMixModeInputs fromJson(
    Object? json,
    BestMixModeInputs fallback, {
    required double maxDepthMeters,
  }) {
    if (json is! Map) return fallback;
    final depth = modNumberInRange(json['depthMeters'], 0, maxDepthMeters);
    final densityAware = json['densityAware'];
    final ppO2 = modNumberInRange(json['recPpO2'], 1.0, 1.6);
    return BestMixModeInputs(
      depthMeters: depth ?? fallback.depthMeters,
      densityAware: densityAware is bool ? densityAware : fallback.densityAware,
      recPpO2: ppO2 ?? fallback.recPpO2,
    );
  }

  @override
  List<Object?> get props => [depthMeters, densityAware, recPpO2];
}

/// Everything the Best Mix calculator remembers between sessions (issue
/// #3112), mirroring `ModCalculatorPreferences`'s shape.
///
/// The ppO2 limits for the Tec modes are overrides of the active diver's
/// profile, kept per diver through [ModLimitOverrides], the same type the
/// MOD calculator uses. The override storage itself is Best Mix's own,
/// under its own key: a diver who overrides their working ppO2 in the MOD
/// calculator does not see that override in Best Mix, and vice versa, each
/// calculator's override is local to it, deliberately not shared.
class BestMixCalculatorPreferences extends Equatable {
  final BestMixMode mode;
  final BestMixModeInputs rec;
  final BestMixModeInputs ocTec;
  final BestMixModeInputs ccrTec;
  final CcrGasSource ccrSource;

  /// Water type of the Tec modes, salt or fresh; null follows the planner's
  /// default.
  final WaterType? waterType;

  final GasDensityTemperature temperature;

  /// The ppO2 limit overrides by diver id; [bestMixNoDiverKey] without one.
  final Map<String, ModLimitOverrides> overridesByDiver;

  const BestMixCalculatorPreferences({
    required this.mode,
    required this.rec,
    required this.ocTec,
    required this.ccrTec,
    required this.ccrSource,
    required this.waterType,
    required this.temperature,
    required this.overridesByDiver,
  });

  static const defaults = BestMixCalculatorPreferences(
    mode: BestMixMode.rec,
    rec: BestMixModeInputs(depthMeters: 30, densityAware: false, recPpO2: 1.4),
    ocTec: BestMixModeInputs(
      depthMeters: 50,
      densityAware: false,
      recPpO2: 1.4,
    ),
    ccrTec: BestMixModeInputs(
      depthMeters: 50,
      densityAware: false,
      recPpO2: 1.4,
    ),
    ccrSource: CcrGasSource.diluent,
    waterType: null,
    temperature: GasDensityTemperature.zeroC,
    overridesByDiver: {},
  );

  /// The water types the calculator offers, matching the MOD calculator's.
  static const List<WaterType> waterTypes = [WaterType.salt, WaterType.fresh];

  BestMixModeInputs inputsFor(BestMixMode mode) => switch (mode) {
    BestMixMode.rec => rec,
    BestMixMode.ocTec => ocTec,
    BestMixMode.ccrTec => ccrTec,
  };

  ModLimitOverrides overridesFor(String? diverId) =>
      overridesByDiver[diverId ?? bestMixNoDiverKey] ?? ModLimitOverrides.none;

  BestMixCalculatorPreferences withInputs(
    BestMixMode mode,
    BestMixModeInputs inputs,
  ) => _with(
    rec: mode == BestMixMode.rec ? inputs : rec,
    ocTec: mode == BestMixMode.ocTec ? inputs : ocTec,
    ccrTec: mode == BestMixMode.ccrTec ? inputs : ccrTec,
  );

  /// [overrides] stored for [diverId]; an empty set drops the entry.
  BestMixCalculatorPreferences withOverrides(
    String? diverId,
    ModLimitOverrides overrides,
  ) {
    final key = diverId ?? bestMixNoDiverKey;
    return _with(
      overridesByDiver: {
        for (final entry in overridesByDiver.entries)
          if (entry.key != key) entry.key: entry.value,
        if (!overrides.isEmpty) key: overrides,
      },
    );
  }

  BestMixCalculatorPreferences copyWith({
    BestMixMode? mode,
    CcrGasSource? ccrSource,
    WaterType? waterType,
    GasDensityTemperature? temperature,
  }) => _with(
    mode: mode,
    ccrSource: ccrSource,
    waterType: waterType,
    temperature: temperature,
  );

  BestMixCalculatorPreferences _with({
    BestMixMode? mode,
    BestMixModeInputs? rec,
    BestMixModeInputs? ocTec,
    BestMixModeInputs? ccrTec,
    CcrGasSource? ccrSource,
    WaterType? waterType,
    GasDensityTemperature? temperature,
    Map<String, ModLimitOverrides>? overridesByDiver,
  }) => BestMixCalculatorPreferences(
    mode: mode ?? this.mode,
    rec: rec ?? this.rec,
    ocTec: ocTec ?? this.ocTec,
    ccrTec: ccrTec ?? this.ccrTec,
    ccrSource: ccrSource ?? this.ccrSource,
    waterType: waterType ?? this.waterType,
    temperature: temperature ?? this.temperature,
    overridesByDiver: overridesByDiver ?? this.overridesByDiver,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'rec': rec.toJson(),
    'ocTec': ocTec.toJson(),
    'ccrTec': ccrTec.toJson(),
    'ccrSource': ccrSource.name,
    'waterType': waterType?.name,
    'temperature': temperature.name,
    'overrides': {
      for (final entry in overridesByDiver.entries)
        entry.key: entry.value.toJson(),
    },
  };

  static BestMixCalculatorPreferences fromJson(Map<String, dynamic> json) {
    const d = defaults;
    final overrides = json['overrides'];
    return BestMixCalculatorPreferences(
      mode: _enumByName(BestMixMode.values, json['mode']) ?? d.mode,
      rec: BestMixModeInputs.fromJson(
        json['rec'],
        d.rec,
        maxDepthMeters: recTargetMaxMeters,
      ),
      ocTec: BestMixModeInputs.fromJson(
        json['ocTec'],
        d.ocTec,
        maxDepthMeters: tecTargetMaxMeters,
      ),
      ccrTec: BestMixModeInputs.fromJson(
        json['ccrTec'],
        d.ccrTec,
        maxDepthMeters: tecTargetMaxMeters,
      ),
      ccrSource:
          _enumByName(CcrGasSource.values, json['ccrSource']) ?? d.ccrSource,
      // Only a type the calculator offers: another (brackish) would be
      // computed while no segment shows it.
      waterType: _enumByName(waterTypes, json['waterType']),
      temperature:
          _enumByName(GasDensityTemperature.values, json['temperature']) ??
          d.temperature,
      overridesByDiver: {
        if (overrides is Map)
          for (final entry in overrides.entries)
            if (entry.key is String)
              if (ModLimitOverrides.fromJson(entry.value) case final o
                  when !o.isEmpty)
                entry.key as String: o,
      },
    );
  }

  @override
  List<Object?> get props => [
    mode,
    rec,
    ocTec,
    ccrTec,
    ccrSource,
    waterType,
    temperature,
    overridesByDiver,
  ];
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
