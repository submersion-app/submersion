import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';

/// A stable default card colour for a new custom agency (issue #690): the
/// id's hash picks a tag palette colour, so a quick-created agency needs no
/// extra step and keeps its colour on every device.
int defaultAgencyColorArgb(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final hex = TagColors.predefined[hash % TagColors.predefined.length];
  return TagColors.fromHex(hex).toARGB32();
}

/// The gradient's second colour: the primary, lightened. Built-in agencies
/// carry a hand-picked secondary; custom ones derive it.
Color secondaryAgencyColor(Color primary) {
  final hsl = HSLColor.fromColor(primary);
  return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 0.85)).toColor();
}
