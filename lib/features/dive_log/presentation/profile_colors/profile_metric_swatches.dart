import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// Every colour a diver can give a profile metric (issue #3012), in the order
/// the picker shows them: the 18 fixed metric defaults, the two colours the
/// events and ascent-rate swatches keep, then six extras. Its length must
/// exceed the number of metrics so a swap always finds a free colour.
const List<Color> profileMetricSwatches = [
  ProfileMetricColors.depth,
  ProfileMetricColors.heartRate,
  ProfileMetricColors.sac,
  ProfileMetricColors.maxDepth,
  ProfileMetricColors.ceiling,
  ProfileMetricColors.ndl,
  ProfileMetricColors.tts,
  ProfileMetricColors.gtr,
  ProfileMetricColors.cns,
  ProfileMetricColors.otu,
  ProfileMetricColors.ppO2,
  ProfileMetricColors.ppN2,
  ProfileMetricColors.ppHe,
  ProfileMetricColors.mod,
  ProfileMetricColors.density,
  ProfileMetricColors.gf,
  ProfileMetricColors.surfaceGf,
  ProfileMetricColors.meanDepth,
  ProfileMetricColors.events,
  ProfileMetricColors.ascentRateLine,
  Color(0xFF689F38), // Light Green 700
  Color(0xFFFF7043), // Deep Orange 400
  Color(0xFF29B6F6), // Light Blue 400
  Color(0xFFE040FB), // Purple A200
  Color(0xFFF50057), // Pink A400
  Color(0xFF00E676), // Green A400
];
