import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3012: the chart draws metrics in the diver's chosen colours.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _purple = Color(0xFFE040FB);
const _greenA400 = Color(0xFF00E676);

List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

List<TankPressurePoint> _series(String id) => [
  for (var i = 0; i < 20; i++)
    TankPressurePoint(tankId: id, timestamp: i * 30, pressure: 200.0 - i * 5),
];

ProfileMetricColorOverrides _with(ProfileMetric metric, Color color) =>
    ProfileMetricColorOverrides.none.withColor(metric, color);

Widget _harness({
  required AppSettings settings,
  _TestSettingsNotifier? notifier,
  List<double>? ppO2Curve,
  Map<String, List<TankPressurePoint>>? tankPressures,
  List<DiveTank>? tanks,
  List<ProfileMarker>? markers,
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => notifier ?? _TestSettingsNotifier(settings),
      ),
    ],
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
            ppO2Curve: ppO2Curve,
            tankPressures: tankPressures,
            tanks: tanks,
            markers: markers,
            showMaxDepthMarker: true,
            showPressureThresholdMarkers: true,
            tooltipPresentation: TooltipPresentation.external,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

List<Color?> _barColors(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .map((b) => b.color)
    .toList();

/// RGB of every marker dot the chart paints (marker bars themselves are
/// transparent; pressure markers paint at 0.9 alpha).
List<int> _dotRgb(WidgetTester tester) {
  final out = <int>[];
  final bars = tester
      .widget<LineChart>(find.byType(LineChart))
      .data
      .lineBarsData;
  for (final bar in bars) {
    if (!bar.dotData.show) continue;
    for (var i = 0; i < bar.spots.length; i++) {
      final painter = bar.dotData.getDotPainter(bar.spots[i], 0, bar, i);
      if (painter is FlDotCirclePainter) {
        out.add(painter.color.toARGB32() & 0xFFFFFF);
      }
    }
  }
  return out;
}

int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

Future<List<TooltipRow>?> _touchCentre(
  WidgetTester tester,
  List<TooltipRow>? Function() rows,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(LineChart)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(const Offset(2, 0));
  await tester.pump();
  final got = rows();
  await gesture.up();
  await tester.pumpAndSettle();
  return got;
}

void main() {
  testWidgets('a chosen ppO2 colour draws the line and its tooltip bullet', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          defaultShowPpO2: true,
          profileMetricColors: _with(ProfileMetric.ppO2, _purple),
        ),
        ppO2Curve: List<double>.filled(20, 1.2),
        onTooltipData: (r) => rows = r,
      ),
    );
    await tester.pumpAndSettle();

    expect(_barColors(tester), contains(_purple));
    expect(_barColors(tester), isNot(contains(ProfileMetricColors.ppO2)));
    final got = await _touchCentre(tester, () => rows);
    expect(got!.map((r) => r.bulletColor), contains(_purple));
  });

  testWidgets('a chosen depth colour draws the depth line', (tester) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          profileMetricColors: _with(ProfileMetric.depth, _purple),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), contains(_purple));
    expect(_barColors(tester), isNot(contains(ProfileMetricColors.depth)));
  });

  testWidgets('a colour picked while the chart is open redraws it', (
    tester,
  ) async {
    final notifier = _TestSettingsNotifier(
      const AppSettings(defaultShowPpO2: true),
    );
    await tester.pumpWidget(
      _harness(
        settings: notifier.state,
        notifier: notifier,
        ppO2Curve: List<double>.filled(20, 1.2),
      ),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), contains(ProfileMetricColors.ppO2));

    notifier.state = notifier.state.copyWith(
      profileMetricColors: _with(ProfileMetric.ppO2, _purple),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), contains(_purple));
    expect(_barColors(tester), isNot(contains(ProfileMetricColors.ppO2)));
  });

  testWidgets('a chosen max depth colour draws the max depth marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          profileMetricColors: _with(ProfileMetric.maxDepth, _purple),
        ),
        markers: const [
          ProfileMarker(
            timestamp: 270,
            depth: 18,
            type: ProfileMarkerType.maxDepth,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_dotRgb(tester), contains(_rgb(_purple)));
  });

  testWidgets('a chosen pressure colour draws a single tank and its '
      'threshold markers', (tester) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          showPressureThresholdMarkers: true,
          profileMetricColors: _with(ProfileMetric.pressure, _greenA400),
        ),
        tankPressures: {'t1': _series('t1')},
        markers: const [
          ProfileMarker(
            timestamp: 300,
            depth: 10,
            type: ProfileMarkerType.pressureHalf,
            tankId: 't1',
            tankIndex: 0,
            value: 100,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), contains(_greenA400));
    expect(_dotRgb(tester), contains(_rgb(_greenA400)));
  });

  testWidgets('a dive with several tanks keeps its gas colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          profileMetricColors: _with(ProfileMetric.pressure, _greenA400),
        ),
        tankPressures: {'t1': _series('t1'), 't2': _series('t2')},
      ),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), isNot(contains(_greenA400)));
  });

  testWidgets('a two-tank dive with one transmitter keeps its gas colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          profileMetricColors: _with(ProfileMetric.pressure, _greenA400),
        ),
        tankPressures: {'t1': _series('t1')},
        tanks: const [
          DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0),
          DiveTank(id: 't2', gasMix: GasMix(o2: 50), order: 1),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_barColors(tester), isNot(contains(_greenA400)));
  });

  testWidgets('on a multi-tank dive the pressure axis keeps its own colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          defaultRightAxisMetric: ProfileRightAxisMetric.pressure,
          profileMetricColors: _with(ProfileMetric.pressure, _greenA400),
        ),
        tankPressures: {'t1': _series('t1'), 't2': _series('t2')},
      ),
    );
    await tester.pumpAndSettle();
    final textColors = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .whereType<Color>();
    expect(textColors, isNot(contains(_greenA400)));
  });

  testWidgets('tooltip rows for tanks with no cylinder keep the fallback '
      'colours', (tester) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          profileMetricColors: _with(ProfileMetric.pressure, _greenA400),
        ),
        tankPressures: {'t1': _series('t1'), 't2': _series('t2')},
        onTooltipData: (r) => rows = r,
      ),
    );
    await tester.pumpAndSettle();
    final got = await _touchCentre(tester, () => rows);
    final bullets = got!.map((r) => r.bulletColor.toARGB32()).toSet();
    expect(bullets, contains(Colors.orange.toARGB32()));
    expect(bullets, isNot(contains(_greenA400.toARGB32())));
  });

  testWidgets('the right axis label takes the chosen colour', (tester) async {
    await tester.pumpWidget(
      _harness(
        settings: AppSettings(
          defaultShowPpO2: true,
          defaultRightAxisMetric: ProfileRightAxisMetric.ppO2,
          profileMetricColors: _with(ProfileMetric.ppO2, _purple),
        ),
        ppO2Curve: List<double>.filled(20, 1.2),
      ),
    );
    await tester.pumpAndSettle();
    final textColors = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .whereType<Color>();
    expect(textColors, contains(_purple));
  });

  test('ProfileMarker.getColor takes a max depth colour', () {
    const marker = ProfileMarker(
      timestamp: 0,
      depth: 10,
      type: ProfileMarkerType.maxDepth,
    );
    expect(marker.getColor(), ProfileMetricColors.maxDepth);
    expect(marker.getColor(maxDepthColor: _purple), _purple);
  });
}
