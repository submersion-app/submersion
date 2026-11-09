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

/// Runs of whitespace text layout may break a line at. The no-break spaces
/// (U+00A0, U+2007, U+202F) are left out: a label joined by one is a
/// single unbreakable run and must fit whole.
final RegExp _breakingWhitespace = RegExp(r'[^\S\u00A0\u2007\u202F]+');

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
      ...label.split(_breakingWhitespace).where((word) => word.isNotEmpty),
  };
  if (words.isEmpty) return 1;

  var scale = 1.0;
  for (final style in styles) {
    // A style without a size cannot be scaled, so it has no say.
    final fontSize = style.fontSize;
    if (fontSize == null || fontSize <= 0) continue;
    final widest = _widestWord(words, style, textScaler, textDirection);
    if (widest <= available) continue;
    final floor = math.min(fontSize, minFontSize);
    // Drawn width follows the scaled size, which a nonlinear scaler (Android
    // 14 and later) does not keep proportional to the font size, so find the
    // font size whose scaled size shrinks the widest word to the slot.
    final target = textScaler.scale(fontSize) * available / widest;
    final fitted = _largestFontSizeWithin(textScaler, target, floor, fontSize);
    scale = math.min(scale, fitted / fontSize);
  }
  return scale;
}

/// The largest font size in [low]..[high] whose scaled size is at most
/// [target], or [low] when even that is too large. TextScaler.scale only
/// ever grows with the font size, so a bisection finds it.
double _largestFontSizeWithin(
  TextScaler textScaler,
  double target,
  double low,
  double high,
) {
  if (textScaler.scale(low) >= target) return low;
  var lo = low;
  var hi = high;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (textScaler.scale(mid) <= target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
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
/// between the destinations, and the theme's horizontal label padding is
/// taken off each slot.
WidgetStateProperty<TextStyle?>? fittedNavBarLabelTextStyle(
  BuildContext context, {
  required List<String> labels,
  required double barWidth,
}) {
  if (labels.isEmpty) return null;
  final theme = Theme.of(context);
  final navBarTheme = NavigationBarTheme.of(context);
  final themed = navBarTheme.labelTextStyle;
  TextStyle? styleFor(Set<WidgetState> states) =>
      themed?.resolve(states) ?? _defaultLabelStyle(theme, states);

  final textDirection = Directionality.of(context);
  final safeArea = MediaQuery.paddingOf(context);
  final labelPadding =
      navBarTheme.labelPadding?.resolve(textDirection).horizontal ?? 0;
  final slotWidth =
      (barWidth - safeArea.horizontal) / labels.length - labelPadding;
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
    textDirection: textDirection,
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
