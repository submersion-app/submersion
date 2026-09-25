import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What a `.sublab` file carries about the dive so a recipient without it
/// can run the scenario: inputs only (profile, tanks, switches, pressures,
/// deco settings), never results.
class DiveSnapshot extends Equatable {
  const DiveSnapshot({
    required this.diveId,
    required this.diveDateTime,
    this.siteName,
    this.diveMode = DiveMode.oc,
    this.gfLow,
    this.gfHigh,
    this.altitudeMeters,
    this.waterType,
    this.surfacePressureBar,
    this.setpointHigh,
    this.setpointLow,
    this.tanks = const [],
    this.gasSwitches = const [],
    this.profile = const [],
    this.tankPressures = const {},
    this.computerName,
  });

  final String diveId;
  final DateTime diveDateTime;
  final String? siteName;
  final DiveMode diveMode;
  final int? gfLow;
  final int? gfHigh;
  final double? altitudeMeters;
  final WaterType? waterType;
  final double? surfacePressureBar;
  final double? setpointHigh;
  final double? setpointLow;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> gasSwitches;
  final List<DiveProfilePoint> profile;
  final Map<String, List<TankPressureSample>> tankPressures;
  final String? computerName;

  /// From a logged dive and its primary profile.
  factory DiveSnapshot.fromDive({
    required Dive dive,
    required List<DiveProfilePoint> profile,
    required List<ScenarioGasSwitch> gasSwitches,
    required Map<String, List<TankPressureSample>> tankPressures,
    String? siteName,
    String? computerName,
  }) => DiveSnapshot(
    diveId: dive.id,
    diveDateTime: dive.dateTime,
    siteName: siteName ?? dive.site?.name,
    diveMode: dive.diveMode,
    gfLow: dive.gradientFactorLow,
    gfHigh: dive.gradientFactorHigh,
    altitudeMeters: dive.altitude,
    waterType: dive.waterType,
    surfacePressureBar: dive.surfacePressure,
    setpointHigh: dive.setpointHigh,
    setpointLow: dive.setpointLow,
    tanks: dive.tanks,
    gasSwitches: gasSwitches,
    profile: [
      for (final p in profile)
        DiveProfilePoint(
          timestamp: p.timestamp,
          depth: p.depth,
          temperature: p.temperature,
          setpoint: p.setpoint,
          ppO2: p.ppO2,
        ),
    ],
    tankPressures: tankPressures,
    computerName: computerName,
  );

  Map<String, Object?> toJson() => {
    'diveId': diveId,
    'diveDateTime': diveDateTime.toUtc().toIso8601String(),
    'siteName': siteName,
    'diveMode': diveMode.name,
    'gfLow': gfLow,
    'gfHigh': gfHigh,
    'altitudeMeters': altitudeMeters,
    'waterType': waterType?.name,
    'surfacePressureBar': surfacePressureBar,
    'setpointHigh': setpointHigh,
    'setpointLow': setpointLow,
    'tanks': [
      for (final t in tanks)
        {
          'id': t.id,
          'name': t.name,
          'volume': t.volume,
          'workingPressure': t.workingPressure,
          'startPressure': t.startPressure,
          'endPressure': t.endPressure,
          'o2': t.gasMix.o2,
          'he': t.gasMix.he,
          'role': t.role.name,
        },
    ],
    'gasSwitches': [
      for (final s in gasSwitches)
        {'timestamp': s.timestamp, 'tankId': s.tankId},
    ],
    'profile': [
      for (final p in profile)
        {
          't': p.timestamp,
          'd': p.depth,
          if (p.temperature != null) 'temp': p.temperature,
          if (p.setpoint != null) 'sp': p.setpoint,
          if (p.ppO2 != null) 'ppO2': p.ppO2,
        },
    ],
    'tankPressures': {
      for (final e in tankPressures.entries)
        e.key: [
          for (final s in e.value) {'t': s.timestamp, 'bar': s.pressureBar},
        ],
    },
    'computerName': computerName,
  };

  factory DiveSnapshot.fromJson(Map<String, Object?> json) {
    T? enumByName<T extends Enum>(List<T> values, Object? name) {
      if (name is! String) return null;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final tanks = <DiveTank>[
      for (final raw in (json['tanks'] as List? ?? const []))
        () {
          final m = (raw as Map).cast<String, Object?>();
          return DiveTank(
            id: m['id'] as String,
            name: m['name'] as String?,
            volume: (m['volume'] as num?)?.toDouble(),
            workingPressure: (m['workingPressure'] as num?)?.toDouble(),
            startPressure: (m['startPressure'] as num?)?.toDouble(),
            endPressure: (m['endPressure'] as num?)?.toDouble(),
            gasMix: GasMix(
              o2: (m['o2'] as num?)?.toDouble() ?? 21,
              he: (m['he'] as num?)?.toDouble() ?? 0,
            ),
            role: enumByName(TankRole.values, m['role']) ?? TankRole.backGas,
          );
        }(),
    ];
    return DiveSnapshot(
      diveId: json['diveId'] as String,
      diveDateTime: DateTime.parse(json['diveDateTime'] as String),
      siteName: json['siteName'] as String?,
      diveMode: enumByName(DiveMode.values, json['diveMode']) ?? DiveMode.oc,
      gfLow: (json['gfLow'] as num?)?.toInt(),
      gfHigh: (json['gfHigh'] as num?)?.toInt(),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      waterType: enumByName(WaterType.values, json['waterType']),
      surfacePressureBar: (json['surfacePressureBar'] as num?)?.toDouble(),
      setpointHigh: (json['setpointHigh'] as num?)?.toDouble(),
      setpointLow: (json['setpointLow'] as num?)?.toDouble(),
      tanks: tanks,
      gasSwitches: [
        for (final raw in (json['gasSwitches'] as List? ?? const []))
          ScenarioGasSwitch(
            timestamp: ((raw as Map)['timestamp'] as num).toInt(),
            tankId: raw['tankId'] as String,
          ),
      ],
      profile: [
        for (final raw in (json['profile'] as List? ?? const []))
          () {
            final m = (raw as Map).cast<String, Object?>();
            return DiveProfilePoint(
              timestamp: (m['t'] as num).toInt(),
              depth: (m['d'] as num).toDouble(),
              temperature: (m['temp'] as num?)?.toDouble(),
              setpoint: (m['sp'] as num?)?.toDouble(),
              ppO2: (m['ppO2'] as num?)?.toDouble(),
            );
          }(),
      ],
      tankPressures: {
        for (final e in ((json['tankPressures'] as Map?) ?? const {}).entries)
          e.key as String: [
            for (final raw in (e.value as List))
              TankPressureSample(
                timestamp: ((raw as Map)['t'] as num).toInt(),
                pressureBar: (raw['bar'] as num).toDouble(),
              ),
          ],
      },
      computerName: json['computerName'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    diveId,
    diveDateTime,
    siteName,
    diveMode,
    gfLow,
    gfHigh,
    altitudeMeters,
    waterType,
    surfacePressureBar,
    setpointHigh,
    setpointLow,
    tanks,
    gasSwitches,
    profile,
    tankPressures,
    computerName,
  ];
}
