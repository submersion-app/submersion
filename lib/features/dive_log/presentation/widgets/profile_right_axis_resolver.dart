import 'package:submersion/core/constants/profile_metrics.dart';

/// The metric the profile chart's right axis shows, given [preferred] (the
/// diver's pick, else the settings default) and [isDrawn], which says whether
/// a metric's line is on the chart right now (toggled on and with data).
///
/// The axis labels a line the diver can see (issue #5012): [preferred] while
/// its line is drawn, else the first drawn metric in
/// [ProfileRightAxisMetric.fallbackPriority], else any other drawn metric in
/// declaration order. With only depth drawn there is no right axis, so null.
///
/// Ascent rate is never a fallback: its bars come from their own overlay, not
/// from a line drawn against this scale, so the axis menu leaves it out too.
/// [preferred] is never stored back, so turning its line on again returns
/// the axis to it.
ProfileRightAxisMetric? resolveRightAxisMetric(
  ProfileRightAxisMetric preferred, {
  required bool Function(ProfileRightAxisMetric metric) isDrawn,
}) {
  if (isDrawn(preferred)) return preferred;
  for (final metric in ProfileRightAxisMetric.fallbackPriority) {
    if (isDrawn(metric)) return metric;
  }
  for (final metric in ProfileRightAxisMetric.values) {
    if (metric != ProfileRightAxisMetric.ascentRate && isDrawn(metric)) {
      return metric;
    }
  }
  return null;
}
