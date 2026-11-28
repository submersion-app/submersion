import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #5098: the trim line on the profile chart, read straight from the
/// angle the computer logged.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A dive whose computer logged trim on every sample but two, which leave a
/// gap in the middle.
List<DiveProfilePoint> _trimmed() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
    trim: i == 8 || i == 9 ? null : -13.0 + i,
  ),
);

List<DiveProfilePoint> _plain() => [
  for (final p in _trimmed())
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

Iterable<LineChartBarData> _trimBars(WidgetTester tester) =>
    _bars(tester).where((b) => b.color == ProfileMetricColors.trim);

const _on = AppSettings(defaultShowTrim: true);

void main() {
  testWidgets('draws the trim line when on, breaking where none was logged', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(settings: _on, profile: _trimmed()));
    await tester.pumpAndSettle();

    final line = _trimBars(tester).single;
    expect(line.spots.where((s) => s == FlSpot.nullSpot), hasLength(1));
    expect(line.spots.first.x, 0);
  });

  testWidgets('the legend names the line', (tester) async {
    await tester.pumpWidget(_harness(settings: _on, profile: _trimmed()));
    await tester.pumpAndSettle();

    expect(find.text('Trim'), findsWidgets);
  });

  testWidgets('draws none while it is off', (tester) async {
    await tester.pumpWidget(
      _harness(settings: const AppSettings(), profile: _trimmed()),
    );
    await tester.pumpAndSettle();

    expect(_trimBars(tester), isEmpty);
  });

  testWidgets('a dive without trim draws none even when on', (tester) async {
    await tester.pumpWidget(_harness(settings: _on, profile: _plain()));
    await tester.pumpAndSettle();

    expect(_trimBars(tester), isEmpty);
  });

  testWidgets('the readout gives the logged angle in signed degrees', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(
        settings: _on,
        profile: _trimmed(),
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

    final trim = got.singleWhere((r) => r.label == 'Trim');
    // A sample in the gap reads '-', any other a signed whole degree.
    expect(trim.value, anyOf('-', matches(RegExp(r'^([+-]\d+|0)°$'))));
    expect(trim.metric, ProfileRightAxisMetric.trim);
  });
}
