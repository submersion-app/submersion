/// The trip gear tab under test: the fixtures, the fakes it writes
/// through, and the pump and Add helpers that trip_gear_tab_test.dart and
/// trip_gear_add_test.dart share.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/folded_groups.dart';

final now = DateTime.now();
final t0 = DateTime(2025, 1, 1);

Trip trip({bool past = false, bool started = false}) => Trip(
  id: 't1',
  name: 'Bonaire',
  startDate: DateTime(
    now.year,
    now.month,
    now.day + (past ? -20 : (started ? -1 : 10)),
  ),
  endDate: DateTime(
    now.year,
    now.month,
    now.day + (past ? -15 : (started ? 4 : 15)),
  ),
  createdAt: t0,
  updatedAt: t0,
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
  createdAt: now,
  updatedAt: now,
);

DueClock dueClock(String itemId, {bool overdue = false}) => (
  item: EquipmentItem(id: itemId, name: itemId, type: EquipmentType.regulator),
  status: ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$itemId',
      equipmentId: itemId,
      serviceKindId: 'annual',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'annual',
      name: 'Annual service',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: overdue
        ? now.subtract(const Duration(days: 30))
        : now.add(const Duration(days: 5)),
    severity: overdue
        ? ServiceClockSeverity.overdue
        : ServiceClockSeverity.dueSoon,
    now: now,
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

class FakeEquipment extends EquipmentRepository {
  @override
  Future<List<String>> usableSetMemberIds(
    List<String> ids,
    String diverId,
  ) async => ids;
}

class FakePacks extends TripEquipmentRepository {
  final packed = <(String, List<String>)>[];
  final unpacked = <(String, String)>[];

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    packed.add((tripId, [...equipmentIds]));
    return equipmentIds.length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async {
    unpacked.add((tripId, equipmentId));
  }
}

class FakeSlots extends TripCylinderRepository {
  FakeSlots(this.stored);

  /// The board as stored, which a sitting reads.
  final List<TripCylinder> stored;
  final created = <List<TripCylinder>>[];

  @override
  Future<List<TripCylinder>> getCylindersForTrip(String tripId) async => stored;

  @override
  Future<Map<String, List<TripCylinderEvent>>> getEventsForTrip(
    String tripId,
  ) async => const {};

  @override
  Future<Map<String, List<TripCylinderTankUse>>> getTankUsesForTrip(
    String tripId,
  ) async => const {};

  @override
  Future<List<TripCylinder>> createCylinders(
    List<TripCylinder> cylinders,
  ) async {
    created.add(cylinders);
    return cylinders;
  }
}

typedef Harness = ({
  FakePacks packs,
  FakeSlots slots,
  List<String> pushed,
  EditSession<Trip>? session,
  SittingList<Trip, EquipmentItem> packed,
  SittingList<Trip, TripCylindersHeld> board,
});

extension HarnessHeld on Harness {
  /// The ids of the gear the sitting holds packed, in its order.
  List<String> get heldPacked => [
    for (final i in packed.current(session!)!) i.id,
  ];

  /// The slots the sitting holds on the board, in board order.
  List<TripCylinder> get heldSlots => heldCylindersOf(session!, board)!.slots;

  /// Performs Save's writes of the gear the sitting holds.
  Future<void> save() => session!.runHeldWrites();
}

Future<Harness> pumpTab(
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
  String? scanned,
  ComponentsIndex components = ComponentsIndex.empty,
  bool editing = false,
}) async {
  final packs = FakePacks();
  final slots = FakeSlots([for (final s in states) s.cylinder]);
  final pushed = <String>[];
  final shown = onTrip ?? trip();
  // The trip page's open sitting, with the packed gear, the board and the
  // checklists read, as the page has them before the tab acts.
  final packed = tripPackedGearList(read: (_) async => gear, packs: packs);
  final board = tripCylindersList(
    cylinders: slots,
    copier: TripFillPassportCopier(),
  );
  EditSession<Trip>? session;
  if (editing) {
    final open = session = EditSession<Trip>(shown);
    addTearDown(open.dispose);
    await packed.load(open);
    await board.load(open);
    await tripChecklistsList(
      checklists: TripChecklistsRepository(),
      items: TripChecklistRepository(),
    ).load(open);
  }
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: TripGearTab(trip: shown, editing: session),
        ),
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
        equipmentRepositoryProvider.overrideWithValue(FakeEquipment()),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => components,
        ),
        if (scanned != null)
          passportScanLauncherProvider.overrideWithValue(
            (context) async => scanned,
          ),
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
  return (
    packs: packs,
    slots: slots,
    pushed: pushed,
    session: session,
    packed: packed,
    board: board,
  );
}

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('trip-gear-add')));
  await tester.pumpAndSettle();
}

/// Opens Add, then From my equipment: the multi-select picker (#4205).
Future<void> openPicker(WidgetTester tester) async {
  await openAdd(tester);
  await tester.tap(find.text('From my equipment'));
  await tester.pumpAndSettle();
  // The picker opens with its groups folded (#3364).
  await openFoldedGroups(tester);
}

/// Ticks each named row in turn, then presses Add N.
Future<void> tickAndAdd(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    // Taller group headings (#3364) can push a row below the sheet's fold.
    await tester.ensureVisible(find.text(name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Add ${names.length}'));
  await tester.pumpAndSettle();
}
