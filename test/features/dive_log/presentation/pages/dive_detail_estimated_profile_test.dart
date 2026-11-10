import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_estimated_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/estimated_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A dive with no recorded profile shows a Dive Profile card with an
/// estimated outline in place of hiding the section (issue #4112).
void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    Dive dive, {
    bool hasStoredSeries = false,
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
          ).overrideWith((ref) async => ProfileAnalysis.empty()),
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
          diveHasProfileSeriesProvider(
            dive.id,
          ).overrideWith((ref) async => hasStoredSeries),
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

  testWidgets('a dive without samples shows an estimated outline', (
    tester,
  ) async {
    await pumpDetail(tester, createTestDiveWithBottomTime());

    final chart = tester.widget<EstimatedProfileChart>(
      find.descendant(
        of: find.byType(DiveDetailEstimatedProfileSection),
        matching: find.byType(EstimatedProfileChart),
      ),
    );
    expect(
      chart.profile,
      EstimatedProfile.estimate(
        maxDepth: 25,
        runtime: const Duration(minutes: 50),
        bottomTime: const Duration(minutes: 45),
      ),
    );
    expect(find.text('Dive Profile'), findsOneWidget);
    expect(
      find.text('Estimated from max depth and time, not a recorded profile'),
      findsOneWidget,
    );
    expect(find.byType(DiveDetailProfileSection), findsNothing);
  });

  testWidgets('a dive with samples shows its recorded profile only', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      createTestDiveWithBottomTime().copyWith(
        profile: List.generate(
          6,
          (i) => DiveProfilePoint(
            timestamp: i * 60,
            depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
          ),
        ),
      ),
    );

    expect(find.byType(DiveDetailProfileSection), findsOneWidget);
    expect(find.byType(DiveDetailEstimatedProfileSection), findsNothing);
  });

  testWidgets('a dive whose stored series is unreadable shows no estimate', (
    tester,
  ) async {
    // getDiveById reads an unreadable series as an empty profile.
    await pumpDetail(
      tester,
      createTestDiveWithBottomTime(),
      hasStoredSeries: true,
    );

    expect(find.byType(DiveDetailEstimatedProfileSection), findsNothing);
    expect(find.byType(DiveDetailProfileSection), findsNothing);
  });

  testWidgets('a dive without samples or a depth shows no profile card', (
    tester,
  ) async {
    await pumpDetail(tester, createTestDiveWithBottomTime(maxDepth: null));

    expect(find.byType(DiveDetailEstimatedProfileSection), findsNothing);
    expect(find.byType(DiveDetailProfileSection), findsNothing);
  });
}
