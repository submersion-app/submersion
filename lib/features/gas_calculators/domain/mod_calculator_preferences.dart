import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';

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
    final o2 =
        modNumberInRange(json['o2Percent'], 1, 100) ?? fallback.o2Percent;
    final he =
        (modNumberInRange(json['hePercent'], 0, 100) ?? fallback.hePercent)
            .clamp(0.0, 100.0 - o2)
            .toDouble();
    final check = json['checkTargetDepth'];
    return ModModeInputs(
      o2Percent: o2,
      hePercent: he,
      targetDepthMeters:
          modNumberInRange(json['targetDepthMeters'], 0, tecTargetMaxMeters) ??
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

/// Key of the overrides kept while no diver is active.
const String modNoDiverKey = '';

/// Everything the MOD calculator remembers between sessions (issue #2342).
///
/// The ppO2 limits and the CCR setpoint are overrides of the active diver's
/// profile (the OC or the CCR ppO2 limits in the settings), kept per diver:
/// a diver who never touches them follows their profile, one who does sees
/// the override marked against it, and switching divers never carries one
/// diver's override onto another's profile.
class ModCalculatorPreferences extends Equatable {
  final ModCalculatorMode mode;
  final ModModeInputs rec;
  final ModModeInputs ocTec;
  final ModModeInputs ccrTec;

  /// Water type of the Tec modes, salt or fresh; null follows the planner's
  /// default.
  final WaterType? waterType;

  final double minPpO2;

  /// The ppO2 limit overrides by diver id; [modNoDiverKey] without one.
  final Map<String, ModLimitOverrides> overridesByDiver;

  const ModCalculatorPreferences({
    required this.mode,
    required this.rec,
    required this.ocTec,
    required this.ccrTec,
    required this.waterType,
    required this.minPpO2,
    required this.overridesByDiver,
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
    overridesByDiver: {},
  );

  /// The water types the calculator offers.
  static const List<WaterType> waterTypes = [WaterType.salt, WaterType.fresh];

  ModModeInputs inputsFor(ModCalculatorMode mode) => switch (mode) {
    ModCalculatorMode.rec => rec,
    ModCalculatorMode.ocTec => ocTec,
    ModCalculatorMode.ccrTec => ccrTec,
  };

  ModLimitOverrides overridesFor(String? diverId) =>
      overridesByDiver[diverId ?? modNoDiverKey] ?? ModLimitOverrides.none;

  ModCalculatorPreferences withInputs(
    ModCalculatorMode mode,
    ModModeInputs inputs,
  ) => _with(
    rec: mode == ModCalculatorMode.rec ? inputs : rec,
    ocTec: mode == ModCalculatorMode.ocTec ? inputs : ocTec,
    ccrTec: mode == ModCalculatorMode.ccrTec ? inputs : ccrTec,
  );

  /// [overrides] stored for [diverId]; an empty set drops the entry.
  ModCalculatorPreferences withOverrides(
    String? diverId,
    ModLimitOverrides overrides,
  ) {
    final key = diverId ?? modNoDiverKey;
    return _with(
      overridesByDiver: {
        for (final entry in overridesByDiver.entries)
          if (entry.key != key) entry.key: entry.value,
        if (!overrides.isEmpty) key: overrides,
      },
    );
  }

  ModCalculatorPreferences copyWith({
    ModCalculatorMode? mode,
    WaterType? waterType,
    double? minPpO2,
  }) => _with(mode: mode, waterType: waterType, minPpO2: minPpO2);

  ModCalculatorPreferences _with({
    ModCalculatorMode? mode,
    ModModeInputs? rec,
    ModModeInputs? ocTec,
    ModModeInputs? ccrTec,
    WaterType? waterType,
    double? minPpO2,
    Map<String, ModLimitOverrides>? overridesByDiver,
  }) => ModCalculatorPreferences(
    mode: mode ?? this.mode,
    rec: rec ?? this.rec,
    ocTec: ocTec ?? this.ocTec,
    ccrTec: ccrTec ?? this.ccrTec,
    waterType: waterType ?? this.waterType,
    minPpO2: minPpO2 ?? this.minPpO2,
    overridesByDiver: overridesByDiver ?? this.overridesByDiver,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'rec': rec.toJson(),
    'ocTec': ocTec.toJson(),
    'ccrTec': ccrTec.toJson(),
    'waterType': waterType?.name,
    'minPpO2': minPpO2,
    'overrides': {
      for (final entry in overridesByDiver.entries)
        entry.key: entry.value.toJson(),
    },
  };

  static ModCalculatorPreferences fromJson(Map<String, dynamic> json) {
    const d = defaults;
    final minPpO2 = json['minPpO2'];
    final overrides = json['overrides'];
    return ModCalculatorPreferences(
      mode: _enumByName(ModCalculatorMode.values, json['mode']) ?? d.mode,
      rec: ModModeInputs.fromJson(json['rec'], d.rec),
      ocTec: ModModeInputs.fromJson(json['ocTec'], d.ocTec),
      ccrTec: ModModeInputs.fromJson(json['ccrTec'], d.ccrTec),
      // Only a type the calculator offers: another (brackish) would be
      // computed while neither segment shows it.
      waterType: _enumByName(waterTypes, json['waterType']),
      minPpO2: minPpO2 is num && modMinPpO2Options.contains(minPpO2.toDouble())
          ? minPpO2.toDouble()
          : d.minPpO2,
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
    waterType,
    minPpO2,
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
