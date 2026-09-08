import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_app.dart';

/// The table-mode side panel hosts the same chart as the detail page and
/// reads the same providers, so it is exposed to the same reload window:
/// a detail change tick refreshes diveProvider, estimatedTankPressuresProvider
/// reloads behind it, and a read through the valueOrNull polyfill would drop
/// the estimated series for a frame. See
/// dive_detail_profile_section_reload_test.dart for the detail page side.
void main() {
  const diveId = 'panel-dive-1';

  Dive diveWithProfileAndTank() =>
      createTestDiveWithBottomTime(id: diveId).copyWith(
        profile: List.generate(
          6,
          (i) => DiveProfilePoint(
            timestamp: i * 60,
            depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
          ),
        ),
        tanks: const [
          DiveTank(
            id: 'tank-1',
            volume: 11.1,
            startPressure: 200,
            endPressure: 60,
          ),
        ],
      );

  ProfileAnalysis analysisWithCeiling() => ProfileAnalysis.empty().copyWith(
    ceilingCurve: List<double>.filled(6, 0.0),
  );

  Future<ProviderContainer> pumpPanel(
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
          diveOverride,
          analysisOverride,
          // The panel's analysis now comes from sourceProfileAnalysisProvider,
          // which awaits the dive's data sources and delegates to the
          // overridden profileAnalysisProvider when there are fewer than two.
          // Without these two overrides the analysis would never resolve, and
          // the overlay assertions below would be measuring an unresolved
          // dependency rather than the reload window they are about.
          diveDataSourcesProvider(
            diveId,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          sourceProfilesProvider(
            diveId,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          gasSwitchesProvider(
            diveId,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          // No real samples, so estimatedTankPressuresProvider (deliberately
          // NOT overridden) synthesizes a series for tank-1.
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
    return ProviderScope.containerOf(
      tester.element(find.byType(DiveProfilePanel)),
    );
  }

  DiveProfileChart chart(WidgetTester tester) =>
      tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

  testWidgets(
    'keeps the estimated pressure series while the dive provider refreshes',
    (tester) async {
      final dive = diveWithProfileAndTank();
      Completer<void>? diveGate;
      final container = await pumpPanel(
        tester,
        diveOverride: diveProvider(diveId).overrideWith((ref) async {
          final gate = diveGate;
          if (gate != null) await gate.future;
          return dive;
        }),
        analysisOverride: profileAnalysisProvider(
          diveId,
        ).overrideWith((ref) async => analysisWithCeiling()),
      );

      expect(chart(tester).estimatedTankIds, contains('tank-1'));

      diveGate = Completer<void>();
      container.invalidate(diveProvider(diveId));
      // Pump until the reload window is actually open rather than assuming
      // a frame count; the gate holds it open until this test closes it.
      await pumpUntil(
        tester,
        () =>
            container.read(estimatedTankPressuresProvider(diveId)).isReloading,
        reason: 'the estimate must be mid-reload',
      );
      expect(
        chart(tester).estimatedTankIds,
        contains('tank-1'),
        reason:
            'a reload of the estimate must not drop the series from the '
            'panel chart; the previous value is still available',
      );
      expect(chart(tester).tankPressures?['tank-1'], isNotEmpty);

      diveGate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chart(tester).estimatedTankIds, contains('tank-1'));
    },
  );

  testWidgets('keeps the analysis overlays while the analysis reloads', (
    tester,
  ) async {
    final dive = diveWithProfileAndTank();
    final analysis = analysisWithCeiling();
    final trigger = StateProvider<int>((ref) => 0);
    Completer<ProfileAnalysis?>? analysisGate;
    final container = await pumpPanel(
      tester,
      diveOverride: diveProvider(diveId).overrideWith((ref) async => dive),
      analysisOverride: profileAnalysisProvider(diveId).overrideWith((
        ref,
      ) async {
        if (ref.watch(trigger) == 0) return analysis;
        return analysisGate!.future;
      }),
    );

    expect(chart(tester).ceilingCurve, isNotNull);

    analysisGate = Completer<ProfileAnalysis?>();
    container.read(trigger.notifier).state = 1;
    // Pump until the reload window is actually open rather than assuming
    // a frame count; the gate holds it open until this test closes it.
    await pumpUntil(
      tester,
      () => container.read(profileAnalysisProvider(diveId)).isReloading,
      reason: 'the analysis must be mid-reload',
    );
    expect(
      chart(tester).ceilingCurve,
      isNotNull,
      reason:
          'a reload of the analysis must not strip the overlays from the '
          'panel chart; the previous analysis is still available',
    );

    analysisGate.complete(analysis);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(chart(tester).ceilingCurve, isNotNull);
  });
}
