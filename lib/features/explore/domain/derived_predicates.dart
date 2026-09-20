import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// A question about a dive that only the phase 2 derived tables can answer.
///
/// Every one is SQL-only: `DiveFilterState.apply` cannot evaluate it because
/// the entity carries no profile, so callers intersect an id set instead,
/// exactly as the deco axis works.
sealed class DerivedPredicate {
  const DerivedPredicate();
}

class SacTrendIs extends DerivedPredicate {
  final SacTrend trend;

  /// The band around zero the engine treats as noise, in bar per minute per
  /// minute. Kept here so the SQL and [DiveDerivedMetrics.trend] agree.
  final double flatBand;

  const SacTrendIs(this.trend, {this.flatBand = 0.02});

  @override
  bool operator ==(Object other) =>
      other is SacTrendIs && other.trend == trend && other.flatBand == flatBand;

  @override
  int get hashCode => Object.hash(trend, flatBand);

  @override
  String toString() => 'SacTrendIs(${trend.name})';
}

/// SAC after [minutes] exceeded SAC before it by at least [ratio].
class SacRoseAfter extends DerivedPredicate {
  final int minutes;
  final double ratio;

  const SacRoseAfter({required this.minutes, this.ratio = 1.1});

  @override
  bool operator ==(Object other) =>
      other is SacRoseAfter && other.minutes == minutes && other.ratio == ratio;

  @override
  int get hashCode => Object.hash(minutes, ratio);

  @override
  String toString() => 'SacRoseAfter($minutes, $ratio)';
}

class FinalStopUnstable extends DerivedPredicate {
  /// How far the diver may stray from the stop's median depth before the
  /// stop counts as unstable. The chip shows this number.
  final double thresholdMeters;

  const FinalStopUnstable({this.thresholdMeters = 1.0});

  @override
  bool operator ==(Object other) =>
      other is FinalStopUnstable && other.thresholdMeters == thresholdMeters;

  @override
  int get hashCode => thresholdMeters.hashCode;

  @override
  String toString() => 'FinalStopUnstable($thresholdMeters)';
}

class FinalStopDuration extends DerivedPredicate {
  final int? minSeconds;
  final int? maxSeconds;

  const FinalStopDuration({this.minSeconds, this.maxSeconds});

  @override
  bool operator ==(Object other) =>
      other is FinalStopDuration &&
      other.minSeconds == minSeconds &&
      other.maxSeconds == maxSeconds;

  @override
  int get hashCode => Object.hash(minSeconds, maxSeconds);

  @override
  String toString() => 'FinalStopDuration($minSeconds, $maxSeconds)';
}

class HasFinding extends DerivedPredicate {
  final SafetyRuleId rule;

  const HasFinding(this.rule);

  @override
  bool operator ==(Object other) => other is HasFinding && other.rule == rule;

  @override
  int get hashCode => rule.hashCode;

  @override
  String toString() => 'HasFinding(${rule.name})';
}

/// A value-equal wrapper, because a `List` passed as a family argument
/// compares by IDENTITY: without this the id-set provider would miss its
/// cache on every rebuild and requery on each frame.
class DerivedConditionsKey {
  final List<DerivedPredicate> predicates;

  const DerivedConditionsKey(this.predicates);

  @override
  bool operator ==(Object other) {
    if (other is! DerivedConditionsKey) return false;
    if (other.predicates.length != predicates.length) return false;
    for (var i = 0; i < predicates.length; i++) {
      if (other.predicates[i] != predicates[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(predicates);

  @override
  String toString() => 'DerivedConditionsKey($predicates)';
}
