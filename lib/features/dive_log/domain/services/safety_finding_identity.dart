import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Fixed namespace for deterministic safety finding ids (UUIDv5). Never
/// change: a stored id minted under it must keep matching.
const String kSafetyFindingNamespace = '4d0c8a52-6b1e-4f3a-9a27-c5e1d7b3f906';

/// What makes two findings of one dive the same finding: the rule, the span
/// and the finding's position among findings sharing that rule and span.
typedef SafetyFindingKey = (String ruleId, int? start, int? end, int ordinal);

/// Keys for [spans] in order. The ordinal counts earlier entries with the
/// same rule and span, so repeats never collapse into one key.
List<SafetyFindingKey> safetyFindingKeys(
  Iterable<({String ruleId, int? start, int? end})> spans,
) {
  final seen = <(String, int?, int?), int>{};
  return [
    for (final s in spans)
      (
        s.ruleId,
        s.start,
        s.end,
        seen.update(
          (s.ruleId, s.start, s.end),
          (n) => n + 1,
          ifAbsent: () => 0,
        ),
      ),
  ];
}

/// Deterministic id: two devices reviewing the same dive mint the same id
/// for the same finding and converge under sync instead of duplicating.
String safetyFindingId(String diveId, SafetyFindingKey key) => const Uuid().v5(
  kSafetyFindingNamespace,
  '$diveId|${key.$1}|${key.$2 ?? ''}|${key.$3 ?? ''}|${key.$4}',
);

/// [findings] with their ids replaced by [safetyFindingId].
List<SafetyFinding> withDeterministicIds(
  String diveId,
  List<SafetyFinding> findings,
) {
  final keys = safetyFindingKeys([
    for (final f in findings)
      (ruleId: f.ruleId.dbValue, start: f.startTimestamp, end: f.endTimestamp),
  ]);
  return [
    for (var i = 0; i < findings.length; i++)
      findings[i].copyWith(id: safetyFindingId(diveId, keys[i])),
  ];
}
