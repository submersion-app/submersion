import 'dart:convert';

import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';

const String sublabFormat = 'submersion-lab';
const int sublabVersion = 1;
const String sublabExtension = 'sublab';

/// A decoded `.sublab` file.
class SublabFile {
  const SublabFile({
    required this.scenario,
    required this.snapshot,
    this.appVersion,
  });
  final DiveScenario scenario;
  final DiveSnapshot snapshot;
  final String? appVersion;
}

/// The shareable JSON for one scenario plus its dive snapshot. Ids are kept
/// as they are; the importer decides whether to attach or re-mint.
String scenarioToSublabJson({
  required DiveScenario scenario,
  required DiveSnapshot snapshot,
  String? appVersion,
}) {
  final envelope = {
    'format': sublabFormat,
    'version': sublabVersion,
    'exportedBy': {'app': 'submersion', 'version': appVersion},
    'scenario': {
      'id': scenario.id,
      'diveId': scenario.diveId,
      'name': scenario.name,
      'notes': scenario.notes,
      'branchSeconds': scenario.branchSeconds,
      'mode': scenario.mode.name,
      'interventions': jsonDecode(encodeInterventions(scenario.interventions)),
      'createdAt': scenario.createdAt.toUtc().toIso8601String(),
      'updatedAt': scenario.updatedAt.toUtc().toIso8601String(),
    },
    'diveSnapshot': snapshot.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(envelope);
}

SublabFile sublabFromJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('Not a valid .sublab file');
  }
  if (decoded is! Map || decoded['format'] != sublabFormat) {
    throw const FormatException('Not a Submersion scenario file');
  }
  final version = decoded['version'];
  if (version is! int || version > sublabVersion) {
    throw FormatException(
      'Scenario file version $version is newer than this app supports',
    );
  }
  final scenarioRaw = decoded['scenario'];
  final snapshotRaw = decoded['diveSnapshot'];
  if (scenarioRaw is! Map || snapshotRaw is! Map) {
    throw const FormatException('Scenario file carries no scenario');
  }
  try {
    final s = scenarioRaw.cast<String, Object?>();
    final snapshot = DiveSnapshot.fromJson(snapshotRaw.cast<String, Object?>());
    if (snapshot.profile.length < 2) {
      throw const FormatException('Scenario file carries no dive profile');
    }
    final exportedBy = decoded['exportedBy'];
    final scenario = DiveScenario(
      id: s['id'] as String,
      diveId: s['diveId'] as String,
      name: s['name'] as String,
      notes: s['notes'] as String?,
      branchSeconds: (s['branchSeconds'] as num).toInt(),
      mode:
          ScenarioMode.values.asNameMap()[s['mode'] as String?] ??
          ScenarioMode.replay,
      interventions: decodeInterventions(jsonEncode(s['interventions'])),
      createdAt: DateTime.parse(s['createdAt'] as String),
      updatedAt: DateTime.parse(s['updatedAt'] as String),
    );
    return SublabFile(
      scenario: scenario,
      snapshot: snapshot,
      appVersion: exportedBy is Map ? exportedBy['version'] as String? : null,
    );
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('Malformed .sublab file: $e');
  }
}
