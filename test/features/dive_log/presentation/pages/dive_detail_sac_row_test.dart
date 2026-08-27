import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dive detail SAC row honors the gas model preference (issue #828) and,
/// when volumetric SAC is selected but no cylinder has a volume, falls back
/// to the pressure lane with a hint instead of vanishing (issue #386).
///
/// The volumetric lane is the only one that can differ by gas model; bar/min
/// is a pressure drop and carries no equation of state.
void main() {
  /// The issue's cylinder: 12 L, 200 -> 50 bar, 44 min, 13.2 m average.
  /// Ideal reads 17.6 L/min, real reads 16.8.
  Dive reportedDive({double? volume = 12.0}) {
    return createTestDiveWithBottomTime(
      runtime: const Duration(minutes: 44),
      avgDepth: 13.2,
    ).copyWith(
      tanks: [
        DiveTank(
          id: 'tank-1',
          volume: volume,
          startPressure: 200.0,
          endPressure: 50.0,
          gasMix: const GasMix(o2: 21.0, he: 0.0),
          role: TankRole.backGas,
        ),
      ],
    );
  }

  /// The detail page renders a profile chart that can overflow an
  /// unconstrained test viewport. Ignore only that, and forward everything
  /// else, so a real rendering or navigation failure still fails the test.
  void ignoreOverflowErrors() {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  }

  Future<void> pumpWith(
    WidgetTester tester,
    AppSettings settings, {
    Dive? dive,
  }) async {
    dive ??= reportedDive();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );

    ignoreOverflowErrors();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(DiveDetailPage)));

  testWidgets('volumetric SAC reads the ideal value when ideal is selected', (
    tester,
  ) async {
    await pumpWith(
      tester,
      const AppSettings(
        sacUnit: SacUnit.litersPerMin,
        gasModel: GasModel.ideal,
      ),
    );

    expect(find.text('17.6 L/min'), findsOneWidget);
    expect(find.byType(SacVolumeHint), findsNothing);
  });

  testWidgets('volumetric SAC reads the real value when real is selected', (
    tester,
  ) async {
    await pumpWith(
      tester,
      const AppSettings(sacUnit: SacUnit.litersPerMin, gasModel: GasModel.real),
    );

    expect(find.text('16.8 L/min'), findsOneWidget);
  });

  testWidgets('the pressure lane ignores the gas model', (tester) async {
    for (final model in GasModel.values) {
      await pumpWith(
        tester,
        AppSettings(sacUnit: SacUnit.pressurePerMin, gasModel: model),
      );
      // 150 bar / 44 min / 2.32 bar ambient = 1.47 bar/min, whichever
      // equation of state is selected.
      expect(find.text('1.5 bar/min'), findsOneWidget);
    }
  });

  group('volumetric SAC without a cylinder volume (issue #386)', () {
    testWidgets('falls back to the pressure lane and says why', (tester) async {
      // A dive-computer download: transmitter pressures, no cylinder size.
      await pumpWith(
        tester,
        const AppSettings(sacUnit: SacUnit.litersPerMin),
        dive: reportedDive(volume: null),
      );

      expect(find.text('1.5 bar/min'), findsOneWidget);
      expect(
        find.text(l10nOf(tester).diveLog_detail_sacVolumeHint('L')),
        findsOneWidget,
      );
    });

    testWidgets('names the diver\'s own volume unit in the hint', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const AppSettings(
          sacUnit: SacUnit.litersPerMin,
          volumeUnit: VolumeUnit.cubicFeet,
        ),
        dive: reportedDive(volume: null),
      );

      expect(
        find.text(l10nOf(tester).diveLog_detail_sacVolumeHint('cuft')),
        findsOneWidget,
      );
    });

    testWidgets('still falls back when only a stage bottle has a volume', (
      tester,
    ) async {
      // The back gas (the tank sacPressure reads) has pressures but no size;
      // a stage carries a size but no pressures. No cylinder can yield L/min,
      // so the row must fall back and the hint must still point at volume.
      final dive = reportedDive(volume: null).copyWith(
        tanks: [
          ...reportedDive(volume: null).tanks,
          const DiveTank(
            id: 'stage-1',
            volume: 11.1,
            gasMix: GasMix(o2: 50.0, he: 0.0),
            role: TankRole.stage,
            order: 1,
          ),
        ],
      );
      await pumpWith(
        tester,
        const AppSettings(sacUnit: SacUnit.litersPerMin),
        dive: dive,
      );

      expect(find.text('1.5 bar/min'), findsOneWidget);
      expect(find.byType(SacVolumeHint), findsOneWidget);
    });

    testWidgets('shows no hint in the pressure lane', (tester) async {
      await pumpWith(
        tester,
        const AppSettings(sacUnit: SacUnit.pressurePerMin),
        dive: reportedDive(volume: null),
      );

      expect(find.text('1.5 bar/min'), findsOneWidget);
      expect(find.byType(SacVolumeHint), findsNothing);
    });

    testWidgets('tapping the hint opens the dive editor', (tester) async {
      final dive = reportedDive(volume: null);
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
      ignoreOverflowErrors();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) async => dive),
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

      final hint = find.byType(SacVolumeHint);
      expect(hint, findsOneWidget);
      await tester.ensureVisible(hint);
      await tester.pump();
      await tester.tap(hint);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('EDIT_STUB ${dive.id}'), findsOneWidget);
    });

    testWidgets('hides the row when there is no pressure data either', (
      tester,
    ) async {
      final dive = reportedDive(volume: null).copyWith(
        tanks: const [
          DiveTank(id: 'tank-1', gasMix: GasMix(), role: TankRole.backGas),
        ],
      );
      await pumpWith(
        tester,
        const AppSettings(sacUnit: SacUnit.litersPerMin),
        dive: dive,
      );

      // Nothing to fall back to, so a hint about volume would mislead.
      expect(
        find.text(l10nOf(tester).diveLog_detail_label_sacRate),
        findsNothing,
      );
      expect(find.byType(SacVolumeHint), findsNothing);
    });
  });
}
