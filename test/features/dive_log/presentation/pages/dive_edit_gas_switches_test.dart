import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show GasSwitche;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
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

  Future<Dive> seedDive({List<DiveTank> tanks = const [back, deco]}) =>
      repository.createDive(
        Dive(
          id: 'dive-32',
          dateTime: DateTime.utc(2026, 5, 3, 10),
          runtime: const Duration(seconds: 1800),
          tanks: tanks,
          profile: profile,
        ),
      );

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
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
}
