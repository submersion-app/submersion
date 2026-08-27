import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/presentation/course_status_colors.dart';

/// The status card used to hand [Card] a 10%-alpha green. Because the card is
/// elevated and the app sets no `surfaceTintColor`, the Material 3 elevation
/// tint and the drop shadow composited through the translucent interior and
/// the "Completed" card read as a grey wash in light themes.
///
/// These tests pin the two properties that prevents: the surface is opaque,
/// and it stays on the same side of the light/dark divide as the theme it
/// came from.
void main() {
  final lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0077B6));
  final darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.dark,
  );

  group('courseStatusSurface', () {
    test('is fully opaque so no elevation tint bleeds through', () {
      for (final scheme in [lightScheme, darkScheme]) {
        for (final completed in [true, false]) {
          final surface = courseStatusSurface(scheme, completed: completed);
          expect(
            surface.a,
            1.0,
            reason:
                'completed=$completed on ${scheme.brightness} must be opaque',
          );
        }
      }
    });

    test('stays light in a light theme and dark in a dark theme', () {
      for (final completed in [true, false]) {
        expect(
          courseStatusSurface(
            lightScheme,
            completed: completed,
          ).computeLuminance(),
          greaterThan(0.5),
          reason: 'completed=$completed must not look dark in a light theme',
        );
        expect(
          courseStatusSurface(
            darkScheme,
            completed: completed,
          ).computeLuminance(),
          lessThan(0.5),
          reason: 'completed=$completed must not look light in a dark theme',
        );
      }
    });

    test('stays close to the theme surface it is tinted from', () {
      // A tint, not a repaint: the status colour must read as the same card
      // material, so it may not drift far from surfaceContainerLow.
      for (final scheme in [lightScheme, darkScheme]) {
        for (final completed in [true, false]) {
          final delta =
              (courseStatusSurface(
                        scheme,
                        completed: completed,
                      ).computeLuminance() -
                      scheme.surfaceContainerLow.computeLuminance())
                  .abs();
          expect(delta, lessThan(0.2), reason: 'completed=$completed');
        }
      }
    });

    test('distinguishes completed from in progress', () {
      for (final scheme in [lightScheme, darkScheme]) {
        expect(
          courseStatusSurface(scheme, completed: true),
          isNot(courseStatusSurface(scheme, completed: false)),
        );
      }
    });
  });

  group('courseStatusAccent', () {
    test('contrasts with its own status surface', () {
      for (final scheme in [lightScheme, darkScheme]) {
        for (final completed in [true, false]) {
          final accent = courseStatusAccent(scheme, completed: completed);
          final surface = courseStatusSurface(scheme, completed: completed);
          final delta = (accent.computeLuminance() - surface.computeLuminance())
              .abs();
          expect(
            delta,
            greaterThan(0.2),
            reason: 'completed=$completed on ${scheme.brightness} is too flat',
          );
        }
      }
    });

    test('is opaque', () {
      for (final scheme in [lightScheme, darkScheme]) {
        for (final completed in [true, false]) {
          expect(courseStatusAccent(scheme, completed: completed).a, 1.0);
        }
      }
    });
  });
}
