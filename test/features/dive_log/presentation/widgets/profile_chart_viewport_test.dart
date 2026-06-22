import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_chart_viewport.dart';

// Data fraction (0..1 of total range) currently under a focal point that sits
// at `focal` (0..1) of the visible window.
double _dataUnderFocal(double offset, double zoom, double focal) =>
    offset + focal / zoom;

void main() {
  group('ProfileChartViewport', () {
    test('reset is unzoomed at the origin', () {
      const vp = ProfileChartViewport.reset;
      expect(vp.zoom, 1.0);
      expect(vp.offsetX, 0.0);
      expect(vp.offsetY, 0.0);
      expect(vp.isZoomed, isFalse);
      expect(vp.visibleWidth, 1.0);
      expect(vp.visibleHeight, 1.0);
    });

    test('zoomedAt center keeps the center centered', () {
      final vp = ProfileChartViewport.reset.zoomedAt(0.5, 0.5, 2);
      expect(vp.zoom, 2.0);
      expect(vp.offsetX, closeTo(0.25, 1e-9));
      expect(vp.offsetY, closeTo(0.25, 1e-9));
      expect(vp.isZoomed, isTrue);
    });

    test('zoomedAt top-left pins the top-left corner', () {
      final vp = ProfileChartViewport.reset.zoomedAt(0, 0, 2);
      expect(vp.offsetX, closeTo(0.0, 1e-9));
      expect(vp.offsetY, closeTo(0.0, 1e-9));
    });

    test('zoomedAt bottom-right pins the bottom-right corner', () {
      final vp = ProfileChartViewport.reset.zoomedAt(1, 1, 2);
      expect(vp.offsetX, closeTo(0.5, 1e-9));
      expect(vp.offsetY, closeTo(0.5, 1e-9));
    });

    test('anchor invariant: the data point under the focal stays fixed', () {
      const cases = [
        [0.3, 0.7, 2.0],
        [0.2, 0.5, 3.0],
        [0.6, 0.4, 1.5],
      ];
      for (final c in cases) {
        const start = ProfileChartViewport(
          zoom: 2,
          offsetX: 0.25,
          offsetY: 0.25,
        );
        final before = _dataUnderFocal(start.offsetX, start.zoom, c[0]);
        final after = start.zoomedAt(c[0], c[1], c[2]);
        final now = _dataUnderFocal(after.offsetX, after.zoom, c[0]);
        expect(now, closeTo(before, 1e-9), reason: 'case $c');
      }
    });

    test('pannedBy clamps to [0, 1 - 1/zoom]', () {
      const vp = ProfileChartViewport(zoom: 2, offsetX: 0.25, offsetY: 0.25);
      final left = vp.pannedBy(-1, -1);
      expect(left.offsetX, 0.0);
      expect(left.offsetY, 0.0);
      final right = vp.pannedBy(1, 1);
      expect(right.offsetX, closeTo(0.5, 1e-9)); // maxOff = 1 - 1/2
      expect(right.offsetY, closeTo(0.5, 1e-9));
    });

    test('zoom clamps to [minZoom, maxZoom] and is a no-op at the rail', () {
      // Zooming out from reset cannot go below 1.0 -> unchanged instance.
      final out = ProfileChartViewport.reset.zoomedAt(0.5, 0.5, 0.5);
      expect(out.zoom, 1.0);
      expect(out.offsetX, 0.0);
      // At max zoom, zooming further in is a no-op.
      const atMax = ProfileChartViewport(zoom: 10, offsetX: 0.4, offsetY: 0.4);
      final stillMax = atMax.zoomedAt(0.5, 0.5, 2);
      expect(stillMax.zoom, 10.0);
      expect(stillMax.offsetX, 0.4);
    });

    test('zoom in then out at the same focal round-trips to the origin', () {
      final there = ProfileChartViewport.reset.zoomedAt(0.3, 0.7, 2);
      final back = there.zoomedAt(0.3, 0.7, 0.5);
      expect(back.zoom, closeTo(1.0, 1e-9));
      expect(back.offsetX, closeTo(0.0, 1e-9));
      expect(back.offsetY, closeTo(0.0, 1e-9));
    });
  });

  group('chartFocalFraction', () {
    const box = Size(200, 100);
    const insets = (left: 40.0, right: 10.0, top: 0.0, bottom: 24.0);
    // plotW = 200-40-10 = 150 ; plotH = 100-0-24 = 76

    test('left/top gutter maps to 0', () {
      final f = chartFocalFraction(
        const Offset(40, 0),
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      expect(f.fx, closeTo(0.0, 1e-9));
      expect(f.fy, closeTo(0.0, 1e-9));
    });

    test('right/bottom plot edge maps to 1', () {
      final f = chartFocalFraction(
        const Offset(190, 76),
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      expect(f.fx, closeTo(1.0, 1e-9));
      expect(f.fy, closeTo(1.0, 1e-9));
    });

    test('mid plot maps to the expected fraction', () {
      final f = chartFocalFraction(
        const Offset(115, 38),
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      expect(f.fx, closeTo(0.5, 1e-9)); // (115-40)/150
      expect(f.fy, closeTo(0.5, 1e-9)); // (38-0)/76
    });

    test('positions outside the plot clamp to [0,1]', () {
      final lo = chartFocalFraction(
        const Offset(0, -50),
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      expect(lo.fx, 0.0);
      expect(lo.fy, 0.0);
      final hi = chartFocalFraction(
        const Offset(500, 500),
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      expect(hi.fx, 1.0);
      expect(hi.fy, 1.0);
    });
  });

  group('chartDragIntent', () {
    test('two or more pointers always zoom+pan', () {
      for (final k in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        expect(
          chartDragIntent(kind: k, pointerCount: 2, doubleTapHold: false),
          ChartDragIntent.zoomPan,
        );
      }
    });

    test('single mouse/trackpad pointer pans', () {
      expect(
        chartDragIntent(
          kind: PointerDeviceKind.mouse,
          pointerCount: 1,
          doubleTapHold: false,
        ),
        ChartDragIntent.pan,
      );
      expect(
        chartDragIntent(
          kind: PointerDeviceKind.trackpad,
          pointerCount: 1,
          doubleTapHold: false,
        ),
        ChartDragIntent.pan,
      );
    });

    test('single touch pointer scrubs', () {
      expect(
        chartDragIntent(
          kind: PointerDeviceKind.touch,
          pointerCount: 1,
          doubleTapHold: false,
        ),
        ChartDragIntent.scrub,
      );
    });

    test('single touch pointer pans during double-tap-hold', () {
      expect(
        chartDragIntent(
          kind: PointerDeviceKind.touch,
          pointerCount: 1,
          doubleTapHold: true,
        ),
        ChartDragIntent.pan,
      );
    });
  });

  group('trackpad scroll maps to a cursor-anchored zoom factor', () {
    // The chart applies pow(2, trackpadScrollZoomDelta(dy)) as the zoom factor.
    test('scroll up produces a >1 factor (zoom in)', () {
      final factor = math.pow(2, trackpadScrollZoomDelta(-100)).toDouble();
      expect(factor, greaterThan(1.0));
      final vp = const ProfileChartViewport().zoomedAt(0.5, 0.5, factor);
      expect(vp.zoom, greaterThan(1.0));
    });

    test('scroll down produces a <1 factor and is a no-op at the min rail', () {
      final factor = math.pow(2, trackpadScrollZoomDelta(100)).toDouble();
      expect(factor, lessThan(1.0));
      final vp = const ProfileChartViewport().zoomedAt(0.5, 0.5, factor);
      expect(vp.zoom, ProfileChartViewport.minZoom);
    });
  });
}
