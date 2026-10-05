import 'dart:math' as math;

import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

/// Compares a Dive focus group's factors with its baseline (issue #1611).
///
/// "Stands out" is an effect size, not a significance test: with ten dives a
/// p-value mostly says nothing, while half a baseline standard deviation
/// answers "is this big next to my usual spread?".
abstract final class FocusFactorAnalyzer {
  static const int minGroupSize = 3;
  static const double standoutDeviations = 0.5;
  static const double standoutSharePoints = 0.20;
  static const int standoutMinCount = 2;
  static const int topCategories = 3;

  static FocusFactorReport analyze({
    required List<FocusFactorRow> group,
    required List<FocusFactorRow> baseline,
    required FocusMetric metric,
  }) {
    if (group.length < minGroupSize) {
      return const FocusFactorReport(factors: [], tooFewDives: true);
    }
    final skip = _selfFactor(metric);
    return FocusFactorReport(
      tooFewDives: false,
      factors: [
        for (final id in FocusFactorId.values)
          if (id != skip)
            id.isNumeric
                ? _numeric(id, group, baseline)
                : _categorical(id, group, baseline),
      ],
    );
  }

  /// The Time patterns page's buckets, on the stored wall clock.
  static String timeOfDayKey(DateTime wallClock) => switch (wallClock.hour) {
    < 6 => 'Night',
    < 12 => 'Morning',
    < 18 => 'Afternoon',
    _ => 'Evening',
  };

  static FocusFactorId? _selfFactor(FocusMetric metric) => switch (metric) {
    FocusMetric.maxDepth => FocusFactorId.maxDepth,
    FocusMetric.bottomTime => FocusFactorId.duration,
    FocusMetric.weight => FocusFactorId.weight,
    FocusMetric.waterTemp => FocusFactorId.waterTemp,
    FocusMetric.rmv || FocusMetric.sac => null,
  };

  static double? _number(FocusFactorId id, FocusFactorRow r) => switch (id) {
    FocusFactorId.maxDepth => r.maxDepth,
    FocusFactorId.avgDepth => r.avgDepth,
    FocusFactorId.duration => r.durationMinutes,
    FocusFactorId.waterTemp => r.waterTemp,
    FocusFactorId.tankVolume => r.firstTankVolume,
    FocusFactorId.weight => r.weight,
    _ => null,
  };

  /// The values [r] carries for a categorical factor: one at most, except
  /// dive type, where a dive can be several types at once.
  static List<String> _categories(FocusFactorId id, FocusFactorRow r) =>
      id == FocusFactorId.diveType
      ? r.diveTypes.toSet().toList(growable: false)
      : [?_category(id, r)];

  static String? _category(FocusFactorId id, FocusFactorRow r) => switch (id) {
    FocusFactorId.visibility => r.visibilityKey,
    FocusFactorId.current => r.currentStrength,
    FocusFactorId.waterType => r.waterType,
    FocusFactorId.entryMethod => r.entryMethod,
    FocusFactorId.month => '${r.dateTime.month}',
    FocusFactorId.timeOfDay => timeOfDayKey(r.entryTime ?? r.dateTime),
    FocusFactorId.site => r.siteId,
    FocusFactorId.gas => r.gasClass,
    FocusFactorId.suit => r.suitKey,
    FocusFactorId.buddy => r.buddyKey,
    _ => null,
  };

  static NumericFactor _numeric(
    FocusFactorId id,
    List<FocusFactorRow> group,
    List<FocusFactorRow> baseline,
  ) {
    final g = [for (final r in group) ?_number(id, r)];
    final b = [for (final r in baseline) ?_number(id, r)];
    final gMean = _mean(g);
    final bMean = _mean(b);
    final sd = _sd(b, bMean);
    final standsOut =
        gMean != null &&
        bMean != null &&
        sd > 0 &&
        (gMean - bMean).abs() >= standoutDeviations * sd;
    return NumericFactor(
      id: id,
      groupCovered: g.length,
      groupSize: group.length,
      groupMean: gMean,
      baselineMean: bMean,
      standsOut: standsOut,
    );
  }

  static CategoricalFactor _categorical(
    FocusFactorId id,
    List<FocusFactorRow> group,
    List<FocusFactorRow> baseline,
  ) {
    // Counts dives per value, and the dives that recorded any value. Shares
    // are of those dives, so a dive with two types counts once under each
    // and the shares of a multi-valued factor can add up to more than 100%.
    ({Map<String, int> counts, int covered}) tally(List<FocusFactorRow> rows) {
      final out = <String, int>{};
      var covered = 0;
      for (final r in rows) {
        final keys = _categories(id, r);
        if (keys.isNotEmpty) covered++;
        for (final key in keys) {
          out[key] = (out[key] ?? 0) + 1;
        }
      }
      return (counts: out, covered: covered);
    }

    final gTally = tally(group);
    final bTally = tally(baseline);
    final g = gTally.counts;
    final b = bTally.counts;
    final gTotal = gTally.covered;
    final bTotal = bTally.covered;
    final labels = id == FocusFactorId.site
        ? {
            for (final r in [...baseline, ...group])
              if (r.siteId != null && r.siteName != null)
                r.siteId!: r.siteName!,
          }
        : const <String, String>{};

    final ranked = g.entries.toList()
      ..sort((x, y) {
        final c = y.value.compareTo(x.value);
        return c != 0 ? c : x.key.compareTo(y.key);
      });
    final top = [
      for (final e in ranked.take(topCategories))
        () {
          final groupShare = gTotal == 0 ? 0.0 : e.value / gTotal;
          final baselineShare = bTotal == 0 ? 0.0 : (b[e.key] ?? 0) / bTotal;
          return CategoryShare(
            key: e.key,
            label: labels[e.key],
            groupShare: groupShare,
            baselineShare: baselineShare,
            groupCount: e.value,
            standsOut:
                e.value >= standoutMinCount &&
                groupShare - baselineShare >= standoutSharePoints - 1e-9,
          );
        }(),
    ];
    return CategoricalFactor(
      id: id,
      groupCovered: gTotal,
      groupSize: group.length,
      top: List.unmodifiable(top),
    );
  }

  static double? _mean(List<double> values) => values.isEmpty
      ? null
      : values.fold<double>(0, (s, v) => s + v) / values.length;

  /// Population standard deviation; 0 for fewer than two values.
  static double _sd(List<double> values, double? mean) {
    if (mean == null || values.length < 2) return 0;
    final variance =
        values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
        values.length;
    return math.sqrt(variance);
  }
}
