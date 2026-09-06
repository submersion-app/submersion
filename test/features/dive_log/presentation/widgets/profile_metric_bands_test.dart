import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';

/// Every metric the chart plots as a banded curve.
const _all = <String, ProfileMetricBand>{
  'ndl': ProfileMetricBands.ndl,
  'tts': ProfileMetricBands.tts,
  'gtr': ProfileMetricBands.gtr,
  'ppO2': ProfileMetricBands.ppO2,
  'ppN2': ProfileMetricBands.ppN2,
  'ppHe': ProfileMetricBands.ppHe,
  'density': ProfileMetricBands.density,
  'gf': ProfileMetricBands.gf,
  'surfaceGf': ProfileMetricBands.surfaceGf,
  'mod': ProfileMetricBands.mod,
  'meanDepth': ProfileMetricBands.meanDepth,
  'cns': ProfileMetricBands.cns,
  'otu': ProfileMetricBands.otu,
};

void main() {
  group('ProfileMetricBands', () {
    test('every metric has its own colour', () {
      // Several traces are drawn at once; two sharing a colour would be
      // indistinguishable on the chart and in the legend beside it.
      final byColour = <int, String>{};
      _all.forEach((name, band) {
        final previous = byColour[band.color.toARGB32()];
        expect(
          previous,
          isNull,
          reason: '$name shares its colour with $previous',
        );
        byColour[band.color.toARGB32()] = name;
      });
    });

    test('a band never runs backwards', () {
      _all.forEach((name, band) {
        if (band.max != null) {
          expect(band.max!, greaterThan(band.min), reason: name);
        }
      });
    });

    test('a runtime-scaled metric refuses to hand out a fixed maximum', () {
      // CNS and OTU scale to the dive, so a caller reaching for fixedMax has
      // mistaken them for a fixed-band metric rather than silently plotting
      // on the wrong axis.
      expect(() => ProfileMetricBands.cns.fixedMax, throwsStateError);
      expect(() => ProfileMetricBands.otu.fixedMax, throwsStateError);
      expect(ProfileMetricBands.ppO2.fixedMax, 2.0);
    });
  });
}
