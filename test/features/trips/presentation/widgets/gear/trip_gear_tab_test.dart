import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

final _now = DateTime.now();
final _t0 = DateTime(2025, 1, 1);

Trip trip({bool past = false, bool started = false}) => Trip(
  id: 't1',
  name: 'Bonaire',
  startDate: DateTime(
    _now.year,
    _now.month,
    _now.day + (past ? -20 : (started ? -1 : 10)),
  ),
  endDate: DateTime(
    _now.year,
    _now.month,
    _now.day + (past ? -15 : (started ? 4 : 15)),
  ),
  createdAt: _t0,
  updatedAt: _t0,
);

const bcd = EquipmentItem(
  id: 'bcd',
  name: 'Hollis wing',
  type: EquipmentType.bcd,
);
const fins = EquipmentItem(id: 'fins', name: 'Fins', type: EquipmentType.fins);
const reg = EquipmentItem(
  id: 'reg',
  name: 'Regulator',
  type: EquipmentType.regulator,
);
const tank = EquipmentItem(
  id: 'tk',
  name: 'Faber 12',
  type: EquipmentType.tank,
);
const ccr = EquipmentItem(
  id: 'ccr',
  name: 'JJ CCR',
  type: EquipmentType.rebreather,
);

EquipmentSet kit(List<EquipmentItem> items) => EquipmentSet(
  id: 's1',
  name: 'Reef kit',
  description: '',
  equipmentIds: [for (final i in items) i.id],
  items: items,
  createdAt: _now,
  updatedAt: _now,
);

DueClock dueClock(String itemId, {bool overdue = false}) => (
  item: EquipmentItem(id: itemId, name: itemId, type: EquipmentType.regulator),
  status: ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$itemId',
      equipmentId: itemId,
      serviceKindId: 'annual',
      createdAt: _t0,
      updatedAt: _t0,
    ),
    kind: ServiceKind(
      id: 'annual',
      name: 'Annual service',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: _t0,
      updatedAt: _t0,
    ),
    anchor: _t0,
    dueDate: overdue
        ? _now.subtract(const Duration(days: 30))
        : _now.add(const Duration(days: 5)),
    severity: overdue
        ? ServiceClockSeverity.overdue
        : ServiceClockSeverity.dueSoon,
    now: _now,
  ),
);

ScrubberMargin margin({double marginAfter = 120, bool caution = false}) =>
    ScrubberMargin(
      item: ccr,
      ratedMinutes: 300,
      consumedMinutes: 90,
      consumedSince: DateTime(2025, 2, 1),
      remainingBefore: 210,
      expectedDives: 10,
      expectedDivesN: 0,
      divesFromOverride: true,
      minutesFromOverride: false,
      minutesPerDive: 35,
      minutesPerDiveN: 2,
      expectedUse: 350,
      marginAfter: marginAfter,
      caution: caution,
    );

TripCylinderState slot(String id, {String? equipmentId, bool full = false}) {
  final at = DateTime.utc(2026, 1, 1);
  return foldCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 't1',
      equipmentId: equipmentId,
      label: id,
      workingPressure: 207,
      createdAt: at,
      updatedAt: at,
    ),
    events: full
        ? [
            TripCylinderEvent(
              id: 'e-$id',
              tripCylinderId: id,
              kind: TripCylinderEventKind.fill,
              occurredAt: at,
              bottleLabel: '#140',
              pressure: 207,
              o2Percent: 32,
              createdAt: at,
              updatedAt: at,
            ),
          ]
        : const [],
    uses: const [],
  );
}

class _FakeEquipment extends EquipmentRepository {
  @override
  Future<List<String>> usableSetMemberIds(
    List<String> ids,
    String diverId,
  ) async => ids;
}

class _FakePacks extends TripEquipmentRepository {
  bool failing = false;
  final packed = <(String, List<String>)>[];
  final unpacked = <(String, String)>[];

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    if (failing) throw StateError('database is locked');
    packed.add((tripId, equipmentIds.toList()));
    return equipmentIds.length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async {
    if (failing) throw StateError('database is locked');
    unpacked.add((tripId, equipmentId));
  }
}

class _FakeSlots extends TripCylinderRepository {
  final created = <List<TripCylinder>>[];

  @override
  Future<List<TripCylinder>> createCylinders(
    List<TripCylinder> cylinders,
  ) async {
    created.add(cylinders);
    return cylinders;
  }
}

typedef _Harness = ({_FakePacks packs, _FakeSlots slots, List<String> pushed});

Future<_Harness> _pumpTab(
  WidgetTester tester, {
  Trip? onTrip,
  List<EquipmentItem> gear = const [],
  List<TripCylinderState> states = const [],
  List<DueClock> alerts = const [],
  List<ScrubberMargin> margins = const [],
  List<EquipmentItem> active = const [],
  List<EquipmentSet> sets = const [],
  AppSettings settings = const AppSettings(),
  Object? gearError,
  List<String>? forecastReads,
}) async {
  final packs = _FakePacks();
  final slots = _FakeSlots();
  final pushed = <String>[];
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: TripGearTab(trip: onTrip ?? trip())),
      ),
      GoRoute(
        path: '/trips/:id/cylinders',
        builder: (_, s) {
          pushed.add(s.uri.path);
          return const Scaffold();
        },
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (_, s) {
          pushed.add(s.uri.path);
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        tripGearProvider('t1').overrideWith((ref) async {
          if (gearError != null) throw gearError;
          return gear;
        }),
        tripCylinderStatesProvider('t1').overrideWith((ref) async => states),
        tripCylindersProvider(
          't1',
        ).overrideWith((ref) async => [for (final s in states) s.cylinder]),
        tripServiceAlertsProvider('t1').overrideWith((ref) async => alerts),
        tripScrubberMarginsProvider('t1').overrideWith((ref) async => margins),
        tripFillForecastProvider('t1').overrideWith((ref) async {
          forecastReads?.add('t1');
          return null;
        }),
        tripEquipmentRepositoryProvider.overrideWithValue(packs),
        tripCylinderRepositoryProvider.overrideWithValue(slots),
        activeEquipmentProvider.overrideWith((ref) async => active),
        equipmentItemProvider.overrideWith(
          (ref, id) async =>
              [...gear, ...active].where((i) => i.id == id).firstOrNull,
        ),
        equipmentSetsProvider.overrideWith((ref) async => sets),
        equipmentSetWithItemsProvider.overrideWith(
          (ref, id) async => sets.where((s) => s.id == id).firstOrNull,
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        equipmentRepositoryProvider.overrideWithValue(_FakeEquipment()),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (packs: packs, slots: slots, pushed: pushed);
}

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('trip-gear-add')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('an upcoming trip with nothing explains Add', (tester) async {
    await _pumpTab(tester);
    expect(
      find.text(
        "Nothing packed yet. Add the gear you'll bring and the cylinders "
        "you'll dive from.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-gear-add')), findsOneWidget);
  });

  testWidgets('a past trip with nothing says so and offers no Add', (
    tester,
  ) async {
    await _pumpTab(tester, onTrip: trip(past: true));
    expect(find.text('Nothing was packed for this trip.'), findsOneWidget);
    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
  });

  testWidgets('packed gear and cylinders sit in two sections', (tester) async {
    await _pumpTab(
      tester,
      gear: const [bcd, fins],
      states: [slot('Truck 1'), slot('Truck 2')],
    );
    expect(find.text('Packed'), findsOneWidget);
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.text('Hollis wing'), findsOneWidget);
    expect(find.text('Truck 2'), findsOneWidget);
  });

  testWidgets('an owned cylinder is listed once', (tester) async {
    await _pumpTab(
      tester,
      gear: const [tank, bcd],
      states: [slot('Faber 12', equipmentId: 'tk')],
    );
    expect(find.text('Faber 12'), findsOneWidget);
    expect(find.textContaining('My equipment'), findsOneWidget);
  });

  testWidgets('before departure an owned slot names its item', (tester) async {
    // The slot carries the tank's mark, so the item's name is what tells
    // the diver which of their cylinders it is.
    await _pumpTab(
      tester,
      states: [slot('A1', equipmentId: 'tk')],
      active: const [tank],
    );
    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Faber 12'), findsOneWidget);
    expect(find.textContaining('My equipment'), findsNothing);
  });

  testWidgets('a service clock reads on its item', (tester) async {
    await _pumpTab(tester, gear: const [reg], alerts: [dueClock('reg')]);
    expect(find.textContaining('Annual service'), findsOneWidget);
  });

  testWidgets('an overdue clock reads overdue on its item', (tester) async {
    await _pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg', overdue: true)],
    );
    expect(find.textContaining('overdue'), findsOneWidget);
  });

  testWidgets('a scrubber margin reads on its rebreather', (tester) async {
    await _pumpTab(tester, gear: const [ccr], margins: [margin()]);
    expect(find.text('120 min scrubber margin'), findsOneWidget);
  });

  testWidgets('before departure a slot shows its specs and origin', (
    tester,
  ) async {
    await _pumpTab(tester, states: [slot('Truck 1', full: true)]);
    expect(find.text('Truck 1'), findsOneWidget);
    expect(find.textContaining('207 bar'), findsOneWidget);
    expect(find.textContaining('Rental'), findsOneWidget);
    expect(find.text('Open board'), findsNothing);
  });

  testWidgets('from the first day a slot shows its state and the board '
      'opens from the header', (tester) async {
    await _pumpTab(
      tester,
      onTrip: trip(started: true),
      states: [slot('Truck 1', full: true)],
    );
    expect(find.text('#140 · EAN32 · 207 bar'), findsOneWidget);
    expect(find.text('Open board'), findsOneWidget);
  });

  testWidgets('tapping a slot opens the board', (tester) async {
    final h = await _pumpTab(tester, states: [slot('Truck 1')]);
    await tester.tap(find.text('Truck 1'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('tapping a packed item opens it', (tester) async {
    final h = await _pumpTab(tester, gear: const [bcd]);
    await tester.tap(find.text('Hollis wing'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/equipment/bcd']);
  });

  testWidgets('Unpack removes the item', (tester) async {
    final h = await _pumpTab(tester, gear: const [bcd]);
    await tester.tap(find.byKey(const Key('trip-gear-menu-bcd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();
    expect(h.packs.unpacked, [('t1', 'bcd')]);
  });

  testWidgets('Add offers three ways in', (tester) async {
    await _pumpTab(tester, gear: const [bcd]);
    await _openAdd(tester);
    expect(find.text('From my equipment'), findsOneWidget);
    expect(find.text('An equipment set'), findsOneWidget);
    expect(find.text('Rental cylinders'), findsOneWidget);
  });

  testWidgets('From my equipment packs a picked item', (tester) async {
    final h = await _pumpTab(tester, active: const [bcd]);
    await _openAdd(tester);
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hollis wing').last);
    await tester.pumpAndSettle();
    expect(h.packs.packed.single.$2, ['bcd']);
    expect(h.slots.created, isEmpty);
  });

  testWidgets('From my equipment makes a picked cylinder a slot', (
    tester,
  ) async {
    final h = await _pumpTab(tester, active: const [tank]);
    await _openAdd(tester);
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faber 12').last);
    await tester.pumpAndSettle();
    expect(h.packs.packed, isEmpty);
    expect(h.slots.created.single.single.equipmentId, 'tk');
  });

  testWidgets('An equipment set packs the members and slots its cylinders', (
    tester,
  ) async {
    final h = await _pumpTab(
      tester,
      sets: [
        kit(const [bcd, fins, tank]),
      ],
    );
    await _openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(h.packs.packed.single.$2, ['bcd', 'fins']);
    expect(h.slots.created.single.single.equipmentId, 'tk');
    // The slotted cylinder counts alongside the packed items (#2877).
    expect(find.text('Packed 3 items from Reef kit'), findsOneWidget);
  });

  testWidgets('a set of only cylinders counts the slots it adds (#2877)', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      sets: [
        kit(const [tank]),
      ],
    );
    await _openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(find.text('Packed 1 item from Reef kit'), findsOneWidget);
  });

  testWidgets('a set whose cylinder is already a slot adds nothing', (
    tester,
  ) async {
    final h = await _pumpTab(
      tester,
      states: [slot('c1', equipmentId: 'tk')],
      sets: [
        kit(const [tank]),
      ],
    );
    await _openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(h.slots.created, isEmpty);
    expect(
      find.text('Everything in Reef kit is already packed'),
      findsOneWidget,
    );
  });

  testWidgets('Rental cylinders opens the rental form alone', (tester) async {
    await _pumpTab(tester);
    await _openAdd(tester);
    await tester.tap(find.text('Rental cylinders'));
    await tester.pumpAndSettle();
    expect(find.text('How many'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SegmentedButton), findsNothing);
  });

  testWidgets('tapping a service line opens that item\'s clocks', (
    tester,
  ) async {
    final h = await _pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg'), dueClock('reg', overdue: true)],
    );
    await tester.tap(find.byKey(const Key('trip-gear-alert-reg')));
    await tester.pumpAndSettle();
    expect(find.byType(TripServiceAlertList), findsOneWidget);
    expect(
      tester
          .widget<TripServiceAlertList>(find.byType(TripServiceAlertList))
          .alerts,
      hasLength(2),
    );
    expect(h.pushed, isEmpty);
  });

  testWidgets('the alert sheet names its item once, not on every row (#2882)', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg'), dueClock('reg', overdue: true)],
    );
    await tester.tap(find.byKey(const Key('trip-gear-alert-reg')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Regulator')),
      findsOneWidget,
    );
    // dueClock names each alert's item by its id; no row may repeat it.
    expect(
      find.descendant(of: sheet, matching: find.text('reg')),
      findsNothing,
    );
    final rows = find.descendant(of: sheet, matching: find.byType(ListTile));
    expect(rows, findsNWidgets(2));
    for (final row in tester.widgetList<ListTile>(rows)) {
      expect(row.subtitle, isNull);
    }
  });

  testWidgets('tapping a scrubber line opens the breakdown', (tester) async {
    await _pumpTab(tester, gear: const [ccr], margins: [margin()]);
    await tester.tap(find.byKey(const Key('trip-gear-alert-ccr')));
    await tester.pumpAndSettle();
    expect(find.byType(TripScrubberMarginDetails), findsOneWidget);
    expect(find.text('Scrubber margin'), findsOneWidget);
  });

  testWidgets('an item with no trip alert has no alert line to tap', (
    tester,
  ) async {
    await _pumpTab(tester, gear: const [fins]);
    expect(find.byKey(const Key('trip-gear-alert-fins')), findsNothing);
  });

  testWidgets('before departure an imperial diver sees rated capacity', (
    tester,
  ) async {
    final al80 = foldCylinderState(
      cylinder: TripCylinder(
        id: 'c1',
        tripId: 't1',
        label: 'Truck 1',
        volume: 11.1,
        workingPressure: 207,
        createdAt: _t0,
        updatedAt: _t0,
      ),
      events: const [],
      uses: const [],
    );
    await _pumpTab(
      tester,
      states: [al80],
      settings: const AppSettings(
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    );
    final subtitle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('trip-gear-slot-c1')),
        matching: find.textContaining('Rental'),
      ),
    );
    // About 78 cuft of gas, never the 0.4 cuft of water the tank holds.
    expect(subtitle.data, matches(RegExp(r'^~?7[0-9] cuft')));
  });

  testWidgets('a failed load says so instead of spinning', (tester) async {
    await _pumpTab(tester, gearError: StateError('database is locked'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('an owned cylinder\'s service clock reads on its slot and '
      'opens the detail', (tester) async {
    await _pumpTab(
      tester,
      states: [slot('Faber 12', equipmentId: 'tk')],
      alerts: [dueClock('tk')],
    );
    expect(find.byKey(const Key('trip-gear-alert-tk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip-gear-alert-tk')));
    await tester.pumpAndSettle();
    expect(find.byType(TripServiceAlertList), findsOneWidget);
  });

  testWidgets('a failed unpack says so without the exception', (tester) async {
    final h = await _pumpTab(tester, gear: const [bcd]);
    h.packs.failing = true;
    await tester.tap(find.byKey(const Key('trip-gear-menu-bcd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();
    expect(find.text('Could not change the gear. Try again.'), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('a failed Add says so without the exception', (tester) async {
    final h = await _pumpTab(tester, active: const [bcd]);
    h.packs.failing = true;
    await _openAdd(tester);
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hollis wing').last);
    await tester.pumpAndSettle();
    expect(find.text('Could not change the gear. Try again.'), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('an ended trip shows no service or scrubber lines (#2485)', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      onTrip: trip(past: true),
      gear: const [reg, ccr],
      states: [slot('Faber 12', equipmentId: 'tk')],
      alerts: [dueClock('reg', overdue: true), dueClock('tk')],
      margins: [margin()],
    );
    expect(find.textContaining('overdue'), findsNothing);
    expect(find.textContaining('scrubber margin'), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-reg')), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-ccr')), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-tk')), findsNothing);
  });

  testWidgets('only a trip under way reads the fill forecast', (tester) async {
    final upcomingReads = <String>[];
    await _pumpTab(
      tester,
      states: [slot('Faber 12')],
      forecastReads: upcomingReads,
    );
    expect(upcomingReads, isEmpty);

    final endedReads = <String>[];
    await _pumpTab(
      tester,
      onTrip: trip(past: true),
      states: [slot('Faber 12')],
      forecastReads: endedReads,
    );
    expect(endedReads, isEmpty);

    final underWayReads = <String>[];
    await _pumpTab(
      tester,
      onTrip: trip(started: true),
      states: [slot('Faber 12')],
      forecastReads: underWayReads,
    );
    expect(underWayReads, isNotEmpty);
  });
}
