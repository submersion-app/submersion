import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show
        DiveComputersCompanion,
        DivesCompanion,
        GasSwitche,
        GasSwitchesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gas switch list on the dive edit page (issue #32): a switch the diver
/// adds is saved with the profile's depth and marks the dive's list as the
/// diver's; removing a cylinder takes its switches with it; a dive with one
/// cylinder shows no list; an untouched list writes nothing.
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  const back = DiveTank(id: 'tank-back', volume: 12, order: 0);
  const deco = DiveTank(
    id: 'tank-deco',
    volume: 7,
    role: TankRole.deco,
    gasMix: GasMix(o2: 50),
    order: 1,
  );
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 30),
    DiveProfilePoint(timestamp: 1200, depth: 30),
    DiveProfilePoint(timestamp: 1800, depth: 0),
  ];

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<Dive> seedDive({
    List<DiveTank> tanks = const [back, deco],
    List<DiveProfilePoint> samples = profile,
    DiveCenter? diveCenter,
  }) => repository.createDive(
    Dive(
      id: 'dive-32',
      dateTime: DateTime.utc(2026, 5, 3, 10),
      runtime: const Duration(seconds: 1800),
      tanks: tanks,
      profile: samples,
      diveCenter: diveCenter,
    ),
  );

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
    Future<Map<String, List<TankPressurePoint>>> Function()? pressures,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          if (pressures != null)
            tankPressuresProvider(diveId).overrideWith((ref) => pressures()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openGasGear(WidgetTester tester) async {
    if (find.text('CCR').evaluate().isEmpty) {
      final gasGear = find.textContaining('Gas & Gear');
      await tester.ensureVisible(gasGear.first);
      await tester.pumpAndSettle();
      await tester.tap(gasGear.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<List<GasSwitche>> storedSwitches() async {
    final db = DatabaseService.instance.database;
    return (db.select(db.gasSwitches)
          ..where((t) => t.diveId.equals('dive-32'))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  Future<bool> flagged() async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-32'))).getSingle();
    return row.gasSwitchesEdited;
  }

  testWidgets(
    'adding a switch saves it with the profile depth and marks the dive '
    'edited',
    (tester) async {
      final dive = await seedDive();
      String? savedId;
      await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
      await openGasGear(tester);

      final add = find.text('Add Switch');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final time = find.descendant(
        of: find.byType(MinutesSecondsField),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(time);
      await tester.enterText(time, '15:00');
      await tester.pumpAndSettle();

      await save(tester);
      expect(savedId, isNotNull, reason: 'save should complete');

      final rows = await storedSwitches();
      expect(rows, hasLength(1));
      expect(rows.single.timestamp, 900);
      expect(rows.single.tankId, 'tank-deco');
      expect(rows.single.depth, 30.0);
      expect(rows.single.computerId, isNull);
      expect(await flagged(), isTrue);
    },
  );

  testWidgets('removing a tank removes its switch on save', (tester) async {
    final dive = await seedDive();
    await repository.createGasSwitch(
      GasSwitch(
        id: 'gs-deco',
        diveId: dive.id,
        timestamp: 900,
        tankId: 'tank-deco',
        createdAt: DateTime.utc(2026, 5, 3, 11),
      ),
    );
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
    await openGasGear(tester);
    expect(find.byType(GasSwitchesEditor), findsOneWidget);

    // Expand the deco cylinder's row, then its remove control.
    final decoRow = find.textContaining('Tank 2');
    await tester.ensureVisible(decoRow.first);
    await tester.pumpAndSettle();
    await tester.tap(decoRow.first);
    await tester.pumpAndSettle();
    final remove = find.byIcon(Icons.delete_outline);
    await tester.ensureVisible(remove.first);
    await tester.pumpAndSettle();
    await tester.tap(remove.first);
    await tester.pumpAndSettle();

    // One cylinder left: the list is gone, the notice is not needed either.
    expect(find.byType(GasSwitchesEditor), findsNothing);

    await save(tester);
    expect(savedId, isNotNull, reason: 'save should complete');

    expect(await storedSwitches(), isEmpty);
    final db = DatabaseService.instance.database;
    final tombstones =
        await (db.select(db.deletionLog)..where(
              (t) =>
                  t.entityType.equals('gasSwitches') &
                  t.recordId.equals('gs-deco'),
            ))
            .get();
    expect(tombstones, hasLength(1));
  });

  testWidgets(
    'applying the last dive at a center drops the switches of the replaced '
    'cylinders',
    (tester) async {
      final center = DiveCenter(
        id: 'center-1',
        name: 'Reef Divers',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await DiveCenterRepository().createDiveCenter(center);
      // An earlier dive here, whose cylinders Apply last dive copies under
      // new ids.
      await repository.createDive(
        Dive(
          id: 'dive-0',
          dateTime: DateTime.utc(2026, 4, 1, 10),
          diveCenter: center,
          tanks: const [
            DiveTank(id: 'tank-old-back', volume: 11, order: 0),
            DiveTank(
              id: 'tank-old-deco',
              volume: 7,
              role: TankRole.deco,
              gasMix: GasMix(o2: 50),
              order: 1,
            ),
          ],
        ),
      );
      final dive = await seedDive(diveCenter: center);
      await repository.createGasSwitch(
        GasSwitch(
          id: 'gs-deco',
          diveId: dive.id,
          timestamp: 900,
          tankId: 'tank-deco',
          createdAt: DateTime.utc(2026, 5, 3, 11),
        ),
      );
      String? savedId;
      await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

      // The rental card sits in the Trip group, collapsed by default.
      final apply = find.text('Apply last dive');
      if (apply.evaluate().isEmpty) {
        final trip = find.text('Trip');
        await tester.ensureVisible(trip.first);
        await tester.pumpAndSettle();
        await tester.tap(trip.first);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(apply);
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      // Every cylinder is new: the switch to the old deco cylinder went
      // with it, and the list says so.
      await openGasGear(tester);
      expect(find.byType(GasSwitchesEditor), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gas-switch-row-gs-deco')),
        findsNothing,
      );
      expect(find.text('1 gas switch removed with its tank'), findsOneWidget);

      await save(tester);
      expect(savedId, isNotNull, reason: 'save should complete');
      expect(await storedSwitches(), isEmpty);
      expect(await flagged(), isTrue);
    },
  );

  testWidgets('a typed time reorders its row only once the field is left', (
    tester,
  ) async {
    final dive = await seedDive();
    for (final (id, t, tank) in [
      ('gs-a', 600, 'tank-deco'),
      ('gs-b', 1200, 'tank-back'),
    ]) {
      await repository.createGasSwitch(
        GasSwitch(
          id: id,
          diveId: dive.id,
          timestamp: t,
          tankId: tank,
          createdAt: DateTime.utc(2026, 5, 3, 11),
        ),
      );
    }
    await pumpEditor(tester, dive.id);
    await openGasGear(tester);

    List<String> rowIds() => tester
        .widgetList<MinutesSecondsField>(find.byType(MinutesSecondsField))
        .map((f) => (f.key as ValueKey<String>).value)
        .toList();
    expect(rowIds(), ['gas-switch-time-gs-a', 'gas-switch-time-gs-b']);

    final first = find.descendant(
      of: find.byKey(const ValueKey('gas-switch-time-gs-a')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(first);
    await tester.enterText(first, '25:00');
    await tester.pumpAndSettle();
    expect(rowIds(), ['gas-switch-time-gs-a', 'gas-switch-time-gs-b']);

    final second = find.descendant(
      of: find.byKey(const ValueKey('gas-switch-time-gs-b')),
      matching: find.byType(TextFormField),
    );
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(rowIds(), ['gas-switch-time-gs-b', 'gas-switch-time-gs-a']);
  });

  testWidgets(
    'a dive with no primary computer shows the untagged switches only',
    (tester) async {
      final dive = await seedDive();
      final db = DatabaseService.instance.database;
      await db
          .into(db.diveComputers)
          .insert(
            const DiveComputersCompanion(
              id: Value('comp-x'),
              name: Value('Secondary'),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      for (final (id, computer) in [
        ('gs-plain', null),
        ('gs-tagged', 'comp-x'),
      ]) {
        await db
            .into(db.gasSwitches)
            .insert(
              GasSwitchesCompanion.insert(
                id: id,
                diveId: dive.id,
                tankId: 'tank-deco',
                timestamp: id == 'gs-plain' ? 600 : 900,
                createdAt: 0,
                computerId: Value(computer),
              ),
            );
      }
      await pumpEditor(tester, dive.id);
      await openGasGear(tester);

      final rows = tester
          .widgetList<MinutesSecondsField>(find.byType(MinutesSecondsField))
          .map((f) => (f.key as ValueKey<String>).value)
          .toList();
      expect(rows, ['gas-switch-time-gs-plain']);
    },
  );

  testWidgets('a dive with one tank shows no gas switch list', (tester) async {
    final dive = await seedDive(tanks: const [back]);
    await pumpEditor(tester, dive.id);
    await openGasGear(tester);

    expect(find.text('Add Tank'), findsOneWidget);
    expect(find.byType(GasSwitchesEditor), findsNothing);
  });

  testWidgets('an untouched list saves nothing', (tester) async {
    final dive = await seedDive();
    await repository.createGasSwitch(
      GasSwitch(
        id: 'gs-deco',
        diveId: dive.id,
        timestamp: 900,
        tankId: 'tank-deco',
        createdAt: DateTime.utc(2026, 5, 3, 11),
      ),
    );
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
    await openGasGear(tester);
    expect(find.byType(GasSwitchesEditor), findsOneWidget);

    await save(tester);
    expect(savedId, isNotNull, reason: 'save should complete');

    expect((await storedSwitches()).map((s) => s.id), ['gs-deco']);
    expect(await flagged(), isFalse);
  });

  testWidgets('saving another field keeps the list the diver\'s', (
    tester,
  ) async {
    final dive = await seedDive();
    final db = DatabaseService.instance.database;
    await (db.update(db.dives)..where((t) => t.id.equals(dive.id))).write(
      const DivesCompanion(gasSwitchesEdited: Value(true)),
    );
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

    await save(tester);

    expect(savedId, isNotNull, reason: 'save should complete');
    expect(await flagged(), isTrue);
  });

  group('suggested times', () {
    /// The deco bottle held until 12:00, then breathed.
    Map<String, List<TankPressurePoint>> decoBreathedAt720() => {
      'tank-deco': [
        for (var t = 0; t < 1500; t += 2)
          TankPressurePoint(
            tankId: 'tank-deco',
            timestamp: t,
            pressure: t < 720 ? 200 : 200 - (t - 720) * 3.4 / 60,
          ),
      ],
    };

    Future<void> addSwitch(WidgetTester tester) async {
      await openGasGear(tester);
      final add = find.text('Add Switch');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
    }

    final timeField = find.descendant(
      of: find.byType(MinutesSecondsField),
      matching: find.byType(TextFormField),
    );

    String timeText(WidgetTester tester) =>
        tester.widget<TextFormField>(timeField).controller!.text;

    testWidgets('a chip fills the time and refills the depth', (tester) async {
      final dive = await seedDive();
      await pumpEditor(
        tester,
        dive.id,
        pressures: () async => decoBreathedAt720(),
      );
      await addSwitch(tester);

      final chip = find.byType(ActionChip);
      expect(chip, findsOneWidget);
      final label = tester.widget<Text>(
        find.descendant(of: chip, matching: find.byType(Text)),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(timeText(tester), label.data);
      final depth = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey('gas-switch-depth-${_onlyRowId(tester)}')),
          matching: find.byType(TextField),
        ),
      );
      expect(depth.controller!.text, '30.0');
    });

    testWidgets('a depth the diver typed stands when a chip is tapped', (
      tester,
    ) async {
      final dive = await seedDive();
      await pumpEditor(
        tester,
        dive.id,
        pressures: () async => decoBreathedAt720(),
      );
      await addSwitch(tester);

      final depthField = find.descendant(
        of: find.byKey(ValueKey('gas-switch-depth-${_onlyRowId(tester)}')),
        matching: find.byType(TextField),
      );
      await tester.enterText(depthField, '12');
      await tester.pumpAndSettle();
      final chip = find.byType(ActionChip);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(depthField).controller!.text, '12');
    });

    testWidgets('a pressure reload keeps the chips on screen', (tester) async {
      final dive = await seedDive();
      final results = [
        Future.value(decoBreathedAt720()),
        Completer<Map<String, List<TankPressurePoint>>>().future,
      ];
      await pumpEditor(
        tester,
        dive.id,
        pressures: () =>
            results.length > 1 ? results.removeAt(0) : results.first,
      );
      await addSwitch(tester);
      expect(find.byType(ActionChip), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(DiveEditPage)),
      ).invalidate(tankPressuresProvider(dive.id));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ActionChip), findsOneWidget);
    });

    testWidgets('a cylinder with no series shows no chip', (tester) async {
      final dive = await seedDive();
      await pumpEditor(tester, dive.id, pressures: () async => const {});
      await addSwitch(tester);

      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('pressure data still loading leaves the editor working', (
      tester,
    ) async {
      final dive = await seedDive();
      final never = Completer<Map<String, List<TankPressurePoint>>>();
      await pumpEditor(tester, dive.id, pressures: () => never.future);
      await addSwitch(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(timeField, findsOneWidget);
    });

    testWidgets('pressure data failing leaves the editor working', (
      tester,
    ) async {
      final dive = await seedDive();
      await pumpEditor(
        tester,
        dive.id,
        pressures: () async => throw StateError('no pressures'),
      );
      await addSwitch(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(timeField, findsOneWidget);
    });
  });

  group('picking on the profile', () {
    Future<void> addSwitch(WidgetTester tester) async {
      await openGasGear(tester);
      final add = find.text('Add Switch');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
    }

    Future<void> openPicker(WidgetTester tester, Finder icon) async {
      await tester.ensureVisible(icon);
      await tester.pumpAndSettle();
      await tester.tap(icon);
      await tester.pumpAndSettle();
    }

    List<String> times(WidgetTester tester) => [
      for (final field in tester.widgetList<TextFormField>(
        find.descendant(
          of: find.byType(MinutesSecondsField),
          matching: find.byType(TextFormField),
        ),
      ))
        field.controller!.text,
    ];

    testWidgets('setting a time fills the row and the depth', (tester) async {
      final dive = await seedDive();
      await pumpEditor(tester, dive.id);
      await addSwitch(tester);

      await openPicker(tester, find.byTooltip('Pick on profile'));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(900);
      await tester.pump();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();

      expect(times(tester), ['15:00']);
      final depth = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey('gas-switch-depth-${_onlyRowId(tester)}')),
          matching: find.byType(TextField),
        ),
      );
      expect(depth.controller!.text, '30.0');
    });

    testWidgets('a picked time takes the row to its place in time order', (
      tester,
    ) async {
      final dive = await seedDive();
      await pumpEditor(tester, dive.id);
      await addSwitch(tester);
      await addSwitch(tester);
      expect(times(tester), ['0:00', '1:00']);

      await openPicker(tester, find.byTooltip('Pick on profile').first);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(120);
      await tester.pump();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();

      expect(times(tester), ['1:00', '2:00']);
    });

    testWidgets('a row past the profile opens the sheet at its end', (
      tester,
    ) async {
      final dive = await seedDive();
      await pumpEditor(tester, dive.id);
      await addSwitch(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(MinutesSecondsField),
          matching: find.byType(TextFormField),
        ),
        '99:00',
      );
      await tester.pumpAndSettle();

      await openPicker(tester, find.byTooltip('Pick on profile'));

      expect(find.text('30:00 at 0.0m'), findsOneWidget);
    });

    testWidgets('Cancel leaves the dive untouched', (tester) async {
      final dive = await seedDive();
      await repository.createGasSwitch(
        GasSwitch(
          id: 'gs-deco',
          diveId: dive.id,
          timestamp: 900,
          tankId: 'tank-deco',
          createdAt: DateTime.utc(2026, 5, 3, 11),
        ),
      );
      String? savedId;
      await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
      await openGasGear(tester);

      await openPicker(tester, find.byTooltip('Pick on profile'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(savedId, isNotNull, reason: 'save should complete');
      expect(await flagged(), isFalse);
    });

    group('the chart in the sheet', () {
      Map<String, List<TankPressurePoint>> recorded(List<String> tankIds) => {
        for (final id in tankIds)
          id: [
            for (var t = 0; t < 1500; t += 30)
              TankPressurePoint(
                tankId: id,
                timestamp: t,
                pressure: 200 - t / 60,
              ),
          ],
      };

      DiveProfileChart chart(WidgetTester tester) =>
          tester.widget<DiveProfileChart>(find.byType(DiveProfileChart).last);

      testWidgets('draws every cylinder, the row\'s heavier', (tester) async {
        final dive = await seedDive();
        await pumpEditor(
          tester,
          dive.id,
          pressures: () async => recorded(['tank-back', 'tank-deco']),
        );
        await addSwitch(tester);

        await openPicker(tester, find.byTooltip('Pick on profile'));

        expect(
          chart(tester).tankPressures!.keys,
          containsAll(['tank-back', 'tank-deco']),
        );
        expect(chart(tester).emphasizedTankId, 'tank-deco');
        expect(chart(tester).depthAndPressureOnly, isTrue);
      });

      testWidgets('leaves out a cylinder the diver removed', (tester) async {
        final dive = await seedDive();
        await pumpEditor(
          tester,
          dive.id,
          pressures: () async => recorded(['tank-deco', 'tank-gone']),
        );
        await addSwitch(tester);

        await openPicker(tester, find.byTooltip('Pick on profile'));

        expect(chart(tester).tankPressures!.keys, ['tank-deco']);
      });

      testWidgets('marks the other switches, not the row\'s own', (
        tester,
      ) async {
        final dive = await seedDive();
        await pumpEditor(tester, dive.id);
        await addSwitch(tester);
        await addSwitch(tester);

        await openPicker(tester, find.byTooltip('Pick on profile').first);

        final marked = chart(tester).gasSwitches!;
        expect(marked, hasLength(1));
        expect(marked.single.timestamp, 60);
        expect(marked.single.o2Fraction, closeTo(0.21, 0.001));
      });
    });

    testWidgets('a dive with no profile offers no picker', (tester) async {
      final dive = await seedDive(samples: const []);
      await pumpEditor(tester, dive.id);
      await addSwitch(tester);

      expect(find.byTooltip('Pick on profile'), findsNothing);
    });

    testWidgets('a profile of one sample offers no picker', (tester) async {
      final dive = await seedDive(
        samples: const [DiveProfilePoint(timestamp: 60, depth: 10)],
      );
      await pumpEditor(tester, dive.id);
      await addSwitch(tester);

      expect(find.byTooltip('Pick on profile'), findsNothing);
    });
  });
}

/// The switch id in the one row on screen, read from its time field's key.
String _onlyRowId(WidgetTester tester) {
  final key = tester.widget(find.byType(MinutesSecondsField)).key!;
  return (key as ValueKey<String>).value.replaceFirst('gas-switch-time-', '');
}
