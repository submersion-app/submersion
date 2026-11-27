import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/species_profile_positions.dart';
import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The selected species drawn on the profile chart (issue #5092).
void main() {
  // 10 points, 30 s apart: x axis spans 0..270 s.
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  const teal = Color(0xFF009688);

  SpeciesProfileHighlight highlight({
    List<SpeciesMoment> moments = const [],
    List<SpeciesSpan> spans = const [],
  }) => SpeciesProfileHighlight(
    positions: SpeciesProfilePositions(moments: moments, spans: spans),
    color: teal,
  );

  Future<void> pumpChart(
    WidgetTester tester, {
    SpeciesProfileHighlight? species,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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
                speciesHighlight: species,
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

  Iterable<LineChartBarData> dotBarsAt(LineChartData data, double x) => data
      .lineBarsData
      .where((b) => b.dotData.show && b.spots.any((s) => s.x == x));

  testWidgets('no species highlight adds no band or line', (tester) async {
    await pumpChart(tester);
    final data = chartData(tester);
    expect(data.rangeAnnotations.verticalRangeAnnotations, isEmpty);
    expect(data.extraLinesData.verticalLines, isEmpty);
  });

  testWidgets('a span draws one band in the species colour', (tester) async {
    await pumpChart(
      tester,
      species: highlight(
        spans: [(start: 60, end: 120, minDepth: 6, maxDepth: 12)],
      ),
    );
    final band = chartData(tester).rangeAnnotations.verticalRangeAnnotations;
    expect(band, hasLength(1));
    expect((band.single.x1, band.single.x2), (60.0, 120.0));
    expect(band.single.color!.toARGB32() & 0x00FFFFFF, 0x009688);
  });

  testWidgets('a moment draws a line and a dot on the depth line', (
    tester,
  ) async {
    await pumpChart(
      tester,
      species: highlight(moments: [(seconds: 90, depthMeters: 9)]),
    );
    final data = chartData(tester);
    expect(
      data.extraLinesData.verticalLines.where((l) => l.x == 90),
      hasLength(1),
    );
    final dots = dotBarsAt(data, 90);
    expect(dots, hasLength(1));
    expect(dots.single.spots.single.y, -9);
  });

  testWidgets('a highlight outside the zoomed window draws nothing', (
    tester,
  ) async {
    await pumpChart(
      tester,
      species: highlight(
        moments: [(seconds: 5000, depthMeters: 9)],
        spans: [(start: 4000, end: 4100, minDepth: 6, maxDepth: 12)],
      ),
    );
    final data = chartData(tester);
    expect(data.rangeAnnotations.verticalRangeAnnotations, isEmpty);
    expect(data.extraLinesData.verticalLines, isEmpty);
    // Its dot stays a bar like the max-depth marker's, and the plot clips
    // it, as it does every point outside the window.
    expect(data.clipData, const FlClipData.all());
  });

  testWidgets('clearing the highlight removes its band and dot', (
    tester,
  ) async {
    await pumpChart(
      tester,
      species: highlight(
        moments: [(seconds: 90, depthMeters: 9)],
        spans: [(start: 60, end: 120, minDepth: 6, maxDepth: 12)],
      ),
    );
    await pumpChart(tester);
    final data = chartData(tester);
    expect(data.rangeAnnotations.verticalRangeAnnotations, isEmpty);
    expect(dotBarsAt(data, 90), isEmpty);
  });
}
