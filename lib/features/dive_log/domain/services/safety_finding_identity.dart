import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Fixed namespace for deterministic safety finding ids (UUIDv5). Never
/// change: a stored id minted under it must keep matching.
const String kSafetyFindingNamespace = '4d0c8a52-6b1e-4f3a-9a27-c5e1d7b3f906';

/// What makes two findings of one dive the same finding: the rule, the span
/// and the finding's position among findings sharing that rule and span.
typedef SafetyFindingKey = (String ruleId, int? start, int? end, int ordinal);

/// Keys for [spans], in the same order. The ordinal is a finding's rank
/// among the spans sharing its rule and span, ordered by value (then by
/// position when values tie), so it does not depend on the order the spans
/// arrive in: stored rows and the engine's output agree on it.
List<SafetyFindingKey> safetyFindingKeys(
  List<({String ruleId, int? start, int? end, double? value})> spans,
) {
  final groups = <(String, int?, int?), List<int>>{};
  for (var i = 0; i < spans.length; i++) {
    final s = spans[i];
    groups.putIfAbsent((s.ruleId, s.start, s.end), () => []).add(i);
  }
  final ordinals = List<int>.filled(spans.length, 0);
  for (final members in groups.values) {
    final ranked = [...members]
      ..sort((a, b) {
        final byValue = (spans[a].value ?? double.negativeInfinity).compareTo(
          spans[b].value ?? double.negativeInfinity,
        );
        return byValue != 0 ? byValue : a.compareTo(b);
      });
    for (var rank = 0; rank < ranked.length; rank++) {
      ordinals[ranked[rank]] = rank;
    }
  }
  return [
    for (var i = 0; i < spans.length; i++)
      (spans[i].ruleId, spans[i].start, spans[i].end, ordinals[i]),
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
      (
        ruleId: f.ruleId.dbValue,
        start: f.startTimestamp,
        end: f.endTimestamp,
        value: f.value,
      ),
  ]);
  return [
    for (var i = 0; i < findings.length; i++)
      findings[i].copyWith(id: safetyFindingId(diveId, keys[i])),
  ];
}
