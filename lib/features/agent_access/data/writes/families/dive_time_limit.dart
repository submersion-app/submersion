import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';

/// A block when [values] puts `t_s` past the last moment the app lets a diver
/// place an annotation or a gas switch on [diveId]: the profile's last
/// sample, else the dive's runtime, else a day, as the dive page caps it
/// ([annotationTimeCap]).
Future<PlanBlock?> beyondDive(
  RecordRepositories r,
  String? diveId,
  Map<String, Object?> values,
) async {
  final t = values['t_s'];
  if (t is! int || diveId == null) return null;
  final limit = await _timeLimit(r, diveId);
  if (t <= limit) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    't_s: $t is past the end of the dive at $limit s.',
  );
}

Future<int> _timeLimit(RecordRepositories r, String diveId) async {
  final profile = await r.dives.getDiveProfile(diveId);
  if (profile.isNotEmpty) return profile.last.timestamp;
  final dives = await r.dives.getDivesByIdsWithoutSamples([diveId]);
  return annotationTimeCap(dives.firstOrNull?.effectiveRuntime?.inSeconds);
}
