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

  // A preset that sets a neutral role itself keeps it: only the roles Flutter
  // fell back for (equal to onSurface or the surface) are derived.
  test('a role the scheme sets itself is kept', () {
    // The plain constructor, as the hand-built presets use it: no defaults
    // beyond Flutter's fallbacks.
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF4AE0C0),
      onPrimary: Color(0xFF0A1018),
      secondary: Color(0xFF8FA6BF),
      onSecondary: Color(0xFF0A1018),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: Color(0xFF141A22),
      onSurface: Color(0xFFE6EAF0),
      onSurfaceVariant: Color(0xFFB0B8C4),
      outline: Color(0xFF2A3A4A),
      surfaceContainerHighest: Color(0xFF2B3440),
    );

    final derived = withDerivedNeutrals(scheme);

    expect(derived.onSurfaceVariant, scheme.onSurfaceVariant);
    expect(derived.outline, scheme.outline);
    expect(derived.surfaceContainerHighest, scheme.surfaceContainerHighest);
    // Left to their fallbacks, these are still derived.
    expect(derived.outlineVariant, isNot(scheme.onSurface));
    expect(derived.surfaceContainer, isNot(scheme.surface));
  });
}
