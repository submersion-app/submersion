import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('visibility calibration is presentational only', () {
    test('the same measurement re-labels across presets', () {
      // A 6 m dive: the stored fact never changes, only the adjective.
      // Temperate puts good at 10 m, so 6 m is still moderate there; only the
      // cold-water scale calls it a good day.
      const meters = 6.0;
      expect(VisibilityScale.tropical.bandFor(meters), VisibilityBand.moderate);
      expect(
        VisibilityScale.temperate.bandFor(meters),
        VisibilityBand.moderate,
      );
      expect(VisibilityScale.coldWater.bandFor(meters), VisibilityBand.good);
    });

    test('a 10 m dive separates tropical from temperate', () {
      expect(VisibilityScale.tropical.bandFor(10), VisibilityBand.moderate);
      expect(VisibilityScale.temperate.bandFor(10), VisibilityBand.good);
      expect(VisibilityScale.coldWater.bandFor(10), VisibilityBand.good);
    });

    test('cold water separates a good day from an exceptional one', () {
      // The reported problem: locally the best visibility landed at the bottom
      // of the second-worst bucket. Under cold water it now spans two bands.
      expect(VisibilityScale.coldWater.bandFor(6), VisibilityBand.good);
      expect(VisibilityScale.coldWater.bandFor(12), VisibilityBand.excellent);
      expect(VisibilityScale.tropical.bandFor(6), VisibilityBand.moderate);
      expect(VisibilityScale.tropical.bandFor(12), VisibilityBand.moderate);
    });
  });

  group('custom thresholds are entered in diver units, stored metric', () {
    test('an imperial entry converts to the metric threshold', () {
      const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
      // A diver typing 40/20/6 ft gets roughly the cold-water scale.
      final scale = VisibilityScale(
        excellentAtOrAboveM: imperial.depthToMeters(40),
        goodAtOrAboveM: imperial.depthToMeters(20),
        moderateAtOrAboveM: imperial.depthToMeters(6),
      );
      expect(scale.isValid, isTrue);
      expect(scale.excellentAtOrAboveM, closeTo(12.19, 0.01));
      expect(scale.goodAtOrAboveM, closeTo(6.1, 0.01));
      expect(scale.bandFor(6.5), VisibilityBand.good);
    });
  });

  group('custom thresholds survive a trip through a named preset', () {
    test('the stored custom values are retained while a preset is active', () {
      // setVisibilityScale keeps the custom columns populated so switching
      // away and back restores them. The settings dialog must seed from those
      // columns, not from visibilityScale, which resolves to the *named*
      // preset's bounds whenever one is active.
      const settings = AppSettings(
        visibilityScalePreset: VisibilityScalePreset.coldWater,
        visibilityScaleExcellentM: 18,
        visibilityScaleGoodM: 9,
        visibilityScaleModerateM: 3,
      );

      // What the dialog must NOT seed from:
      expect(settings.visibilityScale, VisibilityScale.coldWater);
      expect(settings.visibilityScale.excellentAtOrAboveM, 12);

      // What it must seed from:
      expect(settings.visibilityScaleExcellentM, 18);
      expect(settings.visibilityScaleGoodM, 9);
      expect(settings.visibilityScaleModerateM, 3);
    });

    test('switching back to custom restores the retained thresholds', () {
      const active = AppSettings(
        visibilityScalePreset: VisibilityScalePreset.coldWater,
        visibilityScaleExcellentM: 18,
        visibilityScaleGoodM: 9,
        visibilityScaleModerateM: 3,
      );
      final restored = active.copyWith(
        visibilityScalePreset: VisibilityScalePreset.custom,
      );
      expect(restored.visibilityScale.excellentAtOrAboveM, 18);
      expect(restored.visibilityScale.bandFor(9), VisibilityBand.good);
    });
  });

  group('AppSettings integration', () {
    test('changing the preset changes only the derived scale', () {
      const before = AppSettings();
      final after = before.copyWith(
        visibilityScalePreset: VisibilityScalePreset.coldWater,
      );
      expect(before.visibilityScale, VisibilityScale.tropical);
      expect(after.visibilityScale, VisibilityScale.coldWater);
      // Nothing else moved.
      expect(after.depthUnit, before.depthUnit);
      expect(after.defaultCurrency, before.defaultCurrency);
    });

    test(
      'an invalid custom scale degrades to tropical rather than throwing',
      () {
        const settings = AppSettings(
          visibilityScalePreset: VisibilityScalePreset.custom,
          visibilityScaleExcellentM: 2,
          visibilityScaleGoodM: 6,
          visibilityScaleModerateM: 12,
        );
        expect(settings.visibilityScale, VisibilityScale.tropical);
      },
    );
  });
}
