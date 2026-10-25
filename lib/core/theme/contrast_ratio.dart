import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.x contrast ratio between two colours: 1 for identical, 21 for black
/// on white. Alpha is ignored, so blend a translucent colour over its
/// backdrop with [Color.alphaBlend] first.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
