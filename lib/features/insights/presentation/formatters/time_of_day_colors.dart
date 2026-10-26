import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';

/// The Time patterns chart's colour for each [TimeOfDayBucket] (issue
/// #3340): fixed hues, so a bucket reads the same under every theme preset,
/// with a lighter set for dark surfaces.
const Map<TimeOfDayBucket, Color> _lightColors = {
  TimeOfDayBucket.dawn: Color(0xFFE67E7D),
  TimeOfDayBucket.morning: Color(0xFFF4B41A),
  TimeOfDayBucket.afternoon: Color(0xFF2E8BC0),
  TimeOfDayBucket.dusk: Color(0xFF845EC2),
  TimeOfDayBucket.night: Color(0xFF14213D),
};

const Map<TimeOfDayBucket, Color> _darkColors = {
  TimeOfDayBucket.dawn: Color(0xFFFF9A9E),
  TimeOfDayBucket.morning: Color(0xFFFFE066),
  TimeOfDayBucket.afternoon: Color(0xFF00D2FC),
  TimeOfDayBucket.dusk: Color(0xFFD387FF),
  TimeOfDayBucket.night: Color(0xFFA2B2C8),
};

/// The colour for a time-of-day bucket [key] under [brightness].
///
/// Looked up by key, not by position in the chart, so a bucket keeps its
/// colour when the buckets before it have no dives. An unrecognized key can
/// only come from a repository change and is drawn grey, not as some other
/// bucket.
Color timeOfDayColor(String key, Brightness brightness) {
  final colors = brightness == Brightness.dark ? _darkColors : _lightColors;
  return colors[TimeOfDayBucket.fromKey(key)] ?? Colors.grey;
}
