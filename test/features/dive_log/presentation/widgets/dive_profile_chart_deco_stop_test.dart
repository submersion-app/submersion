import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier()
    : super(const AppSettings(defaultShowGasTimeline: true));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A four-point profile that descends into a decompression obligation and
/// climbs back out, matching the shape of the deco/ceiling curves the tests
/// supply alongside it.
List<DiveProfilePoint> _sampleProfileWithDeco() {
  return const [
    DiveProfilePoint(timestamp: 0, depth: 10.0),
    DiveProfilePoint(timestamp: 30, depth: 40.0),
    DiveProfilePoint(timestamp: 60, depth: 40.0),
    DiveProfilePoint(timestamp: 90, depth: 5.0),
  ];
}

/// A 20-point profile for the tooltip tests: the long-press hit-test needs
/// enough spots for a touch near the centre to resolve to one.
List<DiveProfilePoint> _denseProfileWithDeco() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 4.0 : (19 - i) * 4.0,
  ),
);

/// Ceiling and stop curves matching [_denseProfileWithDeco] point for point.
List<double> _denseCeiling() =>
    List.generate(20, (i) => i >= 5 && i <= 14 ? 4.2 : 0.0);
List<double> _denseStops() =>
    List.generate(20, (i) => i >= 5 && i <= 14 ? 6.0 : 0.0);

Widget _buildChartHarness({
  required List<DiveProfilePoint> profile,
  List<double>? ceilingCurve,
  List<double>? decoStopCurve,
  bool showDecoStops = true,
  bool tooltipBelow = false,
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: profile,
            ceilingCurve: ceilingCurve,
            decoStopCurve: decoStopCurve,
            showDecoStops: showDecoStops,
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveProfileChart - deco stop band', () {
    testWidgets('renders the deco stop band beneath the ceiling line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChartHarness(
          profile: _sampleProfileWithDeco(),
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
          decoStopCurve: const [0.0, 6.0, 6.0, 0.0],
          showDecoStops: true,
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bars = chart.data.lineBarsData;
      final bandIndex = bars.indexWhere((b) => b.isStepLineChart);
      final ceilingIndex = bars.indexWhere((b) => b.dashArray != null);

      expect(bandIndex, isNonNegative, reason: 'deco stop band should render');
      expect(
        bandIndex,
        lessThan(ceilingIndex),
        reason: 'band draws first so the dashed ceiling stays legible on top',
      );
    });

    testWidgets('omits the band when showDecoStops is false', (tester) async {
      // The widget's showDecoStops constructor param only seeds initState;
      // once mounted, visibility is driven by profileLegendProvider (see the
      // legend-sync block in dive_profile_chart.dart), so toggling it off
      // there is what actually exercises this path.
      await tester.pumpWidget(
        _buildChartHarness(
          profile: _sampleProfileWithDeco(),
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
          decoStopCurve: const [0.0, 6.0, 6.0, 0.0],
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart)),
      );
      container.read(profileLegendProvider.notifier).toggleDecoStops();
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.any((b) => b.isStepLineChart), isFalse);
    });

    testWidgets('omits the band when no curve is supplied', (tester) async {
      await tester.pumpWidget(
        _buildChartHarness(
          profile: _sampleProfileWithDeco(),
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
          decoStopCurve: null,
          showDecoStops: true,
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.any((b) => b.isStepLineChart), isFalse);
    });
  });

  group('DiveProfileChart - deco stop external tooltip', () {
    testWidgets('emits a Deco stop row alongside Ceiling', (tester) async {
      // tooltipBelow routes the readout to the panel and fullscreen page,
      // which render these rows instead of the in-chart tooltip.
      List<TooltipRow>? rows;
      await tester.pumpWidget(
        _buildChartHarness(
          profile: _denseProfileWithDeco(),
          ceilingCurve: _denseCeiling(),
          decoStopCurve: _denseStops(),
          tooltipBelow: true,
          onTooltipData: (r) => rows = r,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LineChart)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();

      expect(rows, isNotNull);
      expect(
        rows!.where((r) => r.label == 'Ceiling'),
        isNotEmpty,
        reason: 'sanity: the ceiling row is the sibling this mirrors',
      );
      expect(
        rows!.where((r) => r.label == 'Deco stop'),
        isNotEmpty,
        reason:
            'the panel and fullscreen readouts draw the band, so they must '
            'report its value too',
      );
      await gesture.up();
    });

    testWidgets('omits the Deco stop row when no curve is supplied', (
      tester,
    ) async {
      List<TooltipRow>? rows;
      await tester.pumpWidget(
        _buildChartHarness(
          profile: _denseProfileWithDeco(),
          ceilingCurve: _denseCeiling(),
          decoStopCurve: null,
          tooltipBelow: true,
          onTooltipData: (r) => rows = r,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LineChart)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();

      expect(rows, isNotNull);
      expect(rows!.where((r) => r.label == 'Deco stop'), isEmpty);
      await gesture.up();
    });
  });
}
