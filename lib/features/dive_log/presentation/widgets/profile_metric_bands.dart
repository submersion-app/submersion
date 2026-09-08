import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// The scale and stroke one metric is drawn with on the profile chart.
///
/// The active computer's trace and every overlaid computer's trace of the
/// same metric are meant to be read against each other, which only works if
/// both are plotted on the same scale. They used to declare that scale, and
/// their dash pattern, separately: changing the active ppN2 band to 6 bar
/// would silently leave the overlay plotting on the old 0-5 band, and the
/// comparison the overlay exists for would be wrong with nothing to show for
/// it. Both read this instead.
@immutable
class ProfileMetricBand {
  /// Bottom of the plotted range, in the metric's own units.
  final double min;

  /// Top of the plotted range, or null where the metric has no fixed one and
  /// the caller supplies the mapping.
  ///
  /// Null for two different reasons: CNS and OTU are scaled to the dive, so
  /// their maximum is computed at render time; MOD and mean depth are not
  /// band-mapped at all, being plotted in the profile's own depth unit, and
  /// take only a colour and a dash pattern from here.
  final double? max;

  final Color color;

  /// Dash pattern, so traces that overlap stay tellable apart when several
  /// are switched on at once.
  ///
  /// Not unique on its own: NDL and CNS both use [6, 3]. Colour is what
  /// separates every metric from every other, and the dash is a second cue on
  /// top of it, which matters most where colour is unreliable (an overlay's
  /// traces are tinted from the metric colour, and print or a colour-vision
  /// deficiency flattens hues). Two metrics may share a pattern; they may not
  /// share a colour.
  final List<int> dashArray;

  const ProfileMetricBand({
    required this.min,
    required this.max,
    required this.color,
    required this.dashArray,
  });

  /// [max] for the metrics that have a fixed one.
  ///
  /// Throws where [max] is null rather than substituting a default: a caller
  /// reaching for this on a runtime-scaled or depth-mapped metric has
  /// mistaken it for a fixed-band one, and a silent fallback would plot it on
  /// the wrong axis.
  double get fixedMax =>
      max ?? (throw StateError('this metric has no fixed maximum'));
}

/// The metrics an overlaid computer can draw alongside the active one.
///
/// Deliberately not every curve on the chart: depth, tank pressure, heart
/// rate, SAC and the markers are drawn for the active source only, are styled
/// where they are built, and are absent here. What earns an entry is being
/// comparable across computers, because that is what forces the active trace
/// and the overlay onto one definition.
///
/// Most entries are band-mapped, sharing the right-hand axis through
/// [ProfileMetricBand.min] and [ProfileMetricBand.max]. MOD and mean depth are
/// plotted in the profile's depth unit instead and appear here only so their
/// colour and dash pattern have a single definition too.
abstract final class ProfileMetricBands {
  /// Seconds-based metrics share a 60 minute ceiling; longer readings clamp.
  static const double _oneHourSeconds = 3600.0;

  static const ndl = ProfileMetricBand(
    min: 0,
    max: _oneHourSeconds,
    color: ProfileMetricColors.ndl,
    dashArray: [6, 3],
  );
  static const tts = ProfileMetricBand(
    min: 0,
    max: _oneHourSeconds,
    color: ProfileMetricColors.tts,
    dashArray: [5, 4],
  );
  static const gtr = ProfileMetricBand(
    min: 0,
    max: _oneHourSeconds,
    color: ProfileMetricColors.gtr,
    dashArray: [2, 4],
  );

  static const ppO2 = ProfileMetricBand(
    min: 0,
    max: 2.0,
    color: ProfileMetricColors.ppO2,
    dashArray: [5, 3],
  );
  static const ppN2 = ProfileMetricBand(
    min: 0,
    max: 5.0,
    color: ProfileMetricColors.ppN2,
    dashArray: [4, 2],
  );
  static const ppHe = ProfileMetricBand(
    min: 0,
    max: 3.0,
    color: ProfileMetricColors.ppHe,
    dashArray: [3, 3],
  );

  static const density = ProfileMetricBand(
    min: 0,
    max: 8.0,
    color: ProfileMetricColors.density,
    dashArray: [5, 2],
  );

  /// Gradient factor, plotted to 120% so an over-pressure excursion is still
  /// on the chart rather than pinned to the axis.
  static const gf = ProfileMetricBand(
    min: 0,
    max: 120.0,
    color: ProfileMetricColors.gf,
    dashArray: [4, 3],
  );

  /// Surface gradient factor runs higher than in-water GF, so it gets more
  /// headroom than [gf].
  static const surfaceGf = ProfileMetricBand(
    min: 0,
    max: 150.0,
    color: ProfileMetricColors.surfaceGf,
    dashArray: [6, 2],
  );

  static const mod = ProfileMetricBand(
    min: 0,
    max: null,
    color: ProfileMetricColors.mod,
    dashArray: [8, 4],
  );
  static const meanDepth = ProfileMetricBand(
    min: 0,
    max: null,
    color: ProfileMetricColors.meanDepth,
    dashArray: [3, 4],
  );

  /// Scaled to the dive: a 5% CNS load and a 95% one need different axes to
  /// both be readable.
  static const cns = ProfileMetricBand(
    min: 0,
    max: null,
    color: ProfileMetricColors.cns,
    dashArray: [6, 3],
  );
  static const otu = ProfileMetricBand(
    min: 0,
    max: null,
    color: ProfileMetricColors.otu,
    dashArray: [4, 4],
  );
}
