import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
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

  Future<void> pumpBoard(
    WidgetTester tester, {
    TripCylinderRepository? repository,
    Future<List<TripCylinderState>>? states,
    bool settle = true,
    FillForecast? forecast,
    ItineraryDayRepository? itinerary,
    TripGasRecord? record,
    bool unlock = false,
    Object? tripReadError,
  }) async {
    // The lock shows only once the board has read its states, so an
    // unlock needs the page settled.
    assert(!unlock || settle, 'unlock needs settle');
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
          tripFillForecastProvider(
            tripId,
          ).overrideWith((ref) async => forecast),
          if (record != null)
            tripGasRecordProvider(tripId).overrideWith((ref) async => record),
          if (itinerary != null)
            itineraryDayRepositoryProvider.overrideWithValue(itinerary),
          if (repository != null)
            tripCylinderRepositoryProvider.overrideWithValue(repository),
          if (states != null)
            tripCylinderStatesProvider(tripId).overrideWith((ref) => states),
          if (tripReadError != null)
            tripByIdProvider(
              tripId,
            ).overrideWith((ref) async => throw tripReadError),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCylinderBoardPage(tripId: tripId),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    // Opened alone the board has its own lock (issue #4527, decision 9):
    // what it changes is held until its Save.
    if (unlock) {
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pumpBoardWithRouter(
    WidgetTester tester,
    GoRouter router, {
    FillForecast? forecast,
  }) async {
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
          tripFillForecastProvider(
            tripId,
          ).overrideWith((ref) async => forecast),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a board whose trip is gone says so instead of waiting', (
    tester,
  ) async {
    await TripRepository().deleteTrip(tripId);
    await pumpBoard(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(AppLocalizationsEn().trips_detail_error_loading),
      findsOneWidget,
    );
  });

  testWidgets('a board whose trip cannot be read says so', (tester) async {
    await pumpBoard(tester, tripReadError: StateError('broken'));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(AppLocalizationsEn().trips_detail_error_loading),
      findsOneWidget,
    );
  });

  testWidgets('an empty board offers to add cylinders', (tester) async {
    await pumpBoard(tester, unlock: true);
    expect(find.text('No cylinders on this trip yet'), findsOneWidget);

    // In the board's sitting (issue #4527): Add sits under the message.
    await tester.tap(find.byType(FilledButton));
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
    // An unfilled slot has no mix or pressure to show; its status says so
    // alone, with no dashed placeholders in front (#2957).
    expect(find.text('Not filled yet'), findsOneWidget);
    expect(find.textContaining('--'), findsNothing);
  });

  testWidgets(
    'on desktop each card carries its own drag handle inside it (#2957)',
    (tester) async {
      final a = await slot('Truck 1', 0);
      final b = await slot('Truck 2', 1);
      await pumpBoard(tester, unlock: true);

      // One handle per card: the list draws none of its own on top.
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      for (final c in [a, b]) {
        final card = tester.getRect(
          find.ancestor(of: find.text(c.label), matching: find.byType(Card)),
        );
        final handle = tester.getRect(find.byKey(Key('slot-drag-${c.id}')));
        expect(card.contains(handle.topLeft), isTrue);
        expect(card.contains(handle.bottomRight), isTrue);
        final menu = tester.getRect(find.byKey(Key('slot-menu-${c.id}')));
        expect(card.contains(menu.topLeft), isTrue);
        expect(card.contains(menu.bottomRight), isTrue);
      }
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('on desktop dragging a card by its handle reorders the board', (
    tester,
  ) async {
    await slot('Truck 1', 0);
    final b = await slot('Truck 2', 1);
    await pumpBoard(tester, unlock: true);

    final handle = find.byKey(Key('slot-drag-${b.id}'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();

    // Held in the board's sitting until its Save (issue #4527).
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('Truck 2'), lessThan(top('Truck 1')));
    final saved = await repo.getCylindersForTrip(tripId);
    expect([for (final c in saved) c.label], ['Truck 1', 'Truck 2']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'on a phone a card is dragged by a long press and shows no handle',
    (tester) async {
      await slot('Truck 1', 0);
      await slot('Truck 2', 1);
      await pumpBoard(tester, unlock: true);

      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(Card),
          matching: find.byType(ReorderableDelayedDragStartListener),
        ),
        findsNWidgets(2),
      );
    },
    variant: TargetPlatformVariant.mobile(),
  );

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
    await pumpBoard(tester, unlock: true);

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
    // Held in the board's sitting until its Save (issue #4527): the dive
    // keeps its tank and, until then, its link too.
    final tank = await db
        .customSelect(
          'SELECT end_pressure, trip_cylinder_id FROM dive_tanks WHERE id = ?',
          variables: [const Variable<String>('t1')],
        )
        .getSingle();
    expect(tank.read<double>('end_pressure'), 60);
    expect(tank.readNullable<String>('trip_cylinder_id'), a.id);
  });

  testWidgets('fill several preselects the slots that are not full', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    final b = await slot('Truck 2', 1);
    await fill(a.id);
    await pumpBoard(tester, unlock: true);

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

  testWidgets('a reorder shows the new order at once and is held for Save', (
    tester,
  ) async {
    await slot('Truck 1', 0);
    await slot('Truck 2', 1);
    await slot('Truck 3', 2);
    await pumpBoard(tester, unlock: true);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(2, 0);
    await tester.pump();
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('Truck 3'), lessThan(top('Truck 1')));

    await tester.pumpAndSettle();
    // Held in the board's sitting until its Save (issue #4527).
    final stored = await repo.getCylindersForTrip(tripId);
    expect(stored.map((c) => c.label), ['Truck 1', 'Truck 2', 'Truck 3']);
    expect(top('Truck 3'), lessThan(top('Truck 1')));
  });

  testWidgets('Log dive opens a new dive on that slot', (tester) async {
    final a = await slot('Truck 1', 0);
    String? pushed;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => TripCylinderBoardPage(tripId: tripId),
        ),
        GoRoute(
          path: '/dives/new',
          builder: (_, state) {
            pushed = state.uri.toString();
            return const Scaffold(body: Text('NEW DIVE'));
          },
        ),
      ],
    );
    await pumpBoardWithRouter(tester, router);
    addTearDown(router.dispose);

    await tester.tap(find.byKey(Key('slot-menu-${a.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log dive'));
    await tester.pumpAndSettle();

    expect(find.text('NEW DIVE'), findsOneWidget);
    final uri = Uri.parse(pushed!);
    expect(uri.queryParameters['tripId'], tripId);
    expect(uri.queryParameters['tripCylinderId'], a.id);
  });

  test('reorderedIds moves one id and keeps the rest in order', () {
    expect(reorderedIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(reorderedIds(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(reorderedIds(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
  });
  testWidgets('the board shows the forecast as a banner', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: const FillForecast(
        fullCount: 1,
        partialCount: 0,
        todayDemand: 0,
        tomorrowDemand: 4,
        tomorrowSupply: 1,
        todayShortfall: 0,
        tomorrowShortfall: 3,
        deadlineMinutes: null,
        remainingDemand: 8,
        days: [],
      ),
    );
    expect(find.byKey(const Key('fill-forecast-banner')), findsOneWidget);
    expect(find.text("Tomorrow needs 4, you'll have 1 full."), findsOneWidget);
  });
  FillForecast forecastWithDays(List<FillForecastDay> days) => FillForecast(
    fullCount: 4,
    partialCount: 0,
    todayDemand: 2,
    tomorrowDemand: 2,
    tomorrowSupply: 2,
    todayShortfall: 0,
    tomorrowShortfall: 0,
    deadlineMinutes: null,
    remainingDemand: 6,
    days: days,
  );

  testWidgets('the strip lists the remaining days with their plans', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(date: DateTime(2026, 3, 13), plannedDives: 2),
        FillForecastDay(
          date: DateTime(2026, 3, 14),
          plannedDives: 1,
          isOverride: true,
        ),
      ]),
    );
    expect(find.text('Planned dives'), findsOneWidget);
    expect(find.textContaining('2 dives'), findsOneWidget);
    expect(find.textContaining('1 dive'), findsOneWidget);
  });

  testWidgets('a day the diver planned says so to a screen reader', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      forecast: forecastWithDays([
        FillForecastDay(
          date: DateTime(2026, 3, 10),
          plannedDives: 3,
          isOverride: true,
        ),
      ]),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.edit_calendar));
    expect(icon.semanticLabel, 'Planned by you');
  });
  testWidgets('the board has a Record segment', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      record: const TripGasRecord(
        rows: [],
        slots: [],
        fillsLogged: 1,
        costs: [],
        packageFills: 0,
        unlinked: [],
        multipleDivers: false,
      ),
    );
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-empty')), findsOneWidget);
  });
}
