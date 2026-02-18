import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('CardColorAttribute', () {
    test('has 4 values including none', () {
      expect(CardColorAttribute.values.length, 4);
      expect(
        CardColorAttribute.values,
        containsAll([
          CardColorAttribute.none,
          CardColorAttribute.depth,
          CardColorAttribute.duration,
          CardColorAttribute.temperature,
        ]),
      );
    });

    test('fromName parses valid names', () {
      expect(CardColorAttribute.fromName('none'), CardColorAttribute.none);
      expect(CardColorAttribute.fromName('depth'), CardColorAttribute.depth);
      expect(
        CardColorAttribute.fromName('duration'),
        CardColorAttribute.duration,
      );
      expect(
        CardColorAttribute.fromName('temperature'),
        CardColorAttribute.temperature,
      );
    });

    test('fromName defaults to none for unknown names', () {
      expect(CardColorAttribute.fromName('unknown'), CardColorAttribute.none);
      expect(CardColorAttribute.fromName(''), CardColorAttribute.none);
    });
  });

  group('cardColorPresets', () {
    test('contains 5 presets, all with non-null colors', () {
      expect(cardColorPresets.length, 5);
      for (final entry in cardColorPresets.entries) {
        expect(entry.value.name, isNotEmpty, reason: '${entry.key} name');
        // ignore: unnecessary_null_comparison
        expect(entry.value.startColor, isNotNull, reason: '${entry.key} start');
        // ignore: unnecessary_null_comparison
        expect(entry.value.endColor, isNotNull, reason: '${entry.key} end');
      }
    });

    test('ocean preset matches original depth colors', () {
      final ocean = cardColorPresets['ocean']!;
      expect(ocean.startColor, const Color(0xFF4DD0E1));
      expect(ocean.endColor, const Color(0xFF0D1B2A));
    });

    test('contains expected preset keys', () {
      expect(
        cardColorPresets.keys,
        containsAll(['ocean', 'thermal', 'sunset', 'forest', 'monochrome']),
      );
    });
  });

  group('getCardColorValue', () {
    final dive = DiveSummary(
      id: 'test-1',
      dateTime: DateTime(2024, 6, 15),
      maxDepth: 30.0,
      duration: const Duration(minutes: 45),
      waterTemp: 22.5,
      sortTimestamp: DateTime(2024, 6, 15).millisecondsSinceEpoch,
    );

    test('returns maxDepth for depth attribute', () {
      expect(getCardColorValue(dive, CardColorAttribute.depth), 30.0);
    });

    test('returns duration in minutes for duration attribute', () {
      expect(getCardColorValue(dive, CardColorAttribute.duration), 45.0);
    });

    test('returns waterTemp for temperature attribute', () {
      expect(getCardColorValue(dive, CardColorAttribute.temperature), 22.5);
    });

    test('returns null for none attribute', () {
      expect(getCardColorValue(dive, CardColorAttribute.none), isNull);
    });

    test('returns null for dives with missing data', () {
      final spareDive = DiveSummary(
        id: 'test-2',
        dateTime: DateTime(2024, 6, 15),
        sortTimestamp: DateTime(2024, 6, 15).millisecondsSinceEpoch,
      );
      expect(getCardColorValue(spareDive, CardColorAttribute.depth), isNull);
      expect(getCardColorValue(spareDive, CardColorAttribute.duration), isNull);
      expect(
        getCardColorValue(spareDive, CardColorAttribute.temperature),
        isNull,
      );
    });
  });

  group('normalizeAndLerp', () {
    const start = Color(0xFF000000);
    const end = Color(0xFFFFFFFF);

    test('returns null when value is null', () {
      expect(
        normalizeAndLerp(
          value: null,
          min: 0,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        isNull,
      );
    });

    test('returns null when min is null', () {
      expect(
        normalizeAndLerp(
          value: 50,
          min: null,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        isNull,
      );
    });

    test('returns null when max is null', () {
      expect(
        normalizeAndLerp(
          value: 50,
          min: 0,
          max: null,
          startColor: start,
          endColor: end,
        ),
        isNull,
      );
    });

    test('returns startColor when min == max', () {
      expect(
        normalizeAndLerp(
          value: 50,
          min: 50,
          max: 50,
          startColor: start,
          endColor: end,
        ),
        start,
      );
    });

    test('returns startColor at min value', () {
      expect(
        normalizeAndLerp(
          value: 0,
          min: 0,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        start,
      );
    });

    test('returns endColor at max value', () {
      expect(
        normalizeAndLerp(
          value: 100,
          min: 0,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        end,
      );
    });

    test('returns mid-color at midpoint', () {
      final result = normalizeAndLerp(
        value: 50,
        min: 0,
        max: 100,
        startColor: start,
        endColor: end,
      );
      // At 50% between black and white, we expect ~grey
      // Color.lerp(0xFF000000, 0xFFFFFFFF, 0.5) = 0xFF808080
      expect(result, Color.lerp(start, end, 0.5));
    });

    test('clamps values below min to startColor', () {
      expect(
        normalizeAndLerp(
          value: -10,
          min: 0,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        start,
      );
    });

    test('clamps values above max to endColor', () {
      expect(
        normalizeAndLerp(
          value: 200,
          min: 0,
          max: 100,
          startColor: start,
          endColor: end,
        ),
        end,
      );
    });
  });

  group('resolveGradientColors', () {
    test('returns custom colors when both are provided', () {
      final result = resolveGradientColors(
        presetName: 'ocean',
        customStart: 0xFFFF0000,
        customEnd: 0xFF00FF00,
      );
      expect(result.start, const Color(0xFFFF0000));
      expect(result.end, const Color(0xFF00FF00));
    });

    test('returns preset colors when no custom colors', () {
      final result = resolveGradientColors(
        presetName: 'ocean',
        customStart: null,
        customEnd: null,
      );
      expect(result.start, const Color(0xFF4DD0E1));
      expect(result.end, const Color(0xFF0D1B2A));
    });

    test('falls back to ocean preset for unknown preset name', () {
      final result = resolveGradientColors(
        presetName: 'nonexistent',
        customStart: null,
        customEnd: null,
      );
      expect(result.start, const Color(0xFF4DD0E1));
      expect(result.end, const Color(0xFF0D1B2A));
    });

    test('uses preset when only customStart is provided', () {
      final result = resolveGradientColors(
        presetName: 'thermal',
        customStart: 0xFFFF0000,
        customEnd: null,
      );
      // Only one custom color provided, so fall back to preset
      final thermal = cardColorPresets['thermal']!;
      expect(result.start, thermal.startColor);
      expect(result.end, thermal.endColor);
    });
  });

  group('AppSettings backward compatibility', () {
    test(
      'showDepthColoredDiveCards returns true when attribute is not none',
      () {
        const settings = AppSettings(
          cardColorAttribute: CardColorAttribute.depth,
        );
        expect(settings.showDepthColoredDiveCards, true);
      },
    );

    test('showDepthColoredDiveCards returns false when attribute is none', () {
      const settings = AppSettings(cardColorAttribute: CardColorAttribute.none);
      expect(settings.showDepthColoredDiveCards, false);
    });

    test('default AppSettings has cardColorAttribute none', () {
      const settings = AppSettings();
      expect(settings.cardColorAttribute, CardColorAttribute.none);
      expect(settings.cardColorGradientPreset, 'ocean');
      expect(settings.cardColorGradientStart, isNull);
      expect(settings.cardColorGradientEnd, isNull);
    });
  });
}
