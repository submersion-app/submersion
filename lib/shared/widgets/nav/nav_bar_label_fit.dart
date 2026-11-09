import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Smallest font size, in logical pixels before text scaling, that the
/// bottom bar shrinks its labels to. Material 3 draws them at 12.
const double kNavBarLabelMinFontSize = 9;

/// Largest text scale NavigationBar draws its labels at, however large the
/// system text setting; mirrors the framework's private limit.
const double kNavBarLabelMaxTextScaleFactor = 1.3;

/// Width kept free beside the widest word, so rounding in text layout never
/// pushes a word that was measured to fit onto a second line.
const double _kSlack = 1;

final RegExp _whitespace = RegExp(r'\s+');

/// Returns the factor (at most 1) to multiply every bottom-bar label's font
/// size by so that no word of any label is wider than one destination slot.
///
/// NavigationBar draws each label as a plain Text inside its slot, so a
/// word wider than the slot breaks between two letters (#4336). Words are
/// measured rather than whole labels: a label of several words may still
/// wrap at a space, which reads naturally, while a single long word never
/// splits. Every label in the bar shares the one factor so the bar keeps a
/// single type size.
///
/// [styles] are the label styles the bar can draw (selected, unselected);
/// the widest of them decides. The result never takes a style below
/// [minFontSize], and never grows a style that already sits below it.
double fitNavBarLabelScale({
  required Iterable<String> labels,
  required Iterable<TextStyle> styles,
  required double slotWidth,
  required TextScaler textScaler,
  required TextDirection textDirection,
  double minFontSize = kNavBarLabelMinFontSize,
}) {
  final available = slotWidth - _kSlack;
  if (available <= 0) return 1;
  final words = {
    for (final label in labels)
      ...label.split(_whitespace).where((word) => word.isNotEmpty),
  };
  if (words.isEmpty) return 1;

  var scale = 1.0;
  for (final style in styles) {
    // A style without a size cannot be scaled, so it has no say.
    final fontSize = style.fontSize;
    if (fontSize == null || fontSize <= 0) continue;
    final widest = _widestWord(words, style, textScaler, textDirection);
    if (widest <= available) continue;
    final floor = math.min(1.0, minFontSize / fontSize);
    scale = math.min(scale, math.max(floor, available / widest));
  }
  return scale;
}

double _widestWord(
  Set<String> words,
  TextStyle style,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  );
  var widest = 0.0;
  for (final word in words) {
    painter
      ..text = TextSpan(text: word, style: style)
      ..layout();
    widest = math.max(widest, painter.width);
  }
  painter.dispose();
  return widest;
}

/// The label style NavigationBar uses by default under Material 3, for
/// [states]: labelMedium coloured by selection.
TextStyle? _defaultLabelStyle(ThemeData theme, Set<WidgetState> states) {
  final colors = theme.colorScheme;
  final color = states.contains(WidgetState.disabled)
      ? colors.onSurfaceVariant.withValues(alpha: 0.38)
      : states.contains(WidgetState.selected)
      ? colors.onSurface
      : colors.onSurfaceVariant;
  return theme.textTheme.labelMedium?.apply(color: color);
}

/// Returns a label style for a bottom bar of [labels] spread across
/// [barWidth], shrunk so no word splits, or null when every word already
/// fits and the bar should keep its own default style.
///
/// [barWidth] is the full width the bar is given; the horizontal safe-area
/// insets that the bar pads itself by are taken off before it is shared
/// between the destinations.
WidgetStateProperty<TextStyle?>? fittedNavBarLabelTextStyle(
  BuildContext context, {
  required List<String> labels,
  required double barWidth,
}) {
  if (labels.isEmpty) return null;
  final theme = Theme.of(context);
  final themed = NavigationBarTheme.of(context).labelTextStyle;
  TextStyle? styleFor(Set<WidgetState> states) =>
      themed?.resolve(states) ?? _defaultLabelStyle(theme, states);

  final padding = MediaQuery.paddingOf(context);
  final slotWidth = (barWidth - padding.horizontal) / labels.length;
  final scale = fitNavBarLabelScale(
    labels: labels,
    styles: [
      styleFor(const {WidgetState.selected}),
      styleFor(const <WidgetState>{}),
    ].nonNulls,
    slotWidth: slotWidth,
    textScaler: MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kNavBarLabelMaxTextScaleFactor),
    textDirection: Directionality.of(context),
  );
  if (scale >= 1) return null;

  return WidgetStateProperty.resolveWith((states) {
    final style = styleFor(states);
    final fontSize = style?.fontSize;
    return fontSize == null
        ? style
        : style!.copyWith(fontSize: fontSize * scale);
  });
}
