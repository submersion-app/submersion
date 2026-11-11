import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
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

  PinnedStripPainter painter({PlotMapping? from, double morph = 0}) =>
      PinnedStripPainter(
        profile: profile,
        selectedSeconds: null,
        curveColor: Colors.blue,
        fillColors: const [Colors.blue, Colors.blue],
        markerColor: Colors.red,
        from: from,
        morph: morph,
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
    // Inside the curve area, above the 16 px values row.
    expect(m.rect.top, greaterThanOrEqualTo(0));
    expect(m.rect.bottom, lessThanOrEqualTo(kPinnedStripHeight - 16));
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

    test('pinned, it is the whole curve area above the values row', () {
      final p = painter(from: chart, morph: 1);
      const size = Size(400, kPinnedStripHeight);
      expect(
        p.clipFor(size),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight - 16),
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
}
