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
}
