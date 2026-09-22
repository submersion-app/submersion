import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_color_contrast.dart';

/// The label colour a tag chip writes on its own colour (issue #2254).
///
/// A chip filled with the exact tag colour has to choose its own text colour,
/// because the palette spans a pale yellow and a near-black slate. The choice
/// is made on contrast ratio, so every predefined colour stays readable.
void main() {
  /// WCAG 2.1 relative luminance contrast between two opaque colours.
  double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('every predefined tag colour gets a label above WCAG AA', () {
    for (final hex in TagColors.predefined) {
      final background = TagColors.fromHex(hex);
      final foreground = tagForegroundColor(background);
      expect(
        ratio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '$hex label contrast',
      );
    }
  });

  test('a pale colour takes a dark label, a dark colour a light one', () {
    // Amber, the colour in the issue's report.
    expect(tagForegroundColor(const Color(0xFFF59E0B)).computeLuminance(), 0.0);
    // Slate, the darkest entry of the palette.
    expect(tagForegroundColor(const Color(0xFF64748B)).computeLuminance(), 1.0);
  });

  test('the label is opaque, so no surface shows through it', () {
    for (final hex in TagColors.predefined) {
      expect(tagForegroundColor(TagColors.fromHex(hex)).a, 1.0, reason: hex);
    }
  });
}
