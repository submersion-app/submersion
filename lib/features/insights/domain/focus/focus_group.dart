import 'package:flutter/foundation.dart';

import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// The dives a [FocusSelection] picked, and the dives it picked from.
@immutable
class FocusGroup {
  const FocusGroup({required this.members, required this.population});

  /// The selected dives in display order: rank order for a ranked mode,
  /// newest first for a threshold.
  final List<TrendDataPoint> members;

  /// Every dive that has the metric: the group's comparison baseline.
  final List<TrendDataPoint> population;

  Set<String> get memberIds => {for (final m in members) m.diveId!};

  double? get memberMean => _mean(members);
  double? get populationMean => _mean(population);

  double? get populationMin => population.isEmpty
      ? null
      : population.map((p) => p.value).reduce((a, b) => a < b ? a : b);

  double? get populationMax => population.isEmpty
      ? null
      : population.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  static double? _mean(List<TrendDataPoint> points) => points.isEmpty
      ? null
      : points.fold<double>(0, (sum, p) => sum + p.value) / points.length;
}

/// Picks the group [selection] describes from a per-dive [series].
///
/// Ties at a ranked cut-off break newest first, so the same data always
/// yields the same group.
FocusGroup selectFocusGroup(
  List<TrendDataPoint> series,
  FocusSelection selection,
) {
  final population = [
    for (final p in series)
      if (p.diveId != null) p,
  ];
  int newestFirst(TrendDataPoint a, TrendDataPoint b) =>
      b.date.compareTo(a.date);
  final threshold = selection.threshold;

  final List<TrendDataPoint> members;
  switch (selection.mode) {
    case FocusMode.lowest:
      members =
          (List.of(population)..sort((a, b) {
                final c = a.value.compareTo(b.value);
                return c != 0 ? c : newestFirst(a, b);
              }))
              .take(selection.count)
              .toList(growable: false);
    case FocusMode.highest:
      members =
          (List.of(population)..sort((a, b) {
                final c = b.value.compareTo(a.value);
                return c != 0 ? c : newestFirst(a, b);
              }))
              .take(selection.count)
              .toList(growable: false);
    case FocusMode.above:
      members = threshold == null
          ? const []
          : (population.where((p) => p.value > threshold).toList()
              ..sort(newestFirst));
    case FocusMode.below:
      members = threshold == null
          ? const []
          : (population.where((p) => p.value < threshold).toList()
              ..sort(newestFirst));
  }
  return FocusGroup(
    members: List.unmodifiable(members),
    population: List.unmodifiable(population),
  );
}
