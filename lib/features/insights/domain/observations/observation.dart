import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

/// One derived observation. [fingerprint] holds only the facts that matter
/// for dismissal (spec section 4.2): a dismissed observation returns when
/// its fingerprint changes. [score] orders observations within a kind.
class Observation extends Equatable {
  final ObservationRuleId ruleId;
  final String fingerprint;
  final double score;
  final ObservationFacts facts;
  final ObservationTarget target;

  const Observation({
    required this.ruleId,
    required this.fingerprint,
    required this.score,
    required this.facts,
    required this.target,
  });

  ObservationKind get kind => ruleId.kind;

  String get key => observationKey(ruleId, fingerprint);

  Observation copyWith({
    ObservationRuleId? ruleId,
    String? fingerprint,
    double? score,
    ObservationFacts? facts,
    ObservationTarget? target,
  }) => Observation(
    ruleId: ruleId ?? this.ruleId,
    fingerprint: fingerprint ?? this.fingerprint,
    score: score ?? this.score,
    facts: facts ?? this.facts,
    target: target ?? this.target,
  );

  @override
  List<Object?> get props => [ruleId, fingerprint, score, facts, target];
}

/// The identity a dismissal matches on.
String observationKey(ObservationRuleId rule, String fingerprint) =>
    '${rule.dbValue}:$fingerprint';

/// The deterministic dismissal row id. Two devices that dismiss the same
/// observation write the same row, so sync merges it with a plain upsert.
String observationDismissalId(
  String diverId,
  ObservationRuleId rule,
  String fingerprint,
) => 'od_${sha1.convert(utf8.encode('$diverId|${rule.dbValue}|$fingerprint'))}';
