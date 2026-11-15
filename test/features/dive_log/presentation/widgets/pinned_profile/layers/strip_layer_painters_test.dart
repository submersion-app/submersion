import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_band_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_line_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_marker_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';

/// Twenty minutes, from second 60: 400 px wide, a second is 1/3 px.
const _profile = [
  DiveProfilePoint(timestamp: 60, depth: 0),
  DiveProfilePoint(timestamp: 660, depth: 20),
  DiveProfilePoint(timestamp: 1260, depth: 0),
];

PinnedStripPainter _strip({double height = kPinnedStripHeight}) =>
    PinnedStripPainter(
      profile: _profile,
      curveColor: Colors.blue,
      fillColors: const [Colors.blue, Colors.blue],
      surfaceColor: Colors.white,
      curveHeight: height,
    );

const _temperature = StripLine(
  layer: StripLayer.temperature,
  key: 'temperature',
  color: Color(0xFFFF0000),
  runs: [
    [StripPoint(60, 20), StripPoint(1260, 10)],
  ],
  min: 10,
  max: 20,
);

StripLayerState _state(
  PinnedStripLayerData data,
  Map<StripLayer, double> strengths,
) => StripLayerState(
  data: data,
  strengths: strengths,
  grow: 0,
  active: strengths.keys.toSet(),
);

Future<void> _pump(
  WidgetTester tester,
  CustomPainter painter, {
  double height = kPinnedStripHeight,
}) => tester.pumpWidget(
  Center(
    child: SizedBox(
      width: 400,
      height: height,
      child: CustomPaint(painter: painter),
    ),
  ),
);

double _x(int seconds) => (seconds - 60) / 1200 * 400;

void main() {
  group('lines', () {
    const size = Size(400, kPinnedStripHeight);
    final painter = StripLinePainter(
      strip: _strip(),
      layers: _state(const PinnedStripLayerData(lines: [_temperature]), {
        StripLayer.temperature: 1,
      }),
    );

    test('a value at max sits at the curve top, at min at the bottom', () {
      final runs = _temperature.runs.single;
      expect(painter.linePointFor(size, _temperature, runs.first).dy, 4);
      expect(painter.linePointFor(size, _temperature, runs.last).dy, 40);
      expect(painter.linePointFor(size, _temperature, runs.last).dx, 400);
    });

    test('grown, max stays at the top and min drops 28 px', () {
      final grown = StripLinePainter(
        strip: _strip(height: kPinnedStripGrownHeight),
        layers: painter.layers,
      );
      const tall = Size(400, kPinnedStripGrownHeight);
      final runs = _temperature.runs.single;
      expect(grown.linePointFor(tall, _temperature, runs.first).dy, 4);
      expect(grown.linePointFor(tall, _temperature, runs.last).dy, 68);
    });

    test('a flat series sits half way up', () {
      const flat = StripLine(
        layer: StripLayer.sac,
        key: 'sac',
        color: Colors.teal,
        runs: [
          [StripPoint(60, 15), StripPoint(1260, 15)],
        ],
        min: 15,
        max: 15,
      );
      expect(painter.linePointFor(size, flat, flat.runs.single.first).dy, 22);
    });

    testWidgets('a line is drawn in its colour at its strength', (
      tester,
    ) async {
      await _pump(
        tester,
        StripLinePainter(
          strip: _strip(),
          layers: _state(const PinnedStripLayerData(lines: [_temperature]), {
            StripLayer.temperature: 0.5,
          }),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..path(
          color: const Color(0xFFFF0000).withValues(alpha: 0.5),
          style: PaintingStyle.stroke,
          strokeWidth: 1.5,
        ),
      );
    });

    testWidgets('an estimated tank line is drawn dashed, and kept', (
      tester,
    ) async {
      const estimate = StripLine(
        layer: StripLayer.tankPressure,
        key: 't1',
        color: Color(0xFF00AA00),
        runs: [
          [StripPoint(60, 200), StripPoint(1260, 60)],
        ],
        min: 60,
        max: 200,
        estimated: true,
        label: 'Tank 1',
      );
      final p = StripLinePainter(
        strip: _strip(),
        layers: _state(const PinnedStripLayerData(lines: [estimate]), {
          StripLayer.tankPressure: 1,
        }),
      );
      await _pump(tester, p);
      expect(
        find.byType(CustomPaint),
        paints..path(color: const Color(0xFF00AA00), strokeWidth: 1.5),
      );
      // Painted again through the same mapping, the dashes are reused.
      await _pump(tester, p);
      expect(find.byType(CustomPaint), paints..path());
    });

    testWidgets('a layer at strength 0 paints nothing', (tester) async {
      await _pump(
        tester,
        StripLinePainter(
          strip: _strip(),
          layers: _state(const PinnedStripLayerData(lines: [_temperature]), {}),
        ),
      );
      expect(find.byType(CustomPaint), paintsNothing);
    });

    testWidgets('a ghost is a faint line on the depth scale', (tester) async {
      const ghost = StripGhost(
        layer: StripLayer.plannedDepth,
        key: 'plan',
        label: 'Plan',
        color: Color(0xFF00FF00),
        points: [StripPoint(60, 0), StripPoint(660, 20), StripPoint(1260, 0)],
      );
      final p = StripLinePainter(
        strip: _strip(),
        layers: _state(const PinnedStripLayerData(ghosts: [ghost]), {
          StripLayer.plannedDepth: 1,
        }),
      );
      expect(p.ghostPointFor(size, ghost.points[1]), const Offset(200, 40));
      await _pump(tester, p);
      expect(
        find.byType(CustomPaint),
        paints..path(
          color: const Color(0xFF00FF00).withValues(alpha: kStripGhostAlpha),
          style: PaintingStyle.stroke,
          strokeWidth: 1,
        ),
      );
    });
  });

  test('the marks repaint when the depth line changes colour', () {
    final layers = _state(
      const PinnedStripLayerData(
        dots: [StripDot(seconds: 660, depthMeters: 20)],
      ),
      {StripLayer.media: 1},
    );
    const red = PinnedStripPainter(
      profile: _profile,
      curveColor: Colors.red,
      fillColors: [Colors.blue, Colors.blue],
      surfaceColor: Colors.white,
    );
    expect(
      StripMarkerPainter(
        strip: red,
        layers: layers,
      ).shouldRepaint(StripMarkerPainter(strip: _strip(), layers: layers)),
      isTrue,
    );
  });

  group('bands', () {
    testWidgets('a phase tints the strip from its start to its end', (
      tester,
    ) async {
      const band = StripBand(
        layer: StripLayer.phases,
        start: 360,
        end: 660,
        color: Color(0xFF0000FF),
        alpha: 0.2,
        phase: DivePhase.bottom,
      );
      await _pump(
        tester,
        StripBandPainter(
          strip: _strip(),
          layers: _state(const PinnedStripLayerData(bands: [band]), {
            StripLayer.phases: 0.5,
          }),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..rect(
          rect: Rect.fromLTRB(_x(360), 0, _x(660), kPinnedStripHeight),
          color: const Color(0xFF0000FF).withValues(alpha: 0.1),
        ),
      );
    });

    testWidgets('a finding window has a solid edge where it starts', (
      tester,
    ) async {
      const band = StripBand(
        layer: StripLayer.safetyFindings,
        start: 360,
        end: 660,
        color: Color(0xFFAA0000),
        alpha: 0.2,
      );
      await _pump(
        tester,
        StripBandPainter(
          strip: _strip(),
          layers: _state(const PinnedStripLayerData(bands: [band]), {
            StripLayer.safetyFindings: 1,
          }),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..rect(rect: Rect.fromLTRB(_x(360), 0, _x(660), kPinnedStripHeight))
          ..line(
            p1: Offset(_x(360), 0),
            p2: Offset(_x(360), kPinnedStripHeight),
            color: const Color(0xFFAA0000),
          ),
      );
    });

    testWidgets('no strength, no band', (tester) async {
      await _pump(
        tester,
        StripBandPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              bands: [
                StripBand(
                  layer: StripLayer.phases,
                  start: 360,
                  end: 660,
                  color: Colors.blue,
                  alpha: 0.2,
                ),
              ],
            ),
            {},
          ),
        ),
      );
      expect(find.byType(CustomPaint), paintsNothing);
    });
  });

  group('markers', () {
    testWidgets('a top tick hangs from the top edge', (tester) async {
      await _pump(
        tester,
        StripMarkerPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              ticks: [
                StripTick(
                  layer: StripLayer.annotations,
                  seconds: 660,
                  color: Color(0xFFFFAA00),
                  edge: StripTickEdge.top,
                ),
              ],
            ),
            {StripLayer.annotations: 1},
          ),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..line(
          p1: const Offset(200, 0),
          p2: const Offset(200, kStripTickLength),
          color: const Color(0xFFFFAA00),
        ),
      );
    });

    testWidgets('a bookmark is a ring at the top', (tester) async {
      await _pump(
        tester,
        StripMarkerPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              ticks: [
                StripTick(
                  layer: StripLayer.annotations,
                  seconds: 660,
                  color: Color(0xFFFFAA00),
                  edge: StripTickEdge.top,
                  hollow: true,
                ),
              ],
            ),
            {StripLayer.annotations: 1},
          ),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..circle(x: 200, y: 4, radius: 2.5, style: PaintingStyle.stroke),
      );
    });

    testWidgets('a bottom tick stands on the bottom edge', (tester) async {
      await _pump(
        tester,
        StripMarkerPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              ticks: [
                StripTick(
                  layer: StripLayer.gasSwitches,
                  seconds: 660,
                  color: Color(0xFF00AA00),
                  edge: StripTickEdge.bottom,
                ),
              ],
            ),
            {StripLayer.gasSwitches: 1},
          ),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..line(
          p1: const Offset(200, kPinnedStripHeight),
          p2: const Offset(200, kPinnedStripHeight - kStripTickLength),
        ),
      );
    });

    testWidgets('dots too close to tell apart are drawn as one', (
      tester,
    ) async {
      await _pump(
        tester,
        StripMarkerPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              dots: [
                StripDot(seconds: 660, depthMeters: 20),
                StripDot(seconds: 663, depthMeters: 20),
              ],
            ),
            {StripLayer.media: 1},
          ),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..circle(radius: kStripClusterRadius)
          ..circle(radius: kStripClusterRadius),
      );
      expect(
        find.byType(CustomPaint),
        isNot(paints..circle(radius: kStripDotRadius)),
      );
    });

    testWidgets('while condensing, ticks hang from the curve area', (
      tester,
    ) async {
      // The chart's plot, 20 px down and 100 px tall in a 300 px box.
      const plot = PlotMapping(
        rect: Rect.fromLTWH(0, 20, 400, 100),
        minSeconds: 60,
        maxSeconds: 1260,
        minDepthMeters: 0,
        maxDepthMeters: 20,
      );
      const strip = PinnedStripPainter(
        profile: _profile,
        curveColor: Colors.blue,
        fillColors: [Colors.blue, Colors.blue],
        surfaceColor: Colors.white,
        from: plot,
        morph: 0,
      );
      await _pump(
        tester,
        StripMarkerPainter(
          strip: strip,
          layers: _state(
            const PinnedStripLayerData(
              ticks: [
                StripTick(
                  layer: StripLayer.gasSwitches,
                  seconds: 660,
                  color: Color(0xFF00AA00),
                  edge: StripTickEdge.bottom,
                ),
                StripTick(
                  layer: StripLayer.annotations,
                  seconds: 660,
                  color: Color(0xFFFFAA00),
                  edge: StripTickEdge.top,
                ),
              ],
            ),
            {StripLayer.gasSwitches: 1, StripLayer.annotations: 1},
          ),
        ),
        height: 300,
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..line(
            p1: const Offset(200, 120),
            p2: const Offset(200, 120 - kStripTickLength),
          )
          ..line(
            p1: const Offset(200, 20),
            p2: const Offset(200, 20 + kStripTickLength),
          ),
      );
    });

    testWidgets('a media dot sits on the depth line', (tester) async {
      await _pump(
        tester,
        StripMarkerPainter(
          strip: _strip(),
          layers: _state(
            const PinnedStripLayerData(
              dots: [StripDot(seconds: 660, depthMeters: 20)],
            ),
            {StripLayer.media: 1},
          ),
        ),
      );
      expect(
        find.byType(CustomPaint),
        paints..circle(x: 200, y: 40, radius: kStripDotRadius),
      );
    });
  });
}
