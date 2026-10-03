import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Space between an app bar title and tabs placed inline beside it.
const double kAppBarInlineTabGap = 24;

/// Whether [title] and a scrollable tab strip of [labels] fit side by side
/// in the title slot of an [AppBar] [barWidth] wide.
///
/// Mirrors how the framework sizes that slot rather than guessing a
/// breakpoint: [NavigationToolbar] gives the title the bar width minus the
/// leading slot (present when the route can be dismissed) and its spacing on
/// both sides, after the app bar's [SafeArea] has given up any horizontal
/// insets. Each tab is its label plus [kTabLabelPadding], the layout a
/// scrollable [TabBar] with [TabAlignment.start] uses. Measuring the labels
/// with the user's text scale is what keeps a long translation or large text
/// from cramming the tabs into a strip that scrolls.
///
/// [labelStyle] must be the style the [TabBar] is given, so the measurement
/// and the rendered tabs agree.
bool appBarTabsFitInline(
  BuildContext context, {
  required double barWidth,
  required String title,
  required List<String> labels,
  required TextStyle labelStyle,
}) {
  final theme = Theme.of(context);
  final appBarTheme = theme.appBarTheme;
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);

  double widthOf(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  // AppBar's own precedence: a theme's titleTextStyle replaces titleLarge
  // outright rather than merging into it.
  final titleStyle = appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  final tabsWidth = labels.fold<double>(
    0,
    (sum, label) =>
        sum + widthOf(label, labelStyle) + kTabLabelPadding.horizontal,
  );
  final required = widthOf(title, titleStyle) + kAppBarInlineTabGap + tabsWidth;

  final hasLeading = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final leadingWidth = hasLeading
      ? appBarTheme.leadingWidth ?? kToolbarHeight
      : 0.0;
  final spacing = appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
  final available =
      barWidth -
      MediaQuery.paddingOf(context).horizontal -
      leadingWidth -
      spacing * 2;

  return required <= available;
}

/// Label and indicator colours for a [TabBar] drawn on the app bar surface.
///
/// A stock tab marks the selected label in `colorScheme.primary`, which
/// several presets also use as the app bar background (Tropical), so tabs
/// moved onto the bar would vanish there. The selected label keeps `primary`
/// wherever it reaches WCAG AA on the bar, the stock look, and otherwise
/// takes the bar's own foreground, the colour its title is legible in.
/// Unselected labels are always the foreground dimmed toward the background.
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
    final foreground =
        appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final background = Color.alphaBlend(
      appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      theme.scaffoldBackgroundColor,
    );
    final primary = theme.colorScheme.primary;
    return AppBarTabColors(
      barMatchesPage: background == theme.scaffoldBackgroundColor,
      selected: _contrast(primary, background) >= _aaContrast
          ? primary
          : foreground,
      unselected: Color.alphaBlend(
        foreground.withValues(alpha: _unselectedAlpha),
        background,
      ),
    );
  }

  /// WCAG AA contrast for normal-size text.
  static const double _aaContrast = 4.5;

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// How much of the foreground an unselected label keeps. Low enough to
  /// read as unselected, high enough to keep WCAG AA (4.5:1) on every preset
  /// whose own title meets it.
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
}
