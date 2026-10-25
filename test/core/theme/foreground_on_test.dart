import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/foreground_on.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';

import '../../helpers/contrast_ratio.dart';

void main() {
  for (final theme in [submersionLight, submersionDark]) {
    final scheme = theme.colorScheme;
    final mode = scheme.brightness.name;

    test('$mode: an accent role fill gets its paired on-role', () {
      expect(foregroundOn(scheme, scheme.primary), scheme.onPrimary);
      expect(foregroundOn(scheme, scheme.secondary), scheme.onSecondary);
      expect(foregroundOn(scheme, scheme.tertiary), scheme.onTertiary);
      expect(foregroundOn(scheme, scheme.error), scheme.onError);
    });

    // Fixed status hues used as fills beside the role fills.
    for (final fill in [
      Colors.green,
      Colors.orange,
      Colors.green.shade700,
      Colors.blue.shade700,
      Colors.indigo,
      Colors.yellow,
    ]) {
      test('$mode: a fixed fill $fill gets the better of black and white', () {
        final fg = foregroundOn(scheme, fill);
        final other = fg == Colors.black ? Colors.white : Colors.black;
        expect(fg, anyOf(Colors.black, Colors.white));
        expect(
          contrastRatio(fg, fill),
          greaterThanOrEqualTo(contrastRatio(other, fill)),
        );
      });
    }
  }
}
