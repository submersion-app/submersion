import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_preset_edit_page.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  group('TankPresetEditPage', () {
    testWidgets(
      'loads existing preset and displays pressure in imperial (psi)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Configure imperial settings
        final mockSettings = MockSettingsNotifier();
        await mockSettings.setPressureUnit(PressureUnit.psi);
        await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

        // Create a test preset: AL80-like with 206.843 bar working pressure
        final testPreset = TankPresetEntity(
          id: 'test-preset-1',
          name: 'al80',
          displayName: 'AL80',
          volumeLiters: 11.1,
          workingPressureBar: 206.843,
          material: TankMaterial.aluminum,
          description: 'Test preset',
          isBuiltIn: false,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          ratedCapacityCuft: 77.4,
        );

        // Mock repository that returns the test preset
        final mockRepo = _MockTankPresetRepository(preset: testPreset);

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const TankPresetEditPage(presetId: 'test-preset-1'),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              settingsProvider.overrideWith((ref) => mockSettings),
              currentDiverIdProvider.overrideWith(
                (ref) => MockCurrentDiverIdNotifier(),
              ),
              tankPresetRepositoryProvider.overrideWithValue(mockRepo),
              tankPresetListNotifierProvider.overrideWith(
                (ref) => _MockTankPresetListNotifier([testPreset]),
              ),
            ].cast(),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The page should have loaded the preset.
        // Working pressure: 206.843 bar * 14.5038 = ~3000 psi
        // Line 77: _workingPressureController.text =
        //   units.convertPressure(preset.workingPressureBar).toStringAsFixed(0)
        expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget);

        // Volume: in cubicFeet mode, shows volumeCuft = 77.4
        // Line 70: preset.volumeCuft.toStringAsFixed(1)
        expect(find.widgetWithText(TextFormField, '77.4'), findsOneWidget);
      },
    );

    testWidgets('a small bottle keeps both decimals of its size (#4243)', (
      tester,
    ) async {
      // A drysuit's 0.85 L argon bottle must not load, and so save, as 0.9.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final testPreset = TankPresetEntity(
        id: 'argon',
        name: 'argon',
        displayName: 'Argon',
        volumeLiters: 0.85,
        workingPressureBar: 200,
        material: TankMaterial.aluminum,
        description: '',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const TankPresetEditPage(presetId: 'argon'),
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
              _MockTankPresetRepository(preset: testPreset),
            ),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier([testPreset]),
            ),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '0.85'), findsOneWidget);
      expect(find.text('\u2022 Water volume: 0.85 L'), findsOneWidget);
    });

    testWidgets('info card shows working pressure converted to bar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Configure imperial settings (psi input, cuft volume)
      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      // Create a test preset with 206.843 bar working pressure.
      // When loaded in imperial mode, the controller gets 3000 psi.
      // The info card then converts 3000 psi back to bar for display.
      final testPreset = TankPresetEntity(
        id: 'test-preset-2',
        name: 'al80',
        displayName: 'AL80',
        volumeLiters: 11.1,
        workingPressureBar: 206.843,
        material: TankMaterial.aluminum,
        description: 'Test preset',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ratedCapacityCuft: 77.4,
      );

      final mockRepo = _MockTankPresetRepository(preset: testPreset);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const TankPresetEditPage(presetId: 'test-preset-2'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => mockSettings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetRepositoryProvider.overrideWithValue(mockRepo),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier([testPreset]),
            ),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // After loading the preset, the info card is built via _buildInfoCard.
      // Line 269: pressureBar = units.pressureToBar(3000.0)
      //   = 3000 / 14.5038 = ~206.843 bar -> round() = 207
      // Lines 305-306: context.l10n.tankPresets_edit_workingPressureBar(207)
      //   = "Working pressure: 207 bar"
      expect(find.textContaining('207 bar'), findsOneWidget);

      // Verify the Tank Specifications header is present
      expect(find.text('Cylinder Specifications'), findsOneWidget);

      // Line 335 is exercised in _savePreset below.
    });

    testWidgets('save converts pressure to bar for storage', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSettings = MockSettingsNotifier();
      await mockSettings.setPressureUnit(PressureUnit.psi);
      await mockSettings.setVolumeUnit(VolumeUnit.cubicFeet);

      final testPreset = TankPresetEntity(
        id: 'test-preset-save',
        name: 'al80',
        displayName: 'AL80',
        volumeLiters: 11.1,
        workingPressureBar: 206.843,
        material: TankMaterial.aluminum,
        description: 'Test',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ratedCapacityCuft: 77.4,
      );

      final mockRepo = _MockTankPresetRepository(preset: testPreset);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const TankPresetEditPage(presetId: 'test-preset-save'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => mockSettings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            tankPresetRepositoryProvider.overrideWithValue(mockRepo),
            tankPresetListNotifierProvider.overrideWith(
              (ref) => _MockTankPresetListNotifier([testPreset]),
            ),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Save is offered only once something changed: rename it, then
      // save. The pressure shown in psi is stored in bar.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'AL80'),
        'AL80 renamed',
      );
      await tester.pumpAndSettle();
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      final saved = mockRepo.updated.single;
      expect(saved.displayName, 'AL80 renamed');
      expect(saved.workingPressureBar, closeTo(206.843, 0.01));
    });
  });

  group('TankPresetEditPage on the shared Cancel and Save bar', () {
    final stored = TankPresetEntity(
      id: 'p1',
      diverId: 'diver-1',
      name: 'al80',
      displayName: 'AL80',
      volumeLiters: 11.1,
      workingPressureBar: 206.843,
      material: TankMaterial.aluminum,
      description: 'Test',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      ratedCapacityCuft: 77.4,
    );
    late _MockTankPresetRepository repo;
    late _MockTankPresetListNotifier list;
    late ProviderContainer container;

    /// The editor pushed over a stand-in list, in psi and cubic feet.
    Future<void> pumpEditor(
      WidgetTester tester, {
      String? presetId,
      bool failLoad = false,
      bool settle = true,
      bool metric = false,
      bool onlyPage = false,
      String? duplicateFromId,
      TankPresetEntity? repoPreset,
      Locale? locale,
      List<TankPresetEntity> others = const [],
      Completer<void>? loadGate,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = MockSettingsNotifier();
      if (!metric) {
        await settings.setPressureUnit(PressureUnit.psi);
        await settings.setVolumeUnit(VolumeUnit.cubicFeet);
      }
      repo =
          _MockTankPresetRepository(
              preset: repoPreset ?? stored,
              others: others,
            )
            ..loadGate = loadGate
            ..failLoad = failLoad;
      list = _MockTankPresetListNotifier([stored]);
      // [onlyPage]: the editor with no page under it, the preset list
      // reachable only by its address.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('list')),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) => TankPresetEditPage(
                  presetId: presetId,
                  duplicateFromId: duplicateFromId,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/tank-presets',
            builder: (_, _) => const Scaffold(body: Text('preset list')),
          ),
          GoRoute(
            path: '/only-edit',
            builder: (_, _) => TankPresetEditPage(presetId: presetId),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => settings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => ref.watch(currentDiverIdProvider) ?? 'diver-1',
            ),
            tankPresetRepositoryProvider.overrideWithValue(repo),
            tankPresetListNotifierProvider.overrideWith((ref) => list),
          ].cast(),
          child: MaterialApp.router(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(tester.element(find.text('list')));
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('diver-1');
      if (onlyPage) {
        router.go('/only-edit');
      } else {
        router.push('/edit');
      }
      if (settle) await tester.pumpAndSettle();
    }

    Finder saveAction() => find.widgetWithText(RecordEditAction, 'Save');

    VoidCallback? saveOnPressed(WidgetTester tester) =>
        tester.widget<RecordEditAction>(saveAction()).onPressed;

    Future<void> back(WidgetTester tester) async {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      await tester.pumpAndSettle();
    }

    testWidgets('a preset opened in psi and cuft and left alone is unchanged', (
      tester,
    ) async {
      await pumpEditor(tester, presetId: 'p1');
      expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget);
      expect(saveOnPressed(tester), isNull);
      await back(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets(
      'the bar is the tinted Cancel and Save bar, with no close button',
      (tester) async {
        await pumpEditor(tester, presetId: 'p1');
        expect(find.byType(RecordEditBar), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
      },
    );

    testWidgets('Back after changing the name asks before leaving', (
      tester,
    ) async {
      await pumpEditor(tester, presetId: 'p1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'AL80'),
        'AL80 bailout',
      );
      await tester.pumpAndSettle();
      await back(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('list'), findsOneWidget);
      expect(repo.updated, isEmpty);
    });

    testWidgets(
      'a new preset is written under the page id, then the list refreshes',
      (tester) async {
        await pumpEditor(tester);
        expect(saveOnPressed(tester), isNull);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Stage 40');
        await tester.enterText(fields.at(1), '40');
        await tester.enterText(fields.at(2), '3000');
        await tester.pumpAndSettle();
        final host =
            tester.state(find.byType(TankPresetEditPage)) as RecordEditorHost;
        final pageId = host.newEditorRecordId;
        await tester.tap(saveAction());
        await tester.pumpAndSettle();
        final created = repo.created.single;
        expect(created.displayName, 'Stage 40');
        expect(created.diverId, 'diver-1');
        expect(created.id, pageId);
        expect(find.byType(TankPresetEditPage), findsNothing);
        expect(list.refreshes, 1);
        expect(find.text('list'), findsOneWidget);
      },
    );

    testWidgets('renaming a preset in cuft keeps its stored volume and '
        'pressure', (tester) async {
      await pumpEditor(tester, presetId: 'p1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'AL80'),
        'AL80 bailout',
      );
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      final saved = repo.updated.single;
      expect(saved.displayName, 'AL80 bailout');
      expect(saved.volumeLiters, 11.1);
      expect(saved.workingPressureBar, 206.843);
      // Same cylinder, so its rating still holds (#800).
      expect(saved.ratedCapacityCuft, 77.4);
    });

    testWidgets('changing the pressure in cuft stores it and the volume the '
        'shown capacity gives', (tester) async {
      await pumpEditor(tester, presetId: 'p1');
      await tester.enterText(
        find.widgetWithText(TextFormField, '3000'),
        '3442',
      );
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      final saved = repo.updated.single;
      const bar = 3442 / 14.5038;
      expect(saved.workingPressureBar, closeTo(bar, 0.01));
      expect(saved.volumeLiters, closeTo(77.4 * 28.3168 / bar, 0.01));
      // A new pressure is a different cylinder: the rating no longer holds.
      expect(saved.ratedCapacityCuft, isNull);
    });

    testWidgets('changing the pressure in litres keeps the stored volume', (
      tester,
    ) async {
      await pumpEditor(tester, presetId: 'p1', metric: true);
      await tester.enterText(find.widgetWithText(TextFormField, '207'), '232');
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      final saved = repo.updated.single;
      expect(saved.workingPressureBar, 232);
      expect(saved.volumeLiters, 11.1);
    });

    testWidgets('a preset deleted elsewhere while edited is refused at Save, '
        'saying so', (tester) async {
      await pumpEditor(tester, presetId: 'p1');
      repo.deleted = true;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'AL80'),
        'AL80 bailout',
      );
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      expect(repo.updated, isEmpty);
      expect(
        find.text('This cylinder preset no longer exists.'),
        findsOneWidget,
      );
      expect(find.byType(TankPresetEditPage), findsOneWidget);
    });

    testWidgets('a preset that cannot open, with no page under it, goes to '
        'the preset list', (tester) async {
      await pumpEditor(tester, presetId: 'gone', onlyPage: true);
      expect(
        find.text('This cylinder preset no longer exists.'),
        findsOneWidget,
      );
      expect(find.text('preset list'), findsOneWidget);
    });

    testWidgets('a rename keeps what a sync changed meanwhile in fields the '
        'diver left alone', (tester) async {
      await pumpEditor(tester, presetId: 'p1');
      repo.latest = stored.copyWith(
        description: 'Synced from the boat',
        material: TankMaterial.steel,
        sortOrder: 7,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'AL80'),
        'AL80 bailout',
      );
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      final saved = repo.updated.single;
      expect(saved.displayName, 'AL80 bailout');
      expect(saved.description, 'Synced from the boat');
      expect(saved.material, TankMaterial.steel);
      expect(saved.sortOrder, 7);
      expect(saved.volumeLiters, 11.1);
    });

    testWidgets('a preset that no longer exists says so and leaves', (
      tester,
    ) async {
      await pumpEditor(tester, presetId: 'gone');
      expect(
        find.text('This cylinder preset no longer exists.'),
        findsOneWidget,
      );
      expect(find.byType(TankPresetEditPage), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('a preset that fails to load says so and leaves', (
      tester,
    ) async {
      await pumpEditor(tester, presetId: 'p1', failLoad: true);
      expect(find.textContaining('Error loading preset'), findsOneWidget);
      expect(find.byType(TankPresetEditPage), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('a duplicated built-in opens filled, named as a copy, and '
        'saves as a new preset (#800)', (tester) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        metric: true,
        locale: const Locale('en'),
      );
      expect(find.widgetWithText(TextFormField, 'AL80 (copy)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '11.1'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '207'), findsOneWidget);
      // The copy is the change: Save works without touching a field.
      expect(saveOnPressed(tester), isNotNull);

      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      expect(repo.updated, isEmpty);
      final created = repo.created.single;
      expect(created.isBuiltIn, isFalse);
      expect(created.displayName, 'AL80 (copy)');
      expect(created.volumeLiters, closeTo(11.1, 0.01));
      expect(created.workingPressureBar, closeTo(207, 0.5));
      expect(created.material, al80.material);
    });

    testWidgets('a duplicate left alone in psi and cuft keeps the built-in '
        'values exactly (#800)', (tester) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        locale: const Locale('en'),
      );
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      final created = repo.created.single;
      expect(created.workingPressureBar, al80.workingPressureBar);
      expect(created.volumeLiters, al80.volumeLiters);
      // The copy still reads the built-in's rated 77.4 cuft (#800).
      expect(created.ratedCapacityCuft, al80.ratedCapacityCuft);
      expect(created.volumeCuft, 77.4);
    });

    testWidgets('a duplicate given a new pressure drops the built-in rating '
        '(#800)', (tester) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        locale: const Locale('en'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '3000'),
        '3442',
      );
      await tester.pumpAndSettle();
      await tester.tap(saveAction());
      await tester.pumpAndSettle();
      expect(repo.created.single.ratedCapacityCuft, isNull);
    });

    testWidgets('a duplicate takes the built-in description in the app '
        'language (#800)', (tester) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        locale: const Locale('de'),
      );
      final german = builtInTankPresetDescription(
        lookupAppLocalizations(const Locale('de')),
        'al80',
      )!;
      expect(german, isNot(al80.description));
      expect(find.widgetWithText(TextFormField, german), findsOneWidget);
    });

    testWidgets('a duplicated custom preset keeps its own name and '
        'description (#800)', (tester) async {
      await pumpEditor(
        tester,
        duplicateFromId: 'p1',
        metric: true,
        locale: const Locale('en'),
      );
      expect(find.widgetWithText(TextFormField, 'AL80 (copy)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Test'), findsOneWidget);
    });

    testWidgets('a built-in with no translation keeps its stored name and '
        'description (#800)', (tester) async {
      final odd = TankPresetEntity(
        id: 'odd_slug',
        name: 'odd_slug',
        displayName: 'Odd',
        volumeLiters: 3,
        workingPressureBar: 200,
        material: TankMaterial.steel,
        description: 'Plain words',
        isBuiltIn: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      await pumpEditor(
        tester,
        duplicateFromId: 'odd_slug',
        repoPreset: odd,
        metric: true,
        locale: const Locale('en'),
      );
      expect(find.widgetWithText(TextFormField, 'Odd (copy)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Plain words'), findsOneWidget);
    });

    testWidgets('a duplicate whose source fails to load says so and leaves '
        'the new preset empty (#800)', (tester) async {
      await pumpEditor(
        tester,
        duplicateFromId: 'p1',
        failLoad: true,
        locale: const Locale('en'),
      );
      expect(find.textContaining('database closed'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'AL80 (copy)'), findsNothing);
    });

    testWidgets('a second duplicate gets a name of its own (#800)', (
      tester,
    ) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      final firstCopy = TankPresetEntity.create(
        id: 'c1',
        name: TankPresetEntity.generateSlug('AL80 (copy)'),
        displayName: 'AL80 (copy)',
        volumeLiters: 11.1,
        workingPressureBar: 206.843,
        material: TankMaterial.aluminum,
      );
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        others: [firstCopy],
        metric: true,
        locale: const Locale('en'),
      );
      expect(
        find.widgetWithText(TextFormField, 'AL80 (copy 2)'),
        findsOneWidget,
      );
    });

    testWidgets('a duplicate that loads late keeps what the diver already '
        'typed (#800)', (tester) async {
      final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);
      final gate = Completer<void>();
      await pumpEditor(
        tester,
        duplicateFromId: 'al80',
        repoPreset: al80,
        metric: true,
        locale: const Locale('en'),
        loadGate: gate,
      );
      await tester.enterText(find.byType(TextFormField).first, 'My stage');
      await tester.pumpAndSettle();

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'My stage'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '11.1'), findsNothing);
    });

    testWidgets('a new preset opens on the tinted bar from its first frame', (
      tester,
    ) async {
      await pumpEditor(tester, settle: false);
      // The first frame that builds the editor, offstage or not, already
      // shows the bar.
      Finder built(Type type) => find.byType(type, skipOffstage: false);
      for (
        var i = 0;
        i < 5 && built(TankPresetEditPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump();
      }
      expect(built(TankPresetEditPage), findsOneWidget);
      expect(built(RecordEditBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('a new preset typed in closes on a diver switch, writing '
        'nothing', (tester) async {
      await pumpEditor(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Stage 40');
      await tester.pumpAndSettle();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('diver-2');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
      expect(repo.created, isEmpty);
    });
  });
}

/// Mock TankPresetRepository that returns a preset by ID without database access
class _MockTankPresetRepository extends TankPresetRepository {
  final TankPresetEntity? preset;

  /// The diver's other presets, listed beside [preset].
  final List<TankPresetEntity> others;

  /// When set, a load waits for it: a source that arrives late.
  Completer<void>? loadGate;

  _MockTankPresetRepository({this.preset, this.others = const []});

  bool failLoad = false;

  /// Set once the preset has been deleted elsewhere: it reads as gone.
  bool deleted = false;

  /// The preset as stored now, once something else changed it after the
  /// page loaded (a sync from another device).
  TankPresetEntity? latest;

  final created = <TankPresetEntity>[];
  final updated = <TankPresetEntity>[];

  @override
  Future<TankPresetEntity> createPreset(TankPresetEntity preset) async {
    created.add(preset);
    return preset;
  }

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {
    updated.add(preset);
  }

  @override
  Future<TankPresetEntity?> getPresetById(String id) async {
    await loadGate?.future;
    if (failLoad) throw StateError('database closed');
    if (deleted) return null;
    final now = latest;
    if (now != null && now.id == id) return now;
    if (preset != null && preset!.id == id) {
      return preset;
    }
    return null;
  }

  @override
  Future<List<TankPresetEntity>> getAllPresets({String? diverId}) async {
    return [?preset, ...others];
  }

  @override
  Future<List<TankPresetEntity>> getCustomPresets({String? diverId}) async {
    return [];
  }
}

/// Simple mock that directly holds preset data in state
class _MockTankPresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _MockTankPresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async => preset;

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {}

  @override
  Future<void> deletePreset(String id) async {}
}
