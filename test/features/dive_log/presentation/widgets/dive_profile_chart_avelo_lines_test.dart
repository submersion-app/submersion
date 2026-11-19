import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4664: the three Avelo lines on the profile chart, read straight
/// from the samples the computer logged.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _avelo() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
    aveloBuoyancy: -0.4 + i * 0.1,
    aveloGasRemaining: 100 - i * 3,
    computerRmv: i < 2 ? null : 12.0 + i % 5,
  ),
);

List<DiveProfilePoint> _plain() => [
  for (final p in _avelo())
    DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
];

Widget _harness({
  required AppSettings settings,
  required List<DiveProfilePoint> profile,
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 360,
        child: DiveProfileChart(
          profile: profile,
          tooltipPresentation: TooltipPresentation.external,
          onTooltipData: onTooltipData,
        ),
      ),
    ),
  ),
);

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

const _all = AppSettings(
  defaultShowAveloBuoyancy: true,
  defaultShowAveloGasRemaining: true,
  defaultShowComputerRmv: true,
);
const _colors = [
  ProfileMetricColors.aveloBuoyancy,
  ProfileMetricColors.aveloGasRemaining,
  ProfileMetricColors.computerRmv,
];

void main() {
  testWidgets('draws one line per Avelo value when on', (tester) async {
    await tester.pumpWidget(_harness(settings: _all, profile: _avelo()));
    await tester.pumpAndSettle();

    final bars = _bars(tester);
    for (final color in _colors) {
      expect(
        bars.where((b) => b.color == color),
        hasLength(1),
        reason: '$color',
      );
    }
    // RMV starts after two samples without a value.
    final rmv = bars.singleWhere(
      (b) => b.color == ProfileMetricColors.computerRmv,
    );
    expect(rmv.spots.first.x, 60);
  });

  testWidgets('the legend names each line that is on', (tester) async {
    await tester.pumpWidget(_harness(settings: _all, profile: _avelo()));
    await tester.pumpAndSettle();

    for (final label in ['Avelo buoyancy', 'Gas remaining', 'RMV (computer)']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('draws none while they are off', (tester) async {
    await tester.pumpWidget(
      _harness(settings: const AppSettings(), profile: _avelo()),
    );
    await tester.pumpAndSettle();

    expect(_bars(tester).where((b) => _colors.contains(b.color)), isEmpty);
  });

  testWidgets('a dive without Avelo data draws none even when on', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(settings: _all, profile: _plain()));
    await tester.pumpAndSettle();

    expect(_bars(tester).where((b) => _colors.contains(b.color)), isEmpty);
  });

  testWidgets('the readout names each Avelo value in the diver\'s units', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(
        settings: _all,
        profile: _avelo(),
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
    final got = rows!;
    await gesture.up();
    await tester.pumpAndSettle();

    final buoyancy = got.singleWhere((r) => r.label == 'Avelo buoyancy');
    expect(buoyancy.value, matches(RegExp(r'kg (buoyant|heavy|neutral)$')));
    expect(buoyancy.metric, ProfileRightAxisMetric.aveloBuoyancy);
    final gas = got.singleWhere((r) => r.label == 'Gas remaining');
    expect(gas.value, matches(RegExp(r'^\d+%$')));
    expect(gas.metric, ProfileRightAxisMetric.aveloGasRemaining);
    final rmv = got.singleWhere((r) => r.label == 'RMV (computer)');
    expect(rmv.value, endsWith(const UnitFormatter(AppSettings()).rmvSymbol));
    expect(rmv.metric, ProfileRightAxisMetric.computerRmv);
  });
}
