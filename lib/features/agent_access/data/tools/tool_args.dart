import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Reads an optional integer argument, refusing anything that is not an
/// integer inside [min] to [max] (no upper bound when [max] is null).
int intArg(
  Map<String, Object?> args,
  String key, {
  required int fallback,
  required int min,
  int? max,
}) {
  final raw = args[key];
  if (raw == null) return fallback;
  if (raw is! int || raw < min || (max != null && raw > max)) {
    throw AgentToolException(
      AgentToolErrorCode.invalidArgument,
      '$key must be an integer from $min${max == null ? '' : ' to $max'}.',
      details: {key: raw},
    );
  }
  return raw;
}
