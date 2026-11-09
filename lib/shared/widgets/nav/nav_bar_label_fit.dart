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
/// [styles] are the label styles the bar can draw (selected, unselected),
/// already merged over the ambient text style; the widest of them decides.
/// [locale] is the one the labels are drawn in, which picks fallback fonts. The result never takes a style below
/// [minFontSize], and never grows a style that already sits below it.
double fitNavBarLabelScale({
  required Iterable<String> labels,
  required Iterable<TextStyle> styles,
  required double slotWidth,
  required TextScaler textScaler,
  required TextDirection textDirection,
  Locale? locale,
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
    // Width is not proportional to the font size: letter and word spacing
    // stay fixed, and a nonlinear scaler (Android 14 and later) grows small
    // sizes more than large ones. So every candidate size is laid out.
    bool fits(double size) =>
        _widestWord(
          words,
          style.copyWith(fontSize: size),
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        ) <=
        available;
    if (fits(fontSize)) continue;
    final floor = math.min(fontSize, minFontSize);
    scale = math.min(
      scale,
      _largestFittingSize(fits, floor, fontSize) / fontSize,
    );
  }
  return scale;
}

/// Bisection steps when searching for the fitting size: enough to pin a
/// size between the minimum and 12 to well under a hundredth of a point.
const int _kFitSteps = 12;

/// The largest size in [low]..[high] that [fits], or [low] when even that
/// does not. [high] is known not to fit, and a word only ever widens as its
/// size grows, so a bisection finds the boundary.
double _largestFittingSize(
  bool Function(double size) fits,
  double low,
  double high,
) {
  if (!fits(low)) return low;
  var lo = low;
  var hi = high;
  for (var i = 0; i < _kFitSteps; i++) {
    final mid = (lo + hi) / 2;
    if (fits(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

double _widestWord(
  Set<String> words,
  TextStyle style, {
  required TextScaler textScaler,
  required TextDirection textDirection,
  Locale? locale,
}) {
  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
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
  // The label Text merges its style over the ambient one, so measure the
  // merged style it is drawn with.
  final ambient = DefaultTextStyle.of(context).style;
  final scale = fitNavBarLabelScale(
    labels: labels,
    styles: [
      for (final states in const [
        {WidgetState.selected},
        <WidgetState>{},
      ])
        ambient.merge(styleFor(states)),
    ],
    slotWidth: slotWidth,
    textScaler: MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kNavBarLabelMaxTextScaleFactor),
    textDirection: textDirection,
    locale: Localizations.maybeLocaleOf(context),
  );
  if (scale >= 1) return null;

  return WidgetStateProperty.resolveWith((states) {
    final style = styleFor(states);
    // A style without a size draws at the ambient one, which was measured.
    final fontSize = style?.fontSize ?? ambient.fontSize;
    return style == null || fontSize == null
        ? style
        : style.copyWith(fontSize: fontSize * scale);
  });
}
