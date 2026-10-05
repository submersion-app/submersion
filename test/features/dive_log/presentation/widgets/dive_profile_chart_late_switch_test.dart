import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 20 samples, 30 s apart (0..570 s).
List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

GasSwitchWindow _window({int start = 150, int end = 450}) => GasSwitchWindow(
  kind: GasSwitchWindowKind.late,
  fO2: 0.5,
  fHe: 0,
  idealTimestamp: start,
  idealDepth: 10,
  switchTimestamp: end,
  switchDepth: 4,
  endTimestamp: end,
  delaySeconds: end - start,
  depthDelayMeters: 6,
  extraDecoSeconds: 90,
);

Widget _harness(
  GasSwitchWindow window, {
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
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
            gasSwitchEfficiency: GasSwitchEfficiency(
              evaluated: true,
              windows: [window],
            ),
            tooltipPresentation: TooltipPresentation.external,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

List<VerticalRangeAnnotation> _bands(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .rangeAnnotations
    .verticalRangeAnnotations;

void main() {
  testWidgets('shades the window while the toggle is on', (tester) async {
    await tester.pumpWidget(_harness(_window()));
    await tester.pumpAndSettle();
    expect(_bands(tester), hasLength(1));
    expect(_bands(tester).single.x1, 150);
    expect(_bands(tester).single.x2, 450);

    ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChart)),
    ).read(profileLegendProvider.notifier).toggleLateGasSwitches();
    await tester.pumpAndSettle();
    expect(_bands(tester), isEmpty);
  });

  testWidgets('clamps a window running past the visible range', (tester) async {
    await tester.pumpWidget(_harness(_window(start: 300, end: 9999)));
    await tester.pumpAndSettle();
    expect(_bands(tester).single.x1, 300);
    expect(_bands(tester).single.x2, lessThanOrEqualTo(570));
  });

  testWidgets('the tooltip names the late switch under the cursor', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(_window(), onTooltipData: (r) => rows = r),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineChart)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();
    expect(rows, isNotNull);
    // Two rows, so neither is cut off by the tooltip's width cap.
    final labels = rows!.map((r) => r.label).toList();
    expect(labels, containsAll(['Late switch', 'Delay', 'Extra deco']));
    final extra = rows!.firstWhere((r) => r.label == 'Extra deco');
    expect(extra.value, '+1:30');
    await gesture.up();
  });
}
