import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';

List<double> _labelled(List<VerticalScaleMark> marks) => [
  for (final m in marks)
    if (m.labelled) m.landmark.meters,
];

/// Where the bars, ticks and labels go on the scale (issue #4569).
void main() {
  group('VerticalScaleLayout, worked example at 525 m', () {
    // Next up is the Burj Khalifa (828), next down Crater Lake (594), so the
    // extent is 828 and the scale runs at 240 / (828 x 1.08) = 0.26839 px
    // per metre.
    final layout = VerticalScaleLayout.compute(
      totalMeters: 525,
      halfHeightPx: 240,
    );

    test('extent, bar and offsets', () {
      expect(layout.extentMeters, 828);
      expect(layout.barPx, closeTo(140.9, 0.1));
      expect(layout.offsetFor(828), closeTo(222.2, 0.1));
    });

    test('the next landmark closes each side, unpassed', () {
      expect(layout.ascentMarks.last.landmark.meters, 828);
      expect(layout.ascentMarks.last.passed, isFalse);
      expect(layout.descentMarks.last.landmark.meters, 594);
      expect(layout.descentMarks.last.passed, isFalse);
      expect(layout.ascentMarks.where((m) => !m.passed), hasLength(1));
    });

    test('labels closer than the gap are thinned from the top down', () {
      // Up: 828 at 222.2, 443 at 118.9, 330 at 88.6, 139 at 37.3, 93 at
      // 25.0; 93 is 12.3 px from 139.
      expect(_labelled(layout.ascentMarks), [139, 330, 443, 828]);
      // Down: 594 at 159.4, 332 at 89.1, 301 at 80.8, 202 at 54.2, 124 at
      // 33.3, 40 at 10.7; 301 is 8.3 px from 332.
      expect(_labelled(layout.descentMarks), [40, 124, 202, 332, 594]);
    });

    test('an unlabelled mark keeps its tick', () {
      final pyramid = layout.ascentMarks.first;
      expect(pyramid.landmark.meters, 93);
      expect(pyramid.labelled, isFalse);
      expect(pyramid.offsetPx, closeTo(25.0, 0.1));
    });

    test('metersAt is clamped to the total', () {
      expect(layout.metersAt(layout.barPx + 50), 525);
      expect(layout.metersAt(-5), 0);
      expect(layout.metersAt(layout.offsetFor(300)), closeTo(300, 1e-9));
    });

    test('snap finds a passed mark within the tolerance', () {
      expect(layout.snap(VerticalLeg.descent, 90.5)!.landmark.meters, 332);
      expect(layout.snap(VerticalLeg.descent, 100), isNull);
      // The next landmark is not passed, so it never snaps.
      expect(layout.snap(VerticalLeg.descent, 159.4), isNull);
    });
  });

  group('a scale shared by two cards', () {
    test('a total\'s own extent is the larger next landmark', () {
      // Next up from 525 m is the Burj Khalifa (828), next down Crater Lake
      // (594).
      expect(verticalScaleExtent(525), 828);
    });

    test('a larger shared extent shortens the bar, landmarks unchanged', () {
      final layout = VerticalScaleLayout.compute(
        totalMeters: 525,
        halfHeightPx: 240,
        extentMeters: 2000,
      );

      expect(layout.extentMeters, 2000);
      // 525 x 240 / (2000 x 1.08) = 58.33 px.
      expect(layout.barPx, closeTo(58.3, 0.1));
      expect(layout.ascentMarks.last.landmark.meters, 828);
      expect(layout.descentMarks.last.landmark.meters, 594);
    });

    test('a smaller shared extent never cuts off the next landmark', () {
      final layout = VerticalScaleLayout.compute(
        totalMeters: 525,
        halfHeightPx: 240,
        extentMeters: 300,
      );

      expect(layout.extentMeters, 828);
    });
  });

  group('VerticalScaleLayout, edge totals', () {
    test('the most recent passed label is nudged clear of the next one', () {
      // Total 8,700: K2 (8,611) passed, Everest (8,849) next. The extent is
      // the Tonga Trench (10,816), so the two sit about 5 px apart.
      final l = VerticalScaleLayout.compute(
        totalMeters: 8700,
        halfHeightPx: 240,
      );
      final next = l.ascentMarks.last;
      final recent = l.ascentMarks[l.ascentMarks.length - 2];
      expect(next.landmark.id, VerticalLandmarkId.everest);
      expect(recent.landmark.id, VerticalLandmarkId.k2);
      expect(recent.labelled, isTrue);
      expect(
        next.labelOffsetPx - recent.labelOffsetPx,
        greaterThanOrEqualTo(18 - 1e-9),
      );
      expect(recent.offsetPx, closeTo(l.offsetFor(8611), 1e-9));
    });

    test('a zero total lays out to the first landmarks', () {
      final l = VerticalScaleLayout.compute(totalMeters: 0, halfHeightPx: 240);
      expect(l.barPx, 0);
      expect(l.extentMeters, 93);
      expect(l.ascentMarks.single.passed, isFalse);
      expect(l.descentMarks.single.landmark.meters, 40);
      expect(l.metersAt(10), 0);
    });

    test('a very large total stays finite and labels stay apart', () {
      final l = VerticalScaleLayout.compute(
        totalMeters: 1000000,
        halfHeightPx: 240,
      );
      expect(l.barPx.isFinite, isTrue);
      expect(l.barPx, lessThanOrEqualTo(240));
      for (final marks in [l.ascentMarks, l.descentMarks]) {
        final offsets = [
          for (final m in marks)
            if (m.labelled) m.labelOffsetPx,
        ]..sort();
        for (var i = 1; i < offsets.length; i++) {
          expect(offsets[i] - offsets[i - 1], greaterThanOrEqualTo(18 - 1e-9));
        }
      }
    });

    test('labels on opposite sides of sea level keep their gap', () {
      // Total 5,115: the Eiffel Tower (330) sits 12 px above sea level and
      // the 40 m recreational limit 1.5 px below it, on the line itself.
      final l = VerticalScaleLayout.compute(
        totalMeters: 5115,
        halfHeightPx: 240,
      );
      final signed = [
        for (final m in l.ascentMarks)
          if (m.labelled) m.labelOffsetPx,
        for (final m in l.descentMarks)
          if (m.labelled) -m.labelOffsetPx,
      ]..sort();
      for (var i = 1; i < signed.length; i++) {
        expect(signed[i] - signed[i - 1], greaterThanOrEqualTo(18 - 1e-9));
      }
      for (final s in signed) {
        expect(s.abs(), greaterThanOrEqualTo(9 - 1e-9));
      }
      final limit = l.descentMarks.first;
      expect(limit.landmark.id, VerticalLandmarkId.recreationalLimit);
      expect(limit.labelled, isFalse);
    });

    test('across a sweep of totals, labels stay apart and above sea level', () {
      final totals = [
        for (var t = 0.0; t < 30000; t += 37) t,
        for (var t = 30000.0; t < 1200000; t += 9871) t,
      ];
      for (final total in totals) {
        final l = VerticalScaleLayout.compute(
          totalMeters: total,
          halfHeightPx: 240,
        );
        final signed = [
          for (final m in l.ascentMarks)
            if (m.labelled) m.labelOffsetPx,
          for (final m in l.descentMarks)
            if (m.labelled) -m.labelOffsetPx,
        ]..sort();
        for (final s in signed) {
          expect(s.abs(), greaterThanOrEqualTo(9 - 1e-9), reason: 't=$total');
          expect(s.abs(), lessThanOrEqualTo(240), reason: 't=$total');
        }
        for (var i = 1; i < signed.length; i++) {
          expect(
            signed[i] - signed[i - 1],
            greaterThanOrEqualTo(18 - 1e-9),
            reason: 't=$total',
          );
        }
      }
    });
  });
}
