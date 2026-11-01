import 'dart:convert';

import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Version of the interventions JSON envelope. Bump when a kind's fields
/// change shape; decoding a newer version than this is refused.
const int scenarioInterventionFormatVersion = 1;

String encodeInterventions(List<ScenarioIntervention> interventions) =>
    jsonEncode({
      'formatVersion': scenarioInterventionFormatVersion,
      'interventions': [for (final i in interventions) interventionToJson(i)],
    });

List<ScenarioIntervention> decodeInterventions(String json) {
  final Object? decoded = jsonDecode(json);
  if (decoded is! Map) {
    throw const FormatException('interventions envelope must be an object');
  }
  final version = decoded['formatVersion'];
  if (version is! int) {
    throw const FormatException('interventions envelope lacks formatVersion');
  }
  if (version > scenarioInterventionFormatVersion) {
    throw FormatException(
      'interventions formatVersion $version is newer than supported '
      '$scenarioInterventionFormatVersion',
    );
  }
  final list = decoded['interventions'];
  if (list is! List) {
    throw const FormatException('interventions envelope lacks a list');
  }
  return [
    for (final item in list) interventionFromJson(_asMap(item, 'intervention')),
  ];
}

Map<String, Object?> interventionToJson(ScenarioIntervention i) {
  return switch (i) {
    SwitchGasIntervention(:final tank) => {
      'kind': i.kind.name,
      'tank': _tankRefToJson(tank),
    },
    LoseTankIntervention(:final tankId) => {
      'kind': i.kind.name,
      'tankId': tankId,
    },
    ShiftAscentIntervention(:final deltaSeconds) => {
      'kind': i.kind.name,
      'deltaSeconds': deltaSeconds,
    },
    AscendNowIntervention() => {'kind': i.kind.name},
    ChangeGfIntervention(:final gfLow, :final gfHigh) => {
      'kind': i.kind.name,
      'gfLow': gfLow,
      'gfHigh': gfHigh,
    },
    ShareGasIntervention(:final buddyFactor) => {
      'kind': i.kind.name,
      'buddyFactor': buddyFactor,
    },
    BailOutIntervention(:final tank) => {
      'kind': i.kind.name,
      'tank': tank == null ? null : _tankRefToJson(tank),
    },
    AscentPolicyIntervention(
      :final ascentRate,
      :final lastStopDepth,
      :final extraLastStopSeconds,
      :final gasSwitchStopSeconds,
    ) =>
      {
        'kind': i.kind.name,
        'ascentRate': ascentRate,
        'lastStopDepth': lastStopDepth,
        'extraLastStopSeconds': extraLastStopSeconds,
        'gasSwitchStopSeconds': gasSwitchStopSeconds,
      },
  };
}

ScenarioIntervention interventionFromJson(Map<String, Object?> map) {
  final kindName = map['kind'];
  InterventionKind? kind;
  for (final k in InterventionKind.values) {
    if (k.name == kindName) kind = k;
  }
  if (kind == null) {
    throw FormatException('unknown intervention kind: $kindName');
  }
  return switch (kind) {
    InterventionKind.switchGas => SwitchGasIntervention(
      tank: _tankRefFromJson(_asMap(map['tank'], 'tank')),
    ),
    InterventionKind.loseTank => LoseTankIntervention(
      tankId: _asString(map['tankId'], 'tankId'),
    ),
    InterventionKind.shiftAscent => ShiftAscentIntervention(
      deltaSeconds: _asInt(map['deltaSeconds'], 'deltaSeconds'),
    ),
    InterventionKind.ascendNow => const AscendNowIntervention(),
    InterventionKind.changeGf => ChangeGfIntervention(
      gfLow: _asInt(map['gfLow'], 'gfLow'),
      gfHigh: _asInt(map['gfHigh'], 'gfHigh'),
    ),
    InterventionKind.shareGas => ShareGasIntervention(
      buddyFactor: _asDoubleOrNull(map['buddyFactor']),
    ),
    InterventionKind.bailOut => BailOutIntervention(
      tank: map['tank'] == null
          ? null
          : _tankRefFromJson(_asMap(map['tank'], 'tank')),
    ),
    InterventionKind.ascentPolicy => AscentPolicyIntervention(
      ascentRate: _asDoubleOrNull(map['ascentRate']),
      lastStopDepth: _asDoubleOrNull(map['lastStopDepth']),
      extraLastStopSeconds: _asIntOrNull(map['extraLastStopSeconds']),
      gasSwitchStopSeconds: _asIntOrNull(map['gasSwitchStopSeconds']),
    ),
  };
}

Map<String, Object?> _tankRefToJson(TankRef ref) => switch (ref) {
  ExistingTankRef(:final tankId) => {'type': 'existing', 'tankId': tankId},
  HypotheticalTankRef(
    :final gasMix,
    :final volumeLiters,
    :final startPressureBar,
  ) =>
    {
      'type': 'hypothetical',
      'o2': gasMix.o2,
      'he': gasMix.he,
      'volumeLiters': volumeLiters,
      'startPressureBar': startPressureBar,
    },
};

TankRef _tankRefFromJson(Map<String, Object?> map) {
  final type = map['type'];
  if (type == 'existing') {
    return ExistingTankRef(_asString(map['tankId'], 'tankId'));
  }
  if (type == 'hypothetical') {
    return HypotheticalTankRef(
      gasMix: GasMix(
        o2: _asDouble(map['o2'], 'o2'),
        he: _asDouble(map['he'], 'he'),
      ),
      volumeLiters: _asDouble(map['volumeLiters'], 'volumeLiters'),
      startPressureBar: _asDouble(map['startPressureBar'], 'startPressureBar'),
    );
  }
  throw FormatException('unknown tank ref type: $type');
}

Map<String, Object?> _asMap(Object? v, String field) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('$field must be an object');
}

String _asString(Object? v, String field) {
  if (v is String) return v;
  throw FormatException('$field must be a string');
}

int _asInt(Object? v, String field) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw FormatException('$field must be an integer');
}

int? _asIntOrNull(Object? v) => v == null ? null : _asInt(v, 'value');

double _asDouble(Object? v, String field) {
  if (v is num) return v.toDouble();
  throw FormatException('$field must be a number');
}

double? _asDoubleOrNull(Object? v) => v == null ? null : _asDouble(v, 'value');
