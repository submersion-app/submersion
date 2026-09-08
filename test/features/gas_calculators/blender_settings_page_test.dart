import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/blender_settings_page.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_fill_gases_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_app.dart';
import '../../support/fake_app_settings_repository.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the calculator behind a [GoRouter] whose Trimix Mixer route is the
/// real page, so tapping the gear is exercised the way the app's ShellRoute
/// reaches it rather than through an imperative Navigator.push (PR #1359
/// review). Hands back a getter for the current location.
Future<String Function()> _pumpWithRouter(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/gas-calculators',
    routes: [
      GoRoute(
        path: '/gas-calculators',
        builder: (context, state) =>
            const Scaffold(body: GasBlenderCalculator()),
      ),
      GoRoute(
        path: kTrimixMixerSettingsRoute,
        builder: (context, state) => const BlenderSettingsPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    testAppRouter(
      locale: const Locale('en'),
      router: router,
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        tankPresetsProvider.overrideWith((ref) async => const []),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return () => router.state.uri.toString();
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        tankPresetsProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GasBlenderCalculator()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Preferences that differ from every hard-coded default, so a field showing
/// a default is unambiguously a field that never saw storage.
BlenderPreferences _storedPreferences() => const BlenderPreferences(
  templates: [MixTemplate(o2: 21, he: 35)],
  gasPrices: [1.5, null, null],
  fillTempC: 5,
  settledTempC: 15,
  cylinderWaterLiters: 24,
  model: BlendGasModel.ideal,
  billedFills: [],
  billedTo: 'Anna',
  startPressureBar: 55,
  startMix: GasMix(o2: 28),
  targetPressureBar: 232,
  targetMix: GasMix(o2: 18, he: 45),
  topupO2Percent: 32,
);

/// Opens the settings page on its own route, the way Settings > Manage > Data
/// does -- the calculator never mounts, so nothing else can have triggered the
/// preferences load.
Future<void> _pumpSettingsPageAlone(
  WidgetTester tester,
  FakeAppSettingsRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        appSettingsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlenderSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Finder card, int index) => tester
    .widget<TextField>(
      find.descendant(of: card, matching: find.byType(TextField)).at(index),
    )
    .controller!
    .text;

void main() {
  testWidgets('the gear opens the Trimix Mixer settings page', (tester) async {
    final location = await _pumpWithRouter(tester);
    await tester.tap(find.byKey(const Key('blender-settings')));
    await tester.pumpAndSettle();

    // The registered route, not a page pushed onto the shell's navigator:
    // the location has to describe what is on screen, or the bottom bar can
    // change it underneath (PR #1359 review).
    expect(location(), kTrimixMixerSettingsRoute);
    expect(find.text('Trimix Mixer'), findsOneWidget);
    expect(find.text('Fill gases'), findsOneWidget);
    expect(find.text('Blending conditions'), findsOneWidget);
  });

  testWidgets('fill gases and mixing conditions leave the main screen', (
    tester,
  ) async {
    // Issue #1335: they move behind the gear, keeping their own layout, so
    // they no longer compete with the fields a diver retypes every fill.
    await _pump(tester);
    expect(find.text('Fill gases'), findsNothing);
    expect(find.text('Blending conditions'), findsNothing);
  });

  testWidgets(
    'the price fields leave the billing card, and settings carries no local '
    'currency choice',
    (tester) async {
      // Issue #44 follow-up: the mixer's own read-only currency mirror is
      // gone along with the "Default settings and billing" section that used
      // to hold it -- the currency always follows Settings -> Units ->
      // Default currency, with nothing left to show for it here.
      await _pumpWithRouter(tester);
      expect(find.byKey(const Key('blender-currency-display')), findsNothing);

      await tester.tap(find.byKey(const Key('blender-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blender-currency-display')), findsNothing);
      expect(find.text('Default settings and billing'), findsNothing);
    },
  );

  testWidgets(
    'the cylinder-sizes link navigates to the global tank presets, not settings',
    (tester) async {
      late String location;
      final router = GoRouter(
        initialLocation: '/gas-calculators',
        routes: [
          GoRoute(
            path: '/gas-calculators',
            builder: (context, state) =>
                const Scaffold(body: GasBlenderCalculator()),
          ),
          GoRoute(
            path: '/tank-presets',
            builder: (context, state) {
              location = GoRouterState.of(context).uri.toString();
              return const Scaffold(body: Text('Tank Presets'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        testAppRouter(
          locale: const Locale('en'),
          router: router,
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(const AppSettings()),
            ),
            tankPresetsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The billing card sits below the fold on the default test surface, so
      // its dropdown has to be scrolled into view before it can be opened,
      // same as a diver would need to scroll down to reach it.
      await tester.ensureVisible(
        find.byKey(const Key('blender-cylinder-presets')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blender-cylinder-presets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blender-cylinder-sizes-link')));
      await tester.pumpAndSettle();

      expect(location, '/tank-presets');
    },
  );

  group('reached straight from Settings, without the calculator', () {
    testWidgets('seeds its fields from the stored preferences', (tester) async {
      final repository = FakeAppSettingsRepository()
        ..blenderPreferences = _storedPreferences();
      await _pumpSettingsPageAlone(tester, repository);

      // Each role row contributes up to three TextFields in order (mix,
      // price, purge volume); O2 and He show no mix TextField since their
      // purity is fixed (issue #42), so the sequence is: O2 price (0), O2
      // purge volume (1), He price (2), He purge volume (3), topup O2 (4),
      // topup price (5), topup purge volume (6). The topup role's O2
      // fraction is seeded from storage at 32% rather than the default 21%.
      expect(_fieldText(tester, find.byType(BlenderFillGasesCard), 4), '32');
      // The O2 role's price is the first TextField on the card: its fixed
      // purity is an InputDecorator, not a TextField, so only its price
      // field counts.
      expect(_fieldText(tester, find.byType(BlenderFillGasesCard), 0), '1.5');
      expect(find.text('21/35'), findsOneWidget);
    });

    testWidgets('editing one field does not overwrite the rest of the blob', (
      tester,
    ) async {
      // Saving is whole-blob, so a page that never loaded would write its
      // defaults over the templates, the billed-to name and the last-entered
      // pressures the diver never touched.
      final repository = FakeAppSettingsRepository()
        ..blenderPreferences = _storedPreferences();
      await _pumpSettingsPageAlone(tester, repository);

      await tester.enterText(
        find
            .descendant(
              of: find.byType(BlenderFillGasesCard),
              matching: find.byType(TextField),
            )
            // The O2 role's price field: the fixed O2/He rows show no
            // TextField, so this is the first one on the card.
            .at(0),
        '2.25',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final saved = repository.blenderPreferences!;
      expect(saved.gasPrices.first, closeTo(2.25, 1e-9));
      expect(saved.templates, const [MixTemplate(o2: 21, he: 35)]);
      expect(saved.billedTo, 'Anna');
      expect(saved.startPressureBar, 55);
      expect(saved.targetMix, const GasMix(o2: 18, he: 45));
      expect(saved.cylinderWaterLiters, 24);
    });
  });
}
