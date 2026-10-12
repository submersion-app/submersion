import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know [color] by: the nearest (CIE76)
/// of the app's named equipment colours. None of the profile swatches is an
/// equipment colour exactly, so an exact lookup would name none of them.
String swatchName(AppLocalizations l10n, Color color) {
  final target = _lab(color);
  var best = equipmentColorPalette.first;
  var bestDistance = double.infinity;
  for (final hex in equipmentColorPalette) {
    final d = _distance(target, _lab(TagColors.fromHex(hex)));
    if (d < bestDistance) {
      bestDistance = d;
      best = hex;
    }
  }
  return equipmentColorName(l10n, best);
}

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> _lab(Color c) {
  final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double _distance(List<double> a, List<double> b) => math.sqrt(
  math.pow(a[0] - b[0], 2) +
      math.pow(a[1] - b[1], 2) +
      math.pow(a[2] - b[2], 2),
);
