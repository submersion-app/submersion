import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_ratio.dart';

/// Contrast between an [Icon] or [Text] found by [glyph] and the solid fill
/// of the nearest box painted behind it (a marker, pin or badge).
///
/// An [AnimatedContainer] or [Container] paints its decoration through a
/// [DecoratedBox], so the nearest [DecoratedBox] ancestor is the fill the
/// glyph sits on.
double glyphOnFillContrast(WidgetTester tester, Finder glyph) {
  final widget = tester.widget(glyph);
  final color = switch (widget) {
    Icon(:final color) => color,
    Text(:final style) => style?.color,
    _ => throw ArgumentError('Expected an Icon or Text, got $widget'),
  };
  final box = tester.widget<DecoratedBox>(
    find.ancestor(of: glyph, matching: find.byType(DecoratedBox)).first,
  );
  final fill = (box.decoration as BoxDecoration).color;
  if (color == null || fill == null) {
    throw StateError('Glyph colour ($color) or fill ($fill) is not explicit');
  }
  return contrastRatio(color, fill);
}

/// Contrast between the [CircularProgressIndicator] found by [spinner] and
/// the disabled [FilledButton] it sits in, as painted over the page surface.
///
/// A save button is disabled for as long as its spinner shows, so the fill
/// is the button's own disabled background, not its enabled accent.
double spinnerOnDisabledFilledButtonContrast(
  WidgetTester tester,
  Finder spinner,
) {
  final indicator = tester.widget<CircularProgressIndicator>(spinner);
  final context = tester.element(spinner);
  final scheme = Theme.of(context).colorScheme;
  final color =
      indicator.color ??
      ProgressIndicatorTheme.of(context).color ??
      scheme.primary;

  final buttonFinder = find.ancestor(
    of: spinner,
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );
  final button = tester.widget<FilledButton>(buttonFinder.first);
  final disabledFill = button
      .defaultStyleOf(tester.element(buttonFinder.first))
      .backgroundColor!
      .resolve({WidgetState.disabled})!;
  return contrastRatio(color, Color.alphaBlend(disabledFill, scheme.surface));
}
