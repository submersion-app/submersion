import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// The rule that produced a condition finding. Names are the stored values.
enum ConditionRuleId {
  cellOutputDeclining,
  cellOutputLow,
  cellDivergent,
  cellCurrentLimited,
  transmitterDropoutRising,
  transmitterDropoutHigh,
  issueRecurring,
  issueColdCorrelated,
  issueDeepCorrelated,
  incidentLinked;

  String get dbValue => name;

  /// Null for a rule this build does not know (a newer peer), so the
  /// caller drops the row rather than mislabel it.
  static ConditionRuleId? fromDbValue(String value) {
    for (final rule in values) {
      if (rule.name == value) return rule;
    }
    return null;
  }

  /// The spec's severity table. Fixed per rule so a finding's severity is
  /// never a judgement call at render time.
  ConditionSeverity get severity => switch (this) {
    ConditionRuleId.issueColdCorrelated ||
    ConditionRuleId.issueDeepCorrelated ||
    ConditionRuleId.incidentLinked => ConditionSeverity.info,
    ConditionRuleId.cellOutputDeclining ||
    ConditionRuleId.cellDivergent ||
    ConditionRuleId.transmitterDropoutRising ||
    ConditionRuleId.issueRecurring => ConditionSeverity.caution,
    ConditionRuleId.cellOutputLow ||
    ConditionRuleId.cellCurrentLimited ||
    ConditionRuleId.transmitterDropoutHigh => ConditionSeverity.significant,
  };
}

/// Neutral scale, like the safety review's: evidence weight, not alarm.
enum ConditionSeverity {
  info,
  caution,
  significant;

  String get dbValue => name;

  static ConditionSeverity fromDbValue(String value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return ConditionSeverity.info;
  }
}

/// The deterministic row id: a rule re-emits into the same row, which is
/// what lets a dismissal survive a recompute. [slot] distinguishes the
/// cell rules on a rebreather with no child in that slot; [tag] the
/// recurring-issue rule, which emits one finding per tag.
String conditionFindingId(
  String equipmentId,
  ConditionRuleId rule, {
  int? slot,
  String? tag,
}) {
  final base = 'cf_${equipmentId}_${rule.dbValue}';
  if (slot != null) return '${base}_$slot';
  if (tag != null) return '${base}_$tag';
  return base;
}

/// What a finding rests on: n, the window, the dives, and the numbers the
/// sentence is built from. Stored as JSON in `equipment_findings.evidence`.
class FindingEvidence extends Equatable {
  final int n;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<String> diveIds;

  /// Rule-specific, e.g. `{'recentMedian': 41.2, 'baselineMedian': 52.8}`.
  final Map<String, double> values;

  /// `ObservationTag.dbValue` for the recurring-issue rule, else null.
  final String? tag;

  /// The cell slot for the slot rules, else null.
  final int? slot;

  const FindingEvidence({
    required this.n,
    required this.windowStart,
    required this.windowEnd,
    this.diveIds = const [],
    this.values = const {},
    this.tag,
    this.slot,
  });

  String encode() => jsonEncode({
    'n': n,
    'windowStart': windowStart.millisecondsSinceEpoch,
    'windowEnd': windowEnd.millisecondsSinceEpoch,
    'diveIds': diveIds,
    'values': values,
    if (tag != null) 'tag': tag,
    if (slot != null) 'slot': slot,
  });

  /// The widest span of milliseconds a [DateTime] can hold, either side
  /// of the epoch.
  static const int _maxEpochMs = 8640000000000000;

  static bool _inDateRange(num ms) => ms.isFinite && ms.abs() <= _maxEpochMs;

  /// Lenient: a row written by a newer build with a shape this build does
  /// not know yields null, and the caller drops the finding.
  static FindingEvidence? decode(String json) {
    if (json.isEmpty) return null;
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (raw is! Map) return null;
    final n = raw['n'];
    final start = raw['windowStart'];
    final end = raw['windowEnd'];
    if (n is! num || start is! num || end is! num) return null;
    // Valid JSON can still hold a number no DateTime or int can: past the
    // DateTime range, or 1e400, which parses as infinity.
    if (!n.isFinite || !_inDateRange(start) || !_inDateRange(end)) {
      return null;
    }
    final ids = raw['diveIds'];
    final values = raw['values'];
    final slot = raw['slot'];
    return FindingEvidence(
      n: n.toInt(),
      windowStart: DateTime.fromMillisecondsSinceEpoch(
        start.toInt(),
        isUtc: true,
      ),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(end.toInt(), isUtc: true),
      diveIds: ids is List
          ? [
              for (final id in ids)
                if (id is String) id,
            ]
          : [],
      values: values is Map
          ? {
              for (final e in values.entries)
                // jsonDecode reads an overflowing literal as Infinity, which
                // cannot be re-encoded; skip it as the timestamps and slot are.
                if (e.key is String &&
                    e.value is num &&
                    (e.value as num).isFinite)
                  e.key as String: (e.value as num).toDouble(),
            }
          : const {},
      tag: raw['tag'] is String ? raw['tag'] as String : null,
      // Finite only: 1e400 parses as infinity, which toInt() refuses.
      slot: slot is num && slot.isFinite ? slot.toInt() : null,
    );
  }

  @override
  List<Object?> get props => [
    n,
    windowStart,
    windowEnd,
    diveIds,
    values,
    tag,
    slot,
  ];
}

/// SHA-1 hex over the sorted dive ids and the values in key order, so two
/// devices computing the same evidence agree and a dismissal can tell
/// "same evidence" from "new evidence".
String evidenceFingerprint(FindingEvidence evidence) {
  final ids = [...evidence.diveIds]..sort();
  final keys = evidence.values.keys.toList()..sort();
  final canonical = StringBuffer()
    ..write(ids.join('|'))
    ..write('#');
  for (final key in keys) {
    canonical
      ..write(key)
      ..write('=')
      ..write(evidence.values[key])
      ..write(';');
  }
  return sha1.convert(utf8.encode(canonical.toString())).toString();
}

/// One condition finding on one item. Write-once except [dismissedAt].
class EquipmentFinding extends Equatable {
  final String id;
  final String equipmentId;
  final ConditionRuleId ruleId;
  final ConditionSeverity severity;

  /// The rule's headline number (a percent drop, a gain, a fraction, a
  /// count); the evidence carries the rest.
  final double? value;
  final FindingEvidence evidence;
  final String evidenceFingerprint;
  final int engineVersion;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  const EquipmentFinding({
    required this.id,
    required this.equipmentId,
    required this.ruleId,
    required this.severity,
    this.value,
    required this.evidence,
    required this.evidenceFingerprint,
    required this.engineVersion,
    this.dismissedAt,
    required this.createdAt,
  });

  bool get isDismissed => dismissedAt != null;

  EquipmentFinding copyWith({
    String? id,
    String? equipmentId,
    ConditionRuleId? ruleId,
    ConditionSeverity? severity,
    double? value,
    FindingEvidence? evidence,
    String? evidenceFingerprint,
    int? engineVersion,
    DateTime? dismissedAt,
    bool clearDismissedAt = false,
    DateTime? createdAt,
  }) => EquipmentFinding(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    ruleId: ruleId ?? this.ruleId,
    severity: severity ?? this.severity,
    value: value ?? this.value,
    evidence: evidence ?? this.evidence,
    evidenceFingerprint: evidenceFingerprint ?? this.evidenceFingerprint,
    engineVersion: engineVersion ?? this.engineVersion,
    dismissedAt: clearDismissedAt ? null : (dismissedAt ?? this.dismissedAt),
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    ruleId,
    severity,
    value,
    evidence,
    evidenceFingerprint,
    engineVersion,
    dismissedAt,
    createdAt,
  ];
}
