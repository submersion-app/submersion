import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The embedded chart draws the dive's cell divergence runs as secondary
/// ranges; the fullscreen page is pinned to the same wiring (#2278).
void main() {
  testWidgets('cell divergence runs reach the chart as secondary ranges', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime();
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => null),
          diveSensorSummaryProvider(dive.id).overrideWith(
            (ref) async => DiveSensorSummary(
              diveId: dive.id,
              engineVersion: 1,
              sourceUpdatedAt: 1,
              computedAt: DateTime.utc(2026),
              cellMetrics: const [
                CellMetrics(
                  slot: 2,
                  samples: 10,
                  divergenceRanges: [
                    DivergenceRange(
                      startSeconds: 300,
                      endSeconds: 420,
                      peakBar: 0.2,
                    ),
                  ],
                ),
                CellMetrics(
                  slot: 1,
                  samples: 10,
                  divergenceRanges: [
                    DivergenceRange(
                      startSeconds: 60,
                      endSeconds: 120,
                      peakBar: 0.3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: DiveProfileChartHost(dive: dive),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    final errorColor = Theme.of(
      tester.element(find.byType(DiveProfileChart)),
    ).colorScheme.error;
    expect(
      chart.secondaryRanges.map((r) => (r.startTimestamp, r.endTimestamp)),
      [(60, 120), (300, 420)],
    );
    expect(chart.secondaryRanges.map((r) => r.color).toSet(), {errorColor});
  });
}
