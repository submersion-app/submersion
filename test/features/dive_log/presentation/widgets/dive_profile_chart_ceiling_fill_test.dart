import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildChartHarness({
  required List<DiveProfilePoint> profile,
  required List<double> ceilingCurve,
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
          child: DiveProfileChart(profile: profile, ceilingCurve: ceilingCurve),
        ),
      ),
    ),
  );
}

/// The dashed red ceiling curve. The deco stop band shares its colour but is
/// drawn with a transparent stroke, so the stroke colour identifies the line.
LineChartBarData _ceilingBar(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.lineBarsData.firstWhere(
    (b) => b.color == const Color(0xFFD32F2F) && b.dashArray != null,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveProfileChart - ceiling fill', () {
    testWidgets('shades the region between the ceiling and the surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChartHarness(
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 10.0),
            DiveProfilePoint(timestamp: 30, depth: 40.0),
            DiveProfilePoint(timestamp: 60, depth: 40.0),
            DiveProfilePoint(timestamp: 90, depth: 5.0),
          ],
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
        ),
      );
      await tester.pumpAndSettle();

      final bar = _ceilingBar(tester);

      // Depths are negated for the inverted axis, so the surface (y = 0) sits
      // above the ceiling (y = -4.2) and the shaded region is an above-bar
      // area. belowBarData cannot express this: fl_chart's painter draws the
      // below-bar fill and then erases the whole above-line region to clean up
      // the cut-off overdraw, wiping exactly the area the fill needs.
      expect(bar.aboveBarData.show, isTrue);
      expect(bar.aboveBarData.applyCutOffY, isTrue);
      expect(bar.aboveBarData.cutOffY, 0);
      expect(bar.belowBarData.show, isFalse);
    });

    testWidgets('breaks the shaded region where the ceiling clears', (
      tester,
    ) async {
      // A sawtooth profile that incurs an obligation, clears it, then incurs a
      // second one. Samples with no ceiling are skipped rather than plotted at
      // the surface, so without an explicit break the curve joins the two runs
      // and the fill shades the gap as though the diver were still in deco.
      await tester.pumpWidget(
        _buildChartHarness(
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 5.0),
            DiveProfilePoint(timestamp: 30, depth: 40.0),
            DiveProfilePoint(timestamp: 60, depth: 40.0),
            DiveProfilePoint(timestamp: 90, depth: 5.0),
            DiveProfilePoint(timestamp: 120, depth: 40.0),
            DiveProfilePoint(timestamp: 150, depth: 40.0),
            DiveProfilePoint(timestamp: 180, depth: 5.0),
          ],
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0, 6.0, 6.0, 0.0],
        ),
      );
      await tester.pumpAndSettle();

      final bar = _ceilingBar(tester);

      // fl_chart splits a bar on null spots and gives each section its own
      // fill, so one break between the two runs is what keeps the shading off
      // the ceiling-free stretch.
      expect(bar.spots.where((s) => s.isNull()).length, 1);
      expect(
        bar.spots.indexWhere((s) => s.isNull()),
        greaterThan(0),
        reason: 'a leading break would start the curve with an empty section',
      );
      expect(
        bar.spots.last.isNull(),
        isFalse,
        reason: 'a trailing break would end the curve with an empty section',
      );
    });

    testWidgets('leaves a single uninterrupted obligation unbroken', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChartHarness(
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 5.0),
            DiveProfilePoint(timestamp: 30, depth: 40.0),
            DiveProfilePoint(timestamp: 60, depth: 40.0),
            DiveProfilePoint(timestamp: 90, depth: 5.0),
          ],
          ceilingCurve: const [0.0, 4.2, 4.2, 0.0],
        ),
      );
      await tester.pumpAndSettle();

      final bar = _ceilingBar(tester);

      expect(bar.spots.any((s) => s.isNull()), isFalse);
      expect(bar.spots, hasLength(2));
    });
  });
}
