import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_no_pressure_note.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A cylinder logged with only a start and an end pressure gives the
/// Cylinders card a whole-dive SAC, but nothing to break into segments. The
/// Gas consumption by segment card used to vanish for such a dive while its
/// section toggle stayed on (issue #2505); it now says why.
void main() {
  const startEndOnly = DiveTank(
    id: 'tank',
    volume: 11.1,
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(o2: 32.0),
  );
  const noPressures = DiveTank(id: 'tank', volume: 11.1, gasMix: GasMix());

  Dive diveWithProfile({required List<DiveTank> tanks}) {
    return createTestDiveWithBottomTime().copyWith(
      profile: List.generate(
        6,
        (i) => DiveProfilePoint(
          timestamp: i * 60,
          depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
        ),
      ),
      tanks: tanks,
    );
  }

  Future<void> pumpWith(
    WidgetTester tester, {
    required Dive dive,
    required ProfileAnalysis analysis,
  }) async {
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          profileAnalysisProvider(
            dive.id,
          ).overrideWith((ref) async => analysis),
          selectedSegmentationProvider.overrideWith(
            (ref) => SacSegmentationType.timeInterval,
          ),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfilesProvider(
            dive.id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder sacCard(WidgetTester tester) {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DiveDetailPage)),
    );
    return find.widgetWithText(
      CollapsibleCardSection,
      l10n.diveLog_detail_section_sacRateBySegment,
    );
  }

  testWidgets('explains a dive logged with only start and end pressures', (
    tester,
  ) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [startEndOnly]),
      analysis: ProfileAnalysis.empty(),
    );

    final card = sacCard(tester);
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.byType(SacSegmentsNoPressureNote),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stays hidden when no cylinder has a pressure to report', (
    tester,
  ) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [noPressures]),
      analysis: ProfileAnalysis.empty(),
    );

    expect(sacCard(tester), findsNothing);
    expect(find.byType(SacSegmentsNoPressureNote), findsNothing);
  });

  testWidgets('shows segments, not the note, when pressure was recorded', (
    tester,
  ) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [startEndOnly]),
      analysis: ProfileAnalysis.empty().copyWith(
        sacCurve: const [0.0, 0.8],
        sacSegments: const [
          SacSegment(
            startTimestamp: 0,
            endTimestamp: 300,
            avgDepth: 18.0,
            minDepth: 0.0,
            maxDepth: 24.0,
            sacRate: 0.8,
            gasConsumed: 4.0,
            segmentationType: SacSegmentationType.timeInterval,
          ),
        ],
      ),
    );

    expect(sacCard(tester), findsOneWidget);
    expect(find.byType(SacSegmentsNoPressureNote), findsNothing);
  });
}
