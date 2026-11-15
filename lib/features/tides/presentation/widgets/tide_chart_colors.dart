import 'package:flutter/material.dart';

/// The marks on a tide chart: high water, low water, and the dive.
///
/// Fixed hues rather than ColorScheme roles, for the reason `StatusColors`
/// gives: the theme presets do not all set `tertiary`, so a role can land on
/// the same colour as the curve. Each hue has a darker value for a light
/// card and a lighter one for a dark card, because the chart prints its
/// labels in these colours and they have to stay readable as text.
@immutable
class TideChartColors {
  const TideChartColors({
    required this.high,
    required this.low,
    required this.dive,
    required this.onDive,
  });

  /// High water: its dot and its label.
  final Color high;

  /// Low water: its dot and its label.
  final Color low;

  /// The dive: its band, its entry line and the fill of its time marker.
  final Color dive;

  /// Text and icon drawn on a solid [dive] fill.
  final Color onDive;

  static const light = TideChartColors(
    high: Color(0xFFC62828),
    low: Color(0xFF1565C0),
    dive: Color(0xFF00796B),
    onDive: Color(0xFFFFFFFF),
  );

  static const dark = TideChartColors(
    high: Color(0xFFFF8A80),
    low: Color(0xFF90CAF9),
    dive: Color(0xFF80CBC4),
    onDive: Color(0xFF00332E),
  );

  static TideChartColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
