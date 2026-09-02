import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/entities/gradient_factor_source.dart';

/// Provenance of the gradient factors an analysis ran with (#1047).
///
/// The reported bug was a dive detail card showing "GF: 50/85" -- the app's
/// default diver setting -- on a dive downloaded from a computer configured to
/// 45/80. Most dive computers report no gradient factors at all (only 11 of
/// libdivecomputer's 36 parsers implement DC_FIELD_DECOMODEL), so the analysis
/// legitimately falls back to the diver's own setting. What was wrong was
/// presenting that fallback as if the computer had supplied it.
void main() {
  group('GradientFactorSource.resolve', () {
    test('uses the dive\'s own gradient factors when the computer reported '
        'them', () {
      final source = GradientFactorSource.resolve(
        diveGfLow: 45,
        diveGfHigh: 80,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );

      expect(source.low, 45);
      expect(source.high, 80);
      expect(source.origin, GfOrigin.computer);
    });

    test('falls back to the diver settings when the dive recorded no gradient '
        'factors', () {
      final source = GradientFactorSource.resolve(
        diveGfLow: null,
        diveGfHigh: null,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );

      expect(source.low, 50);
      expect(source.high, 85);
      expect(source.origin, GfOrigin.diverSettings);
    });

    test('falls back entirely when the dive recorded only one of the pair', () {
      // A half-populated pair cannot describe a gradient, so mixing the dive's
      // low with the setting's high would invent a schedule neither the
      // computer nor the diver ever chose.
      final source = GradientFactorSource.resolve(
        diveGfLow: 45,
        diveGfHigh: null,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );

      expect(source.low, 50);
      expect(source.high, 85);
      expect(source.origin, GfOrigin.diverSettings);
    });

    test('carries the recorded deco algorithm through the fallback', () {
      // A Shearwater run in VPM reports type=VPM and no gradient factors, so
      // the dive row keeps decoAlgorithm='vpm' with a null GF pair. The card
      // must be able to say the dive did not dive on gradient factors at all.
      final source = GradientFactorSource.resolve(
        diveGfLow: null,
        diveGfHigh: null,
        settingsGfLow: 50,
        settingsGfHigh: 85,
        recordedAlgorithm: 'vpm',
      );

      expect(source.origin, GfOrigin.diverSettings);
      expect(source.recordedAlgorithm, 'vpm');
      expect(source.recordedNonGfAlgorithm, isTrue);
    });

    test('does not flag a recorded Buhlmann algorithm as non-GF', () {
      final source = GradientFactorSource.resolve(
        diveGfLow: 45,
        diveGfHigh: 80,
        settingsGfLow: 50,
        settingsGfHigh: 85,
        recordedAlgorithm: 'buhlmann',
      );

      expect(source.recordedNonGfAlgorithm, isFalse);
    });

    test('does not claim an unrecognized algorithm skips gradient factors', () {
      // UDDF and other imports can carry any string. Saying "X does not use
      // gradient factors" about a model we do not recognize asserts something
      // we cannot know, so an unknown name falls back to the plain treatment.
      final source = GradientFactorSource.resolve(
        diveGfLow: null,
        diveGfHigh: null,
        settingsGfLow: 50,
        settingsGfHigh: 85,
        recordedAlgorithm: 'Some Vendor Model',
      );

      expect(source.recordedAlgorithm, 'Some Vendor Model');
      expect(source.recordedNonGfAlgorithm, isFalse);
    });

    test(
      'recognizes the known non-GF models regardless of spacing or case',
      () {
        for (final name in ['VPM', ' vpm ', 'VPM-B', 'vpmb', 'RGBM', 'dciem']) {
          final source = GradientFactorSource.resolve(
            diveGfLow: null,
            diveGfHigh: null,
            settingsGfLow: 50,
            settingsGfHigh: 85,
            recordedAlgorithm: name,
          );
          expect(
            source.recordedNonGfAlgorithm,
            isTrue,
            reason: '$name is a non-GF model',
          );
        }
      },
    );

    test('treats an unrecorded algorithm as nothing worth naming', () {
      final source = GradientFactorSource.resolve(
        diveGfLow: null,
        diveGfHigh: null,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );

      expect(source.recordedAlgorithm, isNull);
      expect(source.recordedNonGfAlgorithm, isFalse);
    });
  });
}
