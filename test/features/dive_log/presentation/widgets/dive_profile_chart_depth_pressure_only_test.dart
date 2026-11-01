import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The gas switch picker hosts the real chart with depth and pressure only
// (issue #4089): whatever the diver's legend says, nothing else draws, nothing
// offers to change that, and the row's cylinder is always the heavy line.

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _back = DiveTank(id: 'back', gasMix: GasMix(o2: 21), order: 0);
const _deco = DiveTank(id: 'deco', gasMix: GasMix(o2: 50), order: 1);

final _profile = List.generate(
  60,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 30 ? i * 1.0 : (60 - i) * 1.0,
    temperature: 12,
  ),
);

Map<String, List<TankPressurePoint>> _pressures() => {
  for (final (id, start) in [('back', 200.0), ('deco', 180.0)])
    id: [
      for (var i = 0; i < 60; i++)
        TankPressurePoint(
          tankId: id,
          timestamp: i * 30,
          pressure: start - i * 2,
        ),
    ],
};

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool depthAndPressureOnly = true,
  String? emphasizedTankId = 'deco',
  ValueChanged<int>? onTimeChosen,
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _SettingsNotifier(settings)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: DiveProfileChart(
              profile: _profile,
              showTemperature: false,
              showPressure: true,
              tanks: const [_back, _deco],
              tankPressures: _pressures(),
              depthAndPressureOnly: depthAndPressureOnly,
              emphasizedTankId: emphasizedTankId,
              onTimeChosen: onTimeChosen,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(DiveProfileChart)),
  );
}

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data.lineBarsData;

LineChartBarData _barIn(WidgetTester tester, Color color) =>
    _bars(tester).firstWhere((b) => b.color == color);

void main() {
  testWidgets('no legend, options or right-axis menu', (tester) async {
    await _pump(tester);

    expect(find.byType(DiveProfileLegend), findsNothing);
    expect(find.byTooltip('More chart options'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('right axis', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('a normal chart keeps its legend', (tester) async {
    await _pump(tester, depthAndPressureOnly: false);

    expect(find.byType(DiveProfileLegend), findsOneWidget);
  });

  testWidgets('pressures draw though the diver turned them off', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(defaultShowPressure: false),
    );

    expect(
      _bars(tester).where((b) => b.color == GasColors.forGasMix(_deco.gasMix)),
      isNotEmpty,
    );
    expect(
      _bars(tester).where((b) => b.color == GasColors.forGasMix(_back.gasMix)),
      isNotEmpty,
    );
  });

  testWidgets('a line the diver turned on elsewhere stays off', (tester) async {
    final container = await _pump(tester);
    final before = _bars(tester).length;

    container.read(profileLegendProvider.notifier).toggleTemperature();
    await tester.pumpAndSettle();

    expect(_bars(tester).length, before);
  });

  testWidgets('the row\'s cylinder is the heavy line', (tester) async {
    await _pump(tester);

    expect(_barIn(tester, GasColors.forGasMix(_deco.gasMix)).barWidth, 3);
    expect(_barIn(tester, GasColors.forGasMix(_back.gasMix)).barWidth, 1);
  });

  testWidgets('with nothing emphasized every pressure is thin', (tester) async {
    await _pump(tester, emphasizedTankId: null);

    expect(_barIn(tester, GasColors.forGasMix(_deco.gasMix)).barWidth, 1);
  });

  testWidgets('a tap chooses the time under it', (tester) async {
    final chosen = <int>[];
    await _pump(tester, onTimeChosen: chosen.add);

    final chart = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(chart.center);
    await tester.pumpAndSettle();

    expect(chosen, hasLength(1));
    expect(chosen.single, inInclusiveRange(600, 1200));
  });

  testWidgets('a drag across the chart chooses where it ended', (tester) async {
    final chosen = <int>[];
    await _pump(tester, onTimeChosen: chosen.add);

    final chart = tester.getRect(find.byType(LineChart).first);
    await tester.timedDragFrom(
      chart.center,
      Offset(chart.width / 4, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(chosen, isNotEmpty);
    expect(chosen.last, greaterThan(1100));
  });

  testWidgets('hovering shows the usual tooltip with depth and pressure only', (
    tester,
  ) async {
    await _pump(tester, onTimeChosen: (_) {});

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(LineChart).first));
    await tester.pumpAndSettle();

    final labels = tester
        .widget<ProfileCursorTooltip>(find.byType(ProfileCursorTooltip))
        .rows
        .map((r) => r.label)
        .toList();
    expect(labels.where((l) => l.contains('Tank')), hasLength(2));
    expect(labels, contains('Depth'));
    expect(labels.where((l) => l.contains('Temp')), isEmpty);
  });

  testWidgets('hovering chooses nothing', (tester) async {
    final chosen = <int>[];
    await _pump(tester, onTimeChosen: chosen.add);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(LineChart).first));
    await tester.pumpAndSettle();

    expect(chosen, isEmpty);
  });

  test('the slider inset helpers follow the axis sizes', () {
    expect(
      DiveProfileChart.plotLeftInset(400),
      greaterThan(DiveProfileChart.leftAxisSize(400)),
    );
    expect(
      DiveProfileChart.plotRightInset(400, hasRightAxis: true),
      greaterThan(DiveProfileChart.plotRightInset(400, hasRightAxis: false)),
    );
  });
}
