import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Label and indicator colours for a [TabBar] drawn on the app bar surface.
///
/// A stock tab marks the selected label in `colorScheme.primary`, which
/// several presets also use as the app bar background (Tropical), so tabs
/// moved onto the bar would vanish there. The selected label keeps `primary`
/// wherever it reaches WCAG AA on the bar, the stock look, and otherwise
/// takes the bar's own foreground, the colour its title is legible in.
/// Unselected labels are the foreground dimmed toward the background, as far
/// as WCAG AA allows.
/// Both are judged against the background the bar actually shows, so a
/// translucent bar (Minimalist) is read over the scaffold beneath it.
@immutable
class AppBarTabColors {
  const AppBarTabColors({
    required this.selected,
    required this.unselected,
    required this.barMatchesPage,
  });

  factory AppBarTabColors.of(ThemeData theme) {
    final appBarTheme = theme.appBarTheme;
    return AppBarTabColors.on(
      theme,
      background: Color.alphaBlend(
        appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        theme.scaffoldBackgroundColor,
      ),
      foreground: appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
    );
  }

  /// The same colours for tabs on a bar of its own opaque [background], with
  /// [foreground] its title colour: a desktop list pane's header, say, which
  /// is drawn in the scheme's surface whatever colour the app bar takes.
  factory AppBarTabColors.on(
    ThemeData theme, {
    required Color background,
    required Color foreground,
  }) {
    final primary = theme.colorScheme.primary;
    return AppBarTabColors(
      barMatchesPage: background == theme.scaffoldBackgroundColor,
      selected: _contrast(primary, background) >= _aaContrast
          ? primary
          : foreground,
      unselected: _dimmed(foreground, background),
    );
  }

  /// [foreground] dimmed toward [background] by [_unselectedAlpha], or less
  /// where that would drop it under WCAG AA: a bar whose title has little
  /// headroom over 4.5:1 (Tropical light, 5.04:1) keeps its unselected labels
  /// nearly full strength and leaves the indicator to mark the selection.
  static Color _dimmed(Color foreground, Color background) {
    for (var alpha = _unselectedAlpha; alpha < 1; alpha += 0.02) {
      final dimmed = Color.alphaBlend(
        foreground.withValues(alpha: alpha),
        background,
      );
      if (_contrast(dimmed, background) >= _aaContrast) return dimmed;
    }
    return foreground;
  }

  /// WCAG AA contrast for normal-size text.
  static const double _aaContrast = 4.5;

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// How much of the foreground an unselected label keeps where the bar has
  /// the headroom: low enough to read as unselected. [_dimmed] raises it
  /// where WCAG AA (4.5:1) needs more.
  static const double _unselectedAlpha = 0.8;

  final Color selected;
  final Color unselected;

  /// Whether the bar shows the same colour as the page beneath it. Only then
  /// does a tab strip on the bar's bottom edge need a divider to separate it
  /// from the content; a coloured bar's own edge already does.
  final bool barMatchesPage;

  /// Hover, focus and press ink in the foreground's hue, for the same reason
  /// the labels avoid `primary`.
  WidgetStateProperty<Color?> get overlay =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return selected.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return selected.withValues(alpha: 0.08);
        }
        return null;
      });

  /// Style for a [TextButton] on the app bar (a Done or Cancel action), in
  /// the selected tab colour for the same reason the labels avoid `primary`.
  /// Disabled, it is that colour dimmed rather than Material's onSurface tint,
  /// which is dark ink on a dark bar.
  ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: selected,
    disabledForegroundColor: selected.withValues(alpha: 0.38),
  ).copyWith(overlayColor: overlay);
}
