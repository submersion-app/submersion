import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

void main() {
  const geometry = PlanChartGeometry(
    size: Size(500, 400),
    maxTimeSeconds: 3600,
    maxDepthMeters: 40,
    depthUnitScale: 1,
  );

  group('mapping', () {
    test('time 0 maps to plot left, depth 0 to plot top', () {
      expect(geometry.xFor(0), geometry.plotRect.left);
      expect(geometry.yFor(0), geometry.plotRect.top);
    });

    test('max time maps inside the plot (5 percent padding)', () {
      final x = geometry.xFor(3600);
      expect(x, lessThan(geometry.plotRect.right));
      expect(x, greaterThan(geometry.plotRect.left));
    });

    test('timeAtDx inverts xFor and clamps to the data range', () {
      expect(geometry.timeAtDx(geometry.xFor(1800)), closeTo(1800, 0.01));
      expect(geometry.timeAtDx(-50), 0);
      expect(geometry.timeAtDx(10000), 3600);
    });

    test('deeper is lower on screen', () {
      expect(geometry.yFor(30), greaterThan(geometry.yFor(10)));
    });

    test('depthAtDy inverts yFor and clamps to the padded range', () {
      expect(geometry.depthAtDy(geometry.yFor(20)), closeTo(20, 0.01));
      expect(geometry.depthAtDy(-50), 0);
      expect(geometry.depthAtDy(100000), closeTo(40 * 1.1, 0.01));
    });
  });

  group('ticks', () {
    test('niceInterval matches the legacy ladder', () {
      expect(PlanChartGeometry.niceInterval(8), 2);
      expect(PlanChartGeometry.niceInterval(18), 5);
      expect(PlanChartGeometry.niceInterval(45), 10);
      expect(PlanChartGeometry.niceInterval(90), 20);
      expect(PlanChartGeometry.niceInterval(200), 30);
    });

    test('depth interval respects the display unit scale (feet)', () {
      const feet = PlanChartGeometry(
        size: Size(500, 400),
        maxTimeSeconds: 3600,
        maxDepthMeters: 40,
        depthUnitScale: 3.2808,
      );
      // 40 m * 1.1 padding * 3.2808 = ~144 ft display -> 30 ft interval,
      // converted back to meters for drawing.
      expect(feet.depthTickIntervalMeters, closeTo(30 / 3.2808, 0.001));
    });
  });

  test('meanDepthMeters is the time-weighted trapezoid mean', () {
    const profile = [
      CanvasPoint(0, 0),
      CanvasPoint(100, 20),
      CanvasPoint(300, 20),
    ];
    // 100 s ramp averaging 10 m + 200 s flat at 20 m = (1000 + 4000) / 300.
    expect(
      PlanChartGeometry.meanDepthMeters(profile),
      closeTo(5000 / 300, 0.001),
    );
    expect(PlanChartGeometry.meanDepthMeters(const []), 0);
  });

  group('segmentIdAtTime', () {
    const gas = GasMix(o2: 21);
    final segments = [
      PlanSegment.descent(
        id: 'descent',
        targetDepth: 30,
        tankId: 't1',
        gasMix: gas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'bottom',
        depth: 30,
        durationMinutes: 20,
        tankId: 't1',
        gasMix: gas,
        order: 1,
      ),
    ];

    test('maps times to the covering segment', () {
      expect(segmentIdAtTime(segments, 50), 'descent');
      expect(segmentIdAtTime(segments, 600), 'bottom');
    });

    test('returns null past the last user segment', () {
      expect(segmentIdAtTime(segments, 5000), isNull);
    });

    test('empty segments yield null', () {
      expect(segmentIdAtTime(const [], 10), isNull);
    });
  });
}
