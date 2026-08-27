import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';

/// Icon for a compact weather glyph, or null when there is nothing to show.
///
/// Active precipitation outranks cloud cover: a rainy overcast day reads as
/// rain. [Precipitation.none] is real data ("no precipitation") but earns no
/// glyph of its own, so it falls through to the cloud cover.
IconData? weatherIconFor({
  CloudCover? cloudCover,
  Precipitation? precipitation,
}) {
  switch (precipitation) {
    case Precipitation.drizzle:
    case Precipitation.lightRain:
      return Icons.water_drop_outlined;
    case Precipitation.rain:
    case Precipitation.heavyRain:
      return Icons.water_drop;
    case Precipitation.snow:
      return Icons.ac_unit;
    case Precipitation.sleet:
      return Icons.cloudy_snowing;
    case Precipitation.hail:
      return Icons.grain;
    case Precipitation.none:
    case null:
      break;
  }
  switch (cloudCover) {
    case CloudCover.clear:
      return Icons.wb_sunny_outlined;
    case CloudCover.partlyCloudy:
      return Icons.wb_cloudy_outlined;
    case CloudCover.mostlyCloudy:
      return Icons.cloud_outlined;
    case CloudCover.overcast:
      return Icons.cloud;
    case null:
      return null;
  }
}
