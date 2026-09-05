/// Combined-dive overlay coverage for every per-metric tooltip row and chart
/// line the profile chart draws from [ChartSourceOverlay.analysis] (deco
/// stops, ceiling, NDL, TTS, ppO2/ppN2/ppHe, MOD, density, GF%, surface GF%,
/// mean depth, GTR, CNS%, OTU). Each metric follows the same shape in the
/// widget: `if (_showX) { for (overlay in widget.overlays) { read
/// overlay.analysis?.xCurve via _overlayIndexAt, emit a row } }`, mirrored in
/// both the external tooltip ([DiveProfileChart.onTooltipData]) and the
/// in-chart tooltip bubble (fl_chart's getTooltipItems). This file exercises
/// every metric through both paths with a single overlay+active pair, rather
/// than repeating the harness per metric across many small files.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _n = 20;

List<DiveProfilePoint> _profile() => List.generate(
  _n,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < _n / 2 ? i * 2.0 : (_n - i) * 2.0,
  ),
);

/// Every curve populated, all index-aligned with a 20-point overlay profile.
/// Values are deliberately distinct from any active-source curve so a test
/// asserting on the overlay's own value cannot pass by accident against the
/// active row instead.
ProfileAnalysis _fullOverlayAnalysis() {
  return ProfileAnalysis(
    ascentRates: const [],
    ascentRateStats: const AscentRateStats(
      maxAscentRate: 0,
      maxDescentRate: 0,
      averageAscentRate: 0,
      averageDescentRate: 0,
      violationCount: 0,
      criticalViolationCount: 0,
      timeInViolation: 0,
    ),
    ascentRateViolations: const [],
    events: const [],
    // Dips to 0 every 5th sample so the overlay ceiling LINE (not just the
    // tooltip row) exercises its break/resume logic (pendingBreak, then a
    // null-spot when the curve resumes positive).
    ceilingCurve: List.generate(_n, (i) => i % 5 == 0 ? 0.0 : 3.0 + (i % 4)),
    decoStopCurve: List.generate(_n, (i) => 6.0 + (i % 3)),
    // Covers all three NDL tooltip branches: over-max (i<3), a normal
    // countdown (3<=i<10), and in-deco (i>=10).
    ndlCurve: List.generate(
      _n,
      (i) => i < 3 ? 4000 : (i < 10 ? 900 - i * 30 : -1),
    ),
    decoStatuses: const [],
    o2Exposure: const O2Exposure(otu: 0),
    ppO2Curve: List.generate(_n, (i) => 1.1 + i * 0.01),
    ppN2Curve: List.generate(_n, (i) => 2.2 + i * 0.01),
    ppHeCurve: List.generate(_n, (i) => 0.4 + i * 0.01),
    modCurve: List.generate(_n, (i) => 40.0 + i * 0.5),
    densityCurve: List.generate(_n, (i) => 3.3 + i * 0.05),
    gfCurve: List.generate(_n, (i) => 25.0 + i),
    surfaceGfCurve: List.generate(_n, (i) => 35.0 + i),
    meanDepthCurve: List.generate(_n, (i) => 12.0 + i * 0.2),
    ttsCurve: List.generate(_n, (i) => i < 10 ? 0 : (20 - i) * 60),
    gtrCurve: List.generate(_n, (i) => i == 5 ? null : 1200 - i * 30),
    cnsCurve: List.generate(_n, (i) => 4.0 + i * 0.5),
    otuCurve: List.generate(_n, (i) => 1.0 + i * 0.3),
    maxDepth: 20,
    averageDepth: 10,
    maxDepthTimestamp: 300,
    durationSeconds: _n * 30,
  );
}

Widget _harness({
  bool tooltipBelow = true,
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: _profile(),
            overlays: [
              ChartSourceOverlay(
                sourceId: 'src-b',
                name: 'Overlay',
                color: Colors.purple,
                computerId: 'comp-b',
                points: _profile(),
                analysis: _fullOverlayAnalysis(),
              ),
            ],
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

/// Toggle every legend metric the overlay renderers gate on, so their
/// per-metric blocks run for both the tooltip rows and the chart lines.
/// Ceiling, deco stops and NDL are deliberately NOT toggled here: all three
/// default to visible (via AppSettings.showCeilingOnProfile /
/// showDecoStopsOnProfile / showNdlOnProfile, all true), so toggling them
/// would turn them OFF.
void _enableAllOverlayMetrics(ProfileLegend notifier) {
  notifier
    ..togglePpO2()
    ..togglePpN2()
    ..togglePpHe()
    ..toggleMod()
    ..toggleDensity()
    ..toggleGf()
    ..toggleSurfaceGf()
    ..toggleMeanDepth()
    ..toggleTts()
    ..toggleGtr()
    ..toggleCns()
    ..toggleOtu();
}

void main() {
  group('DiveProfileChart overlay metrics - external tooltip', () {
    testWidgets(
      'every toggled metric emits an overlay row labelled "<metric> · '
      '<overlay name>"',
      (tester) async {
        List<TooltipRow>? rows;
        await tester.pumpWidget(
          _harness(tooltipBelow: true, onTooltipData: (r) => rows = r),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveProfileChart)),
        );
        _enableAllOverlayMetrics(
          container.read(profileLegendProvider.notifier),
        );
        await tester.pumpAndSettle();

        final data = tester
            .widget<LineChart>(find.byType(LineChart).first)
            .data;
        final depthBar = data.lineBarsData.first;
        final touchedSpot = depthBar.spots[5];

        data.lineTouchData.touchCallback!(
          FlPanDownEvent(DragDownDetails()),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            lineBarSpots: <TouchLineBarSpot>[
              TouchLineBarSpot(depthBar, 0, touchedSpot, 5),
            ],
          ),
        );

        expect(rows, isNotNull);
        final byLabel = {for (final r in rows!) r.label: r.value};

        final l10n = AppLocalizations.of(
          tester.element(find.byType(DiveProfileChart)),
        );
        for (final label in <String>[
          '${l10n.diveLog_tooltip_ceiling} · Overlay',
          '${l10n.diveLog_tooltip_decoStop} · Overlay',
          '${l10n.diveLog_tooltip_ndl} · Overlay',
          '${l10n.diveLog_tooltip_ppO2} · Overlay',
          '${l10n.diveLog_tooltip_ppN2} · Overlay',
          '${l10n.diveLog_tooltip_ppHe} · Overlay',
          '${l10n.diveLog_tooltip_mod} · Overlay',
          '${l10n.diveLog_tooltip_density} · Overlay',
          '${l10n.diveLog_tooltip_gfPercent} · Overlay',
          '${l10n.diveLog_tooltip_srfGf} · Overlay',
          '${l10n.diveLog_tooltip_mean} · Overlay',
          '${l10n.diveLog_tooltip_tts} · Overlay',
          '${l10n.diveLog_tooltip_gtr} · Overlay',
          '${l10n.diveLog_tooltip_cns} · Overlay',
          '${l10n.diveLog_tooltip_otu} · Overlay',
        ]) {
          expect(byLabel.containsKey(label), isTrue, reason: 'missing $label');
          expect(byLabel[label], isNotNull);
        }

        // The single touch above lands on a mid-profile sample (NDL
        // counting down normally, TTS still 0). Touch the first and last
        // samples too, to cover the NDL "over max"/"in deco" branches and
        // the TTS "> 0" branch, all specific to this external-tooltip path
        // (the in-chart tooltip below is a structurally identical but
        // separate code path with its own coverage).
        void touch(int spotIndex) {
          data.lineTouchData.touchCallback!(
            FlPanDownEvent(DragDownDetails()),
            LineTouchResponse(
              touchLocation: Offset.zero,
              touchChartCoordinate: Offset.zero,
              lineBarSpots: <TouchLineBarSpot>[
                TouchLineBarSpot(depthBar, 0, depthBar.spots[spotIndex], 0),
              ],
            ),
          );
        }

        touch(1); // ndlCurve[0] = 4000: NDL "over max" branch.
        expect(rows, isNotNull);
        expect(
          rows!.any((r) => r.label == '${l10n.diveLog_tooltip_ndl} · Overlay'),
          isTrue,
        );

        touch(15); // ndlCurve[14] < 0 (deco) and ttsCurve[14] > 0.
        expect(rows, isNotNull);
        final lateRows = {for (final r in rows!) r.label: r.value};
        expect(
          lateRows['${l10n.diveLog_tooltip_ndl} · Overlay'],
          l10n.diveLog_playbackStats_deco,
        );
        expect(lateRows['${l10n.diveLog_tooltip_tts} · Overlay'], isNotNull);
      },
    );
  });

  group('DiveProfileChart overlay metrics - in-chart tooltip', () {
    testWidgets(
      'sweeping the chart with every metric toggled on builds the in-chart '
      'tooltip for every overlay branch without throwing',
      (tester) async {
        await tester.pumpWidget(_harness(tooltipBelow: false));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveProfileChart)),
        );
        _enableAllOverlayMetrics(
          container.read(profileLegendProvider.notifier),
        );
        await tester.pumpAndSettle();

        final chartFinder = find.byType(LineChart);
        final chartBox = tester.renderObject(chartFinder) as RenderBox;
        final chartSize = chartBox.size;

        for (var xFrac = 0.1; xFrac <= 0.9; xFrac += 0.1) {
          final testPoint = chartBox.localToGlobal(
            Offset(chartSize.width * xFrac, chartSize.height * 0.5),
          );
          final gesture = await tester.startGesture(testPoint);
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(const Offset(2, 0));
          await tester.pump();
          await gesture.up();
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        expect(find.byType(LineChart), findsOneWidget);
      },
    );
  });

  group('DiveProfileChart overlay metrics - inline legend', () {
    testWidgets('lists the overlay\'s traces per computer beside the active '
        'source\'s', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Depth is only listed on multi-source dives; the harness passes no
      // computer names, so the active source's entry stays unsuffixed.
      expect(find.text('Depth'), findsOneWidget);
      expect(find.text('Depth · Overlay'), findsOneWidget);
      // Ceiling defaults to visible and the overlay analysis has a ceiling.
      expect(find.text('Ceiling · Overlay'), findsOneWidget);
      // TTS is off by default, so neither source lists it yet.
      expect(find.text('TTS · Overlay'), findsNothing);

      final container = tester.element(find.byType(LineChart));
      final notifier = ProviderScope.containerOf(
        container,
      ).read(profileLegendProvider.notifier);
      notifier.toggleTts();
      await tester.pumpAndSettle();

      expect(find.text('TTS · Overlay'), findsOneWidget);
    });
  });
}
