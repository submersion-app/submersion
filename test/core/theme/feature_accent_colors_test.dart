import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('FeatureAccentColors', () {
    test('every routable nav destination has an entry in both palettes', () {
      final routableIds = kNavDestinations
          .where((d) => d.id != 'more')
          .map((d) => d.id);
      for (final id in routableIds) {
        expect(
          FeatureAccentColors.light.of(id),
          isNotNull,
          reason: 'light palette missing $id',
        );
        expect(
          FeatureAccentColors.dark.of(id),
          isNotNull,
          reason: 'dark palette missing $id',
        );
      }
    });

    test('the more sentinel is intentionally absent', () {
      expect(FeatureAccentColors.light.of('more'), isNull);
      expect(FeatureAccentColors.dark.of('more'), isNull);
    });

    test('settings root sections have settings-prefixed entries', () {
      const sectionIds = [
        'about',
        'appearance',
        'data',
        'dataSources',
        'decompression',
        'profile',
        'safety',
        'manage',
        'notifications',
        'sharedData',
        'units',
        'debug',
      ];
      for (final id in sectionIds) {
        expect(FeatureAccentColors.light.of('settings-$id'), isNotNull);
        expect(FeatureAccentColors.dark.of('settings-$id'), isNotNull);
      }
    });

    test('unknown id returns null', () {
      expect(FeatureAccentColors.light.of('nonexistent'), isNull);
    });

    test('light and dark palettes have identical key sets', () {
      expect(
        FeatureAccentColors.light.colors.keys.toSet(),
        FeatureAccentColors.dark.colors.keys.toSet(),
      );
    });

    test('lerp interpolates per key', () {
      final mid = FeatureAccentColors.light.lerp(FeatureAccentColors.dark, 0.5);
      final expected = Color.lerp(
        FeatureAccentColors.light.of('dives'),
        FeatureAccentColors.dark.of('dives'),
        0.5,
      );
      expect(mid.of('dives'), expected);
    });

    test('copyWith replaces the map', () {
      final replaced = FeatureAccentColors.light.copyWith(
        colors: const {'x': Color(0xFF000000)},
      );
      expect(replaced.of('x'), const Color(0xFF000000));
      expect(replaced.of('dives'), isNull);
    });
  });

  group('FeatureAccentColors contrast', () {
    // WCAG 2.1 relative luminance.
    double luminance(Color c) {
      double channel(double v) {
        v = v / 255.0;
        return v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      }

      return 0.2126 * channel((c.r * 255).roundToDouble()) +
          0.7152 * channel((c.g * 255).roundToDouble()) +
          0.0722 * channel((c.b * 255).roundToDouble());
    }

    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final hi = math.max(la, lb);
      final lo = math.min(la, lb);
      return (hi + 0.05) / (lo + 0.05);
    }

    // Material 3 default surfaces for each brightness.
    const lightSurface = Color(0xFFFFFBFE);
    const darkSurface = Color(0xFF1C1B1F);

    // The feature accents tint nav icons, where the icon is the primary
    // affordance, so they must clear the 3:1 WCAG ratio for graphical
    // objects. The settings-* entries are excluded: they reproduce colors
    // the settings root already shipped, sit on a tinted 15%-alpha chip, and
    // always carry a text label; changing them would alter existing UI.
    final featureIds = kNavDestinations
        .where((d) => d.id != 'more')
        .map((d) => d.id);

    test('light accents clear 3:1 against the light surface', () {
      for (final id in featureIds) {
        final color = FeatureAccentColors.light.of(id)!;
        expect(
          contrast(color, lightSurface),
          greaterThanOrEqualTo(3.0),
          reason: '$id is too light to read on a light surface',
        );
      }
    });

    test('dark accents clear 3:1 against the dark surface', () {
      for (final id in featureIds) {
        final color = FeatureAccentColors.dark.of(id)!;
        expect(
          contrast(color, darkSurface),
          greaterThanOrEqualTo(3.0),
          reason: '$id is too dark to read on a dark surface',
        );
      }
    });
  });
}
