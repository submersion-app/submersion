import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
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
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The SAC-by-segment card converts its bar/min segments to L/min with a
/// cylinder volume. Without one it silently showed bar/min under an L/min
/// preference (issue #386); now it says so. The volume comes from the
/// segment's own cylinder when it is attributed, otherwise from the same
/// reference (back gas) cylinder the pressure lane reads; never from an
/// unrelated bottle that happens to have a size.
void main() {
  const backGasNoVolume = DiveTank(
    id: 'back-gas',
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(),
    role: TankRole.backGas,
  );
  const backGasWithVolume = DiveTank(
    id: 'back-gas',
    volume: 12.0,
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(),
    role: TankRole.backGas,
  );
  const stageWithVolume = DiveTank(
    id: 'stage',
    volume: 11.1,
    gasMix: GasMix(o2: 50.0),
    role: TankRole.stage,
    order: 1,
  );
  const decoNoVolume = DiveTank(
    id: 'deco',
    startPressure: 200.0,
    endPressure: 150.0,
    gasMix: GasMix(o2: 50.0),
    role: TankRole.deco,
    order: 1,
  );

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

  ProfileAnalysis analysisWithSacSegments({String? tankId}) {
    return ProfileAnalysis.empty().copyWith(
      sacSegments: [
        SacSegment(
          startTimestamp: 0,
          endTimestamp: 300,
          avgDepth: 18.0,
          minDepth: 0.0,
          maxDepth: 24.0,
          sacRate: 0.8,
          gasConsumed: 4.0,
          segmentationType: SacSegmentationType.timeInterval,
          tankId: tankId,
        ),
      ],
    );
  }

  Future<void> pumpWith(
    WidgetTester tester, {
    required Dive dive,
    required AppSettings settings,
    String? segmentTankId,
  }) async {
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
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
          profileAnalysisProvider(dive.id).overrideWith(
            (ref) async => analysisWithSacSegments(tankId: segmentTankId),
          ),
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
    final card = find.widgetWithText(
      CollapsibleCardSection,
      l10n.diveLog_detail_section_sacRateBySegment,
    );
    expect(card, findsOneWidget);
    return card;
  }

  Finder hintIn(Finder card) =>
      find.descendant(of: card, matching: find.byType(SacVolumeHint));

  /// A segment VALUE in [unit] (e.g. "0.8 bar/min"); the hint's own text
  /// also mentions L/min, so this must not match prose.
  Finder unitIn(Finder card, String unit) => find.descendant(
    of: card,
    matching: find.textContaining(RegExp('^\\d+(\\.\\d+)? $unit/min\$')),
  );

  testWidgets('explains the bar/min fallback when L/min is selected', (
    tester,
  ) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [backGasNoVolume]),
      settings: const AppSettings(sacUnit: SacUnit.litersPerMin),
    );

    final card = sacCard(tester);
    expect(hintIn(card), findsOneWidget);
    expect(unitIn(card, 'bar'), findsWidgets);
    expect(unitIn(card, 'L'), findsNothing);
  });

  testWidgets('shows no hint once the cylinder has a volume', (tester) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [backGasWithVolume]),
      settings: const AppSettings(sacUnit: SacUnit.litersPerMin),
    );

    final card = sacCard(tester);
    expect(hintIn(card), findsNothing);
    expect(unitIn(card, 'L'), findsWidgets);
  });

  testWidgets('shows no hint under a pressure-per-minute preference', (
    tester,
  ) async {
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [backGasNoVolume]),
      settings: const AppSettings(sacUnit: SacUnit.pressurePerMin),
    );

    expect(hintIn(sacCard(tester)), findsNothing);
  });

  testWidgets('tapping the card\'s hint opens the dive editor', (tester) async {
    final dive = diveWithProfile(tanks: const [backGasNoVolume]);
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(sacUnit: SacUnit.litersPerMin),
      ),
    );
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) =>
              DiveDetailPage(diveId: dive.id, embedded: true),
        ),
        GoRoute(
          path: '/dives/:id/edit',
          builder: (context, state) =>
              Scaffold(body: Text('EDIT_STUB ${state.pathParameters['id']}')),
        ),
      ],
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
          ).overrideWith((ref) async => analysisWithSacSegments()),
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
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The Details row has its own hint; scope to the card's.
    final hint = hintIn(sacCard(tester));
    expect(hint, findsOneWidget);
    await tester.ensureVisible(hint);
    await tester.pump();
    await tester.tap(hint);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('EDIT_STUB ${dive.id}'), findsOneWidget);
  });

  testWidgets('does not borrow a stage bottle\'s volume for the back gas', (
    tester,
  ) async {
    // Only the stage has a size; the segments describe the back gas. They
    // must stay in bar/min, with the hint, rather than be converted with a
    // cylinder that never fed them.
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [backGasNoVolume, stageWithVolume]),
      settings: const AppSettings(sacUnit: SacUnit.litersPerMin),
    );

    final card = sacCard(tester);
    expect(hintIn(card), findsOneWidget);
    expect(unitIn(card, 'bar'), findsWidgets);
    expect(unitIn(card, 'L'), findsNothing);
  });

  testWidgets('does not borrow the back gas volume for an attributed deco '
      'segment', (tester) async {
    // A gas-switch segment attributed to the deco bottle, which has no size,
    // while the back gas does: that segment stays in bar/min and the hint
    // points at the missing volume.
    await pumpWith(
      tester,
      dive: diveWithProfile(tanks: const [backGasWithVolume, decoNoVolume]),
      settings: const AppSettings(sacUnit: SacUnit.litersPerMin),
      segmentTankId: 'deco',
    );

    final card = sacCard(tester);
    expect(hintIn(card), findsOneWidget);
    expect(unitIn(card, 'bar'), findsWidgets);
    expect(unitIn(card, 'L'), findsNothing);
  });
}
