import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_depth_season_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'species_picture_test_support.dart';

const _months = [3, 0, 1, 0, 0, 0, 7, 2, 0, 0, 0, 1];

void main() {
  testWidgets('dots from photo depths in feet for an imperial diver', (
    tester,
  ) async {
    await pumpPictures(
      tester,
      const SpeciesDepthSeasonSection(
        photoDepths: [6, 12],
        minDiveDepth: 10,
        maxDiveDepth: 30,
        monthCounts: _months,
      ),
      extra: [
        unitFormatterProvider.overrideWithValue(
          const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
        ),
      ],
    );
    expect(find.text('Photo depths'), findsOneWidget);
    expect(find.text('20ft'), findsOneWidget);
    expect(find.text('39ft'), findsOneWidget);
  });

  testWidgets('falls back to the dive max depth band with its label', (
    tester,
  ) async {
    await pumpPictures(
      tester,
      const SpeciesDepthSeasonSection(
        photoDepths: [],
        minDiveDepth: 18,
        maxDiveDepth: 29.7,
        monthCounts: _months,
      ),
    );
    expect(find.text('Dive max depth'), findsOneWidget);
    expect(find.text('18m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
  });

  testWidgets('twelve bars with the counts', (tester) async {
    await pumpPictures(
      tester,
      const SpeciesDepthSeasonSection(photoDepths: [], monthCounts: _months),
    );
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(12));
    expect(chart.data.barGroups.map((g) => g.barRods.single.toY), [
      for (final m in _months) m.toDouble(),
    ]);
  });

  testWidgets('hidden when no month has a dive', (tester) async {
    await pumpPictures(
      tester,
      const SpeciesDepthSeasonSection(
        photoDepths: [],
        monthCounts: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      ),
    );
    expect(find.byType(BarChart), findsNothing);
  });
}
