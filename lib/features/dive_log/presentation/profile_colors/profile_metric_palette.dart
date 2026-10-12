import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// The colour each profile metric is drawn in for the active diver: their
/// chosen colours (deduped), else the defaults, with temperature's Auto
/// colour taken from the theme.
@immutable
class ProfileMetricPalette {
  ProfileMetricPalette({
    required ProfileMetricColorOverrides overrides,
    required this.temperatureAuto,
  }) : overrides = overrides.deduped();

  final ProfileMetricColorOverrides overrides;

  /// The theme's `colorScheme.tertiary`, temperature's Auto colour.
  final Color temperatureAuto;

  Color colorOf(ProfileMetric metric) {
    final argb = overrides.effectiveArgb(metric);
    if (argb != null) return Color(argb);
    return switch (metric) {
      ProfileMetric.temperature => temperatureAuto,
      // Pressure's Auto colour is per gas; this is its legend swatch.
      _ => ProfileMetricColors.pressure,
    };
  }

  /// The pressure colour the diver chose, which a single-tank dive's
  /// pressure line and threshold markers use; null while on Auto.
  Color? get pressureOverride {
    final argb = overrides.argbOf(ProfileMetric.pressure);
    return argb == null ? null : Color(argb);
  }

  /// The colour a dive's pressure line takes from the diver's choice: only on
  /// a dive with one tank and one pressure series. A dive with more tanks
  /// keeps its gas colours, even when only one tank has a transmitter.
  Color? pressureLineColor({
    required int pressureSeries,
    required int tankCount,
  }) =>
      pressureSeries == 1 &&
          isSingleTankDive(pressureSeries: pressureSeries, tankCount: tankCount)
      ? pressureOverride
      : null;

  /// Whether a dive has at most one tank and one pressure series: the only
  /// dives a chosen pressure colour applies to (issue #3012).
  static bool isSingleTankDive({
    required int pressureSeries,
    required int tankCount,
  }) => pressureSeries <= 1 && tankCount <= 1;

  /// The right Y axis's label colour for [metric]. Ascent rate and O2 cells
  /// are not recolourable and keep their own. Pressure shows the chosen
  /// colour only when [singleTank], since otherwise no line is drawn in it.
  Color rightAxisColor(
    ProfileRightAxisMetric metric, {
    bool singleTank = true,
  }) => switch (metric) {
    ProfileRightAxisMetric.temperature => colorOf(ProfileMetric.temperature),
    ProfileRightAxisMetric.pressure =>
      singleTank
          ? colorOf(ProfileMetric.pressure)
          : ProfileMetricColors.pressure,
    ProfileRightAxisMetric.heartRate => colorOf(ProfileMetric.heartRate),
    ProfileRightAxisMetric.sac => colorOf(ProfileMetric.sac),
    ProfileRightAxisMetric.ndl => colorOf(ProfileMetric.ndl),
    ProfileRightAxisMetric.ppO2 => colorOf(ProfileMetric.ppO2),
    ProfileRightAxisMetric.ppN2 => colorOf(ProfileMetric.ppN2),
    ProfileRightAxisMetric.ppHe => colorOf(ProfileMetric.ppHe),
    ProfileRightAxisMetric.gasDensity => colorOf(ProfileMetric.density),
    ProfileRightAxisMetric.gf => colorOf(ProfileMetric.gf),
    ProfileRightAxisMetric.surfaceGf => colorOf(ProfileMetric.surfaceGf),
    ProfileRightAxisMetric.meanDepth => colorOf(ProfileMetric.meanDepth),
    ProfileRightAxisMetric.tts => colorOf(ProfileMetric.tts),
    ProfileRightAxisMetric.cns => colorOf(ProfileMetric.cns),
    ProfileRightAxisMetric.otu => colorOf(ProfileMetric.otu),
    ProfileRightAxisMetric.gtr => colorOf(ProfileMetric.gtr),
    ProfileRightAxisMetric.ascentRate ||
    ProfileRightAxisMetric.o2CellMv => metric.color ?? temperatureAuto,
  };
}
