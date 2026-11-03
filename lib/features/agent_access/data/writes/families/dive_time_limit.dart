import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';

/// A block when [values] puts [key] past the last moment the app lets a
/// diver place a time on [diveId]: an annotation, a gas switch, a Dive Lab
/// branch. That is the profile's last sample, else the dive's runtime, else
/// a day, as the dive page caps it ([annotationTimeCap]).
Future<PlanBlock?> beyondDive(
  RecordRepositories r,
  String? diveId,
  Map<String, Object?> values, {
  String key = 't_s',
}) async {
  final t = values[key];
  if (t is! int || diveId == null) return null;
  final limit = await _timeLimit(r, diveId);
  if (t <= limit) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    '$key: $t is past the end of the dive at $limit s.',
  );
}

Future<int> _timeLimit(RecordRepositories r, String diveId) async {
  return await _profileEnd(diveId) ??
      annotationTimeCap(
        (await r.dives.getDivesByIdsWithoutSamples([
          diveId,
        ])).firstOrNull?.effectiveRuntime?.inSeconds,
      );
}

/// The last sample of [diveId]'s profile as the dive page reads it, the
/// primary series merged, from the series' stored end times rather than by
/// decoding every sample. Null for a dive with no profile.
Future<int?> _profileEnd(String diveId) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT MAX(end_timestamp) AS end_s FROM dive_profile_series '
        'WHERE dive_id = ? AND is_primary = 1 AND sample_count > 0',
        variables: [Variable.withString(diveId)],
      )
      .getSingle();
  return row.readNullable<int>('end_s');
}
