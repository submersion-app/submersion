import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// A block when [values] puts `t_s` past the end of [diveId]'s profile, the
/// last moment the app lets a diver place an annotation or a gas switch.
/// A dive with no profile has nothing to place a time against, so any time
/// stands.
Future<PlanBlock?> beyondDive(
  RecordRepositories r,
  String? diveId,
  Map<String, Object?> values,
) async {
  final t = values['t_s'];
  if (t is! int || diveId == null) return null;
  final profile = await r.dives.getDiveProfile(diveId);
  if (profile.isEmpty || t <= profile.last.timestamp) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    't_s: $t is past the end of the dive\'s profile at '
    '${profile.last.timestamp} s.',
  );
}
