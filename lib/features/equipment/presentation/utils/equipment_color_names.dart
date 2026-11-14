import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/utils/color_hex.dart';

/// The name a diver and a screen reader know an item colour by: the
/// palette colour's localized name, or for any other `#RRGGBB` (a custom
/// colour, an import's, a peer's) the nearest palette name and the code,
/// "Orange (#FF6A00)" (issue #4537). A value that is not a colour code reads
/// as itself.
String equipmentColorName(AppLocalizations l10n, String hex) {
  final code = normalizeEquipmentColor(hex);
  if (code == null) return hex;
  return _paletteName(l10n, code) ??
      l10n.equipment_color_customName(
        _paletteName(l10n, nearestEquipmentColor(colorFromHex(code)))!,
        code,
      );
}

/// The palette colour's localized name, or null for a code off the palette.
String? _paletteName(AppLocalizations l10n, String code) {
  return switch (code) {
    '#EF4444' => l10n.equipment_color_red,
    '#F97316' => l10n.equipment_color_orange,
    '#F59E0B' => l10n.equipment_color_amber,
    '#EAB308' => l10n.equipment_color_yellow,
    '#84CC16' => l10n.equipment_color_lime,
    '#22C55E' => l10n.equipment_color_green,
    '#10B981' => l10n.equipment_color_emerald,
    '#14B8A6' => l10n.equipment_color_teal,
    '#06B6D4' => l10n.equipment_color_cyan,
    '#0EA5E9' => l10n.equipment_color_sky,
    '#3B82F6' => l10n.equipment_color_blue,
    '#6366F1' => l10n.equipment_color_indigo,
    '#8B5CF6' => l10n.equipment_color_violet,
    '#A855F7' => l10n.equipment_color_purple,
    '#D946EF' => l10n.equipment_color_fuchsia,
    '#EC4899' => l10n.equipment_color_pink,
    '#F43F5E' => l10n.equipment_color_rose,
    '#78716C' => l10n.equipment_color_stone,
    '#71717A' => l10n.equipment_color_zinc,
    '#64748B' => l10n.equipment_color_slate,
    equipmentColorBlack => l10n.equipment_color_black,
    equipmentColorWhite => l10n.equipment_color_white,
    _ => null,
  };
}

/// The palette code nearest [color], by CIE76 distance in Lab, which tracks
/// how different two colours look far better than RGB distance does.
String nearestEquipmentColor(Color color) {
  final target = _lab(color);
  var best = equipmentColorPalette.first;
  var bestDistance = double.infinity;
  for (final (i, hex) in equipmentColorPalette.indexed) {
    final d = _distance(target, _paletteLab[i]);
    if (d < bestDistance) {
      bestDistance = d;
      best = hex;
    }
  }
  return best;
}

/// The palette in Lab, worked out once: every custom swatch name searches it.
final List<List<double>> _paletteLab = [
  for (final hex in equipmentColorPalette) _lab(colorFromHex(hex)),
];

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
