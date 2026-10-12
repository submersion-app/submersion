import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// A profile-chart metric whose colour a diver can choose (issue #3012).
///
/// Metrics whose colour carries its own meaning are absent: the ascent-rate
/// bands and bars, the deco-stop band, O2 cell traces, gas-switch markers,
/// event lines (severity colours) and multi-tank pressure lines (gas colours).
enum ProfileMetric {
  depth(ProfileMetricColors.depth),

  /// Auto: follows the theme's `colorScheme.tertiary`.
  temperature(null),

  /// Auto: each tank's gas colour. A chosen colour applies on a single-tank
  /// dive only.
  pressure(null),
  heartRate(ProfileMetricColors.heartRate),
  sac(ProfileMetricColors.sac),
  maxDepth(ProfileMetricColors.maxDepth),
  ceiling(ProfileMetricColors.ceiling),
  ndl(ProfileMetricColors.ndl),
  tts(ProfileMetricColors.tts),
  gtr(ProfileMetricColors.gtr),
  cns(ProfileMetricColors.cns),
  otu(ProfileMetricColors.otu),
  ppO2(ProfileMetricColors.ppO2),
  ppN2(ProfileMetricColors.ppN2),
  ppHe(ProfileMetricColors.ppHe),
  mod(ProfileMetricColors.mod),
  density(ProfileMetricColors.density),
  gf(ProfileMetricColors.gf),
  surfaceGf(ProfileMetricColors.surfaceGf),
  meanDepth(ProfileMetricColors.meanDepth);

  const ProfileMetric(this.defaultColor);

  /// The colour shipped for this metric, or null for an Auto metric.
  final Color? defaultColor;

  bool get isAuto => defaultColor == null;

  /// The `diver_settings` column (Dart name) and sync key holding this
  /// metric's colour, e.g. `profileColorPpO2`.
  String get settingsKey =>
      'profileColor${name[0].toUpperCase()}${name.substring(1)}';
}
