import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_preset_edit_page.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// Locale-aware numeric input across the planner, cylinder configurations and
/// tank presets (#1091).
///
/// Two behaviours matter, and the second is the dangerous one:
///
/// 1. A comma-decimal diver can type "11,1" and have it stored as 11.1.
/// 2. Opening an existing record under a GROUPING-dot locale (de/es/it) and
///    saving it untouched leaves the value alone. A field seeded with a dot
///    but read back by a locale-aware parser turns 12.5 into 125.
void main() {
  // Intl.defaultLocale is a process global (the app sets it from the diver's
  // locale in lib/app.dart) and leaks across tests in an isolate, so restore
  // it every time. Number symbols are statically bundled: no async init.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  // The UI language stays English so finders like find.text('Save') keep
  // working; the pinned global is what governs number parsing.
  const uiLocale = Locale('en');

  group('PlanTankList tank dialog', () {
    Widget host() => testApp(
      locale: uiLocale,
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: const SingleChildScrollView(child: PlanTankList()),
    );

    testWidgets('stores a comma-decimal volume and gas fraction', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Volume (L)'),
        '11,1',
      );
      await tester.enterText(find.widgetWithText(TextField, 'O₂ %'), '32,5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final added = container.read(divePlanNotifierProvider).tanks.last;
      expect(added.volume, closeTo(11.1, 0.001));
      expect(added.gasMix.o2, 32.5);
    });

    testWidgets('a no-op edit under a grouping-dot locale keeps the volume', (
      tester,
    ) async {
      // The x10 regression guard: the default tank is 11.1 L, so a dot seed
      // read back under de would store 111 L without the diver typing at all.
      Intl.defaultLocale = 'de';
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InputChip, 'Primary'));
      await tester.pumpAndSettle();

      final volume = tester
          .widget<TextField>(find.widgetWithText(TextField, 'Volume (L)'))
          .controller!;
      expect(volume.text, '11,1');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanTankList)),
      );
      final tank = container.read(divePlanNotifierProvider).tanks.first;
      expect(tank.volume, closeTo(11.1, 0.001));
      expect(tank.startPressure, closeTo(200, 0.001));
      expect(tank.gasMix.o2, 21);
    });
  });

  group('CcrSettingsSection', () {
    Widget host() => testApp(
      locale: uiLocale,
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: const SizedBox(width: 500, child: CcrSettingsSection()),
    );

    testWidgets('accepts a comma-decimal setpoint', (tester) async {
      Intl.defaultLocale = 'fr';
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '1,2');
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CcrSettingsSection)),
      );
      expect(container.read(divePlanNotifierProvider).setpointLow, 1.2);
    });

    testWidgets('seeds the setpoints with the locale separator', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        '0,7',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '1,3',
      );
    });
  });

  group('ContingencySettingsSection', () {
    Widget host() => testApp(
      locale: uiLocale,
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: const SizedBox(width: 500, child: ContingencySettingsSection()),
    );

    Future<ProviderContainer> showCustomFraction(WidgetTester tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContingencySettingsSection)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .updateContingencies(turnRule: domain.TurnPressureRule.custom);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('seeds the turn fraction with the locale separator', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      await showCustomFraction(tester);

      expect(find.widgetWithText(TextFormField, '0,33'), findsOneWidget);
    });

    testWidgets('accepts a comma-decimal turn fraction', (tester) async {
      Intl.defaultLocale = 'fr';
      final container = await showCustomFraction(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '0,33'), '0,4');
      await tester.pumpAndSettle();

      expect(
        container.read(divePlanNotifierProvider).turnPressureFraction,
        0.4,
      );
    });
  });

  group('CylinderConfigItemEditor', () {
    late CylinderConfigItem current;

    Widget host(CylinderConfigItem item) {
      current = item;
      return testApp(
        locale: uiLocale,
        overrides: [
          tankPresetsProvider.overrideWith((ref) async => <TankPresetEntity>[]),
        ],
        child: StatefulBuilder(
          builder: (context, setState) => CylinderConfigItemEditor(
            item: current,
            units: const UnitFormatter(AppSettings()),
            onChanged: (updated) => setState(() => current = updated),
            onRemove: () {},
          ),
        ),
      );
    }

    CylinderConfigItem seed({double o2 = 21}) => CylinderConfigItem(
      id: 'i1',
      configId: 'c1',
      tankRole: TankRole.backGas,
      o2Percent: o2,
      hePercent: 0,
      createdAt: DateTime.utc(2026, 8, 16),
      updatedAt: DateTime.utc(2026, 8, 16),
    );

    testWidgets('reports a comma-decimal gas fraction', (tester) async {
      Intl.defaultLocale = 'fr';
      await tester.pumpWidget(host(seed()));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '32,5');
      await tester.pumpAndSettle();

      expect(current.o2Percent, 32.5);
    });

    testWidgets('seeds a fractional mix with the locale separator', (
      tester,
    ) async {
      // Seeding "32.5" here would read back as 325 % oxygen under de.
      Intl.defaultLocale = 'de';
      await tester.pumpWidget(host(seed(o2: 32.5)));
      await tester.pumpAndSettle();

      expect(find.text('32,5'), findsOneWidget);
    });
  });

  group('TankPresetEditPage', () {
    late _RecordingPresetNotifier notifier;

    Future<void> pumpPage(WidgetTester tester, TankPresetEntity preset) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      notifier = _RecordingPresetNotifier([preset]);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                TankPresetEditPage(presetId: preset.id),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetRepositoryProvider.overrideWithValue(
              _StubPresetRepository(preset),
            ),
            tankPresetListNotifierProvider.overrideWith((ref) => notifier),
          ].cast(),
          child: MaterialApp.router(
            locale: uiLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    TankPresetEntity preset({double volumeLiters = 12.5}) => TankPresetEntity(
      id: 'p1',
      name: 'test',
      displayName: 'Test',
      volumeLiters: volumeLiters,
      workingPressureBar: 200,
      material: TankMaterial.aluminum,
      description: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    testWidgets('a no-op save under a grouping-dot locale keeps the volume', (
      tester,
    ) async {
      // The x10 regression guard for a validated form: the validator and the
      // save-path parser must agree with the seed, or 12,5 L becomes 125 L.
      Intl.defaultLocale = 'de';
      await pumpPage(tester, preset());

      expect(find.widgetWithText(TextFormField, '12,5'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.updated, isNotNull);
      expect(notifier.updated!.volumeLiters, closeTo(12.5, 0.001));
      expect(notifier.updated!.workingPressureBar, closeTo(200, 0.001));
    });

    testWidgets('a comma-decimal volume passes the validator and saves', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      await pumpPage(tester, preset());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Volume'),
        '14,2',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No validation error, and the typed value landed unrounded.
      expect(find.text('Enter a valid volume'), findsNothing);
      expect(notifier.updated, isNotNull);
      expect(notifier.updated!.volumeLiters, closeTo(14.2, 0.001));
    });
  });
}

/// Returns one known preset without touching the database.
class _StubPresetRepository extends TankPresetRepository {
  _StubPresetRepository(this.preset);

  final TankPresetEntity preset;

  @override
  Future<TankPresetEntity?> getPresetById(String id) async =>
      preset.id == id ? preset : null;

  @override
  Future<List<TankPresetEntity>> getAllPresets({String? diverId}) async => [
    preset,
  ];

  @override
  Future<List<TankPresetEntity>> getCustomPresets({String? diverId}) async =>
      const [];
}

/// Captures what the edit page asked to persist.
class _RecordingPresetNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _RecordingPresetNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  TankPresetEntity? updated;

  @override
  Future<void> refresh() async {}

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async {
    updated = preset;
    return preset;
  }

  @override
  Future<void> updatePreset(TankPresetEntity preset) async => updated = preset;

  @override
  Future<void> deletePreset(String id) async {}
}
