import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';

/// A shadow and a scrim no real theme would use, so a test can tell a
/// colour that follows the theme from a fixed black.
const Color sentinelShadow = Color(0xFF3A1F5D);
const Color sentinelScrim = Color(0xFF5D3A1F);

/// The dark Submersion theme with [sentinelShadow] and [sentinelScrim].
ThemeData sentinelTheme() => submersionDark.copyWith(
  colorScheme: submersionDark.colorScheme.copyWith(
    shadow: sentinelShadow,
    scrim: sentinelScrim,
  ),
);

/// Whether [color] is [target] at any opacity.
bool sameHue(Color color, Color target) =>
    color.toARGB32() & 0xFFFFFF == target.toARGB32() & 0xFFFFFF;

/// Every [BoxShadow] painted by a [DecoratedBox] under [scope].
List<BoxShadow> boxShadowsUnder(WidgetTester tester, Finder scope) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox)),
  ))
    if (box.decoration case BoxDecoration(:final boxShadow?)) ...boxShadow,
];
