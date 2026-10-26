import 'package:flutter/material.dart';

/// How a scrollbar thumb looks for one set of widget states, resolved from
/// the effective [ScrollbarTheme] with Material's per-platform defaults.
class ListScrubberThumbStyle {
  const ListScrubberThumbStyle({
    required this.thickness,
    required this.color,
    required this.radius,
    required this.crossAxisMargin,
  });

  final double thickness;
  final Color color;
  final Radius radius;
  final double crossAxisMargin;

  /// The states a scrubber in the given mode reports to the theme.
  static Set<WidgetState> statesFor({
    required bool active,
    required bool dragging,
  }) => {
    if (dragging) WidgetState.dragged,
    if (active && !dragging) WidgetState.hovered,
  };

  /// Mirrors the resolution in Flutter's Material `Scrollbar`.
  factory ListScrubberThumbStyle.resolve(
    BuildContext context,
    Set<WidgetState> states,
  ) {
    final theme = Theme.of(context);
    final scrollbar = ScrollbarTheme.of(context);
    final scheme = theme.colorScheme;
    final android = theme.platform == TargetPlatform.android;
    final onSurface = scheme.onSurface;
    final light = scheme.brightness == Brightness.light;

    Color alpha(double opacity) =>
        onSurface.withAlpha((255.0 * opacity).round());

    final Color fallback;
    if (states.contains(WidgetState.dragged)) {
      fallback = alpha(light ? 0.6 : 0.75);
    } else if (states.contains(WidgetState.hovered)) {
      fallback = alpha(light ? 0.5 : 0.65);
    } else if (android) {
      fallback = theme.highlightColor.withAlpha(255);
    } else {
      fallback = alpha(light ? 0.1 : 0.3);
    }

    final trackVisible = scrollbar.trackVisibility?.resolve(states) ?? false;
    final double fallbackThickness;
    if (states.contains(WidgetState.hovered) && trackVisible) {
      fallbackThickness = 12;
    } else {
      fallbackThickness = android ? 4 : 8;
    }

    return ListScrubberThumbStyle(
      thickness: scrollbar.thickness?.resolve(states) ?? fallbackThickness,
      color: scrollbar.thumbColor?.resolve(states) ?? fallback,
      radius:
          scrollbar.radius ??
          (android ? Radius.zero : const Radius.circular(8)),
      crossAxisMargin: scrollbar.crossAxisMargin ?? (android ? 0 : 2),
    );
  }
}
