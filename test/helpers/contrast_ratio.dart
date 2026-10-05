import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast ratio between two opaque colors, from 1 (identical
/// luminance) to 21 (black on white). Blend a translucent color over its
/// backdrop with [Color.alphaBlend] first.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
