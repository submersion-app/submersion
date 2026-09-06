import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';

/// Every metric in the spec.
///
/// Most are band-mapped; MOD and mean depth are plotted in depth units and
/// are here for their colour and dash pattern alone, which is why the
/// fixedMax test below treats them alongside the runtime-scaled metrics.
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

    test('no two metrics share both a colour and a dash pattern', () {
      // Dash patterns are not unique on their own (NDL and CNS both use
      // [6, 3]); the pair must be, or two traces would be identical.
      final seen = <String, String>{};
      _all.forEach((name, band) {
        final key = '${band.color.toARGB32()}/${band.dashArray}';
        final clash = seen[key];
        expect(
          clash,
          isNull,
          reason: '$name would render identically to $clash',
        );
        seen[key] = name;
      });
    });

    test('a band never runs backwards', () {
      _all.forEach((name, band) {
        if (band.max != null) {
          expect(band.max!, greaterThan(band.min), reason: name);
        }
      });
    });

    test('a metric with no fixed maximum refuses to hand one out', () {
      // Two reasons a metric has none: CNS and OTU are scaled to the dive,
      // MOD and mean depth are plotted in depth units. Either way a caller
      // reaching for fixedMax has mistaken it for a fixed-band metric and
      // should hear about it rather than silently plot on the wrong axis.
      //
      // Derived from the map rather than listed, so a metric added later
      // with a null maximum is covered without anyone remembering to.
      final unbounded = {
        for (final e in _all.entries)
          if (e.value.max == null) e.key,
      };
      expect(unbounded, {'mod', 'meanDepth', 'cns', 'otu'});
      for (final name in unbounded) {
        expect(() => _all[name]!.fixedMax, throwsStateError, reason: name);
      }

      // A fixed-band metric hands its maximum over as normal.
      expect(ProfileMetricBands.ppO2.fixedMax, 2.0);
    });
  });
}
