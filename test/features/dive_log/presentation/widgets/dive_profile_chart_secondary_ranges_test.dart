import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // 10 points, 30 s apart: x axis spans 0..270 s.
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
      o2Sensor1: 1.0,
      o2Sensor2: 1.0,
      o2SensorMv1: 50,
      o2SensorMv2: 50,
    ),
  );

  const secondary = [
    ProfileHighlightRange(
      startTimestamp: 30,
      endTimestamp: 90,
      color: Colors.red,
    ),
    ProfileHighlightRange(
      startTimestamp: 150,
      endTimestamp: 210,
      color: Colors.red,
    ),
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    required bool cellOverlayOn,
    ProfileHighlightRange? highlightRange,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              AppSettings(defaultShowO2CellMv: cellOverlayOn),
            ),
          ),
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
                o2SensorCurves: const [
                  [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
                  [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
                ],
                o2CellMvCurves: const [
                  [50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
                  [50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
                ],
                highlightRange: highlightRange,
                secondaryRanges: secondary,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  testWidgets('secondary ranges are hidden while the cell overlay is off', (
    tester,
  ) async {
    await pumpChart(tester, cellOverlayOn: false);
    expect(
      chartData(tester).rangeAnnotations.verticalRangeAnnotations,
      isEmpty,
    );
  });

  testWidgets('secondary ranges draw as bands when the cell overlay is on', (
    tester,
  ) async {
    await pumpChart(tester, cellOverlayOn: true);
    final annotations = chartData(
      tester,
    ).rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(2));
    expect(annotations.map((a) => a.x1), [30, 150]);
    expect(annotations.map((a) => a.x2), [90, 210]);
    // Bands only: no edge lines, unlike the primary highlight.
    expect(chartData(tester).extraLinesData.verticalLines, isEmpty);
  });

  testWidgets('the primary highlight is drawn after the secondary bands', (
    tester,
  ) async {
    await pumpChart(
      tester,
      cellOverlayOn: true,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 60,
        endTimestamp: 120,
        color: Colors.teal,
      ),
    );
    final annotations = chartData(
      tester,
    ).rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(3));
    expect(annotations.last.x1, 60);
    expect(annotations.last.x2, 120);
  });
}
