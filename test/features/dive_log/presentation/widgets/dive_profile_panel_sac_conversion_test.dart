import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_app.dart';

/// Issue #3109: the dive-list profile panel converts its SAC tooltip like
/// the detail and fullscreen charts, normalised to Dive.sac and turned into
/// L/min with the reference cylinder's volume (its partner's when unsized).
void main() {
  const diveId = 'panel-dive-1';

  // A sidemount pair where only the right cylinder carries a size, so the
  // left one, the reference, must borrow it.
  Dive sidemountDive() => createTestDiveWithBottomTime(id: diveId).copyWith(
    profile: List.generate(
      6,
      (i) => DiveProfilePoint(
        timestamp: i * 60,
        depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
      ),
    ),
    tanks: const [
      DiveTank(
        id: 'left',
        role: TankRole.sidemountLeft,
        startPressure: 200,
        endPressure: 100,
      ),
      DiveTank(
        id: 'right',
        role: TankRole.sidemountRight,
        volume: 11.1,
        startPressure: 200,
        endPressure: 100,
      ),
    ],
  );

  // One SAC segment far below Dive.sac, so the factor is well above 1.
  ProfileAnalysis analysis() => ProfileAnalysis.empty().copyWith(
    sacSegments: const [
      SacSegment(
        startTimestamp: 0,
        endTimestamp: 300,
        avgDepth: 10,
        minDepth: 0,
        maxDepth: 16,
        sacRate: 0.1,
        gasConsumed: 1,
      ),
    ],
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    required Override diveOverride,
    required Override analysisOverride,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          highlightedDiveIdProvider.overrideWith((ref) => diveId),
          // The panel previews the highlight only while the table lists it.
          allDivesForTableProvider.overrideWith(
            (ref) =>
                AsyncValue.data([createTestDiveWithBottomTime(id: diveId)]),
          ),
          diveOverride,
          analysisOverride,
          // The panel's analysis comes from sourceProfileAnalysisProvider,
          // which awaits the dive's data sources and delegates to the
          // overridden profileAnalysisProvider when there are fewer than two.
          // Without these two overrides the analysis never resolves, and the
          // chart would get no normalisation factor to assert on.
          diveDataSourcesProvider(
            diveId,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          sourceProfilesProvider(
            diveId,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          gasSwitchesProvider(
            diveId,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          // No recorded series; estimatedTankPressuresProvider (not
          // overridden) synthesizes one from the cylinders' pressures.
          tankPressuresProvider(
            diveId,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        ],
        child: const SizedBox(
          height: 350,
          width: 600,
          child: DiveProfilePanel(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('passes the reference volume and SAC normalisation', (
    tester,
  ) async {
    final dive = sidemountDive();
    final profileAnalysis = analysis();
    await pumpPanel(
      tester,
      diveOverride: diveProvider(diveId).overrideWith((ref) async => dive),
      analysisOverride: profileAnalysisProvider(
        diveId,
      ).overrideWith((ref) async => profileAnalysis),
    );
    await pumpUntil(
      tester,
      () => find.byType(DiveProfileChart).evaluate().isNotEmpty,
    );

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.tankVolume, 11.1);
    final factor = calculateSacNormalizationFactor(dive, profileAnalysis);
    expect(factor, greaterThan(1));
    expect(chart.sacNormalizationFactor, closeTo(factor, 1e-9));
  });
}
