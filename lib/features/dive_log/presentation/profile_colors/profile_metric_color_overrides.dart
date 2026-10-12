import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';

/// The profile-metric colours a diver chose (issue #3012): only the metrics
/// they changed, as ARGB ints. A metric absent here shows its default, or
/// its automatic colour when it [ProfileMetric.isAuto].
///
/// Colours stay unique across metrics: [withColor] swaps a taken colour, and
/// [deduped] repairs a clash that per-field sync conflict resolution can
/// leave behind.
@immutable
class ProfileMetricColorOverrides {
  const ProfileMetricColorOverrides() : _argb = const {};

  ProfileMetricColorOverrides._of(Map<ProfileMetric, int> argb)
    : _argb = Map.unmodifiable(argb);

  /// From stored column values: nulls, fully transparent values and values
  /// equal to the metric's own default are dropped. A colour outside the
  /// palette is kept, since a newer build may offer more swatches.
  factory ProfileMetricColorOverrides.fromArgb(
    Map<ProfileMetric, int?> stored,
  ) {
    final kept = <ProfileMetric, int>{};
    for (final entry in stored.entries) {
      final raw = entry.value;
      if (raw == null) continue;
      final argb = raw & 0xFFFFFFFF;
      if ((argb >> 24) == 0) continue;
      _put(kept, entry.key, argb);
    }
    return kept.isEmpty ? none : ProfileMetricColorOverrides._of(kept);
  }

  static const ProfileMetricColorOverrides none = ProfileMetricColorOverrides();

  final Map<ProfileMetric, int> _argb;

  bool get isEmpty => _argb.isEmpty;

  /// How many metrics carry a chosen colour.
  int get count => _argb.length;

  /// An exact key for memo signatures: every chosen colour in enum order.
  /// Unlike [hashCode] it cannot collide, so two colour sets are never
  /// served each other's cached chart series.
  String get cacheKey => [
    for (final metric in ProfileMetric.values)
      if (_argb[metric] case final argb?) '${metric.index}:$argb',
  ].join(',');

  /// The chosen colour for [metric], or null when it shows its default.
  int? argbOf(ProfileMetric metric) => _argb[metric];

  /// The colour [metric] shows: its override, else its fixed default. Null
  /// for an Auto metric left on Auto, which shows no palette colour.
  int? effectiveArgb(ProfileMetric metric) => _effective(_argb, metric);

  /// The metric other than [except] that shows [argb], if any.
  ProfileMetric? holderOf(int argb, {ProfileMetric? except}) =>
      _holder(_argb, argb, except: except);

  /// [metric] takes [color]; null means its default, or Auto.
  ///
  /// A metric already showing the colour receives the colour [metric] was
  /// showing, or, when [metric] was on Auto, the first swatch nobody shows.
  /// Any metric left holding its own default stores no override.
  ProfileMetricColorOverrides withColor(ProfileMetric metric, Color? color) {
    final base = deduped();
    final target = color?.toARGB32() ?? metric.defaultColor?.toARGB32();
    final next = Map<ProfileMetric, int>.of(base._argb);
    if (target == null) {
      // Auto: no other metric can be showing "no colour", so nothing swaps.
      next.remove(metric);
      return _from(next, base);
    }
    final previous = base.effectiveArgb(metric);
    if (previous == target) return base;
    final holder = base.holderOf(target, except: metric);
    _put(next, metric, target);
    if (holder != null) {
      _put(next, holder, previous ?? _firstFree(next));
    }
    return _from(next, base);
  }

  /// Every metric showing a distinct colour: the first metric, in enum order,
  /// keeps a shared colour and each later one moves to the first free swatch.
  /// Returns this object when nothing clashes.
  ProfileMetricColorOverrides deduped() {
    final next = Map<ProfileMetric, int>.of(_argb);
    final seen = <int>{};
    var changed = false;
    for (final metric in ProfileMetric.values) {
      final shown = _effective(next, metric);
      if (shown == null) continue;
      if (seen.add(shown)) continue;
      final free = _firstFree(next);
      _put(next, metric, free);
      seen.add(free);
      changed = true;
    }
    return changed ? _from(next, this) : this;
  }

  static ProfileMetricColorOverrides _from(
    Map<ProfileMetric, int> argb,
    ProfileMetricColorOverrides same,
  ) {
    if (mapEquals(argb, same._argb)) return same;
    return argb.isEmpty ? none : ProfileMetricColorOverrides._of(argb);
  }

  static int? _effective(Map<ProfileMetric, int> argb, ProfileMetric metric) =>
      argb[metric] ?? metric.defaultColor?.toARGB32();

  static ProfileMetric? _holder(
    Map<ProfileMetric, int> argb,
    int target, {
    ProfileMetric? except,
  }) {
    for (final other in ProfileMetric.values) {
      if (other != except && _effective(argb, other) == target) return other;
    }
    return null;
  }

  /// Stores [argb] for [metric], or clears it when it is the default.
  static void _put(
    Map<ProfileMetric, int> argb,
    ProfileMetric metric,
    int value,
  ) {
    if (value == metric.defaultColor?.toARGB32()) {
      argb.remove(metric);
    } else {
      argb[metric] = value;
    }
  }

  static int _firstFree(Map<ProfileMetric, int> argb) {
    final used = <int>{
      for (final metric in ProfileMetric.values) ?_effective(argb, metric),
    };
    for (final swatch in profileMetricSwatches) {
      final value = swatch.toARGB32();
      if (!used.contains(value)) return value;
    }
    // Unreachable: profile_metric_swatches_test pins more swatches than
    // metrics.
    // coverage:ignore-start
    throw StateError('the palette must outnumber the metrics');
    // coverage:ignore-end
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileMetricColorOverrides && mapEquals(other._argb, _argb);

  @override
  int get hashCode => Object.hashAllUnordered(
    _argb.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
