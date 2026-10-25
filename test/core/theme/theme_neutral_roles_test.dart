import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

import '../../helpers/contrast_ratio.dart';
import '../../helpers/google_fonts_settle.dart';

/// WCAG AA minimum for normal-size text.
const double _aaText = 4.5;

/// WCAG minimum for meaningful non-text marks (borders, icons).
const double _aaNonText = 3.0;

/// Minimum separation of a tonal fill from the surface beneath it. The
/// seeded Submersion light theme's highest container sits at about 1.2.
const double _fillSeparation = 1.15;

// The hand-built presets set only a handful of roles. Flutter's fallbacks
// make onSurfaceVariant equal onSurface, both outlines equal onSurface, and
// every surfaceContainer* equal the surface, so muted text was not muted,
// hairlines were full-contrast lines and tonal fills vanished. These hold
// the neutral roles to what Material 3 means by them, on every preset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Force-initialize the theme finals inside a guarded zone so the expected
  // google_fonts load errors (fonts are not bundled in test assets) do not
  // escape as unhandled async exceptions. Mirrors app_theme_registry_test.
  setUpAll(() async {
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await runZonedGuarded(
        () async {
          // ignore: unnecessary_statements
          AppThemeRegistry.presets;
          // Bounded: a font load another file left pending never finishes.
          await settleGoogleFonts();
        },
        (error, stack) {
          // Silently absorb google_fonts errors in the test environment.
        },
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  /// Runs [check] on every preset in both brightnesses and fails once with
  /// every broken pairing, so one run lists all the offenders.
  void expectEveryScheme(
    void Function(
      ColorScheme scheme,
      void Function(String what, bool ok, String detail) expectThat,
    )
    check,
  ) {
    final failures = <String>[];
    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        final scheme = AppThemeRegistry.resolveTheme(
          preset,
          brightness,
        ).colorScheme;
        final label = '${preset.id} ${brightness.name}';
        check(scheme, (what, ok, detail) {
          if (!ok) failures.add('$label $what: $detail');
        });
      }
    }
    expect(failures, isEmpty);
  }

  String ratio(double r) => '${r.toStringAsFixed(2)}:1';

  Map<String, Color> surfaces(ColorScheme s) => {
    'surface': s.surface,
    'surfaceContainerLow': s.surfaceContainerLow,
    'surfaceContainer': s.surfaceContainer,
    'surfaceContainerHigh': s.surfaceContainerHigh,
    'surfaceContainerHighest': s.surfaceContainerHighest,
  };

  test('onSurfaceVariant reads on every surface', () {
    expectEveryScheme((scheme, expectThat) {
      for (final MapEntry(key: name, value: bg) in surfaces(scheme).entries) {
        final r = contrastRatio(scheme.onSurfaceVariant, bg);
        expectThat('onSurfaceVariant on $name', r >= _aaText, ratio(r));
      }
    });
  });

  test('onSurfaceVariant is quieter than onSurface', () {
    expectEveryScheme((scheme, expectThat) {
      final variant = contrastRatio(scheme.onSurfaceVariant, scheme.surface);
      final full = contrastRatio(scheme.onSurface, scheme.surface);
      expectThat(
        'onSurfaceVariant vs onSurface',
        variant < full * 0.9,
        '${ratio(variant)} against ${ratio(full)}',
      );
    });
  });

  test('outline marks a boundary on the surface and the highest fill', () {
    expectEveryScheme((scheme, expectThat) {
      for (final bg in ['surface', 'surfaceContainerHighest']) {
        final r = contrastRatio(scheme.outline, surfaces(scheme)[bg]!);
        expectThat('outline on $bg', r >= _aaNonText, ratio(r));
      }
    });
  });

  test('outlineVariant is a hairline: visible, but quieter than outline', () {
    expectEveryScheme((scheme, expectThat) {
      final variant = contrastRatio(scheme.outlineVariant, scheme.surface);
      final outline = contrastRatio(scheme.outline, scheme.surface);
      expectThat(
        'outlineVariant visible',
        variant >= _fillSeparation,
        ratio(variant),
      );
      expectThat(
        'outlineVariant quieter than outline',
        variant < outline,
        '${ratio(variant)} against ${ratio(outline)}',
      );
    });
  });

  test('surface containers step away from the surface', () {
    expectEveryScheme((scheme, expectThat) {
      final steps = [
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ].map((c) => contrastRatio(c, scheme.surface)).toList();
      expectThat(
        'surfaceContainer < High < Highest',
        steps[0] < steps[1] && steps[1] < steps[2],
        steps.map(ratio).join(', '),
      );
      expectThat(
        'surfaceContainerHighest separation',
        steps[2] >= _fillSeparation,
        ratio(steps[2]),
      );
    });
  });

  // Material 3 puts the lowest container one step the other way, away from
  // onSurface: white over a near-white page, darker under a dark one. Left
  // equal to the surface, the entity table's alternate rows (which use it)
  // had no stripe on the hand-built presets.
  test('surfaceContainerLowest steps away from onSurface', () {
    expectEveryScheme((scheme, expectThat) {
      final lowest = contrastRatio(
        scheme.onSurface,
        scheme.surfaceContainerLowest,
      );
      final page = contrastRatio(scheme.onSurface, scheme.surface);
      final roomLeft =
          scheme.surface != Colors.white && scheme.surface != Colors.black;
      expectThat(
        'surfaceContainerLowest beyond the surface',
        roomLeft ? lowest > page : lowest >= page,
        '${ratio(lowest)} against ${ratio(page)}',
      );
    });
  });
}
