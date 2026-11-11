import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

void main() {
  // A dive of 0..1200 s and 0..24 m, drawn zoomed in 2x a quarter of the way
  // across and down: 300..900 s, 6..18 m.
  final frame = ProfilePlotFrame(
    plotKey: GlobalKey(),
    plotRect: const Rect.fromLTWH(40, 30, 300, 200),
    minSeconds: 300,
    maxSeconds: 900,
    minDepthMeters: 6,
    maxDepthMeters: 18,
    viewport: const ChartViewport(zoom: 2, offsetX: 0.25, offsetY: 0.25),
  );

  // The pinned profile works out the copy's ranges for the window it is
  // handing the copy this frame, rather than waiting a frame for the copy
  // to report them (#4423).
  group('withViewport', () {
    test('is what the plot spans in another window', () {
      final full = frame.withViewport(ChartViewport.reset);
      expect(full.minSeconds, closeTo(0, 1e-9));
      expect(full.maxSeconds, closeTo(1200, 1e-9));
      expect(full.minDepthMeters, closeTo(0, 1e-9));
      expect(full.maxDepthMeters, closeTo(24, 1e-9));

      final deeper = frame.withViewport(
        const ChartViewport(zoom: 4, offsetX: 0.5),
      );
      expect(deeper.minSeconds, closeTo(600, 1e-9));
      expect(deeper.maxSeconds, closeTo(900, 1e-9));
      expect(deeper.minDepthMeters, closeTo(0, 1e-9));
      expect(deeper.maxDepthMeters, closeTo(6, 1e-9));
    });

    test('keeps the plot and records the new window', () {
      final full = frame.withViewport(ChartViewport.reset);
      expect(full.plotRect, frame.plotRect);
      expect(full.plotKey, frame.plotKey);
      expect(full.viewport.sameWindowAs(ChartViewport.reset), isTrue);
    });
  });

  test('frames drawn with different windows differ', () {
    final other = ProfilePlotFrame(
      plotKey: frame.plotKey,
      plotRect: frame.plotRect,
      minSeconds: 300,
      maxSeconds: 900,
      minDepthMeters: 6,
      maxDepthMeters: 18,
    );
    expect(other, isNot(frame));
    expect(other.viewport.sameWindowAs(ChartViewport.reset), isTrue);
  });

  // Reports a chart's frame after the frame it was laid out in, and only
  // when it changes. Called from a build, as the chart calls it.
  group('ProfilePlotFrameReporter', () {
    Future<void> buildReporting(WidgetTester tester, void Function() report) =>
        tester.pumpWidget(
          Builder(
            builder: (context) {
              report();
              return const SizedBox();
            },
          ),
        );

    testWidgets('reports a new frame once, after its frame', (tester) async {
      final reporter = ProfilePlotFrameReporter();
      final sent = <ProfilePlotFrame>[];
      var sentDuringBuild = -1;
      await buildReporting(tester, () {
        reporter.report(frame, sent.add, mounted: () => true);
        sentDuringBuild = sent.length;
      });
      expect(sentDuringBuild, 0);
      expect(sent, [frame]);

      await buildReporting(
        tester,
        () => reporter.report(frame, sent.add, mounted: () => true),
      );
      expect(sent, [frame]);
    });

    testWidgets('reports nothing without a listener or once unmounted', (
      tester,
    ) async {
      final reporter = ProfilePlotFrameReporter();
      final sent = <ProfilePlotFrame>[];
      await buildReporting(tester, () {
        reporter.report(frame, null, mounted: () => true);
        reporter.report(
          frame.withViewport(ChartViewport.reset),
          sent.add,
          mounted: () => false,
        );
      });
      expect(sent, isEmpty);
    });
  });
}
