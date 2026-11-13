import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ceilingFillAlpha;
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

void main() {
  const profile = [
    DiveProfilePoint(timestamp: 60, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 24),
    DiveProfilePoint(timestamp: 1260, depth: 0),
  ];
  const chart = PlotMapping(
    rect: Rect.fromLTWH(30, -80, 340, 220),
    minSeconds: 0,
    maxSeconds: 1500,
    minDepthMeters: 0,
    maxDepthMeters: 27,
  );

  PinnedStripPainter painter({
    PlotMapping? from,
    double morph = 0,
    List<int>? ndlCurve,
    List<double>? ceilingCurve,
    List<double>? decoStopCurve,
  }) => PinnedStripPainter(
    profile: profile,
    curveColor: Colors.blue,
    fillColors: const [Colors.blue, Colors.blue],
    from: from,
    morph: morph,
    ndlCurve: ndlCurve,
    ceilingCurve: ceilingCurve,
    decoStopCurve: decoStopCurve,
    surfaceColor: Colors.white,
  );

  Future<void> pumpPainter(WidgetTester tester, PinnedStripPainter p) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: kPinnedStripHeight,
              child: CustomPaint(painter: p),
            ),
          ),
        ),
      );

  test('at morph 0 it draws through the chart plot mapping', () {
    final m = painter(from: chart).mappingFor(const Size(400, 300));
    for (final (s, d) in [(60, 0.0), (600, 24.0), (1260, 0.0)]) {
      expect(m.project(s, d), chart.project(s, d));
    }
  });

  test('at morph 1 it draws through its own curve area', () {
    final m = painter(
      from: chart,
      morph: 1,
    ).mappingFor(const Size(400, kPinnedStripHeight));
    expect(m.minSeconds, 60);
    expect(m.maxSeconds, 1260);
    expect(m.minDepthMeters, 0);
    expect(m.maxDepthMeters, 24);
    expect(m.rect.left, 0);
    expect(m.rect.right, 400);
    // The whole strip is curve now, less its breathing room.
    expect(m.rect.top, 4);
    expect(m.rect.bottom, kPinnedStripHeight - 4);
  });

  // The strip's box is still tall while it condenses. Aimed at the box's
  // curve area, the line grew back out of the squashed chart's 48 px plot
  // and then shrank again as the box closed: a bounce.
  group('while the box is still tall', () {
    const tall = Size(400, 300);
    const squashed = PlotMapping(
      rect: Rect.fromLTWH(0, 0, 400, 48),
      minSeconds: 0,
      maxSeconds: 1500,
      minDepthMeters: 0,
      maxDepthMeters: 27,
    );

    test('its own curve area is already the pinned strip\'s', () {
      final inTall = painter(morph: 1).mappingFor(tall).rect;
      final pinned = painter(
        morph: 1,
      ).mappingFor(const Size(400, kPinnedStripHeight)).rect;
      expect(inTall, pinned);
    });

    test('the line only ever shrinks from the squashed chart', () {
      var last = double.infinity;
      for (var i = 0; i <= 10; i++) {
        final h = painter(
          from: squashed,
          morph: i / 10,
        ).mappingFor(tall).rect.height;
        expect(h, lessThanOrEqualTo(last + 1e-9), reason: 'morph ${i / 10}');
        last = h;
      }
    });

    test('its clip ends on the pinned curve area', () {
      expect(
        painter(from: squashed, morph: 1).clipFor(tall),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight),
      );
    });
  });

  test('without a chart plot it draws through its own mapping', () {
    final own = painter(morph: 1).mappingFor(const Size(400, 300));
    final none = painter().mappingFor(const Size(400, 300));
    expect(none.rect, own.rect);
  });

  // The chart clips its line to the plot; zoomed in, the rest of the dive
  // lies outside it and must not show over the axes (review I3).
  group('clip', () {
    test('at morph 0 it is the chart plot', () {
      expect(painter(from: chart).clipFor(const Size(400, 300)), chart.rect);
    });

    test('pinned, it is the whole strip', () {
      final p = painter(from: chart, morph: 1);
      const size = Size(400, kPinnedStripHeight);
      expect(
        p.clipFor(size),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight),
      );
    });

    test('in between, it is between the two', () {
      final clip = painter(
        from: chart,
        morph: 0.5,
      ).clipFor(const Size(400, kPinnedStripHeight))!;
      expect(clip.left, closeTo((30 + 0) / 2, 1e-9));
      expect(clip.right, closeTo((370 + 400) / 2, 1e-9));
    });

    test('there is none without a chart plot', () {
      expect(painter().clipFor(const Size(400, 300)), isNull);
    });
  });

  // Every field of the starting mapping is compared (review M7).
  test('repaints when any part of the starting mapping changes', () {
    final moved = PlotMapping(
      rect: chart.rect,
      minSeconds: 30,
      maxSeconds: chart.maxSeconds,
      minDepthMeters: chart.minDepthMeters,
      maxDepthMeters: chart.maxDepthMeters,
    );
    expect(painter(from: moved).shouldRepaint(painter(from: chart)), isTrue);
    expect(painter(from: chart).shouldRepaint(painter(from: chart)), isFalse);
  });

  // Like the full chart: the water below the depth line is shaded, the space
  // above it is clear.
  group('fill', () {
    const size = Size(400, kPinnedStripHeight);

    test('covers the area below the depth line', () {
      final p = painter(morph: 1);
      final m = p.mappingFor(size);
      final fill = p.fillPathFor(size)!;
      // At 11 min the line is near 22 m: 2 m is above it, in clear water.
      final aboveLine = m.project(660, 2);
      expect(fill.contains(aboveLine), isFalse);
      // At 2 min the line is near 3 m: 20 m is below it, shaded.
      final belowShallowPart = m.project(120, 20);
      expect(fill.contains(belowShallowPart), isTrue);
    });
  });

  // One depth line throughout the hand-over: the strip draws it at the full
  // chart's own width, so it does not thicken as it takes over.
  testWidgets('draws the depth line at the full chart line width', (
    tester,
  ) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 400,
          height: kPinnedStripHeight,
          child: CustomPaint(painter: painter(morph: 1)),
        ),
      ),
    );
    expect(
      find.byType(CustomPaint),
      paints
        // The shading below the line comes first.
        ..path()
        ..path(
          color: Colors.blue,
          style: PaintingStyle.stroke,
          strokeWidth: kProfileDepthLineWidth,
        ),
    );
    expect(kProfileDepthLineWidth, 1);
  });

  test('kPinnedStripHeight is 44', () {
    expect(kPinnedStripHeight, 44);
  });

  // Issue #4509: the NDL line, on the full chart's 0 to 60 minute scale.
  group('NDL line', () {
    testWidgets('draws the NDL line in the NDL colour', (tester) async {
      await pumpPainter(tester, painter(morph: 1, ndlCurve: [3600, 1800, 0]));
      expect(
        find.byType(CustomPaint),
        paints
          // Depth shading and line first, then the NDL line over them.
          ..path()
          ..path(color: Colors.blue)
          ..path(
            color: ProfileMetricColors.ndl,
            style: PaintingStyle.stroke,
            strokeWidth: 1.5,
          ),
      );
    });

    test('NDL at an hour sits at the top of the curve area, zero at the '
        'bottom', () {
      final p = painter(morph: 1, ndlCurve: [3600, 1800, 0]);
      const size = Size(400, kPinnedStripHeight);
      expect(p.ndlPointFor(size, 0, 3600).dy, 4);
      expect(p.ndlPointFor(size, 0, 0).dy, 40);
      expect(p.ndlPointFor(size, 0, 1800).dy, 22);
    });

    testWidgets('no NDL curve, no NDL line', (tester) async {
      await pumpPainter(tester, painter(morph: 1));
      // The depth shading and line only.
      expect(find.byType(CustomPaint), paintsExactlyCountTimes(#drawPath, 2));
    });

    testWidgets('curves shorter than the profile draw no further', (
      tester,
    ) async {
      await pumpPainter(
        tester,
        painter(
          morph: 1,
          ndlCurve: [3600],
          ceilingCurve: [3],
          decoStopCurve: [3],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('curves longer than the profile stop at its end', (
      tester,
    ) async {
      await pumpPainter(
        tester,
        painter(morph: 1, ndlCurve: [600, 600, 600, 600, 600]),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('deco bands', () {
    testWidgets('shades the stop band where there is an obligation', (
      tester,
    ) async {
      await pumpPainter(
        tester,
        painter(morph: 1, decoStopCurve: [0, 6, 0], ceilingCurve: [0, 4, 0]),
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..path()
          ..path(color: decoStopBandColor.withValues(alpha: decoStopFillAlpha))
          ..path(color: decoStopBandColor, style: PaintingStyle.stroke)
          ..path(
            color: ProfileMetricColors.ceiling.withValues(
              alpha: ceilingFillAlpha,
            ),
          )
          ..path(
            color: ProfileMetricColors.ceiling,
            style: PaintingStyle.stroke,
          )
          ..path(color: Colors.blue),
      );
    });

    // The full chart steps its stop band (fl_chart stepDirection 0: hold the
    // last stop until the next sample, then drop); a diagonal between the
    // two samples either side of a change slanted it (review).
    testWidgets('the stop band steps square at a change', (tester) async {
      await pumpPainter(tester, painter(morph: 1, decoStopCurve: [6, 6, 3]));
      // 1200 s of 60 to 1260 s, at 5 m: inside a held 6 m stop, outside a
      // diagonal from 6 m at 600 s to 3 m at 1260 s.
      const held = Offset(380, 4 + 5 / 24 * 36);
      expect(
        find.byType(CustomPaint),
        paints
          ..path()
          ..path(
            color: decoStopBandColor.withValues(alpha: decoStopFillAlpha),
            includes: const [held],
          ),
      );
    });

    // The chart's step band holds a stop until the next sample before it
    // drops, so a stop logged on one sample still shows (review).
    testWidgets('a stop holds until the next sample', (tester) async {
      await pumpPainter(tester, painter(morph: 1, decoStopCurve: [0, 6, 0]));
      // Halfway from 600 s to 1260 s, at 3 m: inside a 6 m stop held to the
      // next sample.
      const held = Offset(290, 4 + 3 / 24 * 36);
      expect(
        find.byType(CustomPaint),
        paints
          ..path()
          ..path(
            color: decoStopBandColor.withValues(alpha: decoStopFillAlpha),
            includes: const [held],
          ),
      );
    });

    testWidgets('no obligation, no band', (tester) async {
      await pumpPainter(
        tester,
        painter(morph: 1, decoStopCurve: [0, 0, 0], ceilingCurve: [0, 0, 0]),
      );
      // The depth shading and line only.
      expect(find.byType(CustomPaint), paintsExactlyCountTimes(#drawPath, 2));
    });
  });

  group('max-depth marker', () {
    testWidgets('draws the max-depth dot at the deepest sample', (
      tester,
    ) async {
      await pumpPainter(tester, painter(morph: 1));
      // 600 s of 60 to 1260 s across 400 px; 24 m is the curve area's
      // bottom, 4 px above the strip's.
      expect(
        find.byType(CustomPaint),
        paints..circle(
          x: 180,
          y: 40,
          radius: 3.5,
          color: ProfileMetricColors.maxDepth,
        ),
      );
    });

    testWidgets('no profile depth, no marker', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            painter: PinnedStripPainter(
              profile: [
                DiveProfilePoint(timestamp: 0, depth: 0),
                DiveProfilePoint(timestamp: 60, depth: 0),
              ],
              curveColor: Colors.blue,
              fillColors: [Colors.blue, Colors.blue],
              morph: 1,
              surfaceColor: Colors.white,
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), paintsExactlyCountTimes(#drawCircle, 0));
    });
  });

  // Every layer behaves as the depth line does: it travels through the
  // condense at full strength and only cross-fades with the strip's surface
  // (an Opacity above the painter). Faded with the condense as well, the
  // chart's own bands were covered and then faded back in (issue #4509).
  testWidgets('new layers ride the condense at full strength', (tester) async {
    await pumpPainter(
      tester,
      painter(
        morph: 0.5,
        ndlCurve: [3600, 1800, 600],
        decoStopCurve: [0, 6, 0],
      ),
    );
    expect(
      find.byType(CustomPaint),
      paints
        ..path()
        ..path(color: decoStopBandColor.withValues(alpha: decoStopFillAlpha))
        ..path(color: decoStopBandColor, style: PaintingStyle.stroke)
        ..path(color: Colors.blue)
        ..path(color: ProfileMetricColors.ndl)
        ..circle(color: ProfileMetricColors.maxDepth),
    );
  });

  testWidgets('on the chart line the layers are already drawn', (tester) async {
    await pumpPainter(
      tester,
      painter(from: chart, morph: 0, decoStopCurve: [0, 6, 0]),
    );
    expect(
      find.byType(CustomPaint),
      paints
        ..path()
        ..path(color: decoStopBandColor.withValues(alpha: decoStopFillAlpha)),
    );
  });

  // The diver's chart colours (Settings > Appearance), as the full chart.
  testWidgets('draws its layers in the colours it is given', (tester) async {
    await pumpPainter(
      tester,
      const PinnedStripPainter(
        profile: profile,
        curveColor: Colors.blue,
        fillColors: [Colors.blue, Colors.blue],
        morph: 1,
        ndlCurve: [3600, 1800, 600],
        ceilingCurve: [0, 4, 0],
        ndlColor: Colors.green,
        ceilingColor: Colors.orange,
        maxDepthColor: Colors.purple,
      ),
    );
    expect(
      find.byType(CustomPaint),
      paints
        ..path()
        ..path(color: Colors.orange.withValues(alpha: ceilingFillAlpha))
        ..path(color: Colors.orange, style: PaintingStyle.stroke)
        ..path(color: Colors.blue)
        ..path(color: Colors.green)
        ..circle(color: Colors.purple),
    );
  });

  testWidgets('band edges keep their colour\'s own alpha', (tester) async {
    final half = Colors.orange.withValues(alpha: 0.5);
    await pumpPainter(
      tester,
      PinnedStripPainter(
        profile: profile,
        curveColor: Colors.blue,
        fillColors: const [Colors.blue, Colors.blue],
        morph: 1,
        ceilingCurve: const [0, 4, 0],
        ceilingColor: half,
      ),
    );
    expect(
      find.byType(CustomPaint),
      paints
        ..path()
        ..path()
        ..path(color: half, style: PaintingStyle.stroke),
    );
  });

  // The cursor has a painter of its own, so moving it repaints only the
  // cursor, not the curve, bands, NDL line and marker (review).
  group('cursor', () {
    PinnedStripCursorPainter cursor(int? seconds, {double morph = 1}) =>
        PinnedStripCursorPainter(
          strip: painter(morph: morph),
          selectedSeconds: seconds,
          color: Colors.red,
        );

    testWidgets('draws the cursor line and its depth dot', (tester) async {
      await pumpPainter(tester, painter(morph: 1));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: kPinnedStripHeight,
              child: CustomPaint(painter: cursor(600)),
            ),
          ),
        ),
      );
      // 600 s of 60 to 1260 s across 400 px, 24 m at the plot's bottom.
      expect(
        find.byType(CustomPaint),
        paints
          ..line(
            p1: const Offset(180, 4),
            p2: const Offset(180, 40),
            color: Colors.red,
            strokeWidth: 1.5,
          )
          ..circle(x: 180, y: 40, radius: 4, color: Colors.red),
      );
    });

    testWidgets('no cursor, nothing drawn', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: kPinnedStripHeight,
              child: CustomPaint(painter: cursor(null)),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), paintsNothing);
    });

    test('moving the cursor does not repaint the strip itself', () {
      expect(cursor(600).shouldRepaint(cursor(300)), isTrue);
      expect(cursor(600).shouldRepaint(cursor(600)), isFalse);
      expect(cursor(600, morph: 0.5).shouldRepaint(cursor(600)), isTrue);
      expect(painter(morph: 1).shouldRepaint(painter(morph: 1)), isFalse);
    });
  });

  test('repaints when a curve changes', () {
    final base = painter(morph: 1, ndlCurve: [600, 600, 600]);
    expect(
      painter(morph: 1, ndlCurve: [600, 300, 600]).shouldRepaint(base),
      isTrue,
    );
    expect(
      painter(morph: 1, ndlCurve: base.ndlCurve).shouldRepaint(base),
      isFalse,
    );
  });

  // The painter runs on every scroll frame while the strip shows. Like the
  // full chart, it draws a bounded set of points and works out the dive's
  // depth bound once per profile, not once per paint (review).
  group('pinnedStripCurve', () {
    final dense = [
      for (var t = 0; t < 12000; t++)
        DiveProfilePoint(
          timestamp: t,
          depth: t == 7777 ? 41.5 : 20 + 5 * ((t % 60) / 60),
        ),
    ];

    test('keeps a dense dive within the chart\'s point budget', () {
      final curve = pinnedStripCurve(dense);
      expect(curve.points.length, lessThanOrEqualTo(kPinnedStripPointBudget));
      expect(curve.points.first.timestamp, 0);
      expect(curve.points.last.timestamp, 11999);
    });

    test('keeps the deepest point and knows the depth bound', () {
      final curve = pinnedStripCurve(dense);
      expect(curve.maxDepthMeters, 41.5);
      expect(curve.points.any((p) => p.depth == 41.5), isTrue);
    });

    test('is worked out once per profile', () {
      expect(
        identical(pinnedStripCurve(dense), pinnedStripCurve(dense)),
        isTrue,
      );
    });

    test('leaves a short dive as it is', () {
      expect(pinnedStripCurve(profile).points, profile);
      expect(pinnedStripCurve(profile).maxDepthMeters, 24);
    });
  });
}
