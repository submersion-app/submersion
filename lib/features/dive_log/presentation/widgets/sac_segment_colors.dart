import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// The colors shared by the time chart and the rows beneath it, so a column
/// and its phase read as the same thing and the rows double as the legend.
///
/// The hues name a phase and say nothing about how it went, so ascent keeps
/// clear of the green, yellow and red a dive computer uses for ascent rate,
/// and no phase wears red. They were checked for color vision deficiency
/// across the phases that can share an edge. Descent rarely meets deco, which
/// is what lets those two sit closer than the others. Picking a column also
/// marks its phase row, so nothing depends on color alone.
abstract final class SacSegmentColors {
  /// How much of the hue a column keeps until it is selected.
  static const double _idleStrength = 0.65;

  /// How much of the hue a row's bar keeps, low enough for the label on it.
  static const double _barStrength = 0.4;

  static Color forPhase(DivePhase phase, Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (phase) {
      DivePhase.descent => Color(light ? 0xFF2A78D6 : 0xFF3987E5),
      DivePhase.bottom => const Color(0xFF008300),
      DivePhase.ascent => Color(light ? 0xFFE87BA4 : 0xFFD55181),
      DivePhase.safetyStop => Color(light ? 0xFFEDA100 : 0xFFC98500),
      DivePhase.deco => Color(light ? 0xFF6250D6 : 0xFF9085E9),
    };
  }

  /// A column that isn't selected: quieter than the selected column's full
  /// [hue].
  static Color idle(Color hue, ThemeData theme) =>
      _onCard(hue.withValues(alpha: _idleStrength), theme);

  /// The bar behind a row's label.
  static Color barFill(Color hue, ThemeData theme) =>
      _onCard(hue.withValues(alpha: _barStrength), theme);

  /// [tint] resolved to the opaque color it paints on the card. A preset's
  /// card can itself be translucent, so that goes over the surface first.
  static Color _onCard(Color tint, ThemeData theme) {
    final scheme = theme.colorScheme;
    final card = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    return Color.alphaBlend(tint, Color.alphaBlend(card, scheme.surface));
  }
}
