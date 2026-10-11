// `show Locale` on purpose: flutter/widgets.dart exports a Visibility widget
// that collides with the app's Visibility enum.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const cold = VisibilityScale.coldWater;
  const tropical = VisibilityScale.tropical;
  const coldGood = VisibilityRange(minM: 6, maxM: 12);
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));

  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  StoredVisibility resolve({
    VisibilityInputMode mode = VisibilityInputMode.range,
    double? precise,
    VisibilityBand? band,
    bool touched = true,
    bool? preciseTouched,
    bool? rangeTouched,
    StoredVisibility original = StoredVisibility.none,
    VisibilityScale scale = cold,
  }) => resolveVisibilityEntry(
    mode: mode,
    preciseMeters: precise,
    band: band,
    preciseTouched: preciseTouched ?? touched,
    rangeTouched: rangeTouched ?? touched,
    original: original,
    scale: scale,
  );

  group('resolveVisibilityEntry', () {
    test('a band pick saves its range on the current scale', () {
      expect(resolve(band: VisibilityBand.good).range, coldGood);
    });

    test('a typed number in Precise saves a measurement', () {
      final saved = resolve(mode: VisibilityInputMode.precise, precise: 7);
      expect(saved.meters, 7);
      expect(saved.range, isNull);
    });

    test('only the active mode is saved', () {
      final saved = resolve(precise: 7, band: VisibilityBand.good);
      expect(saved.meters, isNull);
      expect(saved.range, coldGood);
    });

    test('an untouched dive keeps exactly what it had', () {
      for (final original in const [
        StoredVisibility(meters: 6.44),
        StoredVisibility(range: coldGood),
        StoredVisibility(legacy: Visibility.moderate),
      ]) {
        expect(
          resolve(
            mode: VisibilityInputMode.precise,
            precise: 6,
            touched: false,
            original: original,
            scale: tropical,
          ),
          original,
        );
      }
    });

    test('a range survives a detour through Precise (review #1)', () {
      // Range dive; the diver types 8 in Precise, then returns to Range
      // without tapping a chip.
      expect(
        resolve(
          precise: 8,
          preciseTouched: true,
          rangeTouched: false,
          original: const StoredVisibility(range: coldGood),
        ),
        const StoredVisibility(range: coldGood),
      );
    });

    test('a measurement survives a detour through Range unrounded', () {
      // 6.44 m dive (field seeded "6"); the diver taps Good in Range, then
      // returns to Precise without typing.
      expect(
        resolve(
          mode: VisibilityInputMode.precise,
          precise: 6,
          band: VisibilityBand.good,
          preciseTouched: false,
          rangeTouched: true,
          original: const StoredVisibility(meters: 6.44),
        ),
        const StoredVisibility(meters: 6.44),
      );
    });

    test('clearing the input after touching it saves nothing', () {
      expect(
        resolve(original: const StoredVisibility(range: coldGood)),
        StoredVisibility.none,
      );
    });
  });

  test('a two-shape dive reads as measured, dropping the stale range', () {
    final dive = Dive(
      id: 'd',
      dateTime: DateTime.utc(2026, 1, 1),
      visibilityMeters: 8,
      visibilityMinMeters: 6,
      visibilityMaxMeters: 12,
    );
    expect(StoredVisibility.of(dive), const StoredVisibility(meters: 8));
  });

  group('StoredVisibility modes', () {
    test('a dive opens in the shape it was saved in', () {
      expect(
        const StoredVisibility(meters: 6).naturalMode,
        VisibilityInputMode.precise,
      );
      expect(
        const StoredVisibility(range: coldGood).naturalMode,
        VisibilityInputMode.range,
      );
      expect(
        const StoredVisibility(legacy: Visibility.good).naturalMode,
        VisibilityInputMode.range,
      );
      expect(StoredVisibility.none.naturalMode, isNull);
    });

    test('only a new value is remembered as the last-used mode', () {
      expect(
        const StoredVisibility(range: coldGood).modeToRemember,
        VisibilityInputMode.range,
      );
      expect(
        const StoredVisibility(meters: 6).modeToRemember,
        VisibilityInputMode.precise,
      );
      expect(
        const StoredVisibility(legacy: Visibility.good).modeToRemember,
        isNull,
      );
    });
  });

  group('effectiveVisibilityBand', () {
    test('a stored range selects the chip it equals on the current scale', () {
      expect(
        effectiveVisibilityBand(
          band: null,
          rangeTouched: false,
          original: const StoredVisibility(range: coldGood),
          scale: cold,
        ),
        VisibilityBand.good,
      );
    });

    test('after a scale change the stored range selects no chip', () {
      expect(
        effectiveVisibilityBand(
          band: null,
          rangeTouched: false,
          original: const StoredVisibility(range: coldGood),
          scale: tropical,
        ),
        isNull,
      );
    });

    test('once touched, the pick is what it is', () {
      expect(
        effectiveVisibilityBand(
          band: null,
          rangeTouched: true,
          original: const StoredVisibility(range: coldGood),
          scale: cold,
        ),
        isNull,
      );
    });
  });

  group('visibilityEntryCaption', () {
    String? caption({
      VisibilityInputMode mode = VisibilityInputMode.range,
      double? precise,
      VisibilityBand? band,
      bool touched = true,
      StoredVisibility original = StoredVisibility.none,
      VisibilityScale scale = cold,
    }) => visibilityEntryCaption(
      mode: mode,
      preciseMeters: precise,
      band: band,
      preciseTouched: touched,
      rangeTouched: touched,
      original: original,
      scale: scale,
      l10n: en,
      units: metric,
    );

    test('a picked band shows the range it will save', () {
      expect(caption(band: VisibilityBand.good), '6-12 m');
    });

    test('an off-scale stored range shows itself', () {
      expect(
        caption(
          touched: false,
          original: const StoredVisibility(range: coldGood),
          scale: tropical,
        ),
        '6-12 m',
      );
    });

    test('an untouched legacy dive shows its bucket range', () {
      expect(
        caption(
          touched: false,
          original: const StoredVisibility(legacy: Visibility.moderate),
        ),
        '5-15 m',
      );
    });

    test('a typed number shows its band', () {
      expect(
        caption(mode: VisibilityInputMode.precise, precise: 6),
        en.enum_visibilityBand_good,
      );
    });

    test('back in Range after a Precise detour, the stored range shows', () {
      expect(
        visibilityEntryCaption(
          mode: VisibilityInputMode.range,
          preciseMeters: 8,
          band: null,
          preciseTouched: true,
          rangeTouched: false,
          original: const StoredVisibility(range: coldGood),
          scale: tropical,
          l10n: en,
          units: metric,
        ),
        '6-12 m',
      );
    });

    test('a cleared input shows nothing', () {
      expect(
        caption(original: const StoredVisibility(range: coldGood)),
        isNull,
      );
    });
  });
}
