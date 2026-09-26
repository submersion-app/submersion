import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repo;
  late String tripId;
  final at = DateTime.utc(2026, 3, 9, 8, 15);
  const units = UnitFormatter(AppSettings());

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<TripCylinder> slot(String label, int order) => repo.createCylinder(
    TripCylinder(
      id: '',
      tripId: tripId,
      label: label,
      volume: 11.1,
      workingPressure: 207,
      sortOrder: order,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> fill(String cylinderId) => repo.createEvent(
    TripCylinderEvent(
      id: '',
      tripCylinderId: cylinderId,
      kind: TripCylinderEventKind.fill,
      occurredAt: at,
      bottleLabel: '14',
      pressure: 200,
      o2Percent: 32,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> pumpBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiveCentersProvider.overrideWith((ref) async => const []),
          activeEquipmentProvider.overrideWith((ref) async => const []),
          tankPresetsProvider.overrideWith(
            (ref) => Future.value([
              TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!),
            ]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCylinderBoardPage(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty board offers to add cylinders', (tester) async {
    await pumpBoard(tester);
    expect(find.text('No cylinders on this trip yet'), findsOneWidget);
    final fillSeveral = tester.widget<IconButton>(
      find.byKey(const Key('board-fill-several')),
    );
    expect(fillSeveral.onPressed, isNull);

    await tester.tap(find.byKey(const Key('board-add')));
    await tester.pumpAndSettle();
    expect(find.text('Rental'), findsOneWidget);
  });

  testWidgets('each slot shows its mix, pressure, status and history', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await slot('Truck 2', 1);
    await fill(a.id);
    await pumpBoard(tester);

    expect(find.text('Truck 1'), findsOneWidget);
    expect(
      find.text('EAN32 · ${units.formatPressure(200)} · Full'),
      findsOneWidget,
    );
    expect(find.text('Bottle 14'), findsOneWidget);
    expect(
      find.text(
        'Filled ${units.formatDateTime(at, l10n: AppLocalizationsEn())}',
      ),
      findsOneWidget,
    );
    expect(find.text('Truck 2'), findsOneWidget);
    expect(find.textContaining('Not filled yet'), findsOneWidget);
  });

  testWidgets('deleting a used slot names the dive count and keeps the dive', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: at.millisecondsSinceEpoch + 3600000,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
            tripCylinderId: Value(a.id),
            endPressure: const Value(60.0),
          ),
        );
    await pumpBoard(tester);

    await tester.tap(find.byKey(Key('slot-menu-${a.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Delete this cylinder and its fills? 1 dive used it. That dive keeps its tank; only the link is removed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Truck 1'), findsNothing);
    final tank = await db
        .customSelect(
          'SELECT end_pressure, trip_cylinder_id FROM dive_tanks WHERE id = ?',
          variables: [const Variable<String>('t1')],
        )
        .getSingle();
    expect(tank.read<double>('end_pressure'), 60);
    expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
  });

  testWidgets('fill several preselects the slots that are not full', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    final b = await slot('Truck 2', 1);
    await fill(a.id);
    await pumpBoard(tester);

    await tester.tap(find.byKey(const Key('board-fill-several')));
    await tester.pumpAndSettle();
    final full = tester.widget<CheckboxListTile>(
      find.byKey(Key('fill-slot-${a.id}')),
    );
    final notFull = tester.widget<CheckboxListTile>(
      find.byKey(Key('fill-slot-${b.id}')),
    );
    expect(full.value, isFalse);
    expect(notFull.value, isTrue);
  });

  test('reorderedIds moves one id and keeps the rest in order', () {
    expect(reorderedIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(reorderedIds(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(reorderedIds(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
  });
}
