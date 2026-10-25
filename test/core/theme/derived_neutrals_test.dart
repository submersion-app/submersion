import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/derived_neutrals.dart';

void main() {
  // theme_neutral_roles_test covers the real presets. This covers a scheme
  // whose ink cannot reach the target contrast at all: a mid-grey surface
  // under white text tops out near 4:1, so no blend reaches 7:1 (or 3:1 on
  // the darker containers) and each role falls back to full-strength ink
  // rather than to something fainter.
  test('a scheme too low in contrast keeps full ink for its roles', () {
    const scheme = ColorScheme.dark(
      surface: Color(0xFF808080),
      onSurface: Color(0xFFFFFFFF),
    );

    final derived = withDerivedNeutrals(scheme);

    expect(derived.onSurfaceVariant, scheme.onSurface);
  });
}
